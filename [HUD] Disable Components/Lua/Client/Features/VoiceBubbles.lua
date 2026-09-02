-- Lua/Client/Features/VoiceBubbles.lua — CLIENT
-- Spec item 5: hide the voice-chat bubble above speaking characters.
--
-- The local player's own indicator is left alone — a player still needs
-- to see that their own microphone is transmitting. Only other people's
-- bubbles are suppressed.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "HideVoiceBubbles"

Safe.MakeFieldAccessible("Barotrauma.Character", "textlessSpeechBubble")

local function enabled()
    return ClientState.Get(KEY)
end

local function isLocalPlayer(character)
    if character == nil then return false end
    if Safe.Get(function() return character.IsLocalPlayer end) == true then return true end
    local controlled = Safe.Get(function() return Character.Controlled end)
    return controlled ~= nil and controlled == character
end

local function suppressBubble(instance, ptable)
    if not enabled() then return end
    if instance == nil then
        ptable.PreventExecution = true
        return
    end
    if isLocalPlayer(instance) then return end
    Safe.Set(function() instance.textlessSpeechBubble = nil end)
    ptable.PreventExecution = true
end

-- Preferred overload; falls back to signature-less resolution if the
-- parameter list has changed between game versions.
local patched = Safe.PatchMethod("Barotrauma.Character", "ShowTextlessSpeechBubble", {
    "System.Single", "Microsoft.Xna.Framework.Color"
}, suppressBubble, Hook.HookMethodType.Before)

if not patched then
    Safe.PatchMethod("Barotrauma.Character", "ShowTextlessSpeechBubble", nil,
        suppressBubble, Hook.HookMethodType.Before)
end

-- Clearing the field as DrawFront begins is what actually hides the bubble,
-- and it is not redundant with the patch above. The bubble is drawn at the
-- end of Character.DrawFront straight out of this field, and VoipClient
-- recreates it on every incoming voice packet — so a sweep on a separate
-- schedule (this module previously used a think hook over CharacterList)
-- always loses to a packet that lands between the sweep and the draw. Here
-- there is no gap: the field is cleared inside the call that reads it.
Safe.PatchMethod("Barotrauma.Character", "DrawFront", {
    "Microsoft.Xna.Framework.Graphics.SpriteBatch",
    "Barotrauma.Camera"
}, function(instance, ptable)
    if not enabled() then return end
    if instance == nil or isLocalPlayer(instance) then return end
    Safe.Set(function() instance.textlessSpeechBubble = nil end)
end, Hook.HookMethodType.Before)
