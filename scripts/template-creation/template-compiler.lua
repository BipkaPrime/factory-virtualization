--[[
This file is used to convert venv into compiled template.

-------------------------------------------------------------------------------
TEMPLATE INFO
-------------------------------------------------------------------------------
Once remaining time of a given venv runs out and there are no problems,
template is created from venv. After this venv is deleted.
IMPORTANT: keys are only created when required. For example, if venv didn't have
any inputs greater than 0, key "input" will not be created in template.

Compiled template can have following keys:
research_template bool: true if this is a research template
building_cost table: contains items needed for construction of this template.
    Same 2-level structure as item inputs/outputs.
energy_drain float: energy drain of this template
input table: {items = {}, fluids = {}, energy = 0} inputs per second.
output table: {items = {}, fluids = {}, energy = 0} outputs per second.
science table: {labs_potential = {}, logistics_potential = {}, points_per_item = {}}.
    All inner tables are hashmaps. For all tables, the key is ingredient name.
    For labs_potential and logistics_potential value is research points per second.
    For points_per_item value is number of research points produced per 1 spent item.
    These values are calculated for normal quality items.
--]]


local Helper = {}

-------------------------------------------------------------------------------
-- INITIALIZATION OF TECHNICAL FORCE USED FOR COMPILING RESEARCH TEMPLATES
-------------------------------------------------------------------------------

-- Collects and enables all technical research and saves it to storage
local technical_research_prefix = "FV-technical-"
local function collect_technical_research()
    local lab_tech = game.forces["lab-technical"].technologies
    -- going through prototypes and identifying technical research by prefix
    for tech_name, tech_prototype in pairs(prototypes.technology) do
        if tech_name:find("^" .. technical_research_prefix) then
            local first_ingredient = tech_prototype.research_unit_ingredients[1]
            local tech_data = {
                tech_name = tech_name,
                ingredient_name = first_ingredient.name
            }
            table.insert(storage.technical_research, tech_data)
            -- enabling technology for lab force
            lab_tech[tech_name].enabled = true
        end
    end
end

function Helper.init_lab_force()
    -- creating technical force if it doesn't exist
    if not game.forces["lab-technical"] then
        game.create_force("lab-technical")
    end
    local lab_force = game.forces["lab-technical"]
    -- copying all player force data to match progress
    lab_force.copy_from("player")
    storage.technical_research = {}
    collect_technical_research()
    lab_force.disable_research()
    local player_force = game.forces["player"]
    game.forces["player"].set_friend(lab_force, true)
    game.forces["lab-technical"].set_friend(player_force, true)
end

-------------------------------------------------------------------------------
-- TEMPLATE CONSTRUCTOR
-------------------------------------------------------------------------------

-- Helps in template creation. Calculates input/output flow of
-- items/fluids/energy per second for a given venv and saves results
-- @param template_data table: results will be added here
-- @param venv table: contains data about compiling surface
-- @param io_category "input"/"output": category to process
-- @param type "items"/"fluids"/"energy": type to process
local function collect_io_flow(template_data, venv, io_category, type)
    local venv_section = venv[io_category][type]
    if type == "energy" then
        if venv_section > 0 then
            template_data[io_category] = template_data[io_category] or {}
            template_data[io_category][type] = venv_section / venv.compilation_time
        end
    else
        -- if venv section is empty, we can return
        if next(venv_section) == nil then return end
        -- otherwise we create a template section
        template_data[io_category] = template_data[io_category] or {}
        template_data[io_category][type] = template_data[io_category][type] or {}
        local template_section = template_data[io_category][type]
        if type == "fluids" then
            for fluid_name, amount in pairs(venv_section) do
                template_section[fluid_name] = amount / venv.compilation_time
            end
        else -- type == "items"
            for item_name, counts in pairs(venv_section) do
                template_section[item_name] = {}
                -- going through counts and qualities under the same item name
                for quality, count in pairs(counts) do
                    template_section[item_name][quality] = count / venv.compilation_time
                end
            end
        end
    end
end

-- Helps in template creation. Calculates science potential of given section
-- @param section "slow"/"fast"
local section_name_map = {slow = "labs_potential", fast = "logistics_potential"}
local function collect_science_generation(template_data, venv, section)
    local venv_section = venv.benchmark_results[section]
    -- checking that section is not empty
    if next(venv_section) == nil then return end
    -- creating section in template data
    local t_section = section_name_map[section]
    template_data.science = template_data.science or {}
    template_data.science[t_section] = {}
    local template_section = template_data.science[t_section]
    for ingredient, data in pairs(venv_section) do
        template_section[ingredient] = data.points / data.time
    end
end

