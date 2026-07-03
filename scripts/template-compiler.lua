-- This file is used to compile production and research templates.

-- To compile a template, surface and template names must be provided.
-- When compilation starts, virtual environment is created in storage.compiling_surfaces[surface_index]

--[[
-------------------------------------------------------------------------------
VIRTUAL ENVIRONMENT INFO
-------------------------------------------------------------------------------
template_name string: trimmed template name provided by player
surface_type int 1/2: surface type. 1 means production, 2 means science
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

Additionaly if surface_type == 2 venv will also contain following keys:
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
-------------------------------------------------------------------------------
TEMPLATE INFO
-------------------------------------------------------------------------------
Once remaining time of a given template runs out and there are no problems,
template is created from venv. Venv itself is deleted.
IMPORTANT: keys are only created when required. For example, if venv didn't have
any inputs greater than 0, key "input" will not be created in template.
Compiled template can have following keys:
type int 1/2: 1 means production, 2 means science
building_cost table: contains items needed for construction of this template.
    Same 2-level structure as item inputs/outputs.
area integer: area in tiles of this template
pollution float: pollution per second
input table: {items = {}, fluids = {}, energy = 0} inputs per second.
output table: {items = {}, fluids = {}, energy = 0} outputs per second.
science table: {labs_potential = {}, logistics_potential = {}, points_per_item = {}}.
    All inner tables are hashmaps. For all tables, the key is ingredient name.
    For labs_potential and logistics_potential value is research points per second.
    For points_per_item value is number of research points produced per 1 spent item.
    These values are calculated for normal quality items.
--]]

local chunk_registry = require("scripts.vsurface-chunk-registry")

local Helper = {}

-- Enables/disables all labs on a given surface.
-- @param enabled bool: true for labs to be enabled
local function set_labs_state(surface, enabled)
    if not surface or not surface.valid then return end
    local labs = surface.find_entities_filtered{type = "lab"}
    for _, lab in ipairs(labs) do
        if lab and lab.valid then
            lab.disabled_by_script = not enabled
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

-- Helps in template creation. Calculates input/output flow of
-- items/fluids/energy per second for a given venv and saves results
-- @param template_data table: results will be added here
-- @param venv table: contains data about compiling surface
-- @param io_category "input"/"output": category to process
-- @param type "items"/"fluids"/"energy": type to process
local function collect_io_flow(template_data, venv, io_category, type)
    local venv_section = venv[io_category][type]
    if type == "energy" then
        if venv_section > 0 then
            template_data[io_category] = template_data[io_category] or {}
            template_data[io_category][type] = venv_section / venv.compilation_time
        end
    else
        -- if venv section is empty, we can return
        if next(venv_section) == nil then return end
        -- otherwise we create a template section
        template_data[io_category] = template_data[io_category] or {}
        template_data[io_category][type] = template_data[io_category][type] or {}
        local template_section = template_data[io_category][type]
        if type == "fluids" then
            for fluid_name, amount in pairs(venv_section) do
                template_section[fluid_name] = amount / venv.compilation_time
            end
        else -- type == "items"
            for item_name, counts in pairs(venv_section) do
                template_section[item_name] = {}
                -- going through counts and qualities under the same item name
                for quality, count in pairs(counts) do
                    template_section[item_name][quality] = count / venv.compilation_time
                end
            end
        end
    end
end

-- Helps in template creation. Calculates science potential of given section
-- @param section "slow"/"fast"
local section_name_map = {slow = "labs_potential", fast = "logistics_potential"}
local function collect_science_generation(template_data, venv, section)
    local venv_section = venv.benchmark_results[section]
    -- checking that section is not empty
    if next(venv_section) == nil then return end
    -- creating section in template data
    local t_section = section_name_map[section]
    template_data.science = template_data.science or {}
    template_data.science[t_section] = {}
    local template_section = template_data.science[t_section]
    for ingredient, data in pairs(venv_section) do
        template_section[ingredient] = data.points / data.time
    end
end

-- Helps in template creation. Makes sure that sets of ingredient items in 
-- labs_potential and logistics_potentials match.
local function validate_science_generation(template_data)
    if not template_data.science then return end
    local labs_potential = template_data.science.labs_potential
    local logistics_potential = template_data.science.logistics_potential
    if not labs_potential or not logistics_potential then
        template_data.science = nil
        return
    end
    -- deleting items that are not present in logistics
    for item, _ in pairs(labs_potential) do
        if not logistics_potential[item] then
            labs_potential[item] = nil
        end
    end
    -- deleting items that are not present in labs
    for item, _ in pairs(logistics_potential) do
        if not labs_potential[item] then
            logistics_potential[item] = nil
        end
    end
    -- if nothing is left, erasing science section
    if not next(labs_potential) then
        template_data.science = nil
    end
end

