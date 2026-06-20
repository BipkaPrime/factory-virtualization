-- This file contains is used to compile production templates.


local lab_chunk_manager = require("scripts.lab-chunks-registry")


local Helper = {}


function Helper.storage_init()
    -- keys are template names, values are templates
    storage.compiled_templates = storage.compiled_templates or {}

    -- placeholder 
    storage.compiled_templates["iron plates"] = {}
    storage.compiled_templates["electronic circuits"] = {}
    storage.compiled_templates["compiled_template3"] = {}
    storage.compiled_templates["abobus555"] = {}
    storage.compiled_templates["coal 100m/sec"] = {}
    storage.compiled_templates["compiled_template77"] = {}
    storage.compiled_templates["uuuuuuuu"] = {}
    storage.compiled_templates["plastic 100m/sec"] = {}
    storage.compiled_templates["----asdfafkl;lasf"] = {}

    -- key: surface_id, value = lab virtual environment
    storage.compiling_surfaces = storage.compiling_surfaces or {}
end

-- Enables/disables all labs on a a given surface. Surface must be valid
-- @param enabled bool: true for labs to be enabled
local function set_labs_state(surface, enabled)
    local labs = surface.find_entities_filtered{type = "lab"}
    for _, lab in ipairs(labs) do
        if lab and lab.valid then
            lab.disabled_by_script = not enabled
        end
    end
end

-- Allocates time for benchmarking research "production".
-- @param venv table: has data about compiling surface
-- @param research array: contains tables describing each research.
-- each table must contain keys: "tech_name" and "ingredient_name"
-- @param time int: seconds for each benchmark
local function allocate_benchmark_time(venv, research, time)
    venv.benchmark_time = time
    venv.research_benchmarks = {}
    -- here we are basically making a copy of research table to ensure the compilation
    -- process does not yield incorrect results if research table is modified
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

-- Starts compilation of a given surface
function Helper.start_compilation(surface_id)
    -- checking if given surface is already compiling
    if storage.compiling_surfaces[surface_id] ~= nil then
        game.print("Compilation NOT started. This surface is already compiling")
        return
    end

    -- checking if there are any compiling surfaces with labs
    local labs_enabled = false
    for _, venv in pairs(storage.compiling_surfaces) do
        if venv.has_labs == true then
            labs_enabled = true
        end
    end

    -- checking validity of given sufrace
    local surface = game.get_surface(surface_id)
    if not surface or not surface.valid then return end

    -- checking if the given surface has labs
    local labs_present = surface.count_entities_filtered({type = "lab", limit = 1}) > 0

    -- if lab count is not 0 and there are labs enabled somewhere else
    if labs_present and labs_enabled then
        game.print("Compilation NOT started. Only one compiling surface is allowed to contain labs")
        return
    end

    -- enabling all labs for given surface if it has any
    if labs_present then
        set_labs_state(surface, true)
    end

    -- creating venv for this compilation effectively starting the compilation
    storage.compiling_surfaces[surface_id] = {
        has_labs = labs_present, -- true if compiling surface has labs
        input = {items={}, fluids={}, energy = 0},
        output = {items={}, fluids={}, energy = 0},
    }

    local venv = storage.compiling_surfaces[surface_id]
    -- if surface has labs we need to allocate time for benchmarking each science pack
    if venv.has_labs then
        allocate_benchmark_time(venv, storage.technical_research, 60)
        -- calculating the compilation time
        venv.compilation_time = #venv.research_benchmarks * venv.benchmark_time
    else
        venv.compilation_time = 0
    end
    -- adding some extra time for lab logistics benchmark
    -- also minimum time if there are no labs on surface
    venv.compilation_time = venv.compilation_time + 120
    venv.remaining_time = venv.compilation_time
    
    -- switching lab state in chunk registry
    lab_chunk_manager.switch_lab_state(surface_id, "compiling")
    game.print("Compilation started")
end

-- Changes research for lab force given virtual environment.
-- Saves generated science points for current research to venv.
-- @returns bool: true if everything ok.
local function change_research(venv, new_index)
    local current_idx = venv.currently_researching
    local lab_force = game.forces["lab-technical"]
    local prod_stat = lab_force.get_item_production_statistics("nauvis")
    
    -- checking if something is currently selected
    if current_idx > 0 then
        -- getting number of science points produced
        local points_produced = prod_stat.get_input_count("science")
        -- getting current research ingredient
        local ingredient = venv.research_benchmarks[current_idx]["ingredient_name"]

        -- debug placeholder
        game.print("science pack: " .. ingredient)
        game.print("operation time: " .. venv.current_research_time)
        game.print("produced points: " .. tostring(points_produced))

        -- saving produced points to venv
        if points_produced > 0 then
            local curr_stage = venv.benchmark_results[venv.benchmark_stage]
            curr_stage[ingredient] = curr_stage[ingredient] or {points = 0, time = 0}
            curr_stage[ingredient].points = curr_stage[ingredient].points + points_produced
            curr_stage[ingredient].time = curr_stage[ingredient].time + venv.current_research_time
        end
    end

    lab_force.cancel_current_research()

    -- staring new research
    local status = true
    venv.currently_researching = new_index
    if new_index > 0 then
        status = lab_force.add_research(venv.research_benchmarks[new_index].tech_name)
    end
    
    -- clearing all science production statistics
    prod_stat.clear()
    return status
