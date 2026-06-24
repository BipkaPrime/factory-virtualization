-- File for utility gui functions. Like getting entity data from storage, disabling gui elements, etc.

local Helper = {}


-- Returns table describing entity from entity registry
-- Entity validity must be checked before calling this function
-- @param entity: LuaEntityObject
function Helper.properties_from_reg(entity)
    local reg = storage.entity_registry[entity.name]
    local index = reg.lookup[entity.unit_number]
    return reg.array[index]
end

-- Recursively sets "enabled" to a given state for element and all it's children
function Helper.set_element_state(element, state)
    element.enabled = state
    for _, child in ipairs(element.children) do
        Helper.set_element_state(child, state)
    end
end

-- Filters an array of strings based on a search query
-- @param list table: Array of strings to search through (e.g., {"iron-plate", "copper-plate", "steel-plate"})
-- @param query string: The text typed into the textfield (e.g., "plate" or "IRON")
-- @return table: A new filtered array containing only matching strings
function Helper.filter_strings(list, query)
    if not list then return {} end
    local filtered = {}
    
    -- If search box is empty, return the whole list immediately
    if not query or query == "" then return list end
    
    -- Force search term to lowercase
    local search_term = string.lower(query)
    
    for _, text in ipairs(list) do
        -- Force target text to lowercase and search for a match
        if string.find(string.lower(text), search_term, 1, true) then
            table.insert(filtered, text)
        end
    end
    
    return filtered
end

-- Gathers all compiled template names from storage
function Helper.get_all_templates()
    local result = {}
    for name, _ in pairs(storage.compiled_templates) do
        table.insert(result, name)
    end
    return result
end

-- gathers names of all surfaces, which have vevs associated with given template
function Helper.get_all_surfaces(template_name)
    local result = {}
    local template_envs = storage.virtual_environments[template_name]
    -- checking that at least something is found
    if not template_envs then return end
    for surface_id, _ in pairs(template_envs) do
        table.insert(result, game.get_surface(surface_id).name)
    end
    return result
end

-- Comparison function that is used to sort sprite buttons by count.
-- Table being sorted must contain following keys:
-- count: float, name: prototype name, type: "item"/"fluid", quality (for items): "rare"/"epic", etc.
local type_rank = {item = 1, fluid = 2}
local quality_rank = {
    normal = 1,
    uncommon = 2,
    rare = 3,
    epic = 4,
    legendary = 5,
}
function Helper.sprite_buttons_comparison(a, b)
    -- priority 1: higher count first
    if a.count ~= b.count then
        return a.count > b.count
    
    -- priority 2: items first
    elseif a.type ~= b.type then
        return type_rank[a.type] < type_rank[b.type]
        
    -- priority 3: name (alphabetical)
    elseif a.name ~= b.name then
        return a.name < b.name
    
    -- riority 4: higher quality first
    else
        return (quality_rank[a.quality] or 0) > (quality_rank[b.quality] or 0)
    end
end

-- Collects all items and fluids from input/output data from compiled production template.
-- Also sorts io data by count.
-- @returns array containing following keys: 
-- type str: "item"/"fluid", name str: prototype name, count double, quality str (items only)
function Helper.collect_io_data(io_table)
    local result = {}
    if not io_table then return result end
    -- looking through items section
    if io_table.items then
        for name, quantities in pairs(io_table.items) do
            for quality, count in pairs(quantities) do
                table.insert(result, {type = "item", name = name, count = count, quality = quality})
            end
        end
    end
    -- looking through fluids section
    if io_table.fluids then
        for name, count in pairs(io_table.fluids) do
            table.insert(result, {type = "fluid", name = name, count = count})
        end
    end

    table.sort(result, Helper.sprite_buttons_comparison)
    return result
end

-- collects science points data for function below
local function process_science_table(science)
    if not science then return end
    local buttons = {}
    if science then
        for name, count in pairs(science) do
            table.insert(buttons, {type = "item", count = count, name = name, quality = "normal"})
        end
    end
    table.sort(buttons, Helper.sprite_buttons_comparison)
    return buttons
end

function Helper.collect_science_capability(science_production)
    local lab_buttons = process_science_table(science_production.labs_potential)
    local logistics_buttons = process_science_table(science_production.logistics_potential)
    return lab_buttons, logistics_buttons
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

-- Checks all values of a table and returns true if they all evaluate
-- to true, false otherwise
function Helper.all_true(table)
    for _, val in pairs(table) do
        if not val then return false end
    end
    return true
end


return Helper