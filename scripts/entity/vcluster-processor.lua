local Helper = {}

-- Helps with processing crafts inside clusters. Calculates
-- amount of crafts that can be made with input ingredients.
local function get_input_crafts(cluster)
    local max_crafts = 1e9
    for _, buffer in pairs(cluster.input) do
        local curr_crafts = math.floor(buffer[1] / buffer[2])
        max_crafts = math.min(max_crafts, curr_crafts)
    end
    return max_crafts
end

-- Helps with processing crafts inside clusters. Calculates
-- amount of crafts that can fit in the output.
local function get_output_crafts(cluster)
    local max_crafts = 1e9
    for _, buffer in pairs(cluster.output) do
        local curr_crafts = math.floor((buffer[3] - buffer[1]) / buffer[2])
        max_crafts = math.min(max_crafts, curr_crafts)
    end
    return max_crafts
end

-- Performs a craft for a vcluster.
local function perform_craft(cluster)
    if not cluster.research_producer then
        -- cluster crafting potential
        local max_crafts = cluster.operational_vms
        if max_crafts == 0 then
           cluster.last_cycle_crafts = 0
           return
        end

        -- calculating buffers limitations
        local input_crafts = get_input_crafts(cluster)
        local output_crafts = get_output_crafts(cluster)
        max_crafts = math.min(max_crafts, input_crafts, output_crafts)
        if max_crafts <= 0 then
            cluster.last_cycle_crafts = 0
            return
        end

        -- removing ingredients from input
        for _, buffer in pairs(cluster.input) do
            buffer[1] = buffer[1] - buffer[2] * max_crafts
        end
        -- adding products to output
        for _, buffer in pairs(cluster.output) do
            buffer[1] = buffer[1] + buffer[2] * max_crafts
        end
        cluster.last_cycle_crafts = max_crafts
    end
end

-- On-tick cluster crafting processor
function Helper.process_clusters(event)
    local array = storage.cluster_list
    local offset = event.tick % 60
    for i = #array - offset, 1, -60 do
        local cluster = array[i]
        if cluster.deleted then
            -- moving cluster to the last position and deleting it
            local last_cluster = array[#array]
            array[i] = last_cluster
            array[#array] = nil
        else
            perform_craft(cluster)
        end
    end
end

return Helper