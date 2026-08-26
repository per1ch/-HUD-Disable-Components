-- ============================================================
-- SHARED — runs in both SERVER and CLIENT contexts
-- ============================================================

local NET_HOST_AUTH   = "HUDRemover_Auth"      -- server → host client (one-time)
local NET_HOST_UPDATE = "HUDRemover_HostCfg"   -- host client → server
local NET_CLIENT_SYNC = "HUDRemover_SrvCfg"    -- server → all clients

local CONFIG_KEY_ORDER = {
    "HideDrawFrontOverhead",
    "HideHoverTexts",
    "HideVoiceChatIndicator",
    "HideSpeechBubbles",
    "HideFloatingMessages",
    "HideOrderIconsOnCharacters",
    "HideObjectiveIconsOnCharacters",
}

local DEFAULT_CONFIG = {
    HideDrawFrontOverhead          = true,
    HideHoverTexts                 = true,
    HideVoiceChatIndicator         = true,
    HideSpeechBubbles              = false,
    HideFloatingMessages           = true,
    HideOrderIconsOnCharacters     = true,
    HideObjectiveIconsOnCharacters = true,
}

local SETTINGS_DEFINITIONS = {
    {
        key   = "HideDrawFrontOverhead",
        label = "Names & HP bars",
        desc  = "Player names and health bars above heads",
    },
    {
        key   = "HideVoiceChatIndicator",
        label = "Voice indicator",
        desc  = "Microphone icon shown on other players",
    },
    {
        key   = "HideSpeechBubbles",
        label = "Chat bubbles",
        desc  = "Speech bubbles when players type in chat",
    },
    {
        key   = "HideFloatingMessages",
        label = "Floating alerts",
        desc  = "Damage numbers and floating status text",
    },
    {
        key        = "HideOrderIconsOnCharacters",
        linkedKeys = { "HideObjectiveIconsOnCharacters" },
        label      = "Mission icons",
        desc       = "Order and objective markers on players",
    },
}

local function safeGet(valueFn)
    local ok, r = pcall(valueFn)
    return ok and r or nil
end

local function safeSet(setterFn)
    return pcall(setterFn)
end

-- ============================================================
-- SERVER CONTEXT
-- ============================================================
if SERVER then

    local serverConfig = {}
    for k, v in pairs(DEFAULT_CONFIG) do serverConfig[k] = v end

    -- Detect the listen-server owner client using several fallback checks
    local function isOwnerClient(client)
        if safeGet(function() return client.IsOwner end) == true then return true end
        if safeGet(function() return client.IsServerOwner end) == true then return true end
        return safeGet(function()
            local ownerConn = GameMain.Server ~= nil and GameMain.Server.OwnerConnection
            return ownerConn ~= nil and client.Connection == ownerConn
        end) == true
    end

    local function sendConfigTo(conn)
        pcall(function()
            local msg = Networking.Start(NET_CLIENT_SYNC)
            for _, key in ipairs(CONFIG_KEY_ORDER) do
                msg.WriteBoolean(serverConfig[key] == true)
            end
            Networking.Send(msg, conn)
        end)
    end

    local function broadcastConfigToAll()
        local clients = safeGet(function() return Client.ClientList end)
        if clients == nil then return end
        for _, client in pairs(clients) do
            local conn = safeGet(function() return client.Connection end)
            if conn ~= nil then sendConfigTo(conn) end
        end
    end

    Hook.Add("clientConnected", "HUDRemover.ClientConnect", function(client)
        local conn = safeGet(function() return client.Connection end)
        if conn == nil then return end
        -- Tell the owner they are the host (so they push their disk config to us)
        if isOwnerClient(client) then
            pcall(function() Networking.Send(Networking.Start(NET_HOST_AUTH), conn) end)
        end
        -- Send current config so the client has something to work with
        sendConfigTo(conn)
    end)

    -- Only the owner may update the server config
    Networking.Receive(NET_HOST_UPDATE, function(msg, sender)
        if not isOwnerClient(sender) then return end
        pcall(function()
            for _, key in ipairs(CONFIG_KEY_ORDER) do
                serverConfig[key] = msg.ReadBoolean()
            end
        end)
        broadcastConfigToAll()
    end)

    return
end

-- ============================================================
-- CLIENT CONTEXT
-- ============================================================

_G.HUDRemover = _G.HUDRemover or {}
local Mod = _G.HUDRemover

if Mod._initialized then return end
Mod._initialized = true

