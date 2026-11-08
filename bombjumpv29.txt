local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local VirtualUser = game:GetService("VirtualUser")
local sharedEnv = type(getgenv) == "function" and getgenv() or _G

if type(sharedEnv.__StandaloneBombJumpFireflyCleanup) == "function" then
    pcall(sharedEnv.__StandaloneBombJumpFireflyCleanup)
end
if type(sharedEnv.__StandaloneBombJumpFireflyDiagnosticsCleanup) == "function" then
    pcall(sharedEnv.__StandaloneBombJumpFireflyDiagnosticsCleanup)
end
-- Recover controls if the previously executed v13 left PlayerModule controls disabled.
pcall(function()
    local previousControls = sharedEnv.__StandaloneBombJumpFireflyMovementControls
    if previousControls then
        previousControls:Enable()
    end
    sharedEnv.__StandaloneBombJumpFireflyMovementControls = nil
end)
sharedEnv.__StandaloneBombJumpFireflyCleanup = nil

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

-- Diagnostic-only panel. Stored in one namespace to avoid increasing the
-- script's long-lived top-level local count (Luau has a per-function local limit).
local fireflyDiag = {}
do
    fireflyDiag.lines = {}
    fireflyDiag.startedAt = os.clock()

    fireflyDiag.refresh = function()
        local state = fireflyDiag
        if not state.textLabel or not state.scroll then
            return
        end
        local first = math.max(1, #state.lines - 11)
        local shown = {}
        for i = first, #state.lines do
            shown[#shown + 1] = state.lines[i]
        end
        state.textLabel.Text = table.concat(shown, "\n")
        local height = math.max(160, #shown * 18)
        state.textLabel.Size = UDim2.new(1, -8, 0, height)
        state.scroll.CanvasSize = UDim2.new(0, 0, 0, height + 6)
        state.scroll.CanvasPosition = Vector2.new(0, math.max(0, height - state.scroll.AbsoluteSize.Y))
    end

    fireflyDiag.log = function(tag, detail)
        local state = fireflyDiag
        local elapsed = os.clock() - state.startedAt
        local line = string.format("+%.3fs | %s%s", elapsed, tostring(tag),
            detail ~= nil and (" | " .. tostring(detail)) or "")
        state.lines[#state.lines + 1] = line
        if #state.lines > 180 then
            table.remove(state.lines, 1)
        end
        pcall(state.refresh)
    end

    local function makeButton(parent, name, buttonText, pos, size, callback)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Position = pos
        button.Size = size
        button.BackgroundColor3 = Color3.fromRGB(45, 48, 58)
        button.BorderSizePixel = 0
        button.TextColor3 = Color3.fromRGB(240, 242, 248)
        button.TextSize = 11
        button.Font = Enum.Font.GothamSemibold
        button.Text = buttonText
        button.AutoButtonColor = true
        button.Parent = parent
        button.Activated:Connect(callback)
        return button
    end

    local function createGui()
        local state = fireflyDiag
        local gui = Instance.new("ScreenGui")
        gui.Name = "__Standalone_BombJump_Firefly_Diagnostics"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 10000
        local parentOk = pcall(function() gui.Parent = CoreGui end)
        if not parentOk or not gui.Parent then
            local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 3)
            if playerGui then gui.Parent = playerGui end
        end
        if not gui.Parent then
            gui:Destroy()
            return
        end
        state.gui = gui

        local panel = Instance.new("Frame")
        panel.Name = "Panel"
        panel.AnchorPoint = Vector2.new(0.5, 0)
        panel.Position = UDim2.new(0.5, 0, 0.06, 0)
        panel.Size = UDim2.new(0.96, 0, 0, 238)
        panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
        panel.BorderSizePixel = 0
        panel.Active = true
        panel.Draggable = true
        panel.Parent = gui
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = panel
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(88, 96, 116)
        stroke.Thickness = 1
        stroke.Parent = panel
        state.panel = panel

        local header = Instance.new("Frame")
        header.Name = "Header"
        header.Size = UDim2.new(1, 0, 0, 32)
        header.BackgroundColor3 = Color3.fromRGB(34, 37, 46)
        header.BorderSizePixel = 0
        header.Parent = panel
        header.Active = true
        header.Draggable = true
        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Position = UDim2.new(0, 9, 0, 0)
        title.Size = UDim2.new(1, -190, 1, 0)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 11
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = Color3.fromRGB(238, 240, 248)
        title.Text = "FIREFLY DEBUG v18"
        title.Parent = header
        makeButton(header, "Copy", "COPIAR", UDim2.new(1, -174, 0, 5), UDim2.new(0, 57, 0, 22), function()
            local content = table.concat(state.lines, "\n")
            local ok = false
            if type(setclipboard) == "function" then
                ok = pcall(setclipboard, content)
            elseif type(toclipboard) == "function" then
                ok = pcall(toclipboard, content)
            end
            if state.statusLabel then
                state.statusLabel.Text = ok and "Histórico copiado." or "Clipboard indisponível: envie uma captura do painel."
            end
        end)
        makeButton(header, "Clear", "LIMPAR", UDim2.new(1, -112, 0, 5), UDim2.new(0, 54, 0, 22), function()
            state.lines = {}
            state.startedAt = os.clock()
            state.log("DIAG", "Histórico limpo; aguardando eventos")
        end)
        makeButton(header, "Hide", "MIN", UDim2.new(1, -54, 0, 5), UDim2.new(0, 47, 0, 22), function()
            panel.Visible = false
            if state.toggle then state.toggle.Visible = true end
        end)

        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "LogScroll"
        scroll.Position = UDim2.new(0, 6, 0, 37)
        scroll.Size = UDim2.new(1, -12, 1, -61)
        scroll.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 5
        scroll.CanvasSize = UDim2.new(0, 0, 0, 160)
        scroll.Parent = panel
        local scrollCorner = Instance.new("UICorner")
        scrollCorner.CornerRadius = UDim.new(0, 5)
        scrollCorner.Parent = scroll
        state.scroll = scroll
        local body = Instance.new("TextLabel")
        body.Name = "LogText"
        body.Position = UDim2.new(0, 4, 0, 3)
        body.Size = UDim2.new(1, -8, 0, 160)
        body.BackgroundTransparency = 1
        body.Font = Enum.Font.Code
        body.TextSize = 10
        body.TextColor3 = Color3.fromRGB(215, 222, 236)
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.TextWrapped = true
        body.Text = "Iniciando diagnóstico..."
        body.Parent = scroll
        state.textLabel = body
        local status = Instance.new("TextLabel")
        status.Name = "Status"
        status.Position = UDim2.new(0, 8, 1, -20)
        status.Size = UDim2.new(1, -16, 0, 16)
        status.BackgroundTransparency = 1
        status.Font = Enum.Font.Gotham
        status.TextSize = 9
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.TextColor3 = Color3.fromRGB(174, 183, 201)
        status.Text = "Copie o histórico após reproduzir o atraso."
        status.Parent = panel
        state.statusLabel = status
        state.toggle = makeButton(gui, "ShowDiagnostics", "FIRE FLY DBG", UDim2.new(1, -116, 0, 58), UDim2.new(0, 108, 0, 26), function()
            panel.Visible = true
            state.toggle.Visible = false
        end)
        state.toggle.Visible = false
        state.refresh()
    end

    pcall(createGui)
    sharedEnv.__StandaloneBombJumpFireflyDiagnosticsCleanup = function()
        pcall(function()
            if fireflyDiag.gui then fireflyDiag.gui:Destroy() end
        end)
    end
    fireflyDiag.log("SCRIPT", "v29 loaded; walking target velocity accepted up to 24 studs/s; lead bounded to 8.4; takeoff release retained")
end

local Config = {
    BOMB_AIM_DROP_BASE = 0.025,
    BOMB_AIM_DROP_MAX = 0.040,
    BOMB_BOUNCE_CHECK_RADIUS = 3.5,
    BOMB_BOUNCE_INPUT_HOLD_TIME = 0.25,
    BOMB_BOUNCE_TRACK_TIME = 1.25,
    BOMB_DRAG_THRESHOLD = 8,
    BOMB_EQUIP_TIMEOUT = 0.18,
    BOMB_FORWARD_BIAS = 0.055,
    BOMB_FORWARD_MAX = 0.11,
    BOMB_FORWARD_PING_SCALE = 0.04,
    BOMB_FORWARD_SPEED_SCALE = 0.0018,
    BOMB_GROUND_SINK = 0.08,
    BOMB_HIGH_PING_FORWARD_MAX = 2.00,
    BOMB_HIGH_PING_FORWARD_MIN = 0.35,
    BOMB_HIGH_PING_FORWARD_SCALE = 4.0,
    BOMB_HIGH_PING_THRESHOLD = 0.10,
    BOMB_LAUNCH_FALL_SPEED = 18,
    BOMB_MAX_HORIZONTAL_PREDICTION = 0.18,
    BOMB_MAX_SURFACE_RISE = 0.30,
    BOMB_PREDICTION_INPUT_BASE = 0.008,
    BOMB_PREDICTION_INPUT_MAX = 0.020,
    BOMB_PREDICTION_ITERATIONS = 1,
    BOMB_PREDICTION_PING_SCALE = 0.12,
    BOMB_TARGET_CLEARANCE = 0.04,
    BOMB_TARGET_RAY_HEIGHT = 12,
    BOMB_TARGET_RAY_LENGTH = 120,
    BOMB_FREEFALL_GROUND_RAY_MARGIN = 0.10,
    FIREFLY_ARM_INITIAL_TRAVEL_RATIO = 0.025,
    FIREFLY_ARM_REVERSAL_FRAMES = 2,
    FIREFLY_ARM_SECOND_TRAVEL_RATIO = 0.010,
    FIREFLY_ARM_TRACK_TIMEOUT = 4.0,
    FIREFLY_COOLDOWN = 10.0,
    FIREFLY_COOLDOWN_START_DELAY = 6.0,
    FIREFLY_EQUIP_SETTLE_TIME = 0.12,
    FIREFLY_FIRST_JUMP_HOLD_TIME = 0.55,
    FIREFLY_FIRST_JUMP_RETURN_RATIO = 0.15,
    FIREFLY_FORWARD_HOLD_TIME = 0.55,
    FIREFLY_LID_APPROACH_CLEARANCE = 0.12,
    FIREFLY_FORWARD_MOVEMENT_BIND_NAME = "__BombJumpFireflyForwardMovement",
    FIREFLY_JUMP_INPUT_LOCK_NAME = "__BombJumpFireflyJumpInputLock",
    FIREFLY_RELEASE_DELAY = 6.0,
    GOLD_COOLDOWN = 3.2,
    GUI_NAME = "__Standalone_BombJump",
    NORMAL_COOLDOWN = 21.7,
    POSITION_FILE = "BombJump_Standalone_Position.json",
}

pcall(function()
    RunService:UnbindFromRenderStep("__FireflyDoubleJumpIdleMovementLock")
    RunService:UnbindFromRenderStep(Config.FIREFLY_FORWARD_MOVEMENT_BIND_NAME)
    local contextActionService = game:GetService("ContextActionService")
    contextActionService:UnbindAction("__FireflyDoubleJumpMovementLock")
    contextActionService:UnbindAction(Config.FIREFLY_JUMP_INPUT_LOCK_NAME)
end)
pcall(function()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid:GetAttribute("__FireflyMovementLockActive") then
        local originalWalkSpeed = humanoid:GetAttribute("__FireflyMovementLockWalkSpeed")
        if typeof(originalWalkSpeed) == "number" then
            humanoid.WalkSpeed = originalWalkSpeed
        end
        humanoid:SetAttribute("__FireflyMovementLockWalkSpeed", nil)
        humanoid:SetAttribute("__FireflyMovementLockActive", nil)
        humanoid.Jump = false
        humanoid:Move(Vector3.zero, false)
    end
end)

pcall(function()
    local old = CoreGui:FindFirstChild(Config.GUI_NAME)
    if old then
        old:Destroy()
    end
end)

local toyEvent
local function resolveToyEvent()
    if toyEvent and toyEvent.Parent then
        return toyEvent
    end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local extras = remotes and remotes:FindFirstChild("Extras")
    local remote = extras and extras:FindFirstChild("ReplicateToy")
    toyEvent = remote and remote:IsA("RemoteFunction") and remote or nil
    return toyEvent
end

resolveToyEvent()

local savedPositions = {}
local GuiPositionRecovery = {}
pcall(function()
    if type(readfile) == "function" and type(isfile) == "function" and isfile(Config.POSITION_FILE) then
        local decoded = HttpService:JSONDecode(readfile(Config.POSITION_FILE))
        if type(decoded) == "table" then
            savedPositions = decoded
        end
    end
end)

GuiPositionRecovery.readUDim2 = function(value)
    if type(value) ~= "table" then
        return nil
    end
    local xs, xo, ys, yo = tonumber(value[1]), tonumber(value[2]), tonumber(value[3]), tonumber(value[4])
    if not xs or not xo or not ys or not yo then
        return nil
    end
    return UDim2.new(xs, xo, ys, yo)
end

GuiPositionRecovery.savePositions = function()
    pcall(function()
        if type(writefile) ~= "function" then
            return
        end
        writefile(Config.POSITION_FILE, HttpService:JSONEncode(savedPositions))
    end)
end


GuiPositionRecovery.resolve = function(key, defaultPosition, width, height)
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize
    if not viewport or viewport.X <= 0 or viewport.Y <= 0 then
        return defaultPosition
    end

    local storedPosition = GuiPositionRecovery.readUDim2(savedPositions[key])

    local function isFullyVisible(position)
        if not viewport or viewport.X <= 0 or viewport.Y <= 0 then
            return false
        end

        local x = position.X.Scale * viewport.X + position.X.Offset
        local y = position.Y.Scale * viewport.Y + position.Y.Offset
        return x >= 0
            and y >= 0
            and x + width <= viewport.X
            and y + height <= viewport.Y
    end

    if storedPosition and isFullyVisible(storedPosition) then
        return storedPosition
    end

    local fallbackPosition = defaultPosition
    if viewport and viewport.X > 0 and viewport.Y > 0 and not isFullyVisible(fallbackPosition) then
        local defaultX = fallbackPosition.X.Scale * viewport.X + fallbackPosition.X.Offset
        local defaultY = fallbackPosition.Y.Scale * viewport.Y + fallbackPosition.Y.Offset
        local maxX = math.max(0, viewport.X - width)
        local maxY = math.max(0, viewport.Y - height)
        fallbackPosition = UDim2.fromOffset(
            math.floor(math.clamp(defaultX, 0, maxX)),
            math.floor(math.clamp(defaultY, 0, maxY))
        )
    end

    if storedPosition then
        savedPositions[key] = {
            fallbackPosition.X.Scale,
            fallbackPosition.X.Offset,
            fallbackPosition.Y.Scale,
            fallbackPosition.Y.Offset,
        }
        GuiPositionRecovery.savePositions()
    end

    return fallbackPosition
end

GuiPositionRecovery.clampNumber = function(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local savedBombSettings = type(savedPositions.BombSettings) == "table" and savedPositions.BombSettings or {}

local function savedBoolean(key, defaultValue)
    if type(savedBombSettings[key]) == "boolean" then
        return savedBombSettings[key]
    end
    return defaultValue
end

local function savedNumber(key, defaultValue)
    local value = tonumber(savedBombSettings[key])
    return value or defaultValue
end

local function savedString(key, defaultValue)
    return type(savedBombSettings[key]) == "string" and savedBombSettings[key] or defaultValue
end

if savedBombSettings.BombStyle ~= "Legit"
    and savedBombSettings.BombStyle ~= "Blatant" then
    savedBombSettings.BombStyle = "Legit"
end

local currentColor = Color3.fromRGB(255, 255, 255)
local colorPresets = {
    Color3.fromRGB(255, 255, 255),
    Color3.fromRGB(170, 210, 255),
    Color3.fromRGB(180, 120, 255),
    Color3.fromRGB(255, 100, 170),
    Color3.fromRGB(80, 255, 190),
    Color3.fromRGB(255, 190, 70),
}
local colorIndex = GuiPositionRecovery.clampNumber(math.floor(savedNumber("ColorIndex", 1)), 1, 6)
local savedColor = savedBombSettings.Color
if type(savedColor) == "table" then
    local r = tonumber(savedColor[1])
    local g = tonumber(savedColor[2])
    local b = tonumber(savedColor[3])
    if r and g and b then
        currentColor = Color3.new(
            GuiPositionRecovery.clampNumber(r, 0, 1),
            GuiPositionRecovery.clampNumber(g, 0, 1),
            GuiPositionRecovery.clampNumber(b, 0, 1)
        )
    else
        currentColor = colorPresets[colorIndex]
    end
else
    currentColor = colorPresets[colorIndex]
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = Config.GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = CoreGui

local menu = Instance.new("Frame")
menu.Name = "Settings"
menu.Size = UDim2.fromOffset(290, 340)
menu.Position = GuiPositionRecovery.resolve("Menu", UDim2.new(0.5, -145, 0.5, -175), 290, 340)
menu.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
menu.BorderSizePixel = 0
menu.Parent = screenGui

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 14)
menuCorner.Parent = menu

local menuStroke = Instance.new("UIStroke")
menuStroke.Thickness = 2
menuStroke.Color = currentColor
menuStroke.Transparency = 0.15
menuStroke.Parent = menu

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 54)
titleBar.BackgroundTransparency = 1
titleBar.Active = true
titleBar.Parent = menu

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "BOMB JUMP"
title.TextColor3 = Color3.fromRGB(245, 245, 250)
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -58, 0, 18)
subtitle.Position = UDim2.fromOffset(10, 31)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Standalone controller"
subtitle.TextColor3 = Color3.fromRGB(145, 150, 165)
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = titleBar

local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -20, 1, -68)
content.Position = UDim2.fromOffset(10, 60)
content.CanvasSize = UDim2.fromOffset(0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.ScrollBarThickness = 3
content.ScrollBarImageTransparency = 0.25
content.Active = true
content.ClipsDescendants = true
content.BackgroundTransparency = 1
content.Parent = menu

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local function makeRow(height)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, height or 42)
    row.BackgroundColor3 = Color3.fromRGB(27, 30, 38)
    row.BorderSizePixel = 0
    row.Parent = content
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = row
    return row
end

local function makeLabel(row, textValue)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.56, -8, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.Text = textValue
    label.TextColor3 = Color3.fromRGB(220, 223, 232)
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row
    return label
end

local function makeButton(row, initialText)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.42, -8, 0, 30)
    btn.Position = UDim2.new(0.58, 0, 0.5, -15)
    btn.BackgroundColor3 = Color3.fromRGB(38, 42, 53)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = true
    btn.Font = Enum.Font.GothamBold
    btn.Text = initialText
    btn.TextColor3 = Color3.fromRGB(235, 238, 245)
    btn.TextSize = 11
    btn.Parent = row
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
    return btn
end

local bombUseMode, selectedBombType

do
    local typeSettingsMap = type(savedBombSettings.BombTypeSettings) == "table"
        and savedBombSettings.BombTypeSettings
        or {}
    local legacyMode = savedString("BombUseMode", "Click To Use Bomb")
    local legacyStyle = savedBombSettings.BombStyle

    if legacyMode ~= "Toggle To Use Bomb" and legacyMode ~= "Click To Use Bomb" and legacyMode ~= "Armed To Use Bomb" then
        legacyMode = "Click To Use Bomb"
    end
    if legacyStyle ~= "Legit" and legacyStyle ~= "Blatant" then
        legacyStyle = "Legit"
    end

    selectedBombType = savedString("BombType", "Bomb")
    if selectedBombType ~= "Bomb" and selectedBombType ~= "Gold Bomb" and selectedBombType ~= "Firefly Jar" then
        selectedBombType = "Bomb"
    end

    savedBombSettings.BombTypeSettings = typeSettingsMap
    for _, typeName in ipairs({"Bomb", "Gold Bomb", "Firefly Jar"}) do
        local typeSettings = typeSettingsMap[typeName]
        if type(typeSettings) ~= "table" then
            typeSettings = {}
            typeSettingsMap[typeName] = typeSettings
        end

        if typeSettings.UsageMode ~= "Toggle To Use Bomb"
            and typeSettings.UsageMode ~= "Click To Use Bomb"
            and typeSettings.UsageMode ~= "Armed To Use Bomb" then
            typeSettings.UsageMode = typeName == selectedBombType and legacyMode or "Click To Use Bomb"
        end

        if typeSettings.Style ~= "Legit"
            and typeSettings.Style ~= "Blatant" then
            typeSettings.Style = typeName == selectedBombType and legacyStyle or "Legit"
        end

        if typeName == "Firefly Jar" then
            typeSettings.UsageMode = "Click To Use Bomb"
        end
    end

    local activeTypeSettings = typeSettingsMap[selectedBombType]
    bombUseMode = activeTypeSettings.UsageMode
    savedBombSettings.BombStyle = activeTypeSettings.Style
end
local noGuiTimerBomb = savedBoolean("HideGuiTimer", false)
local showBombJumpGui = savedBoolean("ShowBombJumpButton", false)
local lockBombPosition = savedBoolean("LockBombPosition", false)
local bombJumpGuiSize = GuiPositionRecovery.clampNumber(savedNumber("ButtonSize", 110), 50, 300)
local menuCollapsed = savedBoolean("MenuCollapsed", false)
local isActiveBomb = savedBoolean("IsActive", false) and bombUseMode == "Toggle To Use Bomb"
local isArmedBomb = false
local lastKnownBombTool = nil
local hasTriggeredBomb = false
local isWaitingTimerBomb = false

local bombFrame
local bombButton
local bombStroke
local cooldownOverlay
local draggingBomb = false
local dragInputBomb
local dragStartBomb
local startPosBomb
local movedBomb = false
local dragTouchBomb
local bombActionInProgress = false
local pendingBombJump = false
local pendingBombTool = nil
local pendingBombCharacter = nil
local pendingBombHumanoid = nil
local pendingBombRootPart = nil
local pendingBombWasEquipped = false
local pendingBombManualActivationOriginal = nil
local pendingBombStateConnection = nil
local pendingBombHeartbeatConnection = nil
local pendingBombWasToggle = false
local pendingBombEquipDeadline = 0
local pendingBombLaunchWindowReached = false
local pendingBombLaunchWaitDeadline = nil
local pendingBombStartedInFreefall = false
local pendingBombLaunchInProgress = false
local pendingBombSequenceGeneration = 0
local fireflyTimingChildConnection = nil
local fireflyTimingRenderConnection = nil
local fireflyTimingActive = false
local fireflyTimingStartedAt = 0
local fireflyTimingElapsed = nil
local fireflyDoubleJumpRenderConnection = nil
local fireflyDoubleJumpStateConnection = nil
local fireflyDoubleJumpJumpingConnection = nil
local fireflyDoubleJumpPhysicsConnection = nil
local fireflyDoubleJumpLidConnection = nil
local fireflyDoubleJumpForwardConnection = nil
local fireflyDoubleJumpJumpConnection = nil
local fireflySecondJumpClearConnection = nil
local fireflyDoubleJumpLid = nil
local fireflyFirstJumpTriggered = false
local bombCooldownGeneration = 0
local resetBombCooldown
local cancelFireflyDoubleJump
local cancelPendingBombJump
local bombPressInput = nil
local bombPressReleased = false
local bombPressWasDragged = false
local bombToolActivationLocked = false
local bombToolActivationOriginal = nil
local bombToolActivationReference = nil
local preEquippedBombTool = nil
local preEquippedBombWasEquipped = false
local preEquippedBombAt = 0
local preEquipBombGeneration = 0

