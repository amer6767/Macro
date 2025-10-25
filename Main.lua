-- This is the COMBINED Macro Script
-- Execute this single file in Delta.
-- Key system and module loading have been removed.

-- --- Wait for Services ---
while not (game and game.GetService and game.HttpGet) do
    wait(0.05)
end

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local workspace = workspace

-- Wait for LocalPlayer to exist
local player = Players.LocalPlayer
while not player do
    RunService.Heartbeat:Wait()
    player = Players.LocalPlayer
end

local mouse = player:GetMouse()

-- --- Helper ---
local function sendNotification(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = 3})
    end)
end

-- --- START OF UI_Module.lua CODE ---

local FONT_MAIN = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamBold

-- --- Main ScreenGui ---
-- 'mainGui' will be a global variable in the loadstring environment.
mainGui = Instance.new("ScreenGui")
mainGui.Name = "MacroV2GUI"
mainGui.IgnoreGuiInset = true
mainGui.ResetOnSpawn = false
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
mainGui.Parent = CoreGui

-- --- Main Frame ---
mainFrame = Instance.new("Frame", mainGui)
mainFrame.Name = "MacroFrame" -- Give it a name to wait for
mainFrame.Size = UDim2.new(0, 260, 0, 360)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Visible = false -- Core.lua will make this visible
local frameCorner = Instance.new("UICorner", mainFrame)
frameCorner.CornerRadius = UDim.new(0, 12)

dragLayer = Instance.new("Frame", mainFrame)
dragLayer.Size = UDim2.new(1, 0, 0, 40)
dragLayer.BackgroundTransparency = 1
dragLayer.ZIndex = 1
dragLayer.Active = true

local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "Macro V2"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = FONT_BOLD
title.TextSize = 22
title.ZIndex = 2

-- --- Tab Bar ---
tabBar = Instance.new("Frame", mainFrame)
tabBar.Size = UDim2.new(1, 0, 0, 40)
tabBar.Position = UDim2.new(0, 0, 0, 40)
tabBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)

tabAutoClicker = Instance.new("TextButton", tabBar)
tabAutoClicker.Size = UDim2.new(0, 75, 1, 0)
tabAutoClicker.Text = "Auto"
tabAutoClicker.Font = FONT_MAIN
tabAutoClicker.TextSize = 14
tabAutoClicker.TextColor3 = Color3.new(1, 1, 1)
tabAutoClicker.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
local tabAutoCorner = Instance.new("UICorner", tabAutoClicker)
tabAutoCorner.CornerRadius = UDim.new(0, 4)

tabRecorder = Instance.new("TextButton", tabBar)
tabRecorder.Size = UDim2.new(0, 75, 1, 0)
tabRecorder.Position = UDim2.new(0, 75, 0, 0)
tabRecorder.Text = "Record"
tabRecorder.Font = FONT_MAIN
tabRecorder.TextSize = 14
tabRecorder.TextColor3 = Color3.new(1, 1, 1)
tabRecorder.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
local tabRecordCorner = Instance.new("UICorner", tabRecorder)
tabRecordCorner.CornerRadius = UDim.new(0, 4)

tabSettings = Instance.new("TextButton", tabBar)
tabSettings.Size = UDim2.new(0, 75, 1, 0)
tabSettings.Position = UDim2.new(0, 150, 0, 0)
tabSettings.Text = "Settings"
tabSettings.Font = FONT_MAIN
tabSettings.TextSize = 14
tabSettings.TextColor3 = Color3.new(1, 1, 1)
tabSettings.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
local tabSettingsCorner = Instance.new("UICorner", tabSettings)
tabSettingsCorner.CornerRadius = UDim.new(0, 4)

-- --- Content Areas ---
contentArea = Instance.new("Frame", mainFrame)
contentArea.Size = UDim2.new(1, 0, 1, -80)
contentArea.Position = UDim2.new(0, 0, 0, 80)
contentArea.BackgroundTransparency = 1

autoContent = Instance.new("Frame", contentArea)
autoContent.Size = UDim2.new(1, 0, 1, 0)
autoContent.BackgroundTransparency = 1
autoContent.Visible = true -- Will be controlled by Core.lua

