-- This file is used to create and process virtual environments used for compile templates/
-- To create a venv, surface and template names must be provided.
-- When compilation starts, virtual environment is created in storage.compiling_surfaces[surface_index]

--[[
-------------------------------------------------------------------------------
VIRTUAL ENVIRONMENT INFO
-------------------------------------------------------------------------------
template_name string: trimmed template name provided by player
research_template bool: true if this is a research template
input: {items = {}, fluids = {}, energy = 0}. Used to keep track of all inputs
output: {items = {}, fluids = {}, energy = 0}. Used to keep track of all outputs
compilation_time int: full compilation time in seconds
remaining_time int: remaining compilation time in seconds

Fluids are stored in a hashmap. Key is fluid name, value is count.
Items are stored in a two-level hashmap. First key is item name, second key is quality, value is count.
For example:
items = {
    ["electronic-circuit"] = {
        ["normal"] = 1234,
        ["epic"] = 555,
        ["legendary"] = 200,
    },
    ["engine-unit"] = {
        ["rare"] = 200,
        ["normal"] = 500,
    }
}

Additionaly if research_template == true venv will also contain following keys:
benchmark_time int: time in seconds allocated to each research benchmarks
research_benchmarks array: contains data about technical research that will be used for benchmarks
    each element is a table with following keys: tech_name, ingredient_name
    tech_name is used to start the research; ingredient_name is used at the end to create template
benchmark_stage string "slow"/"fast": represents current benchmark stage
currently_researching int: index of currently researching tech in research_benchmarks or 0 if nothing is being researched
current_research_time int: time in seconds that current tech is researching
benchmark_results: {slow = {}, fast = {}}

"slow" and "fast" are two-level hashmaps. First key is ingredient name (science pack name).
Second layer contains 2 keys: points (number of research points generated with that ingredient)
and time (seconds spent researching with that ingredient). Value is integer.
--]]

local chunk_processor = require("scripts.template-creation.chunk-processor")

local Helper = {}

-------------------------------------------------------------------------------
-- INITIALIZATION OF TECHNICAL FORCE USED FOR COMPILING RESEARCH TEMPLATES
-------------------------------------------------------------------------------

-- Collects and enables all technical research and saves it to storage
local technical_research_prefix = "FV-technical-"
local function collect_technical_research()
    local lab_tech = game.forces["lab-technical"].technologies
    -- going through prototypes and identifying technical research by prefix
    for tech_name, tech_prototype in pairs(prototypes.technology) do
        if tech_name:find("^" .. technical_research_prefix) then
            local first_ingredient = tech_prototype.research_unit_ingredients[1]
            local tech_data = {
                tech_name = tech_name,
                ingredient_name = first_ingredient.name
            }
            table.insert(storage.technical_research, tech_data)
            -- enabling technology for lab force
            lab_tech[tech_name].enabled = true
        end
    end
end

function Helper.init_lab_force()
    -- creating technical force if it doesn't exist
    if not game.forces["lab-technical"] then
        game.create_force("lab-technical")
    end
    local lab_force = game.forces["lab-technical"]
    -- copying all player force data to match progress
    lab_force.copy_from("player")
    storage.technical_research = {}
    collect_technical_research()
    lab_force.disable_research()
    local player_force = game.forces["player"]
    game.forces["player"].set_friend(lab_force, true)
    game.forces["lab-technical"].set_friend(player_force, true)
end

-------------------------------------------------------------------------------
-- COMPILATION HELPER FUNCTIONS
-------------------------------------------------------------------------------

-- Enables labs on a given surface. And changes their force to lab-technical
local function enable_labs(surface)
    if not surface or not surface.valid then return end
    local labs = surface.find_entities_filtered{type = "lab"}
    for _, lab in ipairs(labs) do
        if lab and lab.valid then
            lab.force = "lab-technical"
            lab.disabled_by_script = false
        end
    end
end

-- Disables labs on a given surface. And changes their force to lab-technical
local function disable_labs(surface)
    if not surface or not surface.valid then return end
    local labs = surface.find_entities_filtered{type = "lab"}
    for _, lab in ipairs(labs) do
        if lab and lab.valid then
            lab.force = "player"
            lab.disabled_by_script = true
        end
    end
end

