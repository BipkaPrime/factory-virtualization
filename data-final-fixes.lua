-- We need to make a technical research for each science pack in the game.
-- Doing it here to let other mods add their science packs

local gui_names = require("scripts.gui.gui-names")

-- Table to store your collected science pack data
local collected_science_packs = {}

-- Scan all technologies to identify which items are used as science packs
for _, tech_data in pairs(data.raw["technology"]) do
    if tech_data.unit and tech_data.unit.ingredients then
        for _, ingredient in ipairs(tech_data.unit.ingredients) do
            
            -- Handle both format styles: 
            -- {"automation-science-pack", 1} or {name="automation-science-pack", amount=1}
            local pack_name = ingredient[1] or ingredient.name
            
            if pack_name and not collected_science_packs[pack_name] then
                -- Fetch the actual item prototype from data.raw
                -- Science packs can occasionally be tools (like standard packs) or ammunition/items
                local item_proto = data.raw["tool"][pack_name] or data.raw["item"][pack_name]
                
                if item_proto then
                    collected_science_packs[pack_name] = {
                        name = item_proto.name,
                        icon = item_proto.icon,
                        icon_size = item_proto.icon_size,
                    }
                end
            end
        end
    end
end

-- adding technical research
for _, pack in pairs(collected_science_packs) do
    data.extend({{
        type = "technology",
        name = gui_names.prefix .. pack.name,
        icon = pack.icon,
        icon_size = pack.icon_size,
        enabled = false,
        -- visible_when_disabled = true,
        unit = {
            count = 1e18,
            time = 60,
            ingredients = {{pack.name, 1}},
        }
    }})
end