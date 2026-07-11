-- This file is for managing parameters of entities added by this mod.
-- For example: flow limits of mainframe-IOs.

local EntityParams = {}

local PREFIX = "FV-"

-- Initializes values to their defaults
function EntityParams.storage_init()
    storage.entity_params = {
        [PREFIX .. "mainframe-item-io"] = {
            flow_limit = 500,
        },
        [PREFIX .. "mainframe-fluid-io"] = {
            flow_limit = 10000,
        },
        [PREFIX .. "mainframe-energy-io"] = {
            flow_limit = 1e9, -- 1GW
        },
    }
end

function EntityParams.get_entity_params(entity_name)
    return storage.entity_params[entity_name]
end

return EntityParams