recordContent = Instance.new("Frame", contentArea)
recordContent.Size = UDim2.new(1, 0, 1, 0)
recordContent.BackgroundTransparency = 1
recordContent.Visible = false

settingsContent = Instance.new("Frame", contentArea)
settingsContent.Size = UDim2.new(1, 0, 1, 0)
settingsContent.BackgroundTransparency = 1
settingsContent.Visible = false

-- --- Button Factory ---
local function createButton(text, posY, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.85, 0, 0, 30)
    btn.Position = UDim2.new(0.075, 0, 0, posY)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = FONT_MAIN
    btn.TextSize = 16
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    btn.BorderSizePixel = 0
    btn.ZIndex = 3
    btn.Parent = parent
    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 6)
    return btn
end

-- --- Auto Tab Content ---
btnAutoClicker = createButton("Auto Clicker: OFF", 10, autoContent)
btnSetPosition = createButton("Set Position", 50, autoContent)
lblInterval = Instance.new("TextBox", autoContent)
lblInterval.Size = UDim2.new(0.85, 0, 0, 30)
lblInterval.Position = UDim2.new(0.075, 0, 0, 90)
lblInterval.PlaceholderText = "Click Interval (sec)"
lblInterval.Text = "0.2" -- Default
lblInterval.Font = FONT_MAIN
lblInterval.TextSize = 14
lblInterval.TextColor3 = Color3.fromRGB(255, 255, 255)
lblInterval.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
lblInterval.BorderSizePixel = 0
local lblIntervalCorner = Instance.new("UICorner", lblInterval)
lblIntervalCorner.CornerRadius = UDim.new(0, 6)

-- --- Record Tab Content ---
btnStartRecording = createButton("Start Recording", 10, recordContent)
btnReplayClicks = createButton("Replay Clicks", 50, recordContent)
btnReplayLoop = createButton("Replay Loop: OFF", 90, recordContent)

replayCountInput = Instance.new("TextBox", recordContent)
replayCountInput.Size = UDim2.new(0.85, 0, 0, 30)
replayCountInput.Position = UDim2.new(0.075, 0, 0, 130)
replayCountInput.PlaceholderText = "Replay Amount (default 1)"
replayCountInput.Text = "1"
replayCountInput.Font = FONT_MAIN
replayCountInput.TextSize = 16
replayCountInput.TextColor3 = Color3.fromRGB(255, 255, 255)
replayCountInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
replayCountInput.BorderSizePixel = 0
replayCountInput.ZIndex = 3
local replayCorner = Instance.new("UICorner", replayCountInput)
replayCorner.CornerRadius = UDim.new(0, 6)

-- --- Settings Tab Content ---
offsetXInput = Instance.new("TextBox", settingsContent)
offsetXInput.Size = UDim2.new(0.85, 0, 0, 30)
offsetXInput.Position = UDim2.new(0.075, 0, 0, 10)
offsetXInput.PlaceholderText = "Set X Offset (px or % e.g. 10 or 2%)"
offsetXInput.Text = "0"
offsetXInput.Font = FONT_MAIN
offsetXInput.TextSize = 16
offsetXInput.TextColor3 = Color3.fromRGB(255, 255, 255)
offsetXInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
offsetXInput.BorderSizePixel = 0
offsetXInput.ClearTextOnFocus = false
offsetXInput.ZIndex = 3
local offsetXCorner = Instance.new("UICorner", offsetXInput)
offsetXCorner.CornerRadius = UDim.new(0, 6)

offsetYInput = Instance.new("TextBox", settingsContent)
offsetYInput.Size = UDim2.new(0.85, 0, 0, 30)
offsetYInput.Position = UDim2.new(0.075, 0, 0, 50)
offsetYInput.PlaceholderText = "Set Y Offset (px or % e.g. -5 or -1%)"
offsetYInput.Text = "0"
offsetYInput.Font = FONT_MAIN
offsetYInput.TextSize = 16
offsetYInput.TextColor3 = Color3.fromRGB(255, 255, 255)
offsetYInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
offsetYInput.BorderSizePixel = 0
offsetYInput.ClearTextOnFocus = false
offsetYInput.ZIndex = 3
local offsetYCorner = Instance.new("UICorner", offsetYInput)
offsetYCorner.CornerRadius = UDim.new(0, 6)

