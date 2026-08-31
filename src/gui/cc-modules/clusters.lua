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
---@field rename_cluster_btn LuaGuiElement|nil used to toggle "rename" submode
---@field optimal_cluster_selector LuaGuiElement|nil left side selector
---@field delete_cluster_btn LuaGuiElement|nil used to toggle "delete" submode
---@field clear_template_btn LuaGuiElement|nil used to toggle "clear_template" submode
---@field cluster_surface_selector LuaGuiElement|nil new cluster surface selection
---@field new_cluster_confirm_btn LuaGuiElement|nil confirm cluster creation btn
---@field new_cluster_confirm_status LuaGuiElement|nil confirm cluster creation status
---@field confirm_cluster_rename_btn LuaGuiElement|nil confirm cluster rename button
---@field confirm_cluster_rename_label LuaGuiElement|nil confirm cluster rename status
---@field cluster_members_table LuaGuiElement|nil "table" for cluster member data
---@field cluster_members_elems LuaGuiElement[]|nil table with elements that populate
---cluster members "table" element
---@field cluster_status_lbl LuaGuiElement|nil "label" displaying cluster status
---@field assigned_template_lbl LuaGuiElement|nil "label", general cluster info
---@field cluster_total_members LuaGuiElement|nil "label", general cluster info
---@field cluster_craft_progressbar LuaGuiElement|nil cluster operation section
---@field cluster_craft_style LuaStyle|nil cluster operation section
---@field cluster_energy_demand LuaGuiElement|nil "label", operation section
---@field cluster_decentr_loss LuaGuiElement|nil "label", operation section


---@class ControlCenterData additional fields used in "clusters" mode
---@field cluster_submode string|nil used to handle mutually exclusive gui states
---@field suboptimal_cluster_query string|nil suboptimal cluster search query
---@field selected_cluster string|nil display name of selected cluster
---@field optimal_cluster_query string|nil optimal cluster search query
---@field new_cluster_name string|nil name of new cluster (cluster creation)
---@field new_cluster_surface string|nil name of the surface for
---the new cluster (cluster creation)
---@field cluster_rename_name string|nil new name for a cluser (cluster rename)


local CommonGui = require("src.gui.common")
local TCCManager = require("src.simulation.tcc-manager")
local ClusterProcessor = require("src.simulation.cluster-processor")
local VSurfaceManager = require("src.world.vsurface-manager")


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
    button.toggled = (gui_data.cluster_submode == cluster_submodes.create)
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
    button.toggled = (gui_data.cluster_submode == cluster_submodes.rename)
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
    button.toggled = (gui_data.cluster_submode == cluster_submodes.clear_template)
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
    button.toggled = (gui_data.cluster_submode == cluster_submodes.delete)
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
    local selector = gui_data.elements.suboptimal_cluster_selector
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

---Adds selection widget for suboptimal clusters to given parent element. Widget
---consists of "label", "textfield" for searching and "list-box" for selection.
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_suboptimal_cluster_selection_widget(parent, gui_data)
    local search, selector = CommonGui.add_selection_widget(
        parent,
        PREFIX .. "cc-suboptimal-cluster-search",
        PREFIX .. "cc-suboptimal-cluster-selector",
        {"cc-clusters.clusters-suboptimal"},
        140
    )
    search.text = gui_data.suboptimal_cluster_query or ""
    gui_data.elements.suboptimal_cluster_selector = selector
    update_suboptimal_cluster_selector(gui_data)
    -- scrolling to selected item when creating the element
    CommonGui.scroll_to_selection(selector)
end

-------------------------- OPTIMAL CLUSTER SELECTION --------------------------

---Updates optimal cluster selector according to gui_data
---@param gui_data ControlCenterData
local function update_optimal_cluster_selector(gui_data)
    local selector = gui_data.elements.optimal_cluster_selector
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
    local search, selector = CommonGui.add_selection_widget(
        parent,
        PREFIX .. "cc-optimal-cluster-search",
        PREFIX .. "cc-optimal-cluster-selector",
        {"cc-clusters.clusters-optimal"},
        140
    )
    search.text = gui_data.optimal_cluster_query or ""
    gui_data.elements.optimal_cluster_selector = selector
    update_optimal_cluster_selector(gui_data)
    -- scrolling to selected item when creating the element
    CommonGui.scroll_to_selection(selector)
end

