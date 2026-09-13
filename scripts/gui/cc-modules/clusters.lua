--[[
Helps in handling of control center GUI. Contains definitions, configurators
and handlers for GUI elements that are used in "clusters" mode. As well as
all the logic required to operate the window in this mode.

Control center gui in "clusters" mode can be used to manage virtualization clusters.
Player can make following cluster-level requests using this mode:
create; rename; delete; clear assigned template.
--]]

---@class ControlCenterElements additional elements used in "clusters" mode
---@field new_cluster_btn LuaGuiElement|nil used to toggle "create" submode
---@field suboptimal_cluster_selector LuaGuiElement|nil left side selector
---@field suboptimal_cluster_update LuaGuiElement|nil button used to toggle updates
---@field rename_cluster_btn LuaGuiElement|nil used to toggle "rename" submode
---@field optimal_cluster_selector LuaGuiElement|nil left side selector
---@field optimal_cluster_update LuaGuiElement|nil button used to toggle updates
---@field delete_cluster_btn LuaGuiElement|nil used to toggle "delete" submode
---@field clear_template_btn LuaGuiElement|nil used to toggle "clear_template" submode
---@field cluster_surface_selector LuaGuiElement|nil new cluster surface selection
---@field new_cluster_confirm_btn LuaGuiElement|nil confirm cluster creation btn
---@field new_cluster_confirm_status LuaGuiElement|nil confirm cluster creation status
---@field confirm_cluster_rename_btn LuaGuiElement|nil confirm cluster rename button
---@field confirm_cluster_rename_label LuaGuiElement|nil confirm cluster rename status
---@field cluster_members_table LuaGuiElement|nil "table" for cluster member data
---@field cluster_members_elems table<integer, LuaGuiElement|LuaStyle>|nil table
---with elements that populate cluster members "table" element
---@field cluster_status_lbl LuaGuiElement|nil "label" displaying cluster status
---@field assigned_template_lbl LuaGuiElement|nil "label", general cluster info
---@field cluster_total_members LuaGuiElement|nil "label", general cluster info
---@field cluster_craft_progressbar LuaGuiElement|nil cluster operation section
---@field cluster_craft_style LuaStyle|nil cluster operation section
---@field cluster_energy_demand LuaGuiElement|nil "label", operation section
---@field cluster_decentr_loss LuaGuiElement|nil "label", operation section
---@field cluster_input_table LuaGuiElement|nil "table", used for input section
---@field cluster_input_elems table<integer, LuaGuiElement|LuaStyle>|nil
---@field cluster_output_table LuaGuiElement|nil "table", used for output section
---@field cluster_output_elems table<integer, LuaGuiElement|LuaStyle>|nil


---@class ControlCenterData additional fields used in "clusters" mode
---@field cluster_submode string|nil used to handle mutually exclusive gui states
---@field suboptimal_cluster_query string|nil suboptimal cluster search query
---@field selected_cluster string|nil display name of selected cluster
---@field optimal_cluster_query string|nil optimal cluster search query
---@field new_cluster_name string|nil name of new cluster (cluster creation)
---@field new_cluster_surface string|nil surface for new cluster (cluster creation)
---@field cluster_rename_name string|nil new name for a cluser (cluster rename)
---@field cluster_updates boolean|nil true if selectors are updated on time


local CommonGui = require("scripts.gui.common")
local TCCManager = require("scripts.simulation.tcc-manager")
local ClusterProcessor = require("scripts.simulation.cluster-processor")
local VSurfaceManager = require("scripts.world.vsurface-manager")


local PREFIX = "FV-"
local CCClusters = {}

---All possible submodes of control center in "clusters" mode.
---Used to handle mutually exclusive GUI states.
local cluster_submodes = {
    create = "create",
    rename = "rename",
    clear_template = "clear_template",
    delete = "delete",
}

-------------------------------------------------------------------------------
----------- LEFT FRAME CONTROL ELEMENTS: CREATION AND CONFIGURATION -----------
-------------------------------------------------------------------------------

----------------------------- NEW CLUSTER BUTTON ------------------------------

---Updates "create new cluster" button according to gui_data
---@param gui_data ControlCenterData
local function update_new_cluster_button(gui_data)
    local button = gui_data.elements.new_cluster_btn
    if not button or not button.valid then return end
    -- button is toggled if gui is in "create" submode
    button.toggled = (
        gui_data.cluster_submode == cluster_submodes.create
    )
end

---Adds "create new cluster" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_new_cluster_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-new-cluster-btn",
        caption = {"cc-clusters.new-cluster-btn"},
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.new_cluster_btn = button
    update_new_cluster_button(gui_data)
end

-------------------------------- RENAME BUTTON --------------------------------

---Updates "rename cluster" button according to gui_data
---@param gui_data ControlCenterData
local function update_rename_cluster_button(gui_data)
    local button = gui_data.elements.rename_cluster_btn
    if not button or not button.valid then return end
    -- button is enabled if cluster is selected
    button.enabled = not not gui_data.selected_cluster
    -- button is toggled if gui is in "rename" submode
    button.toggled = (
        gui_data.cluster_submode == cluster_submodes.rename
    )
end

---Adds "rename cluster" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_rename_cluster_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-rename-cluster",
        caption = {"cc-clusters.rename-cluster-btn"},
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.rename_cluster_btn = button
    update_rename_cluster_button(gui_data)
end

---------------------------- CLEAR TEMPLATE BUTTON ----------------------------

---Updates "clear template" button according to gui_data
---@param gui_data ControlCenterData 
local function update_clear_template_button(gui_data)
    local button = gui_data.elements.clear_template_btn
    if not button or not button.valid then return end
    -- button is enabled if cluster is selected
    button.enabled = not not gui_data.selected_cluster
    -- button is toggled if gui in "clear_template" submode
    button.toggled = (
        gui_data.cluster_submode == cluster_submodes.clear_template
    )
end

---Adds "clear template" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_clear_template_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-clear-template-btn",
        caption = {"cc-clusters.clear-template-btn"},
        style = "red_button",
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.clear_template_btn = button
    update_clear_template_button(gui_data)
end

-------------------------------- DELETE BUTTON --------------------------------

