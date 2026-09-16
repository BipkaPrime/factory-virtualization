local Misc = {}


---Considering we are trying to slice an array into n slices.
---Each slice consisting of indexes for which (index % n == m).
---In other words, they are congruent modulo n.
---This function gets first and last indexes of this slice.
---@param length integer length of the array
---@param offset integer offset for the slice (m)
---@param modulo integer comparison modulo (n)
---@return integer|nil start_idx nil is returned when slice is empty
---@return integer|nil stop_idx nil is returned when slice is empty
function Misc.get_slice_range(length, offset, modulo)
    local start_idx = (offset == 0) and modulo or offset
    if start_idx > length then return end
    local stop_idx = length - ((length - start_idx) % modulo)
    return start_idx, stop_idx
end

---Helps update storage table when migration occures.
---@param buffer_key BufferKeyString "iron-plate//normal", "water", etc.
---@param item table<string, string> migration item mappind (old -> new)
---@param fluid table<string, string> migration fluid mappind (old -> new)
---@param quality table<string, string> migration quality mappind (old -> new)
---@return BufferKeyString|nil new_key nil is returned when migration fails
function Misc.migrate_buffer_key(buffer_key, item, fluid, quality)
    local start_idx, stop_idx = string.find(buffer_key, "//", 1, true)
    if start_idx then
        -- item key "name//quality"
        local old_name = string.sub(buffer_key, 1, start_idx - 1)
        local old_quality = string.sub(buffer_key, stop_idx + 1)
        local new_name = item[old_name] or old_name
        local new_quality = quality[old_quality] or old_quality
        -- when prototype is removed, it maps to an empty string
        if new_name == "" or new_quality == "" then return end
        return string.format("%s//%s", new_name, new_quality)
    elseif buffer_key == "electric_energy" then
        -- energy key
        return buffer_key
    else
        -- fluid key "name"
        local new_name = fluid[buffer_key] or buffer_key
        -- when prototype is removed, it maps to an empty string
        if new_name == "" then return end
        return new_name
    end
end

---Applies a migration to the given buffer table.
---@param old_table table<BufferKeyString, any>
---@param item table<string, string> migration item mappind (old -> new)
---@param fluid table<string, string> migration fluid mappind (old -> new)
---@param quality table<string, string> migration quality mappind (old -> new)
---@param strict boolean true to fail migration for any unmigratable string
---@return table<BufferKeyString, any>|nil new_table nil if migration fails
function Misc.migrate_buffer_table(old_table, item, fluid, quality, strict)
    local new_table = {}
    for old_key, data in pairs(old_table) do
        local new_key = Misc.migrate_buffer_key(
            old_key,
            item,
            fluid,
            quality
        )
        if not new_key and strict then return end
        if new_key then new_table[new_key] = data end
    end
    return new_table
end

return Misc