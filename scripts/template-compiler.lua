-- This file contains is used to compile production templates.

local lab_chunk_manager = require("scripts.lab-chunks-registry")

local Helper = {}

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

-- Checks if given surface_id can start a compilation
-- @returns bool: true if compilation can be started
function Helper.compilation_startup_check(surface_id)
    -- checking if provided surface is a virtualization surface
    if not storage.lab_surfaces[surface_id] then
        game.print("Compilation NOT started. Given surface is not a virtualization surface")
        return
    end

    -- checking if given surface is already compiling
    if storage.compiling_surfaces[surface_id] ~= nil then
        game.print("Compilation NOT started. Surface is already compiling")
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
    if not surface or not surface.valid then
        game.print("Compilation NOT started. Given surface is invalid")
        return
    end

    -- checking if the given surface has labs
    local labs_present = surface.count_entities_filtered({type = "lab", limit = 1}) > 0

    -- if lab count is not 0 and there are labs enabled somewhere else
    if labs_present and labs_enabled then
        game.print("Compilation NOT started. Only one compiling surface is allowed to contain labs")
        return
    end

    return true, labs_present
end

-- Starts compilation of a given surface
-- @param template_name str: unique template identifier specified by the player
function Helper.start_compilation(surface_id, template_name)
    local check, labs_present = Helper.compilation_startup_check(surface_id)
    if not check then return end

    -- enabling all labs for given surface if it has any
    local surface = game.get_surface(surface_id)
    if labs_present then
        set_labs_state(surface, true)
    end

    -- creating venv for this compilation effectively starting the compilation
    storage.compiling_surfaces[surface_id] = {
        template_name = template_name, -- unique template identifier specified by the player
        has_labs = labs_present, -- true if compiling surface has labs
        input = {items={}, fluids={}, energy = 0},
        output = {items={}, fluids={}, energy = 0},
    }

    -- cleaning pollution statistics for given surface
    surface.pollution_statistics.clear()

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
        -- game.print("science pack: " .. ingredient)
        -- game.print("operation time: " .. venv.current_research_time)
        -- game.print("produced points: " .. tostring(points_produced))

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

-- Helper function in calculating building cost of a surface
local function add_to_cost(total_cost, name, count, quality)
    quality = quality or "normal"
    if not total_cost[name] then
        total_cost[name] = {}
    end
    total_cost[name][quality] = (total_cost[name][quality] or 0) + count
end

-- Function to calculate the building cost of a given surface
local function get_building_cost(surface)
    local total_cost = {}

    -- searching for all entities on a surface
    local entities = surface.find_entities()

    for _, entity in ipairs(entities) do
        -- counting only valid entities excluding ghosts
        if entity and entity.valid and entity.type ~= "entity-ghost" then
            local build_cost = entity.prototype.items_to_place_this
            -- checking if entity can be built
            if build_cost then
                local entity_quality = "normal"
                if entity_quality then
                    entity_quality = entity.quality.name
                end

                add_to_cost(total_cost, build_cost[1].name, build_cost[1].count, entity_quality)

                -- add any inserted modules inside the building
                local module_inv = entity.get_module_inventory()
                -- checking if entity has a module inventory and it's not empty
                if module_inv and not module_inv.is_empty() then
                    -- get_contents() returns an array of {name, count, quality}
                    for _, item in ipairs(module_inv.get_contents()) do
                        add_to_cost(total_cost, item.name, item.count, item.quality)
                    end
                end
            end
        end
    end
    return total_cost
end