---Updates "delete selected" button according to gui_data
---@param gui_data ControlCenterData 
local function update_cluster_delete_button(gui_data)
    local button = gui_data.elements.delete_cluster_btn
    if not button or not button.valid then return end
    -- button is enabled only when cluster is selected
    button.enabled = not not gui_data.selected_cluster
    -- button is toggled if gui in "delete" submode
    button.toggled = (
        gui_data.cluster_submode == cluster_submodes.delete
    )
end

---Adds "delete selected" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_cluster_delete_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-delete-cluster-btn",
        caption = {"cc-clusters.delete-cluster-btn"},
        style = "red_button",
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.delete_cluster_btn = button
    update_cluster_delete_button(gui_data)
end

------------------------ SUBOPTIMAL CLUSTER SELECTION -------------------------

---Updates suboptimal cluster selector according to gui_data
---@param gui_data ControlCenterData
local function update_suboptimal_cluster_selector(gui_data)
    local elements = gui_data.elements
    -- Updating button toggling cluster updates
    local button = elements.suboptimal_cluster_update
    if not button or not button.valid then return end
    local update_toggled = not not gui_data.cluster_updates
    button.toggled = update_toggled
    button.tooltip = (
        update_toggled and CommonGui.updates_on or CommonGui.updates_off
    )
    -- Updating elements displayed in the selector
    local selector = elements.suboptimal_cluster_selector
    if not selector or not selector.valid then return end
    local query = gui_data.suboptimal_cluster_query
    -- getting names of all suboptimal clusters
    local options = ClusterProcessor.get_all_clusters_by_status(query, false)
    table.sort(options)
    local selected_option = gui_data.selected_cluster
    -- if selected cluster is optimal, it's not displayed as selected
    if ClusterProcessor.is_cluster_optimal(selected_option) then
        selected_option = nil
    end
    CommonGui.update_selector(selector, options, selected_option)
end

---Adds selection widget for suboptimal clusters to given parent element.
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_suboptimal_cluster_selection_widget(parent, gui_data)
    local search, selector, update_btn = CommonGui.add_selection_widget(
        parent,
        PREFIX .. "cc-suboptimal-cluster-search",
        PREFIX .. "cc-suboptimal-cluster-selector",
        PREFIX .. "cc-cluster-update",
        {"cc-clusters.clusters-suboptimal"},
        140
    )
    local elements = gui_data.elements
    elements.suboptimal_cluster_selector = selector
    elements.suboptimal_cluster_update = update_btn
    update_suboptimal_cluster_selector(gui_data)
    CommonGui.scroll_to_selection(selector)
    -- updating searchfield (only on creation)
    search.text = gui_data.suboptimal_cluster_query or ""
end

-------------------------- OPTIMAL CLUSTER SELECTION --------------------------

---Updates optimal cluster selector according to gui_data
---@param gui_data ControlCenterData
local function update_optimal_cluster_selector(gui_data)
    local elements = gui_data.elements
    -- Updating button toggling cluster updates
    local button = elements.optimal_cluster_update
    if not button or not button.valid then return end
    local update_toggled = not not gui_data.cluster_updates
    button.toggled = update_toggled
    button.tooltip = (
        update_toggled and CommonGui.updates_on or CommonGui.updates_off
    )
    -- Updating elements displayed in the selector
    local selector = elements.optimal_cluster_selector
    if not selector or not selector.valid then return end
    local query = gui_data.optimal_cluster_query
    -- getting names of all optimal clusters
    local options = ClusterProcessor.get_all_clusters_by_status(query, true)
    table.sort(options)
    local selected_option = gui_data.selected_cluster
    -- if selected cluster is suboptimal, it's not displayed as selected
    if ClusterProcessor.is_cluster_suboptimal(selected_option) then
        selected_option = nil
    end
    CommonGui.update_selector(selector, options, selected_option)
end

---Adds selection widget for optimal clusters to given parent element. Widget
---consists of "label", "textfield" for searching and "list-box" for selection.
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_optimal_cluster_selection_widget(parent, gui_data)
    local search, selector, update_btn = CommonGui.add_selection_widget(
        parent,
        PREFIX .. "cc-optimal-cluster-search",
        PREFIX .. "cc-optimal-cluster-selector",
        PREFIX .. "cc-cluster-update",
        {"cc-clusters.clusters-optimal"},
        140
    )
    local elements = gui_data.elements
    elements.optimal_cluster_selector = selector
    elements.optimal_cluster_update = update_btn
    update_optimal_cluster_selector(gui_data)
    CommonGui.scroll_to_selection(selector)
    -- updating searchfield (only on creation)
    search.text = gui_data.optimal_cluster_query or ""
end

-------------------------------------------------------------------------------
---------------------------- RIGHT FRAME ELEMENTS -----------------------------
-------------------------------------------------------------------------------

-------------------------- CLUSTER CREATION SECTION ---------------------------

---Updates section used for new cluster creation
---@param gui_data ControlCenterData
local function update_new_cluster_section(gui_data)
    local elements = gui_data.elements
    -- Updating new cluster surface selection
    local selector = elements.cluster_surface_selector
    if not selector or not selector.valid then return end
    local options = ClusterProcessor.get_cluster_location_options()
    local selected = gui_data.new_cluster_surface
    CommonGui.update_selector(selector, options, selected)
    CommonGui.scroll_to_selection(selector)
    -- Updating button and status label
    local button = elements.new_cluster_confirm_btn
    if not button or not button.valid then return end
    local label = elements.new_cluster_confirm_status
    if not label or not label.valid then return end
    local status, reason = ClusterProcessor.can_create_cluser(
        gui_data.new_cluster_name,
        gui_data.new_cluster_surface
    )
    button.enabled = status
    label.caption = reason or ""
end

