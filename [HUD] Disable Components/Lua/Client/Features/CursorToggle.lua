-- Lua/Client/Features/ChatNameLink.lua — CLIENT
-- Spec item 12: remove the clickable player-profile link from chat names.
--
-- The name stays readable and keeps its job colour; only the routes to the
-- player's server profile are removed, so the chat log looks the same but
-- nothing opens when a name is clicked.
--
-- ChatBox.AddMessage attaches two of them per message: the sender name is a
-- transparent GUIButton whose OnClicked calls NetLobbyScreen.SelectPlayer,
-- and any player reference inside the message body becomes an entry in the
-- message text's ClickableAreas list. Both are cleared here.
--
-- Only the message list is walked, never the whole chat frame. The input
-- box and the toggle button are siblings of the list, and clearing focus
-- across all of them would take the chat box's own controls with it.
--
-- SelectPlayer itself is deliberately left alone. Suppressing it would kill
-- the chat links, but it is the same call the tab menu and the player list
-- use, so it would also take away admin player selection.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "HideChatNameLink"

Safe.MakeFieldAccessible("Barotrauma.ChatBox", "chatBox")

local function enabled()
    return ClientState.Get(KEY)
end

local function stripLinks(messageList)
    if messageList == nil then return end
    Safe.WalkComponents(messageList, function(node)
        Safe.Set(function() node.CanBeFocused = false end)
        Safe.Set(function() node.ClickableAreas.Clear() end)
    end)
end

-- The whole list is re-stripped on each arriving message rather than just
-- the new row. Chat holds sixty messages at most, so the walk is cheap, and
-- doing it this way means messages that were already in the log when the
-- setting was switched on get cleaned up too, without a separate pass that
-- has to be triggered from somewhere.
Safe.PatchMethod("Barotrauma.ChatBox", "AddMessage", nil, function(instance, ptable)
    if not enabled() then return end
    if instance == nil then return end
    stripLinks(Safe.Get(function() return instance.chatBox.Content end))
end, Hook.HookMethodType.After)
