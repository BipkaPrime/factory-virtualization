local Helper = {}

-- collects all compiled template names that exist
function Helper.get_all_templates()
    local result = {}
    for name, _ in pairs(storage.compiled_templates) do
        table.insert(result, name)
    end
    return result
end

-- Clears entity inventory (item, fluids and energy) of a given
-- entity if it's located on a vsurface
function Helper.clear_inventory_vsurface(entity)
    local surface_index = entity.surface_index
    if not storage.v_surfaces[surface_index] then return end
    local item_inventory = entity.get_inventory(defines.inventory.chest)
    if item_inventory then item_inventory.clear() end
    entity.clear_fluid_inside()
    if entity.energy > 0 then entity.energy = 0 end
end

-- Gets the name of a a given entity or ghost-entity assuming it's valid
-- @returns string: name of given entity or ghost-entity
-- @returns bool: true if entity is a ghost
function Helper.get_entity_name(entity)
    local entity_name = entity.name
    local is_ghost = false
    if entity_name == "entity-ghost" then
        entity_name = entity.ghost_name
        is_ghost = true
    end
    return entity_name, is_ghost
end

-- Converts double value to human-readable format
local prefixes = {
    {suffix = "", value = 1},
    {suffix = "k", value = 1e3},
    {suffix = "M", value = 1e6},
    {suffix = "G", value = 1e9},
    {suffix = "T", value = 1e12},
    {suffix = "P", value = 1e15},
    {suffix = "E", value = 1e18},
}
function Helper.format_double(value)
    local selected = prefixes[1]
    for _, prefix in ipairs(prefixes) do
        if value < prefix.value then
            break
        end
        selected = prefix
    end

    local scaled_value = value / selected.value
    local value_str
    if scaled_value < 100 then
        -- rounding to 1 decimal place
        local rounded = math.floor(scaled_value * 10 + 0.5) / 10
        if rounded % 1 == 0 then
            -- rounded is whole number
            value_str = string.format("%d", rounded)
        else
            value_str = string.format("%.1f", rounded)
        end
    else
        -- rounding to whole number
        value_str = string.format("%d", math.floor(scaled_value + 0.5))
    end
    
    return value_str .. " " .. selected.suffix
end

-- Calculates power consumption of a simulation based on its area
local K = 500
function Helper.template_area_to_power(area)
    return K * math.sqrt(area) * area
end

return Helper