-- Helps in template creation. Calculates research points per item.
-- Must be called after collecting science points generation.
local sections = {"slow", "fast"}
local function collect_science_ppi(template_data, venv)
    if not template_data.science then return end
    local pack_stats = {}
    -- going through both slow and fast sections
    for _, section in ipairs(sections) do
        -- getting to the right section
        local venv_section = venv.benchmark_results[section]
        for ingredient, data in pairs(venv_section) do
            -- collecting sum of points and time for each ingredient
            pack_stats[ingredient] = pack_stats[ingredient] or {points = 0, time = 0}
            pack_stats[ingredient].points = pack_stats[ingredient].points + data.points
            pack_stats[ingredient].time = pack_stats[ingredient].time + data.time
        end
    end
    -- calculating research points per item 
    template_data.science.points_per_item = {}
    for ingredient, data in pairs(pack_stats) do
        -- getting input data of current ingredient
        local ingredient_inputs = venv.input.items[ingredient]
        if ingredient_inputs then
            -- TODO: add support for quality research items
            local total_count = 0
            for quality, count in pairs(ingredient_inputs) do
                total_count = total_count + count
            end
            template_data.science.points_per_item[ingredient] = data.points / total_count
        else
            -- if ingredient not found, removing its science production
            template_data.science.labs_potential[ingredient] = nil
            template_data.science.logistics_potential[ingredient] = nil
        end
    end
    -- deleting points per item table if it's empty
    if next(template_data.science.points_per_item) == nil then
        template_data.science.points_per_item = nil
    end
end

-- Helps in template creation. Collects pollution per second.
local function collect_pollution(template_data, venv, surface)
    local pollution_counts = surface.pollution_statistics.input_counts
    local total = 0
    for _, count in pairs(pollution_counts) do
        total = total + count
    end
    if total > 0 then
        template_data.pollution = total / venv.compilation_time
    end
end

-- Helps in calculation of building cost of a surface
local function add_to_cost(total_cost, name, count, quality)
    total_cost[name] = total_cost[name] or {}
    total_cost[name][quality] = (total_cost[name][quality] or 0) + count
end

-- Helper in template creation, collects building cost of a surface.
-- Surface is assumed to be valid.
local function collect_building_cost(template_data, surface)
    local total_cost = {}
    -- getting array[LuaEntity] containing all entities on given surface
    local entities = surface.find_entities()
    for _, entity in ipairs(entities) do
        -- counting only valid entities excluding ghosts
        if entity and entity.valid and entity.type ~= "entity-ghost" then
            -- getting array[ItemToPlace] or nil if entity can't be built
            local build_cost = entity.prototype.items_to_place_this
            if build_cost then
                -- getting LuaQualityPrototype of entity
                local quality = entity.quality
                add_to_cost(total_cost, build_cost[1].name, build_cost[1].count, quality.name)
                -- getting LuaInventory or nil if it does not exist
                local module_inv = entity.get_module_inventory()
                -- checking if entity has a module inventory and it's not empty
                if module_inv and not module_inv.is_empty() then
                    -- get_contents() returns an array of {name, count, quality_name}
                    for _, item in ipairs(module_inv.get_contents()) do
                        add_to_cost(total_cost, item.name, item.count, item.quality)
                    end
                end
            end
        end
    end
    -- if total cost is not empty, save it to template data
    if next(total_cost) then
        template_data.building_cost = total_cost
    end
end

-- Creates compiled production template. Surface is assumed to be valid.
local function create_production_template(venv, surface, template_name)
    local template_data = {type = venv.surface_type}
    collect_building_cost(template_data, surface)
    collect_pollution(template_data, venv, surface)
    -- gathering surface area
    local settings = surface.map_gen_settings
    template_data.area = settings.width * settings.height
    -- gathering inputs 
    collect_io_flow(template_data, venv, "input", "items")
    collect_io_flow(template_data, venv, "input", "fluids")
    collect_io_flow(template_data, venv, "input", "energy")
    if venv.surface_type == 2 then
        -- gathering science generation and ppi
        collect_science_generation(template_data, venv, "slow")
        collect_science_generation(template_data, venv, "fast")
        validate_science_generation(template_data)
        collect_science_ppi(template_data, venv)
    else
        -- gathering outputs
        collect_io_flow(template_data, venv, "output", "items")
        collect_io_flow(template_data, venv, "output", "fluids")
        collect_io_flow(template_data, venv, "output", "energy")
    end
    storage.compiled_templates[template_name] = template_data
end

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
    -- checking that compilation can be started
    local can_start, reason = Helper.can_start_compilation(surface_name, template_name)
    if not can_start then return can_start, reason end

    -- surface exists and valid (checked above)
    local surface = game.get_surface(surface_name)
    local surface_type = storage.v_surfaces[surface.index].type

    -- cleaning pollution statistics for given surface
    surface.pollution_statistics.clear()

    -- switching vsurface state in chunk registry
    chunk_registry.set_compiling_flag(surface.index, true)

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
        set_labs_state(surface, true)
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

-- Changes research for lab force given virtual environment. 
-- Saves generated science points for current research to venv.
-- @param new_index int: index of new research (in research_benchmarks)
--      or 0 to cancel the current research and just save the stats.     
-- @returns bool: true if everything ok.
local function change_research(venv, new_index)
    game.print("changing research")
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
        set_labs_state(surface, false)
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
        create_production_template(venv, surface, venv.template_name)
    end

    -- switching lab state in chunk registry
    chunk_registry.set_compiling_flag(surface_id, false)
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