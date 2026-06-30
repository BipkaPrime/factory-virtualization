local Helper = {}

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