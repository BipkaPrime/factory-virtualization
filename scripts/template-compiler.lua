-- This file contains is used to compile production templates.

-- When a surface compilation start we need to somehow tell udlinks
-- with lab surface io checkbox to start recording how much stuff outputs spawn in
-- and how much inputs are getting.
-- For this we need a virtual environment

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

    -- key: surface id, value:table containing virtual_environments
    -- virtual_environments table: keys: compiled_template name, value: table describing venv
    -- like stored energy, stored resources, stored finished product, etc.
    storage.virtual_environments = storage.virtual_environments or {}

    -- key: surface_id, value = lab virtual environment that will count
    -- inputs and outputs of the system
    storage.compiling_surfaces = storage.compiling_surfaces or {}
end

-- Starts compilation of a given surface
function Helper.start_compilation(surface_id)
    -- creating venv for this compilation
    storage.compiling_surfaces[surface_id] = {
        compilation_time = 60, -- compilation time in seconds
        remaining_time = 60,
        input = {items={}, fluids={}, energy = 0},
        output = {items={}, fluids={}, energy = 0, science = {}},
    }
    -- switching lab state in chunk registry
    lab_chunk_manager.switch_lab_state(surface_id, "compiling")
end

-- Stops compilation of a given surface and deletes assocciated venv
-- @param surface_id int: unique surface identifier
-- @param status bool: true if successful
function Helper.stop_compilation(surface_id, status)

    -- debug placeholder TODO: make real logic
    game.print(serpent.block(storage.compiling_surfaces[surface_id]))
    game.print("surface compiled, status:" .. tostring(status))

    -- switching lab state in chunk registry
    lab_chunk_manager.switch_lab_state(surface_id, "designing")
    -- cleaning up the environment
    storage.compiling_surfaces[surface_id] = nil
end

-- For now decrements remaining time of each compilation by 1 each second
-- and stops the compilation when time is over
function Helper.process_compiling_surfaces()
    for surface_id, venv in pairs(storage.compiling_surfaces) do
        venv.remaining_time = venv.remaining_time - 1
        if venv.remaining_time == 0 then
            Helper.stop_compilation(surface_id)
        end
    end
end

-- `/compile` -> Starts the compilation of a lab surface player is looking at
commands.add_command("compile", "Starts the compilation of a lab surface player is looking at", function(command)
    local player = game.get_player(command.player_index)
    local surface_idx = player.surface_index
    if not storage.lab_surfaces[surface_idx] then
        game.print("This is not a lab surface")
    end
    Helper.start_compilation(surface_idx)
    game.print("Compilation started")
end)


return Helper