swipeCurveInput = Instance.new("TextBox", settingsContent)
swipeCurveInput.Size = UDim2.new(0.85, 0, 0, 30)
swipeCurveInput.Position = UDim2.new(0.075, 0, 0, 90)
swipeCurveInput.PlaceholderText = "Swipe Curvature (0..50%)"
swipeCurveInput.Text = "0" -- Default
swipeCurveInput.Font = FONT_MAIN
swipeCurveInput.TextSize = 16
swipeCurveInput.TextColor3 = Color3.fromRGB(255, 255, 255)
swipeCurveInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
swipeCurveInput.BorderSizePixel = 0
swipeCurveInput.ClearTextOnFocus = false
swipeCurveInput.ZIndex = 3
local swipeCorner = Instance.new("UICorner", swipeCurveInput)
swipeCorner.CornerRadius = UDim.new(0, 6)

btnApplyOffsets = createButton("Apply Offsets & Swipe Curve", 130, settingsContent)

-- --- Toggle Button ---
toggleGuiBtn = Instance.new("TextButton", mainGui)
toggleGuiBtn.Size = UDim2.new(0, 70, 0, 30)
toggleGuiBtn.Position = UDim2.new(0, 10, 0, 70)
toggleGuiBtn.Text = "Hide"
toggleGuiBtn.Font = FONT_MAIN
toggleGuiBtn.TextSize = 14
toggleGuiBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
toggleGuiBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleGuiBtn.ZIndex = 1000
toggleGuiBtn.Visible = false -- Core.lua will make this visible
toggleGuiBtn.Active = true
local toggleCorner = Instance.new("UICorner", toggleGuiBtn)
toggleCorner.CornerRadius = UDim.new(0, 6)

-- --- Draggability ---
local function makeDraggable(guiObject, dragHandle)
    local dragging = false
    local dragStartMousePos
    local objectStartPos

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStartMousePos = UserInputService:GetMouseLocation()
            objectStartPos = guiObject.Position
        end
    end)

    dragHandle.InputChanged:Connect(function(changedInput)
        if not dragging then return end
        if changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch then
            local currentMousePos = UserInputService:GetMouseLocation()
            local delta = currentMousePos - dragStartMousePos
            guiObject.Position = UDim2.new(
                objectStartPos.X.Scale, objectStartPos.X.Offset + delta.X,
                objectStartPos.Y.Scale, objectStartPos.Y.Offset + delta.Y
            )
        end
    end)

    dragHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

makeDraggable(mainFrame, dragLayer)
makeDraggable(toggleGuiBtn, toggleGuiBtn)

-- --- END OF UI_Module.lua CODE ---


-- --- START OF Core_Module.lua CODE ---

-- --- Config ---
local MIN_CLICK_HOLD_DURATION = 0.05
local SWIPE_MIN_PIXELS = 8
local SWIPE_SAMPLE_FPS = 60
local SWIPE_CURVATURE_DEFAULT = 0.0
local SWIPE_EASING = "easeInOutQuad"

-- --- State Variables ---
local autoClickEnabled = false
local clickInterval = 0.2
local clickPosition = Vector2.new(500, 500)
local waitingForPosition = false

local isRecording = false
local recordedActions = {}
local recordStartTime = 0
local recordConnections = {}

local isReplaying = false
local replayCount = 1
local currentReplayThread = nil

local isReplayingLoop = false
local currentReplayLoopThread = nil

local activeXOffsetRaw = { mode = "px", value = 0 }
local activeYOffsetRaw = { mode = "px", value = 0 }

local guiHidden = false
local positionSetConnection = nil

-- --- task Shim ---
if type(task) ~= "table" or type(task.spawn) ~= "function" then
    task = {
        spawn = function(func)
            local co = coroutine.create(func)
            coroutine.resume(co)
            return co
        end,
        wait = function(time)
            local start = tick()
            while tick() - start < (time or 0) do
                RunService.Heartbeat:Wait()
            end
        end,
        delay = function(time, func)
            task.spawn(function()
                task.wait(time)
                func()
            end)
        end,
        cancel = function(co)
            if type(co) == "thread" then
                -- no safe cancel; leave nil
            end
        end
    }