---Adds section used for new cluster creation
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_new_cluster_section(parent, gui_data)
    local elements = gui_data.elements
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-clusters.create-section-title"}
    )

    -- First row: new cluster name and surface 
    local h_flow = section.add{type = "flow", direction = "horizontal"}

    -- First row, left side: name textfield and select current surface btn
    local left_flow = h_flow.add{type = "flow", direction = "vertical"}
    -- New cluster name textfied
    left_flow.add{
        type = "label",
        caption = {"cc-clusters.create-section-name"}
    }
    local textfield = left_flow.add{
        type = "textfield",
        name = PREFIX .. "cc-new-cluster-name",
        lose_focus_on_confirm = true,
        text = gui_data.new_cluster_name
    }
    local textfield_style = textfield.style
    textfield_style.width = 180
    textfield_style.bottom_margin = 24
    -- Select current surface button
    local surface_button = left_flow.add{
        type = "button",
        name = PREFIX .. "cc-select-current-surface-btn",
        caption = {"cc-clusters.select-current-surface"},
        tooltip = {"cc-clusters.select-current-surface-tooltip"},
    }
    surface_button.style.width = 180

    -- horizontal spacer between columns
    local h_spacer = h_flow.add{type = "flow"}
    h_spacer.style.horizontally_stretchable = true

    -- First row, right side: cluster surface selector
    local right_flow = h_flow.add{type = "flow", direction = "vertical"}
    right_flow.add{
        type = "label",
        caption = {"cc-clusters.create-section-surface"}
    }
    local selector = right_flow.add{
        type = "list-box",
        name = PREFIX .. "cc-new-cluster-selector",
        style = "list_box_in_shallow_frame",
    }
    elements.cluster_surface_selector = selector
    local selector_style = selector.style
    selector_style.width = 200
    selector_style.height = 84

    -- Second row: confirm cration button and status label
    local confirm_flow = section.add{type = "flow", direction = "vertical"}
    -- needed for right side alignment
    local flow_style = confirm_flow.style
    flow_style.horizontally_stretchable = true
    flow_style.horizontal_align = "right"
    -- status label
    local label = confirm_flow.add{type = "label"}
    label.style.font_color = CommonGui.red
    -- confirm button
    local button = confirm_flow.add{
        type = "button",
        name = PREFIX .. "cc-new-cluster-confirm",
        caption = {"cc-clusters.create-section-confirm-btn"},
        style = "confirm_button",
        tooltip = {"cc-clusters.create-section-confirm-tooltip"},
    }
    elements.new_cluster_confirm_btn = button
    elements.new_cluster_confirm_status = label
    update_new_cluster_section(gui_data)
end

--------------------------- CLUSTER RENAME SECTION ----------------------------

---Updates section used to rename selected cluster
---@param gui_data ControlCenterData
local function update_rename_cluster_section(gui_data)
    local elements = gui_data.elements
    local button = elements.confirm_cluster_rename_btn
    if not button or not button.valid then return end
    local label = elements.confirm_cluster_rename_label
    if not label or not label.valid then return end
    local status, reason = ClusterProcessor.can_rename_cluster(
        gui_data.selected_cluster,
        gui_data.cluster_rename_name
    )
    button.enabled = status
    label.caption = reason or ""
end

---Adds section used to rename selected cluster
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_rename_cluster_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-clusters.rename-section-title"}
    )

    -- Old name label
    local caption = {
        "cc-clusters.rename-section-old",
        gui_data.selected_cluster or "—"
    }
    section.add{type = "label", caption = caption}

    -- New name textfield
    local name_flow = section.add{type = "flow", direction = "horizontal"}
    name_flow.style.vertical_align = "center"
    name_flow.add{
        type = "label",
        caption = {"cc-clusters.rename-section-new"}
    }
    name_flow.add{
        type = "textfield",
        name = PREFIX .. "cc-cluster-rename-textfield",
        lose_focus_on_confirm = true,
        text = gui_data.cluster_rename_name
    }

    -- confirm button and status label above
    local confirm_flow = section.add{type = "flow", direction = "vertical"}
    local flow_style = confirm_flow.style
    flow_style.horizontally_stretchable = true
    flow_style.horizontal_align = "right"
    local label = confirm_flow.add{type = "label"}
    label.style.font_color = CommonGui.red
    local button = confirm_flow.add{
        type = "button",
        name = PREFIX .. "cc-confirm-cluster-rename",
        caption = {"cc-clusters.confirm-rename-btn"},
        style = "confirm_button",
        tooltip = {"cc-clusters.confirm-rename-tooltip"},
    }
    local elements = gui_data.elements
    elements.confirm_cluster_rename_btn = button
    elements.confirm_cluster_rename_label = label
    update_rename_cluster_section(gui_data)
end

--------------------------- CLEAR TEMPLATE SECTION ----------------------------

---Adds section used to clear template assigned to cluster
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_clear_template_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-clusters.clear-template-section-title"}
    )

    -- Template drop warning
    local caption = {
        "cc-clusters.clear-template-warning",
        gui_data.selected_cluster or "—"
    }
    local warning_label = section.add{type = "label", caption = caption}
    warning_label.style.single_line = false

    -- Confirm button
    local flow = section.add{type = "flow", direction = "vertical"}
    local flow_style = flow.style
    flow_style.horizontally_stretchable = true
    flow_style.horizontal_align = "right"
    flow.add{
        type = "button",
        name = PREFIX .. "cc-confirm-template-clear",
        caption = {"cc-clusters.confirm-template-clear-btn"},
        style = "red_confirm_button",
        tooltip = {"cc-clusters.confirm-template-clear-tooltip"},
    }
end

--------------------------- DELETE CLUSTER SECTION ----------------------------

---Adds section used to delete selected cluster
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_delete_cluster_section(parent, gui_data)
    local cluster_name = gui_data.selected_cluster
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-clusters.delete-section-title"}
    )

    -- General warning: always present
    local caption = {
        "cc-clusters.delete-warning-general",
        cluster_name or "—"
    }
    local general_label = section.add{type = "label", caption = caption}
    general_label.style.single_line = false

    -- Non empty warning: present when cluster member count is not 0
    local member_count = ClusterProcessor.get_total_member_counts(cluster_name)
    if member_count ~= 0 then
        caption = {
            "cc-clusters.delete-warning-non-empty",
            member_count
        }
        local label = section.add{type = "label", caption = caption}
        label.style.single_line = false
    end

    -- Confirm deletion button
    local flow = section.add{type = "flow", direction = "vertical"}
    local flow_style = flow.style
    flow_style.horizontally_stretchable = true
    flow_style.horizontal_align = "right"
    flow.add{
        type = "button",
        name = PREFIX .. "cc-confirm-cluster-delete",
        caption = {"cc-clusters.confirm-cluster-delete-btn"},
        style = "red_confirm_button",
        tooltip = {"cc-clusters.confirm-cluster-delete-tooltip"},
    }
end

------------------------ GENERAL CLUSTER INFO SECTION -------------------------

