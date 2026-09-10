-- Lua/Client/CursorToggle.lua — CLIENT
-- Policy is synced like any other feature. When on, the player's cursor is
-- hidden while aiming (ranged weapon or turret). When off, we touch nothing
-- and vanilla behavior rules.
--
-- Two mechanisms, belt-and-braces:
--   1. Set GUI.HideCursor, which is the flag vanilla's own aiming logic
--      reads. Covers the case where DrawCursor checks it.
--   2. Patch GUI.DrawCursor Before, setting PreventExecution. Covers the
--      case where DrawCursor is called unconditionally and the flag alone
--      would not be enough.
-- Either mechanism alone is sufficient in a healthy build; together they
-- do not conflict, because both consult the same predicate.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "HideCursor"

local function isAiming()
    return Safe.Get(function()
        local c = Character.Controlled
        if c == nil or c.IsDead == true then return false end
        return c.IsAiming == true
    end) == true
end

local function shouldHideCursor()
    if ClientState.Get(KEY) ~= true then return false end
    if Safe.Get(function() return GUI.PauseMenuOpen end) == true then return false end
    return isAiming()
end

-- Mechanism 1: keep the flag in sync. Only written while the policy is on,
-- so disabling the feature leaves vanilla's own flag handling alone.
Safe.AddHook("think", "HDC.CursorToggle.Think", function()
    if ClientState.Get(KEY) ~= true then return end
    local want = shouldHideCursor()
    Safe.Set(function()
        if GUI.HideCursor ~= want then GUI.HideCursor = want end
    end)
end)

-- Mechanism 2: suppress the draw call itself. Runs Before so we can set
-- PreventExecution; DrawCursor still runs normally when the predicate is
-- false. No per-frame work here beyond the predicate.
Safe.PatchMethod("Barotrauma.GUI", "DrawCursor", nil, function(instance, ptable)
    if shouldHideCursor() then
        ptable.PreventExecution = true
    end
end, Hook.HookMethodType.Before)