-------------------------------------------------------------------------------
---------------------------- RIGHT FRAME ELEMENTS -----------------------------
-------------------------------------------------------------------------------

-------------------------- CLUSTER CREATION SECTION ---------------------------

---Updates section used for new cluster creation
---@param gui_data ControlCenterData
local function update_new_cluster_section(gui_data)
    -- New cluster surface selection
    local selector = gui_data.elements.cluster_surface_selector
    if not selector or not selector.valid then return end
    local options = ClusterProcessor.get_cluster_location_options()
    local selected = gui_data.new_cluster_surface
    CommonGui.update_selector(selector, options, selected)
    CommonGui.scroll_to_selection(selector)
    -- Confirm cluster creation button and status
    local button = gui_data.elements.new_cluster_confirm_btn
    if not button or not button.valid then return end
    local label = gui_data.elements.new_cluster_confirm_status
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
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-clusters.create-section-title"}
    )

    -- First row: new cluster name and surface 
    local h_flow = section.add{type = "flow", direction = "horizontal"}

    -- First row, left side: name textfield and select current surface btn
    local left_flow = h_flow.add{type = "flow", direction = "vertical"}
    -- New cluster name textfied
    left_flow.add{type = "label", caption = {"cc-clusters.create-section-name"}}
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
    right_flow.add{type = "label", caption = {"cc-clusters.create-section-surface"}}
    local selector = right_flow.add{
        type = "list-box",
        name = PREFIX .. "cc-new-cluster-selector",
        style = "list_box_in_shallow_frame",
    }
    gui_data.elements.cluster_surface_selector = selector
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
    gui_data.elements.new_cluster_confirm_btn = button
    gui_data.elements.new_cluster_confirm_status = label
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
    local cluster_name = gui_data.selected_cluster or "None"
    local old_caption = {"cc-clusters.rename-section-old", cluster_name}
    section.add{type = "label", caption = old_caption}

    -- New name textfield
    local name_flow = section.add{type = "flow", direction = "horizontal"}
    name_flow.style.vertical_align = "center"
    name_flow.add{type = "label", caption = {"cc-clusters.rename-section-new"}}
    name_flow.add{
        type = "textfield",
        name = PREFIX .. "cc-cluster-rename-textfield",
        lose_focus_on_confirm = true,
        text = gui_data.cluster_rename_name or ""
    }

    -- confirm button and status label above
    local confirm_flow = section.add{type = "flow", direction = "vertical"}
    local flow_style = confirm_flow.style
    flow_style.horizontally_stretchable = true
    flow_style.horizontal_align = "right"

    -- button and status label
    local label = confirm_flow.add{type = "label"}
    label.style.font_color = CommonGui.red
    local button = confirm_flow.add{
        type = "button",
        name = PREFIX .. "cc-confirm-cluster-rename",
        caption = {"cc-clusters.confirm-rename-btn"},
        style = "confirm_button",
        tooltip = {"cc-clusters.confirm-rename-tooltip"},
    }
    gui_data.elements.confirm_cluster_rename_btn = button
    gui_data.elements.confirm_cluster_rename_label = label
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

    local cluster_name = gui_data.selected_cluster or "None"
    local warning = {"cc-clusters.clear-template-warning", cluster_name}
    local warning_label = section.add{type = "label", caption = warning}
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
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-clusters.delete-section-title"}
    )

    -- general warning: always present
    local cluster_name = gui_data.selected_cluster or "None"
    local general_warning = {
        "cc-clusters.delete-warning-general",
        cluster_name
    }
    local general_label = section.add{type = "label", caption = general_warning}
    general_label.style.single_line = false

    -- non empty warning: present when cluster member count is not 0
    local member_count = ClusterProcessor.get_total_member_counts(cluster_name)
    if member_count ~= 0 then
        local non_empty_warning = {
            "cc-clusters.delete-warning-non-empty",
            member_count
        }
        local label = section.add{type = "label", caption = non_empty_warning}
        label.style.single_line = false
    end

    -- confirm deletion button
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

    -- Updating cluster status
    local label = elements.cluster_status_lbl
    if not label or not label.valid then return end
    local is_optimal = ClusterProcessor.is_cluster_optimal(cluster_name)
    label.caption = (
        is_optimal and
        {"cc-clusters.cluster-status-ok"} or
        {"cc-clusters.cluster-status-not-ok"}
    )

    -- Updaing assigned template
    label = elements.assigned_template_lbl
    if not label or not label.valid then return end
    local template_uuid = ClusterProcessor.get_assigned_template_by_name(
        cluster_name
    )
    local template_name = TCCManager.get_template_name(template_uuid) or "None"
    local caption = {"cc-clusters.assigned-template", template_name}
    label.caption = caption

    -- Updating total member count
    label = elements.cluster_total_members
    if not label or not label.valid then return end
    local total_members = ClusterProcessor.get_total_member_counts(
        cluster_name
    )
    caption = {"cc-clusters.total-members", total_members}
    label.caption = caption
