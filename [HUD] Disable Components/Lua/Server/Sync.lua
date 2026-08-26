-- Lua/Server/Sync.lua — SERVER
--
-- Pushes the authoritative policy to clients and validates incoming edit
-- requests. The payload is a single JSON string, so adding a setting to
-- the registry needs no protocol change and no field-order agreement
-- between the two sides.

HDC = HDC or {}

local Safe        = HDC.Safe
local NetIds      = HDC.NetIds
local ServerState = HDC.ServerState
local Permissions = HDC.Permissions

local Sync = {}
HDC.Sync = Sync

function Sync.SendTo(connection)
    if connection == nil then return end
    Safe.Set(function()
        local message = Networking.Start(NetIds.Sync)
        message.WriteString(ServerState.Serialize())
        Networking.Send(message, connection)
    end)
end

function Sync.Broadcast()
    local clients = Safe.Get(function() return Client.ClientList end)
    if clients == nil then return end
    for _, client in pairs(clients) do
        local connection = Safe.Get(function() return client.Connection end)
        if connection ~= nil then Sync.SendTo(connection) end
    end
end

-- New arrivals get the policy immediately, so they never render a frame
-- with the wrong HUD state.
Safe.AddHook("clientConnected", "HDC.Sync.ClientConnected", function(client)
    local connection = Safe.Get(function() return client.Connection end)
    if connection == nil then return end
    Sync.SendTo(connection)
end)

Networking.Receive(NetIds.EditRequest, function(message, sender)
    -- Always consume the payload, even when rejecting, or the stream desyncs.
    local raw = Safe.Get(function() return message.ReadString() end)

    if not Permissions.CanEditPolicy(sender) then
        Safe.Log("rejected settings change from " .. Permissions.DescribeClient(sender) ..
                 " (missing " .. Permissions.POLICY_COMMAND .. " permission)")
        -- Re-send the true state so their menu snaps back.
        Sync.SendTo(Safe.Get(function() return sender.Connection end))
        return
    end

    local proposed = raw ~= nil and Safe.Get(function() return json.parse(raw) end) or nil
    if proposed == nil then
        Safe.Log("ignored malformed settings payload from " .. Permissions.DescribeClient(sender))
        return
    end

    ServerState.ApplyTable(proposed)
    ServerState.Save()
    Sync.Broadcast()

    Safe.Log("settings updated by " .. Permissions.DescribeClient(sender))
end)

Safe.AddCommand("hdc_serverstate", "Print the current [HUD] Disable Components policy on the server.",
    function()
        print("[HDC] Current server policy:\n" .. ServerState.Describe())
    end, nil, false)

Safe.AddCommand("hdc_resync", "Re-send the current [HUD] Disable Components policy to every client.",
    function()
        Sync.Broadcast()
        print("[HDC] Policy re-sent to all clients.")
    end, nil, false)

return Sync