end

-- Stops compilation of a given surface and deletes assocciated venv
-- @param surface_id int: unique surface identifier
-- @param status bool: true if successful
local function stop_compilation(surface_id, status)
    -- checking validity of given sufrace
    local surface = game.get_surface(surface_id)
    if not surface or not surface.valid then return end

    local venv = storage.compiling_surfaces[surface_id]

    -- if simulation has labs we need to do cleanup
    if venv.has_labs then
        -- disabling labs for given surface
        set_labs_state(surface, false)
        -- setting lab speed for lab force back to normal
        local player_lab_speed = game.forces["player"].laboratory_speed_modifier
        local lab_force = game.forces["lab-technical"]
        lab_force.laboratory_speed_modifier = player_lab_speed
        -- effectively cancels lab force research and stores last bit of
        -- science production to venv
        change_research(venv, 0)
    end
    
    -- TODO: make production template if compilation is successful
    -- TODO: make function that collects building cost of a lab surface
    -- TODO: make function to check that surface compilation was valid. Like there are no chests full of trash etc.


    -- debug placeholder
    game.print("Surface compiled. Status:" .. tostring(status))
    helpers.write_file('compilation_result.json', "Inputs:" .. serpent.block(venv.input) .. "\n", true)
    helpers.write_file('compilation_result.json', "Outputs:" .. serpent.block(venv.output) .. "\n", true)
    if venv.has_labs then
        helpers.write_file('compilation_result.json', "Science production:" .. serpent.block(venv.benchmark_results) .. "\n", true)
    end
    
    -- switching lab state in chunk registry
    lab_chunk_manager.switch_lab_state(surface_id, "designing")
    -- cleaning up the environment
    storage.compiling_surfaces[surface_id] = nil
end

-- Decides current research index for benchmarking given venv
-- Compilation consists of 2 stages:
-- First stage is for slow benchmarks (venv.benchmark_time seconds for each research)
-- Second stage is for testing logistics: labs get speed boost (1 second for each research)
local function decide_current_research(venv)
    local elapsed_time = venv.compilation_time - venv.remaining_time
    local research_count = #venv.research_benchmarks

    -- checking if we are in slow or fast stage
    if elapsed_time < research_count * venv.benchmark_time then
        -- slow stage
        return math.floor(elapsed_time / venv.benchmark_time) + 1, "slow"
    else
        -- fast stage
        return elapsed_time % research_count + 1, "fast"
    end
end

-- This function orchestrates surface compilations. It is called every second.
-- Controls current research of lab force. Ends compilations when necessery
function Helper.process_compiling_surfaces()
    for surface_id, venv in pairs(storage.compiling_surfaces) do
        if venv.has_labs then
            local research_idx, stage = decide_current_research(venv)

            -- for the fast stage we want to test logistics throughput
            if stage == "fast" then
                -- buffing lab speed will result in logistics becoming a bottleneck
                game.forces["lab-technical"].laboratory_speed_modifier = 1000
            end

            -- checking if it's time to change the research
            if venv.currently_researching ~= research_idx then
                -- saving science production statistics and changing the research
                local status = change_research(venv, research_idx)
                -- updating benchmark stage after saving science production data
                venv.benchmark_stage = stage
                -- if new research didn't start
                if not status then
                    stop_compilation(surface_id, false)
                    game.print(
                        "Compilation was aborted most likely due to configuration change. Restarting the compilation should help."
                    )
                end
                venv.current_research_time = 1
            else
                venv.current_research_time = venv.current_research_time + 1
            end
        end
        
        -- decrementing remaining time and stopping the compilation when necessery
        venv.remaining_time = venv.remaining_time - 1
        if venv.remaining_time == 0 then
            stop_compilation(surface_id, true)
        end
    end
end

-- `/compile` -> Starts the compilation of a lab surface player is looking at
commands.add_command("compile", "Starts the compilation of a lab surface player is looking at", function(command)
    local player = game.get_player(command.player_index)
    local surface_idx = player.surface_index
    if not storage.lab_surfaces[surface_idx] then
        game.print("This is not a lab surface")
        return
    end
    Helper.start_compilation(surface_idx)
end)


return Helper