local function findSelectedBombTool(container)
    if not container then
        return nil
    end

    local preferredName
    if selectedBombType == "Gold Bomb" then
        preferredName = "GoldBomb"
    elseif selectedBombType == "Firefly Jar" then
        preferredName = "Fireflies"
    else
        preferredName = "FakeBomb"
    end

    if selectedBombType == "Firefly Jar" then
        local exact = container:FindFirstChild("Fireflies")
        if exact and exact:IsA("Tool") then
            return exact
        end

        local toys = container:FindFirstChild("Toys")
        local fireflies = toys and toys:FindFirstChild("Fireflies")
        if fireflies and fireflies:IsA("Tool") then
            return fireflies
        end

        return nil
    end

    local exact = container:FindFirstChild(preferredName)
    if exact and exact:IsA("Tool") then
        return exact
    end

    return nil
end

local function findRealFireflyJar(player)
    if not player then
        return nil
    end

    local backpack = player:FindFirstChild("Backpack")
    local character = player.Character
    if character then
        local fireflies = character:FindFirstChild("Fireflies")
        if fireflies and fireflies:IsA("Tool") then
            return fireflies
        end
    end

    if backpack then
        local fireflies = backpack:FindFirstChild("Fireflies")
        if fireflies and fireflies:IsA("Tool") then
            return fireflies
        end
    end

    return nil
end

local function prepareRealFireflyJar(player)
    if not player then
        return nil
    end

    local backpack = player:FindFirstChild("Backpack")
    local character = player.Character
    if not backpack then
        return nil
    end

    local fireflies = findRealFireflyJar(player)
    if fireflies then
        return fireflies
    end

    local toys = backpack:FindFirstChild("Toys")
    local toyFireflies = toys and toys:FindFirstChild("Fireflies")
    if not toyFireflies or not toyFireflies:IsA("Tool") then
        return nil
    end

    local remote = resolveToyEvent()
    if not remote then
        return nil
    end

    pcall(function()
        remote:InvokeServer("Fireflies")
    end)

    local deadline = os.clock() + math.max(Config.BOMB_EQUIP_TIMEOUT, 0.50)
    while os.clock() < deadline do
        fireflies = findRealFireflyJar(player)
        if fireflies then
            return fireflies
        end
        RunService.Heartbeat:Wait()
    end

    return findRealFireflyJar(player)
end


local function clearPreEquippedBomb()
    preEquipBombGeneration = preEquipBombGeneration + 1
    preEquippedBombTool = nil
    preEquippedBombWasEquipped = false
    preEquippedBombAt = 0
end

local function requestFastBombEquip(humanoid, character, bombTool)
    if not humanoid or not character or not bombTool then
        return
    end

    if bombTool.Parent == character then
        lastKnownBombTool = bombTool
    elseif bombTool.Parent == LocalPlayer:FindFirstChild("Backpack") then
        lastKnownBombTool = bombTool
    end

    preEquipBombGeneration = preEquipBombGeneration + 1
    local generation = preEquipBombGeneration

    pcall(function()
        humanoid:EquipTool(bombTool)
    end)

    if bombTool.Parent ~= character then
        pcall(function()
            bombTool.Parent = character
        end)
    end

    if bombTool.Parent == character then
        preEquippedBombAt = os.clock()
    end

    task.spawn(function()
        local deadline = os.clock() + 2.50
        while preEquipBombGeneration == generation
            and bombTool.Parent ~= character
            and os.clock() < deadline do
            pcall(function()
                humanoid:EquipTool(bombTool)
            end)
            if bombTool.Parent ~= character then
                pcall(function()
                    bombTool.Parent = character
                end)
            end
            if bombTool.Parent == character and preEquippedBombAt == 0 then
                preEquippedBombAt = os.clock()
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

local function releaseScriptEquippedBomb(bombTool, character, humanoid, wasPreviouslyEquipped)
    if wasPreviouslyEquipped or not bombTool or not character or not humanoid then
        return
    end

    task.spawn(function()
        pcall(function()
            if bombTool.Parent == character then
                humanoid:UnequipTools()
            end
        end)

        RunService.Heartbeat:Wait()

        pcall(function()
            if bombTool.Parent == character then
                local backpack = LocalPlayer:FindFirstChild("Backpack")
                if backpack then
                    bombTool.Parent = backpack
                end
            end
        end)
    end)
end
local lockBombActivation
local unlockBombActivation
local saveBombSettings
local renderBombVisualState
local isBombJumpGrounded

local function getBombTextSize()
    return math.clamp(math.floor(bombJumpGuiSize / 8), 12, 32)
end

local function updateBombVisuals()
    if not bombButton or not bombStroke then
        return
    end
    bombButton.TextSize = getBombTextSize()
    bombFrame.Size = UDim2.new(0, bombJumpGuiSize, 0, bombJumpGuiSize * (100 / 220))
    if not isWaitingTimerBomb
        and not (pendingBombJump and bombUseMode == "Armed To Use Bomb" and not pendingBombWasToggle)
        and not (bombUseMode == "Armed To Use Bomb" and isArmedBomb)
        and not (bombUseMode == "Toggle To Use Bomb" and isActiveBomb) then
        bombStroke.Color = currentColor
    end
end

local defaultBombPos = UDim2.new(1, -240, 1, -210)

local bombGui = Instance.new("ScreenGui")
bombGui.Name = "BombJumpButtonGui"
bombGui.ResetOnSpawn = false
bombGui.IgnoreGuiInset = true
bombGui.DisplayOrder = 1000000
bombGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
bombGui.Enabled = false
bombGui.Parent = CoreGui

bombFrame = Instance.new("Frame")
bombFrame.Name = "BombFrame"
bombFrame.Size = UDim2.new(0, bombJumpGuiSize, 0, bombJumpGuiSize * (100 / 220))
bombFrame.Position = GuiPositionRecovery.resolve(
    "BombButton",
    defaultBombPos,
    bombJumpGuiSize,
    bombJumpGuiSize * (100 / 220)
)
bombFrame.BackgroundTransparency = 1
bombFrame.Parent = bombGui

local bombCorner = Instance.new("UICorner")
bombCorner.CornerRadius = UDim.new(0, 4)
bombCorner.Parent = bombFrame

bombStroke = Instance.new("UIStroke")
bombStroke.Color = currentColor
bombStroke.Thickness = 3.5
bombStroke.Parent = bombFrame

bombButton = Instance.new("TextButton")
bombButton.Size = UDim2.fromScale(1, 1)
bombButton.BackgroundTransparency = 1
bombButton.Text = selectedBombType == "Firefly Jar"
    and "Jar jump"
    or (bombUseMode == "Toggle To Use Bomb" and (isActiveBomb and "Ready" or "Bomb Jump (OFF)") or "Bomb Jump")
bombButton.TextColor3 = Color3.fromRGB(255, 255, 255)
bombButton.TextSize = getBombTextSize()
bombButton.TextXAlignment = Enum.TextXAlignment.Center
bombButton.TextYAlignment = Enum.TextYAlignment.Center
bombButton.TextWrapped = true
bombButton.Font = Enum.Font.GothamBold
bombButton.ZIndex = 2
bombButton.Parent = bombFrame

cooldownOverlay = Instance.new("Frame")
cooldownOverlay.Name = "CooldownOverlay"
cooldownOverlay.Position = UDim2.fromOffset(-4, -4)
cooldownOverlay.Size = UDim2.new(1, 8, 1, 8)
cooldownOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
cooldownOverlay.BackgroundTransparency = 1
cooldownOverlay.BorderSizePixel = 0
cooldownOverlay.Active = false
cooldownOverlay.ZIndex = 100
cooldownOverlay.Parent = bombButton

local cooldownCorner = Instance.new("UICorner")
cooldownCorner.CornerRadius = UDim.new(0, 8)
cooldownCorner.Parent = cooldownOverlay

bombGui.Enabled = showBombJumpGui

local function saveBombButtonPosition()
    savedPositions.BombButton = {
        bombFrame.Position.X.Scale,
        bombFrame.Position.X.Offset,
        bombFrame.Position.Y.Scale,
        bombFrame.Position.Y.Offset,
    }
    GuiPositionRecovery.savePositions()
end

saveBombSettings = function()
    local typeSettingsMap = savedBombSettings.BombTypeSettings
    if type(typeSettingsMap) == "table" then
        local currentTypeSettings = typeSettingsMap[selectedBombType]
        if type(currentTypeSettings) == "table" then
            currentTypeSettings.UsageMode = selectedBombType == "Firefly Jar"
                and "Click To Use Bomb"
                or bombUseMode
            currentTypeSettings.Style = savedBombSettings.BombStyle or currentTypeSettings.Style or "Legit"
        end
    end

    savedPositions.BombSettings = {
        BombUseMode = bombUseMode,
        BombType = selectedBombType,
        BombStyle = savedBombSettings.BombStyle or "Legit",
        BombTypeSettings = typeSettingsMap,
        HideGuiTimer = noGuiTimerBomb,
        ShowBombJumpButton = showBombJumpGui,
        LockBombPosition = lockBombPosition,
        ButtonSize = bombJumpGuiSize,
        MenuCollapsed = menuCollapsed,
        IsActive = isActiveBomb,
        ColorIndex = colorIndex,
        Color = {currentColor.R, currentColor.G, currentColor.B},
    }
    GuiPositionRecovery.savePositions()
end

bombButton.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end

    draggingBomb = false
    dragTouchBomb = input
    movedBomb = false
    bombPressInput = input
    bombPressReleased = false
    bombPressWasDragged = false
    lockBombActivation()

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local grounded = character and humanoid and rootPart and isBombJumpGrounded(character, humanoid, rootPart)
    local shouldPreEquip = not isWaitingTimerBomb and selectedBombType ~= "Firefly Jar" and (
        (bombUseMode == "Toggle To Use Bomb" and not isActiveBomb)
        or (bombUseMode == "Armed To Use Bomb" and grounded == true)
        or bombUseMode == "Click To Use Bomb"
    )

    if shouldPreEquip then
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local bombTool
        if selectedBombType == "Firefly Jar" then
            bombTool = prepareRealFireflyJar(LocalPlayer)
        else
            bombTool = bombToolActivationReference
                or preEquippedBombTool
                or lastKnownBombTool
                or findSelectedBombTool(character)
                or findSelectedBombTool(backpack)

            if bombTool and bombTool.Parent ~= character and bombTool.Parent ~= backpack then
                bombTool = findSelectedBombTool(character)
                    or findSelectedBombTool(backpack)
            end
        end

        if humanoid and bombTool then
            preEquippedBombTool = bombTool
            preEquippedBombWasEquipped = bombTool.Parent == character
            if not preEquippedBombWasEquipped then
                requestFastBombEquip(humanoid, character, bombTool)
            end
        end
    end

    if not lockBombPosition then
        draggingBomb = true
        dragStartBomb = input.Position
        startPosBomb = bombFrame.Position
    end

    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End and dragTouchBomb == input then
            draggingBomb = false
            dragTouchBomb = nil
            dragInputBomb = nil
            bombPressReleased = true
            local wasDragged = bombPressWasDragged
            bombPressInput = nil
            saveBombButtonPosition()
            if wasDragged then
                clearPreEquippedBomb()
            end
            if wasDragged or not pendingBombJump then
                unlockBombActivation()
            end
        end
    end)
end)

bombButton.InputChanged:Connect(function(input)
    if lockBombPosition then
        return
    end
    if dragTouchBomb and input ~= dragTouchBomb then
        return
    end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInputBomb = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if lockBombPosition or not draggingBomb then
        return
    end
    if dragTouchBomb and input.UserInputType == Enum.UserInputType.Touch and input ~= dragTouchBomb then
        return
    end
    if input ~= dragInputBomb and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local delta = input.Position - dragStartBomb
    if math.abs(delta.X) > Config.BOMB_DRAG_THRESHOLD or math.abs(delta.Y) > Config.BOMB_DRAG_THRESHOLD then
        movedBomb = true
        bombPressWasDragged = true

        if preEquippedBombTool and not preEquippedBombWasEquipped then
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid and preEquippedBombTool.Parent == character then
                pcall(function()
                    humanoid:UnequipTools()
                end)
            end
        end

        clearPreEquippedBomb()
    end

    bombFrame.Position = UDim2.new(
        startPosBomb.X.Scale,
        startPosBomb.X.Offset + delta.X,
        startPosBomb.Y.Scale,
        startPosBomb.Y.Offset + delta.Y
    )
end)

local function makeToggleRow(textValue, initialValue, callback)
    local row = makeRow(42)
    makeLabel(row, textValue)
    local btn = makeButton(row, initialValue and "ON" or "OFF")
    local function render(value)
        btn.Text = value and "ON" or "OFF"
        btn.TextColor3 = value and Color3.fromRGB(80, 255, 170) or Color3.fromRGB(235, 238, 245)
    end
    btn.Activated:Connect(function()
        initialValue = not initialValue
        render(initialValue)
        callback(initialValue)
    end)
    render(initialValue)
    return btn
end

makeToggleRow("Show Bomb Jump Button", showBombJumpGui, function(value)
    showBombJumpGui = value
    bombGui.Enabled = value
    if value then
        bombFrame.Position = GuiPositionRecovery.resolve(
            "BombButton",
            defaultBombPos,
            bombJumpGuiSize,
            bombJumpGuiSize * (100 / 220)
        )
    else
        cancelPendingBombJump()
        unlockBombActivation()
        isActiveBomb = false
        hasTriggeredBomb = false
    end
    saveBombSettings()
    renderBombVisualState()
end)

local openDropdown = nil

local function closeOpenDropdown()
    if openDropdown then
        openDropdown.Visible = false
        openDropdown = nil
    end
end

local function makeDropdownSelector(labelText, initialText, options, callback)
    local row = makeRow(42)
    makeLabel(row, labelText)
    local button = makeButton(row, initialText)

    local dropdownHeight = 14 + (#options * 36) + (math.max(#options - 1, 0) * 4)
    local dropdown = makeRow(dropdownHeight)
    dropdown.Visible = false
    dropdown.ZIndex = 20
    dropdown.BackgroundColor3 = Color3.fromRGB(24, 27, 35)

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 7)
    padding.PaddingBottom = UDim.new(0, 7)
    padding.PaddingLeft = UDim.new(0, 7)
    padding.PaddingRight = UDim.new(0, 7)
    padding.Parent = dropdown

    local dropdownLayout = Instance.new("UIListLayout")
    dropdownLayout.Padding = UDim.new(0, 4)
    dropdownLayout.FillDirection = Enum.FillDirection.Vertical
    dropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
    dropdownLayout.Parent = dropdown

    for index, option in ipairs(options) do
        local optionButton = Instance.new("TextButton")
        optionButton.Size = UDim2.new(1, 0, 0, 36)
        optionButton.BackgroundColor3 = Color3.fromRGB(38, 42, 53)
        optionButton.BorderSizePixel = 0
        optionButton.AutoButtonColor = true
        optionButton.Font = Enum.Font.GothamBold
        optionButton.Text = option.text
        optionButton.TextColor3 = Color3.fromRGB(235, 238, 245)
        optionButton.TextSize = 11
        optionButton.LayoutOrder = index
        optionButton.ZIndex = 21
        optionButton.Parent = dropdown

        local optionCorner = Instance.new("UICorner")
        optionCorner.CornerRadius = UDim.new(0, 8)
        optionCorner.Parent = optionButton

        optionButton.Activated:Connect(function()
            callback(option.value, option.text)
            button.Text = option.text
            closeOpenDropdown()
        end)
    end

    button.Activated:Connect(function()
        if openDropdown == dropdown then
            closeOpenDropdown()
            return
        end
        closeOpenDropdown()
        dropdown.Visible = true
        openDropdown = dropdown
    end)

    return button, dropdown
end

local typeOptions = {
    {value = "Bomb", text = "Bomb"},
    {value = "Gold Bomb", text = "Gold Bomb"},
    {value = "Firefly Jar", text = "Firefly Jar"},
}

local updateModeOptionsForBombType

makeDropdownSelector("Bomb Type", selectedBombType, typeOptions, function(newType)
    if selectedBombType == newType then
        return
    end

    cancelPendingBombJump()
    if resetBombCooldown then
        resetBombCooldown()
    end

    local typeSettingsMap = savedBombSettings.BombTypeSettings
    if type(typeSettingsMap) ~= "table" then
        typeSettingsMap = {}
        savedBombSettings.BombTypeSettings = typeSettingsMap
    end

    local currentTypeSettings = typeSettingsMap[selectedBombType]
    if type(currentTypeSettings) ~= "table" then
        currentTypeSettings = {}
        typeSettingsMap[selectedBombType] = currentTypeSettings
    end
    currentTypeSettings.UsageMode = selectedBombType == "Firefly Jar"
        and "Click To Use Bomb"
        or bombUseMode
    currentTypeSettings.Style = savedBombSettings.BombStyle or currentTypeSettings.Style or "Legit"

    selectedBombType = newType
    local nextTypeSettings = typeSettingsMap[selectedBombType]
    if type(nextTypeSettings) ~= "table" then
        nextTypeSettings = {UsageMode = "Click To Use Bomb", Style = "Legit"}
        typeSettingsMap[selectedBombType] = nextTypeSettings
    end

    bombUseMode = nextTypeSettings.UsageMode
    if bombUseMode ~= "Toggle To Use Bomb" and bombUseMode ~= "Click To Use Bomb" and bombUseMode ~= "Armed To Use Bomb" then
        bombUseMode = "Click To Use Bomb"
        nextTypeSettings.UsageMode = bombUseMode
    end
    if nextTypeSettings.Style ~= "Legit"
        and nextTypeSettings.Style ~= "Blatant" then
        nextTypeSettings.Style = "Legit"
    end
    savedBombSettings.BombStyle = nextTypeSettings.Style

    if selectedBombType == "Firefly Jar" then
        bombUseMode = "Click To Use Bomb"
        nextTypeSettings.UsageMode = bombUseMode
    end

    isActiveBomb = false
    isArmedBomb = false
    lastKnownBombTool = nil
    saveBombSettings()
    hasTriggeredBomb = false
    if bombButton then
        renderBombVisualState()
    end
    if updateModeOptionsForBombType then
        updateModeOptionsForBombType()
    end
    unlockBombActivation()
end)

do
    local styleOptions = {
        {value = "Legit", text = "Legit"},
        {value = "Blatant", text = "Blatant"},
    }

    local styleButton, styleDropdown = makeDropdownSelector(
        "Style",
        savedBombSettings.BombStyle,
        styleOptions,
        function(newStyle)
            if selectedBombType == "Firefly Jar" then
                return
            end
            if newStyle ~= "Legit" and newStyle ~= "Blatant" then
                return
            end
            if savedBombSettings.BombStyle == newStyle then
                return
            end
            savedBombSettings.BombStyle = newStyle
            saveBombSettings()
        end
    )

    styleButton.Parent.Name = "BombStyleRow"
    styleDropdown.Name = "BombStyleDropdown"
    styleDropdown.Visible = false
end

local function getModeButtonText()
    if bombUseMode == "Toggle To Use Bomb" then
        return "Toggle"
    elseif bombUseMode == "Armed To Use Bomb" then
        return "Armed"
    end
    return "Click"
end

local modeOptions = {
    {value = "Click To Use Bomb", text = "Click"},
    {value = "Toggle To Use Bomb", text = "Toggle"},
    {value = "Armed To Use Bomb", text = "Armed"},
}

local function setBombUseMode(newMode)
    if bombUseMode == newMode then
        return
    end

    cancelPendingBombJump()
    clearPreEquippedBomb()
    local cooldownInProgress = isWaitingTimerBomb
    bombUseMode = newMode
    isActiveBomb = false
    isArmedBomb = false
    hasTriggeredBomb = cooldownInProgress
    saveBombSettings()
    renderBombVisualState()
    unlockBombActivation()
end

local modeButton, modeDropdown = makeDropdownSelector("Usage Mode", getModeButtonText(), modeOptions, function(newMode)
    if selectedBombType == "Firefly Jar" and newMode ~= "Click To Use Bomb" then
        return
    end
    setBombUseMode(newMode)
end)

updateModeOptionsForBombType = function()
    local firefly = selectedBombType == "Firefly Jar"
    if firefly then
        bombUseMode = "Click To Use Bomb"
        modeButton.Text = "Click"
        modeDropdown.Size = UDim2.new(1, 0, 0, 50)
    else
        modeDropdown.Size = UDim2.new(1, 0, 0, 130)
        modeButton.Text = getModeButtonText()
    end

    for _, child in ipairs(modeDropdown:GetChildren()) do
        if child:IsA("TextButton") then
            child.Visible = not firefly or child.Text == "Click"
        end
    end

    local styleRow = content:FindFirstChild("BombStyleRow")
    local styleDropdown = content:FindFirstChild("BombStyleDropdown")
    if styleRow then
        styleRow.Visible = not firefly
        local styleButton = styleRow:FindFirstChildWhichIsA("TextButton")
        if styleButton then
            styleButton.Text = savedBombSettings.BombStyle or "Legit"
        end
    end
    if styleDropdown then
        if firefly and openDropdown == styleDropdown then
            closeOpenDropdown()
        end
        styleDropdown.Visible = false
    end
end

updateModeOptionsForBombType()

local colorNames = {"WHITE", "BLUE", "PURPLE", "PINK", "MINT", "GOLD"}
local colorOptions = {}
for index, name in ipairs(colorNames) do
    colorOptions[index] = {
        value = index,
        text = name,
    }
end

makeDropdownSelector("Border Color", colorNames[colorIndex], colorOptions, function(newIndex)
    colorIndex = newIndex
    currentColor = colorPresets[colorIndex]
    menuStroke.Color = currentColor
    renderBombVisualState()
    saveBombSettings()
end)

makeToggleRow("Hide GUI Timer", noGuiTimerBomb, function(value)
    noGuiTimerBomb = value
    saveBombSettings()
end)


makeToggleRow("Lock Bomb Position", lockBombPosition, function(value)
    lockBombPosition = value
    saveBombSettings()
end)

local sizeRow = makeRow(46)
makeLabel(sizeRow, "Bomb Button Size")

local sizeControls = Instance.new("Frame")
sizeControls.Size = UDim2.fromOffset(126, 30)
sizeControls.Position = UDim2.new(1, -126, 0.5, -15)
sizeControls.BackgroundTransparency = 1
sizeControls.BorderSizePixel = 0
sizeControls.Parent = sizeRow

local sizeMinus = makeButton(sizeControls, "-")
sizeMinus.Size = UDim2.fromOffset(34, 30)
sizeMinus.Position = UDim2.fromOffset(0, 0)

local sizeValue = Instance.new("TextLabel")
sizeValue.Size = UDim2.fromOffset(58, 30)
sizeValue.Position = UDim2.fromOffset(34, 0)
sizeValue.AnchorPoint = Vector2.new(0, 0)
sizeValue.BackgroundTransparency = 1
sizeValue.Font = Enum.Font.GothamBold
sizeValue.TextColor3 = Color3.fromRGB(235, 238, 245)
sizeValue.TextSize = 11
sizeValue.TextXAlignment = Enum.TextXAlignment.Center
sizeValue.TextYAlignment = Enum.TextYAlignment.Center
sizeValue.Text = tostring(bombJumpGuiSize)
sizeValue.Parent = sizeControls

local sizePlus = makeButton(sizeControls, "+")
sizePlus.Size = UDim2.fromOffset(34, 30)
sizePlus.Position = UDim2.fromOffset(92, 0)

local function changeBombSize(delta)
    bombJumpGuiSize = GuiPositionRecovery.clampNumber(bombJumpGuiSize + delta, 50, 300)
    sizeValue.Text = tostring(bombJumpGuiSize)
    updateBombVisuals()
    saveBombSettings()
end
sizeMinus.Activated:Connect(function() changeBombSize(-10) end)
sizePlus.Activated:Connect(function() changeBombSize(10) end)