---Adds section used to display general cluster information
---@param gui_data ControlCenterData
local function update_general_info_section(gui_data)
    local elements = gui_data.elements
    local cluster_name = gui_data.selected_cluster

    -- Updating cluster status label
    local label = elements.cluster_status_lbl
    if not label or not label.valid then return end
    local is_optimal = ClusterProcessor.is_cluster_optimal(cluster_name)
    label.caption = (
        is_optimal and
        {"cc-clusters.perfect-operation"} or
        {"cc-clusters.attention-required"}
    )

    -- Updaing assigned template label
    label = elements.assigned_template_lbl
    if not label or not label.valid then return end
    local assigned_uuid = ClusterProcessor.get_assigned_template_by_name(
        cluster_name
    )
    local caption = {
        "",
        TCCManager.get_template_name(assigned_uuid) or "—"
    }
    -- Checking if this template is reachable
    local reachable_uuid
    local cluster_uuid = ClusterProcessor.get_cluster_uuid(cluster_name)
    if cluster_uuid then
        reachable_uuid = TCCManager.get_assigned_template(cluster_uuid)
    end
    if reachable_uuid ~= assigned_uuid then
        table.insert(caption, {"cc-clusters.no-connection"})
    end
    label.caption = caption

    -- Updating total member count
    label = elements.cluster_total_members
    if not label or not label.valid then return end
    local total_members = ClusterProcessor.get_total_member_counts(
        cluster_name
    )
    label.caption = tostring(total_members)
end

---Adds section used to display general cluster information
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_general_info_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-clusters.general-info-title"}
    )
    local info_table = section.add{
        type = "table",
        column_count = 2,
        style = "cluster_info_table",
    }

    local elements = gui_data.elements
    local cluster_name = gui_data.selected_cluster

    -- Cluster name row: does not need updates
    info_table.add{
        type = "label",
        caption = {"cc-clusters.cluster-name"},
        style = "bold_label",
    }
    local label = info_table.add{
        type = "label",
        caption = cluster_name or "—"
    }
    label.style.maximal_width = 220
    -- Surface name row: does not need updates
    local surface_name = ClusterProcessor.get_cluster_surface_name(
        cluster_name
    )
    info_table.add{
        type = "label",
        caption = {"cc-clusters.surface-name"},
        style = "bold_label",
    }
    label = info_table.add{type = "label", caption = surface_name}
    label.style.maximal_width = 220
    -- Cluster status row: requires updates
    info_table.add{
        type = "label",
        caption = {"cc-clusters.cluster-status"},
        style = "bold_label",
    }
    elements.cluster_status_lbl = info_table.add{type = "label"}
    -- Assigned template row: requires updates
    info_table.add{
        type = "label",
        caption = {"cc-clusters.assigned-template"},
        style = "bold_label",
    }
    label = info_table.add{type = "label"}
    label.style.maximal_width = 220
    elements.assigned_template_lbl = label
    -- Cluster total members row: requires updates
    info_table.add{
        type = "label",
        caption = {"cc-clusters.total-members"},
        style = "bold_label",
    }
    elements.cluster_total_members = info_table.add{type = "label"}
    -- Cluster center of mass row: does not need updates
    info_table.add{
        type = "label",
        caption = {"cc-clusters.center-of-mass"},
        style = "bold_label",
    }
    info_table.add{
        type = "button",
        name = PREFIX .. "cc-view-cluster",
        caption = {"cc-clusters.view"},
    }

    update_general_info_section(gui_data)
end

--------------------------- CLUSTER MEMBERS SECTION ---------------------------

local view_problems = {"cc-clusters.view-problems"}
local no_problems = {"cc-clusters.no-problems"}

---Updates one row of members table
---@param member_table LuaGuiElement "table" element to be filled 
---@param elems table<integer, LuaGuiElement|LuaStyle>
---@param used_elems integer number of elements already updated
---@param member_counts NamedMemberCount data to be displayed
---@return integer used_elems new value
local function fill_member_table_row(
    member_table,
    elems,
    used_elems,
    member_counts
)
    local member_name = member_counts.name
    local sprite = "item/" .. member_name
    local tooltip = {"entity-name." .. member_name}
    local total = member_counts.total
    local operational = member_counts.operational
    local has_problems = total ~= operational
    local label_color = has_problems and CommonGui.red or CommonGui.green
    local bnt_caption = has_problems and view_problems or no_problems
    local elems_length = #elems

    if elems_length > used_elems then
        -- There are enough elements: updating existing
        local sprite_btn = elems[used_elems + 1]
        sprite_btn.sprite = sprite
        sprite_btn.tooltip = tooltip
        elems[used_elems + 2].caption = total
        elems[used_elems + 3].font_color = label_color
        elems[used_elems + 4].caption = operational
        elems[used_elems + 5].font_color = label_color
        local problems_btn = elems[used_elems + 6]
        problems_btn.caption = bnt_caption
        problems_btn.enabled = has_problems
        if has_problems then
            problems_btn.tags = {[PREFIX] = member_name}
        end
    else
        -- There are not enough elements: creating new ones
        local frame = member_table.add{
            type = "frame",
            style = "deep_frame_in_shallow_frame",
        }
        elems[elems_length + 1] = frame.add{
            type = "sprite-button",
            sprite = sprite,
            tooltip = tooltip,
        }

        local total_label = member_table.add{
            type = "label",
            caption = total,
        }
        local total_style = total_label.style
        total_style.font_color = label_color
        elems[elems_length + 2] = total_label
        ---@diagnostic disable-next-line: assign-type-mismatch
        elems[elems_length + 3] = total_style

        local op_label = member_table.add{
            type = "label",
            caption = operational,
        }
        local op_style = op_label.style
        op_style.font_color = label_color
        elems[elems_length + 4] = op_label
        ---@diagnostic disable-next-line: assign-type-mismatch
        elems[elems_length + 5] = op_style

        local problems_flow = member_table.add{type = "flow"}
        local problems_btn = problems_flow.add{
            type = "button",
            caption = bnt_caption,
            enabled = has_problems,
            name = PREFIX .. "cc-view-problems",
        }
        problems_btn.style.width = 120
        if has_problems then
            problems_btn.tags = {[PREFIX] = member_name}
        end
        elems[elems_length + 6] = problems_btn
    end
    return used_elems + 6
end

