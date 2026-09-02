-- Lua/Client/Features/QuickMarkIcons.lua — CLIENT
-- Spec item 15: hide the quick-marker icons (fire, breach, intruder, …)
-- shown beside the chat box, while leaving chat messages themselves
-- visible.
--
-- Only the icon buttons of the report bar are hidden. The chat log next to
-- them is a separate component and is not touched, which is what keeps
-- messages readable.
--
-- CrewManager creates ReportButtonFrame already hidden (Visible = false)
-- and CrewManager.UpdateReports is the only thing that ever shows it
-- again, once per tick. Suppressing that one call therefore leaves the
-- frame in the state the game itself built it in.
--
-- This module previously patched CreateReportButtons and a method named
-- UpdateReportButtons. The real method is UpdateReports, so that patch
-- failed at load; and CreateReportButtons is the one-shot builder, so
-- blocking it destroyed the buttons for the rest of the session instead of
-- hiding them, leaving nothing to show when the setting was turned off
-- again.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "HideQuickMarkIcons"

local function enabled()
    return ClientState.Get(KEY)
end

local function reportButtons()
    return Safe.Get(function() return GameMain.GameSession.CrewManager.ReportButtonFrame end)
end

Safe.PatchMethod("Barotrauma.CrewManager", "UpdateReports", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

-- If the bar was already on screen when the setting was switched on, the
-- suppressed update will never hide it. One pass on the change does.
ClientState.AddChangeListener(function()
    if not enabled() then return end
    local frame = reportButtons()
    if frame == nil then return end
    Safe.Set(function() frame.Visible = false end)
end)
