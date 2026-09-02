-- Lua/Client/Features/ItemHighlights.lua — CLIENT
-- Spec item 7: hide the selection outline / highlight drawn on
-- interactable items.
--
-- Only the outline rendering is suppressed — interaction itself is
-- untouched, so items remain usable, they simply stop glowing.
--
-- What the player actually sees on a focused item is drawn by
-- CharacterHUD.Draw, inside one block guarded by
--   focusedItem != null && focusedItemOverlayTimer > ItemOverlayDelay
-- which covers both the pulsing focus ring and the item's hover text. The
-- timer never exceeding the delay is therefore the whole feature, and it
-- costs a single field write per frame.
--
-- This module used to patch Item.DrawSelectionIndicator and
-- Item.UpdateHighlight. Neither method exists on Barotrauma.Item, so both
-- patches failed at load and the feature rested entirely on its fallback:
-- a think hook that walked Item.ItemList — every item on the submarine,
-- thousands of them — and ran two pcall-wrapped property writes on each,
-- every frame. That was the lag, and because HighlightColor and
-- IsHighlighted are not what draws the focus ring, it bought nothing.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "HideItemHighlights"

local function enabled()
    return ClientState.Get(KEY)
end

Safe.MakeFieldAccessible("Barotrauma.CharacterHUD", "focusedItemOverlayTimer")

local characterHUD = nil
local function hudStatic()
    if characterHUD == nil then
        characterHUD = Safe.Static("Barotrauma.CharacterHUD")
    end
    return characterHUD
end

Safe.AddHook("think", "HDC.ItemHighlights.Suppress", function()
    -- The vanilla switch for the interaction highlight, which the game
    -- checks itself. Written unconditionally so releasing the setting hands
    -- the flag straight back rather than leaving it stuck on.
    local gui = Safe.GUIStatic()
    if gui ~= nil then
        Safe.Set(function() gui.DisableItemHighlights = enabled() end)
    end

    if not enabled() then return end

    local hud = hudStatic()
    if hud == nil then return end
    Safe.Set(function() hud.focusedItemOverlayTimer = 0 end)
end)