---Comparison function that is used to sort member counts by name.
---@param a NamedMemberCount
---@param b NamedMemberCount
local function member_counts_comparison(a, b)
    return a.name < b.name
end

---Updates section used to display cluser member statistics
---@param gui_data ControlCenterData
local function update_member_info_section(gui_data)
    local members_table = gui_data.elements.cluster_members_table
    if not members_table or not members_table.valid then return end
    -- all elements are considered valid as long as members table is
    ---@type table<integer, LuaGuiElement|LuaStyle>
    local elems = gui_data.elements.cluster_members_elems
    local used_elems = 0

    local counts = ClusterProcessor.get_member_counts(gui_data.selected_cluster)
    table.sort(counts, member_counts_comparison)
    for i = 1, #counts do
        used_elems = fill_member_table_row(
            members_table,
            elems,
            used_elems,
            counts[i]
        )
    end
    -- destoying any unwanted rows in case "table" got smaller
    for i = #elems, used_elems + 1, -6 do
        -- "view problems" button (destroying parent flow)
        elems[i].parent.destroy()
        elems[i] = nil
        -- "op_label" style
        elems[i - 1] = nil
        -- "op_label"
        elems[i - 2].destroy()
        elems[i - 2] = nil
        -- "total_label" style
        elems[i - 3] = nil
        -- "total_label"
        elems[i - 4].destroy()
        elems[i - 4] = nil
        -- "sprite button"
        elems[i - 5].parent.destroy()
        elems[i - 5] = nil
    end
end

---Adds section used to display cluser member statistics
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_member_info_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-clusters.members-section-title"}
    )

    local members_table = section.add{
        type = "table",
        column_count = 4,
        style = "cluster_members_table",
    }
    -- table header
    members_table.add{
        type = "label",
        caption = {"cc-clusters.member"},
        style = "bold_label"
    }
    members_table.add{
        type = "label",
        caption = {"cc-clusters.total"},
        style = "bold_label"
    }
    members_table.add{
        type = "label",
        caption = {"cc-clusters.operational"},
        style = "bold_label"
    }
    members_table.add{
        type = "label",
        caption = {"cc-clusters.problems"},
        style = "bold_label"
    }
    local elements = gui_data.elements
    elements.cluster_members_table = members_table
    elements.cluster_members_elems = {}
    update_member_info_section(gui_data)
end

-------------------------- CLUSTER OPERATION SECTION --------------------------

---Updates section used to display current cluster operation
---@param gui_data ControlCenterData
local function update_cluster_operation_section(gui_data)
    local elements = gui_data.elements
    local cluster_name = gui_data.selected_cluster

    -- Updating progressbar
    local progressbar = elements.cluster_craft_progressbar
    if not progressbar or not progressbar.valid then return end
    ---@type LuaStyle assuming its valid as long as progressbar is valid
    local style = elements.cluster_craft_style
    local max_power, usage = ClusterProcessor.get_crafting_power_values(
        cluster_name
    )
    local caption = {
        "cc-clusters.craft-progressbar-text",
        CommonGui.large_number_to_string(usage),
        CommonGui.large_number_to_string(max_power),
    }
    progressbar.caption = caption
    local value = (max_power ~= 0) and usage / max_power or 0
    progressbar.value = value
    if value <= 0.5 then
        style.color = CommonGui.red
    elseif value <= 0.999 then
        style.color = CommonGui.yellow
    else
        style.color = CommonGui.green
    end

    -- Updating max energy demand label
    local max_demand, mult = ClusterProcessor.get_cluster_energy_demand(
        cluster_name
    )
    local label = elements.cluster_energy_demand
    if not label or not label.valid then return end
    caption = {
        "cc-clusters.max-energy-demand",
        CommonGui.large_number_to_string(max_demand * mult)
    }
    label.caption = caption

    -- Updating decentalization loss label
    label = elements.cluster_decentr_loss
    if not label or not label.valid then return end
    local loss = max_demand * (mult - 1)
    local percent = (mult - 1) / mult * 100
    caption = {
        "cc-clusters.decentr-loss",
        CommonGui.large_number_to_string(loss),
        CommonGui.number_to_string(percent, 2)
    }
    label.caption = caption
end

---Adds section used to display current cluster operation
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_cluster_operation_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-clusters.operation-section-title"}
    )
    local elements = gui_data.elements

    -- Crafting power utilization progressbar (ls_crafts/total)
    local progressbar = section.add{
        type = "progressbar",
        style = "electric_statistics_progressbar",
    }
    local style = progressbar.style
    style.horizontally_stretchable = true
    elements.cluster_craft_progressbar = progressbar
    ---@diagnostic disable-next-line: assign-type-mismatch
    elements.cluster_craft_style = style

    -- Energy demand labels
    local flow = section.add{type = "flow", direction = "vertical"}
    flow.style.vertical_spacing = 0
    elements.cluster_energy_demand = flow.add{type = "label"}
    elements.cluster_decentr_loss = flow.add{type = "label"}
    update_cluster_operation_section(gui_data)
end

------------------------- CLUSTER IO BUFFER SECTIONS --------------------------

