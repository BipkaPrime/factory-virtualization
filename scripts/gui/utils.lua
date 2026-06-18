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
function Helper.get_all_freq()
    local all_freq = {}
    for f, _ in pairs(storage.compiled_templates) do
        table.insert(all_freq, f)
    end
    return all_freq
end




return Helper