end

-- --- Helper Functions ---
-- (sendNotification is already defined at the top)

local function selectTab(tabName)
    autoContent.Visible = tabName == "auto"
    recordContent.Visible = tabName == "record"
    settingsContent.Visible = tabName == "settings"
    tabAutoClicker.BackgroundColor3 = tabName == "auto" and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(50, 50, 50)
    tabRecorder.BackgroundColor3 = tabName == "record" and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(50, 50, 50)
    tabSettings.BackgroundColor3 = tabName == "settings" and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(50, 50, 50)
end

local function getViewportSize()
    local cam = workspace.CurrentCamera
    if cam and cam.ViewportSize then
        return cam.ViewportSize
    end
    return Vector2.new(1920, 1080)
end

local function toNormalized(pos)
    local vs = getViewportSize()
    if vs.X == 0 or vs.Y == 0 then return Vector2.new(0,0) end
    return Vector2.new(pos.X / vs.X, pos.Y / vs.Y)
end

local function fromNormalized(norm)
    local vs = getViewportSize()
    return Vector2.new(math.clamp(norm.X * vs.X, 0, vs.X), math.clamp(norm.Y * vs.Y, 0, vs.Y))
end

local function computePixelXOffset(raw)
    if raw.mode == "px" then
        return raw.value
    else
        return raw.value * getViewportSize().X
    end
end

local function computePixelYOffset(raw)
    if raw.mode == "px" then
        return raw.value
    else
        return raw.value * getViewportSize().Y
    end
end

-- --- VIM (Click Engine) ---
local VirtualInputManager
local vmAvailable do
    local success, result = pcall(function() 
        return game:GetService("VirtualInputManager") 
    end)
    vmAvailable = success
    if success then
        VirtualInputManager = result
    end
end

local function safeSendMouseMove(x, y)
    if vmAvailable then
        pcall(function() VirtualInputManager:SendMouseMoveEvent(x, y, game, 0) end)
    end
end

local function safeSendMouseButton(x, y, button, isDown)
    if vmAvailable then
        pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, button, isDown, game, 0) end)
    end
end