Mod.Config = Mod.Config or {}
for k, v in pairs(DEFAULT_CONFIG) do
    if Mod.Config[k] == nil then Mod.Config[k] = v end
end

local SIG_SPRITEBATCH_CAMERA = {
    "Microsoft.Xna.Framework.Graphics.SpriteBatch",
    "Barotrauma.Camera"
}

local CONFIG_FILE_NAME     = "HUDRemoverConfig.txt"
local MOD_PACKAGE_HINT     = "Immersive Overhead HUD Remover"
local FALLBACK_CONFIG_PATH = "LocalMods/Immersive Overhead HUD Remover (No Nameplates  HP Bars)/" .. CONFIG_FILE_NAME
local COPYRIGHT_GUARD = {
    Enabled            = true,
    ExpectedWorkshopId = "3492263121"
}

local fieldsAccessibilityInitialized = false
local transparentNameColor           = nil
local resolvedConfigPath             = nil

-- Server explicitly told us we are the host
local _isAuthorizedAsHost = false
-- True once any server message has arrived (confirms multiplayer)
local _isKnownMultiplayer = false
-- True after we have pushed our disk config to the server once.
-- Prevents the NET_CLIENT_SYNC → NET_HOST_UPDATE → NET_CLIENT_SYNC infinite loop.
local _serverConfigInitialized = false

local SettingsUI = {
    root        = nil,
    panel       = nil,
    list        = nil,
    toggles     = {},
    pauseMenu   = nil,
    pauseButton = nil,
    isOpen      = false
}

-- ---------------------------------------------------------------------------
-- Host detection — tries four independent methods so at least one works
-- ---------------------------------------------------------------------------

local function isHostPlayer()
    -- 1. Confirmed singleplayer
    local isMP = safeGet(function() return GameMain.IsMultiplayer end)
    if isMP == false then return true end

    -- 2. Server explicitly authorised this client
    if _isAuthorizedAsHost then return true end

    -- 3. Listen server: the server process runs on the same machine,
    --    so GameMain.Server is non-nil even in the CLIENT Lua VM
    if safeGet(function() return GameMain.Server ~= nil end) == true then return true end

    -- 4. Direct client-side ownership flag
    if safeGet(function() return GameMain.Client ~= nil
                                  and GameMain.Client.IsServerOwner end) == true then
        return true
    end

    -- If we have never received a network message and IsMultiplayer is unknown,
    -- assume singleplayer (no server message ever arrives in SP)
    if isMP == nil and not _isKnownMultiplayer then
        local nm = safeGet(function() return GameMain.NetworkMember end)
        if nm == nil then return true end
    end

    return false
end

-- ---------------------------------------------------------------------------
-- Utilities
-- ---------------------------------------------------------------------------

local function preventExecution(p)
    if p ~= nil then p.PreventExecution = true end
    return false
end

local function setTextScale(button, scale)
    safeSet(function() button.TextBlock.TextScale = scale end)
end

local function patchMethod(typeName, methodName, signatures, callback, hookType)
    local ok, err = pcall(function()
        if signatures ~= nil then
            Hook.Patch(typeName, methodName, signatures, callback, hookType)
        else
            Hook.Patch(typeName, methodName, callback, hookType)
        end
    end)
    if not ok then
        print("[HUDRemover] patch failed: " .. tostring(typeName) .. "." ..
              tostring(methodName) .. " — " .. tostring(err))
    end
    return ok
end

local function makeFieldAccessible(typeName, fieldName)
    pcall(function()
        local descriptor = Descriptors and Descriptors[typeName] or nil
        if descriptor == nil then descriptor = LuaUserData.RegisterType(typeName) end
        if descriptor ~= nil then LuaUserData.MakeFieldAccessible(descriptor, fieldName) end
    end)
end

-- ---------------------------------------------------------------------------
-- Config persistence
-- ---------------------------------------------------------------------------

local function resolveConfigPath()
    if resolvedConfigPath ~= nil then return resolvedConfigPath end
    local packages = safeGet(function() return ContentPackageManager.AllPackages end)
    if packages ~= nil then
        for package in packages do
            local name = safeGet(function() return package.Name end)
            local dir  = safeGet(function() return package.Dir  end)
            if name ~= nil and dir ~= nil and dir ~= "" then
                if string.find(tostring(name), MOD_PACKAGE_HINT, 1, true) ~= nil then
                    resolvedConfigPath = tostring(dir) .. "/" .. CONFIG_FILE_NAME
                    return resolvedConfigPath
                end
            end
        end
    end
    resolvedConfigPath = FALLBACK_CONFIG_PATH
    return resolvedConfigPath
