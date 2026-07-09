-- This file used to enable proper copy-paste for buildings with
-- custom data in entity registry.

-- TODO: improve user experience
-- on_blueprint_settings_pasted
-- on_entity_cloned 
-- on_entity_settings_pasted
-- on_player_configured_blueprint
-- on_redo_applied (probably will never be supported)
-- on_undo_applied (probably will never be supported)

local util = require("util")
local entity_processor = require("scripts.entity-processor")

-- table containing names of all entities that require
-- custom tags to be added to the blueprint
local entities_with_custom_data = {
    [PREFIX .. "template-item-io"] = true,
    [PREFIX .. "template-fluid-io"] = true,
    [PREFIX .. "template-energy-io"] = true,
    [PREFIX .. "mainframe-item-io"] = true,
    [PREFIX .. "mainframe-fluid-io"] = true,
    [PREFIX .. "mainframe-energy-io"] = true,
    [PREFIX .. "virtualization-mainframe"] = true,
}
-- table containing all fields from entity properties that should be copied.
-- Basically only fields that user can directly influence from GUI.
local copyable_fields = {
    selected_template = true,
    selected_item = true,
    selected_fluid = true,
    is_output = true,
}
-- Handles player setting up blueprint.
script.on_event(defines.events.on_player_setup_blueprint, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local blueprint = event.stack
    if not blueprint then return end
    -- maps blueprint entity index to "real world" entity
    local mapping = event.mapping.get()

    for b_entity_index, entity in ipairs(mapping) do
        if not entity or not entity.valid then goto continue end
        -- skipping entities that do not need tags
        if not entities_with_custom_data[entity.name] then goto continue end

        -- if registry does not have entity properties we have to skip it
        local properties = entity_processor.get_entity_data(entity.unit_number)
        if not properties then goto continue end
        local entity_tags = blueprint.get_blueprint_entity_tags(b_entity_index) or {}

        -- creating our own section in tags and adding all copyable properties there
        local tag_key = PREFIX
        entity_tags[tag_key] = {}
        local tag_section = entity_tags[tag_key]
        for field, _ in pairs(copyable_fields) do
            local value = properties[field]
            if value and type(value) == "table" then
                tag_section[field] = util.table.deepcopy(value)
            else
                tag_section[field] = value
            end
        end
        blueprint.set_blueprint_entity_tags(b_entity_index, entity_tags)
        ::continue::
    end
end)