-- Decides current research index for benchmarking given venv
-- Compilation consists of 2 stages:
-- First stage is for slow benchmarks (venv.benchmark_time seconds for each research)
-- Second stage is for testing logistics: labs get speed boost (1 second for each research)
-- @returns int: research index, string: stage (slow/fast) 
local function decide_current_research(venv)
    local elapsed_time = venv.compilation_time - venv.remaining_time
    local research_count = #venv.research_benchmarks
    if elapsed_time < research_count * venv.benchmark_time then
        -- slow stage
        return math.floor(elapsed_time / venv.benchmark_time) + 1, "slow"
    else
        -- fast stage
        return elapsed_time % research_count + 1, "fast"
    end
end

-- Changes research for lab force given virtual environment. 
-- Saves generated science points for current research to venv.
-- @param new_index int: index of new research (in research_benchmarks)
--      or 0 to cancel the current research and just save the stats.     
-- @returns bool: true if everything ok.
local function change_research(venv, new_index)
    local current_idx = venv.currently_researching
    local lab_force = game.forces["lab-technical"]
    -- getting LuaFlowStatistics for lab-force item production on nauvis
    -- there will only be generated research points if any
    local prod_stat = lab_force.get_item_production_statistics("nauvis")
    -- checking if something is currently selected
    if current_idx > 0 then
        -- getting uint64 or double: number of science points produced
        local points_produced = prod_stat.get_input_count("science")
        -- getting string: current research ingredient 
        local ingredient = venv.research_benchmarks[current_idx]["ingredient_name"]
        -- saving produced points to venv
        if points_produced > 0 then
            local curr_stage = venv.benchmark_results[venv.benchmark_stage]
            -- creating entry of current stage table if necessery
            curr_stage[ingredient] = curr_stage[ingredient] or {points = 0, time = 0}
            curr_stage[ingredient].points = curr_stage[ingredient].points + points_produced
            curr_stage[ingredient].time = curr_stage[ingredient].time + venv.current_research_time
        end
    end
    -- cancel current research, clear research production statistics
    -- and start a new one if new_index > 0
    lab_force.cancel_current_research()
    prod_stat.clear()
    if new_index > 0 then
        local status = lab_force.add_research(venv.research_benchmarks[new_index].tech_name)
        if not status then return false end
        venv.currently_researching = new_index
    end
    return true
end

-- Allocates time for benchmarking research point production.
-- @param venv table: has data about compiling surface
-- @param research array: contains tables describing each research.
--      each table must contain keys: "tech_name" and "ingredient_name"
-- @param time int: seconds for each benchmark
local function allocate_benchmark_time(venv, research, time)
    venv.benchmark_time = time
    venv.research_benchmarks = {}
    -- here we are basically making a copy of research table to ensure the compilation
    -- process does not yield incorrect results if original table is modified
    for _, tech in ipairs(research) do
        table.insert(
            venv.research_benchmarks,
            {tech_name = tech.tech_name, ingredient_name = tech.ingredient_name}
        )
    end
    -- current benchmark stage
    venv.benchmark_stage = "slow"
    -- index of current research in venv.research_benchmarks
    venv.currently_researching = 0
    -- time in seconds of current_research
    venv.current_research_time = 0
    -- table for storing the results
    venv.benchmark_results = {slow = {}, fast = {}}
end


-------------------------------------------------------------------------------
-- START/STOP COMPILATION
-------------------------------------------------------------------------------

-- checks if given template name is available
local function template_name_available(template_name)
    if not template_name then return false end
    local trimmed_name = template_name:match("^%s*(.-)%s*$") or ""
    if trimmed_name == "" then return false end
    -- checking for matches in compiled templates
    for name, _ in pairs(storage.compiled_templates) do
        if name == trimmed_name then return false end
    end
    -- checking for matches in compiling templates
    for _, venv in pairs(storage.compiling_surfaces) do
        if venv.template_name == trimmed_name then return false end
    end
    return true
end

-- checks if research template is currently compiling
local function research_template_compiling()
    for _, venv in pairs(storage.compiling_surfaces) do
        if venv.surface_type == 2 then return true end
    end
    return false
end

