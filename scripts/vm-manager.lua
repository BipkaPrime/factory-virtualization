-- File for virtualization mainframe logic


local Helper = {}


function Helper.storage_init()
    -- key: surface id, value:table containing virtual_environments
    -- virtual_environments table: keys: compiled_template name, value: table describing venv
    -- like stored energy, stored resources, stored finished product, etc.
    storage.virtual_environments = storage.virtual_environments or {}
end

return Helper