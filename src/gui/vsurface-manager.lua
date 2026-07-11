--[[
Vsurface manager is a gui window that allows players to manage virtualization
surfaces: create, destroy, start compilation, see information, etc.



--------------------------------------------------------------------------------------------
-- STORAGE KEYS FOR CONVENIENCE
--------------------------------------------------------------------------------------------
-- table = storage.surface_manager[playaer_index]. table keys:
-- elements.main_window LuaGuiElement: reference to main widow (to destroy it when needed)
-- elements.vsurface_selector LuaGuiElement: reference to selector element on the left side
-- elements.create_surface_btn LuaGuiElement: reference to "create new surface" button
-- elements.delete_surface_btn LuaGuiElement: reference to "delete selected surface" button
-- elements.right_frame LuaGuiElement: reference to frame on the right side of interface
-- elements.new_surface_drain LuaGuiElement: reference to new surface energy drain label
-- element.compile_btn LuaGuiElement: reference to compile button
-- elements.compile_btn_status LuaGuiElement: reference to status label above compile button
-- elements.new_surface_confirm LuaGuiElement: reference to confirm create new surface btn
-- elements.new_surface_confirm_status LuaGuiElement: reference to status label above confirm create btn
-- elements.compile_bar_label LuaGuiElement: reference to label above compilation progressbar
-- elements.compile_progressbar LuaGuiElement: reference to progressbar indicating surface compilation progress
-- elements.template_name_textfield LuaGuiElement: reference to template name textfield element
-- elements.template_name_label LuaGuiElement: refenrence label above template name textfield
-- opened bool: indicates if surface manager is currently opened
-- vsurface_search_query string: last user input into vsurface searchfield
-- selected_vsurface string: surface name selected in the selector
-- new_surface_pressed bool: indicates if "create new surface" button is pressed
-- new_surface_size int: chosen surface size dropdown index. (1 = 64 x 64; 2 = 128 x 128; etc)
-- new_surface_type int: chosen surface type dropdown index. (1 = "production", 2 = "science")
-- new_surface_name string: last user input into new surface name textfield
-- template_name string: last user input into template name textfield
--]]