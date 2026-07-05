-- This file is for managing parameters of entities added by this mod.
-- For example: item/fluid/energy flow limits of uplink/downlinks.

local names = require("scripts.gui.names")

local Helper = {}

-- Initializes values to thier defaults
function Helper.storage_init()
    storage.entity_params = {
        [names.prefix .. "item-uplink"] = {
            flow_limit = 1000,
        },
        [names.prefix .. "item-downlink"] = {
            flow_limit = 1000,
        },
        [names.prefix .. "fluid-uplink"] = {
            flow_limit = 10000,
        },
        [names.prefix .. "fluid-downlink"] = {
            flow_limit = 10000,
        },
        [names.prefix .. "energy-uplink"] = {
            flow_limit = 1e9, -- 1GW
        },
        [names.prefix .. "energy-downlink"] = {
            flow_limit = 1e9, -- 1GW
        },
    }
end

return Helper