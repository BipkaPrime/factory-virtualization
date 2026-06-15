-- This file is for definitions of custom GUIs for entities and everything related to it

-- TODO: make better structure. For example GUI base is the same for all uplinks/downlinks
-- It can be wrapped in a separate function that will create and configure the main_frame


-- Prefix for gui element names to avoid conflicts with other mods
PREFIX = "FV_"

-- Opens item uplink gui for a given player
function item_uplink_gui(player, entity)
    if player.gui.screen[PREFIX.."item_uplink_frame"] then
        player.gui.screen[PREFIX.."item_uplink_frame"].destroy()
    end

    local main_frame = player.gui.screen.add{
        type = "frame", 
        name = PREFIX.."item_uplink_frame", 
        caption = "Item Uplink",
    }
    main_frame.style.size = {385, 165}
    main_frame.auto_center = true
    player.opened = frame
end

-- Opens item downlink gui for a given player
function item_downlink_gui(player, entity)
    if player.gui.screen[PREFIX.."item_downlink_frame"] then
        player.gui.screen[PREFIX.."item_downlink_frame"].destroy()
    end

    local main_frame = player.gui.screen.add{
        type = "frame", 
        name = PREFIX.."item_downlink_frame", 
        caption = "Item Downlink",
    }
    main_frame.style.size = {385, 165}
    main_frame.auto_center = true
    player.opened = frame
end



-- Table mapping entity names to functions used for opening their GUIs
local Mapping = {
    ["item-uplink"] = item_uplink_gui,
    ["item-downlink"] = item_downlink_gui,
}

return Mapping