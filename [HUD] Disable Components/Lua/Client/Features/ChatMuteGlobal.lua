-- Lua/Client/Features/ChatMuteGlobal.lua — CLIENT
-- Spec item 16, global half: block chat for every player at once.
--
-- Real enforcement is server-side (Server/Moderation.lua drops messages
-- from muted senders before they are ever broadcast). This client half
-- only handles the local presentation: the chat box is hidden and the
-- input field is disabled, so a muted player sees a blocked chat rather
-- than typing into a void and wondering why nobody answers.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "MuteChatGlobal"

local function enabled()
    return ClientState.Get(KEY)
end

Safe.PatchMethod("Barotrauma.ChatBox", "AddToGUIUpdateList", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

-- Stop the input box accepting new text.
Safe.PatchMethod("Barotrauma.ChatBox", "SelectInputBox", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

Safe.AddHook("think", "HDC.ChatMuteGlobal.DisableInput", function()
    if not enabled() then return end
    local chatBox = Safe.Get(function() return GameMain.GameSession.CrewManager.ChatBox end)
    if chatBox == nil then return end
    Safe.Set(function() chatBox.GUIFrame.Visible    = false end)
    Safe.Set(function() chatBox.InputBox.Enabled    = false end)
    Safe.Set(function() chatBox.InputBox.Text       = "" end)
end)
