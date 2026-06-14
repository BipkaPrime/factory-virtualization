-- This file contains logic regarding special "lab" surfaces that can be created by the mod.
-- They are used to compile Production Templates

-- surface documentation https://lua-api.factorio.com/latest/classes/LuaSurface.html#build_checkerboard

-- Полезные методы: 
-- request_to_generate_chunks(position, radius?) - для генерации чанков при создании поверхности
-- force_generate_chunk_requests() - в комбинации с предыдущим для того, чтобы прервать выполнение скрипта, пока чанки не сгенерируются
-- clear_pollution() - прямо перед началом компиляции
-- get_total_pollution() - для подсчёта загрязнения после завершения компиляции
-- build_checkerboard(area) - заполняет прощадь тайлами лаборатории, для начального сетапа
-- create_global_electric_network() - возможно будет полезно?

-- Полезные атрибуты:
-- name - QoL, переименование поверхностей для удобства игроков
-- generate_with_lab_tiles - при создании перед прогрузкой, чтобы генерировать сразу lab tiles
-- always_day - QoL, при создании поверхности
-- solar_power_multiplier - Баланс, для контроля над солнечными панелями
-- show_clouds - QoL, отключить облака
-- global_electric_network_statistics - при компиляции, для подсчёта энергопотребления


-- forces documantation https://lua-api.factorio.com/latest/classes/LuaForce.html#chart_all
-- Полезные методы:
-- chart_all(surface?) - для прогрузки лабораторных поверхностей
-- get_item_production_statistics(surface) - для подсчёта производства после завершения компиляции
-- get_fluid_production_statistics(surface) - для подсчёта производства после завершения компиляции

-- events documantation https://lua-api.factorio.com/latest/events.html
-- Полезные ивенты: (defines.events)
-- on_marked_for_deconstruction - для обработки сущностей в лабораториях
-- on_marked_for_upgrade - для обработки сущностей в лабораториях
-- on_built_entity - для превращения призраков в здания в лаборатории


local Compiler = {}

-- Ensures the main system storage exists
local function verify_compiler_storage()
    storage.compiler_system = storage.compiler_system or {
        active_labs = {}
    }
end

-- Creates a new lab surface
function Compiler.create_lab_surface(custom_name, size)
    verify_compiler_storage()

    local lab_name = custom_name or ("Virtual Lab #" .. game.tick)
    local map_size = size or 64

    local surface = game.create_surface(lab_name, {
        width = map_size,
        height = map_size,
        starting_area = 0
    })

    -- modifying surface attributes 
    surface.generate_with_lab_tiles = true
    surface.always_day = true
    surface.show_clouds = false

    -- generating and charting surface area
    surface.request_to_generate_chunks({0, 0}, map_size / 2)
    surface.force_generate_chunk_requests()
    game.forces["player"].chart_all(surface)

    storage.compiler_system.active_labs[surface.index] = {
        name = lab_name,
        status = "designing"
    }

    return surface
end

-- Switches the player's camera to the lab
function Compiler.enter_lab_view(player, surface_index)
    local surface = game.get_surface(surface_index)
    if not (surface and surface.valid) then return end
    
    player.set_controller{
        type = defines.controllers.remote,
        surface = surface,
        position = {0, 0}
    }
end

-- Charts all chunks on all lab surfaces
-- It is used on tick. Each lab will be charted every 5 seconds.
function Compiler.chart_all_labs(event)
    if not (storage.compiler_system and storage.compiler_system.active_labs) then return end

    local active_surfaces = {}
    for surface_index, _ in pairs(storage.compiler_system.active_labs) do
        table.insert(active_surfaces, surface_index)
    end

    local count = #active_surfaces
    if count == 0 then return end
    local interval = 300

    -- splitting the load. At most 1 lab surface is charted per tick
    for i, surface_index in ipairs(active_surfaces) do
        if (event.tick + i) % interval == 0 then
            local surface = game.surfaces[surface_index]
            if surface and surface.valid then
                game.forces["player"].chart_all(surface)
            end
            break 
        end
    end
end