-- --- Easing ---
local EASINGS = {}
EASINGS.easeInOutQuad = function(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return -1 + (4 - 2 * t) * t
    end
end
local function applyEasing(name, t)
    return (EASINGS[name] and EASINGS[name](t)) or t
end

-- --- Simulation Functions (The "Engine") ---
local function simulateClick(pixelPos)
    if not pixelPos then return end
    local xOffset = computePixelXOffset(activeXOffsetRaw)
    local yOffset = computePixelYOffset(activeYOffsetRaw)
    local effectivePos = Vector2.new(pixelPos.X + xOffset, pixelPos.Y + yOffset)

    safeSendMouseMove(effectivePos.X, effectivePos.Y)
    for _ = 1, 3 do RunService.Heartbeat:Wait() end
    safeSendMouseButton(effectivePos.X, effectivePos.Y, 0, true)
    task.wait(MIN_CLICK_HOLD_DURATION)
    safeSendMouseButton(effectivePos.X, effectivePos.Y, 0, false)
end

local function simulateSwipe(startPixel, endPixel, duration, curvatureFraction)
    if not startPixel or not endPixel then return end
    local xOffset = computePixelXOffset(activeXOffsetRaw)
    local yOffset = computePixelYOffset(activeYOffsetRaw)
    local startPos = Vector2.new(startPixel.X + xOffset, startPixel.Y + yOffset)
    local endPos = Vector2.new(endPixel.X + xOffset, endPixel.Y + yOffset)

    local dx = endPos.X - startPos.X
    local dy = endPos.Y - startPos.Y
    local dist = math.sqrt(dx * dx + dy * dy)
    local steps = math.max(2, math.floor(math.max(0.02, duration) * SWIPE_SAMPLE_FPS))
    local perpX, perpY = 0, 0
    if curvatureFraction and curvatureFraction ~= 0 and dist > 0 then
        perpX = -dy / dist
        perpY = dx / dist
    end
    
    safeSendMouseMove(startPos.X, startPos.Y)
    for _ = 1, 2 do RunService.Heartbeat:Wait() end
    safeSendMouseButton(startPos.X, startPos.Y, 0, true)

    for i = 1, steps do
        local t = i / steps
        local eased = applyEasing(SWIPE_EASING, t)
        local baseX = startPos.X + (endPos.X - startPos.X) * eased
        local baseY = startPos.Y + (endPos.Y - startPos.Y) * eased
        local curveAmount = (curvatureFraction or 0) * dist * (1 - math.abs(2 * t - 1))
        local x = baseX + perpX * curveAmount
        local y = baseY + perpY * curveAmount
        safeSendMouseMove(x, y)
        RunService.Heartbeat:Wait()
    end

    safeSendMouseMove(endPos.X, endPos.Y)
    safeSendMouseButton(endPos.X, endPos.Y, 0, false)
end

-- --- Stop All ---
local function stopAllProcesses()
    -- This function needs to be defined *before* it's used
    -- So we declare it here, and define it properly after
    -- all the stop...() functions exist.
    
    -- Forward-declare functions to stop processes
    local stopAutoClicker_impl
    local stopRecording_impl
    local stopReplay_impl
    local stopReplayLoop_impl
    local stopSetPosition_impl

    -- Define the main function
    function stopAllProcesses()
        if stopAutoClicker_impl then stopAutoClicker_impl() end
        if stopRecording_impl then stopRecording_impl() end
        if stopReplay_impl then stopReplay_impl() end
        if stopReplayLoop_impl then stopReplayLoop_impl() end
        if stopSetPosition_impl then stopSetPosition_impl() end
    end
    
    -- Return a function to assign implementations
    return function(impls)
        stopAutoClicker_impl = impls.stopAutoClicker
        stopRecording_impl = impls.stopRecording
        stopReplay_impl = impls.stopReplay
        stopReplayLoop_impl = impls.stopReplayLoop
        stopSetPosition_impl = impls.stopSetPosition
    end
end

-- Create stopAllProcesses and get the 'assigner' function
local assignStopFunctions = stopAllProcesses()

-- --- Recording Logic ---
local activeInputs = {}
local function clearActiveInputs()
    for k in pairs(activeInputs) do activeInputs[k] = nil end
end

local function isOverOurGUI(pos)
    local x, y = math.floor(pos.X + 0.5), math.floor(pos.Y + 0.5)
    local success, result = pcall(function()
        local objs = UserInputService:GetGuiObjectsAtPosition(x, y)
        if #objs == 0 then return false end
        for _, o in ipairs(objs) do
            if o:IsDescendantOf(mainGui) then return true end
        end
    end)
    return success and result or false
end

local function stopRecording()
    if not isRecording then return end
    isRecording = false
    btnStartRecording.Text = "Start Recording"
    for k, conn in pairs(recordConnections) do
        if conn and conn.Disconnect then pcall(function() conn:Disconnect() end) end
    end
    recordConnections = {}
    clearActiveInputs()
end

local function startRecording()
    stopAllProcesses()
    isRecording = true
    recordedActions = {}
    recordStartTime = os.clock()
    btnStartRecording.Text = "Stop Recording"

    recordConnections["began"] = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not isRecording or gameProcessed then return end
        local ut = input.UserInputType
        if not (ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch) then return end
        local pos = input.Position and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
        if isOverOurGUI(pos) then return end
        activeInputs[input] = { startTime = os.clock(), startPos = pos, lastPos = pos, isDragging = false }
    end)

    recordConnections["changed"] = UserInputService.InputChanged:Connect(function(input)
        if not isRecording then return end
        local data = activeInputs[input]
        if not data then return end
        local pos = input.Position and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
        if not data.isDragging and (pos - data.startPos).Magnitude >= SWIPE_MIN_PIXELS then
            data.isDragging = true
        end
        data.lastPos = pos
    end)

    recordConnections["ended"] = UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if not isRecording then return end
        local data = activeInputs[input]
        if not data then return end
        local now = os.clock()
        local delay = now - recordStartTime
        recordStartTime = now
        local endPos = input.Position and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
        local moved = (endPos - data.startPos).Magnitude

        if data.isDragging or moved >= SWIPE_MIN_PIXELS then
            table.insert(recordedActions, {
                type = "swipe",
                startPixel = data.startPos,
                endPixel = endPos,
                duration = math.max(0.02, now - data.startTime),
                delay = delay
            })
        else
            table.insert(recordedActions, {
                type = "tap",
                pixelPos = data.startPos,
                delay = delay
            })
        end
        activeInputs[input] = nil
    end)
