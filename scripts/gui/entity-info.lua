-- This file contains definitions for information gui elements.
-- They cannot be interacted with and only there to display information.

local common = require("scripts.gui.common")

local Helper = {}

-- converts table containing items in the 2-level hmap format of:
-- "table[item_name][quality_name] = count" to displayable format
-- of array of {type, name, count, quality}.
local function collect_item_table(input_table)
    local result = {}
    if not input_table then return result end
    for name, q_counts in pairs(input_table) do
        for quality, count in pairs(q_counts) do
            local data = {
                type = "item",
                name = name,
                count = count,
                quality = quality
            }
            table.insert(result, data)
        end
    end
    return result
end

-- Adds a status display for virtualization mainframe
function Helper.vmainframe_status_display(parent, reg_data)
    local section = common.info_element_base(parent, "VMAINFRAME INFO DISPLAY")
    local status = "STATUS: TEMPLATE NOT SELECTED"
    if reg_data.operational then
        status = "STATUS: OPERATIONAL"
    elseif reg_data.active_template then
        status = "STATUS: REQUESTING CONSTRUCTION MATERIALS"
    end
    common.add_bold_label(section, status)
end

-- Collects building requests of a given vmainframe
local function get_vmainframe_requests(reg_data)
    if not reg_data or not reg_data.building_requests then return {} end
    local requests = reg_data.building_requests
    return collect_item_table(requests)
end

function Helper.vmainframe_building_requests(parent, reg_data)
    local section = common.info_element_base(parent, "MISSING CONSTRUCTION MATERIALS")
    local requests = get_vmainframe_requests(reg_data)
    common.sprite_button_panel(section, requests)
end

return Helper