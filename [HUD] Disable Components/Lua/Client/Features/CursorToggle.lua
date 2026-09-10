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

return nil