end

local function toggleRecording()
    if isRecording then stopRecording() else startRecording() end
end

-- --- Replay Logic ---
local function stopReplay()
    if not isReplaying then return end
    isReplaying = false
    if btnReplayClicks.Text ~= "Replay Clicks" then btnReplayClicks.Text = "Replay Clicks" end
    if currentReplayThread then
        task.cancel(currentReplayThread)
        currentReplayThread = nil
    end
end

local function doReplayActions(actionList)
    for _, act in ipairs(actionList) do
        if not isReplaying and not isReplayingLoop then break end
        if act.delay and act.delay > 0 then task.wait(act.delay) else RunService.Heartbeat:Wait() end
        if not isReplaying and not isReplayingLoop then break end

        if act.type == "tap" then
            simulateClick(act.pixelPos)
        elseif act.type == "swipe" then
            local curve = tonumber(swipeCurveInput.Text) or (SWIPE_CURVATURE_DEFAULT * 100)
            curve = math.clamp(curve, 0, 100) / 100
            simulateSwipe(act.startPixel, act.endPixel, act.duration or 0.12, curve)
        end
    end
end

local function toggleReplay()
    if isReplaying then stopReplay() return end
    if #recordedActions == 0 then
        sendNotification("Replay Failed", "No actions recorded yet.")
        return
    end
    stopAllProcesses()
    isReplaying = true
    local num = tonumber(replayCountInput.Text)
    replayCount = (num and num > 0) and math.floor(num) or 1
    replayCountInput.Text = tostring(replayCount)
    btnReplayClicks.Text = "Stop Replay"

    currentReplayThread = task.spawn(function()
        for i = 1, replayCount do
            if not isReplaying then break end
            btnReplayClicks.Text = string.format("Replaying (%d/%d)", i, replayCount)
            doReplayActions(recordedActions)
            if i < replayCount and isReplaying then task.wait(0.1) end
        end
        stopReplay()
    end)
end

-- --- Replay Loop ---
local function stopReplayLoop()
    if not isReplayingLoop then return end
    isReplayingLoop = false
    btnReplayLoop.Text = "Replay Loop: OFF"
    if currentReplayLoopThread then
        task.cancel(currentReplayLoopThread)
        currentReplayLoopThread = nil
    end
end

local function toggleReplayLoop()
    if isReplayingLoop then stopReplayLoop() return end
    if #recordedActions == 0 then
        sendNotification("Replay Failed", "No actions recorded yet.")
        return
    end
    stopAllProcesses()
    isReplayingLoop = true
    btnReplayLoop.Text = "Replay Loop: ON"
    currentReplayLoopThread = task.spawn(function()
        while isReplayingLoop do
            doReplayActions(recordedActions)
            if isReplayingLoop then task.wait(0.1) end
        end
    end)
end

-- --- Autoclicker Logic ---
local function stopAutoClicker()
    if not autoClickEnabled then return end
    autoClickEnabled = false
    btnAutoClicker.Text = "Auto Clicker: OFF"
end

local function toggleAutoClicker()
    if autoClickEnabled then
        stopAutoClicker()
        return
    end

    stopAllProcesses()
    autoClickEnabled = true
    btnAutoClicker.Text = "Auto Clicker: ON"
    
    task.spawn(function()
        local nextTime = tick()
        while autoClickEnabled do
            local interval = math.max(0.001, clickInterval)
            nextTime = nextTime + interval
            simulateClick(clickPosition)
            local waitTime = nextTime - tick()
            if waitTime > 0 then
                task.wait(waitTime)
            else
                RunService.Heartbeat:Wait()
                nextTime = tick() 
            end
        end
    end)
end

-- --- Set Position Logic ---
local function stopSetPosition()
    if not waitingForPosition then return end
    waitingForPosition = false
    if btnSetPosition.Text ~= "Set Position" then
        btnSetPosition.Text = "Set Position"
    end
    if positionSetConnection then
        local connToDisconnect = positionSetConnection
        positionSetConnection = nil
        task.spawn(function()
            pcall(function() connToDisconnect:Disconnect() end)
        end)
    end
