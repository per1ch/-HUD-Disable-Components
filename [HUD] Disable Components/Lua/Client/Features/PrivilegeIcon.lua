-- Lua/Client/Features/PrivilegeIcon.lua — CLIENT
-- Spec item 6: remove the host/permission icon shown next to names in the
-- tab player list.
--
-- The icon is removed by hiding the icon GUI elements inside each player
-- row after the list is built — never by touching the client list itself.
-- Mutating the real list is what breaks bot commands and admin actions in
-- other mods that attempt this, so the row stays intact and only its icon
-- child is made invisible.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "HidePrivilegeIcon"

local function enabled()
    return ClientState.Get(KEY)
end

-- Icon elements are GUIImages with no text. Player names, ping figures and
-- other row content are text-bearing, so text-free images are the icons.
local function hideIconsIn(root)
    Safe.WalkComponents(root, function(node)
        local isImage = Safe.Get(function()
            local _ = node.Sprite
            return true
        end) == true
        if not isImage then return end

        local hasText = Safe.Get(function()
            local textBlock = node.TextBlock
            return textBlock ~= nil and tostring(textBlock.Text) ~= ""
        end) == true
        if hasText then return end

        local style = Safe.Get(function() return tostring(node.Style.Element.Name) end)
        if style == nil then return end
        local lowered = string.lower(style)
        if string.find(lowered, "permission", 1, true) ~= nil
        or string.find(lowered, "owner", 1, true) ~= nil
        or string.find(lowered, "host", 1, true) ~= nil
        or string.find(lowered, "admin", 1, true) ~= nil then
            Safe.Set(function() node.Visible = false end)
        end
    end)
end

Safe.PatchMethod("Barotrauma.TabMenu", "CreateMultiPlayerList", nil, function(instance, ptable)
    if not enabled() then return end
    Timer.Wait(function()
        if not enabled() then return end
        hideIconsIn(Safe.Get(function() return GUI.Canvas end))
    end, 1)
end, Hook.HookMethodType.After)

Safe.PatchMethod("Barotrauma.TabMenu", "AddToGUIUpdateList", nil, function(instance, ptable)
    if not enabled() then return end
    hideIconsIn(Safe.Get(function() return GUI.Canvas end))
end, Hook.HookMethodType.After)
