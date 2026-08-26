-- Lua/Client/Features/HealthMenuLock.lua — CLIENT
-- Spec item 8: make the character health menu non-interactive.
--
-- Approach chosen over a full menu rewrite: the vanilla menu keeps its
-- appearance, but the key that opens it is intercepted and every control
-- inside it is made unfocusable, so nothing in it can be clicked. A full
-- rewrite would need a C# component (as the reference BetterHealthUI mod
-- does) for no gain against this spec item, which only asks that the menu
-- be unavailable for interaction.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local KEY = "LockHealthMenu"

local function enabled()
    return ClientState.Get(KEY)
end

-- 1. Stop the menu being opened by its keybind.
Safe.PatchMethod("Barotrauma.CharacterHealth", "OpenHealthWindow", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

Safe.PatchMethod("Barotrauma.CharacterHealth", "set_OpenHealthWindow", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

Safe.PatchMethod("Barotrauma.CharacterHealth", "ToggleHealthWindow", nil, function(instance, ptable)
    if not enabled() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

-- 2. If it is open anyway (already open when the toggle flipped, or opened
--    through a path not covered above), strip interactivity from every
--    control inside it so it cannot be used.
local function lockControls(root)
    if root == nil then return end
    Safe.WalkComponents(root, function(node)
        Safe.Set(function() node.CanBeFocused = false end)
        local isButton = Safe.Get(function()
            local _ = node.OnClicked
            return true
        end) == true
        if isButton then
            Safe.Set(function() node.Enabled = false end)
        end
    end)
end

Safe.PatchMethod("Barotrauma.CharacterHealth", "AddToGUIUpdateList", nil, function(instance, ptable)
    if not enabled() then return end
    if instance == nil then return end
    lockControls(Safe.Get(function() return instance.HealthWindow end))
    lockControls(Safe.Get(function() return instance.InventoryContainer end))
end, Hook.HookMethodType.After)

-- 3. Close it if it is showing.
Safe.AddHook("think", "HDC.HealthMenuLock.ForceClose", function()
    if not enabled() then return end
    local controlled = Safe.Get(function() return Character.Controlled end)
    if controlled == nil then return end
    local health = Safe.Get(function() return controlled.CharacterHealth end)
    if health == nil then return end
    Safe.Set(function() health.OpenHealthWindow = nil end)
end)
