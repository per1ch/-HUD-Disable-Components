--https://github.com/FakeFishGames/Barotrauma/blob/master/Barotrauma/BarotraumaClient/ClientSource/GUI/GUI.cs
--https://github.com/FakeFishGames/Barotrauma/blob/master/Barotrauma/BarotraumaClient/ClientSource/Characters/Character.cs
-- Lua/Client/CursorToggle.lua — CLIENT
-- Policy is synced like any other feature. When on, the cursor is hidden
-- while the player holds the Aim input (ranged weapon or turret).
--
-- Aiming is not a Character property; vanilla checks the Aim input via
-- Character.IsKeyDown(InputType.Aim). We do the same.
--
-- GUI.HideCursor is a public static bool, not a method — write the flag,
-- do not patch. DrawCursor is also patched as a belt-and-braces suppress
-- in case the flag alone isn't enough in a given build.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "HideCursor"

local function isAiming()
    return Safe.Get(function()
        local c = Character.Controlled
        if c == nil or c.IsDead == true then return false end
        return c.IsKeyDown(InputType.Aim) == true
    end) == true
end

local function shouldHideCursor()
    if ClientState.Get(KEY) ~= true then return false end
    if Safe.Get(function() return GUI.PauseMenuOpen end) == true then return false end
    return isAiming()
end

Safe.AddHook("think", "HDC.CursorToggle.Think", function()
    -- When the policy is off, do not write the flag at all: leaving it
    -- alone lets vanilla's own aiming logic decide, which is what "off"
    -- should mean.
    if ClientState.Get(KEY) ~= true then return end
    local want = shouldHideCursor()
    Safe.Set(function()
        if GUI.HideCursor ~= want then GUI.HideCursor = want end
    end)
end)

Safe.PatchMethod("Barotrauma.GUI", "DrawCursor", nil, function(instance, ptable)
    if shouldHideCursor() then
        ptable.PreventExecution = true
    end
end, Hook.HookMethodType.Before)
