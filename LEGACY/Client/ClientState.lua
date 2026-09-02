-- Lua/Client/ClientState.lua — CLIENT
--
-- Local mirror of the server's policy, plus the two self-only toggles
-- (items 13 and 14) which never leave this machine.
--
-- Feature modules read from here every frame rather than being patched and
-- unpatched as values change: patches install once at load and simply
-- consult the current value, which makes toggling instant and free of
-- re-patch races.

HDC = HDC or {}

local ClientState = {}
HDC.ClientState = ClientState

ClientState.Values = {}
for key, default in pairs(HDC.FeatureDefaults) do
    ClientState.Values[key] = default
end

-- Self-only, driven by client commands rather than the server.
ClientState.Local = {
    HideOwnUI     = false, -- item 13
    HideOwnCursor = false, -- item 14
}

local listeners = {}

function ClientState.Get(key)
    local value = ClientState.Values[key]
    if value == nil then return HDC.FeatureDefaults[key] end
    return value
end

function ClientState.GetNumber(key)
    return tonumber(ClientState.Get(key)) or 0
end

function ClientState.GetLocal(key)
    return ClientState.Local[key] == true
end

function ClientState.SetLocal(key, value)
    if ClientState.Local[key] == nil then return false end
    ClientState.Local[key] = (value == true)
    return true
end

function ClientState.ToggleLocal(key)
    if ClientState.Local[key] == nil then return nil end
    ClientState.Local[key] = not ClientState.Local[key]
    return ClientState.Local[key]
end

-- Local edit made from the settings menu, before it is sent upstream.
-- Values are coerced against the registry here too, so the menu cannot
-- push an out-of-range float even momentarily.
function ClientState.SetLocalPolicyValue(key, value)
    local coerced = HDC.CoerceValue(key, value)
    if coerced == nil then return false end
    ClientState.Values[key] = coerced
    return true
end

function ClientState.ApplyFromServer(values)
    if type(values) ~= "table" then return end
    for key, value in pairs(values) do
        local coerced = HDC.CoerceValue(key, value)
        if coerced ~= nil then ClientState.Values[key] = coerced end
    end
    for _, listener in ipairs(listeners) do
        pcall(listener)
    end
end

function ClientState.AddChangeListener(callback)
    if type(callback) == "function" then
        table.insert(listeners, callback)
    end
end

function ClientState.Snapshot()
    local snapshot = {}
    for _, key in ipairs(HDC.FeatureKeyOrder) do
        snapshot[key] = ClientState.Get(key)
    end
    return snapshot
end

function ClientState.Describe()
    local lines = {}
    for _, entry in ipairs(HDC.FeatureRegistry) do
        local value = ClientState.Get(entry.key)
        local shown
        if entry.type == "float" then
            shown = string.format("%.2f", tonumber(value) or 0)
        else
            shown = value == true and "ON" or "off"
        end
        table.insert(lines, string.format("  %-22s %s", entry.key, shown))
    end
    table.insert(lines, string.format("  %-22s %s", "HideOwnUI (local)",
        ClientState.GetLocal("HideOwnUI") and "ON" or "off"))
    table.insert(lines, string.format("  %-22s %s", "HideOwnCursor (local)",
        ClientState.GetLocal("HideOwnCursor") and "ON" or "off"))
    return table.concat(lines, "\n")
end

return ClientState
