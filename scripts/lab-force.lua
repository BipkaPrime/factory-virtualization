-- This file is for everything regarding technical force this mod introduces.

-- This mod allows for creation of special virtualization surfaces where all buildings and resources
-- are basically free. One potential problem to keep in mind is that player can get 
-- infinite research for free. So we need to prevent that somehow.

-- For that we will create "lab-technical" force that will own everything that is built on vsurfaces
-- Moreover, when player looks as vsurface we will assign them to "lab-technical" force.

-- The lab force should have the same researched technologies as the player force so that simulation is accurate.
-- So whenever the player researches something, we need to also unlock that technology for the lab force.
-- Since mod can be added to an already existing save, we need to match the research progress on_init as well.

local names = require("scripts.gui-v2.names")

local Helper = {}

-- Collects and enables all technical research and saves it to storage
local function collect_technical_research()
    local lab_tech = game.forces["lab-technical"].technologies
    -- going through prototypes and identifying technical research by prefix
    for tech_name, tech_prototype in pairs(prototypes.technology) do
        if tech_name:find("^" .. names.prefix) then
            local first_ingredient = tech_prototype.research_unit_ingredients[1]
            local tech_data = {
                tech_name = tech_name,
                ingredient_name = first_ingredient.name
            }
            table.insert(storage.technical_research, tech_data)
            -- enabling technology for lab force
            lab_tech[tech_name].enabled = true
        end
    end
end

function Helper.init_lab_force()
    -- creating technical force if it doesn't exist
    local lab_force = game.forces["lab-technical"]
    if not lab_force then
        game.create_force("lab-technical")
    end
    -- copying all player force data to match progress
    game.forces["lab-technical"].copy_from("player")
    storage.technical_research = {}
    collect_technical_research()
    game.forces["lab-technical"].disable_research()
end

function Helper.process_player_changed_surface(event)
    local player = game.players[event.player_index]
    if not player and not player.valid then return end
    local surface_idx = player.surface_index
    if storage.v_surfaces[surface_idx] then
        player.force = game.forces["lab-technical"]
    else
        player.force = game.forces["player"]
    end
end

-- Used to sync progress between player and "lab-technical" forces
-- When player researches a technology, "lab-technical" unlocks it too
function Helper.process_research_finished(event)
    local tech = event.research
    local lab_tech = game.forces["lab-technical"].technologies

    if tech.force == game.forces["player"] then
        lab_tech[tech.name].researched = true
    end
end

-- Used to sync progress between player and "lab-technical" forces
-- When player reverses a technology, "lab-technical" locks it too
function Helper.process_research_reversed(event)
    local tech = event.research
    local lab_tech = game.forces["lab-technical"].technologies

    if tech.force == game.forces["player"] then
        lab_tech[tech.name].researched = false
    end
end

return Helper