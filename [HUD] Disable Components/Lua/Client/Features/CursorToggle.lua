HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "HideCursor"

Safe.MakeFieldAccessible("Barotrauma.GUI", "HideCursor")

local function enabled()
    return ClientState.Get(KEY)
end

Safe.PatchMethod("Barotrauma.GUI", "HideCursor", nil, function(instance, ptable)
    if not enabled() then return end
    if instance == nil then return end
    stripLinks(Safe.Get(function() return instance.chatBox.Content end))
end, Hook.HookMethodType.After)