local statusRow = makeRow(48)
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 1, -8)
statusLabel.Position = UDim2.fromOffset(10, 4)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "Ready"
statusLabel.TextColor3 = Color3.fromRGB(150, 156, 170)
statusLabel.TextSize = 11
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = statusRow

renderBombVisualState = function()
    if not bombButton or not bombStroke then
        return
    end

    if isWaitingTimerBomb then
        bombStroke.Color = Color3.fromRGB(255, 0, 0)
        bombButton.TextColor3 = Color3.fromRGB(255, 70, 70)
        bombButton.AutoButtonColor = false
        if cooldownOverlay then
            cooldownOverlay.BackgroundTransparency = 0.70
        end
        return
    end

    if cooldownOverlay then
        cooldownOverlay.BackgroundTransparency = 1
    end
    bombButton.AutoButtonColor = true

    if bombUseMode == "Armed To Use Bomb" and (isArmedBomb or (pendingBombJump and not pendingBombWasToggle)) then
        bombButton.Text = selectedBombType == "Firefly Jar" and "Jar jump [ARMED]" or "Bomb Jump [ARMED]"
        bombButton.TextColor3 = Color3.fromRGB(255, 220, 80)
        bombStroke.Color = Color3.fromRGB(255, 200, 60)
        return
    end

    if bombUseMode == "Toggle To Use Bomb" and isActiveBomb then
        bombButton.Text = "Ready"
        bombButton.TextColor3 = Color3.fromRGB(50, 255, 50)
        bombStroke.Color = Color3.fromRGB(50, 200, 50)
        return
    end

    bombButton.Text = selectedBombType == "Firefly Jar"
        and "Jar jump"
        or (bombUseMode == "Toggle To Use Bomb" and "Bomb Jump (OFF)" or "Bomb Jump")
    bombButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    bombStroke.Color = currentColor
end

bombGui.Enabled = showBombJumpGui
renderBombVisualState()

local menuDragging = false
local menuDragInput
local menuDragStart
local menuStartPos
local menuTouch

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end
    menuDragging = true
    menuTouch = input
    menuDragStart = input.Position
    menuStartPos = menu.Position
    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End and menuTouch == input then
            menuDragging = false
            menuTouch = nil
            menuDragInput = nil
            savedPositions.Menu = {
                menu.Position.X.Scale,
                menu.Position.X.Offset,
                menu.Position.Y.Scale,
                menu.Position.Y.Offset,
            }
            GuiPositionRecovery.savePositions()
        end
    end)
end)

titleBar.InputChanged:Connect(function(input)
    if menuTouch and input ~= menuTouch then
        return
    end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        menuDragInput = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if not menuDragging then
        return
    end
    if menuTouch and input.UserInputType == Enum.UserInputType.Touch and input ~= menuTouch then
        return
    end
    if input ~= menuDragInput and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    local delta = input.Position - menuDragStart
    menu.Position = UDim2.new(
        menuStartPos.X.Scale,
        menuStartPos.X.Offset + delta.X,
        menuStartPos.Y.Scale,
        menuStartPos.Y.Offset + delta.Y
    )
end)

local collapseButton = Instance.new("TextButton")
collapseButton.Size = UDim2.fromOffset(32, 26)
collapseButton.Position = UDim2.new(1, -40, 0, 8)
collapseButton.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
collapseButton.BorderSizePixel = 0
collapseButton.Text = "-"
collapseButton.Font = Enum.Font.GothamBold
collapseButton.TextColor3 = Color3.fromRGB(235, 238, 245)
collapseButton.TextSize = 14
collapseButton.Parent = menu
local collapseCorner = Instance.new("UICorner")
collapseCorner.CornerRadius = UDim.new(0, 8)
collapseCorner.Parent = collapseButton

collapseButton.Activated:Connect(function()
    menuCollapsed = not menuCollapsed
    content.Visible = not menuCollapsed
    menu.Size = menuCollapsed and UDim2.fromOffset(290, 56) or UDim2.fromOffset(290, 340)
    collapseButton.Text = menuCollapsed and "+" or "-"
    saveBombSettings()
end)

content.Visible = not menuCollapsed
menu.Size = menuCollapsed and UDim2.fromOffset(290, 56) or UDim2.fromOffset(290, 340)
collapseButton.Text = menuCollapsed and "+" or "-"

local function getBombToolName()
    if selectedBombType == "Gold Bomb" then
        return "GoldBomb"
    elseif selectedBombType == "Firefly Jar" then
        return "Fireflies"
    end
    return "FakeBomb"
end

local BombStyleRuntime = {
    FreefallReleaseDelay = 0.10,
}

BombStyleRuntime.usesInstantFreefallLaunch = function()
    return selectedBombType ~= "Firefly Jar"
        and savedBombSettings.BombStyle == "Blatant"
end


local function snapshotExistingFireflyLids()
    local snapshot = {}
    for _, instance in ipairs(Workspace:GetChildren()) do
        if instance.Name == "Handle2" and instance:IsA("Part") then
            snapshot[instance] = true
        end
    end
    return snapshot
end

local function getBombPing(player)
    local ok, ping = pcall(function()
        return player:GetNetworkPing()
    end)
    if not ok or type(ping) ~= "number" then
        return 0
    end
    return math.clamp(ping, 0, 1.0)
end

local function getBombDataPing()
    local value = 0
    pcall(function()
        local network = Stats:FindFirstChild("Network")
        local serverStats = network and network:FindFirstChild("ServerStatsItem")
        local item = serverStats and serverStats:FindFirstChild("Data Ping")
        if item then
            local raw = item:GetValueString()
            local number = tonumber(string.match(raw, "[%d%.]+"))
            if number then
                value = number / 1000
            end
        end
    end)
    return math.clamp(value, 0, 1.0)
end

local function getBombOneWayLatency(player)
    local networkPing = getBombPing(player)
    local dataPing = getBombDataPing()
    local effectivePing = math.max(networkPing, dataPing)
    return math.clamp(effectivePing * 0.5, 0, 0.15), effectivePing
end



local function getFootData(character, rootPart)
    local leftFoot = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg")
    local rightFoot = character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg")

    if leftFoot and rightFoot and leftFoot:IsA("BasePart") and rightFoot:IsA("BasePart") then
        local center = (leftFoot.Position + rightFoot.Position) * 0.5
        local leftBottom = leftFoot.Position.Y - leftFoot.Size.Y * 0.5
        local rightBottom = rightFoot.Position.Y - rightFoot.Size.Y * 0.5
        return center, math.min(leftBottom, rightBottom)
    end

    if leftFoot and leftFoot:IsA("BasePart") then
        return leftFoot.Position, leftFoot.Position.Y - leftFoot.Size.Y * 0.5
    end

    if rightFoot and rightFoot:IsA("BasePart") then
        return rightFoot.Position, rightFoot.Position.Y - rightFoot.Size.Y * 0.5
    end

    return rootPart.Position, rootPart.Position.Y - rootPart.Size.Y * 0.5
end

local function getMovementVelocity(humanoid, rootPart)
    local actualVelocity = rootPart.AssemblyLinearVelocity
    local horizontalVelocity = Vector3.new(actualVelocity.X, 0, actualVelocity.Z)
    local intendedVelocity = Vector3.zero

    pcall(function()
        local moveVelocity = humanoid:GetMoveVelocity()
        intendedVelocity = Vector3.new(moveVelocity.X, 0, moveVelocity.Z)
    end)

    if horizontalVelocity.Magnitude < 0.75 and intendedVelocity.Magnitude > 0.75 then
        horizontalVelocity = intendedVelocity
    end

    return horizontalVelocity
end

local function solveDescendingGroundHitTime(startY, verticalVelocity, targetY, gravity)
    local delta = verticalVelocity * verticalVelocity - 2 * gravity * (targetY - startY)
    if delta < 0 then
        return nil
    end

    local root = math.sqrt(delta)
    local first = (verticalVelocity - root) / gravity
    local second = (verticalVelocity + root) / gravity
    local best = -math.huge

    if first > 0.01 then
        best = math.max(best, first)
    end
    if second > 0.01 then
        best = math.max(best, second)
    end

    if best == -math.huge then
        return nil
    end

    return best
end

local function raycastGroundAt(character, bombTool, targetXZ, originY, rayLength)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {character, bombTool}
    raycastParams.IgnoreWater = false

    local castOriginY = originY or (targetXZ.Y + Config.BOMB_TARGET_RAY_HEIGHT)
    local castLength = rayLength or Config.BOMB_TARGET_RAY_LENGTH
    local origin = Vector3.new(targetXZ.X, castOriginY, targetXZ.Z)
    return Workspace:Raycast(origin, Vector3.new(0, -castLength, 0), raycastParams)
end

local function getPredictedBombTarget(character, humanoid, rootPart, bombTool, player)
    local footCenter, footBottomY = getFootData(character, rootPart)
    local horizontalVelocity = getMovementVelocity(humanoid, rootPart)
    local horizontalSpeed = horizontalVelocity.Magnitude
    local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
    local ping = getBombPing(player)

    local moveDirection = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
    if moveDirection.Magnitude > 0.001 then
        moveDirection = moveDirection.Unit
    elseif horizontalSpeed > 0.75 then
        moveDirection = horizontalVelocity.Unit
    else
        local lookVector = rootPart.CFrame.LookVector
        moveDirection = Vector3.new(lookVector.X, 0, lookVector.Z)
        if moveDirection.Magnitude > 0.001 then
            moveDirection = moveDirection.Unit
        else
            moveDirection = Vector3.zero
        end
    end

    local currentGround = raycastGroundAt(character, bombTool, footCenter)
    local groundedDistance = math.huge
    if currentGround then
        groundedDistance = math.abs(footBottomY - currentGround.Position.Y)
    end

    local nearGround = groundedDistance <= 0.85
    local oneWayLatency = math.clamp(ping * 0.5, 0, 0.08)
    local verticalInfluence = math.clamp(math.abs(verticalVelocity) / 60, 0, 1)

    local predictionHorizon = math.clamp(
        Config.BOMB_PREDICTION_INPUT_BASE
        + oneWayLatency * Config.BOMB_PREDICTION_PING_SCALE
        + verticalInfluence * 0.004,
        Config.BOMB_PREDICTION_INPUT_BASE,
        Config.BOMB_PREDICTION_INPUT_MAX
    )

    if nearGround then
        predictionHorizon = math.min(predictionHorizon, 0.010)
    elseif verticalVelocity > 4 then
        predictionHorizon = math.min(predictionHorizon, 0.014)
    elseif verticalVelocity < -4 then
        predictionHorizon = math.min(predictionHorizon, 0.018)
    end

    local horizontalPrediction = horizontalVelocity * predictionHorizon
    if horizontalPrediction.Magnitude > Config.BOMB_MAX_HORIZONTAL_PREDICTION then
        horizontalPrediction = horizontalPrediction.Unit * Config.BOMB_MAX_HORIZONTAL_PREDICTION
    end

    if nearGround then
        horizontalPrediction = horizontalPrediction * 0.20
    elseif verticalVelocity > 4 then
        horizontalPrediction = horizontalPrediction * 0.45
    elseif verticalVelocity < -4 then
        horizontalPrediction = horizontalPrediction * 0.70
    end

    local forwardDistance = math.clamp(
        Config.BOMB_FORWARD_BIAS
        + horizontalSpeed * Config.BOMB_FORWARD_SPEED_SCALE
        + oneWayLatency * Config.BOMB_FORWARD_PING_SCALE,
        Config.BOMB_FORWARD_BIAS,
        Config.BOMB_FORWARD_MAX
    )

    if nearGround then
        forwardDistance = math.min(forwardDistance, 0.070)
    elseif verticalVelocity > 4 then
        forwardDistance = math.min(forwardDistance, 0.065)
    elseif verticalVelocity < -4 then
        forwardDistance = math.min(forwardDistance, 0.095)
    else
        forwardDistance = math.min(forwardDistance, 0.085)
    end

    local targetXZ = footCenter + horizontalPrediction + moveDirection * forwardDistance
    local groundResult = raycastGroundAt(character, bombTool, targetXZ)

    if currentGround and groundResult then
        local surfaceRise = groundResult.Position.Y - currentGround.Position.Y
        if surfaceRise > Config.BOMB_MAX_SURFACE_RISE then
            targetXZ = footCenter + horizontalPrediction * 0.10 + moveDirection * math.min(forwardDistance, 0.045)
            groundResult = raycastGroundAt(character, bombTool, targetXZ)
        end

        if groundResult and groundResult.Position.Y - currentGround.Position.Y > Config.BOMB_MAX_SURFACE_RISE then
            groundResult = currentGround
            targetXZ = currentGround.Position
        end
    elseif not groundResult and currentGround then
        groundResult = currentGround
        targetXZ = currentGround.Position
    end

    local aimDrop = math.clamp(Config.BOMB_AIM_DROP_BASE, Config.BOMB_AIM_DROP_BASE, Config.BOMB_AIM_DROP_MAX)

    if groundResult then
        return Vector3.new(
            groundResult.Position.X,
            groundResult.Position.Y - aimDrop,
            groundResult.Position.Z
        ), targetXZ - footCenter, groundResult.Instance, predictionHorizon
    end

    return Vector3.new(
        targetXZ.X,
        footBottomY - aimDrop,
        targetXZ.Z
    ), targetXZ - footCenter, nil, predictionHorizon
end

BombStyleRuntime.getBombWorldVerticalBounds = function(bombPart, character, bombTool, containerOverride)
    local candidate = bombPart
    if not candidate and bombTool then
        candidate = bombTool:FindFirstChild("Handle") or bombTool:FindFirstChildWhichIsA("BasePart", true)
    end

    local container = containerOverride
    if not container and candidate then
        local cursor = candidate.Parent
        while cursor and cursor ~= Workspace do
            if cursor:IsA("Model") and cursor ~= character then
                local lowerName = string.lower(cursor.Name)
                if lowerName:find("bomb")
                    or lowerName:find("bomba")
                    or lowerName:find("explosive")
                    or lowerName:find("explosivo")
                    or lowerName:find("tnt")
                    or lowerName:find("dynamite") then
                    container = cursor
                    break
                end
            end
            cursor = cursor.Parent
        end
    end

    local minimumY = math.huge
    local maximumY = -math.huge
    local function includePart(part)
        if not part or not part:IsA("BasePart") then
            return
        end
        local cf = part.CFrame
        local size = part.Size
        local halfHeight = 0.5 * (
            math.abs(cf.RightVector.Y) * size.X
            + math.abs(cf.UpVector.Y) * size.Y
            + math.abs(cf.LookVector.Y) * size.Z
        )
        minimumY = math.min(minimumY, part.Position.Y - halfHeight)
        maximumY = math.max(maximumY, part.Position.Y + halfHeight)
    end

    if container and container:IsA("Model") then
        for _, instance in ipairs(container:GetDescendants()) do
            includePart(instance)
        end
    elseif container and container:IsA("BasePart") then
        includePart(container)
    else
        includePart(candidate)
    end

    if minimumY == math.huge or maximumY == -math.huge then
        return nil, nil
    end
    return minimumY, maximumY
end

local function getBombThrowTarget(character, rootPart, humanoid, bombTool, player, forceBelowFeet)
    if not character or not rootPart or not humanoid then
        return nil
    end

    local footCenter, footBottomY = getFootData(character, rootPart)

    local lookVector = rootPart.CFrame.LookVector
    local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)

    if flatLook.Magnitude <= 0.001 then
        local moveDirection = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
        if moveDirection.Magnitude <= 0.001 then
            flatLook = Vector3.new(0, 0, -1)
        else
            flatLook = moveDirection
        end
    end

    flatLook = flatLook.Unit

    local velocity = rootPart.AssemblyLinearVelocity
    local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
    local horizontalSpeed = horizontalVelocity.Magnitude
    local verticalVelocity = velocity.Y
    local state = humanoid:GetState()

    local isFreefall = state == Enum.HumanoidStateType.Freefall
    local isFalling = forceBelowFeet == true or (isFreefall and verticalVelocity < -1)

    if isFalling then
        local oneWayLatency = getBombOneWayLatency(player)

        local gravity = workspace.Gravity
        local futureVerticalDelta =
            verticalVelocity * oneWayLatency
            - 0.5 * gravity * oneWayLatency * oneWayLatency
        local futureHorizontalDelta = horizontalVelocity * oneWayLatency
        local predictedFootCenter = footCenter + Vector3.new(
            futureHorizontalDelta.X,
            futureVerticalDelta,
            futureHorizontalDelta.Z
        )
        local predictedFootBottomY = footBottomY + futureVerticalDelta
        local fallingSpeed = math.max(0, -verticalVelocity)
        local fallDistanceEstimate = (fallingSpeed * fallingSpeed) / (2 * gravity)

        local belowFeet = math.clamp(
            3.20
            + fallingSpeed * 0.030
            + math.clamp(fallDistanceEstimate, 0, 18) * 0.14,
            3.20,
            7.50
        )

        local aimDirection = flatLook
        local forwardDistance = forceBelowFeet and 0 or math.clamp(
            1.50 + horizontalSpeed * 0.004,
            1.15,
            1.65
        )

        local targetXZ = Vector3.new(
            predictedFootCenter.X + aimDirection.X * forwardDistance,
            predictedFootBottomY - belowFeet,
            predictedFootCenter.Z + aimDirection.Z * forwardDistance
        )
        local targetBodyMinimumY, targetBodyMaximumY = BombStyleRuntime.getBombWorldVerticalBounds(
            nil,
            character,
            bombTool
        )
        local targetBodyHeight = targetBodyMinimumY and targetBodyMaximumY
            and math.max(0.5, targetBodyMaximumY - targetBodyMinimumY)
            or 1
        local targetBodyBottomY = targetXZ.Y - targetBodyHeight
        local groundRayOriginY = predictedFootBottomY + Config.BOMB_FREEFALL_GROUND_RAY_MARGIN
        local groundRayLength = math.max(
            Config.BOMB_FREEFALL_GROUND_RAY_MARGIN,
            groundRayOriginY - targetBodyBottomY + Config.BOMB_FREEFALL_GROUND_RAY_MARGIN
        )
        local groundResult = raycastGroundAt(
            character,
            bombTool,
            targetXZ,
            groundRayOriginY,
            groundRayLength
        )
        local targetY = targetXZ.Y
        local targetIsGroundSurface = false
        if groundResult and groundResult.Position.Y < predictedFootBottomY then
            local groundTargetY = groundResult.Position.Y + Config.BOMB_GROUND_SINK
            if groundResult.Position.Y > targetBodyBottomY then
                targetY = groundTargetY
                targetIsGroundSurface = true
            end
        end

        return Vector3.new(targetXZ.X, targetY, targetXZ.Z), targetIsGroundSurface
    end

    local isStationary = horizontalSpeed <= 0.75 and humanoid.MoveDirection.Magnitude <= 0.05
    local ping = getBombPing(player)
    local highPingForward = 0

    if ping > Config.BOMB_HIGH_PING_THRESHOLD then
        highPingForward = math.clamp(
            Config.BOMB_HIGH_PING_FORWARD_MIN
            + (ping - Config.BOMB_HIGH_PING_THRESHOLD) * Config.BOMB_HIGH_PING_FORWARD_SCALE,
            Config.BOMB_HIGH_PING_FORWARD_MIN,
            Config.BOMB_HIGH_PING_FORWARD_MAX
        )
    end

    local forwardDistance
    if isStationary then
        forwardDistance = 0
    else
        forwardDistance = math.clamp(
            0.85 + horizontalSpeed * 0.002 + highPingForward,
            0.85,
            1.05 + Config.BOMB_HIGH_PING_FORWARD_MAX
        )
    end

    return (rootPart.CFrame * CFrame.new(0, -3, -forwardDistance)).Position
end

local function fireBombRemote(bombTool, character, rootPart, humanoid, player, forceBelowFeet)
    if not bombTool or not character or not rootPart or not humanoid then
        return false, nil
    end

    local remote = bombTool:FindFirstChild("Remote")
    if not remote then
        return false, nil
    end

    local targetPosition = getBombThrowTarget(character, rootPart, humanoid, bombTool, player, forceBelowFeet)
    if not targetPosition then
        return false, nil
    end

    local lookVector = rootPart.CFrame.LookVector
    local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)
    if flatLook.Magnitude <= 0.001 then
        flatLook = Vector3.new(0, 0, -1)
    else
        flatLook = flatLook.Unit
    end

    local throwCFrame = CFrame.lookAt(targetPosition, targetPosition + flatLook)
    local throwForce = 50

    local ok = pcall(function()
        remote:FireServer(throwCFrame, throwForce)
    end)

    return ok, targetPosition
end

local bombMouseOverride = sharedEnv.__StandaloneBombJumpMouseOverride

if type(bombMouseOverride) ~= "table" then
    bombMouseOverride = {
        active = false,
        mouse = nil,
        targetCFrame = nil,
        targetPart = nil,
        screenPosition = nil,
        camera = nil,
        installed = false,
    }
    sharedEnv.__StandaloneBombJumpMouseOverride = bombMouseOverride

    if type(hookmetamethod) == "function" then
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", (type(newcclosure) == "function" and newcclosure or function(fn) return fn end)(function(self, key)
            local state = sharedEnv.__StandaloneBombJumpMouseOverride

            if state and state.active and self == state.mouse then
                if key == "Hit" or key == "hit" then
                    return state.targetCFrame
                end

                if key == "Target" or key == "target" then
                    return state.targetPart
                end

                if key == "X" or key == "x" then
                    return state.screenPosition and state.screenPosition.X or oldIndex(self, key)
                end

                if key == "Y" or key == "y" then
                    return state.screenPosition and state.screenPosition.Y or oldIndex(self, key)
                end

                if key == "Origin" then
                    return state.camera and state.camera.CFrame or oldIndex(self, key)
                end

                if key == "UnitRay" then
                    local camera = state.camera
                    local targetCFrame = state.targetCFrame
                    if camera and targetCFrame then
                        local origin = camera.CFrame.Position
                        local direction = targetCFrame.Position - origin
                        if direction.Magnitude > 0.001 then
                            return Ray.new(origin, direction.Unit)
                        end
                    end
                end
            end

            return oldIndex(self, key)
        end))
        bombMouseOverride.installed = true
    end
end

local function setBombMouseOverride(camera, screenPosition, targetPosition, targetPart)
    bombMouseOverride.mouse = LocalPlayer:GetMouse()
    bombMouseOverride.camera = camera
    bombMouseOverride.screenPosition = screenPosition
    bombMouseOverride.targetCFrame = CFrame.new(targetPosition)
    bombMouseOverride.targetPart = targetPart
    bombMouseOverride.active = bombMouseOverride.installed
end

local function clearBombMouseOverride()
    bombMouseOverride.active = false
    bombMouseOverride.mouse = nil
    bombMouseOverride.targetCFrame = nil
    bombMouseOverride.targetPart = nil
    bombMouseOverride.screenPosition = nil
    bombMouseOverride.camera = nil
end

