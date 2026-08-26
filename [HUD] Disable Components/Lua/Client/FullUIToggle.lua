-- Lua/Client/FullUIToggle.lua — CLIENT
-- Spec item 13: hide the whole player interface, via its own command.
--
-- Self-only: this is a local view preference, so it is not part of the
-- synced policy and needs no server round-trip. The settings menu itself
-- is deliberately exempt, otherwise a player who hid their UI would have
-- no way to reach the menu and turn it back on.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "HideOwnUI"

local function enabled()
    return ClientState.GetLocal(KEY)
end

-- Suppress the two top-level HUD draw calls. The pause menu and this
-- mod's own settings window draw through separate paths and stay usable.
Safe.PatchMethod("Barotrauma.CharacterHUD", "Draw", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

Safe.PatchMethod("Barotrauma.CharacterHUD", "AddToGUIUpdateList", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

Safe.PatchMethod("Barotrauma.CrewManager", "AddToGUIUpdateList", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

Safe.AddCommand("hdc_hideui", "Toggle your own interface on/off (affects only you).", function()
    local now = ClientState.ToggleLocal(KEY)
    print("[HDC] Your interface is now " .. (now and "HIDDEN" or "visible") .. ".")
end, nil, false)
