
local Utilities = {}

---Creates a buffer key for multi-mode entities. Assumes that provided
---configuration is correct. Operation mode is selected, selected item
---is present for "item" mode, selected fluid is present for "fluid" mode.
---@param properties EntityProperties
---@return BufferKeyString
function Utilities.generate_multimode_buffer_key(properties)
    local operation_mode = properties.operation_mode
    if operation_mode == "item" then
        local name = properties.selected_item_name
        local quality = properties.selected_item_quality
        return name .. "//" .. quality
    end
    if operation_mode == "fluid" then
        return properties.selected_fluid
    end
    return "electric_energy"
end

return Utilities