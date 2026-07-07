-- This file is used to display information about vclusters.
-- Created gui element cannot be interacted with.

local common = require("scripts.gui.common")
local misc = require("scripts.misc")

local Helper = {}

-- Prepares data from vcluster buffer for displaying.
-- Parses a key from vcluster buffer. There are 3 types of keys.
-- For items they are "name//quality"; for fluids "name";
-- for energy: "electric_energy".
-- @returns table containing "sprite", "tooltip", "quality"
local function get_sprite_button_data(key)
    local data = {}
    -- parsing different key types
    if key:find("//", 1, true) then
        -- handling item key type: "name//quality"
        local name, quality = string.match(key, "^([^/]+)//([^/]+)$")
        data.sprite = "item/" .. name
        data.tooltip = {"item-name." .. name}
        data.quality = quality
    elseif key == "electric_energy" then
        -- hadling energy key type "electric_energy"
        data.sprite = "virtual-signal/signal-lightning"
        data.tooltip = {"description.electricity"}
    else
        -- handling fluid key type "name"
        data.sprite = "fluid/" .. key
        data.tooltip = {"fluid-name." .. key}
    end
    return data
end

-- Adds a row displaying current and maximum buffer values.
-- Consists of a sprite button, progressbar and a label [curr / max] layed horizontally.
local function vcluster_buffer_entry(parent, key, buffer)
    local button_data = get_sprite_button_data(key)
    -- invisible element for horizontal alignment
    local frame = parent.add{
        type = "frame",
        direction = "horizontal",
        style = "shallow_frame"
    }
    frame.style.width = 388
    frame.style.padding = 2

    -- button
    frame.add{
        type = "sprite-button",
        sprite = button_data.sprite,
        style = "slot_button",
        quality = button_data.quality,
        tooltip = button_data.tooltip,
    }

    -- progressbar
    local bar = frame.add{
        type = "progressbar",
        value = buffer[3]/buffer[1],
    }
    bar.style.bar_width = 12
    bar.style.width = 220

    -- label to the right of progressbar (curr / max)
    local curr = misc.format_double(buffer[1])
    local maximum = misc.format_double(buffer[3])
    local caption = curr .. " / " .. maximum
    frame.add{type = "label", caption = caption}
end

-- Adds element displaying current state of a given buffer of a vcluster
-- @param parent LuaGuiElement: information will be added here
-- @param title localized string: title displayed on the top of info element
-- @param buffer table: input/output buffer from vcluster
local function vcluster_buffer_display(parent, title, buffer)
    local section = common.info_element_base(parent, title)
    local main_container = section.add{
        type = "scroll-pane",
        style = "deep_scroll_pane",
        direction = "vertical",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "never",
    }
    main_container.style.padding = 2
    local inner_flow = main_container.add{
        type = "flow",
        direction = "vertical",
    }
    inner_flow.style.vertical_spacing = 2

    for key, counts in pairs(buffer) do
        vcluster_buffer_entry(inner_flow, key, counts)
    end
end

function Helper.vcluster_input_buffer(parent, vcluster)
    local input_buffer = vcluster.input
    vcluster_buffer_display(parent, "VCLUSTER INPUT", input_buffer)
end

function Helper.vcluster_output_buffer(parent, vcluster)
    local output_buffer = vcluster.output
    vcluster_buffer_display(parent, "VCLUSTER OUTPUT", output_buffer)
end

return Helper