-- Gets the current status of a laboratory surface
function Compiler.get_lab_status(surface_index)
    if not (storage.compiler_system and storage.compiler_system.active_labs) then return nil end
    local lab = storage.compiler_system.active_labs[surface_index]
    return lab.status
end

-- Handles anything built inside the laboratory surface
function Compiler.process_built_entity(event)
    if not event.entity or not event.entity.valid then return end

    local status = Compiler.get_lab_status(event.entity.surface.index)
    if status ~= "designing" then return end
    
    local _, revived_entity = event.entity.revive()
    -- reviving all ghosts built in labs. 
    -- IMPORTANT: revive destroys the old ghost entity and creates a new one
    -- if revived ran successfully, we replace the old event.entity with a new one
    if revived_entity then
        event.entity = revived_entity
    else
        -- if revive failed, we invalidate the event.entity basically
        -- stopping it from being processed further down the line
        if not event.entity.valid then
            event.entity = nil
        end
    end
end

-- Checks if a specific surface index is a registered virtual lab
function Compiler.is_lab_surface(surface_index)
    if not (storage.compiler_system and storage.compiler_system.active_labs) then return false end
    return storage.compiler_system.active_labs[surface_index] ~= nil
end


-- ГРАНИЦА РАБОЧЕГО КОДА (ВСЁ, ЧТО НИЖЕ, НУЖНО ПЕРЕДЕЛЫВАТЬ)
-- =======================================================================================================================================
-- Toggles lab status between "designing" and "compiling" modes using native engine locks
-- ЭТУ ФУНКЦИЮ НУЖНО ПЕРЕДЕЛАТЬ.
-- Идея: Вместо того, чтобы мудрить с запретами на строительство и прочее, поступим проще
-- Будем отслеживать все действия игрока, которые могут изменить состояние поверхности
-- Если такое действие обнаружено, компиляция отменяется
function Compiler.set_lab_status(surface_index, new_status)
    if not (storage.compiler_system and storage.compiler_system.active_labs) then return end
    local lab = storage.compiler_system.active_labs[surface_index]
    if not lab then return end
    
    local surface = game.get_surface(surface_index)
    if not (surface and surface.valid) then return end
    
    lab.status = new_status
    
    if new_status == "compiling" then
        -- NATIVE ENGINE LOCK: Disable ghost-building and blueprinting on this surface entirely!
        -- ТАКОГО МЕТОДА НЕ СУЩЕСТВУЕТ, ГАЛЮЦИНАЦИЯ
        surface.generate_blueprints = false
        
        -- PRO SAFETY NET: Temporarily flip player structures to Neutral force
        -- ТОЖЕ ОЧ СТРАННЫЙ ХОД. ПОПАХИВАЕТ КАКОЙ-ТО ХРЕНЬЮ.
        -- upd. ДА. крашит игру при попытке построить что-то
        -- This natively blocks mining, changing module items, or opening machine GUIs during tests
        for _, entity in pairs(surface.find_entities()) do
            if entity.valid and entity.force.name == "player" then
                entity.force = "neutral"
            end
        end
        
    elseif new_status == "designing" then
        -- RESTORE WORKSPACE: Allow player to remote-build and place ghosts again
        surface.generate_blueprints = true
        
        -- Restore original ownership back to player force so they can edit the factories again
        for _, entity in pairs(surface.find_entities()) do
            if entity.valid and entity.force.name == "neutral" then
                entity.force = "player"
            end
        end
    end
end


-- Completely deletes the lab from engine memory (Manual wipe via GUI action only)
function Compiler.destroy_lab_surface(surface_index)
    if not (storage.compiler_system and storage.compiler_system.active_labs) then return end
    
    -- Print warning to players currently observing this surface via remote view
    for _, player in pairs(game.players) do
        if player.render_mode == defines.render_mode.game and player.surface.index == surface_index then
            player.print("[Compiler] This virtual laboratory was permanently deleted by a player.")
        end
    end
    
    local surface = game.get_surface(surface_index)
    if surface and surface.valid then
        game.delete_surface(surface)
    end
    
    storage.compiler_system.active_labs[surface_index] = nil
end



return Compiler