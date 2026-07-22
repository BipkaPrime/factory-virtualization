local CommonGui = require("src.gui.common")


local ClusterInfo = {}

---Adds an element displaying information about 1 io buffer entry.
---Consists of a sprite button, progressbar and a label [curr / max] layed horizontally.
---@param parent LuaGuiElement info element will be added here
---@param key BufferKeyString unique buffer identifier
---@param buffer ClusterBufferEntry table containing buffer information
local function create_cluster_buffer_entry(parent, key, buffer)
    -- invisible element for horizontal alignment
    local frame = parent.add{
        type = "frame",
        direction = "horizontal",
        style = "shallow_frame"
    }
    frame.style.horizontally_stretchable = true
    frame.style.padding = 2

    -- sprite button on the left side
    local button_data = CommonGui.assemble_sprite_button_data(key, buffer.current)
    CommonGui.create_sprite_button(frame, button_data)

    -- progressbar
    local bar = frame.add{
        type = "progressbar",
        value = buffer.current/(buffer.maximum or 1),
    }
    bar.style.bar_width = 12
    bar.style.width = 220
end

---Adds a container for displaying cluster buffer contents
---@param parent LuaGuiElement info element will be added here
---@param title LocalisedString title displayed on the top of info element
---@return LuaGuiElement flow buffer entries can be displayed here
local function vcluster_buffer_base(parent, title)
    local section = CommonGui.create_info_element_base(parent, title)
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
function ClusterInfo.create_input_buffer(parent, cluster)
    if not cluster then return end
    local input = cluster.input
    if not next(input) then return end
    local container = vcluster_buffer_base(parent, {"gui-label.cluster-input"})
    for key, buffer in pairs(cluster.input) do
        create_cluster_buffer_entry(container, key, buffer)
    end
end

---Adds an element displaying info about cluster output buffer.
---@param parent LuaGuiElement element will be added here
---@param cluster ClusterData|nil table with cluster information
function ClusterInfo.create_output_buffer(parent, cluster)
    if not cluster then return end
    local output = cluster.output
    if not next(output) then return end
    local container = vcluster_buffer_base(parent, {"gui-label.cluster-output"})
    for key, buffer in pairs(cluster.output) do
        create_cluster_buffer_entry(container, key, buffer)
    end
end

---Adds an element displaying info about cluster member counts.
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

    local suffix = ": " .. tostring(cluster.crafting_power)
    CommonGui.create_bold_label(
        section,
        {"", {"gui-label.cluster-crafting-power"}, suffix}
    )
end

---Adds all cluster information to given element
---@param parent LuaGuiElement element will be added here
---@param cluster ClusterData|nil table with cluster information
function ClusterInfo.create_all_cluster_info(parent, cluster)
    if not cluster then return end
    ClusterInfo.create_input_buffer(parent, cluster)
    ClusterInfo.create_output_buffer(parent, cluster)
    ClusterInfo.create_member_counts(parent, cluster)
end

return ClusterInfo