--[[
This mod allows players to create special "virtualization surfaces".
Vsurface is basically a sandbox where player can build anything for free.
Vsurface is created as a sterile environment generated with lab tiles.

To compile a template player has to build a factory on a vsurface and then
start compilation of that surface. Once compilation is done, template will be created.

To know which surfaces are "vsurfaces" and which are not, on creation they are stored at
storage.vsurfaces with all needed data. For that table key is surface_index and value is
a table with vsurface information.
storage.vsurface[surface_index] = {
    surface_index integer, unique surface identifier (same as key)
    width = integer, surface width in tiles
    height = integer, surface height in tiles
    research_surface = boolean, true if this surface can produce research
}

This vsurface manager handles create/delete/lookup requests. It also handles various
requests of venv processor and template compiler.
--]]

local ChunkProcessor = require("src.world.vsurface-chunk-processor")

local VSurfaceManager = {}


---@param surface_id number|string|LuaSurface|nil surface identification
---@return LuaSurface|nil
function VSurfaceManager.get_surface(surface_id)
    if not surface_id then return end
    local surface
    if type(surface_id) == "number" or type(surface_id) == "string" then
        surface = game.get_surface(surface_id)
    else
        surface = surface_id
    end
    return surface
end

-------------------------------------------------------------------------------
-- VSURFACE CREATION/DELETION/LOOKUP
-------------------------------------------------------------------------------

---Checks if a vsurface with specified parameters can be created
---@param name string|nil name of the surface
---@param width integer|nil width of the surface
---@param height integer|nil height of the surface
---@return boolean status true if surface can be created
---@return string|nil reason why surface cannot be created if any
function VSurfaceManager.can_create_vsurface(name, width, height)
    -- checking that name is not empty
    if not name or not name:match("%S") then
        return false, "Surface name is missing"
    end
    -- checking if surface or planet with given name already exists
    if game.get_surface(name) ~= nil or game.planets[name] ~= nil then
        return false, "Surface name not available"
    end
    -- validating surface width
    if not width or type(width) ~= "number" or width < 1 or width > 512 then
        return false, "Surface width must be an integer in the range [1, 512]"
    end
    -- validating surface height
    if not height or type(height) ~= "number" or height < 1 or height > 512 then
        return false, "Surface height must be an integer in the range [1, 512]"
    end
    return true
end

---Creates a new virtualization surface
---@param player LuaPlayer|nil reference to player who requested surface creation
---@param name string|nil name of new surface
---@param width number|nil width of new surface
---@param height number|nil height of new surface
---@param research_surface boolean|nil true if surface can produce research
---@return boolean true if surface was created
---@return string|nil reason why surface was not created if any
function VSurfaceManager.create_vsurface(player, name, width, height, research_surface)
    -- checking that surface can be created
    local status, reason = VSurfaceManager.can_create_vsurface(name, width, height)
    if not status then return status, reason end

    ---@cast name string
    ---@cast width number
    ---@cast height number

    -- creating surface with specified properties
    local trimmed_name = name:match("^%s*(.-)%s*$")
    local surface = game.create_surface(trimmed_name, {
        width = width,
        height = height,
        starting_area = 0
    })
    -- making sure surface was created and it's valid
    if not surface or not surface.valid then
        return false, "Could not create surface"
    end

    local chunk_radius = math.ceil(math.max(width, height) / 64)
    surface.request_to_generate_chunks({0, 0}, chunk_radius)

    -- modifying surface attributes
    surface.generate_with_lab_tiles = true
    surface.always_day = true
    surface.show_clouds = false
    surface.ignore_surface_conditions = true

    -- adding created surface table with vsurfaces
    storage.vsurfaces[surface.index] = {
        surface_index = surface.index,
        width = width,
        height = height,
        research_surface = not not research_surface
    }

    -- adding surface to chunk registry
    ChunkProcessor.register_surface(surface)

    -- move player's camera to created surface
    if player and player.valid then
        player.set_controller{
            type = defines.controllers.remote,
            surface = surface,
            position = {0, 0}
        }
    end

    return true
end

---Gets vsurface data from storage
---@param surface_id string|integer|LuaSurface|nil surface identification
---@return table|nil data
function VSurfaceManager.get_vsurface_data(surface_id)
    if not surface_id then return end

    -- if index is passed we can retrieve data easily
    if type(surface_id) == "number" then
        return storage.vsurfaces[surface_id]
    end

    -- getting LuaSurface object
    ---@cast surface_id LuaSurface|string
    local surface
    if type(surface_id) == "string" then
        surface = game.get_surface(surface_id)
    else
        surface = surface_id
    end

    -- checking that surface is found and valid
    if not surface or not surface.valid then return end
    return storage.vsurfaces[surface.index]
