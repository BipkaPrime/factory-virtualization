
-- Changes research for lab force given virtual environment. 
-- Saves generated science points for current research to venv.
-- @param new_index int: index of new research (in research_benchmarks)
--      or 0 to cancel the current research and just save the stats.     
-- @returns bool: true if everything ok.
local function change_research(venv, new_index)
    local current_idx = venv.currently_researching
    local lab_force = game.forces["lab-technical"]
    -- getting LuaFlowStatistics for lab-force item production on nauvis
    -- there will only be generated research points if any
    local prod_stat = lab_force.get_item_production_statistics("nauvis")
    -- checking if something is currently selected
    if current_idx > 0 then
        -- getting uint64 or double: number of science points produced
        local points_produced = prod_stat.get_input_count("science")
        -- getting string: current research ingredient 
        local ingredient = venv.research_benchmarks[current_idx]["ingredient_name"]
        -- saving produced points to venv
        if points_produced > 0 then
            local curr_stage = venv.benchmark_results[venv.benchmark_stage]
            -- creating entry of current stage table if necessery
            curr_stage[ingredient] = curr_stage[ingredient] or {points = 0, time = 0}
            curr_stage[ingredient].points = curr_stage[ingredient].points + points_produced
            curr_stage[ingredient].time = curr_stage[ingredient].time + venv.current_research_time
        end
    end
    -- cancel current research, clear research production statistics
    -- and start a new one if new_index > 0
    lab_force.cancel_current_research()
    prod_stat.clear()
    if new_index > 0 then
        local status = lab_force.add_research(venv.research_benchmarks[new_index].tech_name)
        if not status then return false end
        venv.currently_researching = new_index
    end
    return true
end
