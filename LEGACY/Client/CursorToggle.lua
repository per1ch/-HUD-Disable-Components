-- Lua/Client/CursorToggle.lua — CLIENT
-- Spec item 14: hide the player's own mouse cursor, via its own command.
--
-- Self-only, like item 13. The cursor is restored automatically whenever
-- the settings menu or pause menu is open, so a player can never lock
-- themselves out of clicking their way back.

HDC = HDC or {}

local Safe         = HDC.Safe
local ClientState  = HDC.ClientState
local SettingsMenu = HDC.SettingsMenu

local KEY = "HideOwnCursor"

local function menuNeedsCursor()
    if SettingsMenu ~= nil and SettingsMenu.IsOpen() then return true end
    return Safe.Get(function() return GUI.PauseMenuOpen end) == true
end

local function enabled()
    if not ClientState.GetLocal(KEY) then return false end
    return not menuNeedsCursor()
end

Safe.PatchMethod("Barotrauma.GUI", "DrawCursor", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

Safe.AddCommand("hdc_hidecursor", "Toggle your own mouse cursor on/off (affects only you).", function()
    local now = ClientState.ToggleLocal(KEY)
    print("[HDC] Your cursor is now " .. (now and "HIDDEN" or "visible") ..
          ". (It reappears while a menu is open.)")
end, nil, false)
