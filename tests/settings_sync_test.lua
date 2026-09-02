-- tests/settings_sync_test.lua
--
-- Run:  lua tests/settings_sync_test.lua
--
-- Guards the settings-menu feedback loop that made every policy change
-- spam the network. The real Shared/FeatureRegistry.lua and
-- Client/ClientState.lua are loaded as-is (neither touches the Barotrauma
-- API); the settings menu's number-input wiring is reproduced here because
-- the file it lives in does not load outside the game.

local ROOT = "[HUD] Disable Components/Lua/"

SERVER, CLIENT = false, true
dofile(ROOT .. "Shared/FeatureRegistry.lua")
dofile(ROOT .. "Client/ClientState.lua")

local ClientState = HDC.ClientState
local KEY = "CameraZoomLevel"

-- Stand-ins for the GUI number input and the server round trip.
local sends = 0
local numberInput = { FloatValue = ClientState.GetNumber(KEY) }

local function refresh()
    numberInput.FloatValue = ClientState.GetNumber(KEY)
    if numberInput.OnValueChanged then numberInput.OnValueChanged() end
end
ClientState.AddChangeListener(refresh)

-- The server accepts the edit and broadcasts the result back to everyone,
-- the sender included. That echo is what the guard has to absorb.
local function send()
    sends = sends + 1
    assert(sends < 50, "runaway: the menu is echoing the server's broadcast back at it")
    ClientState.ApplyFromServer({ [KEY] = ClientState.Get(KEY) })
end

-- Client/UI/SettingsMenu.lua, float row.
numberInput.OnValueChanged = function()
    local entered = numberInput.FloatValue
    if entered == nil then return end
    if math.abs(entered - ClientState.GetNumber(KEY)) < 1e-4 then return end
    ClientState.SetLocalPolicyValue(KEY, entered)
    send()
end

-- A real edit sends once and settles.
numberInput.FloatValue = 1.75
numberInput.OnValueChanged()
assert(sends == 1, "expected one packet per edit, got " .. sends)
assert(math.abs(ClientState.GetNumber(KEY) - 1.75) < 1e-4, "edit did not stick")

-- A policy push from another admin repaints the row and sends nothing.
ClientState.ApplyFromServer({ [KEY] = 2.5 })
assert(sends == 1, "a server push must not be sent back upstream, got " .. sends)
assert(math.abs(numberInput.FloatValue - 2.5) < 1e-4, "row did not follow the server")

-- The registry clamps out-of-range values on both sides of the wire.
assert(HDC.CoerceValue(KEY, 99) == 3.0, "zoom above range must clamp to max")
assert(HDC.CoerceValue(KEY, -5) == 0.3, "zoom below range must clamp to min")
assert(HDC.CoerceValue("NotASetting", true) == nil, "unknown keys must be rejected")

print("settings_sync_test: ok (" .. sends .. " packet for 1 edit + 1 remote push)")