---Updates one row of cluster io table
---@param io_table LuaGuiElement "table" element to be filled 
---@param elems table<integer, LuaGuiElement|LuaStyle>
---@param used_elems integer number of elements already updated
---@param buffer_entry ClusterBufferEntry data to be displayed
---@param crafting_power number crafting power of a cluster
---@return integer used_elems new value
local function fill_cluster_io_row(
    io_table,
    elems,
    used_elems,
    buffer_entry,
    crafting_power
)
    local sprite = buffer_entry.sprite
    local tooltip = buffer_entry.tooltip
    local quality
    if buffer_entry.item_id then
        quality = buffer_entry.item_id.quality
    end
    local current = buffer_entry.current
    local maximum = buffer_entry.maximum
    local bar_value = (maximum ~= 0) and current / maximum or 0
    local bar_caption = {
        "cc-clusters.bar-text",
        CommonGui.large_number_to_string(current),
        CommonGui.large_number_to_string(maximum),
    }
    -- deciding progressbar color
    local bar_color
    if crafting_power == 0 then
        bar_color = CommonGui.grey
    else
        local utilization = buffer_entry.ls_possible_crafts / crafting_power
        if utilization < 0.33 then
            bar_color = CommonGui.red
        elseif utilization < 1 then
            bar_color = CommonGui.yellow
        else
            bar_color = CommonGui.green
        end
    end
    local ls_input = CommonGui.large_number_to_string(buffer_entry.ls_input_flow)
    local ls_output = CommonGui.large_number_to_string(buffer_entry.ls_output_flow)
    local elems_length = #elems

    if elems_length > used_elems then
        -- There are enough elements: updating existing
        local sprite_btn = elems[used_elems + 1]
        sprite_btn.sprite = sprite
        sprite_btn.tooltip = tooltip
        sprite_btn.quality = quality
        -- progressbar
        local progressbar = elems[used_elems + 2]
        progressbar.caption = bar_caption
        progressbar.value = bar_value
        -- progressbar style
        elems[used_elems + 3].color = bar_color
        -- input last second flow
        elems[used_elems + 4].caption = ls_input
        -- output last second flow
        elems[used_elems + 5].caption = ls_output
    else
        -- There are not enough elements: creating new ones
        local frame = io_table.add{
            type = "frame",
            style = "deep_frame_in_shallow_frame",
        }
        elems[elems_length + 1] = frame.add{
            type = "sprite-button",
            sprite = sprite,
            tooltip = tooltip,
            quality = quality,
        }
        -- progressbar and its style
        local progressbar = io_table.add{
            type = "progressbar",
            style = "electric_statistics_progressbar",
            caption = bar_caption,
            value = bar_value,
        }
        elems[elems_length + 2] = progressbar
        local style = progressbar.style
        style.color = bar_color
        ---@diagnostic disable-next-line: assign-type-mismatch
        elems[elems_length + 3] = style
        -- last section input label
        elems[elems_length + 4] = io_table.add{
            type = "label",
            caption = ls_input
        }
        -- last section output label
        elems[elems_length + 5] = io_table.add{
            type = "label",
            caption = ls_output
        }
    end
    return used_elems + 5
end

---Clears all unwanted rows from cluster io table
---@param elems table<integer, LuaGuiElement|LuaStyle>
---@param used_elems integer number of elements already updated
local function clear_io_table_unwanded_rows(elems, used_elems)
    for i = #elems, used_elems + 1, -5 do
        -- last section output label
        elems[i].destroy()
        elems[i] = nil
        -- last section input label
        elems[i - 1].destroy()
        elems[i - 1] = nil
        -- progressbar style
        elems[i - 2] = nil
        -- progressbar
        elems[i - 3].destroy()
        elems[i - 3] = nil
        -- sprite button (inside deep frame)
        elems[i - 4].parent.destroy()
        elems[i - 4] = nil
    end
end

---Updates 2 sections used to display cluster IO buffers
---@param gui_data ControlCenterData
local function update_cluster_io_sections(gui_data)
    local elements = gui_data.elements
    local cluster_name = gui_data.selected_cluster
    local crafting_power = ClusterProcessor.get_crafting_power_values(
        cluster_name
    )
    local input, output = ClusterProcessor.get_cluster_io_buffers(
        cluster_name
    )

    -- Updating input table
    local io_table = elements.cluster_input_table
    if not io_table or not io_table.valid then return end
    ---@type table<integer, LuaGuiElement|LuaStyle>
    local elems = elements.cluster_input_elems
    local used_elems = 0
    for _, entry in pairs(input) do
        used_elems = fill_cluster_io_row(
            io_table,
            elems,
            used_elems,
            entry,
            crafting_power
        )
    end
    clear_io_table_unwanded_rows(elems, used_elems)

    -- Updating output table
    io_table = elements.cluster_output_table
    if not io_table or not io_table.valid then return end
    ---@type table<integer, LuaGuiElement|LuaStyle>
    elems = elements.cluster_output_elems
    used_elems = 0
    for _, entry in pairs(output) do
        used_elems = fill_cluster_io_row(
            io_table,
            elems,
            used_elems,
            entry,
            crafting_power
        )
    end
    clear_io_table_unwanded_rows(elems, used_elems)
end

---Captions used for io table headers
local io_table_header = {
    {"cc-clusters.entry"},
    {"cc-clusters.current"},
    {"cc-clusters.in"},
    {"cc-clusters.out"},
}
---Adds io table to given parent element and fills its header
---@return LuaGuiElement -- created "table" element
local function construct_io_table_header(parent)
    local io_table = parent.add{
        type = "table",
        column_count = 4,
        style = "cluster_io_table",
    }
    -- table header
    for _, caption in ipairs(io_table_header) do
        io_table.add{
            type = "label",
            caption = caption,
            style = "bold_label"
        }
    end
    return io_table
end

---Adds 2 sections used to display cluster IO buffers
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_cluster_io_sections(parent, gui_data)
    local elements = gui_data.elements

    -- Cluster inputs section
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-clusters.input-buffer"}
    )
    local io_table = construct_io_table_header(section)
    elements.cluster_input_table = io_table
    elements.cluster_input_elems = {}

    -- Cluster outputs section
    section = CommonGui.create_info_element_base(
        parent,
        {"cc-clusters.output-buffer"}
    )
    io_table = construct_io_table_header(section)
    elements.cluster_output_table = io_table
    elements.cluster_output_elems = {}
    update_cluster_io_sections(gui_data)
end

-------------------------------------------------------------------------------
------------------------ GUI CONSTRUCTION AND UPDATES -------------------------
-------------------------------------------------------------------------------

---Constructs left side of clusters mode interface
---@param gui_data ControlCenterData
function CCClusters.construct_left_side(gui_data)
    local left_frame = gui_data.elements.left_frame
    add_new_cluster_button(left_frame, gui_data)
    add_rename_cluster_button(left_frame, gui_data)
    add_suboptimal_cluster_selection_widget(left_frame, gui_data)
    add_clear_template_button(left_frame, gui_data)
    add_cluster_delete_button(left_frame, gui_data)
    local spacer = left_frame.add{type = "flow"}
    spacer.style.vertically_stretchable = true
    add_optimal_cluster_selection_widget(left_frame, gui_data)
end

---Maps submodes to functions used to construct corresponding sections
local submode_constructors = {
    [cluster_submodes.create] = add_new_cluster_section,
    [cluster_submodes.rename] = add_rename_cluster_section,
    [cluster_submodes.clear_template] = add_clear_template_section,
    [cluster_submodes.delete] = add_delete_cluster_section,
}

