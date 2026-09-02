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
-- SelectPlayer itself is deliberately left alone. Suppressing it would
-- indeed kill the chat links, but it is the same call the tab menu and the
-- player list use, so it would also take away admin player selection —
-- much more than this setting asks for.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "HideChatNameLink"

Safe.MakeFieldAccessible("Barotrauma.ChatBox", "chatBox")

local function enabled()
    return ClientState.Get(KEY)
end

-- Nothing inside a chat message needs to take focus once its links are
-- gone: the log's own scrollbar belongs to the list box, not to the message
-- rows underneath it, so clearing focus across a row is safe.
local function stripRow(row)
    if row == nil then return end
    Safe.WalkComponents(row, function(node)
        Safe.Set(function() node.CanBeFocused = false end)
        Safe.Set(function() node.ClickableAreas.Clear() end)
    end)
end

local function messageList(chatBoxInstance)
    if chatBoxInstance == nil then return nil end
    return Safe.Get(function() return chatBoxInstance.chatBox.Content end)
end

-- Messages are stripped as they arrive rather than on every frame. The
-- previous version re-walked the entire chat GUI from AddToGUIUpdateList,
-- which runs each frame, and neutralised every clickable node it found
-- anywhere in the box rather than only the name links.
Safe.PatchMethod("Barotrauma.ChatBox", "AddMessage", nil, function(instance, ptable)
    if not enabled() then return end
    local content = messageList(instance)
    if content == nil then return end
    -- The message just appended is the last child of the list.
    local newest = Safe.Get(function()
        return content.GetChild(content.CountChildren - 1)
    end)
    -- Deliberately no whole-list fallback here: this runs per message, and
    -- re-walking all sixty rows each time would cost more than the frame
    -- loop that was just removed. The change listener below covers the
    -- backlog case.
    stripRow(newest)
end, Hook.HookMethodType.After)

-- Messages already in the log when the setting is switched on: one pass,
-- on the change itself.
ClientState.AddChangeListener(function()
    if not enabled() then return end
    local chatBoxType = Safe.Static("Barotrauma.ChatBox")
    if chatBoxType == nil then return end
    stripRow(messageList(Safe.Get(function() return chatBoxType.GetChatBox() end)))
end)
