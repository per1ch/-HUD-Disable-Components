-- Lua/Client/Features/QuickMarkIcons.lua — CLIENT
-- Spec item 15: hide the quick-marker icons (fire, breach, intruder, …)
-- shown beside the chat box, while leaving chat messages themselves
-- visible.
--
-- Only the icon buttons of the report/order bar are hidden. The chat log
-- next to them is a separate component and is not touched, which is what
-- keeps messages readable.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "HideQuickMarkIcons"

local function enabled()
    return ClientState.Get(KEY)
end

-- The report-button row built by the crew manager next to the chat box.
Safe.PatchMethod("Barotrauma.CrewManager", "CreateReportButtons", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

Safe.PatchMethod("Barotrauma.CrewManager", "UpdateReportButtons", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

-- If the buttons already exist (toggle flipped mid-round), hide the
-- container instead of rebuilding it.
Safe.AddHook("think", "HDC.QuickMarkIcons.HideContainer", function()
    if not enabled() then return end
    local crew = Safe.Get(function() return GameMain.GameSession.CrewManager end)
    if crew == nil then return end
    Safe.Set(function() crew.ReportButtonFrame.Visible = false end)
end)