end

local function readAllText(path)
    local openOk, file = pcall(function()
        if io == nil or io.open == nil then return nil end
        return io.open(path, "r")
    end)
    if not openOk or file == nil then return nil end
    local readOk, data = pcall(function() return file:read("*a") end)
    pcall(function() file:close() end)
    return readOk and data or nil
end

local function writeAllText(path, content)
    local openOk, file = pcall(function()
        if io == nil or io.open == nil then return nil end
        return io.open(path, "w")
    end)
    if not openOk or file == nil then return false end
    local writeOk = pcall(function() file:write(content or "") end)
    pcall(function() file:close() end)
    return writeOk
end

local function normalizePath(path)
    if path == nil then return nil end
    return tostring(path):gsub("\\", "/")
end

local function extractWorkshopIdFromPath(path)
    local p = normalizePath(path)
    if p == nil then return nil end
    local id = string.match(string.lower(p), "/workshop/content/%d+/(%d+)/")
    return id and tostring(id) or nil
end

local function getCurrentScriptPath()
    local source = safeGet(function()
        if debug == nil or debug.getinfo == nil then return nil end
        local info = debug.getinfo(1, "S")
        return info and info.source or nil
    end)
    if source == nil then return nil end
    if string.sub(source, 1, 1) == "@" then source = string.sub(source, 2) end
    return normalizePath(source)
end

local function enforceCopyrightGuard()
    if not COPYRIGHT_GUARD.Enabled then return true end
    local workshopId = extractWorkshopIdFromPath(getCurrentScriptPath())
    if workshopId == nil then return true end
    if workshopId == COPYRIGHT_GUARD.ExpectedWorkshopId then return true end
    print("[HUDRemover] Copyright guard blocked Workshop ID " .. tostring(workshopId))
    return false
end

