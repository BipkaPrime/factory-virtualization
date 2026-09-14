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

return Misc