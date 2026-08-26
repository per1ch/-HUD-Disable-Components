-- Lua/Client/Net.lua — CLIENT
--
-- Receives policy pushes from the server, sends edit requests upstream,
-- and answers the integrity heartbeat.
--
-- The policy payload is a single JSON string, so the two sides need no
-- agreement on field order and new settings need no protocol change.

HDC = HDC or {}

local Safe        = HDC.Safe
local NetIds      = HDC.NetIds
local ClientState = HDC.ClientState

local Net = {}
HDC.Net = Net

Networking.Receive(NetIds.Sync, function(message)
    local raw = Safe.Get(function() return message.ReadString() end)
    if raw == nil then return end

    local values = Safe.Get(function() return json.parse(raw) end)
    if values == nil then
        Safe.Log("malformed policy payload from server, ignoring")
        return
    end
    ClientState.ApplyFromServer(values)
end)

-- Sends the local view of the policy upstream. The server decides whether
-- to honour it (Server/Permissions.lua) and re-broadcasts either way, so an
-- unauthorised client's menu simply snaps back.
function Net.RequestPolicyChange(values)
    Safe.Set(function()
        local message = Networking.Start(NetIds.EditRequest)
        message.WriteString(json.serialize(values))
        Networking.Send(message)
    end)
end

-- Integrity probe: reply with the mod version so the server can spot
-- clients that are missing, stale, or not running the mod at all.
Networking.Receive(NetIds.Heartbeat, function(message)
    Safe.Set(function()
        local reply = Networking.Start(NetIds.Heartbeat)
        reply.WriteString(tostring(HDC.Version or "unknown"))
        Networking.Send(reply)
    end)
end)

function Net.IsMultiplayer()
    return Safe.Get(function() return Game.IsMultiplayer end) == true
end

return Net
