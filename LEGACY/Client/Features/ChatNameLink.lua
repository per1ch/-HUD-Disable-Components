-- Lua/Client/Features/ChatNameLink.lua — CLIENT
-- Spec item 12: remove the clickable player-profile link from chat names.
--
-- The name stays readable; only its click behaviour and focusability are
-- stripped, so the chat log looks the same but nothing routes to the
-- player's server profile.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "HideChatNameLink"

local function enabled()
    return ClientState.Get(KEY)
end

local function stripLinks(root)
    if root == nil then return end
    Safe.WalkComponents(root, function(node)
        local isClickable = Safe.Get(function()
            local _ = node.OnClicked
            return true
        end) == true
        if not isClickable then return end
        Safe.Set(function() node.OnClicked    = function() return true end end)
        Safe.Set(function() node.CanBeFocused = false end)
    end)
end

-- Chat entries are rebuilt as messages arrive, so re-strip on each append.
Safe.PatchMethod("Barotrauma.ChatBox", "AddMessage", nil, function(instance, ptable)
    if not enabled() then return end
    if instance == nil then return end
    stripLinks(Safe.Get(function() return instance.GUIFrame end))
end, Hook.HookMethodType.After)

Safe.PatchMethod("Barotrauma.ChatBox", "AddToGUIUpdateList", nil, function(instance, ptable)
    if not enabled() then return end
    if instance == nil then return end
    stripLinks(Safe.Get(function() return instance.GUIFrame end))
end, Hook.HookMethodType.After)
