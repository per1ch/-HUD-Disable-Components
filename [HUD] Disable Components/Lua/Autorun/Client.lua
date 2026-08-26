HUD = {}
HUD.Path = ...

if CLIENT then

    local patchesActive = false

    local clientState = false
    local CursorState = false

    Game.AddCommand("client_checkstate", "Проверить текущий state на клиенте.", function(args)
        print("[ChatStateSync] Текущий state на клиенте: " .. tostring(clientState))
    end, nil, false)
    Game.AddCommand("client_togglestate", "Проверить текущий state на клиенте.", function(args)
        clientState = not clientState
        print("[ChatStateSync] Текущий state на клиенте: " .. tostring(clientState))
    end, nil, false)

    local function applyPatches()
        if patchesActive then return end
        print("[ChatStateSync] Применяем патчи (hooks.lua)")
        dofile(HUD.Path .. "/Lua/hooks.lua")
        patchesActive = true
    end

    local function removePatches()
        if not patchesActive then return end
        print("[ChatStateSync] Удаляем патчи (unhook.lua)")
        dofile(HUD.Path .. "/Lua/unhook.lua")
        patchesActive = false
    end

    local function setState(newState)
        if clientState == newState then return end
        clientState = newState

        if clientState then
            applyPatches()
        else
            removePatches()
        end

        if Game.ChatBox then
            local text = "State " .. (clientState and "активирован" or "деактивирован") .. " сервером!"
            local notify = ChatMessage.Create("System", text, ChatMessageType.Server, nil, nil)
            notify.Color = clientState and Color(0, 255, 100, 255) or Color(255, 100, 100, 255)
            Game.ChatBox.AddMessage(notify)
        end
    end

    

    local lastCheckTime = 0
    local CHECK_INTERVAL = 2.0

    Hook.Add("think", "ChatStateSync_Think", function()
        Networking.Receive(NET_MSG_ID, function(message)
            local newState = message.ReadBoolean()
            print("[ChatStateSync] Клиент получил state от сервера: " .. tostring(newState))
            setState(newState)
        end)
        local currentTime = Timer.GetTime()
        if currentTime - lastCheckTime < CHECK_INTERVAL then return end
        lastCheckTime = currentTime

        if clientState and not patchesActive then
            print("[ChatStateSync] Think failsafe: state=true, но патчи не активны. Применяем.")
            applyPatches()
        elseif not clientState and patchesActive then
            print("[ChatStateSync] Think failsafe: state=false, но патчи активны. Удаляем.")
            removePatches()
        end
        -- if CursorState then
        --     Hook.Patch("ChatState_HideCursor", "Barotrauma.GUI", "DrawCursor", function(instance, ptable)
        --         ptable.PreventExecution = true
        --     end, Hook.HookMethodType.Before)
        -- elseif not CursorState then
        --     Hook.Patch("ChatState_HideCursor", "Barotrauma.GUI", "DrawCursor", function(instance, ptable)
        --     end, Hook.HookMethodType.Before)
        -- end
    end)

    
    Networking.Receive(NET_MSG_clientState, function(message)
        local response = Networking.Start(NET_MSG_clientState)
        response.WriteBoolean(clientState)
        response.WriteBoolean(patchesActive)
        Networking.Send(response)
        
        print("[ChatStateSync] NET_MSG_clientState -- received.")
    end)

    Networking.Receive(NET_MSG_PING, function(message)
        local response = Networking.Start(NET_MSG_PING)
        response.WriteBoolean(clientState)
        response.WriteBoolean(patchesActive)
        Networking.Send(response)
        
        print("[ChatStateSync] NET_MSG_PING -- received.")
    end)

    Networking.Receive(NET_MSG_CursorState, function(message)
        local response = Networking.Start(NET_MSG_CursorState)
        response.WriteBoolean(CursorState)
        response.WriteBoolean(patchesActive)
        Networking.Send(response)
        
        print("[ChatStateSync] NET_MSG_CursorState -- received.")
    end)

    Networking.Receive(NET_MSG_ID, function(message)
        local response = Networking.Start(NET_MSG_ID)
        response.WriteBoolean(clientState)
        response.WriteBoolean(patchesActive)
        Networking.Send(response)
        
        print("[ChatStateSync] NET_MSG_ID -- received.")
    end)
end