-- Helps in template creation. Makes sure that sets of ingredient items in 
-- labs_potential and logistics_potentials match.
local function validate_science_generation(template_data)
    if not template_data.science then return end
    local labs_potential = template_data.science.labs_potential
    local logistics_potential = template_data.science.logistics_potential
    if not labs_potential or not logistics_potential then
        template_data.science = nil
        return
    end
    -- deleting items that are not present in logistics
    for item, _ in pairs(labs_potential) do
        if not logistics_potential[item] then
            labs_potential[item] = nil
        end
    end
    -- deleting items that are not present in labs
    for item, _ in pairs(logistics_potential) do
        if not labs_potential[item] then
            logistics_potential[item] = nil
        end
    end
    -- if nothing is left, erasing science section
    if not next(labs_potential) then
        template_data.science = nil
    end
end

-- Helps in template creation. Calculates research points per item.
-- Must be called after collecting science points generation.
local sections = {"slow", "fast"}
local function collect_science_ppi(template_data, venv)
    if not template_data.science then return end
    local pack_stats = {}
    -- going through both slow and fast sections
    for _, section in ipairs(sections) do
        -- getting to the right section
        local venv_section = venv.benchmark_results[section]
        for ingredient, data in pairs(venv_section) do
            -- collecting sum of points and time for each ingredient
            pack_stats[ingredient] = pack_stats[ingredient] or {points = 0, time = 0}
            pack_stats[ingredient].points = pack_stats[ingredient].points + data.points
            pack_stats[ingredient].time = pack_stats[ingredient].time + data.time
        end
    end
    -- calculating research points per item 
    template_data.science.points_per_item = {}
    for ingredient, data in pairs(pack_stats) do
        -- getting input data of current ingredient
        local ingredient_inputs = venv.input.items[ingredient]
        if ingredient_inputs then
            -- TODO: add support for quality research items
            local total_count = 0
            for quality, count in pairs(ingredient_inputs) do
                total_count = total_count + count
            end
            template_data.science.points_per_item[ingredient] = data.points / total_count
        else
            -- if ingredient not found, removing its science production
            template_data.science.labs_potential[ingredient] = nil
            template_data.science.logistics_potential[ingredient] = nil
        end
    end
    -- deleting points per item table if it's empty
    if next(template_data.science.points_per_item) == nil then
        template_data.science.points_per_item = nil
    end
end

-- Helps in calculation of building cost of a surface
local function add_to_cost(total_cost, name, count, quality)
    total_cost[name] = total_cost[name] or {}
    total_cost[name][quality] = (total_cost[name][quality] or 0) + count
end

-- Helper in template creation, collects building cost of a surface.
-- Surface is assumed to be valid.
local function collect_building_cost(template_data, surface)
    local total_cost = {}
    -- getting array[LuaEntity] containing all entities on given surface
    local entities = surface.find_entities()
    for _, entity in ipairs(entities) do
        -- counting only valid entities excluding ghosts
        if entity and entity.valid and entity.type ~= "entity-ghost" then
            -- getting array[ItemToPlace] or nil if entity can't be built
            local build_cost = entity.prototype.items_to_place_this
            if build_cost then
                -- getting LuaQualityPrototype of entity
                local quality = entity.quality
                add_to_cost(total_cost, build_cost[1].name, build_cost[1].count, quality.name)
                -- getting LuaInventory or nil if it does not exist
                local module_inv = entity.get_module_inventory()
                -- checking if entity has a module inventory and it's not empty
                if module_inv and not module_inv.is_empty() then
                    -- get_contents() returns an array of {name, count, quality_name}
                    for _, item in ipairs(module_inv.get_contents()) do
                        add_to_cost(total_cost, item.name, item.count, item.quality)
                    end
                end
            end
        end
    end
    -- if total cost is not empty, save it to template data
    if next(total_cost) then
        template_data.building_cost = total_cost
    end
end

-- Creates compiled production template.
local function create_production_template(venv, surface, template_name)
    local template_data = {type = venv.surface_type}
    collect_building_cost(template_data, surface)
    -- gathering surface area
    local settings = surface.map_gen_settings
    template_data.area = settings.width * settings.height
    -- gathering inputs 
    collect_io_flow(template_data, venv, "input", "items")
    collect_io_flow(template_data, venv, "input", "fluids")
    collect_io_flow(template_data, venv, "input", "energy")
    if venv.surface_type == 2 then
        -- gathering science generation and ppi
        collect_science_generation(template_data, venv, "slow")
        collect_science_generation(template_data, venv, "fast")
        validate_science_generation(template_data)
        collect_science_ppi(template_data, venv)
    else
        -- gathering outputs
        collect_io_flow(template_data, venv, "output", "items")
        collect_io_flow(template_data, venv, "output", "fluids")
        collect_io_flow(template_data, venv, "output", "energy")
    end
    storage.compiled_templates[template_name] = template_data
end

-- Creates compiled research template.
local function create_research_template(venv, surface, template_name)

end

