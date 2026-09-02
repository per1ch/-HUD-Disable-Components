-- Lua/Client/Features/GiveInButton.lua — CLIENT
-- Spec item 11: neutralise the "Give In" (surrender/suicide) button.
--
-- The button is CharacterHealth.SuicideButton, a public property, so it can
-- be reached directly. CharacterHealth.UpdateClientSpecific re-decides its
-- Visible flag every update, which is why hiding it belongs on a per-frame
-- hook rather than a one-shot: anything set once is overwritten on the next
-- update. Nothing in the game writes Enabled, so that half is this module's
-- to hold and to give back.
--
-- Hiding it is also what disables it: CharacterHealth only calls
-- SuicideButton.AddToGUIUpdateList() when the button is visible, so an
-- invisible button is never in the update list to be clicked. Enabled is
-- cleared as well so the state is explicit rather than incidental.
--
-- This module previously searched the whole canvas each frame for a button
-- whose text matched a "Give In" translation, and patched
-- Character.GiveInToPressure. No such method exists on Character, so that
-- patch failed at load, and the canvas search went through
-- Safe.WalkComponents, which did not descend past its own root.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "DisableGiveIn"

local function enabled()
    return ClientState.Get(KEY)
end

Safe.AddHook("think", "HDC.GiveInButton.Disable", function()
    local button = Safe.Get(function()
        return Character.Controlled.CharacterHealth.SuicideButton
    end)
    if button == nil then return end

    local off = enabled()
    Safe.Set(function() button.Enabled = not off end)
    if off then
        Safe.Set(function() button.Visible = false end)
    end
end)