-- Checks if surface can start a compilation
-- @returns bool: true if compilation can be started
-- @return string/nil: reason why compilation was not started if any
function Helper.can_start_compilation(surface_name, template_name)
    -- checking that surface name is provided
    if not surface_name then
        return false, "Surface name is missing"
    end
    -- checking that template name is provided
    if not template_name then
        return false, "Template name is missing"
    end
    -- cheсking that provided surface name corresponds to a valid surface
    local surface = game.get_surface(surface_name)
    if not surface or not surface.valid then
        return false, "Surface is invalid"
    end
    -- checking that provided template name is available
    if not template_name_available(template_name) then
        return false, "Template name unavailable"
    end
    -- checking if provided surface is a virtualization surface
    local vsurface_data = storage.v_surfaces[surface.index]
    if not vsurface_data then
        return false, "Surface is not a virtualization surface"
    end
    -- checking that surface is not compiling
    if storage.compiling_surfaces[surface.index] ~= nil then
        return false, "Surface is already compiling"
    end
    -- checking that we don't start a second research compilation
    if vsurface_data.type == 2 and research_template_compiling() then
        return false, "Another research template is already compiling"
    end
    -- checking that at least one technical research is available
    if vsurface_data.type == 2 and #storage.technical_research == 0 then
        return false, "Can not find technical research for science benchmarks. Report to mod author"
    end
    return true
end


-- Attempts to starts a compilation of a given surface
-- @returns bool: true if compilation was started
-- @return string/nil: reason why compilation was not started if any
function Helper.start_compilation(surface_name, template_name)
    local input_data = {
        template_name = template_name:match("^%s*(.-)%s*$"),
        surface_name = surface_name:match("^%s*(.-)%s*$"),
    }


    -- checking that compilation can be started
    local can_start, reason = Helper.can_start_compilation(surface_name, template_name)
    if not can_start then return can_start, reason end

    -- surface exists and valid (checked above)
    local surface = game.get_surface(surface_name)
    local surface_type = storage.v_surfaces[surface.index].type

    -- switching vsurface state in chunk registry
    chunk_processor.set_compiling_flag(surface.index, true)

    -- creating venv for this compilation effectively starting it
    local trimmed_name = template_name:match("^%s*(.-)%s*$")
    storage.compiling_surfaces[surface.index] = {
        template_name = trimmed_name,
        surface_type = surface_type,
        input = {items={}, fluids={}, energy = 0},
        output = {items={}, fluids={}, energy = 0},
    }
    local venv = storage.compiling_surfaces[surface.index]

    -- now we need to allocate time for compilation
    if surface_type == 2 then
        -- surface type 2 means research surface
        enable_labs(surface)
        allocate_benchmark_time(venv, storage.technical_research, 60)
        venv.compilation_time = #venv.research_benchmarks * venv.benchmark_time
    else
        venv.compilation_time = 0
    end
    -- adding some extra time for lab logistics benchmark
    -- also dafault time for production type
    venv.compilation_time = venv.compilation_time + 120
    venv.remaining_time = venv.compilation_time
    return true
end




-- Checks if surface can start a compilation
-- @returns bool: true if compilation can be started
-- @return string/nil: reason why compilation was not started if any
function Helper.can_start_compilation(surface_name, template_name)
    -- checking that surface name is provided
    if not surface_name then
        return false, "Surface name is missing"
    end
    -- checking that template name is provided
    if not template_name then
        return false, "Template name is missing"
    end
    -- cheсking that provided surface name corresponds to a valid surface
    local surface = game.get_surface(surface_name)
    if not surface or not surface.valid then
        return false, "Surface is invalid"
    end
    -- checking that provided template name is available
    if not template_name_available(template_name) then
        return false, "Template name unavailable"
    end
    -- checking if provided surface is a virtualization surface
    local vsurface_data = storage.v_surfaces[surface.index]
    if not vsurface_data then
        return false, "Surface is not a virtualization surface"
    end
    -- checking that surface is not compiling
    if storage.compiling_surfaces[surface.index] ~= nil then
        return false, "Surface is already compiling"
    end
    -- checking that we don't start a second research compilation
    if vsurface_data.type == 2 and research_template_compiling() then
        return false, "Another research template is already compiling"
    end
    -- checking that at least one technical research is available
    if vsurface_data.type == 2 and #storage.technical_research == 0 then
        return false, "Can not find technical research for science benchmarks. Report to mod author"
    end
    return true
end


-- Stops compilation of a given surface in case surface was invalidated
local function emergency_stop_compilation(surface_id)
    local venv = storage.compiling_surfaces[surface_id]
    if venv.surface_type == 2 then
        -- in case compilation was in "fast" stage, setting lab speed back to normal
        local player_lab_speed = game.forces["player"].laboratory_speed_modifier
        local lab_force = game.forces["lab-technical"]
        lab_force.laboratory_speed_modifier = player_lab_speed
        -- cancel current research
        change_research(venv, 0)
    end
    storage.compiling_surfaces[surface_id] = nil
