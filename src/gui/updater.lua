--[[
Opened guis added by this mod may need updates to display relevant information.
This operation usually heavily impacts performance. Currently, updating all cluster information
in a window can take around ~0.5 ms on my computer, which is a lot.
Because of this, we can't update all opened GUIs every tick, because it can cause
performance issues in the multiplayer. Instead, we will update one opened window per tick.
This file is needed to enable this idea.

Currently there are 3 types of GUIs that can be opened: entity, template dashboard, vsurface manager.
Different windows should be updated using different functions. Since we can't simply save functions
in storage, we will have to get a bit creative. We will create a router that maps strings to functions.
These strings serve as unique updater identifiers and are called "schemas".
A gui file that adds a window that should be updated, must call add_schema function when loading.

This updater is also used to solve problems with strage gui behavior. For example:
After player changes surface with a window opened, player.opened can be assigned nil without
actually destroying the window. (Somehow on_gui_closed event was not triggering). I also encountered
similar behavior when going into editor mode.
To solve this problem, we should have the source of truth in the gui_data table. If window is opened
then gui_data.opened must be set to true. When updating a window, player.opened will be set
to gui_data.element.main_window in case gui_data.opened is set to true. This flag is also vital for
updater operation. It is used to automatically remove tables that have gui_data.opened ~= true.

Table in storage used by this gui updater is the following:
storage.opened_guis = {
    array = {},
    next_index = 1,
}
--]]

---Base class for table containing references to LuaGuiElements
---@class GuiElementsBase
---@field main_window LuaGuiElement main window that should be destroyed when closing the gui

---Base class for table containing gui data. All tables with gui data must contain these fields
---@class GuiDataBase
---@field opened boolean|nil true if window is opened
---@field elements GuiElementsBase|nil

---Union of all classes that inherit from GuiDataBase
---@alias GuiData
---|EntityGuiData
---|ControlCenterData

---Entry in the storage.opened_guis.array
---@class GuiUpdaterEntry
---@field schema string update function identifier
---@field gui_data GuiData
---@field player_index number unique player identifier

local GuiUpdater = {}

---Maps update schemas to functions that should be used for an update
---@type table<string, function>
GuiUpdater.router = {}

---Adds update schema to update router
---@param name string
---@param updater fun(gui_data: GuiData)
function GuiUpdater.add_schema(name, updater)
    GuiUpdater.router[name] = updater
end

---Registers gui for on-tick updates
---@param schema string
---@param gui_data GuiData
---@param player_index number
function GuiUpdater.register_gui(schema, gui_data, player_index)
    local arr = storage.opened_guis.array
    ---@type GuiUpdaterEntry
    local entry = {
        schema = schema,
        player_index = player_index,
        gui_data = gui_data,
    }
    table.insert(arr, entry)
end

---Removes entry from gui updater given its index
---@param index number 
local function unregister_gui(index)
    local arr = storage.opened_guis.array
    arr[index] = arr[#arr]
    table.remove(arr)
end

---Time-based updater for opened guis. Should be called every tick.
function GuiUpdater.update()
    -- if update array is empty, return
    local arr = storage.opened_guis.array
    if #arr == 0 then return end

    -- getting entry we want to update this tick
    local index = storage.opened_guis.next_index
    if not arr[index] then index = 1 end
    ---@type GuiUpdaterEntry
    local entry = arr[index]

    -- removing entry from updater if player is not found
    local player = game.get_player(entry.player_index)
    if not player then
        unregister_gui(index)
        return
    end

    -- closing window and removing it from updater if player disconnected
    local gui_data = entry.gui_data
    if not player.connected then
        local elements = gui_data.elements
        if elements and elements.main_window and elements.main_window.valid then
            elements.main_window.destroy()
            gui_data.elements = nil
            gui_data.opened = false
        end
        unregister_gui(index)
        return
    end

    -- making sure player.opened is correctly set to opened window    
    if gui_data.opened then
        player.opened = gui_data.elements.main_window
    else
        unregister_gui(index)
        return
    end

    -- making sure handler is found in the router
    local handler = GuiUpdater.router[entry.schema]
    if not handler then
        unregister_gui(index)
        return
    end

    handler(gui_data)
    storage.opened_guis.next_index = index + 1
end

return GuiUpdater