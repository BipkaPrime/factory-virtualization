---@class ProductionResearchTrigger
---@field tech_name string name of technology prototype
---@field item_name string name of item that needs to be produced
---@field amount number amount that needs to be produced in one hour


local PREFIX = "FV-"
local ProductionResearch = {}


function ProductionResearch.initialize_storage()
    ---@type ProductionResearchTrigger[]
    storage.production_research = {
        {
            tech_name = PREFIX .. "mk2-root",
            item_name = "processing-unit",
            amount = 2.5e8,
        },
        {
            tech_name = PREFIX .. "mk3-root",
            item_name = "quantum-processor",
            amount = 5e9,
        },
        {
            tech_name = PREFIX .. "victory",
            item_name = "quantum-processor",
            amount = 3.6e12,
        },
    }
end

function ProductionResearch.check_progress()
    local production_research = storage.production_research
    if #production_research == 0 then return end

    -- gathering item statistics for player force for all surfaces
    ---@type LuaForce
    local player_force = game.forces["player"]
    ---@type LuaFlowStatistics[]
    local statistics = {}
    for _, surface in pairs(game.surfaces) do
        table.insert(
            statistics,
            player_force.get_item_production_statistics(surface)
        )
    end

    -- checking for research completion
    local technologies = player_force.technologies
    local counts = {}
    for i, research in ipairs(production_research) do
        local item_name = research.item_name
        -- counting total production for the item across all surfaces
        if not counts[item_name] then
            local count = 0
            for _, stats in ipairs(statistics) do
                count = count + stats.get_flow_count{
                    name = item_name,
                    category = "input",
                    precision_index = defines.flow_precision_index.one_hour,
                    count = true,
                }
            end
            counts[item_name] = count
        end
        -- researching the technology if requirments are met
        if research.amount <= counts[item_name] then
            player_force.script_trigger_research(research.tech_name)
            -- Removing technology from the list if it was researched
            ---@type LuaTechnology
            local tech = technologies[research.tech_name]
            if tech.researched then
                table.remove(storage.production_research, i)
            end
        end
    end
end

return ProductionResearch