


local Helper = {}

-------------------------------------------------------------------------------
-- INITIALIZATION OF TECHNICAL FORCE USED FOR COMPILING RESEARCH TEMPLATES
-------------------------------------------------------------------------------

-- Collects and enables all technical research and saves it to storage
local technical_research_prefix = "FV-technical-"
local function collect_technical_research()
    local lab_tech = game.forces["lab-technical"].technologies
    -- going through prototypes and identifying technical research by prefix
    for tech_name, tech_prototype in pairs(prototypes.technology) do
        if tech_name:find("^" .. technical_research_prefix) then
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
    if not game.forces["lab-technical"] then
        game.create_force("lab-technical")
    end
    local lab_force = game.forces["lab-technical"]
    -- copying all player force data to match progress
    lab_force.copy_from("player")
    storage.technical_research = {}
    collect_technical_research()
    lab_force.disable_research()
    local player_force = game.forces["player"]
    game.forces["player"].set_friend(lab_force, true)
    game.forces["lab-technical"].set_friend(player_force, true)
end

-------------------------------------------------------------------------------
-- TEMPLATE CONSTRUCTOR
-------------------------------------------------------------------------------

