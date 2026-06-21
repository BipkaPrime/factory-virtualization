-- Template dashboards is a gui window that displays information
-- about current state of all venvs there are.


Helper = {}


function Helper.storage_init()
    -- we need to track all players who have dashboard opened for updating it
    -- keys: player ids, value = true
    storage.dashboard_opened = {}
end

