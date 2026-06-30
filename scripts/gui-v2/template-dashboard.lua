-- Template dashboard is a gui window which displays information
-- about all compiled templates and all virtual environments on all surfaces.

-- Main considerations to keep in mind when creating this gui.
-- 1. I want all data to persist if inteface is closed and then opened again.
--    To achieve this, we store all data related to interface state in storage.
-- 2. We have to update parts of the interface in responce to user inputs.
--    To do this conveniently, we store references to all objects that we want to update,
--    because it's much more convenient and robust then traversing gui by element names.
-- 3. We have to process user inputs. For that we give names to all elements that user
--    can interact with: main_window, textfields, dropdowns, etc.

--------------------------------------------------------------------------------------------
-- STORAGE KEYS FOR CONVENIENCE
--------------------------------------------------------------------------------------------
-- table = storage.template_dashboard[playaer_index]. table keys:
--

local names = require("scripts.gui-v2.names")
local common = require("scripts.gui-v2.common")

local Helper = {}





-- Opens/Closes template dashboard for a given player
local function toggle_template_dashboard(player)
    -- closing dashboard if it was opened
    if player.gui.screen[gui_names.prefix .. gui_names.dashboard_window] then
        player.opened = nil
        return
    end

    -- opening dashboard
    local main_frame = gui_common.gui_base_window(player, gui_names.prefix .. gui_names.dashboard_window)
    player.opened = main_frame
    storage.dashboard[player.index] = {}

    -- invisible container for other frames
    local main_content_frame = main_frame.add{
        type="flow",
        name = gui_names.prefix .. gui_names.dashboard_content_frame,
        direction="horizontal",
    }
    main_content_frame.style.height = 548

    -- left half of interface
    local left_content_frame = main_content_frame.add{
        type="frame",
        direction="vertical",
        style="inside_shallow_frame_with_padding",
    }
    left_content_frame.style.right_margin = 12

    -- template selection element
    local row1 = gui_common.selection_widget(
        left_content_frame,
        gui_names.prefix .. gui_names.dashboard_template_selection_flow,
        gui_names.prefix .. gui_names.dashboard_template_searchfield,
        gui_names.prefix .. gui_names.dashboard_template_selector,
        {"gui-label.frequency-selection"}
    )
    row1.style.bottom_margin = 12

    -- populate template selector with all compiled templates
    local template_selector = row1[gui_names.prefix .. gui_names.dashboard_template_selector]
    local available_templates = utils.get_all_templates()
    gui_common.arrange_selector(template_selector, available_templates, nil, nil)

    -- surface selection element
    local row2 = gui_common.selection_widget(
        left_content_frame,
        gui_names.prefix .. gui_names.dashboard_surface_selection_flow,
        gui_names.prefix .. gui_names.dashboard_surface_searchfield,
        gui_names.prefix .. gui_names.dashboard_surface_selector,
        {"gui-label.surface-selection"}
    )
    -- disabling surface selection. It should be enabled only when template is selected.
    utils.set_element_state(row2, false)

    -- right half of interface
    local right_content_frame = main_content_frame.add{
        type = "frame",
        name = gui_names.prefix .. gui_names.dashboard_right_content_frame,
        style = "inside_shallow_frame",
        direction = "vertical"
    }
    right_content_frame.style.width = 444

    -- main datafield
    local datafield = right_content_frame.add{
        type = "scroll-pane",
        name = gui_names.prefix .. gui_names.dashboard_datafield,
    }
    datafield.style.vertically_stretchable = true
end

local dashboard_shortcut_name = gui_names.prefix .. gui_names.template_dashboard
-- Toggles production template dashboard when shortcut bar element is clicked
function Helper.process_dashboard_shortcut(event)
    if event.prototype_name == dashboard_shortcut_name then
        local player = game.get_player(event.player_index)
        if not player then return end
        toggle_template_dashboard(player)
    end
end

-- Toggles production template dashboard when custom hotkey is pressed
function Helper.process_dashboard_hotkey(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    toggle_template_dashboard(player)
end

-- Collects all items and fluids from input/output data from compiled production template.
-- Also sorts io data by count.
-- @returns array containing following keys: 
-- type str: "item"/"fluid", name str: prototype name, count double, quality str (items only)
function Helper.collect_io_data(io_table)
    local result = {}
    if not io_table then return result end
    -- looking through items section
    if io_table.items then
        for name, quantities in pairs(io_table.items) do
            for quality, count in pairs(quantities) do
                table.insert(result, {type = "item", name = name, count = count, quality = quality})
            end
        end
    end
    -- looking through fluids section
    if io_table.fluids then
        for name, count in pairs(io_table.fluids) do
            table.insert(result, {type = "fluid", name = name, count = count})
        end
    end

    table.sort(result, Helper.sprite_buttons_comparison)
    return result
end

-- collects science points data for function below
local function process_science_table(science)
    if not science then return end
    local buttons = {}
    if science then
        for name, count in pairs(science) do
            table.insert(buttons, {type = "item", count = count, name = name, quality = "normal"})
        end
    end
    table.sort(buttons, Helper.sprite_buttons_comparison)
    return buttons
end

function Helper.collect_science_capability(science_production)
    local lab_buttons = process_science_table(science_production.labs_potential)
    local logistics_buttons = process_science_table(science_production.logistics_potential)
    return lab_buttons, logistics_buttons
end