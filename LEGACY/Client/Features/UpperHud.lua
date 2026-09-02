-- Lua/Client/Features/UpperHud.lua — CLIENT
-- Spec item 10: hide the upper HUD crew panel and the respawn / round-end
-- timers, and keep an !alive command for checking crew status.
--
-- IMPORTANT — why this is done by rendering only:
-- The reference mod for this feature hides players by REMOVING them from
-- the underlying crew/client list. That is the cause of its three known
-- bugs: bot commands break, players can no longer be selected in the tab
-- menu (forcing console bans), and the round-end screen reports "your team
-- died on a mission" even after a success, because the game genuinely
-- believes the crew is gone.
--
-- This module therefore never touches the real list. It suppresses the
-- draw/update calls only, so the game's own state stays fully intact and
-- every one of those bugs is avoided by construction.
--
-- Team handling: the suppression is team-agnostic. It applies to the crew
-- panel regardless of which TeamID it is rendering, which is why entries
-- do not "show through" for Team 1 in two-team modes (PvP/Traitor) the way
-- they do in the reference mod. Bots are ordinary characters on a team and
-- are covered by the same pass, with no special-casing.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "HideUpperHud"

local function enabled()
    return ClientState.Get(KEY)
end

-- Crew status panel (the upper-HUD list of crew members).
Safe.PatchMethod("Barotrauma.CrewManager", "DrawCharacterOrder", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

Safe.PatchMethod("Barotrauma.CrewManager", "AddToGUIUpdateList", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

Safe.PatchMethod("Barotrauma.CrewManager", "UpdateCrewListIndicators", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

-- Respawn timer / respawn shuttle countdown.
Safe.PatchMethod("Barotrauma.RespawnManager", "DrawRespawnInfo", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

-- Round-end / mission countdown readout.
Safe.PatchMethod("Barotrauma.GameSession", "DrawRoundInfo", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

-- Fallback: hide the crew frame outright if a draw path above was renamed
-- in a game update. Visibility only — the list contents stay untouched.
Safe.AddHook("think", "HDC.UpperHud.HideFrames", function()
    if not enabled() then return end
    local crew = Safe.Get(function() return GameMain.GameSession.CrewManager end)
    if crew == nil then return end
    Safe.Set(function() crew.GetCrewFrame().Visible = false end)
end)