end

local function setClickPosition()
    if waitingForPosition then
        stopSetPosition()
        return
    end
    
    stopAllProcesses()
    waitingForPosition = true
    btnSetPosition.Text = "Tap anywhere..."
    
    positionSetConnection = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if not waitingForPosition or gameProcessedEvent then return end
        local ut = input.UserInputType
        
        if (ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch) and input.UserInputState == Enum.UserInputState.Begin then
            local pos = input.Position and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
            if isOverOurGUI(pos) then return end
            
            clickPosition = pos
            stopSetPosition()
            
            btnSetPosition.Text = "Position Set!"
            task.delay(1, function()
                if btnSetPosition.Text == "Position Set!" then
                    btnSetPosition.Text = "Set Position"
                end
            end)
        end
    end)
end

-- --- Assign Stop Functions ---
assignStopFunctions({
    stopAutoClicker = stopAutoClicker,
    stopRecording = stopRecording,
    stopReplay = stopReplay,
    stopReplayLoop = stopReplayLoop,
    stopSetPosition = stopSetPosition
})


-- --- GUI Connections ---
btnAutoClicker.MouseButton1Click:Connect(function()
    local val = tonumber(lblInterval.Text)
    if val and val > 0 then
        clickInterval = val
    else
        lblInterval.Text = tostring(clickInterval)
    end
    toggleAutoClicker()
end)

btnSetPosition.MouseButton1Click:Connect(setClickPosition)
btnStartRecording.MouseButton1Click:Connect(toggleRecording)
btnReplayClicks.MouseButton1Click:Connect(toggleReplay)
btnReplayLoop.MouseButton1Click:Connect(toggleReplayLoop)

btnApplyOffsets.MouseButton1Click:Connect(function()
    local function parseOffsetInput(text)
        text = tostring(text or "")
        text = text:gsub("%s+", "")
        if text:match("%%$") then
            local num = tonumber(text:sub(1, -2))
            if num then return { mode = "pct", value = num / 100 } end
        else
            local num = tonumber(text)
            if num then return { mode = "px", value = num } end
        end
        return nil
    end

    local xRaw = parseOffsetInput(offsetXInput.Text)
    local yRaw = parseOffsetInput(offsetYInput.Text)
    local curve = tonumber(swipeCurveInput.Text)
    
    if xRaw and yRaw and curve ~= nil then
        activeXOffsetRaw = xRaw
        activeYOffsetRaw = yRaw
        local curveClamped = math.clamp(curve, 0, 100) / 100
        swipeCurveInput.Text = tostring(curveClamped * 100)
        
        sendNotification("Offsets Updated", ("X: %s, Y: %s, Curve: %.1f%%")
            :format(offsetXInput.Text, offsetYInput.Text, curveClamped*100))
    else
        sendNotification("Invalid Input", "Offsets must be numbers (px) or percent (e.g. 2%).")
        offsetXInput.Text = (activeXOffsetRaw.mode == "px") and tostring(activeXOffsetRaw.value) or tostring(activeXOffsetRaw.value * 100) .. "%"
        offsetYInput.Text = (activeYOffsetRaw.mode == "px") and tostring(activeYOffsetRaw.value) or tostring(activeYOffsetRaw.value * 100) .. "%"
    end
end)

toggleGuiBtn.MouseButton1Click:Connect(function()
    guiHidden = not guiHidden
    mainFrame.Visible = not guiHidden
    toggleGuiBtn.Text = guiHidden and "Show" or "Hide"
end)

-- Tab connections
tabAutoClicker.MouseButton1Click:Connect(function() selectTab("auto") end)
tabRecorder.MouseButton1Click:Connect(function() selectTab("record") end)
tabSettings.MouseButton1Click:Connect(function() selectTab("settings")end)

-- --- Initial State ---
selectTab("auto")
sendNotification("MacroV2 Loaded", vmAvailable and "VIM (Patched) Found" or "CRITICAL: VIM NOT Found")

-- Make GUI visible now that modules are loaded
mainFrame.Visible = true
toggleGuiBtn.Visible = true

-- --- END OF Core_Module.lua CODE ---