end

---Adds section used to display general cluster information
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_general_info_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-clusters.general-info-title"}
    )
    local elements = gui_data.elements
    local cluster_name = gui_data.selected_cluster or "None"

    local flow = section.add{type = "flow", direction = "vertical"}
    flow.style.vertical_spacing = 0
    -- Cluster name label: does not need updates
    local caption = {"cc-clusters.cluster-name", cluster_name}
    flow.add{type = "label", caption = caption}
    -- Surface name label: does not need updates
    local surface_name = ClusterProcessor.get_cluster_surface_name(
        cluster_name
    )
    caption = {"cc-clusters.surface-name", surface_name}
    flow.add{type = "label", caption = caption}
    -- Cluster status label: requires updates
    elements.cluster_status_lbl = flow.add{type = "label"}
    -- Assigned template label: requires updates
    elements.assigned_template_lbl = flow.add{type = "label"}
    -- Cluster total member count: requires updates
    elements.cluster_total_members = flow.add{type = "label"}
    update_general_info_section(gui_data)
end

--------------------------- CLUSTER MEMBERS SECTION ---------------------------

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
            caption = {"cc-clusters.view-problems"},
            enabled = has_problems,
            name = PREFIX .. "cc-view-problems",
        }
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
    gui_data.elements.cluster_members_table = members_table
    gui_data.elements.cluster_members_elems = {}
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

---Updates 2 sections used to display cluster IO buffers
---@param gui_data ControlCenterData
local function update_cluster_io_sections(gui_data)

end


---Adds 2 sections used to display cluster IO buffers
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_cluster_io_sections(parent, gui_data)



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
    if gui_data.selected_cluster then
        add_general_info_section(right_frame, gui_data)
        add_member_info_section(right_frame, gui_data)
        add_cluster_operation_section(right_frame, gui_data)
    end

    ---If sumbode is selected, displaying corresponding section
    local submode = gui_data.cluster_submode
    if submode then
        local constructor = submode_constructors[submode]
        if constructor then
            constructor(right_frame, gui_data)
        end
    end
end

---Time based updater for the window in clusters mode
---@param gui_data ControlCenterData
---@param update_cycle integer
function CCClusters.on_tick_updater(gui_data, update_cycle)
    if gui_data.selected_cluster then
        if update_cycle % 30 == 0 then
            update_general_info_section(gui_data)
            update_member_info_section(gui_data)
            update_cluster_operation_section(gui_data)
        end
    end
end

-------------------------------------------------------------------------------
---------------------------- GUI STATE MANAGEMENT -----------------------------
-------------------------------------------------------------------------------

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

---Used to set clusters submode to provided value. If provided value
---matches with current submode, it's cleared instead.
---@param gui_data ControlCenterData
---@param new_submode string|nil submode value to set
local function toggle_cluster_submode(gui_data, new_submode)
    if gui_data.cluster_submode == new_submode then
        gui_data.cluster_submode = nil
    else
        gui_data.cluster_submode = new_submode
        -- "create" submode is mutually exclusive with selected cluster
        if new_submode == cluster_submodes.create then
            gui_data.selected_cluster = nil
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
    -- if vsurface is selected, it should not be selected
    if VSurfaceManager.is_vsurface(surface.index) then
        CommonGui.print_message(player_index, {"cc-clusters.cannot-select-vsurface"})
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
    local player = game.get_player(player_index)
    if not player then return end
    local surface = game.get_surface(surface_index)
    if not surface then return end

    -- closing the window
    player.opened = nil
    local zoom = player.zoom
    -- moving player camera
    player.set_controller{
        type = defines.controllers.remote,
        surface = surface,
        position = {pos_x, pos_y},
    }
    player.zoom = zoom
    -- printing location in chat (cheating ping)
    player.print(string.format("[gps=%f,%f,%s]", pos_x, pos_y, surface.name))
end


return CCClusters