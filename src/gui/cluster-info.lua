--[[
This file is used for displaying virtualization cluster information.
It works directly (read only) with cluster data from storage.
--]]

local CommonGui = require("src.gui.common")


local ClusterInfo = {}

---Helps in creation of cluster buffer entry.
---@param entry ClusterBufferEntry
---@return SpriteButtonData
local function assemble_sprite_button_data(entry)
    ---@type SpriteButtonData
    local data = {count = entry.current}
    if entry.type == "item" then
        local name = entry.name
        data.sprite = "item/" .. name
        -- some items only have localization as entities
        ---@diagnostic disable-next-line
        data.tooltip = {"?", {"item-name." .. name}, {"entity-name." .. name}}
        data.quality = entry.quality
    elseif entry.type == "fluid" then
        local name = entry.name
        data.sprite = "fluid/" .. name
        data.tooltip = {"fluid-name." .. name}
    else -- entry.type == "energy"
        data.sprite = "virtual-signal/signal-lightning"
        data.tooltip = {"description.energy"}
    end
    return data
end

---Adds an element displaying information about 1 io buffer entry.
---This elements contains several children layer horizontally.
---Sprite button with number indicating current amount in the entry.
---Progressbar indicating how full the entry. Progressbar color is based on whether this
---entry is a bottleneck for operation of the cluster. Labels that indicate IO flows for the entry.
---@param parent LuaGuiElement info element will be added here
---@param cluster ClusterData table with cluster information
---@param entry ClusterBufferEntry table containing entry information
local function create_cluster_buffer_entry(parent, cluster, entry)
    -- main frame that holds all children elements
    local frame = parent.add{
        type = "frame",
        direction = "horizontal",
        style = "shallow_frame"
    }
    frame.style.horizontally_stretchable = true
    frame.style.padding = 2

    -- sprite button on the left side
    local button_data = assemble_sprite_button_data(entry)
    CommonGui.create_sprite_button(frame, button_data)

    -- progressbar
    local maximum = entry.maximum
    local fullness = (maximum == 0) and 1 or (entry.current / maximum)
    local bar = frame.add{
        type = "progressbar",
        value = fullness,
    }
    bar.style.bar_width = 12
    bar.style.width = 220

    -- deciding progressbar color
    local crafting_power = cluster.crafting_power
    if crafting_power == 0 or maximum == 0 then
        bar.style.color = CommonGui.grey
    else
        local fraction = entry.ls_possible_crafts/crafting_power
        if fraction < 0.33 then
            bar.style.color = CommonGui.red
        elseif fraction < 1 then
            bar.style.color = CommonGui.yellow
        else -- fraction >= 1
            bar.style.color = CommonGui.green
        end
    end

    -- input flow label
    local io_flow = frame.add{type = "flow", direction = "horizontal"}
    io_flow.style.horizontally_stretchable = true
    io_flow.style.horizontal_spacing = 0
    io_flow.style.vertical_align = "center"
    io_flow.style.horizontal_align = "center"

    local input_caption = CommonGui.format_number(entry.ls_input_flow) .. " ▲"
    local input_label = io_flow.add{
        type = "label",
        caption = input_caption,
    }
    input_label.style.font_color = CommonGui.green

    -- output flow label
    local output_caption = "▼ " .. CommonGui.format_number(entry.ls_output_flow)
    local output_label = io_flow.add{
        type = "label",
        caption = output_caption,
    }
    output_label.style.font_color = CommonGui.red
end

---Adds a container for displaying cluster buffer contents
---@param parent LuaGuiElement info element will be added here
---@param subtitle LocalisedString subtitle displayed on the top of info element
---@return LuaGuiElement flow buffer entries can be displayed here
local function vcluster_buffer_base(parent, subtitle)
    local section = CommonGui.create_info_element_base(parent, subtitle)
    -- scroll pane so that built-in style can be used
    local main_container = section.add{
        type = "scroll-pane",
        style = "deep_scroll_pane",
        direction = "vertical",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "never",
    }
    main_container.style.width = 400
    main_container.style.padding = 2

    -- this is needed to override main container vertical spacing
    local inner_flow = main_container.add{
        type = "flow",
        direction = "vertical",
    }
    inner_flow.style.vertical_spacing = 2
    return inner_flow
end

---Adds an element displaying info about cluster input buffer.
---@param parent LuaGuiElement element will be added here
---@param cluster ClusterData|nil table with cluster information
---@param subtitle LocalisedString subtitle to display
function ClusterInfo.create_input_buffer(parent, cluster, subtitle)
    if not cluster then return end
    local container = vcluster_buffer_base(parent, subtitle)
    for _, entry in pairs(cluster.input) do
        create_cluster_buffer_entry(container, cluster, entry)
    end
end

---Adds an element displaying info about cluster output buffer.
---@param parent LuaGuiElement element will be added here
---@param cluster ClusterData|nil table with cluster information
---@param subtitle LocalisedString subtitle to display
function ClusterInfo.create_output_buffer(parent, cluster, subtitle)
    if not cluster then return end
    local output = cluster.output
    if not next(output) then return end
    local container = vcluster_buffer_base(parent, subtitle)
    for _, entry in pairs(cluster.output) do
        create_cluster_buffer_entry(container, cluster, entry)
    end
end

---Adds an element displaying info about cluster member counts.
---Also displays cluster crafting power and storage capacity
---@param parent LuaGuiElement element will be added here
---@param cluster ClusterData|nil table with cluster information
function ClusterInfo.create_member_counts(parent, cluster)
    if not cluster then return end
    local member_counts = cluster.member_counts
    if not member_counts or not next(member_counts) then return end

    local section = CommonGui.create_info_element_base(
        parent,
        {"gui-label.cluster-members"}
    )

    ---@type SpriteButtonData[]
    local buttons = {}
    for key, count in pairs(member_counts) do
        local button_data = CommonGui.assemble_sprite_button_data(key, count)
        table.insert(buttons, button_data)
    end
    CommonGui.create_sprite_button_table(section, buttons)

    -- crafting power label
    local crafting_power = ": " .. tostring(cluster.crafting_power)
    CommonGui.create_bold_label(
        section,
        ---@diagnostic disable-next-line
        {"", {"gui-label.cluster-crafting-power"}, crafting_power}
    )
    ---Decentralization energy loss
    local loss_mult = cluster.decentralization_loss
    local base_consumption = cluster.base_energy_per_craft
    -- total number of joules lost per craft due to decentralization loss
    local loss_value = base_consumption * loss_mult
    local loss_formatted = CommonGui.format_number(loss_value)
    -- fraction decentralization loss in total energy consumption
    local percentage = 100 * loss_mult / (1 + loss_mult)
    local percentage_caption = CommonGui.number_to_string(percentage, 2)
    CommonGui.create_bold_label(
        section,
        {
            ---@diagnostic disable-next-line
            "", {"gui-label.decentralization-loss"}, ": ", loss_formatted, "J (",
            ---@diagnostic disable-next-line
            percentage_caption, "% ", {"gui-label.decentralization-loss-percentage"}, ")"
        }
    )
end

---Adds all cluster information to given element
---@param parent LuaGuiElement element will be added here
---@param cluster ClusterData|nil table with cluster information
function ClusterInfo.create_all_cluster_info(parent, cluster)
    if not cluster then return end
    ClusterInfo.create_input_buffer(parent, cluster, {"gui-label.cluster-input"})
    ClusterInfo.create_output_buffer(parent, cluster, {"gui-label.cluster-output"})
    ClusterInfo.create_member_counts(parent, cluster)
end

return ClusterInfo