local function performBombActivationInput(screenPosition, inputCamera, waitForActivation)
    local touchPreferred = UIS.TouchEnabled
    pcall(function()
        touchPreferred = touchPreferred and (
            not UIS.MouseEnabled
            or UIS.PreferredInput == Enum.PreferredInput.Touch
        )
    end)

    if touchPreferred then
        local touchManager
        local touchManagerOk = pcall(function()
            touchManager = game:GetService("VirtualInputManager")
            return touchManager
        end)

        if touchManagerOk and touchManager and type(touchManager.SendTouchEvent) == "function" then
            local touchId = math.floor(os.clock() * 1000000) % 2147483647
            local sent = pcall(function()
                touchManager:SendTouchEvent(
                    touchId,
                    Enum.UserInputState.Begin.Value,
                    screenPosition.X,
                    screenPosition.Y
                )

                RunService.Heartbeat:Wait()

                touchManager:SendTouchEvent(
                    touchId,
                    Enum.UserInputState.End.Value,
                    screenPosition.X,
                    screenPosition.Y
                )

                if type(touchManager.WaitForInputEventsProcessed) == "function" then
                    touchManager:WaitForInputEventsProcessed()
                end
            end)

            if sent then
                if waitForActivation then
                    local deadline = os.clock() + 0.08
                    while not waitForActivation() and os.clock() < deadline do
                        RunService.Heartbeat:Wait()
                    end
                    if waitForActivation() then
                        return true
                    end
                else
                    return true
                end
            end
        end
    end

    local virtualInputManager
    local managerOk = pcall(function()
        virtualInputManager = game:GetService("VirtualInputManager")
        return virtualInputManager
    end)

    if managerOk and virtualInputManager and type(virtualInputManager.SendMouseButtonEvent) == "function" then
        local sent = pcall(function()
            if type(virtualInputManager.SendMouseMoveEvent) == "function" then
                virtualInputManager:SendMouseMoveEvent(
                    screenPosition.X,
                    screenPosition.Y,
                    game
                )
            end

            virtualInputManager:SendMouseButtonEvent(
                screenPosition.X,
                screenPosition.Y,
                0,
                true,
                game,
                0
            )

            virtualInputManager:SendMouseButtonEvent(
                screenPosition.X,
                screenPosition.Y,
                0,
                false,
                game,
                0
            )
        end)

        if sent then
            if waitForActivation then
                local deadline = os.clock() + 0.08
                while not waitForActivation() and os.clock() < deadline do
                    RunService.Heartbeat:Wait()
                end
                if waitForActivation() then
                    return true
                end
            else
                return true
            end
        end
    end

    local sent = pcall(function()
        VirtualUser:MoveMouse(screenPosition, inputCamera)
        VirtualUser:Button1Down(screenPosition, inputCamera)
        task.wait(0.018)
        VirtualUser:Button1Up(screenPosition, inputCamera)
    end)

    if waitForActivation and sent then
        local deadline = os.clock() + 0.08
        while not waitForActivation() and os.clock() < deadline do
            RunService.Heartbeat:Wait()
        end
    end

    return sent
end

local function fireBombActivatedConnections(tool)
    local getConnections = rawget(_G, "getconnections")
    if type(getConnections) ~= "function" then
        getConnections = getgenv and getgenv().getconnections or nil
    end
    if type(getConnections) ~= "function" then
        return false
    end

    local ok, connections = pcall(getConnections, tool.Activated)
    if not ok or type(connections) ~= "table" then
        return false
    end

    local fired = false
    for _, connection in ipairs(connections) do
        local fn = connection.Function or connection.Func
        if type(fn) == "function" then
            if connection.Enabled == nil or connection.Enabled then
                pcall(fn)
                fired = true
            end
        end
    end

    return fired
end

local function getVirtualBombInput(camera, worldPosition)
    if not camera or not worldPosition then
        return nil, nil
    end

    local screenPoint = camera:WorldToScreenPoint(worldPosition)
    local viewport = camera.ViewportSize
    if viewport.X <= 0 or viewport.Y <= 0 or screenPoint.Z <= 0 then
        return nil, nil
    end

    local margin = 2
    local x = math.clamp(screenPoint.X, margin, viewport.X - margin)
    local y = math.clamp(screenPoint.Y, margin, viewport.Y - margin)
    return Vector2.new(x, y), camera.CFrame
end

local function isBombCandidate(instance, character, bombTool)
    if not instance or not instance:IsA("BasePart") or not instance.Parent then
        return false
    end
    if character and instance:IsDescendantOf(character) then
        return false
    end
    if bombTool and instance:IsDescendantOf(bombTool) then
        return false
    end

    local cursor = instance
    while cursor and cursor ~= Workspace do
        local lowerName = cursor.Name:lower()
        if lowerName:find("bomb")
            or lowerName:find("bomba")
            or lowerName:find("explosive")
            or lowerName:find("explosivo")
            or lowerName:find("tnt")
            or lowerName:find("dynamite") then
            return true
        end
        cursor = cursor.Parent
    end

    return false
end

local function findNearbyBombPart(character, bombTool, targetPosition)
    if not targetPosition then
        return nil
    end

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = {character, bombTool}
    overlapParams.MaxParts = 64

    local parts = Workspace:GetPartBoundsInRadius(targetPosition, 7, overlapParams)
    local bestPart = nil
    local bestDistance = math.huge

    for _, instance in ipairs(parts) do
        if isBombCandidate(instance, character, bombTool) then
            local distance = (instance.Position - targetPosition).Magnitude
            if distance < bestDistance then
                bestDistance = distance
                bestPart = instance
            end
        end
    end

    return bestPart
end

local function getBombContainer(bombPart, character)
    if not bombPart then
        return nil
    end

    local matchingModel = nil
    local cursor = bombPart.Parent

    while cursor and cursor ~= Workspace do
        if cursor:IsA("Model") and cursor ~= character then
            local lowerName = string.lower(cursor.Name)
            if lowerName:find("bomb")
                or lowerName:find("bomba")
                or lowerName:find("explosive")
                or lowerName:find("explosivo")
                or lowerName:find("tnt")
                or lowerName:find("dynamite") then
                matchingModel = cursor
                break
            end
        end
        cursor = cursor.Parent
    end

    return matchingModel or bombPart
end

local function getBombHeight(bombPart, container)
    if container and container:IsA("Model") then
        local ok, size = pcall(function()
            return container:GetExtentsSize()
        end)
        if ok and size.Y > 0 then
            return size.Y
        end
    end

    if bombPart and bombPart:IsA("BasePart") then
        return bombPart.Size.Y
    end

    return 1
end

