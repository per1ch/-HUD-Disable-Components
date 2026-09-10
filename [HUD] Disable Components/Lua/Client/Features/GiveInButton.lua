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