end

---Collects names of all existing valid vsurfaces
---@return string[]
function VSurfaceManager.get_all_vsurface_names()
    local result = {}
    for surface_index, _ in pairs(storage.vsurfaces) do
        local surface = game.get_surface(surface_index)
        if surface and surface.valid then
            table.insert(result, surface.name)
        end
    end
    return result
end

---Deletes given vsurface
---@param surface_id string|integer|LuaSurface|nil surface identification
function VSurfaceManager.delete_vsurface(surface_id)
    -- getting LuaSurface object
    local surface = VSurfaceManager.get_surface(surface_id)
    if not surface or not surface.valid then return end

    -- checking if provided surface is a vsurface
    local surface_index = surface.index
    if not storage.vsurfaces[surface_index] then return end

    local status = game.delete_surface(surface_index)
    if status then storage.vsurfaces[surface_index] = nil end
end

-------------------------------------------------------------------------------
-- VENV-PROCESSOR/TEMPLATE-COMPILER REQUESTS
-------------------------------------------------------------------------------

---@param surface_id string|integer|LuaSurface|nil surface identification
---@return boolean is_valid true if surface is valid
function VSurfaceManager.check_surface_validity(surface_id)
    local surface = VSurfaceManager.get_surface(surface_id)
    return (surface and surface.valid) and true or false
end

---Calculates template energy drain for provided vsurface dimensions
---@param width number|nil surface width
---@param height number|nil surface height
---@return number energy_drain passive template energy drain
function VSurfaceManager.calculate_energy_drain(width, height)
    local area = (width or 0) * (height or 0)
    return 500 * math.sqrt(area) * area
end

---Calculates passive energy drain of a template for a given surface
---@param surface_index integer unique surface identifier
---@return number energy_drain passive template energy drain
function VSurfaceManager.get_vsurface_energy_drain(surface_index)
    local vsurface_data = storage.vsurfaces[surface_index]
    if not vsurface_data then return 0 end
    local width, height = vsurface_data.width, vsurface_data.height
    return VSurfaceManager.calculate_energy_drain(width, height)
end

---Helps in calculating surface building cost. Adds item to total cost.
---@param total_cost table<string, integer> building cost
---@param name string name of an item
---@param quality string quality of an item
---@param count integer count of an item
local function add_to_cost(total_cost, name, quality, count)
    local key = name .. "//" .. quality
    total_cost[key] = (total_cost[key] or 0) + count
end

---Collects building cost of a vsurface.
---@param surface_index integer unique surface identifier
---@return table<string, integer> building_cost
function VSurfaceManager.get_vsurface_building_cost(surface_index)
    local surface = game.get_surface(surface_index)
    if not surface or not surface.valid then return {} end

    -- collecting building cost
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
                add_to_cost(total_cost, build_cost[1].name, quality.name, build_cost[1].count)
                -- getting LuaInventory or nil if it does not exist
                local module_inv = entity.get_module_inventory()
                -- checking if entity has a module inventory and it's not empty
                if module_inv and not module_inv.is_empty() then
                    -- get_contents() returns an array of {name, count, quality_name}
                    for _, item in ipairs(module_inv.get_contents()) do
                        add_to_cost(total_cost, item.name, item.quality, item.count)
                    end
                end
            end
        end
    end
    return total_cost
end

---Enables labs on a given vsurface and changes their force to "lab-technical"
---@param surface_id string|integer|LuaSurface|nil surface identification
function VSurfaceManager.enable_labs(surface_id)
    local surface = VSurfaceManager.get_surface(surface_id)
    if not surface or not surface.valid then return end
    local labs = surface.find_entities_filtered{type = "lab"}
    for _, lab in ipairs(labs) do
        if lab and lab.valid then
            lab.force = "lab-technical"
            lab.disabled_by_script = false
        end
    end
end

---Disables labs on a given surface and changes their force to player
---@param surface_id string|integer|LuaSurface|nil surface identification
function VSurfaceManager.disable_labs(surface_id)
    local surface = VSurfaceManager.get_surface(surface_id)
    if not surface or not surface.valid then return end
    local labs = surface.find_entities_filtered{type = "lab"}
    for _, lab in ipairs(labs) do
        if lab and lab.valid then
            lab.force = "player"
            lab.disabled_by_script = true
        end
    end
end

return VSurfaceManager