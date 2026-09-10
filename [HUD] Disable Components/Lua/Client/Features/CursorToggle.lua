HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "HideOwnCursor"

local TICK_MS = 1000  -- 10 Hz; plenty fast for a cursor flag, cheap enough to run forever

local function shouldHideCursor()
    if ClientState.GetLocal(KEY) ~= true then return false end
    if Safe.Get(function() return GUI.PauseMenuOpen end) == true then return false end

    local controlled = Safe.Get(function()
        local c = Character.Controlled
        if c == nil then return false end
        if c.IsDead == true then return false end
        return true
    end)
    return controlled == true
end

local function applyCursorFlag()
    local wantHidden = shouldHideCursor()
    Safe.Set(function()
        if GUI.HideCursor ~= wantHidden then GUI.HideCursor = wantHidden end
    end)
end

local function tick()
    applyCursorFlag()
    Safe.Set(function()
        Timer.Wait(function() tick() end, TICK_MS)
    end)
end

tick()
