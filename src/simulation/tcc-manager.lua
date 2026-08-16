--[[
Template control center is a building that serves a purpose of central hub
needed from template compilation. It's vital for operation of the template system.
This file contains logic necessery to control this system.

Template control manager consists of 3 parts:

I. Hub manager. In order to system to function in any capacity, template control center
entity must exist on proper surface (aquilo), have enough electric energy, etc.
Hub manager is needed to keep track of tcc entity. It's tier, existance, surface it's
located on, etc. If control center entity is not registered (or is unregistered),
computation and all compiled templates temporaty become inaccesible.

II. Computation manager. Computation is a resource required to sustain the existence of
virtualization surfaces as well as for their compilation. It's a flow variable and can't
be stored in any way. Manager allows to control required and available computation. Also
can be used to conveniently get computation-related information.

III. Template storage. Templates are essentially black-box mathematical models of a
production line with defined inputs, outputs, construction costs, etc. Each template
has a display name that is shown to the user and unique identifier that is assigned to
the template at the moment of creation and can't be changed. Templates are used by
virtualization clusters to "craft" template outputs from template inputs. Another
important thing to keep in mind is that templates must be accesible in order to be
used. According to mod's lore templates are "stored" in template control center and
are automatically accessible on the surface where control center entity is located.

Data structure:
storage.template_hub = {
    hub = 
    templates

}


--]]

local util = require("util")


local TCCManager = {}

-------------------------------------------------------------------------------
------------------------------ TEMPLATE STORAGE -------------------------------
-------------------------------------------------------------------------------

---@alias template_uuid string template identifier, assigned at creation
---@alias template_name string display name of template that is shown to player
---@alias surface_index integer unique surface identifier
---Both uuid and display name must be unique among all templates

---Contains data of one compiled template
---@class TemplateData
---@field input table<BufferKeyString, number> input per second
---@field output table<BufferKeyString, number> output per second
---@field building_cost table<BufferKeyString, number> items needed for construction of this template
---@field energy_drain number energy drain of this template

---Contains data of all compiled templates
---@class TemplateStorage 
---@field template_lookup table<template_uuid, TemplateData> maps template uuid
---to template data. Used to store all template data.
---@field name_to_uuid table<template_name, template_uuid>
---@field uuid_to_name table<template_uuid, template_name>
---@field broadcasting table<template_uuid, integer> contains uuids of all
---broadcasting templates (value is number of broadcasters)
---@field receiving_by_surface table<surface_index, table<template_uuid, integer>> 
---groups template receivers by surface (value is number of receivers)
---@field receiving_by_uuid table<template_uuid, table<surface_index, integer>>
---groups template receivers by template_uuid (value is number of receivers)


---Generates uuid for a template for internal use.
---@param name template_name display name that is shown to player
---@return template_uuid uuid unique template identifier 
local function generate_template_uuid(name)
    local uuid = string.format(
        "%s//%d//%.9f",
        name,
        game.tick,
        math.random()
    )
    return uuid
end

---Saves given template to template storage
---@param template TemplateData
---@param name template_name display name
---@return template_name name unique name of saved template
function TCCManager.add_template(template, name)
    ---@type TemplateStorage
    local templates = storage.template_hub.templates

    -- making sure that name is not occupied
    local name_to_uuid = templates.name_to_uuid
    local unique_name = name
    local suffix = 1
    while name_to_uuid[unique_name] do
        unique_name = name .. " (" .. suffix .. ")"
        suffix = suffix + 1
    end

    -- generating template uuid and saving template to storage
    local uuid = generate_template_uuid(unique_name)
    templates.template_lookup[uuid] = template
    name_to_uuid[unique_name] = uuid
    templates.uuid_to_name[uuid] = unique_name
    return unique_name
end

---Creates a copy of given template
---@param name template_name display name
---@return boolean status true if copy was successfully created
---@return template_name|LocalisedString result name of new template or error string
function TCCManager.copy_template(name)
    ---@type TemplateStorage
    local templates = storage.template_hub.templates
    local uuid = templates.name_to_uuid[name]
    if not uuid then
        return false, "[Template storage] [color=red]Error:[/color] copy failed: template data not found"
    end
    local template = templates.template_lookup[uuid]
    local template_copy = util.copy(template)
    local copy_name = TCCManager.add_template(template_copy, name)
    return true, copy_name
end

---Changes display name for a given template
---@param old_name template_name
---@param new_name template_name
---@return boolean status true if template was successfully renamed
---@return LocalisedString|nil reason error string if rename failed
function TCCManager.rename_template(old_name, new_name)
    -- safety check: old_name key will be erased from lookup tables
    if old_name == new_name then return true end

    ---@type TemplateStorage
    local templates = storage.template_hub.templates
    local name_to_uuid = templates.name_to_uuid
    local uuid = name_to_uuid[old_name]

    -- checking that template is found
    if not uuid then
        return false, "[Template storage] [color=red]Error:[/color] rename failed: template data not found"
    end
    -- checking that new name is free
    if name_to_uuid[new_name] then
        return false, "[Template storage] [color=red]Error:[/color] rename failed: new name is occupied"
    end

    -- everything is ok: renaming template
    name_to_uuid[new_name] = uuid
    name_to_uuid[old_name] = nil
    templates.uuid_to_name[uuid] = new_name
    return true
end

---Deletes provided template from storage
---@param name template_name display name
---@return boolean status true if deletion was successful
---@return LocalisedString|nil reason error string if deletion failed
function TCCManager.delete_template(name)
    

end