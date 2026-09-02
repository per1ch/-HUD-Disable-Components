-- Lua/Client/Features/GiveInButton.lua — CLIENT
-- Spec item 11: neutralise the "Give In" (surrender/suicide) button.
--
-- Disabled rather than merely hidden: hiding a button that still works
-- leaves the underlying action reachable through other paths. The button
-- stays visible but greyed out, and the action itself is blocked.
--
-- Note this is the client-side half only. A client with a modified game
-- could still trigger the underlying kill; genuine enforcement belongs on
-- the server, which is why the server also refuses the resulting state
-- change where it can (see Server/Moderation.lua for the same pattern).

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "DisableGiveIn"

local function enabled()
    return ClientState.Get(KEY)
end

-- Block the underlying "give in to pressure / accept death" action.
Safe.PatchMethod("Barotrauma.Character", "GiveInToPressure", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

-- The button lives on the character HUD's death/ragdoll prompt. Find it by
-- its text and disable it, rather than depending on a private field name.
local giveInLabels = nil

local function matchesGiveInLabel(text)
    if text == nil then return false end
    if giveInLabels == nil then
        giveInLabels = {}
        for _, tag in ipairs({ "GiveInButton", "GiveIn", "give in" }) do
            local translated = Safe.Get(function()
                return tostring(TextManager.Get(tag).Value)
            end)
            if translated ~= nil and translated ~= "" then
                giveInLabels[string.lower(translated)] = true
            end
        end
        giveInLabels["give in"] = true
    end
    return giveInLabels[string.lower(tostring(text))] == true
end

local function disableGiveInButtons(root)
    Safe.WalkComponents(root, function(node)
        local textBlock = Safe.Get(function() return node.TextBlock end)
        if textBlock == nil then return end
        local text = Safe.Get(function() return tostring(textBlock.Text) end)
        if not matchesGiveInLabel(text) then return end
        Safe.Set(function() node.Enabled      = false end)
        Safe.Set(function() node.CanBeFocused = false end)
        Safe.Set(function() node.OnClicked    = function() return true end end)
    end)
end

Safe.PatchMethod("Barotrauma.CharacterHUD", "AddToGUIUpdateList", nil, function(instance, ptable)
    if not enabled() then return end
    disableGiveInButtons(Safe.Get(function() return GUI.Canvas end))
end, Hook.HookMethodType.After)