---Constructs right side of clusters mode interface
---@param gui_data ControlCenterData
function CCClusters.construct_right_side(gui_data)
    local right_frame = gui_data.elements.right_frame

    -- If cluster is selected displaying cluster info sections
    if gui_data.selected_cluster then
        add_general_info_section(right_frame, gui_data)
        add_member_info_section(right_frame, gui_data)
        add_cluster_operation_section(right_frame, gui_data)
        add_cluster_io_sections(right_frame, gui_data)
    end

    -- If sumbode is selected, displaying corresponding section
    local submode = gui_data.cluster_submode
    if submode then
        local constructor = submode_constructors[submode]
        constructor(right_frame, gui_data)
        right_frame.scroll_to_bottom()
    end
end

---Updates all elements in the left frame, rebuilds the right frame
---@param gui_data ControlCenterData
local function update_left_rebuild_right(gui_data)
    update_new_cluster_button(gui_data)
    update_rename_cluster_button(gui_data)
    update_clear_template_button(gui_data)
    update_cluster_delete_button(gui_data)
    update_optimal_cluster_selector(gui_data)
    update_suboptimal_cluster_selector(gui_data)
    gui_data.elements.right_frame.clear()
    CCClusters.construct_right_side(gui_data)
end

---Time based updater for the window in clusters mode
---@param gui_data ControlCenterData
---@param update_cycle integer
function CCClusters.on_tick_updater(gui_data, update_cycle)
    -- Verifying that selected cluster actually exists
    local selected = gui_data.selected_cluster
    if selected and not ClusterProcessor.get_cluster_uuid(selected) then
        gui_data.selected_cluster = nil
        gui_data.cluster_submode = nil
        update_left_rebuild_right(gui_data)
        return
    end

    -- If cluster is selected updating cluster info elements
    if gui_data.selected_cluster then
        update_cluster_io_sections(gui_data)
        if update_cycle % 30 == 0 then
            update_general_info_section(gui_data)
            update_member_info_section(gui_data)
            update_cluster_operation_section(gui_data)
        end
    end

    -- Updating cluster selectors if updates are enabled
    if update_cycle % 60 == 0 and gui_data.cluster_updates then
        update_suboptimal_cluster_selector(gui_data)
        update_optimal_cluster_selector(gui_data)
    end
end

-------------------------------------------------------------------------------
---------------------------- GUI STATE MANAGEMENT -----------------------------
-------------------------------------------------------------------------------

---Used to set clusters submode to provided value. If provided value
---matches with current submode, it's cleared instead.
---@param gui_data ControlCenterData
---@param new_submode string|nil submode value to set
local function toggle_cluster_submode(gui_data, new_submode)
    if gui_data.cluster_submode == new_submode then
        gui_data.cluster_submode = nil
    else
        gui_data.cluster_submode = new_submode
        if new_submode == cluster_submodes.create then
            -- this submode is mutually exclusive with selected cluster
            gui_data.selected_cluster = nil
            gui_data.new_cluster_name = nil
            gui_data.new_cluster_surface = nil
        elseif new_submode == cluster_submodes.rename then
            gui_data.cluster_rename_name = nil
        end
    end
    update_left_rebuild_right(gui_data)
end

---Used to set selected cluster to new value. If provided value
---matches with current selection, it is cleared instead.
---@param gui_data ControlCenterData
---@param new_selection string|nil
local function toggle_cluster_selection(gui_data, new_selection)
    local old_selection = gui_data.selected_cluster
    if old_selection == new_selection then
        gui_data.selected_cluster = nil
    else
        gui_data.selected_cluster = new_selection
    end
    -- when cluster selection changes, submode is reset as well
    gui_data.cluster_submode = nil
    update_left_rebuild_right(gui_data)
end

-------------------------------------------------------------------------------
-------------------- LEFT FRAME CONTROL ELEMENTS: HANDLERS --------------------
-------------------------------------------------------------------------------

----------------------------------- BUTTONS -----------------------------------

---Handles "create new cluster" button being pressed
---@param event EventData.on_gui_click
function CCClusters.handle_new_cluster_btn(event)
    toggle_cluster_submode(
        storage.control_center[event.player_index],
        cluster_submodes.create
    )
end

---Handles "rename selected" button being pressed
---@param event EventData.on_gui_click
function CCClusters.handle_rename_cluster_btn(event)
    toggle_cluster_submode(
        storage.control_center[event.player_index],
        cluster_submodes.rename
    )
end

---Handles "clear assigned template" button being pressed
---@param event EventData.on_gui_click
function CCClusters.handle_clear_template_btn(event)
    toggle_cluster_submode(
        storage.control_center[event.player_index],
        cluster_submodes.clear_template
    )
end

---Handles "delete selected" button being pressed
---@param event EventData.on_gui_click
function CCClusters.handle_delete_cluster_btn(event)
    toggle_cluster_submode(
        storage.control_center[event.player_index],
        cluster_submodes.delete
    )
end

------------------------------ CLUSTER SELECTION ------------------------------

---Handles button, which toggles time-based updates for template selectors
---@param event EventData.on_gui_click
function CCClusters.handle_cluster_updates_btn(event)
    local gui_data = storage.control_center[event.player_index]
    gui_data.cluster_updates = not gui_data.cluster_updates
    update_suboptimal_cluster_selector(gui_data)
    update_optimal_cluster_selector(gui_data)
end

---Handles optimal cluster searchfield being changed
---@param event EventData.on_gui_text_changed
function CCClusters.handle_optimal_cluster_search(event)
    local gui_data = storage.control_center[event.player_index]
    gui_data.optimal_cluster_query = event.text
    update_optimal_cluster_selector(gui_data)
end

---Handles suboptimal cluster searchfield being changed
---@param event EventData.on_gui_text_changed
function CCClusters.handle_suboptimal_cluster_search(event)
    local gui_data = storage.control_center[event.player_index]
    gui_data.suboptimal_cluster_query = event.text
    update_suboptimal_cluster_selector(gui_data)
end

---Handles selected cluster being changed
---@param event EventData.on_gui_selection_state_changed
function CCClusters.handle_cluster_selection_change(event)
    local selector = event.element
    local new_selection = selector.get_item(selector.selected_index)
    toggle_cluster_selection(
        storage.control_center[event.player_index],
        ---@diagnostic disable-next-line
        new_selection
    )
