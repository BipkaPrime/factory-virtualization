-- This file is for everything regarding technical force this mod introduces.

-- This mod allows for creation of special lab surfaces where all buildings and resources
-- are basically free. One potential problem to keep in mind is that player can get 
-- infinite research for free. So we need to prevent that somehow.

-- The idea is simple. Whenever an entity is built on a lab surface its force will be converted
-- to technical lab force. This way player won't be able to get any research progress from the lab surface.
-- This approach will also allow for virtualization of research. Another side effect from this is that 
-- production from lab surfaces will not affect production statistics for player.

-- The lab force should have the same researched technologies as the player force so that simulation is accurate.
-- So whenever the player researches something, we need to also unlock that technology for the lab force.
-- Since mod can be added to an already existing save, we need to match the research progress on_init as well.

-- We will have to change the force of whoever looking at lab surface for 
-- deconstrucion and upgrade planners to work properly.


local gui_names = require("scripts.gui.gui-names")

local Helper = {}

function Helper.init_lab_force()
    game.create_force("lab-technical")
    game.forces["lab-technical"].disable_research()
end

-- Changing force of the player who is looking at a lab surface to technical force
-- and changing it back after leaving
function Helper.process_surface_changed(event)
    local player = game.players[event.player_index]
    local surface_idx = player.surface_index

    -- chechking if the surface is a virtual lab
    if storage.lab_surfaces[surface_idx] then
        if player.force.name ~= "lab-technical" then
            player.force = game.forces["lab-technical"]
            game.print("You now belong to lab force")
        end
    else
        if player.force.name == "lab-technical" then
            player.force = game.forces["player"]
            game.print("You now belong to player force")
        end
    end
end

-- Used when on_research_finished event is triggered.
-- Researches finished technology for lab force.
function Helper.process_research_finished(event)
    local tech = event.research
    local lab_tech = game.forces["lab-technical"].technologies

    -- if player force did the research, we unlock it for lab force
    if tech.force == game.forces["player"] then
        lab_tech[tech.name].researched = true
    end
end

-- Used when on_research_reversed event is triggered.
-- Unresearches technology for lab force.
function Helper.process_research_reversed(event)
    local tech = event.research
    local lab_tech = game.forces["lab-technical"].technologies

    -- if player force did unresearched, we unresearch it for lab force
    if tech.force == game.forces["player"] then
        lab_tech[tech.name].researched = false
    end
end

-- Collects all technical research added by this mod and saves to storage
-- Also enables it to lab-techical force
-- Called on_init and on_configuration_changed
function Helper.collect_technical_research()
    local lab_tech = game.forces["lab-technical"].technologies

    -- going through prototypes and identifying technical research by prefix
    for tech_name, tech_prototype in pairs(prototypes.technology) do
        
        if tech_name:find("^" .. gui_names.prefix) then
            local ingredients = tech_prototype.research_unit_ingredients
            if ingredients and #ingredients > 0 then
                local first_ingredient = ingredients[1]

                -- saving tech_name and ingridient_name
                table.insert(
                    storage.technical_research,
                    {
                        tech_name = tech_name,
                        ingredient_name = first_ingredient.name,
                    }
                )
                
                -- enabling the technology for lab force
                lab_tech[tech_name].enabled = true
            end
        end
    end
end

return Helper