-- Creates compiled production template 
local function create_production_template(venv, surface, template_name)
    local template_data = {}

    -- gathering science production capability
    -- local science_packs = {}
    if venv.has_labs then
        -- slow stage. labs potential
        for ingredient, data in pairs(venv.benchmark_results.slow) do
            template_data.science = template_data.science or {}
            template_data.science.labs_potential = template_data.science.labs_potential or {}
            template_data.science.labs_potential[ingredient] = data.points / data.time
            -- science_packs[ingredient] = true
        end

        -- fast stage. logistics potential
        for ingredient, data in pairs(venv.benchmark_results.fast) do
            template_data.science = template_data.science or {}
            template_data.science.logistics_potential = template_data.science.logistics_potential or {}
            template_data.science.logistics_potential[ingredient] = data.points / data.time
            -- science_packs[ingredient] = true
        end
    end

    -- gathering item inputs
    for item_name, q_counts in pairs(venv.input.items) do
        -- creating categories only when required
        template_data.input = template_data.input or {}
        template_data.input.items = template_data.input.items or {}
        -- going through counts and qualities under the same item name
        for quality, count in pairs(q_counts) do
            if count > 0 then
                template_data.input.items[item_name] = template_data.input.items[item_name] or {}

                template_data.input.items[item_name][quality] = count / venv.compilation_time
            end
        end
    end

    -- gathering item outputs
    for item_name, q_counts in pairs(venv.output.items) do
        -- creating categories only when required
        template_data.output = template_data.output or {}
        template_data.output.items = template_data.output.items or {}
        -- going through counts and qualities under the same item name
        for quality, count in pairs(q_counts) do
            if count > 0 then
                template_data.output.items[item_name] = template_data.output.items[item_name] or {}
                template_data.output.items[item_name][quality] = count / venv.compilation_time
            end
        end
    end

    -- gathering fluid inputs
    for fluid_name, amount in pairs(venv.input.fluids) do
        if amount > 0 then
            -- creating categories only when required
            template_data.input = template_data.input or {}
            template_data.input.fluids = template_data.input.fluids or {}
            template_data.input.fluids[fluid_name] = amount / venv.compilation_time
        end
    end

    -- gathering fluid ouputs
    for fluid_name, amount in pairs(venv.output.fluids) do
        if amount > 0 then
            -- creating categories only when required
            template_data.output = template_data.output or {}
            template_data.output.fluids = template_data.output.fluids or {}
            template_data.output.fluids[fluid_name] = amount / venv.compilation_time
        end
    end

    -- gathering energy input
    if venv.input.energy > 0 then
        -- creating categories only when required
        template_data.input = template_data.input or {}
        template_data.input.energy = venv.input.energy / venv.compilation_time
    end

    -- gathering energy output
    if venv.output.energy > 0 then
        -- creating categories only when required
        template_data.output = template_data.output or {}
        template_data.output.energy = venv.output.energy / venv.compilation_time
    end

    -- gathering building costs
    local cost = get_building_cost(surface)
    -- checking if cost is not empty
    if next(cost) ~= nil then
        template_data.building_cost = cost
    end

    -- gathering surface area
    local settings = surface.map_gen_settings
    template_data.area = settings.width * settings.height

    -- gathering pollution
    local pollution_counts = surface.pollution_statistics.input_counts
    local total = 0
    for _, count in pairs(pollution_counts) do
        total = total + count
    end
    if total > 0 then
        template_data.pollution = total / venv.compilation_time
    end

    storage.compiled_templates[template_name] = template_data
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
    
    

    -- Adding compiled template data to template storage
    if status then
       create_production_template(venv, surface, venv.template_name) 
    end

    -- debug placeholder
    game.print("Surface compiled. Status:" .. tostring(status))
    --helpers.write_file('compilation_result.json', "Inputs:" .. serpent.block(venv.input) .. "\n", true)
    --helpers.write_file('compilation_result.json', "Outputs:" .. serpent.block(venv.output) .. "\n", true)
    --if venv.has_labs then
        --helpers.write_file('compilation_result.json', "Science production:" .. serpent.block(venv.benchmark_results) .. "\n", true)
    --end
    
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

    local template_name = "Unspecified"
    if command.parameter then
        template_name = command.parameter
    end

    Helper.start_compilation(surface_idx, template_name)
end)

commands.add_command("save_template_data", "Saves all compiled template data to json", function(command)
    helpers.write_file("compiled_templates.json", serpent.block(storage.compiled_templates), false)
    game.print("Template data saved to compiled_templates.json")
end)

commands.add_command("surface_cost", "Prints building cost of a surface player is looking at", function(command)
    local player = game.get_player(command.player_index)
    local surface_idx = player.surface_index
    if not storage.lab_surfaces[surface_idx] then
        game.print("This is not a lab surface")
        return
    end

    game.print(serpent.block(get_building_cost(surface_idx)))
end)


return Helper