end

-------------------------------------------------------------------------------
------------------- RIGHT FRAME CONTROL ELEMENTS: HANDLERS --------------------
-------------------------------------------------------------------------------

-------------------------- CLUSTER CREATION SECTION ---------------------------

---Handles new cluster name being changed
---@param event EventData.on_gui_text_changed
function CCClusters.handle_new_cluster_name(event)
    local gui_data = storage.control_center[event.player_index]
    gui_data.new_cluster_name = event.text
    update_new_cluster_section(gui_data)
end

---Handles new cluster surface being changed
---@param event EventData.on_gui_selection_state_changed
function CCClusters.handle_new_cluster_surface_selection(event)
    local gui_data = storage.control_center[event.player_index]
    local selector = event.element
    local old_selection = gui_data.new_cluster_surface
    local new_selection = selector.get_item(selector.selected_index)

    -- if selected item is clicked again: unselect it
    if old_selection == new_selection then
        gui_data.new_cluster_surface = nil
        selector.selected_index = 0
    else
        ---@diagnostic disable-next-line
        gui_data.new_cluster_surface = new_selection
    end
    update_new_cluster_section(gui_data)
end

---Handles "select current surface" button being pressed
---@param event EventData.on_gui_click
function CCClusters.handle_select_current_surface_btn(event)
    local player_index = event.player_index
    local player = game.get_player(player_index)
    if not player then return end
    local gui_data = storage.control_center[player_index]
    local surface = player.surface
    -- vsurface cannot be selected
    if VSurfaceManager.is_vsurface(surface.index) then
        CommonGui.print_message(
            player_index,
            {"cc-clusters.cannot-select-vsurface"}
        )
        return
    end
    gui_data.new_cluster_surface = surface.name
    update_new_cluster_section(gui_data)
end

---Handles confirm cluster creation button being pressed
---@param event EventData.on_gui_click
function CCClusters.handle_confirm_cluster_creation_btn(event)
    local player_index = event.player_index
    local gui_data = storage.control_center[player_index]

    local status, reason = ClusterProcessor.create_cluster(
        gui_data.new_cluster_name,
        gui_data.new_cluster_surface
    )
    if not status then
        CommonGui.print_message(player_index, reason)
        return
    end

    -- Cluster successfully created: cleanup
    gui_data.selected_cluster = gui_data.new_cluster_name
    gui_data.new_cluster_name = nil
    gui_data.new_cluster_surface = nil
    gui_data.cluster_submode = nil
    update_left_rebuild_right(gui_data)
end


--------------------------- CLUSTER RENAME SECTION ----------------------------

---Handles new name textfield being changed in cluster rename section
---@param event EventData.on_gui_text_changed
function CCClusters.handle_cluster_rename_textfield(event)
    local gui_data = storage.control_center[event.player_index]
    gui_data.cluster_rename_name = event.text
    update_rename_cluster_section(gui_data)
end

---Handles confirm cluster rename button
---@param event EventData.on_gui_click
function CCClusters.handle_confirm_cluster_rename(event)
    local player_index = event.player_index
    local gui_data = storage.control_center[player_index]

    local status, _ = ClusterProcessor.rename_cluster(
        gui_data.selected_cluster,
        gui_data.cluster_rename_name
    )
    if not status then
        update_rename_cluster_section(gui_data)
        return
    end

    -- cluster was successfully renamed: cleanup
    gui_data.selected_cluster = gui_data.cluster_rename_name
    gui_data.cluster_rename_name = nil
    gui_data.cluster_submode = nil
    update_left_rebuild_right(gui_data)
end

--------------------------- CLEAR TEMPLATE SECTION ----------------------------

---Handles confirm template clear button
---@param event EventData.on_gui_click
function CCClusters.handle_confirm_template_clear_btn(event)
    local player_index = event.player_index
    local gui_data = storage.control_center[player_index]

    local status, reason = ClusterProcessor.drop_assigned_template(
        gui_data.selected_cluster
    )
    if not status then CommonGui.print_message(player_index, reason) return end

    -- template was successfully cleared: cleanup
    gui_data.cluster_submode = nil
    update_left_rebuild_right(gui_data)
end

--------------------------- DELETE CLUSTER SECTION ----------------------------

---Handles confirm cluster deletion button
---@param event EventData.on_gui_click
function CCClusters.handle_confirm_cluster_delete_btn(event)
    local player_index = event.player_index
    local gui_data = storage.control_center[player_index]

    local cluster_name = gui_data.selected_cluster
    local status, reason = ClusterProcessor.delete_cluster(cluster_name)
    if not status then CommonGui.print_message(player_index, reason) return end

    -- cluster deletion successfull: cleanup
    gui_data.cluster_submode = nil
    gui_data.selected_cluster = nil
    update_left_rebuild_right(gui_data)
end

------------------------ GENERAL CLUSTER INFO SECTION -------------------------

---Handles "view" cluster center button being pressed
---@param event EventData.on_gui_click
function CCClusters.handle_view_cluster_btn(event)
    local player_index = event.player_index
    local gui_data = storage.control_center[player_index]
    -- getting the position of selected cluster
    local surface_index, pos_x, pos_y = ClusterProcessor.get_cluster_center(
        gui_data.selected_cluster
    )
    -- cluster not found / not selected: return
    if not surface_index then return end
    ---@cast pos_x number
    ---@cast pos_y number
    CommonGui.move_player_camera(player_index, surface_index, pos_x, pos_y)
end

--------------------------- CLUSTER MEMBERS SECTION ---------------------------

---Handles "view_problems" button being pressed
---@param event EventData.on_gui_click
function CCClusters.handle_view_problems_btn(event)
    local player_index = event.player_index
    local gui_data = storage.control_center[player_index]
    -- getting position of "not operational" member
    local surface_index, pos_x, pos_y = ClusterProcessor.get_not_operational_position(
        gui_data.selected_cluster,
        ---@diagnostic disable-next-line: param-type-mismatch
        event.element.tags[PREFIX]
    )
    -- Problem was not found: return
    if not surface_index then return end
    -- Problem was found: moving camera to it
    ---@cast pos_x number
    ---@cast pos_y number
    CommonGui.move_player_camera(player_index, surface_index, pos_x, pos_y)
end

return CCClusters