local function placeBombAtTarget(bombPart, character, targetPosition, placementMode)
    if not bombPart or not targetPosition or not bombPart.Parent then
        return false
    end

    local container = getBombContainer(bombPart, character)
    local height = getBombHeight(bombPart, container)
    local currentMinimumY, currentMaximumY = BombStyleRuntime.getBombWorldVerticalBounds(
        bombPart,
        character,
        nil,
        container
    )

    local positioned = pcall(function()
        local boundsPosition
        if container and container:IsA("Model") then
            boundsPosition = container:GetBoundingBox().Position
        else
            boundsPosition = bombPart.Position
        end

        local translation
        if placementMode == "top" and currentMaximumY then
            translation = Vector3.new(
                targetPosition.X - boundsPosition.X,
                targetPosition.Y - currentMaximumY,
                targetPosition.Z - boundsPosition.Z
            )
        elseif placementMode == "surface" and currentMinimumY then
            local surfaceY = targetPosition.Y - Config.BOMB_GROUND_SINK
            translation = Vector3.new(
                targetPosition.X - boundsPosition.X,
                surfaceY - currentMinimumY,
                targetPosition.Z - boundsPosition.Z
            )
        else
            local finalPosition = Vector3.new(
                targetPosition.X,
                targetPosition.Y + height * 0.5 - Config.BOMB_GROUND_SINK,
                targetPosition.Z
            )
            translation = finalPosition - boundsPosition
        end

        if container and container:IsA("Model") then
            container:PivotTo(CFrame.new(translation) * container:GetPivot())
        else
            bombPart.CFrame = bombPart.CFrame + translation
        end
    end)
    if not positioned then
        return false
    end

    local parts = {}
    if container and container:IsA("Model") then
        for _, instance in ipairs(container:GetDescendants()) do
            if instance:IsA("BasePart") then
                parts[#parts + 1] = instance
            end
        end
    else
        parts[1] = bombPart
    end

    for _, part in ipairs(parts) do
        pcall(function()
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    return true
end

local function findFireflyRightShoulder(character)
    if not character then
        return nil
    end

    local torso = character:FindFirstChild("Torso")
    local upperTorso = character:FindFirstChild("UpperTorso")

    if torso then
        local shoulder = torso:FindFirstChild("Right Shoulder")
        if shoulder and (shoulder:IsA("Motor6D") or shoulder.ClassName == "AnimationConstraint") then
            return shoulder
        end
    end

    if upperTorso then
        local shoulder = upperTorso:FindFirstChild("RightShoulder")
        if shoulder and (shoulder:IsA("Motor6D") or shoulder.ClassName == "AnimationConstraint") then
            return shoulder
        end
    end

    for _, descendant in ipairs(character:GetDescendants()) do
        if (descendant:IsA("Motor6D") or descendant.ClassName == "AnimationConstraint")
            and (descendant.Name == "Right Shoulder" or descendant.Name == "RightShoulder") then
            return descendant
        end
    end

    return nil
end

local function getFireflyArmPart(shoulder, character)
    if character then
        local hand = character:FindFirstChild("RightHand")
        if hand and hand:IsA("BasePart") then
            return hand
        end

        local lowerArm = character:FindFirstChild("RightLowerArm")
        if lowerArm and lowerArm:IsA("BasePart") then
            return lowerArm
        end

        local upperArm = character:FindFirstChild("RightUpperArm")
        if upperArm and upperArm:IsA("BasePart") then
            return upperArm
        end

        local r6Arm = character:FindFirstChild("Right Arm")
        if r6Arm and r6Arm:IsA("BasePart") then
            return r6Arm
        end
    end

    if shoulder and shoulder.Part1 and shoulder.Part1:IsA("BasePart") then
        return shoulder.Part1
    end

    return nil
end

local function getFireflyArmLateralPosition(shoulder, armPart)
    if not shoulder or not shoulder.Part0 or not armPart or not armPart:IsA("BasePart") then
        return nil
    end

    local torso = shoulder.Part0
    if not torso:IsA("BasePart") then
        return nil
    end

    return (armPart.Position - torso.Position):Dot(torso.CFrame.RightVector)
end

local function holdFireflyJump(humanoid, character, duration, sharedDeadline)
    if fireflyDoubleJumpJumpConnection then
        fireflyDoubleJumpJumpConnection:Disconnect()
        fireflyDoubleJumpJumpConnection = nil
    end

    local deadline = sharedDeadline or (os.clock() + duration)
    fireflyDoubleJumpJumpConnection = RunService.RenderStepped:Connect(function()
        if not character.Parent or not humanoid.Parent or humanoid.Health <= 0 or os.clock() >= deadline then
            pcall(function()
                humanoid.Jump = false
            end)
            if fireflyDoubleJumpJumpConnection then
                fireflyDoubleJumpJumpConnection:Disconnect()
                fireflyDoubleJumpJumpConnection = nil
            end
            return
        end

        pcall(function()
            humanoid.Jump = true
        end)
    end)
end

local function stopFireflyForwardMovement()
    local wasActive = fireflyDoubleJumpForwardConnection ~= nil
    fireflyDoubleJumpForwardConnection = nil
    RunService:UnbindFromRenderStep(Config.FIREFLY_FORWARD_MOVEMENT_BIND_NAME)
    if wasActive then
        fireflyDiag.log("AUTO_MOVE_STOP", "forward RenderStep unbound")
    end
end

local function startFireflyForwardMovement(character, humanoid, rootPart, movementStartAt, onWindowStarted, onWindowEnded, onFailure)
    stopFireflyForwardMovement()

    local startAt = movementStartAt or os.clock()
    local deadline = nil
    local nextAutoTraceAt = 0
    local climbingSince = nil
    local velocitySamplePart = nil
    local velocitySamplePosition = nil
    local velocitySampleAt = 0
    local measuredLidVelocity = Vector3.zero
    local measuredLidVelocityValid = false
    local measuredLowSpeedSamples = 0
    local lidRayParams = RaycastParams.new()
    lidRayParams.FilterType = Enum.RaycastFilterType.Exclude
    lidRayParams.IgnoreWater = true
    fireflyDoubleJumpForwardConnection = true
    fireflyDiag.log("AUTO_MOVE_START", "forward RenderStep bound; startAt=" .. string.format("%.3f", startAt))

    local function stopWithFailure(message)
        fireflyDiag.log("AUTO_MOVE_FAILURE", tostring(message))
        pcall(function()
            humanoid:Move(Vector3.zero, false)
        end)
        stopFireflyForwardMovement()
        if onFailure then
            onFailure(message)
        end
    end

    RunService:BindToRenderStep(
        Config.FIREFLY_FORWARD_MOVEMENT_BIND_NAME,
        Enum.RenderPriority.Last.Value + 1,
        function()
            if not fireflyDoubleJumpForwardConnection then
                return
            end
            local now = os.clock()
            if not character.Parent or not humanoid.Parent or not rootPart.Parent or humanoid.Health <= 0 then
                stopWithFailure("Firefly: character unavailable")
                return
            end
            local currentState = humanoid:GetState()
            if currentState == Enum.HumanoidStateType.Climbing then
                local traceLid = fireflyDoubleJumpLid
                local traceRootPosition = rootPart.Position
                local traceRootVelocity = rootPart.AssemblyLinearVelocity
                local traceLidPosition = traceLid and traceLid.Parent == Workspace and traceLid.Position or Vector3.zero
                local horizontalDistance = math.huge
                local feetGap = math.huge
                local nearLid = false

                if traceLid and traceLid:IsA("BasePart") and traceLid.Parent == Workspace then
                    local dx = traceRootPosition.X - traceLidPosition.X
                    local dz = traceRootPosition.Z - traceLidPosition.Z
                    horizontalDistance = math.sqrt(dx * dx + dz * dz)

                    local expectedRootHeight = humanoid.HipHeight + rootPart.Size.Y * 0.5
                    if not character:FindFirstChild("LowerTorso") then
                        local leftLeg = character:FindFirstChild("Left Leg")
                        expectedRootHeight = (leftLeg and leftLeg:IsA("BasePart") and leftLeg.Size.Y or humanoid.HipHeight)
                            + rootPart.Size.Y * 0.5
                    end
                    feetGap = traceRootPosition.Y - expectedRootHeight
                        - (traceLidPosition.Y + traceLid.Size.Y * 0.5)

                    local horizontalGraceRadius = math.max(traceLid.Size.X, traceLid.Size.Z) * 0.5
                        + math.max(rootPart.Size.X, rootPart.Size.Z) * 0.5 + 0.65
                    nearLid = horizontalDistance <= horizontalGraceRadius
                        and feetGap >= -1.25 and feetGap <= 1.75
                end

                if not nearLid then
                    stopWithFailure("Firefly: climbing away from lid; attempt canceled safely")
                    return
                end

                if not climbingSince then
                    climbingSince = now
                    fireflyDiag.log("CLIMBING_GRACE_BEGIN", string.format(
                        "brief climbing contact near lid; horizontalDistance=%.2f; feetGap=%.2f; grace=0.18s",
                        horizontalDistance, feetGap
                    ))
                elseif now - climbingSince >= 0.18 then
                    stopWithFailure("Firefly: climbing persisted near lid; attempt canceled safely")
                    return
                end

                if now >= nextAutoTraceAt then
                    nextAutoTraceAt = now + 0.05
                    fireflyDiag.log("AUTO_TRACE_CLIMB", string.format(
                        "state=%s; root=(%.2f,%.2f,%.2f); lid=(%.2f,%.2f,%.2f); rootV=(%.2f,%.2f,%.2f); horizontalDistance=%.2f; feetGap=%.2f; graceElapsed=%.3f; floor=%s",
                        tostring(currentState),
                        traceRootPosition.X, traceRootPosition.Y, traceRootPosition.Z,
                        traceLidPosition.X, traceLidPosition.Y, traceLidPosition.Z,
                        traceRootVelocity.X, traceRootVelocity.Y, traceRootVelocity.Z,
                        horizontalDistance, feetGap, now - climbingSince,
                        tostring(humanoid.FloorMaterial)
                    ))
                end
            else
                climbingSince = nil
            end

            if now < startAt then
                humanoid:Move(Vector3.zero, false)
                if now >= nextAutoTraceAt then
                    nextAutoTraceAt = now + 0.10
                    fireflyDiag.log("AUTO_TRACE_WAIT", string.format(
                        "before startAt; state=%s; startAt=%.3f; now=%.3f; rootY=%.2f; floor=%s",
                        tostring(currentState), startAt, now, rootPart.Position.Y, tostring(humanoid.FloorMaterial)
                    ))
                end
                return
            end

            local lid = fireflyDoubleJumpLid
            if not lid or not lid:IsA("BasePart") or lid.Parent ~= Workspace then
                humanoid:Move(Vector3.zero, false)
                if now >= startAt + 1.25 then
                    stopWithFailure("Firefly: lid not detected")
                end
                return
            end

            lidRayParams.FilterDescendantsInstances = {character, lid}
            local floorHit = Workspace:Raycast(lid.Position, Vector3.new(0, -64, 0), lidRayParams)
            local bottomGap = floorHit and (lid.Position.Y - lid.Size.Y * 0.5 - floorHit.Position.Y) or math.huge
            local reportedLidVelocity = lid.AssemblyLinearVelocity

            -- AssemblyLinearVelocity can be stale or misleading for replicated/anchored lid parts.
            -- Estimate horizontal motion from the part's actual observed displacement over a short window.
            if velocitySamplePart ~= lid or not velocitySamplePosition then
                velocitySamplePart = lid
                velocitySamplePosition = lid.Position
                velocitySampleAt = now
                measuredLidVelocity = Vector3.zero
                measuredLidVelocityValid = false
                measuredLowSpeedSamples = 0
            else
                local sampleDt = now - velocitySampleAt
                if sampleDt >= 0.06 and sampleDt <= 0.20 then
                    local observedVelocity = (lid.Position - velocitySamplePosition) / sampleDt
                    if observedVelocity.Magnitude <= 100 then
                        measuredLidVelocity = observedVelocity
                        measuredLidVelocityValid = true
                        local observedHorizontalSpeed = Vector3.new(
                            observedVelocity.X, 0, observedVelocity.Z
                        ).Magnitude
                        if observedHorizontalSpeed <= 1.0 then
                            measuredLowSpeedSamples = measuredLowSpeedSamples + 1
                        else
                            measuredLowSpeedSamples = 0
                        end
                    else
                        measuredLidVelocityValid = false
                        measuredLowSpeedSamples = 0
                    end
                    velocitySamplePosition = lid.Position
                    velocitySampleAt = now
                elseif sampleDt > 0.20 then
                    -- The sample window went stale; re-baseline instead of extrapolating old motion.
                    velocitySamplePosition = lid.Position
                    velocitySampleAt = now
                    measuredLidVelocity = Vector3.zero
                    measuredLidVelocityValid = false
                    measuredLowSpeedSamples = 0
                end
            end

            -- Prefer observed displacement when it shows meaningful movement. However, the
            -- walking trace showed the lid accelerating between position samples: the measured
            -- displacement briefly returned zero while an unanchored lid's reported velocity
            -- already indicated motion. In that narrow case, use reported horizontal velocity
            -- provisionally; anchored lids continue to rely only on observed displacement.
            local measuredHorizontalVelocity = Vector3.new(
                measuredLidVelocity.X, 0, measuredLidVelocity.Z
            )
            local reportedHorizontalVelocity = Vector3.new(
                reportedLidVelocity.X, 0, reportedLidVelocity.Z
            )
            local reportedHorizontalSpeed = reportedHorizontalVelocity.Magnitude
            -- Later traces measured 19-20.5 studs/s, confirming that prior reports above
            -- 18 were real lid motion rather than spikes. Accept reported velocity up to 24
            -- studs/s provisionally; observed displacement takes over when valid, and larger
            -- reports are still rejected as implausible.
            local measuredHorizontalSpeed = measuredHorizontalVelocity.Magnitude
            local reportedVelocityIsPlausible = reportedHorizontalSpeed >= 1.25
                and reportedHorizontalSpeed <= 24.0
            local measuredLooksTemporarilyStale = measuredLidVelocityValid
                and measuredHorizontalSpeed <= 1.0
                and measuredLowSpeedSamples <= 1
            local useReportedHorizontalVelocity = not lid.Anchored
                and reportedVelocityIsPlausible
                and (not measuredLidVelocityValid or measuredLooksTemporarilyStale)
            local horizontalLidVelocity = Vector3.zero
            local horizontalVelocitySource = "zero"
            if useReportedHorizontalVelocity then
                horizontalLidVelocity = reportedHorizontalVelocity
                horizontalVelocitySource = "reported"
            elseif measuredLidVelocityValid then
                horizontalLidVelocity = measuredHorizontalVelocity
                horizontalVelocitySource = "measured"
            end
            -- AssemblyLinearVelocity.Y can spike independently of observed displacement.
            -- Select vertical speed AFTER updating the displacement sample this frame.
            -- Traces included >100 stud/s reports while the lid moved only slightly.
            local selectedLidVerticalVelocity = reportedLidVelocity.Y
            local lidVerticalVelocitySource = "reported"
            if measuredLidVelocityValid and math.abs(measuredLidVelocity.Y) <= 60.0 then
                selectedLidVerticalVelocity = measuredLidVelocity.Y
                lidVerticalVelocitySource = "measured"
            elseif math.abs(reportedLidVelocity.Y) > 60.0 then
                selectedLidVerticalVelocity = 0
                lidVerticalVelocitySource = "zero-clamped"
            end

            local lidVelocity = Vector3.new(
                horizontalLidVelocity.X,
                selectedLidVerticalVelocity,
                horizontalLidVelocity.Z
            )
            local lidIsSettled = floorHit ~= nil
                and bottomGap >= -0.08
                and bottomGap <= 0.18
                and lidVelocity.Magnitude <= 1.5

            if not deadline then
                deadline = now + Config.FIREFLY_FORWARD_HOLD_TIME
                if onWindowStarted then
                    onWindowStarted(deadline)
                end
            end

            if now >= deadline then
                pcall(function()
                    humanoid:Move(Vector3.zero, false)
                end)
                stopFireflyForwardMovement()
                if onWindowEnded then
                    onWindowEnded()
                end
                return
            end

            local lowerTorso = character:FindFirstChild("LowerTorso")
            local rootHeightAboveGround = humanoid.HipHeight + rootPart.Size.Y * 0.5
            if not lowerTorso then
                local leftLeg = character:FindFirstChild("Left Leg")
                rootHeightAboveGround = (leftLeg and leftLeg:IsA("BasePart") and leftLeg.Size.Y or humanoid.HipHeight)
                    + rootPart.Size.Y * 0.5
            end

            local lidTopY = lid.Position.Y + lid.Size.Y * 0.5
            local feetGap = rootPart.Position.Y - rootHeightAboveGround - lidTopY
            local rootVelocity = rootPart.AssemblyLinearVelocity
            local verticalVelocity = rootVelocity.Y
            local relativeVerticalVelocity = verticalVelocity - lidVelocity.Y
            local gravity = math.max(Workspace.Gravity, 1)
            local landingDiscriminant = math.max(
                0,
                relativeVerticalVelocity * relativeVerticalVelocity
                    + 2 * gravity * math.max(feetGap, 0)
            )
            local predictedLandingTime = (
                relativeVerticalVelocity + math.sqrt(landingDiscriminant)
            ) / gravity
            predictedLandingTime = math.clamp(predictedLandingTime, 0, 0.35)

            -- Bound the lead to the revised plausible horizontal speed ceiling
            -- (24 studs/s) times the maximum landing horizon (0.35 s): 24 * 0.35 = 8.4.
            -- This allows the initial prediction to account for the fastest observed target
            -- motion without extrapolating beyond the accepted speed range.
            local leadOffset = horizontalLidVelocity * predictedLandingTime
            if leadOffset.Magnitude > 8.4 then
                leadOffset = leadOffset.Unit * 8.4
            end

            local predictedLidPosition = lid.Position + leadOffset
            local predictedLidCFrame = lid.CFrame + leadOffset
            local horizontalRootVelocity = Vector3.new(rootVelocity.X, 0, rootVelocity.Z)
            local relativeHorizontalVelocity = horizontalRootVelocity - horizontalLidVelocity
            local rootLeadTime = math.min(predictedLandingTime, 0.08)
            local predictedRootControlPosition = rootPart.Position
                + horizontalRootVelocity * rootLeadTime
            local predictedRootLandingPosition = rootPart.Position
                + horizontalRootVelocity * predictedLandingTime
            local predictedRootAtLanding = Vector3.new(
                predictedRootLandingPosition.X,
                predictedLidPosition.Y + lid.Size.Y * 0.5 + rootHeightAboveGround,
                predictedRootLandingPosition.Z
            )
            local horizontalOffset = Vector3.new(
                predictedLidPosition.X - predictedRootControlPosition.X,
                0,
                predictedLidPosition.Z - predictedRootControlPosition.Z
            )
            local predictedLocalPosition = predictedLidCFrame:PointToObjectSpace(predictedRootAtLanding)
            local safeHalfX = math.max(
                0.05,
                lid.Size.X * 0.5 - math.min(rootPart.Size.X * 0.25, lid.Size.X * 0.25)
            )
            local safeHalfZ = math.max(
                0.05,
                lid.Size.Z * 0.5 - math.min(rootPart.Size.Z * 0.25, lid.Size.Z * 0.25)
            )
            local predictedWithinLandingFootprint = math.abs(predictedLocalPosition.X) <= safeHalfX
                and math.abs(predictedLocalPosition.Z) <= safeHalfZ
            local descendingIntoLid = relativeVerticalVelocity <= -1.0
                and feetGap >= -0.25
                and feetGap <= 2.2
                and predictedWithinLandingFootprint
                and (lidIsSettled or horizontalLidVelocity.Magnitude <= 3)

            local direction = Vector3.zero
            local captureRadius = math.clamp(math.min(lid.Size.X, lid.Size.Z) * 0.12, 0.16, 0.32)
            local remainingLandingTime = math.max(predictedLandingTime - rootLeadTime, 0.08)
            local desiredRelativeVelocity = horizontalOffset / remainingLandingTime
            local maximumCorrectionSpeed = math.max(humanoid.WalkSpeed, 1)
            if desiredRelativeVelocity.Magnitude > maximumCorrectionSpeed then
                desiredRelativeVelocity = desiredRelativeVelocity.Unit * maximumCorrectionSpeed
            end
            -- Humanoid:Move consumes a desired movement vector. Convert the relative
            -- interception velocity into world-space movement before creating that vector;
            -- using (desired-relative velocity minus current velocity) directly as Move input
            -- can under-command the final correction as the landing window shrinks.
            local desiredWorldVelocity = horizontalLidVelocity + desiredRelativeVelocity
            if desiredWorldVelocity.Magnitude > maximumCorrectionSpeed then
                desiredWorldVelocity = desiredWorldVelocity.Unit * maximumCorrectionSpeed
            end
            local canSettleOnLid = descendingIntoLid
                and predictedWithinLandingFootprint
                and relativeHorizontalVelocity.Magnitude <= 1.15

            if not canSettleOnLid then
                if desiredWorldVelocity.Magnitude > 0.08 then
                    direction = desiredWorldVelocity / maximumCorrectionSpeed
                elseif horizontalOffset.Magnitude > captureRadius and not predictedWithinLandingFootprint then
                    direction = horizontalOffset / math.max(maximumCorrectionSpeed * remainingLandingTime, 0.1)
                    if direction.Magnitude > 1 then
                        direction = direction.Unit
                    end
                end
            end

            if feetGap < Config.FIREFLY_LID_APPROACH_CLEARANCE then
                if predictedWithinLandingFootprint then
                    -- Brake only after the projected landing point is inside the safe footprint.
                    local brakingDirection = -relativeHorizontalVelocity
                    if brakingDirection.Magnitude > maximumCorrectionSpeed then
                        brakingDirection = brakingDirection.Unit * maximumCorrectionSpeed
                    end
                    direction = brakingDirection / maximumCorrectionSpeed
                else
                    -- Still outside the safe footprint at low altitude: keep the full
                    -- target-interception command rather than a reduced velocity-error delta.
                    direction = desiredWorldVelocity / maximumCorrectionSpeed
                    if direction.Magnitude > 1 then
                        direction = direction.Unit
                    end
                end
            end

            humanoid:Move(direction, false)
            if now >= nextAutoTraceAt then
                nextAutoTraceAt = now + 0.10
                fireflyDiag.log("AUTO_TRACE", string.format(
                    "state=%s; root=(%.2f,%.2f,%.2f); lid=(%.2f,%.2f,%.2f); feetGap=%.2f; landingT=%.3f; remainingT=%.3f; offset=(%.2f,%.2f); desiredWorldV=(%.2f,%.2f); dir=(%.3f,%.3f); rootV=(%.2f,%.2f); lidV=(%.2f,%.2f); lidReportedV=(%.2f,%.2f); lidReportedSpeed=%.2f; reportPlausible=%s; lidVy=%.2f; lidReportedVy=%.2f; lidVelocityYSource=%s; measuredSpeed=%.2f; lowSamples=%d; lidAnchored=%s; lidVelocitySource=%s; lidVelocityMeasured=%s; local=(%.2f,%.2f); footprint=%s; descending=%s; settle=%s; floor=%s",
                    tostring(currentState),
                    rootPart.Position.X, rootPart.Position.Y, rootPart.Position.Z,
                    lid.Position.X, lid.Position.Y, lid.Position.Z,
                    feetGap, predictedLandingTime, remainingLandingTime,
                    horizontalOffset.X, horizontalOffset.Z,
                    desiredWorldVelocity.X, desiredWorldVelocity.Z,
                    direction.X, direction.Z,
                    rootVelocity.X, rootVelocity.Z,
                    lidVelocity.X, lidVelocity.Z,
                    reportedLidVelocity.X, reportedLidVelocity.Z,
                    reportedHorizontalSpeed, tostring(reportedVelocityIsPlausible),
                    selectedLidVerticalVelocity, reportedLidVelocity.Y, lidVerticalVelocitySource,
                    measuredHorizontalSpeed, measuredLowSpeedSamples,
                    tostring(lid.Anchored), horizontalVelocitySource,
                    tostring(measuredLidVelocityValid),
                    predictedLocalPosition.X, predictedLocalPosition.Z,
                    tostring(predictedWithinLandingFootprint), tostring(descendingIntoLid),
                    tostring(canSettleOnLid), tostring(humanoid.FloorMaterial)
                ))
            end
        end
    )
end

local function bindFireflyLid(lid)
    if not lid or not lid:IsA("BasePart") or lid.Parent ~= Workspace then
        return false
    end

    if fireflyDoubleJumpLid == lid then
        return true
    end

    fireflyDoubleJumpLid = lid
    return true
end

local cancelFireflyDoubleJump = function(preserveJump)
    pcall(function()
        local contextActionService = game:GetService("ContextActionService")
        contextActionService:UnbindAction("__FireflyDoubleJumpMovementLock")
        contextActionService:UnbindAction(Config.FIREFLY_JUMP_INPUT_LOCK_NAME)
    end)
    pcall(function()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid:GetAttribute("__FireflyMovementLockActive") then
            local originalWalkSpeed = humanoid:GetAttribute("__FireflyMovementLockWalkSpeed")
            if typeof(originalWalkSpeed) == "number" then
                humanoid.WalkSpeed = originalWalkSpeed
            end
            humanoid:SetAttribute("__FireflyMovementLockWalkSpeed", nil)
            humanoid:SetAttribute("__FireflyMovementLockActive", nil)
        end
    end)
    if fireflyDoubleJumpRenderConnection then
        fireflyDoubleJumpRenderConnection:Disconnect()
        fireflyDoubleJumpRenderConnection = nil
    end
    if fireflyDoubleJumpStateConnection then
        fireflyDoubleJumpStateConnection:Disconnect()
        fireflyDoubleJumpStateConnection = nil
    end
    if fireflyDoubleJumpJumpingConnection then
        fireflyDoubleJumpJumpingConnection:Disconnect()
        fireflyDoubleJumpJumpingConnection = nil
    end
    if fireflyDoubleJumpPhysicsConnection then
        fireflyDoubleJumpPhysicsConnection:Disconnect()
        fireflyDoubleJumpPhysicsConnection = nil
    end
    if fireflyDoubleJumpLidConnection then
        fireflyDoubleJumpLidConnection:Disconnect()
        fireflyDoubleJumpLidConnection = nil
    end
    if fireflySecondJumpClearConnection then
        fireflySecondJumpClearConnection:Disconnect()
        fireflySecondJumpClearConnection = nil
    end
    RunService:UnbindFromRenderStep("__FireflyDoubleJumpIdleMovementLock")
    stopFireflyForwardMovement()
    if not preserveJump and fireflyDoubleJumpJumpConnection then
        fireflyDoubleJumpJumpConnection:Disconnect()
        fireflyDoubleJumpJumpConnection = nil
    end
    fireflyDoubleJumpLid = nil
    fireflyFirstJumpTriggered = false
end

sharedEnv.__StandaloneBombJumpFireflyCleanup = function()
    cancelFireflyDoubleJump()
    if fireflyTimingChildConnection then
        fireflyTimingChildConnection:Disconnect()
        fireflyTimingChildConnection = nil
    end
    if fireflyTimingRenderConnection then
        fireflyTimingRenderConnection:Disconnect()
        fireflyTimingRenderConnection = nil
    end
    fireflyTimingActive = false
    pcall(function()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Jump = false
            humanoid:Move(Vector3.zero, false)
        end
    end)
end

local function getFireflyArmRotationVector(shoulder)
    if not shoulder or not shoulder:IsA("Motor6D") then
        return nil
    end

    local x, y, z = shoulder.Transform:ToOrientation()
    return Vector3.new(x, y, z)
end

local function wrapAngle(angle)
    return math.atan2(math.sin(angle), math.cos(angle))
end

local function getAngularComponent(rotation, baseline, axis)
    if not rotation or not baseline then
        return nil
    end

    if axis == 1 then
        return wrapAngle(rotation.X - baseline.X)
    elseif axis == 2 then
        return wrapAngle(rotation.Y - baseline.Y)
    end
    return wrapAngle(rotation.Z - baseline.Z)
end

local function armFireflyDoubleJump(character, humanoid, rootPart, shoulder, preExistingLids, activationState)
    cancelFireflyDoubleJump()

    shoulder = shoulder or findFireflyRightShoulder(character)
    if not shoulder
        or not (shoulder:IsA("Motor6D") or shoulder.ClassName == "AnimationConstraint") then
        statusLabel.Text = "Firefly: right arm sensor unavailable"
        return
    end

    local armPart = getFireflyArmPart(shoulder, character)
    if not armPart then
        statusLabel.Text = "Firefly: right arm part unavailable"
        return
    end

    local neutralLateral = getFireflyArmLateralPosition(shoulder, armPart)
    if neutralLateral == nil then
        statusLabel.Text = "Firefly: right arm position unavailable"
        return
    end

    local armLength = math.max(armPart.Size.Magnitude, 0.1)
    pcall(function()
        if shoulder.Part0 and shoulder.C0 then
            local jointOrigin = shoulder.Part0.CFrame:PointToWorldSpace(shoulder.C0.Position)
            armLength = math.max((armPart.Position - jointOrigin).Magnitude, 0.1)
        end
    end)

    local initialTravelThreshold = math.max(0.025, armLength * Config.FIREFLY_ARM_INITIAL_TRAVEL_RATIO)
    local returnTravelThreshold = math.max(0.02, armLength * Config.FIREFLY_FIRST_JUMP_RETURN_RATIO)
    local phase = 0
    local firstDirection = 0
    local firstLegTravel = 0
    local returnTravel = 0
    local reversalFrames = 0
    local previousLateral = neutralLateral
    local startedAt = os.clock()
    local previousSampleAt = startedAt
    local sequenceStarted = false
    local firstJumpAirborne = false
    local firstJumpDescentObserved = false
    local firstLandingSeen = false
    local lastClimbingStateAt = nil
    local lastLandingStateAt = nil
    local inputWindowDeadline = nil
    local movementWindowDeadline = nil
    local landedOnLid = false
    local movementWindowStarted = false
    local sequenceStartedAt = nil
    local sequenceResolutionDeadline = nil
    local firstJumpRequestDeadline = nil
    local nextFirstJumpRetryAt = 0
    local secondJumpRequestDeadline = nil
    local nextSecondJumpRetryAt = 0

    statusLabel.Text = "Firefly: tracking right arm"

    local function lockMovement()
        fireflyDiag.log("PLAYER_LOCK_BEGIN", "existing lockMovement() entered; jump sink + idle Move(0), no PlayerModule disable")
        pcall(function()
            if not humanoid:GetAttribute("__FireflyMovementLockActive") then
                humanoid:SetAttribute("__FireflyMovementLockWalkSpeed", humanoid.WalkSpeed)
            end
            humanoid:SetAttribute("__FireflyMovementLockActive", true)
        end)
        pcall(function()
            local contextActionService = game:GetService("ContextActionService")
            contextActionService:BindActionAtPriority(
                "__FireflyDoubleJumpMovementLock",
                function()
                    return Enum.ContextActionResult.Sink
                end,
                false,
                10000,
                Enum.PlayerActions.CharacterJump,
                Enum.KeyCode.Space
            )
        end)
        RunService:BindToRenderStep(
            "__FireflyDoubleJumpIdleMovementLock",
            Enum.RenderPriority.Last.Value + 2,
            function()
                if fireflyDoubleJumpForwardConnection then
                    return
                end
                if character.Parent and humanoid.Parent and humanoid.Health > 0 then
                    humanoid:Move(Vector3.zero, false)
                end
            end
        )
    end

    local function clearFireflyJumpAfterSimulation()
        if fireflySecondJumpClearConnection then
            fireflySecondJumpClearConnection:Disconnect()
            fireflySecondJumpClearConnection = nil
        end

        local connection
        connection = RunService.PostSimulation:Connect(function()
            fireflyDiag.log("JUMP_FLAG_CLEAR", "PostSimulation clearing humanoid.Jump")
            connection:Disconnect()
            if fireflySecondJumpClearConnection == connection then
                fireflySecondJumpClearConnection = nil
            end
            if humanoid and humanoid.Parent then
                pcall(function()
                    humanoid.Jump = false
                end)
            end
        end)
        fireflySecondJumpClearConnection = connection
    end

    local function isCharacterAirborne()
        if not character.Parent or not humanoid.Parent or humanoid.Health <= 0 or not rootPart.Parent then
            return false
        end

        local state = humanoid:GetState()
        local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
        if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.FallingDown then
            return true
        end
        if state == Enum.HumanoidStateType.Jumping and verticalVelocity > 2 then
            return true
        end

        return humanoid.FloorMaterial == Enum.Material.Air and math.abs(verticalVelocity) > 3.5
    end

    local function isCharacterGrounded()
        if not character.Parent or not humanoid.Parent or humanoid.Health <= 0 or not rootPart.Parent then
            return false
        end

        local state = humanoid:GetState()
        local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
        return humanoid.FloorMaterial ~= Enum.Material.Air
            and math.abs(verticalVelocity) <= 1.5
            and state ~= Enum.HumanoidStateType.Jumping
            and state ~= Enum.HumanoidStateType.Freefall
            and state ~= Enum.HumanoidStateType.FallingDown
            and state ~= Enum.HumanoidStateType.Climbing
    end

    local function getGroundPart(allowStateTransition)
        if not allowStateTransition and not isCharacterGrounded() then
            return nil
        end

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {character}
        rayParams.IgnoreWater = true

        local rayLength = math.max(humanoid.HipHeight + rootPart.Size.Y * 0.5 + 1.5, 4)
        local lid = fireflyDoubleJumpLid
        local result = Workspace:Raycast(rootPart.Position, Vector3.new(0, -rayLength, 0), rayParams)
        local centerHitInstance = result and result.Instance or nil

        local function isLidTopHit(hit)
            if not hit or not lid or lid.Parent ~= Workspace or hit.Instance ~= lid then
                return false
            end
            local localHitPosition = lid.CFrame:PointToObjectSpace(hit.Position)
            return hit.Normal:Dot(lid.CFrame.UpVector) >= 0.7
                and math.abs(localHitPosition.Y - lid.Size.Y * 0.5) <= 0.20
                and math.abs(localHitPosition.X) <= lid.Size.X * 0.5
                and math.abs(localHitPosition.Z) <= lid.Size.Z * 0.5
        end

        if isLidTopHit(result) then
            return lid
        end

        if lid and lid.Parent == Workspace then
            -- The character can physically touch the top with its feet while the root-center
            -- ray falls just outside the lid's edge. Probe a small cross around the root, but
            -- still require a real ray hit on the lid's top face to avoid treating side contact
            -- or a nearby floor as a successful landing.
            local right = Vector3.new(rootPart.CFrame.RightVector.X, 0, rootPart.CFrame.RightVector.Z)
            local forward = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
            if right.Magnitude > 0.001 then right = right.Unit else right = Vector3.xAxis end
            if forward.Magnitude > 0.001 then forward = forward.Unit else forward = Vector3.zAxis end
            local sideOffset = math.max(rootPart.Size.X * 0.35, 0.2)
            local forwardOffset = math.max(rootPart.Size.Z * 0.35, 0.2)
            local probeOffsets = {
                right * sideOffset,
                -right * sideOffset,
                forward * forwardOffset,
                -forward * forwardOffset,
            }
            for _, offset in ipairs(probeOffsets) do
                local hit = Workspace:Raycast(rootPart.Position + offset, Vector3.new(0, -rayLength, 0), rayParams)
                if isLidTopHit(hit) then
                    return lid
                end
            end
        end

        if centerHitInstance == lid then
            return nil
        end
        return centerHitInstance
    end

    local secondJumpRequested = false
    local secondJumpDetected = false
    local secondJumpRequestStartedAt = nil
    local secondJumpRequestInitialRelativeVelocity = nil

    local function issueSecondJumpRequest()
        fireflyDiag.log("JUMP_REQUEST_ISSUE", "state=" .. tostring(humanoid:GetState())
            .. "; floor=" .. tostring(humanoid.FloorMaterial)
            .. "; vy=" .. string.format("%.2f", rootPart.AssemblyLinearVelocity.Y)
            .. "; seq=" .. tostring(sequenceStarted)
            .. "; lid=" .. tostring(fireflyDoubleJumpLid and fireflyDoubleJumpLid.Name))
        if fireflyDoubleJumpJumpConnection then
            fireflyDoubleJumpJumpConnection:Disconnect()
            fireflyDoubleJumpJumpConnection = nil
        end

        pcall(function()
            humanoid.Jump = true
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
        fireflyDiag.log("JUMP_REQUEST_SENT", "state now=" .. tostring(humanoid:GetState())
            .. "; vy=" .. string.format("%.2f", rootPart.AssemblyLinearVelocity.Y))
        -- Do not clear Jump in the same simulation step as the request.
        -- The request may otherwise be canceled before the second takeoff begins.
        -- releaseAfterSecondJump clears it after detecting the actual takeoff.
    end

    local function releaseAfterSecondJump(detectionSource)
        fireflyDiag.log("RELEASE_HANDLER_ENTER", "source=" .. tostring(detectionSource)
            .. "; alreadyDetected=" .. tostring(secondJumpDetected)
            .. "; sequenceStarted=" .. tostring(sequenceStarted)
            .. "; state=" .. tostring(humanoid:GetState())
            .. "; vy=" .. string.format("%.2f", rootPart.AssemblyLinearVelocity.Y)
            .. "; floor=" .. tostring(humanoid.FloorMaterial))
        if secondJumpDetected or not sequenceStarted then
            fireflyDiag.log("RELEASE_HANDLER_SKIP", "guard stopped release")
            return
        end

        secondJumpDetected = true
        sequenceStarted = false
        statusLabel.Text = detectionSource and ("Firefly: second jump detected (" .. detectionSource .. ")")
            or "Firefly: second jump detected"

        stopFireflyForwardMovement()
        if fireflyDoubleJumpJumpConnection then
            fireflyDoubleJumpJumpConnection:Disconnect()
            fireflyDoubleJumpJumpConnection = nil
        end
        pcall(function()
            humanoid:Move(Vector3.zero, false)
        end)
        cancelFireflyDoubleJump()
        fireflyDiag.log("PLAYER_UNLOCK_DONE", "release handler completed; seq=false, movement bind/callbacks cancelled")

        clearFireflyJumpAfterSimulation()
    end

    local function requestSecondJumpOnLid()
        if secondJumpRequested or not sequenceStarted or not landedOnLid then
            fireflyDiag.log("JUMP_REQUEST_GUARD", "alreadyRequested=" .. tostring(secondJumpRequested)
                .. "; sequenceStarted=" .. tostring(sequenceStarted)
                .. "; landedOnLid=" .. tostring(landedOnLid))
            return
        end

        secondJumpRequested = true
        fireflyDiag.log("LID_JUMP_REQUEST", "recognized lid landing; requesting second jump now")
        secondJumpRequestStartedAt = os.clock()
        secondJumpRequestDeadline = secondJumpRequestStartedAt + 0.35
        nextSecondJumpRetryAt = secondJumpRequestStartedAt + 0.06
        local lid = fireflyDoubleJumpLid
        local lidVerticalVelocity = lid and lid.Parent == Workspace and lid.AssemblyLinearVelocity.Y or 0
        secondJumpRequestInitialRelativeVelocity = rootPart.AssemblyLinearVelocity.Y - lidVerticalVelocity
        statusLabel.Text = "Firefly: requesting second jump"
        issueSecondJumpRequest()
        -- Keep the existing movement sequence active only until the second jump
        -- actually starts; releaseAfterSecondJump handles that detection.
    end

    local function isSecondJumpBeginning()
        return firstJumpAirborne and landedOnLid and secondJumpRequested
    end

    local function registerLandedOnLid()
        fireflyDiag.log("LID_LANDING_HANDLER", "alreadyLanded=" .. tostring(landedOnLid)
            .. "; lid=" .. tostring(fireflyDoubleJumpLid))
        if landedOnLid then
            return
        end

        local lid = fireflyDoubleJumpLid
        if not lid or not lid.Parent then
            return
        end

        landedOnLid = true
        statusLabel.Text = "Firefly: landed on lid"
        requestSecondJumpOnLid()
    end

    local function finishAttempt(message)
        fireflyDiag.log("ATTEMPT_FINISH", tostring(message or "no message")
            .. "; state=" .. tostring(humanoid:GetState())
            .. "; vy=" .. string.format("%.2f", rootPart.AssemblyLinearVelocity.Y)
            .. "; seq=" .. tostring(sequenceStarted))
        if message then
            statusLabel.Text = message
        end

        pcall(function()
            humanoid.Jump = false
            humanoid:Move(Vector3.zero, false)
        end)
        cancelFireflyDoubleJump()
        sequenceStarted = false
    end

    local function requestFirstJumpAgain()
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            humanoid.Jump = true
        end)
    end

    local function handleLandedGroundPart(groundPart, now)
        local lid = fireflyDoubleJumpLid
        if groundPart and lid and lid.Parent == Workspace and groundPart == lid then
            registerLandedOnLid()
            return false
        end

        if not groundPart then
            return false
        end

        if (not lid or lid.Parent ~= Workspace) and sequenceStartedAt and now < sequenceStartedAt + 1.25 then
            firstJumpAirborne = false
            statusLabel.Text = "Firefly: waiting for lid"
            return false
        end

        finishAttempt("Firefly: landed off lid")
        return true
    end

    local function beginTimedSequence()
        if sequenceStarted or fireflyFirstJumpTriggered
            or not character.Parent or humanoid.Health <= 0 or not rootPart.Parent then
            return false
        end

        local wasAirborneAtTrigger = isCharacterAirborne()
        lockMovement()
        pcall(function()
            humanoid:Move(Vector3.zero, false)
        end)

        sequenceStarted = true
        fireflyFirstJumpTriggered = true
        sequenceStartedAt = os.clock()
        firstJumpAirborne = false
        firstJumpDescentObserved = false
        firstLandingSeen = false
        lastClimbingStateAt = nil
        lastLandingStateAt = nil
        landedOnLid = false
        movementWindowStarted = false
        movementWindowDeadline = nil
        secondJumpRequested = false
        secondJumpDetected = false
        secondJumpRequestStartedAt = nil
        secondJumpRequestInitialRelativeVelocity = nil
        secondJumpRequestDeadline = nil
        nextSecondJumpRetryAt = 0
        if wasAirborneAtTrigger then
            firstJumpRequestDeadline = nil
        else
            firstJumpRequestDeadline = sequenceStartedAt + 0.22
        end
        nextFirstJumpRetryAt = sequenceStartedAt + 0.04
        sequenceResolutionDeadline = sequenceStartedAt + 2.0
        statusLabel.Text = wasAirborneAtTrigger and "Firefly: waiting for fresh jump" or "Firefly: first jump"

        inputWindowDeadline = sequenceStartedAt + Config.FIREFLY_FIRST_JUMP_HOLD_TIME
        local movementStartAt = sequenceStartedAt + 0.05

        if not wasAirborneAtTrigger then
            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
        end
        pcall(function()
            humanoid.Jump = true
        end)

        holdFireflyJump(humanoid, character, Config.FIREFLY_FIRST_JUMP_HOLD_TIME, inputWindowDeadline)
        startFireflyForwardMovement(
            character,
            humanoid,
            rootPart,
            movementStartAt,
            function(deadline)
                movementWindowStarted = true
                movementWindowDeadline = deadline
                sequenceResolutionDeadline = deadline + 0.75
            end,
            function()
                movementWindowDeadline = nil
            end,
            function(message)
                finishAttempt(message)
            end
        )
        return true
    end

    fireflyDoubleJumpJumpingConnection = humanoid.Jumping:Connect(function(active)
        fireflyDiag.log("JUMPING_EVENT", "active=" .. tostring(active)
            .. "; seq=" .. tostring(sequenceStarted)
            .. "; firstAirborne=" .. tostring(firstJumpAirborne)
            .. "; lidLanded=" .. tostring(landedOnLid)
            .. "; secondRequested=" .. tostring(secondJumpRequested)
            .. "; state=" .. tostring(humanoid:GetState())
            .. "; vy=" .. string.format("%.2f", rootPart.AssemblyLinearVelocity.Y))
        if active
            and sequenceStarted
            and character.Parent
            and humanoid.Parent
            and humanoid.Health > 0
            and isSecondJumpBeginning() then
            local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
            if verticalVelocity >= 20.0 then
                releaseAfterSecondJump("jump event with upward impulse")
            else
                -- The Jumping signal can fire before physics applies the actual jump
                -- impulse. Do not cancel Humanoid.Jump or release steering on that
                -- pre-impulse signal; PostSimulation confirms the real takeoff.
                fireflyDiag.log("JUMP_EVENT_WAIT_IMPULSE", "Jumping signal arrived before upward takeoff was confirmed; waiting for physics; vy="
                    .. string.format("%.2f", verticalVelocity)
                    .. "; state=" .. tostring(humanoid:GetState())
                    .. "; floor=" .. tostring(humanoid.FloorMaterial))
            end
        end
    end)

    fireflyDoubleJumpStateConnection = humanoid.StateChanged:Connect(function(oldState, newState)
        fireflyDiag.log("STATE_EVENT", tostring(oldState) .. " -> " .. tostring(newState)
            .. "; seq=" .. tostring(sequenceStarted)
            .. "; firstAirborne=" .. tostring(firstJumpAirborne)
            .. "; lidLanded=" .. tostring(landedOnLid)
            .. "; secondRequested=" .. tostring(secondJumpRequested)
            .. "; vy=" .. string.format("%.2f", rootPart.AssemblyLinearVelocity.Y))
        if not sequenceStarted or not character.Parent or humanoid.Health <= 0 then
            return
        end

        if newState == Enum.HumanoidStateType.Climbing then
            lastClimbingStateAt = os.clock()
            if fireflyDoubleJumpForwardConnection then
                fireflyDiag.log("CLIMBING_STATE_DEFERRED", "active steering will allow only brief near-lid contact; distant or persistent climbing is still canceled")
            else
                finishAttempt("Firefly: climbing detected without active lid steering; attempt canceled safely")
            end
            return
        end

        if newState == Enum.HumanoidStateType.Jumping then
            if isSecondJumpBeginning() then
                local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
                if verticalVelocity >= 20.0 then
                    releaseAfterSecondJump("state event with upward impulse")
                else
                    -- StateChanged can precede the physical jump impulse as well.
                    -- Keep the sequence alive until PostSimulation sees real takeoff.
                    fireflyDiag.log("STATE_EVENT_WAIT_IMPULSE", "Jumping state arrived before upward takeoff was confirmed; waiting for physics; vy="
                        .. string.format("%.2f", verticalVelocity)
                        .. "; state=" .. tostring(newState)
                        .. "; floor=" .. tostring(humanoid.FloorMaterial))
                end
                return
            end

            firstJumpAirborne = true
            firstJumpRequestDeadline = nil
            return
        end

        if newState == Enum.HumanoidStateType.Landed and firstJumpAirborne then
            lastLandingStateAt = os.clock()
            firstLandingSeen = true
            fireflyDiag.log("FIRST_LANDING_OBSERVED", "the first airborne phase has ended; a later upward takeoff can release controls even if lid detection fails")
            local landedPart = getGroundPart(true)
            fireflyDiag.log("LANDED_STATE", "groundPart=" .. tostring(landedPart)
                .. "; lid=" .. tostring(fireflyDoubleJumpLid)
                .. "; matches=" .. tostring(landedPart ~= nil and landedPart == fireflyDoubleJumpLid))
            handleLandedGroundPart(landedPart, os.clock())
        end
    end)

    local lastSecondJumpPhysicsDiagAt = 0
    fireflyDoubleJumpPhysicsConnection = RunService.PostSimulation:Connect(function()
        if not sequenceStarted
            or not firstJumpAirborne
            or secondJumpDetected
            or not character.Parent
            or not rootPart.Parent
            or not humanoid.Parent
            or humanoid.Health <= 0 then
            return
        end

        -- Remember that the first airborne phase has genuinely entered descent.
        -- Some Firefly attempts touch the lid's side, transition Climbing -> Running,
        -- and take off again without ever producing HumanoidStateType.Landed. The old
        -- fallback required firstLandingSeen, so it missed that second takeoff and left
        -- forward steering active until its timer expired.
        local currentState = humanoid:GetState()
        local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
        if not firstJumpDescentObserved
            and verticalVelocity <= -4.0
            and (currentState == Enum.HumanoidStateType.Freefall
                or currentState == Enum.HumanoidStateType.FallingDown
                or currentState == Enum.HumanoidStateType.Climbing
                or currentState == Enum.HumanoidStateType.Landed) then
            firstJumpDescentObserved = true
            fireflyDiag.log("FIRST_DESCENT_OBSERVED", "downward phase confirmed; later upward takeoff can release even without Landed; vy="
                .. string.format("%.2f", verticalVelocity)
                .. "; state=" .. tostring(currentState))
        end

        if firstJumpDescentObserved
            and verticalVelocity >= 20.0
            and (currentState == Enum.HumanoidStateType.Jumping
                or currentState == Enum.HumanoidStateType.Freefall) then
            local recentClimbingContact = lastClimbingStateAt ~= nil
                and os.clock() - lastClimbingStateAt <= 0.25
                and (lastLandingStateAt == nil or lastLandingStateAt < lastClimbingStateAt)
            if recentClimbingContact and not (landedOnLid and secondJumpRequested) then
                fireflyDiag.log("NON_LID_REBOUND_ABORT", "upward impulse followed recent Climbing contact without a confirmed lid-jump request; restoring controls; vy="
                    .. string.format("%.2f", verticalVelocity)
                    .. "; state=" .. tostring(currentState)
                    .. "; lidLanded=" .. tostring(landedOnLid)
                    .. "; secondRequested=" .. tostring(secondJumpRequested))
                finishAttempt("Firefly: side-climb rebound; controls restored")
            elseif landedOnLid and secondJumpRequested then
                fireflyDiag.log("POST_DESCENT_TAKEOFF", "confirmed upward impulse after requested lid jump; vy="
                    .. string.format("%.2f", verticalVelocity)
                    .. "; state=" .. tostring(currentState)
                    .. "; lidLanded=true; secondRequested=true; releasing controls now")
                releaseAfterSecondJump("confirmed post-descent lid jump impulse")
            else
                -- Preserve the fallback for cases where contact happened on the top edge but
                -- the root-center ray still did not recognize the lid. Recent side-climb contact
                -- is excluded above so this does not misclassify the lateral rebound as success.
                fireflyDiag.log("POST_DESCENT_TAKEOFF_FALLBACK", "upward impulse after descent without recent Climbing; releasing controls; vy="
                    .. string.format("%.2f", verticalVelocity)
                    .. "; state=" .. tostring(currentState)
                    .. "; lidLanded=" .. tostring(landedOnLid)
                    .. "; secondRequested=" .. tostring(secondJumpRequested))
                releaseAfterSecondJump("post-descent takeoff fallback")
            end
            return
        end

        -- Keep the earlier landed-state fallback as a lower-threshold backup for
        -- legitimate takeoffs whose upward impulse is weaker than the general detector.
        if firstLandingSeen and (not landedOnLid or not secondJumpRequested) then
            local currentState = humanoid:GetState()
            local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
            if verticalVelocity >= 2.0
                and (currentState == Enum.HumanoidStateType.Jumping
                    or currentState == Enum.HumanoidStateType.Freefall) then
                fireflyDiag.log("POST_LANDING_TAKEOFF", "fallback detected upward velocity; vy="
                    .. string.format("%.2f", verticalVelocity)
                    .. "; state=" .. tostring(currentState)
                    .. "; lidLanded=" .. tostring(landedOnLid)
                    .. "; secondRequested=" .. tostring(secondJumpRequested)
                    .. "; releasing controls now")
                releaseAfterSecondJump("post-landing takeoff fallback")
            end
            return
        end

        if not landedOnLid or not secondJumpRequested then
            return
        end

        local requestStartedAt = secondJumpRequestStartedAt
        if not requestStartedAt then
            return
        end

        local elapsedSinceRequest = os.clock() - requestStartedAt
        if elapsedSinceRequest <= 0 or elapsedSinceRequest > 0.45 then
            return
        end

        local lid = fireflyDoubleJumpLid
        local lidVerticalVelocity = 0
        if lid and lid.Parent == Workspace then
            lidVerticalVelocity = lid.AssemblyLinearVelocity.Y
        end

        local playerVerticalVelocity = rootPart.AssemblyLinearVelocity.Y
        local playerState = humanoid:GetState()
        local relativeVerticalVelocity = playerVerticalVelocity - lidVerticalVelocity
        local initialRelativeVelocity = secondJumpRequestInitialRelativeVelocity or 0
        local upwardVelocityChange = relativeVerticalVelocity - initialRelativeVelocity
        if os.clock() - lastSecondJumpPhysicsDiagAt >= 0.06 then
            lastSecondJumpPhysicsDiagAt = os.clock()
            fireflyDiag.log("PHYSICS_CHECK", "t=" .. string.format("%.3f", elapsedSinceRequest)
                .. "; rootVy=" .. string.format("%.2f", playerVerticalVelocity)
                .. "; relVy=" .. string.format("%.2f", relativeVerticalVelocity)
                .. "; deltaVy=" .. string.format("%.2f", upwardVelocityChange)
                .. "; state=" .. tostring(playerState)
                .. "; floor=" .. tostring(humanoid.FloorMaterial))
        end

        -- The lid can move independently and create a large relative-velocity change
        -- while the character is still grounded. Never treat lid-relative motion alone
        -- as proof that the player's second jump has begun.
        if playerVerticalVelocity >= 2.0
            and (playerState == Enum.HumanoidStateType.Jumping
                or playerState == Enum.HumanoidStateType.Freefall)
            and relativeVerticalVelocity >= 2.0
            and upwardVelocityChange >= 1.5 then
            releaseAfterSecondJump("physics impulse confirmed by player ascent")
        end
    end)

    local function handleFireflyLidAppearance(lid)
        if not lid or not lid:IsA("Part") or lid.Parent ~= Workspace then
            return
        end
        if preExistingLids and preExistingLids[lid] then
            return
        end
        if fireflyDoubleJumpLid and fireflyDoubleJumpLid.Parent and fireflyDoubleJumpLid ~= lid then
            return
        end
        bindFireflyLid(lid)
    end

    fireflyDoubleJumpLidConnection = Workspace.ChildAdded:Connect(function(instance)
        if instance and instance.Name == "Handle2" and instance:IsA("Part")
            and instance.Parent == Workspace
            and not (preExistingLids and preExistingLids[instance]) then
            handleFireflyLidAppearance(instance)
        end
    end)

    for _, existingLid in ipairs(Workspace:GetChildren()) do
        if existingLid.Name == "Handle2" and existingLid:IsA("Part")
            and not (preExistingLids and preExistingLids[existingLid]) then
            handleFireflyLidAppearance(existingLid)
        end
    end

    fireflyDoubleJumpRenderConnection = RunService.RenderStepped:Connect(function()
        local now = os.clock()
        if not character.Parent or not rootPart.Parent or not humanoid.Parent or humanoid.Health <= 0 then
            finishAttempt("Firefly: character unavailable")
            return
        end

        if not sequenceStarted then
            if now - startedAt > Config.FIREFLY_ARM_TRACK_TIMEOUT then
                finishAttempt("Firefly: right arm trigger timed out")
                return
            end

            local lateral = getFireflyArmLateralPosition(shoulder, armPart)
            if activationState and not activationState.activated then
                if lateral ~= nil then
                    neutralLateral = lateral
                    previousLateral = lateral
                    previousSampleAt = now
                    phase = 0
                    firstDirection = 0
                    firstLegTravel = 0
                    returnTravel = 0
                    reversalFrames = 0
                end
                return
            end
            if lateral == nil then
                finishAttempt("Firefly: right arm position unavailable")
                return
            end

            local delta = lateral - neutralLateral
            local step = lateral - previousLateral
            local dt = math.max(now - previousSampleAt, 1 / 240)
            local velocity = step / dt
            previousSampleAt = now

            if phase == 0 then
                if math.abs(delta) >= initialTravelThreshold then
                    firstDirection = delta >= 0 and 1 or -1
                    firstLegTravel = math.abs(delta)
                    phase = 1
                end
            elseif phase == 1 then
                if math.abs(delta) > firstLegTravel then
                    firstLegTravel = math.abs(delta)
                    returnTravel = 0
                    reversalFrames = 0
                end

                if velocity * firstDirection < -0.01 then
                    reversalFrames = reversalFrames + 1
                    returnTravel = returnTravel + math.abs(step)
                    if reversalFrames >= Config.FIREFLY_ARM_REVERSAL_FRAMES then
                        phase = 2
                    end
                else
                    reversalFrames = 0
                    returnTravel = 0
                end
            elseif phase == 2 then
                local returnVelocity = -velocity * firstDirection
                if returnVelocity > 0.01 then
                    returnTravel = returnTravel + math.abs(step)
                    local returnRatio = firstLegTravel > 0 and returnTravel / firstLegTravel or 0
                    if returnTravel >= returnTravelThreshold
                        and returnRatio >= Config.FIREFLY_FIRST_JUMP_RETURN_RATIO then
                        beginTimedSequence()
                    end
                elseif velocity * firstDirection > 0.01 then
                    phase = 1
                    firstLegTravel = math.max(firstLegTravel, math.abs(delta))
                    returnTravel = 0
                    reversalFrames = 0
                end
            end

            previousLateral = lateral
            if not sequenceStarted then
                return
            end
        end

        if not firstJumpAirborne then
            if firstJumpRequestDeadline and now >= firstJumpRequestDeadline then
                finishAttempt("Firefly: first jump not detected")
                return
            end

            if humanoid.FloorMaterial ~= Enum.Material.Air
                and math.abs(rootPart.AssemblyLinearVelocity.Y) <= 1.5
                and now >= nextFirstJumpRetryAt then
                if not firstJumpRequestDeadline then
                    firstJumpRequestDeadline = now + 0.22
                end
                nextFirstJumpRetryAt = now + 0.045
                requestFirstJumpAgain()
            end
        end

        if firstJumpAirborne and isCharacterGrounded() then
            if handleLandedGroundPart(getGroundPart(), now) then
                return
            end
        end

        if not sequenceStarted then
            return
        end

        if landedOnLid and secondJumpRequested and not secondJumpDetected then
            if secondJumpRequestDeadline and now >= secondJumpRequestDeadline then
                finishAttempt("Firefly: second jump failed")
                return
            end

            local lid = fireflyDoubleJumpLid
            if now >= nextSecondJumpRetryAt
                and lid and lid.Parent == Workspace
                and humanoid.FloorMaterial ~= Enum.Material.Air
                and math.abs(rootPart.AssemblyLinearVelocity.Y) <= 1.5
                and getGroundPart(true) == lid then
                nextSecondJumpRetryAt = now + 0.06
                issueSecondJumpRequest()
            end
        end

        if movementWindowDeadline and now >= movementWindowDeadline then
            fireflyDiag.log("MOVE_WINDOW_EXPIRED", "movement deadline reached before/after lid jump request; lidLanded="
                .. tostring(landedOnLid) .. "; secondRequested=" .. tostring(secondJumpRequested)
                .. "; secondDetected=" .. tostring(secondJumpDetected))
            stopFireflyForwardMovement()
            pcall(function()
                humanoid:Move(Vector3.zero, false)
            end)
            movementWindowDeadline = nil
        end

        if inputWindowDeadline and now >= inputWindowDeadline and not movementWindowDeadline then
            if landedOnLid and secondJumpRequested and not secondJumpDetected then
                if secondJumpRequestDeadline and now >= secondJumpRequestDeadline then
                    finishAttempt("Firefly: second jump failed")
                    return
                end
            elseif sequenceResolutionDeadline and now >= sequenceResolutionDeadline then
                finishAttempt("Firefly: sequence timed out")
                return
            elseif not movementWindowStarted and sequenceStartedAt and now >= sequenceStartedAt + 1.25 then
                finishAttempt("Firefly: lid not detected")
                return
            elseif not firstJumpAirborne and firstJumpRequestDeadline and now >= firstJumpRequestDeadline then
                finishAttempt("Firefly: first jump not detected")
                return
            end
        end
    end)
end

local function armFireflyBounce(character, humanoid, rootPart)
    if not character or not humanoid or not rootPart then
        return
    end

    if fireflyTimingChildConnection then
        fireflyTimingChildConnection:Disconnect()
        fireflyTimingChildConnection = nil
    end
    if fireflyTimingRenderConnection then
        fireflyTimingRenderConnection:Disconnect()
        fireflyTimingRenderConnection = nil
    end

    local startedAt = fireflyTimingStartedAt
    fireflyTimingActive = true
    fireflyTimingElapsed = nil

    local function finishTiming(instance)
        if not fireflyTimingActive then
            return
        end

        if not instance or instance.Name ~= "Handle2" or not instance:IsA("Part") or instance.Parent ~= Workspace then
            return
        end

        fireflyTimingElapsed = os.clock() - startedAt
        fireflyTimingActive = false

        if fireflyTimingChildConnection then
            fireflyTimingChildConnection:Disconnect()
            fireflyTimingChildConnection = nil
        end
        if fireflyTimingRenderConnection then
            fireflyTimingRenderConnection:Disconnect()
            fireflyTimingRenderConnection = nil
        end

        statusLabel.Text = string.format("Firefly lid opened: %.3fs", fireflyTimingElapsed)
    end

    fireflyTimingChildConnection = Workspace.ChildAdded:Connect(finishTiming)

    fireflyTimingRenderConnection = RunService.RenderStepped:Connect(function()
        if not character.Parent or not rootPart.Parent or humanoid.Health <= 0 then
            if fireflyTimingChildConnection then
                fireflyTimingChildConnection:Disconnect()
                fireflyTimingChildConnection = nil
            end
            if fireflyTimingRenderConnection then
                fireflyTimingRenderConnection:Disconnect()
                fireflyTimingRenderConnection = nil
            end
            fireflyTimingActive = false
            return
        end

        if fireflyTimingActive then
            statusLabel.Text = string.format("Opening Firefly: %.3fs", os.clock() - startedAt)
        end
    end)
end

local function armBombBounce(character, humanoid, rootPart, bombPart, targetPosition, bombTool)
    if not character or not humanoid or not rootPart then
        return
    end

    if savedBombSettings.BombStyle == "Blatant" and selectedBombType ~= "Firefly Jar" then
        local deadline = os.clock() + Config.BOMB_BOUNCE_TRACK_TIME
        local trackedBomb = bombPart
        local foundBomb = trackedBomb ~= nil and trackedBomb.Parent ~= nil
        local finished = false
        local previousGap = nil
        local contactConnection = nil
        local descendantConnection = nil
        local fallbackBombHeight = 1

        local function cleanupContactTracking()
            if contactConnection then
                contactConnection:Disconnect()
                contactConnection = nil
            end
            if descendantConnection then
                descendantConnection:Disconnect()
                descendantConnection = nil
            end
        end

        local function getTrackedBombBounds(part)
            if not part or not part.Parent then
                return nil, nil
            end
            local container = getBombContainer(part, character)
            if container and container:IsA("Model") then
                local ok, boundsCFrame, boundsSize = pcall(function()
                    return container:GetBoundingBox()
                end)
                if ok and boundsCFrame and boundsSize then
                    return boundsCFrame, boundsSize
                end
            end
            return part.CFrame, part.Size
        end

        local function horizontalDistance(first, second)
            return Vector3.new(first.X - second.X, 0, first.Z - second.Z).Magnitude
        end

        local function getContactPlaneY()
            if targetPosition then
                local expectedBombHeight = fallbackBombHeight
                if trackedBomb and trackedBomb.Parent then
                    local container = getBombContainer(trackedBomb, character)
                    expectedBombHeight = getBombHeight(trackedBomb, container)
                end
                return targetPosition.Y + expectedBombHeight - Config.BOMB_GROUND_SINK
            end

            if trackedBomb and trackedBomb.Parent then
                local boundsCFrame, boundsSize = getTrackedBombBounds(trackedBomb)
                if boundsCFrame and boundsSize then
                    return boundsCFrame.Position.Y + boundsSize.Y * 0.5
                end
            end

            return nil
        end

        local function triggerBlatantJump()
            if finished or not character.Parent or not rootPart.Parent or humanoid.Health <= 0 then
                return
            end
            finished = true
            cleanupContactTracking()

            local velocity = rootPart.AssemblyLinearVelocity
            local jumpVelocity
            if humanoid.UseJumpPower then
                jumpVelocity = humanoid.JumpPower
            else
                jumpVelocity = math.sqrt(math.max(0, 2 * Workspace.Gravity * humanoid.JumpHeight))
            end
            pcall(function()
                humanoid.Jump = false
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
            rootPart.AssemblyLinearVelocity = Vector3.new(
                velocity.X,
                math.max(velocity.Y, jumpVelocity),
                velocity.Z
            )
            statusLabel.Text = "Blatant: air jump synchronized"
        end

        local initialHumanoidState = humanoid:GetState()
        local initialVerticalVelocity = rootPart.AssemblyLinearVelocity.Y
        local alreadyInFreefall = initialHumanoidState == Enum.HumanoidStateType.Freefall
            or initialHumanoidState == Enum.HumanoidStateType.FallingDown

        if not alreadyInFreefall
            and humanoid.FloorMaterial == Enum.Material.Air
            and initialVerticalVelocity < -0.5 then
            alreadyInFreefall = true
        end

        if alreadyInFreefall then
            triggerBlatantJump()
            return
        end

        local function considerBombCandidate(instance)
            if trackedBomb and trackedBomb.Parent then
                return
            end
            if not isBombCandidate(instance, character, bombTool) then
                return
            end
            if targetPosition and horizontalDistance(instance.Position, targetPosition) > Config.BOMB_BOUNCE_CHECK_RADIUS + 2 then
                return
            end
            trackedBomb = instance
            foundBomb = true
        end

        if not trackedBomb or not trackedBomb.Parent then
            trackedBomb = findNearbyBombPart(character, bombTool, targetPosition)
            foundBomb = trackedBomb ~= nil
        end
        descendantConnection = Workspace.DescendantAdded:Connect(considerBombCandidate)

        contactConnection = RunService.PostSimulation:Connect(function(deltaTimeSim)
            if finished then
                cleanupContactTracking()
                return
            end
            if not character.Parent or not rootPart.Parent or humanoid.Health <= 0 then
                finished = true
                cleanupContactTracking()
                return
            end
            if os.clock() >= deadline then
                finished = true
                cleanupContactTracking()
                statusLabel.Text = foundBomb and "Blatant: air-jump timing missed" or "Blatant: virtual-plane timing missed"
                return
            end

            if not trackedBomb or not trackedBomb.Parent then
                trackedBomb = findNearbyBombPart(character, bombTool, targetPosition)
                if trackedBomb then
                    foundBomb = true
                end
            end

            local contactPlaneY = getContactPlaneY()
            if not contactPlaneY then
                return
            end

            local _, footBottomY = getFootData(character, rootPart)
            local velocityY = rootPart.AssemblyLinearVelocity.Y
            local verticalGap = footBottomY - contactPlaneY
            local timeToContact = nil

            if velocityY < -0.5 then
                timeToContact = solveDescendingGroundHitTime(
                    footBottomY,
                    velocityY,
                    contactPlaneY,
                    Workspace.Gravity
                )
            end

            local contactWithinFrame = timeToContact ~= nil
                and timeToContact >= 0
                and timeToContact <= math.clamp(deltaTimeSim * 1.5, 0.020, 0.035)
            local crossedContactPlane = previousGap ~= nil
                and previousGap > 0
                and verticalGap <= 0
            local insideContactBand = verticalGap <= 0.30 and verticalGap >= -0.85
            local alreadyPastPlaneOnFirstSample = previousGap == nil and verticalGap < -0.85

            if velocityY < -0.5 and (
                contactWithinFrame
                or crossedContactPlane
                or insideContactBand
                or alreadyPastPlaneOnFirstSample
            ) then
                triggerBlatantJump()
                return
            end

            previousGap = verticalGap
        end)
        return
    end

    local deadline = os.clock() + Config.BOMB_BOUNCE_INPUT_HOLD_TIME
    local inputConnection

    local function cleanup()
        if inputConnection then
            inputConnection:Disconnect()
            inputConnection = nil
        end
        pcall(function()
            humanoid.Jump = false
        end)
    end

    inputConnection = RunService.RenderStepped:Connect(function()
        if not character.Parent or not rootPart.Parent or humanoid.Health <= 0 or os.clock() >= deadline then
            cleanup()
            return
        end

        pcall(function()
            humanoid.Jump = true
        end)
    end)
end

lockBombActivation = function()
    if bombToolActivationLocked then
        return
    end

    local bombTool
    local character = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if selectedBombType == "Firefly Jar" then
        bombTool = findRealFireflyJar(LocalPlayer)
    else
        bombTool = findSelectedBombTool(character) or findSelectedBombTool(backpack)
    end
    if not bombTool then
        return
    end

    local ok = pcall(function()
        bombToolActivationOriginal = bombTool.ManualActivationOnly
        bombTool.ManualActivationOnly = true
    end)

    if ok then
        bombToolActivationLocked = true
        bombToolActivationReference = bombTool
    end
end

unlockBombActivation = function()
    if not bombToolActivationLocked then
        return
    end

    local bombTool = bombToolActivationReference
    pcall(function()
        if bombTool and bombTool.Parent then
            bombTool.ManualActivationOnly = bombToolActivationOriginal
        end
    end)

    bombToolActivationLocked = false
    bombToolActivationReference = nil
    bombToolActivationOriginal = nil
end

resetBombCooldown = function()
    bombCooldownGeneration = bombCooldownGeneration + 1
    isWaitingTimerBomb = false
    hasTriggeredBomb = false
    isActiveBomb = false
    isArmedBomb = false
    cancelFireflyDoubleJump()
    if fireflyTimingChildConnection then
        fireflyTimingChildConnection:Disconnect()
        fireflyTimingChildConnection = nil
    end
    if fireflyTimingRenderConnection then
        fireflyTimingRenderConnection:Disconnect()
        fireflyTimingRenderConnection = nil
    end
    fireflyTimingActive = false
    fireflyTimingStartedAt = 0
    fireflyTimingElapsed = nil
    saveBombSettings()
    statusLabel.Text = "Ready"
    renderBombVisualState()
end

local function updatePendingBombVisual()
    if not bombButton then
        return
    end
    renderBombVisualState()
    statusLabel.Text = "Armed. Jump to launch. Tap again to cancel."
end

local function disconnectPendingBombWatchers()
    if pendingBombStateConnection then
        pendingBombStateConnection:Disconnect()
        pendingBombStateConnection = nil
    end
    if pendingBombHeartbeatConnection then
        pendingBombHeartbeatConnection:Disconnect()
        pendingBombHeartbeatConnection = nil
    end
end

local function finishBombCooldown()
    if isWaitingTimerBomb then
        if isActiveBomb or isArmedBomb then
            isActiveBomb = false
            isArmedBomb = false
            saveBombSettings()
            renderBombVisualState()
        end
        return
    end

    bombCooldownGeneration = bombCooldownGeneration + 1
    local generation = bombCooldownGeneration
    isWaitingTimerBomb = true
    isActiveBomb = false
    isArmedBomb = false
    local cooldown
    if selectedBombType == "Gold Bomb" then
        cooldown = Config.GOLD_COOLDOWN
    elseif selectedBombType == "Firefly Jar" then
        cooldown = Config.FIREFLY_COOLDOWN
    else
        cooldown = Config.NORMAL_COOLDOWN
    end
    local deadline = time() + cooldown
    saveBombSettings()

    statusLabel.Text = string.format("Cooldown: %.1fs", cooldown)
    renderBombVisualState()

    task.spawn(function()
        while isWaitingTimerBomb and generation == bombCooldownGeneration and time() < deadline do
            local remaining = math.max(0, deadline - time())
            if not noGuiTimerBomb then
                bombButton.Text = string.format("Wait (%.1fs)", remaining)
            else
                renderBombVisualState()
            end
            bombButton.TextColor3 = Color3.fromRGB(255, 70, 70)
            bombStroke.Color = Color3.fromRGB(255, 0, 0)
            if cooldownOverlay then
                cooldownOverlay.BackgroundTransparency = 0.70
            end
            if selectedBombType ~= "Firefly Jar" or not fireflyTimingActive then
                if selectedBombType == "Firefly Jar" and fireflyTimingElapsed then
                    statusLabel.Text = string.format("Lid opened: %.3fs | Cooldown: %.1fs", fireflyTimingElapsed, remaining)
                else
                    statusLabel.Text = string.format("Cooldown: %.1fs", remaining)
                end
            end
            task.wait(0.05)
        end

        if not isWaitingTimerBomb or generation ~= bombCooldownGeneration then
            return
        end

        isWaitingTimerBomb = false
        hasTriggeredBomb = false
        statusLabel.Text = "Ready"
        renderBombVisualState()
        saveBombSettings()
    end)
end

local function activateFireflyJar()
    if isWaitingTimerBomb then
        return false
    end

    local activationGeneration = bombCooldownGeneration
    local cooldownAnchor = os.clock()
    local player = LocalPlayer
    local character = player and player.Character
    if not character then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart or humanoid.Health <= 0 then
        return false
    end

    local bombTool = prepareRealFireflyJar(player)
    if not bombTool then
        statusLabel.Text = "Firefly Jar not found"
        return false
    end

    local backpack = player:FindFirstChild("Backpack")
    local fireflyEquipped = bombTool.Parent == character
    local fireflyEquippedConnection = nil
    local fireflyMouse = nil

    pcall(function()
        fireflyEquippedConnection = bombTool.Equipped:Connect(function(mouse)
            fireflyEquipped = true
            fireflyMouse = mouse
        end)
    end)

    if bombTool.Parent ~= character then
        if bombTool.Parent ~= backpack then
            if fireflyEquippedConnection then
                fireflyEquippedConnection:Disconnect()
            end
            statusLabel.Text = "Firefly Jar is not in Backpack"
            return false
        end

        pcall(function()
            humanoid:EquipTool(bombTool)
        end)

        local equipDeadline = os.clock() + math.max(Config.BOMB_EQUIP_TIMEOUT, 1.50)
        while (bombTool.Parent ~= character or not fireflyEquipped)
            and os.clock() < equipDeadline do
            RunService.Heartbeat:Wait()
        end
    end

    if fireflyEquipped and not fireflyMouse then
        pcall(function()
            fireflyEquipped = false
            humanoid:UnequipTools()
        end)

        RunService.Heartbeat:Wait()

        if bombTool.Parent ~= character then
            pcall(function()
                humanoid:EquipTool(bombTool)
            end)
        end

        local reEquipDeadline = os.clock() + 1.50
        while (bombTool.Parent ~= character or not fireflyMouse)
            and os.clock() < reEquipDeadline do
            RunService.Heartbeat:Wait()
        end
        fireflyEquipped = bombTool.Parent == character
    end

    if fireflyEquipped and not fireflyMouse then
        pcall(function()
            fireflyMouse = player:GetMouse()
        end)
    end

    if fireflyEquippedConnection then
        fireflyEquippedConnection:Disconnect()
        fireflyEquippedConnection = nil
    end

    if bombTool.Parent ~= character or not fireflyEquipped then
        statusLabel.Text = "Firefly Jar could not be equipped"
        return false
    end

    lastKnownBombTool = bombTool

    task.wait(Config.FIREFLY_EQUIP_SETTLE_TIME)

    local originalManualActivationOnly = nil
    pcall(function()
        originalManualActivationOnly = bombTool.ManualActivationOnly
        bombTool.ManualActivationOnly = false
    end)

    RunService.Heartbeat:Wait()

    pcall(function()
        bombTool:Deactivate()
    end)
    RunService.Heartbeat:Wait()

    local preActivationFireflyLids = snapshotExistingFireflyLids()
    local fireflyShoulder = findFireflyRightShoulder(character)
    local fireflyActivationState = { activated = false }
    armFireflyDoubleJump(
        character,
        humanoid,
        rootPart,
        fireflyShoulder,
        preActivationFireflyLids,
        fireflyActivationState
    )

    local activated = false
    local fireflyReleaseAnchor = nil
    local fireflyMousePressStarted = false
    local toolActivationObserved = false
    local toolActivationConnection = nil

    pcall(function()
        toolActivationConnection = bombTool.Activated:Connect(function()
            toolActivationObserved = true
            fireflyActivationState.activated = true
        end)
    end)

    local function waitForToolActivation(timeout)
        local deadline = os.clock() + timeout
        while not toolActivationObserved and os.clock() < deadline do
            RunService.Heartbeat:Wait()
        end
        return toolActivationObserved
    end

    local function releaseFireflyMousePress()
        if not fireflyMousePressStarted then
            return
        end
        pcall(function()
            if fireflyMouse and fireflyMouse.Button1Up and type(firesignal) == "function" then
                firesignal(fireflyMouse.Button1Up)
            end
        end)
        fireflyMousePressStarted = false
    end

    if fireflyMouse and fireflyMouse.Button1Down and type(firesignal) == "function" then
        local pressSucceeded = pcall(function()
            fireflyReleaseAnchor = os.clock()
            fireflyMousePressStarted = true
            firesignal(fireflyMouse.Button1Down)
        end)
        if pressSucceeded then
            activated = waitForToolActivation(0.20)
        end
        if not activated then
            releaseFireflyMousePress()
        end
    end

    if not activated and fireflyMouse and fireflyMouse.Button1Down and type(getconnections) == "function" then
        local callSucceeded, invoked = pcall(function()
            fireflyReleaseAnchor = os.clock()
            local connections = getconnections(fireflyMouse.Button1Down)
            local called = false
            for _, connection in ipairs(connections) do
                if connection and connection.Function then
                    called = pcall(connection.Function) or called
                end
            end
            return called
        end)
        if callSucceeded and invoked then
            activated = waitForToolActivation(0.20)
        end
    end

    if not activated then
        local activateSucceeded = pcall(function()
            fireflyReleaseAnchor = os.clock()
            bombTool:Activate()
        end)
        if activateSucceeded then
            activated = waitForToolActivation(0.20)
        end
    end

    if toolActivationConnection then
        toolActivationConnection:Disconnect()
        toolActivationConnection = nil
    end

    if not activated then
        releaseFireflyMousePress()
    end

    if not activated then
        if fireflyTimingChildConnection then
            fireflyTimingChildConnection:Disconnect()
            fireflyTimingChildConnection = nil
        end
        if fireflyTimingRenderConnection then
            fireflyTimingRenderConnection:Disconnect()
            fireflyTimingRenderConnection = nil
        end
        fireflyTimingActive = false
        fireflyTimingElapsed = nil
        cancelFireflyDoubleJump()
        statusLabel.Text = "Firefly Jar activation failed"

        pcall(function()
            if originalManualActivationOnly ~= nil then
                bombTool.ManualActivationOnly = originalManualActivationOnly
            end
        end)
        unlockBombActivation()
        return false
    end

    pcall(function()
        if originalManualActivationOnly ~= nil then
            bombTool.ManualActivationOnly = originalManualActivationOnly
        end
    end)

    unlockBombActivation()

    task.spawn(function()
        local releaseAnchor = fireflyReleaseAnchor or os.clock()
        local releaseDelay = releaseAnchor + Config.FIREFLY_RELEASE_DELAY - os.clock()
        if releaseDelay > 0 then
            task.wait(releaseDelay)
        end

        releaseFireflyMousePress()
        pcall(function()
            bombTool:Deactivate()
            if originalManualActivationOnly ~= nil then
                bombTool.ManualActivationOnly = originalManualActivationOnly
            else
                bombTool.ManualActivationOnly = false
            end
        end)

        pcall(function()
            if bombTool.Parent == character then
                humanoid:UnequipTools()
            end
            RunService.Heartbeat:Wait()
            if bombTool.Parent == character then
                local currentBackpack = player:FindFirstChild("Backpack")
                if currentBackpack then
                    bombTool.Parent = currentBackpack
                end
            end
        end)
    end)

    local cooldownDelay = cooldownAnchor + Config.FIREFLY_COOLDOWN_START_DELAY - os.clock()
    if cooldownDelay > 0 then
        task.wait(cooldownDelay)
    end

    if activationGeneration ~= bombCooldownGeneration
        or not character.Parent
        or humanoid.Health <= 0
        or player.Character ~= character then
        return false
    end

    finishBombCooldown()

    return true
end

local function launchPendingBombJump()
    if not pendingBombJump or pendingBombLaunchInProgress then
        return
    end

    local launchGeneration = pendingBombSequenceGeneration
    local player = LocalPlayer
    local character = pendingBombCharacter
    local humanoid = pendingBombHumanoid
    local rootPart = pendingBombRootPart
    local bombTool = pendingBombTool
    local wasEquipped = pendingBombWasEquipped
    local wasToggle = pendingBombWasToggle
    local freefallFastPath = pendingBombStartedInFreefall

    if not player or not character or not humanoid or not rootPart or not bombTool then
        return
    end

    if humanoid.Health <= 0 or not character.Parent then
        cancelPendingBombJump()
        return
    end

    if bombTool.Parent ~= character then
        return
    end

    if freefallFastPath then
        pendingBombLaunchInProgress = true
        task.wait(BombStyleRuntime.FreefallReleaseDelay)

        if not pendingBombJump
            or pendingBombSequenceGeneration ~= launchGeneration
            or pendingBombCharacter ~= character
            or pendingBombTool ~= bombTool then
            pendingBombLaunchInProgress = false
            return
        end
        if not character.Parent or humanoid.Health <= 0 or player.Character ~= character then
            pendingBombLaunchInProgress = false
            cancelPendingBombJump()
            return
        end
        if bombTool.Parent ~= character then
            pendingBombLaunchInProgress = false
            return
        end

        pendingBombLaunchInProgress = false
    end

    disconnectPendingBombWatchers()

    pendingBombJump = false
    pendingBombTool = nil
    pendingBombCharacter = nil
    pendingBombHumanoid = nil
    pendingBombRootPart = nil
    pendingBombWasToggle = false
    pendingBombEquipDeadline = 0
    pendingBombLaunchWindowReached = false
    pendingBombLaunchWaitDeadline = nil
    pendingBombStartedInFreefall = false

    local targetPosition = nil
    local targetPart = nil
    local bombPart = nil
    local descendantConnection
    local detectionDeadline = os.clock() + 0.18
    local launchConfirmed = false
    local throwOrigin = rootPart.Position
    local rightHand = character:FindFirstChild("RightHand")
        or character:FindFirstChild("Right Arm")
        or character:FindFirstChild("RightLowerArm")
        or character:FindFirstChild("RightUpperArm")
    if rightHand and rightHand:IsA("BasePart") then
        throwOrigin = rightHand.Position
    end

    local existingBombParts = {}
    local newBombCandidates = {}
    local bombDetectionScheduled = false
    local launchOverlapParams = OverlapParams.new()
    launchOverlapParams.FilterType = Enum.RaycastFilterType.Exclude
    launchOverlapParams.FilterDescendantsInstances = {character, bombTool}
    launchOverlapParams.MaxParts = 128

    for _, instance in ipairs(Workspace:GetPartBoundsInRadius(throwOrigin, 24, launchOverlapParams)) do
        existingBombParts[instance] = true
    end

    local function isPlausibleThrownBombPart(instance, metadata)
        if not instance or not instance:IsA("BasePart") or not instance.Parent then
            return false
        end
        if instance:IsDescendantOf(character) or instance:IsDescendantOf(bombTool) then
            return false
        end
        if existingBombParts[instance] or not metadata then
            return false
        end

        local largestDimension = math.max(instance.Size.X, instance.Size.Y, instance.Size.Z)
        if largestDimension < 0.16 or largestDimension > 9 then
            return false
        end

        if instance.Anchored then
            return false
        end

        local namedCandidate = isBombCandidate(instance, character, bombTool)
        local originDistance = (instance.Position - throwOrigin).Magnitude
        local targetDistance = targetPosition and (instance.Position - targetPosition).Magnitude or math.huge

        if namedCandidate then
            return metadata.originDistance <= 24 or metadata.targetDistance <= 12
        end

        if not (instance.CanCollide or instance.CanTouch or instance.CanQuery) then
            return false
        end

        return metadata.originDistance <= 13 and (originDistance <= 16 or targetDistance <= 8)
    end

    local function findNewlySpawnedBombPart()
        local bestPart = nil
        local bestScore = math.huge

        local function consider(instance)
            local metadata = newBombCandidates[instance]
            if not isPlausibleThrownBombPart(instance, metadata) then
                return
            end

            local originDistance = (instance.Position - throwOrigin).Magnitude
            local targetDistance = targetPosition and (instance.Position - targetPosition).Magnitude or originDistance
            local largestDimension = math.max(instance.Size.X, instance.Size.Y, instance.Size.Z)
            local agePenalty = metadata and math.max(0, os.clock() - metadata.createdAt) * 3 or 2
            local nameBonus = isBombCandidate(instance, character, bombTool) and -100 or 0
            local collisionBonus = instance.CanCollide and -8 or 0
            local sizeBonus = -math.min(largestDimension, 3) * 0.2
            local score = nameBonus + targetDistance + originDistance * 0.12 + agePenalty + collisionBonus + sizeBonus

            if score < bestScore then
                bestScore = score
                bestPart = instance
            end
        end

        for instance in pairs(newBombCandidates) do
            consider(instance)
        end

        for _, instance in ipairs(Workspace:GetPartBoundsInRadius(throwOrigin, 24, launchOverlapParams)) do
            consider(instance)
        end

        if targetPosition then
            for _, instance in ipairs(Workspace:GetPartBoundsInRadius(targetPosition, 12, launchOverlapParams)) do
                consider(instance)
            end
        end

        return bestPart
    end

    local function selectNewlySpawnedBombPart()
        if bombPart and bombPart.Parent then
            return true
        end

        local candidate = findNewlySpawnedBombPart()
        if not candidate then
            return false
        end

        bombPart = candidate
        return true
    end

    local function cleanupDetection()
        if descendantConnection then
            descendantConnection:Disconnect()
            descendantConnection = nil
        end
    end

    descendantConnection = Workspace.DescendantAdded:Connect(function(instance)
        if not instance:IsA("BasePart") or existingBombParts[instance] then
            return
        end
        if instance:IsDescendantOf(character) or instance:IsDescendantOf(bombTool) then
            return
        end

        local namedCandidate = isBombCandidate(instance, character, bombTool)
        local largestDimension = math.max(instance.Size.X, instance.Size.Y, instance.Size.Z)
        if largestDimension < 0.16 or largestDimension > 9 then
            return
        end
        if not namedCandidate and not (instance.CanCollide or instance.CanTouch or instance.CanQuery) then
            return
        end

        local distanceFromThrowOrigin = (instance.Position - throwOrigin).Magnitude
        local distanceFromTarget = targetPosition and (instance.Position - targetPosition).Magnitude or math.huge
        if namedCandidate then
            if distanceFromThrowOrigin > 24 and distanceFromTarget > 12 then
                return
            end
        elseif distanceFromThrowOrigin > 13 and distanceFromTarget > 8 then
            return
        end

        newBombCandidates[instance] = {
            createdAt = os.clock(),
            named = namedCandidate,
            originDistance = distanceFromThrowOrigin,
            targetDistance = distanceFromTarget,
        }
        if bombDetectionScheduled then
            return
        end
        bombDetectionScheduled = true

        task.delay(0.02, function()
            bombDetectionScheduled = false
            if not bombPart then
                selectNewlySpawnedBombPart()
            end
        end)
    end)

    local activationConnection = bombTool.Activated:Connect(function()
        launchConfirmed = true
    end)

    local directRemoteLaunch, remoteTargetPosition = fireBombRemote(
        bombTool,
        character,
        rootPart,
        humanoid,
        player,
        freefallFastPath
    )

    if directRemoteLaunch then
        targetPosition = remoteTargetPosition
    else
        targetPosition, _, targetPart = getPredictedBombTarget(
            character,
            humanoid,
            rootPart,
            bombTool,
            player
        )
    end

    if directRemoteLaunch then
        selectNewlySpawnedBombPart()
    end

    if not targetPosition then
        cleanupDetection()
        if activationConnection then
            activationConnection:Disconnect()
        end
        pcall(function()
            bombTool.ManualActivationOnly = pendingBombManualActivationOriginal
        end)
        pendingBombManualActivationOriginal = nil
        unlockBombActivation()
        if not wasEquipped and bombTool.Parent == character then
            pcall(function()
                humanoid:UnequipTools()
            end)
        end
        if not wasToggle then
            updatePendingBombVisual()
        end
        return
    end

    if wasToggle then
        saveBombSettings()
    end

    local mouse
    local previousTargetFilter

    if not directRemoteLaunch then
        local camera = Workspace.CurrentCamera
        if not camera then
            cleanupDetection()
            if activationConnection then
                activationConnection:Disconnect()
            end
            pcall(function()
                bombTool.ManualActivationOnly = pendingBombManualActivationOriginal
            end)
            pendingBombManualActivationOriginal = nil
            unlockBombActivation()
            if not wasEquipped and bombTool.Parent == character then
                pcall(function()
                    humanoid:UnequipTools()
                end)
            end
            return
        end

        local screenPosition, inputCamera = getVirtualBombInput(camera, targetPosition)
        if not screenPosition or not inputCamera then
            cleanupDetection()
            if activationConnection then
                activationConnection:Disconnect()
            end
            pcall(function()
                bombTool.ManualActivationOnly = pendingBombManualActivationOriginal
            end)
            pendingBombManualActivationOriginal = nil
            unlockBombActivation()
            if not wasEquipped and bombTool.Parent == character then
                pcall(function()
                    humanoid:UnequipTools()
                end)
            end
            return
        end

        setBombMouseOverride(inputCamera, screenPosition, targetPosition, targetPart)
        mouse = player:GetMouse()
        previousTargetFilter = mouse.TargetFilter
        mouse.TargetFilter = character

        pcall(function()
            bombTool.ManualActivationOnly = false
        end)

        local activated = performBombActivationInput(
            screenPosition,
            inputCamera,
            function()
                return launchConfirmed
            end
        )

        if not launchConfirmed and type(firesignal) == "function" then
            pcall(function()
                firesignal(bombTool.Activated)
            end)
            activated = true
            RunService.Heartbeat:Wait()
        end

        if not launchConfirmed and activated then
            pcall(function()
                fireBombActivatedConnections(bombTool)
            end)
            RunService.Heartbeat:Wait()
        end

        pcall(function()
            bombTool:Deactivate()
        end)
    end

    if directRemoteLaunch and not freefallFastPath then
        task.wait(0.05)
    end

    pcall(function()
        bombTool.ManualActivationOnly = pendingBombManualActivationOriginal
    end)
    pendingBombManualActivationOriginal = nil

    if mouse then
        pcall(function()
            if mouse.TargetFilter == character then
                mouse.TargetFilter = previousTargetFilter
            end
        end)
    end

    unlockBombActivation()

    task.spawn(function()
        RunService.Heartbeat:Wait()
        pcall(function()
            if bombTool.Parent == character then
                humanoid:UnequipTools()
            end
            RunService.Heartbeat:Wait()
            if bombTool.Parent == character then
                local backpack = player:FindFirstChild("Backpack")
                if backpack then
                    bombTool.Parent = backpack
                end
            end
        end)
    end)

    cleanupDetection()
    if activationConnection then
        activationConnection:Disconnect()
    end

    if not bombPart then
        bombPart = findNearbyBombPart(character, bombTool, targetPosition)
        if not bombPart then
            bombPart = findNearbyBombPart(character, bombTool, throwOrigin)
        end
    end

    armBombBounce(character, humanoid, rootPart, bombPart, targetPosition, bombTool)

    task.spawn(function()
        local placementDeadline = os.clock() + Config.BOMB_BOUNCE_TRACK_TIME

        while os.clock() < placementDeadline do
            if not bombPart then
                bombPart = findNearbyBombPart(character, bombTool, targetPosition)
                if not bombPart then
                    bombPart = findNearbyBombPart(character, bombTool, throwOrigin)
                end
            end

            if bombPart and bombPart.Parent then
                if not directRemoteLaunch then
                    placeBombAtTarget(bombPart, character, targetPosition)
                end
                break
            end

            RunService.Heartbeat:Wait()
        end

    end)

    if mouse then
        task.delay(0.08, clearBombMouseOverride)
    end

    finishBombCooldown()
end

cancelPendingBombJump = function()
    if not pendingBombJump then
        local preTool = preEquippedBombTool
        local preWasEquipped = preEquippedBombWasEquipped
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        releaseScriptEquippedBomb(preTool, character, humanoid, preWasEquipped)
        clearPreEquippedBomb()
        return
    end

    pendingBombSequenceGeneration += 1
    local bombTool = pendingBombTool
    local character = pendingBombCharacter
    local humanoid = pendingBombHumanoid
    local wasEquipped = pendingBombWasEquipped
    local wasToggle = pendingBombWasToggle

    disconnectPendingBombWatchers()

    pendingBombJump = false
    pendingBombTool = nil
    pendingBombCharacter = nil
    pendingBombHumanoid = nil
    pendingBombRootPart = nil
    pendingBombWasToggle = false
    pendingBombEquipDeadline = 0
    pendingBombLaunchWindowReached = false
    pendingBombLaunchWaitDeadline = nil
    pendingBombStartedInFreefall = false

    pcall(function()
        if bombTool and bombTool.Parent then
            bombTool.ManualActivationOnly = pendingBombManualActivationOriginal
        end
    end)

    pendingBombManualActivationOriginal = nil
    unlockBombActivation()

    if fireflyTimingChildConnection then
        fireflyTimingChildConnection:Disconnect()
        fireflyTimingChildConnection = nil
    end
    if fireflyTimingRenderConnection then
        fireflyTimingRenderConnection:Disconnect()
        fireflyTimingRenderConnection = nil
    end
    fireflyTimingActive = false
    fireflyTimingStartedAt = 0
    fireflyTimingElapsed = nil
    cancelFireflyDoubleJump()

    releaseScriptEquippedBomb(bombTool, character, humanoid, wasEquipped)

    renderBombVisualState()
    statusLabel.Text = "Bomb Jump cancelled"
end

isBombJumpGrounded = function(character, humanoid, rootPart)
    if not character or not humanoid or not rootPart then
        return false
    end

    local state = humanoid:GetState()

    if state == Enum.HumanoidStateType.Jumping
        or state == Enum.HumanoidStateType.Freefall
        or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Climbing
        or state == Enum.HumanoidStateType.Swimming
        or state == Enum.HumanoidStateType.Seated
        or state == Enum.HumanoidStateType.PlatformStanding
        or state == Enum.HumanoidStateType.Dead
    then
        return false
    end

    if humanoid.FloorMaterial ~= Enum.Material.Air then
        return true
    end

    local footCenter = getFootData(character, rootPart)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {character}
    raycastParams.IgnoreWater = false

    local result = Workspace:Raycast(
        footCenter + Vector3.new(0, 0.25, 0),
        Vector3.new(0, -1.75, 0),
        raycastParams
    )

    return result ~= nil
end


local function getBombLaunchFallSpeed()
    return Config.BOMB_LAUNCH_FALL_SPEED
end

local function isBombLaunchMoment(humanoid, rootPart)
    if not humanoid or not rootPart or humanoid.Health <= 0 then
        return false
    end

    local state = humanoid:GetState()
    if state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.FallingDown then
        return false
    end

    local launchFallSpeed = getBombLaunchFallSpeed()
    local oneWayLatency, effectivePing = getBombOneWayLatency(LocalPlayer)

    if effectivePing > Config.BOMB_HIGH_PING_THRESHOLD then
        launchFallSpeed = math.max(
            0,
            launchFallSpeed - workspace.Gravity * oneWayLatency
        )
    end

    return rootPart.AssemblyLinearVelocity.Y <= -launchFallSpeed
end

local function beginPendingBombJump(isToggleMode, bombTool, character, humanoid, rootPart, wasEquipped, originalManualActivationOnly, showArmed, startedInFreefall)
    if pendingBombJump then
        return false
    end

    pendingBombSequenceGeneration += 1
    pendingBombTool = bombTool
    pendingBombCharacter = character
    pendingBombHumanoid = humanoid
    pendingBombRootPart = rootPart
    pendingBombWasEquipped = wasEquipped
    pendingBombManualActivationOriginal = originalManualActivationOnly
    pendingBombWasToggle = isToggleMode
    pendingBombEquipDeadline = os.clock() + math.max(5.0, Config.BOMB_EQUIP_TIMEOUT * 12)
    pendingBombLaunchWaitDeadline = nil
    pendingBombStartedInFreefall = startedInFreefall == true
        and BombStyleRuntime.usesInstantFreefallLaunch()
    pendingBombLaunchWindowReached = pendingBombStartedInFreefall
    pendingBombJump = true

    pcall(function()
        bombTool.ManualActivationOnly = true
    end)

    pendingBombStateConnection = humanoid.StateChanged:Connect(function(_, newState)
        if not pendingBombJump then
            return
        end

        if (newState == Enum.HumanoidStateType.Freefall or newState == Enum.HumanoidStateType.FallingDown) and isBombLaunchMoment(humanoid, rootPart) then
            pendingBombLaunchWindowReached = true
            task.defer(function()
                local canLaunch = selectedBombType == "Firefly Jar" or bombTool:FindFirstChild("Remote")
                if pendingBombJump and bombTool.Parent == character and canLaunch
                    and (not pendingBombStartedInFreefall or pendingBombEquipDeadline <= 0) then
                    launchPendingBombJump()
                end
            end)
        end
    end)

    pendingBombHeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not pendingBombJump then
            return
        end

        if not humanoid.Parent or humanoid.Health <= 0 or not character.Parent then
            cancelPendingBombJump()
            return
        end

        local launchMoment = isBombLaunchMoment(humanoid, rootPart)
        local groundedNow = isBombJumpGrounded(character, humanoid, rootPart)

        if launchMoment then
            pendingBombLaunchWindowReached = true
        elseif pendingBombLaunchWindowReached and groundedNow then
            if pendingBombStartedInFreefall then
                cancelPendingBombJump()
                statusLabel.Text = "Freefall launch window ended before equip"
                return
            end
            pendingBombLaunchWindowReached = false
        end

        if bombTool.Parent ~= character
            and pendingBombEquipDeadline > 0
            and os.clock() >= pendingBombEquipDeadline then
            cancelPendingBombJump()
            hasTriggeredBomb = false
            statusLabel.Text = "Bomb equip timed out; ready to retry"
            renderBombVisualState()
            return
        end

        if bombTool.Parent ~= character and launchMoment and not pendingBombStartedInFreefall then
            local wasOutOfHand = true

            pcall(function()
                humanoid:EquipTool(bombTool)
            end)

            if bombTool.Parent ~= character then
                pcall(function()
                    bombTool.Parent = character
                end)
            end

            if wasOutOfHand and bombTool.Parent == character then
                pcall(function()
                    bombTool.ManualActivationOnly = true
                end)
            end
        end

        local canLaunch = selectedBombType == "Firefly Jar" or bombTool:FindFirstChild("Remote")
        if bombTool.Parent == character and pendingBombLaunchWindowReached and not canLaunch then
            if not pendingBombLaunchWaitDeadline then
                pendingBombLaunchWaitDeadline = os.clock() + 0.75
            elseif os.clock() >= pendingBombLaunchWaitDeadline then
                cancelPendingBombJump()
                hasTriggeredBomb = false
                statusLabel.Text = "Bomb remote unavailable; ready to retry"
                renderBombVisualState()
                return
            end
        else
            pendingBombLaunchWaitDeadline = nil
        end

        if bombTool.Parent == character
            and pendingBombLaunchWindowReached
            and canLaunch
            and (not pendingBombStartedInFreefall or pendingBombEquipDeadline <= 0) then
            launchPendingBombJump()
        end
    end)

    if showArmed or bombUseMode == "Armed To Use Bomb" then
        updatePendingBombVisual()
    else
        renderBombVisualState()
    end

    return true
end

local function quickUseBomb(isToggleMode, armOnly)
    if selectedBombType == "Firefly Jar" then
        return activateFireflyJar()
    end

    if isWaitingTimerBomb then
        return
    end

    if pendingBombJump then
        return
    end

    local player = LocalPlayer
    local character = player and player.Character
    if not character then
        return
    end

    if isToggleMode and not isActiveBomb then
        local preTool = preEquippedBombTool
        local preWasEquipped = preEquippedBombWasEquipped
        local preHumanoid = character:FindFirstChildOfClass("Humanoid")
        releaseScriptEquippedBomb(preTool, character, preHumanoid, preWasEquipped)
        clearPreEquippedBomb()
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart or humanoid.Health <= 0 then
        return
    end

    local requestState = humanoid:GetState()
    local requestVerticalVelocity = rootPart.AssemblyLinearVelocity.Y
    local requestedDuringFreefall = BombStyleRuntime.usesInstantFreefallLaunch()
        and (
            requestState == Enum.HumanoidStateType.Freefall
            or requestState == Enum.HumanoidStateType.FallingDown
        )
        and requestVerticalVelocity <= 0.5

    if armOnly and not isBombJumpGrounded(character, humanoid, rootPart) then
        return
    end

    local backpack = player:FindFirstChild("Backpack")
    if not backpack then
        return
    end

    if lastKnownBombTool and lastKnownBombTool.Parent ~= character and lastKnownBombTool.Parent ~= backpack then
        lastKnownBombTool = nil
    end

    local bombTool
    if selectedBombType == "Firefly Jar" then
        bombTool = prepareRealFireflyJar(player)
    else
        bombTool = bombToolActivationReference
            or preEquippedBombTool
            or lastKnownBombTool
            or findSelectedBombTool(character)
            or findSelectedBombTool(backpack)

        if bombTool and bombTool.Parent ~= character and bombTool.Parent ~= backpack then
            bombTool = findSelectedBombTool(character)
                or findSelectedBombTool(backpack)
        end
    end

    if not bombTool and selectedBombType ~= "Firefly Jar" then
        local remote = resolveToyEvent()
        if remote then
            pcall(function()
                remote:InvokeServer(getBombToolName())
            end)

            local findTimeout = requestedDuringFreefall and math.max(Config.BOMB_EQUIP_TIMEOUT, 0.75) or Config.BOMB_EQUIP_TIMEOUT
            local findDeadline = os.clock() + findTimeout
            while not bombTool and os.clock() < findDeadline do
                bombTool = findSelectedBombTool(character) or findSelectedBombTool(backpack)
                if bombTool then
                    break
                end
                RunService.Heartbeat:Wait()
            end
        end
    end

    if not bombTool then
        statusLabel.Text = "Bomb tool not found: " .. getBombToolName()
        clearPreEquippedBomb()
        return
    end

    lastKnownBombTool = bombTool

    local wasEquipped = bombTool.Parent == character
    local originalManualActivationOnly = nil

    pcall(function()
        originalManualActivationOnly = bombTool.ManualActivationOnly
    end)

    if not beginPendingBombJump(
        isToggleMode,
        bombTool,
        character,
        humanoid,
        rootPart,
        wasEquipped,
        originalManualActivationOnly,
        armOnly,
        requestedDuringFreefall
    ) then
        clearPreEquippedBomb()
        return
    end

    if wasEquipped then
        clearPreEquippedBomb()
        pendingBombEquipDeadline = 0
    end

    if not wasEquipped then
        local equipDeadline = os.clock() + math.max(Config.BOMB_EQUIP_TIMEOUT, 2.50)
        while bombTool.Parent ~= character and os.clock() < equipDeadline and pendingBombJump do
            pcall(function()
                humanoid:EquipTool(bombTool)
            end)
            if bombTool.Parent ~= character then
                pcall(function()
                    bombTool.Parent = character
                end)
            end
            RunService.Heartbeat:Wait()
        end

        if not pendingBombJump then
            if bombTool.Parent == character then
                pcall(function()
                    humanoid:UnequipTools()
                end)
            end
            return
        end

        if bombTool.Parent == character then
            pendingBombEquipDeadline = 0
            clearPreEquippedBomb()
            if not pendingBombStartedInFreefall then
                RunService.RenderStepped:Wait()
            end
        end
    end

    if bombTool.Parent ~= character and pendingBombJump then
        pcall(function()
            humanoid:EquipTool(bombTool)
        end)
        if bombTool.Parent ~= character then
            pcall(function()
                bombTool.Parent = character
            end)
        end
        RunService.Heartbeat:Wait()
        if bombTool.Parent == character then
            pendingBombEquipDeadline = 0
            clearPreEquippedBomb()
        end
    end

    if bombTool.Parent ~= character then
        cancelPendingBombJump()
        return
    end

    if humanoid.Health <= 0 or not character.Parent then
        cancelPendingBombJump()
        return
    end

    if isToggleMode and bombUseMode == "Toggle To Use Bomb" and not isActiveBomb then
        cancelPendingBombJump()
        return
    end

    if pendingBombJump
        and pendingBombStartedInFreefall
        and pendingBombLaunchWindowReached
        and bombTool.Parent == character then
        local currentState = humanoid:GetState()
        if currentState == Enum.HumanoidStateType.Freefall
            or currentState == Enum.HumanoidStateType.FallingDown then
            launchPendingBombJump()
        end
    end
end

local function setToggleReady(value, armedMode)
    if armedMode then
        isArmedBomb = value
    else
        isActiveBomb = value
    end

    saveBombSettings()
    renderBombVisualState()

    if not value or selectedBombType == "Firefly Jar" then
        return
    end

    local requestedMode = armedMode and "Armed To Use Bomb" or "Toggle To Use Bomb"
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not character or not humanoid or humanoid.Health <= 0 or not backpack then
        return
    end

    task.spawn(function()
        local function modeStillReady()
            return character == LocalPlayer.Character
                and not isWaitingTimerBomb
                and selectedBombType ~= "Firefly Jar"
                and bombUseMode == requestedMode
                and ((armedMode and isArmedBomb) or (not armedMode and isActiveBomb))
                and humanoid.Parent ~= nil
                and humanoid.Health > 0
        end

        if not modeStillReady() then
            return
        end

        local bombTool = bombToolActivationReference
            or preEquippedBombTool
            or lastKnownBombTool
            or findSelectedBombTool(character)
            or findSelectedBombTool(backpack)

        if bombTool and bombTool.Parent ~= character and bombTool.Parent ~= backpack then
            bombTool = findSelectedBombTool(character) or findSelectedBombTool(backpack)
        end

        if not bombTool then
            local remote = resolveToyEvent()
            if remote then
                pcall(function()
                    remote:InvokeServer(getBombToolName())
                end)
            end
        end

        local findDeadline = os.clock() + math.max(Config.BOMB_EQUIP_TIMEOUT, 0.50)
        while not bombTool and os.clock() < findDeadline do
            if not modeStillReady() then
                return
            end
            bombTool = findSelectedBombTool(character) or findSelectedBombTool(backpack)
            if not bombTool then
                RunService.Heartbeat:Wait()
            end
        end

        if not bombTool then
            if modeStillReady() then
                statusLabel.Text = "Bomb tool not found: " .. getBombToolName()
            end
            return
        end

        if not modeStillReady() then
            return
        end

        lastKnownBombTool = bombTool
        if preEquippedBombTool ~= bombTool then
            preEquippedBombWasEquipped = bombTool.Parent == character
            preEquippedBombTool = bombTool
        end

        if bombTool.Parent ~= character then
            requestFastBombEquip(humanoid, character, bombTool)
        end
    end)
end

bombButton.Activated:Connect(function()
    if movedBomb or bombPressWasDragged or isWaitingTimerBomb then
        return
    end

    if bombUseMode == "Toggle To Use Bomb" and isActiveBomb then
        setToggleReady(false)
        hasTriggeredBomb = false
        cancelPendingBombJump()
        clearPreEquippedBomb()
        unlockBombActivation()
        bombActionInProgress = false
        return
    end

    if bombUseMode == "Armed To Use Bomb" and (isArmedBomb or pendingBombJump) then
        isArmedBomb = false
        cancelPendingBombJump()
        clearPreEquippedBomb()
        unlockBombActivation()
        renderBombVisualState()
        return
    end

    if bombActionInProgress then
        return
    end

    if selectedBombType == "Firefly Jar" then
        bombActionInProgress = true
        task.defer(function()
            pcall(function()
                activateFireflyJar()
            end)
            bombActionInProgress = false
            bombPressReleased = true
            bombPressInput = nil
            bombPressWasDragged = false
        end)
        return
    end

    if bombUseMode == "Toggle To Use Bomb" then
        setToggleReady(true)
        hasTriggeredBomb = false
        return
    end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local grounded = character and humanoid and rootPart and isBombJumpGrounded(character, humanoid, rootPart)

    if bombUseMode == "Click To Use Bomb" and grounded == true then
        statusLabel.Text = "Jump first to use Bomb Jump"
        return
    end

    local armOnly = bombUseMode == "Armed To Use Bomb" and grounded == true

    if armOnly then
        setToggleReady(true, true)
        hasTriggeredBomb = false
        return
    end

    bombActionInProgress = true
    task.defer(function()
        pcall(function()
            quickUseBomb(false, false)
        end)
        bombActionInProgress = false
        bombPressReleased = true
        bombPressInput = nil
        bombPressWasDragged = false
    end)
end)
local function setupCharacter(character)
    local humanoid = character:WaitForChild("Humanoid")
    local freefallAutoConnection

    humanoid.Died:Connect(function()
        if freefallAutoConnection then
            freefallAutoConnection:Disconnect()
            freefallAutoConnection = nil
        end
        isArmedBomb = false
        cancelPendingBombJump()
        unlockBombActivation()
        resetBombCooldown()
        bombActionInProgress = false
        bombPressReleased = true
        bombPressInput = nil
        bombPressWasDragged = false
    end)

    humanoid.StateChanged:Connect(function(_, state)
        local persistentMode = bombUseMode == "Toggle To Use Bomb"
            or (bombUseMode == "Armed To Use Bomb" and isArmedBomb)

        if state == Enum.HumanoidStateType.Landed and persistentMode and not isWaitingTimerBomb then
            hasTriggeredBomb = false
        end

        if not persistentMode then
            return
        end

        local modeActive = (bombUseMode == "Toggle To Use Bomb" and isActiveBomb)
            or (bombUseMode == "Armed To Use Bomb" and isArmedBomb)

        if not modeActive or hasTriggeredBomb or isWaitingTimerBomb then
            return
        end

        if state == Enum.HumanoidStateType.Jumping then
            if not bombActionInProgress and not pendingBombJump then
                hasTriggeredBomb = true
                bombActionInProgress = true

                task.defer(function()
                    pcall(function()
                        quickUseBomb(bombUseMode == "Toggle To Use Bomb", false)
                    end)

                    bombActionInProgress = false
                end)
            end
        end
    end)

    freefallAutoConnection = RunService.Heartbeat:Connect(function()
        if character ~= LocalPlayer.Character or not character.Parent or not humanoid.Parent or humanoid.Health <= 0 then
            if freefallAutoConnection then
                freefallAutoConnection:Disconnect()
                freefallAutoConnection = nil
            end
            return
        end

        if not BombStyleRuntime.usesInstantFreefallLaunch() then
            return
        end

        local modeActive = (bombUseMode == "Toggle To Use Bomb" and isActiveBomb)
            or (bombUseMode == "Armed To Use Bomb" and isArmedBomb)
        if not modeActive or hasTriggeredBomb or isWaitingTimerBomb or bombActionInProgress or pendingBombJump then
            return
        end

        local state = humanoid:GetState()
        if state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.FallingDown then
            return
        end

        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart or rootPart.AssemblyLinearVelocity.Y > -0.5 then
            return
        end

        hasTriggeredBomb = true
        bombActionInProgress = true
        task.defer(function()
            pcall(function()
                quickUseBomb(bombUseMode == "Toggle To Use Bomb", false)
            end)
            bombActionInProgress = false
        end)
    end)
end

if LocalPlayer.Character then
    task.defer(setupCharacter, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(function(character)
    resetBombCooldown()
    setupCharacter(character)
end)

statusLabel.Text = resolveToyEvent() and "Ready" or "Ready: ReplicateToy unavailable"
updateBombVisuals()
