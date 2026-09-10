-- key -> last value the server actually broadcast for this key. Updated on
-- every accepted broadcast, whether or not we applied it (a dropped
-- broadcast due to a pending edit still teaches us what the server thinks
-- the value is). Used as the fallback when a pending edit times out.
ClientState.LastServerValue = {}

function ClientState.MarkPending(key, value)
    local token = {}
    ClientState.Pending[key] = { value = value, token = token }
    Safe.Set(function()
        Timer.Wait(function()
            local entry = ClientState.Pending[key]
            if entry ~= nil and entry.token == token then
                -- Server never echoed this value back: our edit was either
                -- rejected or lost a same-field race to another admin.
                -- Stop shadowing and adopt the server's last known value so
                -- the UI does not lie about what is actually in effect.
                ClientState.Pending[key] = nil
                local serverValue = ClientState.LastServerValue[key]
                if serverValue ~= nil then
                    ClientState.Values[key] = serverValue
                end
                notifyListeners()
            end
        end, PENDING_TIMEOUT_MS)
    end)
end

function ClientState.ApplyFromServer(values)
    if type(values) ~= "table" then return end
    for key, value in pairs(values) do
        local coerced = HDC.CoerceValue(key, value)
        if coerced ~= nil then
            ClientState.LastServerValue[key] = coerced

            local pending = ClientState.Pending[key]
            if pending == nil then
                ClientState.Values[key] = coerced
            elseif pending.value == coerced then
                -- Server confirmed our edit. Adopt and stop shadowing.
                ClientState.Pending[key] = nil
                ClientState.Values[key] = coerced
            end
            -- else: our edit is still in flight (or lost). Keep the
            -- optimistic value; the pending timeout above will adopt
            -- LastServerValue if confirmation never arrives.
        end
    end
    notifyListeners()
end
