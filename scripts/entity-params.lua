-- This file is for managing parameters of entities added by this mod.
-- For example: flow limits of mainframe-IOs.

local Helper = {}

-- Initializes values to thier defaults
function Helper.storage_init()
    storage.entity_params = {
        [PREFIX .. "mainframe-item-io"] = {
            flow_limit = 1000,
        },
        [PREFIX .. "mainframe-fluid-io"] = {
            flow_limit = 10000,
        },
        [PREFIX .. "mainframe-energy-io"] = {
            flow_limit = 1e9, -- 1GW
        },
    }
end

return Helper