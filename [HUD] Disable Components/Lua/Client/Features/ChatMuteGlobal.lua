-- Lua/Client/Features/ChatMuteGlobal.lua — CLIENT
-- Spec item 16, global half: block chat for every player at once.
--
-- Real enforcement is server-side (Server/Moderation.lua drops messages
-- from muted senders before they are ever broadcast, and the server honours
-- that hook's return value). This client half only handles the local
-- presentation: the chat box is hidden and the input field is disabled, so
-- a muted player sees a blocked chat rather than typing into a void and
-- wondering why nobody answers.
--
-- This module used to patch ChatBox.AddToGUIUpdateList and
-- ChatBox.SelectInputBox. Barotrauma.ChatBox has neither method — it is not
-- a GUIComponent, just a class holding a GUIFrame — so both patches failed
-- at load. What was left was a think hook reading
-- GameMain.GameSession.CrewManager.ChatBox, and CrewManager assigns that
-- field only inside `if (IsSinglePlayer)`. On a server it is null, so the
-- hook returned on its second line every frame and the whole client half
-- did nothing. Messages were still dropped server-side, which is why the
-- setting looked broken rather than absent: chat kept its box and its
-- caret, and simply swallowed everything typed into it.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "MuteChatGlobal"

local function enabled()
    return ClientState.Get(KEY)
end

-- ChatBox.GetChatBox() is the accessor that resolves correctly in both
-- modes: CrewManager's box in singleplayer, GameMain.Client's on a server.
local chatBoxType = nil
local function chatBox()
    if chatBoxType == nil then
        chatBoxType = Safe.Static("Barotrauma.ChatBox")
    end
    if chatBoxType == nil then return nil end
    return Safe.Get(function() return chatBoxType.GetChatBox() end)
end

-- Tracks whether this module is the reason the box is hidden, so releasing
-- the setting restores it exactly once instead of fighting the player's own
-- chat toggle for the rest of the round.
local hiddenByUs = false

Safe.AddHook("think", "HDC.ChatMuteGlobal.Apply", function()
    local box = chatBox()
    if box == nil then return end

    if not enabled() then
        if hiddenByUs then
            Safe.Set(function() box.SetVisibility(true) end)
            Safe.Set(function() box.InputBox.Enabled = true end)
            hiddenByUs = false
        end
        return
    end

    -- Re-applied every frame rather than once on the transition: a round
    -- change builds a fresh ChatBox, and a new one starts visible.
    Safe.Set(function() box.SetVisibility(false) end)
    Safe.Set(function() box.InputBox.Enabled = false end)
    hiddenByUs = true

    -- Only cleared when there is something to clear. Writing InputBox.Text
    -- fires OnTextChanged, which is wired to ChatBox.TypingChatMessage and
    -- puts a "typing" notice on the wire — blanking it unconditionally
    -- would send one of those every frame.
    local typed = Safe.Get(function() return tostring(box.InputBox.Text) end)
    if typed ~= nil and typed ~= "" then
        Safe.Set(function() box.InputBox.Text = "" end)
    end

    -- Hand the keyboard back if the player was mid-sentence when the mute
    -- landed, otherwise their keystrokes keep going to an invisible field.
    if Safe.Get(function() return box.InputBox.Selected end) == true then
        Safe.Set(function() box.InputBox.Deselect() end)
    end
end)