local function saveConfigToDisk()
    local path = resolveConfigPath()
    if path == nil or path == "" then return end
    local lines = {}
    for key in pairs(DEFAULT_CONFIG) do
        lines[#lines + 1] = key .. "=" .. tostring(Mod.Config[key] == true)
    end
    writeAllText(path, table.concat(lines, "\n"))
end

local function loadConfigFromDisk()
    local path = resolveConfigPath()
    if path == nil or path == "" then return end
    local content = readAllText(path)
    if content == nil or content == "" then return end
    for line in string.gmatch(content, "[^\r\n]+") do
        local key, rawValue = string.match(line, "^([A-Za-z0-9_]+)%s*=%s*(%a+)%s*$")
        if key ~= nil and Mod.Config[key] ~= nil then
            local v = string.lower(rawValue)
            if     v == "true"  then Mod.Config[key] = true
            elseif v == "false" then Mod.Config[key] = false end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Networking (client side)
-- ---------------------------------------------------------------------------

local sendConfigUpdateToServer

-- Server tells us we are the listen-server owner.
-- Reload disk config (NET_CLIENT_SYNC might have overwritten it with defaults)
-- and push it to the server so all clients get the correct values.
Networking.Receive(NET_HOST_AUTH, function(msg)
    _isKnownMultiplayer = true
    _isAuthorizedAsHost = true
    loadConfigFromDisk()
    if not _serverConfigInitialized then
        _serverConfigInitialized = true
        if sendConfigUpdateToServer then sendConfigUpdateToServer() end
    end
end)

-- Server pushes config to this client.
-- Non-host  → apply and update visuals.
-- Host      → push our disk config to server ONCE to correct the defaults,
--             then ignore further syncs (our config is always authoritative).
Networking.Receive(NET_CLIENT_SYNC, function(msg)
    _isKnownMultiplayer = true

    -- Read all values regardless of branch (must consume the message)
    local values = {}
    pcall(function()
        for _, key in ipairs(CONFIG_KEY_ORDER) do
            values[key] = msg.ReadBoolean()
        end
    end)

    if isHostPlayer() then
        -- Push our disk config to the server the first time, then stop.
        -- This also prevents the sync loop:
        --   NET_CLIENT_SYNC → NET_HOST_UPDATE → NET_CLIENT_SYNC → ...
        if not _serverConfigInitialized then
            _serverConfigInitialized = true
            if sendConfigUpdateToServer then sendConfigUpdateToServer() end
        end
    else
        -- Non-host: apply server values
        for key, val in pairs(values) do
            Mod.Config[key] = val
        end
        -- Refresh toggle visuals (UI is hidden for non-hosts, but guard anyway)
        pcall(function()
            for _, def in ipairs(SETTINGS_DEFINITIONS) do
                local entry = SettingsUI.toggles[def.key]
                if entry == nil then return end
                local isOn = Mod.Config[def.key] == true
                safeSet(function()
                    local p = SettingsUI._palette
                    if p == nil then return end
                    entry.button.Color          = isOn and p.toggleOn      or p.toggleOff
                    entry.button.HoverColor     = isOn and p.toggleOnHover or p.toggleOffHover
                    entry.button.TextBlock.Text = isOn and "  ON  " or " OFF  "
                end)
                if entry.indicator ~= nil then
                    safeSet(function()
                        local p = SettingsUI._palette
                        if p == nil then return end
                        entry.indicator.TextColor = isOn and p.indicatorOn or p.indicatorOff
                    end)
                end
            end
        end)
    end
end)

sendConfigUpdateToServer = function()
    if not isHostPlayer() then return end
    local isMP  = safeGet(function() return GameMain.IsMultiplayer end)
    local inMP  = (isMP == true) or _isKnownMultiplayer
    if not inMP then return end
    pcall(function()
        local msg = Networking.Start(NET_HOST_UPDATE)
        for _, key in ipairs(CONFIG_KEY_ORDER) do
            msg.WriteBoolean(Mod.Config[key] == true)
        end
        Networking.SendServer(msg)
    end)
end

local function setConfigValue(key, value, linkedKeys)
    if Mod.Config[key] == nil then return end
    Mod.Config[key] = (value == true)
    if linkedKeys ~= nil then
        for _, lk in ipairs(linkedKeys) do
            if Mod.Config[lk] ~= nil then Mod.Config[lk] = (value == true) end
        end
    end
    saveConfigToDisk()
    sendConfigUpdateToServer()
end

-- ---------------------------------------------------------------------------
-- Character overhead hiding
-- ---------------------------------------------------------------------------

local function ensureAccessibility()
    if fieldsAccessibilityInitialized then return end
    fieldsAccessibilityInitialized = true
    makeFieldAccessible("Barotrauma.Character", "hudInfoVisible")
    makeFieldAccessible("Barotrauma.Character", "textlessSpeechBubble")
    makeFieldAccessible("Barotrauma.Character", "speechBubbles")
    makeFieldAccessible("Barotrauma.Character", "guiMessages")
end

local function shouldHideHoverTexts()
    return Mod.Config.HideDrawFrontOverhead
end

local function isLocalPlayerCharacter(character)
    if character == nil then return false end
    if safeGet(function() return character.IsLocalPlayer end) == true then return true end
    local controlled = safeGet(function() return Character.Controlled end)
    return controlled ~= nil and controlled == character
end

local function applyCharacterOverheadHiding(character)
    if character == nil then return end
    if Mod.Config.HideDrawFrontOverhead then
        safeSet(function() character.hudInfoVisible = false end)
    end
    if Mod.Config.HideVoiceChatIndicator and not isLocalPlayerCharacter(character) then
        safeSet(function() character.textlessSpeechBubble = nil end)
    end
    safeSet(function() character.ShowInteractionLabels = not shouldHideHoverTexts() end)
    if Mod.Config.HideSpeechBubbles then
        local sb = safeGet(function() return character.speechBubbles end)
        if sb ~= nil then pcall(function() sb:Clear() end) end
    end
    if Mod.Config.HideFloatingMessages then
        local gm = safeGet(function() return character.guiMessages end)
        if gm ~= nil then pcall(function() gm:Clear() end) end
    end
end

-- ---------------------------------------------------------------------------
-- Settings UI — color palette
-- ---------------------------------------------------------------------------

local function buildPalette()
    if SettingsUI._palette ~= nil then return SettingsUI._palette end
    SettingsUI._palette = {
        toggleOn       = Color(15,  145, 95,  228),
        toggleOnHover  = Color(22,  180, 118, 255),
        toggleOff      = Color(44,  46,  56,  215),
        toggleOffHover = Color(62,  65,  78,  245),
        indicatorOn    = Color(30,  190, 130, 255),
        indicatorOff   = Color(70,  78,  92,  170),
        titleCyan      = Color(50,  200, 225, 255),
        subtitleGrey   = Color(145, 162, 172, 195),
        descGrey       = Color(118, 135, 148, 185),
        separatorTeal  = Color(35,  162, 198, 150),
        versionGrey    = Color(88,  110, 125, 175),
    }
    return SettingsUI._palette
end

local function pal() return buildPalette() end

-- ---------------------------------------------------------------------------
-- Settings UI — toggle helpers
-- ---------------------------------------------------------------------------

local function updateToggleVisual(key)
    local entry = SettingsUI.toggles[key]
    if entry == nil then return end
    local isOn = Mod.Config[key] == true
    local p    = pal()
    safeSet(function()
        entry.button.Color          = isOn and p.toggleOn      or p.toggleOff
        entry.button.HoverColor     = isOn and p.toggleOnHover or p.toggleOffHover
        entry.button.TextBlock.Text = isOn and "  ON  " or " OFF  "
    end)
    if entry.indicator ~= nil then
        safeSet(function()
            entry.indicator.TextColor = isOn and p.indicatorOn or p.indicatorOff
        end)
    end
end

local function refreshSettingsUI()
    for _, def in ipairs(SETTINGS_DEFINITIONS) do
        updateToggleVisual(def.key)
    end
end

local function closeSettingsWindow()
    if SettingsUI.root ~= nil then SettingsUI.root.Visible = false end
    SettingsUI.isOpen = false
end

-- ---------------------------------------------------------------------------
-- Settings UI — window (host only)
-- ---------------------------------------------------------------------------

local function ensureSettingsWindow()
    if SettingsUI.root ~= nil then return end

    SettingsUI.root = GUI.Frame(GUI.RectTransform(Vector2(1, 1)), "GUIBackgroundBlocker")
    SettingsUI.root.Visible      = false
    SettingsUI.root.CanBeFocused = true

    SettingsUI.panel = GUI.Frame(
        GUI.RectTransform(Vector2(0.50, 0.74), SettingsUI.root.RectTransform, GUI.Anchor.Center),
        "GUIFrame"
    )

    local titleBlock = GUI.TextBlock(
        GUI.RectTransform(Vector2(0.78, 0.09), SettingsUI.panel.RectTransform, GUI.Anchor.TopLeft),
        "◈  HUD REMOVER", nil, GUI.Style.LargeFont, GUI.Alignment.CenterLeft
    )
    titleBlock.RectTransform.RelativeOffset = Vector2(0.04, 0.022)
    safeSet(function() titleBlock.TextColor = pal().titleCyan end)

    local versionLabel = GUI.TextBlock(
        GUI.RectTransform(Vector2(0.18, 0.06), SettingsUI.panel.RectTransform, GUI.Anchor.TopRight),
        "v1.1.8", nil, nil, GUI.Alignment.CenterRight
    )
    versionLabel.RectTransform.RelativeOffset = Vector2(-0.04, 0.028)
    safeSet(function() versionLabel.TextColor = pal().versionGrey end)

    local subtitleBlock = GUI.TextBlock(
        GUI.RectTransform(Vector2(0.88, 0.05), SettingsUI.panel.RectTransform, GUI.Anchor.TopLeft),
        "Toggle what overhead elements to hide", nil, nil, GUI.Alignment.CenterLeft
    )
    subtitleBlock.RectTransform.RelativeOffset = Vector2(0.04, 0.108)
    safeSet(function() subtitleBlock.TextColor = pal().subtitleGrey end)

    local separator = GUI.Frame(
        GUI.RectTransform(Vector2(0.92, 0.004), SettingsUI.panel.RectTransform, GUI.Anchor.TopCenter),
        "GUIFrameListBox"
    )
    separator.RectTransform.RelativeOffset = Vector2(0, 0.158)
    safeSet(function() separator.Color = pal().separatorTeal end)

    local listFrame = GUI.Frame(
        GUI.RectTransform(Vector2(0.92, 0.580), SettingsUI.panel.RectTransform, GUI.Anchor.TopCenter),
        "GUIFrameListBox"
    )
    listFrame.RectTransform.RelativeOffset = Vector2(0, 0.177)

    SettingsUI.list = GUI.ListBox(
        GUI.RectTransform(Vector2(1, 1), listFrame.RectTransform, GUI.Anchor.Center),
        false
    )

    for _, def in ipairs(SETTINGS_DEFINITIONS) do
        local row = GUI.Frame(
            GUI.RectTransform(Vector2(0.985, 0.178), SettingsUI.list.Content.RectTransform, GUI.Anchor.TopCenter),
            "InnerFrame"
        )
        row.ToolTip = def.desc

        local indicator = GUI.TextBlock(
            GUI.RectTransform(Vector2(0.022, 0.82), row.RectTransform, GUI.Anchor.CenterLeft),
            "▌", nil, nil, GUI.Alignment.Center
        )
        indicator.RectTransform.RelativeOffset = Vector2(0.008, 0)

        local label = GUI.TextBlock(
            GUI.RectTransform(Vector2(0.60, 0.44), row.RectTransform, GUI.Anchor.TopLeft),
            def.label, nil, nil, GUI.Alignment.CenterLeft
        )
        label.RectTransform.RelativeOffset = Vector2(0.052, 0.065)
        safeSet(function() label.TextScale = 1.06 end)

        local descText = GUI.TextBlock(
            GUI.RectTransform(Vector2(0.60, 0.36), row.RectTransform, GUI.Anchor.BottomLeft),
            def.desc, nil, nil, GUI.Alignment.CenterLeft
        )
        descText.RectTransform.RelativeOffset = Vector2(0.052, -0.065)
        safeSet(function() descText.TextScale = 0.87 end)
        safeSet(function() descText.TextColor = pal().descGrey end)

        local toggle = GUI.Button(
            GUI.RectTransform(Vector2(0.17, 0.62), row.RectTransform, GUI.Anchor.CenterRight),
            "  ON  ", GUI.Alignment.Center, "GUIButtonSmall"
        )
        toggle.RectTransform.RelativeOffset = Vector2(-0.050, 0)
        setTextScale(toggle, 1.0)

        SettingsUI.toggles[def.key] = { button = toggle, indicator = indicator }
        updateToggleVisual(def.key)

        local capturedKey        = def.key
        local capturedLinkedKeys = def.linkedKeys
        toggle.OnClicked = function(btn)
            setConfigValue(capturedKey, not (Mod.Config[capturedKey] == true), capturedLinkedKeys)
            updateToggleVisual(capturedKey)
            return true
        end
    end
    SettingsUI.list.RecalculateChildren()

    local actionSep = GUI.Frame(
        GUI.RectTransform(Vector2(0.92, 0.004), SettingsUI.panel.RectTransform, GUI.Anchor.BottomCenter),
        "GUIFrameListBox"
    )
    actionSep.RectTransform.RelativeOffset = Vector2(0, -0.190)
    safeSet(function() actionSep.Color = pal().separatorTeal end)

    local actionBar = GUI.Frame(
        GUI.RectTransform(Vector2(0.92, 0.148), SettingsUI.panel.RectTransform, GUI.Anchor.BottomCenter),
        nil
    )
    actionBar.RectTransform.RelativeOffset = Vector2(0, -0.016)

    local enableAllButton = GUI.Button(
        GUI.RectTransform(Vector2(0.30, 0.82), actionBar.RectTransform, GUI.Anchor.CenterLeft),
        "Enable All", GUI.Alignment.Center, "GUIButton"
    )
    setTextScale(enableAllButton, 1.08)
    enableAllButton.OnClicked = function()
        for key in pairs(DEFAULT_CONFIG) do Mod.Config[key] = true end
        saveConfigToDisk(); sendConfigUpdateToServer(); refreshSettingsUI()
        return true
    end

    local disableAllButton = GUI.Button(
        GUI.RectTransform(Vector2(0.30, 0.82), actionBar.RectTransform, GUI.Anchor.Center),
        "Disable All", GUI.Alignment.Center, "GUIButton"
    )
    setTextScale(disableAllButton, 1.08)
    disableAllButton.OnClicked = function()
        for key in pairs(DEFAULT_CONFIG) do Mod.Config[key] = false end
        saveConfigToDisk(); sendConfigUpdateToServer(); refreshSettingsUI()
        return true
    end

    local closeButton = GUI.Button(
        GUI.RectTransform(Vector2(0.30, 0.82), actionBar.RectTransform, GUI.Anchor.CenterRight),
        "Close", GUI.Alignment.Center, "GUIButton"
    )
    setTextScale(closeButton, 1.08)
    closeButton.OnClicked = function() closeSettingsWindow(); return true end
end

local function toggleSettingsWindow()
    ensureSettingsWindow()
    refreshSettingsUI()
    SettingsUI.isOpen       = not SettingsUI.isOpen
    SettingsUI.root.Visible = SettingsUI.isOpen
end

local function addSettingsUIToGUIUpdateList()
    if SettingsUI.root == nil or SettingsUI.root.Visible ~= true then return end
    local added = safeSet(function() SettingsUI.root.AddToGUIUpdateList(false, 999) end)
    if not added then safeSet(function() SettingsUI.root.AddToGUIUpdateList() end) end
end

-- ---------------------------------------------------------------------------
-- Pause menu button (host only)
-- ---------------------------------------------------------------------------

local function looksLikeCharacter(entity)
    if entity == nil then return false end
    return safeGet(function() return entity.CharacterHealth end) ~= nil
end

local function enumerateChildren(component)
    local result = {}
    if component == nil then return result end
    local children = safeGet(function() return component.Children end)
    if children == nil then return result end
    for child in children do result[#result + 1] = child end
    return result
end

local function isLayoutGroup(component)
    return safeGet(function()
        local _ = component.AbsoluteSpacing; return true
    end) == true
end

local function findPauseButtonContainer(root)
    local best, bestScore = nil, -1
    local function visit(node)
        if node == nil then return end
        local children = enumerateChildren(node)
        if isLayoutGroup(node) then
            local n = 0
            for _, child in ipairs(children) do
                if safeGet(function() return child.TextBlock end) ~= nil then n = n + 1 end
            end
            if n >= 3 then
                local score = n * 10 + #children
                if score > bestScore then best = node; bestScore = score end
            end
        end
        for _, child in ipairs(children) do visit(child) end
    end
    visit(root)
    return best
end

local function ensurePauseMenuButton()
    if not isHostPlayer() then return end

    local pauseMenu = safeGet(function() return GUI.PauseMenu end)
    if pauseMenu == nil then return end

    if SettingsUI.pauseMenu ~= pauseMenu then
        SettingsUI.pauseMenu   = pauseMenu
        SettingsUI.pauseButton = nil
    end
    if SettingsUI.pauseButton ~= nil then return end

    local container = findPauseButtonContainer(pauseMenu)
    if container ~= nil then
        SettingsUI.pauseButton = GUI.Button(
            GUI.RectTransform(Vector2(1, 0.09), container.RectTransform),
            "HUD Remover", GUI.Alignment.Center, "GUIButtonSmall"
        )
    else
        SettingsUI.pauseButton = GUI.Button(
            GUI.RectTransform(Vector2(0.48, 0.065), pauseMenu.RectTransform, GUI.Anchor.BottomCenter),
            "HUD Remover", GUI.Alignment.Center, "GUIButtonSmall"
        )
    end
    SettingsUI.pauseButton.OnClicked = function() toggleSettingsWindow(); return true end
end

local _pauseMenuWasOpen = false

local function updateSettingsMenuState()
    local pauseMenuOpen = safeGet(function() return GUI.PauseMenuOpen end) == true
    if pauseMenuOpen == _pauseMenuWasOpen then return end
    _pauseMenuWasOpen = pauseMenuOpen
    if pauseMenuOpen then
        ensurePauseMenuButton()
    else
        SettingsUI.pauseMenu   = nil
        SettingsUI.pauseButton = nil
        closeSettingsWindow()
    end
end

-- ---------------------------------------------------------------------------
-- Startup
-- ---------------------------------------------------------------------------

if not enforceCopyrightGuard() then return end

loadConfigFromDisk()

-- ---------------------------------------------------------------------------
-- Hooks
-- ---------------------------------------------------------------------------

local function getGUIStatic()
    local gui = safeGet(function() return GUI end)
    if gui == nil then return nil end
    return safeGet(function() return gui.GUI end) or gui
end

local function setDisableCharacterNames(value)
    local guiStatic = getGUIStatic()
    if guiStatic == nil then return false end
    return safeSet(function() guiStatic.DisableCharacterNames = value end)
end

local function getTransparentColor()
    if transparentNameColor ~= nil then return transparentNameColor end
    transparentNameColor = safeGet(function() return Color(255, 255, 255, 0) end)
                        or safeGet(function() return Color.Transparent end)
    return transparentNameColor
end

Hook.Add("think", "HUDRemover.ApplyOverheadHiding", function()
    ensureAccessibility()
    updateSettingsMenuState()
    setDisableCharacterNames(Mod.Config.HideDrawFrontOverhead == true)

    local characterList = safeGet(function() return Character.CharacterList end)
    if characterList == nil then return end
    for _, character in pairs(characterList) do
        applyCharacterOverheadHiding(character)
    end
end)

patchMethod("Barotrauma.Character", "GetNameColor", nil, function(instance, p)
    if not Mod.Config.HideDrawFrontOverhead then return end
    local color = getTransparentColor()
    if color == nil then return end
    return preventExecution(p) or color
end, Hook.HookMethodType.Before)

patchMethod("Barotrauma.CharacterParams", "get_ShowHealthBar", nil, function(instance, p)
    if Mod.Config.HideDrawFrontOverhead then return preventExecution(p) end
end, Hook.HookMethodType.Before)

patchMethod("Barotrauma.Character", "DrawFront", SIG_SPRITEBATCH_CAMERA, function(instance, p)
    if instance == nil then return end
    if Mod.Config.HideDrawFrontOverhead then
        safeSet(function() instance.hudInfoVisible = false end)
        setDisableCharacterNames(true)
    end
    if Mod.Config.HideVoiceChatIndicator and not isLocalPlayerCharacter(instance) then
        safeSet(function() instance.textlessSpeechBubble = nil end)
    end
end, Hook.HookMethodType.Before)

patchMethod("Barotrauma.CharacterHUD", "DrawCharacterHoverTexts", {
        "Microsoft.Xna.Framework.Graphics.SpriteBatch",
        "Barotrauma.Camera",
        "Barotrauma.Character"
    }, function(instance, p)
    if shouldHideHoverTexts() then return preventExecution(p) end
end, Hook.HookMethodType.Before)

patchMethod("Barotrauma.Character", "DrawSpeechBubbles", SIG_SPRITEBATCH_CAMERA, function(instance, p)
    if Mod.Config.HideSpeechBubbles then return preventExecution(p) end
end, Hook.HookMethodType.Before)

local function showTextlessSpeechBubbleHook(instance, p)
    if not Mod.Config.HideVoiceChatIndicator then return end
    if instance == nil then return preventExecution(p) end
    if isLocalPlayerCharacter(instance) then return end
    safeSet(function() instance.textlessSpeechBubble = nil end)
    return preventExecution(p)
end

local patchedVoice = patchMethod("Barotrauma.Character", "ShowTextlessSpeechBubble", {
    "System.Single", "Microsoft.Xna.Framework.Color"
}, showTextlessSpeechBubbleHook, Hook.HookMethodType.Before)

if not patchedVoice then
    patchMethod("Barotrauma.Character", "ShowTextlessSpeechBubble", nil,
                showTextlessSpeechBubbleHook, Hook.HookMethodType.Before)
end

patchMethod("Barotrauma.Character", "DrawGUIMessages", SIG_SPRITEBATCH_CAMERA, function(instance, p)
    if Mod.Config.HideFloatingMessages then return preventExecution(p) end
end, Hook.HookMethodType.Before)

patchMethod("Barotrauma.CharacterHUD", "DrawOrderIndicator", {
    "Microsoft.Xna.Framework.Graphics.SpriteBatch",
    "Barotrauma.Camera",
    "Barotrauma.Character",
    "Barotrauma.Order",
    "System.Single",
    "System.Boolean",
    "System.Single",
    "System.Boolean"
}, function(instance, p)
    if not Mod.Config.HideOrderIconsOnCharacters then return end
    local order = p and (p["order"] or p[4]) or nil
    if order == nil then return end
    local target = safeGet(function() return order.TargetSpatialEntity end)
    if looksLikeCharacter(target) then return preventExecution(p) end
end, Hook.HookMethodType.Before)

patchMethod("Barotrauma.CharacterHUD", "DrawObjectiveIndicator", {
    "Microsoft.Xna.Framework.Graphics.SpriteBatch",
    "Barotrauma.Camera",
    "Barotrauma.Character",
    "Barotrauma.Character+ObjectiveEntity",
    "System.Single"
}, function(instance, p)
    if not Mod.Config.HideObjectiveIconsOnCharacters then return end
    local objectiveEntity = p and (p["objectiveEntity"] or p[4]) or nil
    if objectiveEntity == nil then return end
    local target = safeGet(function() return objectiveEntity.Entity end)
    if looksLikeCharacter(target) then return preventExecution(p) end
end, Hook.HookMethodType.Before)

patchMethod("Barotrauma.GameSession", "AddToGUIUpdateList", nil, function(instance, p)
    addSettingsUIToGUIUpdateList()
end, Hook.HookMethodType.After)

patchMethod("Barotrauma.GameScreen", "AddToGUIUpdateList", nil, function(instance, p)
    addSettingsUIToGUIUpdateList()
end, Hook.HookMethodType.After)
