--[[
Opened guis added by this mod may need updates to display relevant information.
Updating a gui window can be computationally intense and can generate some garbage for GC.
Because of this, we can not fully update all opened GUIs every tick.

This file is used for scheduling gui updates. More specifically, it forms a ring buffer
from opened windows added to it. To add a window to this updater two following steps
must be taken:
1. During the file loading stage of runtime an update schema must be added
with add_schema(). An "update schema" consists of 2 parts. First is
function that should be used for updates of a window (later). Second is
schema "name" (string): it is used to tell apart update functions.
2. During regular event handling of runtime stage, opened window can be added
to the updater with register_gui(). Among other arguments it takes schema
name (used to decide which update function should be used) and a table
"gui_data", which must contain several fields mandatory for updater
operation (more info on this below). 

When updating a window, an update function is called and 2 arguments are passed
to it. First is "gui_data" (table), second is "update_cycle" (integer): it's a couter
for how many times this window was updated since it was added to the buffer; it can
be useful if you'd like to update something in your window once every n calls.

Also, before calling an update function on a window, several things are checked:
1. LuaPlayer, for which this window is opened, is valid. Otherwise the window
is "closed" internally and removed from update buffer.
2. LuaPlayer, for which this window is opened, is connected. Otherwise the window
is closed and removed from update buffer.
3. gui_data.opened == true. Otherwise the window is removed from update buffer.
4. schema_name points to an update funtion. Otherwise window is removed from update buffer.

Apart from everything mentioned above, updater serves one more purpose. It makes sure
that player.opened is syncronized with data in storage. When gui_data.opened == true
player.opened will be set to the window being updated.

Gui_data fields that are mandatory for operation of gui updater.
1. opened boolean|nil true if window is opened. Must be accurate. Used to remove
window from ring buffer of updater when window is closed.
2. elements.main_window LuaGuiElement: used to close the window and for
player.opened syncronization.

The updater operates on the following rules. Each tick it updates exactly one registered
window (or zero if empty). The buffer cannot contain more than one entry for a single
player_index. In case of a collision (aka. for some reason you are trying to register
a second entry for a given player_index), the older entry is always destroyed. Also, if
schema names do not match between the older and newer entries, the updater ensures that
the older window is closed before deleting the entry.

Everything related to this updater is located at:
storage.gui_updater = {
    array GuiUpdaterEntry[]: contains all registered entries, used as the ring buffer
    lookup table<player_index, GuiUpdaterEntry> maps player index to their entries
    next_index integeк points to the inxed in array that should be updated in the next iteration 
}
--]]

---A function used to update one gui window
---@alias gui_update_fun fun(gui_data: table, update_cycle: integer)
---@alias gui_data table must contain "opened" and "elements.main_window"

---@class GuiUpdaterEntry
---@field array_index integer index of this entry in the array
---@field player_index integer unique player identifier
---@field schema_name string unique update function identifier
---@field gui_data gui_data
---@field player LuaPlayer player for which window is opened
---@field update_cycle integer how many times this entry was updated


local GuiUpdater = {}

---Maps schema names to update functions
---@type table<string, gui_update_fun>
GuiUpdater.router = {}

---Adds update schema to update router
---@param name string
---@param updater gui_update_fun
function GuiUpdater.add_schema(name, updater)
    GuiUpdater.router[name] = updater
end

---Removes the given entry from the updater data structure.
---@param entry GuiUpdaterEntry
local function delete_entry(entry)
    local updater = storage.gui_updater
    ---@type GuiUpdaterEntry[]
    local array = updater.array
    ---@type table<integer, GuiUpdaterEntry>
    local lookup = updater.lookup

    -- replacing entry with the last element in the array
    local last_element = array[#array]
    local index = entry.array_index
    array[index] = array[#array]
    last_element.array_index = index

    -- deleting entry from both tables
    array[#array] = nil
    lookup[entry.player_index] = nil
end

---Ensures that the window corresponding to the given entry is closed
---and deletes the entry from the data structure.
---@param entry GuiUpdaterEntry
local function unregister_entry(entry)
    local gui_data = entry.gui_data
    if gui_data.opened then
        gui_data.opened = nil
        local main_window = gui_data.elements.main_window
        if main_window and main_window.valid then
            main_window.destroy()
        end
        gui_data.elements = nil
    end
    delete_entry(entry)
end

---Used to close a window opened for given player index.
---@param player_index integer unique player identifier
function GuiUpdater.close_window(player_index)
    local entry = storage.gui_updater.lookup[player_index]
    if not entry then return end
    unregister_entry(entry)
end

---Registers gui for on-tick updates
---@param schema_name string unique update function identifier
---@param gui_data gui_data gui window data
---@param player LuaPlayer assumed to be valid
function GuiUpdater.register_gui(schema_name, gui_data, player)
    local updater = storage.gui_updater
    ---@type GuiUpdaterEntry[]
    local array = updater.array
    ---@type table<integer, GuiUpdaterEntry>
    local lookup = updater.lookup

    -- checking for collisions on player_index
    local player_index = player.index
    local old_entry = lookup[player_index]
    if old_entry then
        local old_schema = old_entry.schema_name
        if old_schema ~= schema_name then
            -- closing old window and deleting entry
            unregister_entry(old_entry)
        else
            delete_entry(old_entry)
        end
    end

    -- creating and adding the entry for new window
    local array_index = #array + 1
    ---@type GuiUpdaterEntry
    local entry = {
        array_index = array_index,
        player_index = player_index,
        schema_name = schema_name,
        gui_data = gui_data,
        player = player,
        update_cycle = 1,
    }
    array[array_index] = entry
    lookup[player_index] = entry
end

---Time-based gui updater
function GuiUpdater.on_tick()
    local updater = storage.gui_updater
    local array = updater.array
    -- no windows to update: return
    if #array == 0 then return end

    -- getting entry we want to update this tick
    local index = updater.next_index
    if not array[index] then index = 1 end
    ---@type GuiUpdaterEntry
    local entry = array[index]

    -- removing entry from updater if player is not found
    -- in case player was removed from the game or smth
    local player = entry.player
    if not player.valid then
        unregister_entry(entry)
        return
    end

    -- closing the window in case player disconnected
    if not player.connected then
        unregister_entry(entry)
        return
    end

    -- syncronizing player.opened with opened window
    local gui_data = entry.gui_data
    if gui_data.opened then
        player.opened = gui_data.elements.main_window
    else
        delete_entry(entry)
        return
    end

    -- making sure handler is found in the router
    local update_function = GuiUpdater.router[entry.schema_name]
    if not update_function then
        unregister_entry(entry)
        return
    end

    local update_cycle = entry.update_cycle
    update_function(gui_data, update_cycle)
    entry.update_cycle = update_cycle + 1
    updater.next_index = index + 1
end

return GuiUpdater