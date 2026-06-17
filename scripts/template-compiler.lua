-- This file contains logic used to track all compiled production templates

local Helper = {}


function Helper.storage_init()
    -- keys are template names, values are templates
    storage.compiled_templates = storage.compiled_templates or {}

    -- placeholder 
    storage.compiled_templates["iron plates"] = {}
    storage.compiled_templates["electronic circuits"] = {}
    storage.compiled_templates["compiled_template3"] = {}

    -- key: surface id, value:table containing virtual_environments
    -- virtual_environments table: keys: compiled_template name, value: table describing venv
    -- like consumption/sec, production/sec, pollution/sec, materials to build, etc.
    storage.virtual_environments = storage.virtual_environments or {}
end


return Helper