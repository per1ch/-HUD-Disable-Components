if SERVER then
    local state = state or false
    local CursorState = CursorState or false

    local function broadcastState(state)
        local sentCount = 0
        print("1")
        for _, client in pairs(Client.ClientList) do
            if client.Connection ~= nil then
                print("2")
                local message = Networking.Start(NET_MSG_ID)
                print("3")
                message.WriteBoolean(state)
                print("4")
                Networking.Send(message, client.Connection)
                print("5")
                sentCount = sentCount + 1
            end
        end
        print("[ChatStateSync] State (" .. tostring(state) .. ") разослан " .. sentCount .. " клиентам.")
    end

    Game.AddCommand("server_togglestate", "Активировать state у всех клиентов с модом.", function(args)
        state = not state
        print(state)
        print("[ChatStateSync] Администратор активировал state. Рассылка клиентам...")
        broadcastState(state)
    end, nil, false)

    Game.AddCommand("server_cursorstate", "Активировать cursorstate у всех клиентов с модом.", function(args)
        CursorState = not CursorState
        print(CursorState)
        print("[ChatStateSync] Администратор активировал CursorState. Рассылка клиентам...")
        broadcastState(CursorState)
    end, nil, false)

    Game.AddCommand("server_checkstate", "Проверить текущий state на сервере.", function(args)
        print("[ChatStateSync] Текущий state на сервере: " .. tostring(state))
    end, nil, false)

    Game.AddCommand("checkclients", "Запросить фактический state у всех подключенных клиентов.", function(args)
        print("[ChatStateSync] Отправка запроса статуса всем клиентам...")
        
        local count = 0
        local message = Networking.Start(NET_MSG_PING)
        for _, client in pairs(Client.ClientList) do
            if client.Connection ~= nil then
                Networking.Send(message, client.Connection)
                count = count + 1
            end
        end
        
        if count == 0 then
            print("[ChatStateSync] Нет подключенных клиентов для проверки.")
        end
    end, nil, false)

    Hook.Add("clientConnected", "ChatStateSync_SyncOnJoin", function(client)
        if client.Connection ~= nil then
            local message = Networking.Start(NET_MSG_ID)
            message.WriteBoolean(state)
            Networking.Send(message, client.Connection)
            print("[ChatStateSync] Отправлен текущий state (" .. tostring(state) .. ") новому игроку: " .. client.Name)
        end
    end)

    Networking.Receive(NET_MSG_clientState, function(message, client)
        if client == nil then return end
        
        local reportedState = message.ReadBoolean()
        local reportedPatches = message.ReadBoolean()
        
        local stateText = reportedState and "АКТИВЕН" or "ОТКЛЮЧЕН"
        local patchesText = reportedPatches and "ПРИМЕНЕНЫ" or "СНЯТЫ"
        
        print(string.format("[ChatStateSync] Ответ от %s: State = %s | Патчи = %s", 
            client.Name, stateText, patchesText))
    end)
end