end

-- Stops compilation of a given surface and deletes assocciated venv
-- @param surface_id int: unique surface identifier
-- @param status bool: true if everything is ok and template should be created
local function stop_compilation(surface_id, status)
    -- checking validity of given sufrace
    local surface = game.get_surface(surface_id)
    if not surface or not surface.valid then
        emergency_stop_compilation(surface_id)
        return
    end

    -- if surface type is research we need to do cleanup
    local venv = storage.compiling_surfaces[surface_id]
    if venv.surface_type == 2 then
        -- disabling labs for given surface
        disable_labs(surface)
        -- setting lab speed for lab force back to normal
        local player_lab_speed = game.forces["player"].laboratory_speed_modifier
        local lab_force = game.forces["lab-technical"]
        lab_force.laboratory_speed_modifier = player_lab_speed
        -- cancel research and store last bit of science production to venv
        change_research(venv, 0)
    end

    -- Creating template if compilation was successfull
    -- TODO: make function to check that surface compilation was valid. Like there are no chests full of trash etc.
    if status then
        create_template(venv, surface, venv.template_name)
    end

    -- switching lab state in chunk registry
    chunk_processor.set_compiling_flag(surface_id, false)
    -- cleaning up the environment
    storage.compiling_surfaces[surface_id] = nil
end

-- Returns compilation progress of a given surface if it's valid and compiling 
-- in the form of 2 integers: time elapsed, time remaining (in seconds). 
-- In all other cases returns nil
function Helper.get_compilation_progress(surface_name)
    local surface = game.get_surface(surface_name)
    if not surface or not surface.valid then return end
    local venv = storage.compiling_surfaces[surface.index]
    if not venv then return end
    local elapsed_time = venv.compilation_time - venv.remaining_time
    return elapsed_time, venv.remaining_time
end

-------------------------------------------------------------------------------
-- MAIN COMPILATION PROCESSOR
-------------------------------------------------------------------------------

-- helper function for time-based processing compilation of type 2 surface.
-- surface is assumed to be valid (checked earlier)
-- @returns bool: true if everything is ok, false is compilation was stopped
local function process_research_surface(venv, surface_id)
    local research_idx, stage = decide_current_research(venv)
    if stage == "fast" then
        -- buffing lab for fast stage to test logistics potential
        game.forces["lab-technical"].laboratory_speed_modifier = 1000
    end
    -- checking if it's time to change current research
    if venv.currently_researching ~= research_idx then
        -- saving science production statistics and changing the research
        local status = change_research(venv, research_idx)
        -- updating benchmark stage after saving science production data
        venv.benchmark_stage = stage
        -- if new research didn't start
        if not status then
            game.print(
                "[Surface compiler] Compilation of template [" .. venv.template_name ..
                "] was terminated most likely due to configuration change. " ..
                "Restarting the compilation should help. If this issue persists, report to mod author"
            )
            stop_compilation(surface_id, false)
            return false
        end
        venv.current_research_time = 1
    else
        venv.current_research_time = venv.current_research_time + 1
    end
    return true
end

-- This function orchestrates surface compilations. It is called every second.
-- Controls current research of lab force. Ends compilations when necessery
function Helper.process_compiling_surfaces()
    for surface_id, venv in pairs(storage.compiling_surfaces) do
        -- we need to check that surface is still valid 
        -- otherwise terminate the compilation
        local surface = game.get_surface(surface_id)
        if surface and surface.valid then
            -- type 2 means research surface
            if venv.surface_type == 2 then
                local status = process_research_surface(venv, surface_id)
                -- if compilation of this surface was stopped, goto next surface
                if not status then goto continue end
            end
            -- decrementing remaining time and stopping the compilation when necessery
            venv.remaining_time = venv.remaining_time - 1
            if venv.remaining_time == 0 then
                stop_compilation(surface_id, true)
            end
        else
            emergency_stop_compilation(surface_id)
        end
        ::continue::
    end
end

---------------------------------------------------------------------------------------
-- DEBUG COMMANDS
---------------------------------------------------------------------------------------

commands.add_command("save_template_data", "Saves all compiled template data to json", function()
    helpers.write_file("compiled_templates.json", serpent.block(storage.compiled_templates), false)
    game.print("Template data saved to compiled_templates.json")
end)

return Helper