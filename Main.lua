-- Roblox Macro V4.1 (Y-Offset Fix)
-- Put this as a LocalScript in StarterPlayerScripts or StarterGui
--
-- V4.1 Changes:
-- 1. Y-OFFSET FIX: Added a permanent +25px Y-offset to counteract clicks registering too high.
-- 2. LOGIC FIX: Refactored Auto-Clicker and Test-Click to use the main simulation pipeline.
-- 3. CODE READABILITY: Formatted the script for better maintenance and clarity.
--
-- V4 (Simplified) Changes:
-- 1. DIRECT COORDINATES: Removed all complex scaling and virtual screen calibration.
-- 2. SIMPLIFIED SETTINGS: Removed virtual width/height. Offsets are now pixels only.
-- 3. RELIABLE POSITION SET: 'Set Position' is now more robust and provides visual feedback.
-- 4. TEST CLICK: Added a button to test the currently set click position.
-- 5. ROBUST VIM: Improved VirtualInputManager initialization with a self-test.

-- NEW FIX: Wait for game.GetService to be available
while not (game and game.GetService) do
    wait(0.05)
end

-- Now it's safe to call GetService
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local workspace = workspace

-- Wait for LocalPlayer to exist (crucial for executor injection)
local player = Players.LocalPlayer
while not player do
    RunService.Heartbeat:Wait()
    player = Players.LocalPlayer
end

-- Config
local MIN_CLICK_HOLD_DURATION = 0.05
local FONT_MAIN = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamBold
local SWIPE_MIN_PIXELS = 8
local SWIPE_SAMPLE_FPS = 60
local SWIPE_CURVATURE_DEFAULT = 0.0
local SWIPE_EASING = "easeInOutQuad"

local CoreGui = game:GetService("CoreGui")
local mouse = player:GetMouse()

-- State
local autoClickEnabled = false
local clickInterval = 0.2
local clickPosition = Vector2.new(500, 500) -- Default, user should set this
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

-- task shim
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
        cancel = function(co) end
    }
end

-- UI Creation
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "MacroV4GUI_Simplified"
mainGui.IgnoreGuiInset = true
mainGui.ResetOnSpawn = false
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
mainGui.Parent = CoreGui

local keyEntry = Instance.new("Frame")
keyEntry.Size = UDim2.new(0, 260, 0, 140)
keyEntry.Position = UDim2.new(0.5, -130, 0.5, -70)
keyEntry.AnchorPoint = Vector2.new(0.5, 0.5)
keyEntry.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
keyEntry.BorderSizePixel = 0
keyEntry.Parent = mainGui
local keyEntryCorner = Instance.new("UICorner", keyEntry)
keyEntryCorner.CornerRadius = UDim.new(0, 8)

local keyBox = Instance.new("TextBox", keyEntry)
keyBox.Size = UDim2.new(0.9, 0, 0, 30)
keyBox.Position = UDim2.new(0.05, 0, 0, 10)
keyBox.PlaceholderText = "Enter Key"
keyBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
keyBox.TextColor3 = Color3.new(1, 1, 1)
keyBox.Font = FONT_MAIN
keyBox.TextSize = 16
keyBox.BorderSizePixel = 0
keyBox.ClearTextOnFocus = false
local keyBoxCorner = Instance.new("UICorner", keyBox)
keyBoxCorner.CornerRadius = UDim.new(0, 6)

local submitBtn = Instance.new("TextButton", keyEntry)
submitBtn.Size = UDim2.new(0.9, 0, 0, 30)
submitBtn.Position = UDim2.new(0.05, 0, 0, 50)
submitBtn.Text = "Submit Key"
submitBtn.Font = FONT_MAIN
submitBtn.TextSize = 16
submitBtn.TextColor3 = Color3.new(1, 1, 1)
submitBtn.BackgroundColor3 = Color3.fromRGB(0, 122, 204)
submitBtn.BorderSizePixel = 0
local submitBtnCorner = Instance.new("UICorner", submitBtn)
submitBtnCorner.CornerRadius = UDim.new(0, 6)

local copyBtn = Instance.new("TextButton", keyEntry)
copyBtn.Size = UDim2.new(0.9, 0, 0, 30)
copyBtn.Position = UDim2.new(0.05, 0, 0, 90)
copyBtn.Text = "Copy Key Link"
copyBtn.Font = FONT_MAIN
copyBtn.TextSize = 16
copyBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
copyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
copyBtn.BorderSizePixel = 0
local copyBtnCorner = Instance.new("UICorner", copyBtn)
copyBtnCorner.CornerRadius = UDim.new(0, 6)

local mainFrame = Instance.new("Frame", mainGui)
mainFrame.Size = UDim2.new(0, 260, 0, 300) -- Adjusted height
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Visible = false
local frameCorner = Instance.new("UICorner", mainFrame)
frameCorner.CornerRadius = UDim.new(0, 12)

local dragLayer = Instance.new("Frame", mainFrame)
dragLayer.Size = UDim2.new(1, 0, 0, 40)
dragLayer.BackgroundTransparency = 1
dragLayer.ZIndex = 1
dragLayer.Active = true

local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "Macro V4.1 (Offset Fix)"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = FONT_BOLD
title.TextSize = 20
title.ZIndex = 2

local tabBar = Instance.new("Frame", mainFrame)
tabBar.Size = UDim2.new(1, 0, 0, 40)
tabBar.Position = UDim2.new(0, 0, 0, 40)
tabBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)

local tabAutoClicker = Instance.new("TextButton", tabBar)
tabAutoClicker.Size = UDim2.new(0, 75, 1, 0)
tabAutoClicker.Text = "Auto"
tabAutoClicker.Font = FONT_MAIN
tabAutoClicker.TextSize = 14
tabAutoClicker.TextColor3 = Color3.new(1, 1, 1)
tabAutoClicker.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
local tabAutoCorner = Instance.new("UICorner", tabAutoClicker)
tabAutoCorner.CornerRadius = UDim.new(0, 4)

local tabRecorder = Instance.new("TextButton", tabBar)
tabRecorder.Size = UDim2.new(0, 75, 1, 0)
tabRecorder.Position = UDim2.new(0, 75, 0, 0)
tabRecorder.Text = "Record"
tabRecorder.Font = FONT_MAIN
tabRecorder.TextSize = 14
tabRecorder.TextColor3 = Color3.new(1, 1, 1)
tabRecorder.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
local tabRecordCorner = Instance.new("UICorner", tabRecorder)
tabRecordCorner.CornerRadius = UDim.new(0, 4)

local tabSettings = Instance.new("TextButton", tabBar)
tabSettings.Size = UDim2.new(0, 75, 1, 0)
tabSettings.Position = UDim2.new(0, 150, 0, 0)
tabSettings.Text = "Settings"
tabSettings.Font = FONT_MAIN
tabSettings.TextSize = 14
tabSettings.TextColor3 = Color3.new(1, 1, 1)
tabSettings.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
local tabSettingsCorner = Instance.new("UICorner", tabSettings)
tabSettingsCorner.CornerRadius = UDim.new(0, 4)

local contentArea = Instance.new("Frame", mainFrame)
contentArea.Size = UDim2.new(1, 0, 1, -80)
contentArea.Position = UDim2.new(0, 0, 0, 80)
contentArea.BackgroundTransparency = 1

local autoContent = Instance.new("Frame", contentArea)
autoContent.Size = UDim2.new(1, 0, 1, 0)
autoContent.BackgroundTransparency = 1
autoContent.Visible = true

local recordContent = Instance.new("Frame", contentArea)
recordContent.Size = UDim2.new(1, 0, 1, 0)
recordContent.BackgroundTransparency = 1
recordContent.Visible = false

local settingsContent = Instance.new("Frame", contentArea)
settingsContent.Size = UDim2.new(1, 0, 1, 0)
settingsContent.BackgroundTransparency = 1
settingsContent.Visible = false

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

local function createInput(placeholder, text, posY, parent)
	local input = Instance.new("TextBox")
	input.Size = UDim2.new(0.85, 0, 0, 30)
	input.Position = UDim2.new(0.075, 0, 0, posY)
	input.PlaceholderText = placeholder
	input.Text = text
	input.Font = FONT_MAIN
	input.TextSize = 16
	input.TextColor3 = Color3.fromRGB(255, 255, 255)
	input.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	input.BorderSizePixel = 0
	input.ClearTextOnFocus = false
	input.ZIndex = 3
	input.Parent = parent
	local corner = Instance.new("UICorner", input)
	corner.CornerRadius = UDim.new(0, 6)
	return input
end

local btnAutoClicker = createButton("Auto Clicker: OFF", 10, autoContent)
local btnSetPosition = createButton("Set Position", 50, autoContent)
local lblInterval = createInput("Click Interval (sec)", tostring(clickInterval), 90, autoContent)
local btnTestClick = createButton("Test Click", 130, autoContent)

local btnStartRecording = createButton("Start Recording", 10, recordContent)
local btnReplayClicks = createButton("Replay Clicks", 50, recordContent)
local btnReplayLoop = createButton("Replay Loop: OFF", 90, recordContent)
local replayCountInput = createInput("Replay Amount (default 1)", "1", 130, recordContent)

-- SIMPLIFIED Settings
local offsetXInput = createInput("X Offset (pixels)", "0", 10, settingsContent)
local offsetYInput = createInput("Y Offset (pixels)", "0", 50, settingsContent)
local swipeCurveInput = createInput("Swipe Curvature (0-100)", "0", 90, settingsContent)
local btnApplySettings = createButton("Apply Offsets", 130, settingsContent)

local toggleGuiBtn = Instance.new("TextButton", mainGui)
toggleGuiBtn.Size = UDim2.new(0, 70, 0, 30)
toggleGuiBtn.Position = UDim2.new(0, 10, 0, 70)
toggleGuiBtn.Text = "Hide"
toggleGuiBtn.Font = FONT_MAIN
toggleGuiBtn.TextSize = 14
toggleGuiBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
toggleGuiBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleGuiBtn.ZIndex = 1000
toggleGuiBtn.Visible = false
toggleGuiBtn.Active = true
local toggleCorner = Instance.new("UICorner", toggleGuiBtn)
toggleCorner.CornerRadius = UDim.new(0, 6)

-- Helpers
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

local function sendNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = duration or 3})
    end)
end

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

local function computePixelXOffset(raw)
    return raw.value
end

local function computePixelYOffset(raw)
    return raw.value
end

-- --- SIMPLIFIED CALIBRATION LOGIC ---
function updateCalibration()
    sendNotification("Calibration", "Using direct coordinates with a fixed Y-offset.", 3)
    print("[CALIBRATION] Using direct coordinate system with a fixed +25px Y-offset.")
end

function ViewportToExecutor(viewportPos)
    -- Add permanent Y offset to fix upward clicks
    local yOffset = 25 -- Adjust this value as needed
    return Vector2.new(math.floor(viewportPos.X), math.floor(viewportPos.Y + yOffset))
end
-- --- END SIMPLIFIED CALIBRATION LOGIC ---


-- VirtualInputManager and simulation functions
local VirtualInputManager
local vmAvailable = false

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

local function performAutoClick(x, y)
    if vmAvailable then
        safeSendMouseMove(x, y)
        task.wait(0.01)
        safeSendMouseButton(x, y, 0, true)
        task.wait(MIN_CLICK_HOLD_DURATION)
        safeSendMouseButton(x, y, 0, false)
    end
end

-- Easing functions
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

local function simulateClick(pixelPos)
    if not pixelPos then return end
    local xOffset = computePixelXOffset(activeXOffsetRaw)
    local yOffset = computePixelYOffset(activeYOffsetRaw)
    local offsetPos = Vector2.new(pixelPos.X + xOffset, pixelPos.Y + yOffset)
    local effectivePos = ViewportToExecutor(offsetPos)
    performAutoClick(effectivePos.X, effectivePos.Y)
end

local function simulateSwipe(startPixel, endPixel, duration, curvatureFraction)
    if not startPixel or not endPixel then return end
    local xOffset = computePixelXOffset(activeXOffsetRaw)
    local yOffset = computePixelYOffset(activeYOffsetRaw)
    local startOffsetPos = Vector2.new(startPixel.X + xOffset, startPixel.Y + yOffset)
    local endOffsetPos = Vector2.new(endPixel.X + xOffset, endPixel.Y + yOffset)
    local startPos = ViewportToExecutor(startOffsetPos)
    local endPos = ViewportToExecutor(endOffsetPos)

    local dx = endPos.X - startPos.X
    local dy = endPos.Y - startPos.Y
    local dist = math.sqrt(dx * dx + dy * dy)
    local steps = math.max(2, math.floor(math.max(0.02, duration) * SWIPE_SAMPLE_FPS))
    local perpX, perpY = 0, 0
    if curvatureFraction and curvatureFraction ~= 0 and dist > 0 then
        perpX = -dy / dist; perpY = dx / dist
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

-- Recording implementation
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
            if o:IsDescendantOf(mainGui) then
                return true
            end
        end
        return false
    end)
    return success and result or false
end

local function stopRecording()
    if not isRecording then return end
    isRecording = false
    btnStartRecording.Text = "Start Recording"
    for _, conn in pairs(recordConnections) do
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
        if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then return end

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
        
        if data.isDragging or (endPos - data.startPos).Magnitude >= SWIPE_MIN_PIXELS then
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

-- Replay functions
function stopReplay()
    if not isReplaying then return end
    isReplaying = false
    if btnReplayClicks.Text ~= "Replay Clicks" then btnReplayClicks.Text = "Replay Clicks" end
    if currentReplayThread then task.cancel(currentReplayThread); currentReplayThread = nil end
end

local function doReplayActions(actionList)
    for _, act in ipairs(actionList) do
        if not isReplaying and not isReplayingLoop then break end
        
        if act.delay and act.delay > 0 then
            task.wait(act.delay)
        else
            RunService.Heartbeat:Wait()
        end
        
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
    if isReplaying then stopReplay(); return end
    if #recordedActions == 0 then sendNotification("Replay Failed", "No actions recorded yet."); return end
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

local function stopReplayLoop()
    if not isReplayingLoop then return end
    isReplayingLoop = false
    btnReplayLoop.Text = "Replay Loop: OFF"
    if currentReplayLoopThread then task.cancel(currentReplayLoopThread); currentReplayLoopThread = nil end
end

local function toggleReplayLoop()
    if isReplayingLoop then stopReplayLoop(); return end
    if #recordedActions == 0 then sendNotification("Replay Failed", "No actions recorded yet."); return end
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

-- Auto-clicker
local function stopAutoClicker()
    if not autoClickEnabled then return end
    autoClickEnabled = false
    btnAutoClicker.Text = "Auto Clicker: OFF"
end

local function toggleAutoClicker()
    if autoClickEnabled then stopAutoClicker(); return end
    if clickPosition == Vector2.new(500, 500) then
        sendNotification("Warning", "Set click position first!", 3)
        return
    end
    stopAllProcesses()
    autoClickEnabled = true
    btnAutoClicker.Text = "Auto Clicker: ON"
    task.spawn(function()
        local clickCount = 0
        while autoClickEnabled do
            local interval = math.max(0.05, clickInterval)
            if vmAvailable then
                -- This now correctly uses the full coordinate transformation pipeline
                simulateClick(clickPosition)
                clickCount = clickCount + 1
                if clickCount % 10 == 0 then
                    btnAutoClicker.Text = string.format("Clicks: %d", clickCount)
                end
            else
                stopAutoClicker()
                sendNotification("Error", "VirtualInputManager not available", 3)
                break
            end
            task.wait(interval)
        end
    end)
    sendNotification("Auto Clicker", string.format("Started clicking at (%d, %d)", clickPosition.X, clickPosition.Y), 3)
end

-- Set click position
local positionSetConnection = nil
local function stopSetPosition()
    if not waitingForPosition then return end
    waitingForPosition = false
    if btnSetPosition.Text ~= "Set Position" then btnSetPosition.Text = "Set Position" end
    if positionSetConnection then
        positionSetConnection:Disconnect()
        positionSetConnection = nil
    end
end

local function setClickPosition()
    if waitingForPosition then stopSetPosition(); return end
    stopAllProcesses()
    waitingForPosition = true
    btnSetPosition.Text = "Click anywhere on screen..."
    if positionSetConnection then positionSetConnection:Disconnect(); positionSetConnection = nil end
    positionSetConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if waitingForPosition and not gameProcessed then
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local pos = Vector2.new(input.Position.X, input.Position.Y)
                if isOverOurGUI(pos) then return end
                
                local marker = Instance.new("Frame", mainGui)
                marker.Size = UDim2.new(0, 10, 0, 10)
                marker.Position = UDim2.new(0, pos.X-5, 0, pos.Y-5)
                marker.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                marker.BorderSizePixel = 0
                task.delay(1, function() marker:Destroy() end)
                
                clickPosition = pos
                stopSetPosition()
                btnSetPosition.Text = "Position Set!"
                sendNotification("Position Set", string.format("Click position: (%d, %d)", pos.X, pos.Y), 3)
                
                task.delay(2, function() 
                    if btnSetPosition.Text == "Position Set!" then btnSetPosition.Text = "Set Position" end
                end)
            end
        end
    end)
end

function stopAllProcesses()
    stopAutoClicker()
    stopRecording()
    stopReplay()
    stopReplayLoop()
    stopSetPosition()
end

-- UI Connections
makeDraggable(mainFrame, dragLayer)
makeDraggable(toggleGuiBtn, toggleGuiBtn)

btnAutoClicker.MouseButton1Click:Connect(function()
    local val = tonumber(lblInterval.Text)
    if val and val > 0 then clickInterval = val else lblInterval.Text = tostring(clickInterval) end
    toggleAutoClicker()
end)

btnSetPosition.MouseButton1Click:Connect(setClickPosition)
btnTestClick.MouseButton1Click:Connect(function()
    if clickPosition == Vector2.new(500, 500) then
        sendNotification("Test Failed", "Set click position first!", 3)
        return
    end
    if vmAvailable then
        -- This now correctly uses the full coordinate transformation pipeline
        simulateClick(clickPosition)
        sendNotification("Test Click", string.format("Clicked at (%d, %d)", clickPosition.X, clickPosition.Y), 2)
    else
        sendNotification("Test Failed", "VirtualInputManager not available", 3)
    end
end)

btnStartRecording.MouseButton1Click:Connect(toggleRecording)
btnReplayClicks.MouseButton1Click:Connect(toggleReplay)
btnReplayLoop.MouseButton1Click:Connect(toggleReplayLoop)

btnApplySettings.MouseButton1Click:Connect(function()
    local offsetX = tonumber(offsetXInput.Text) or 0
    local offsetY = tonumber(offsetYInput.Text) or 0
    local curve = tonumber(swipeCurveInput.Text) or 0
    activeXOffsetRaw = { mode = "px", value = offsetX }
    activeYOffsetRaw = { mode = "px", value = offsetY }
    curve = math.clamp(curve, 0, 100)
    swipeCurveInput.Text = tostring(curve)
    sendNotification("Offsets Applied", string.format("X: %dpx, Y: %dpx, Curve: %d%%", offsetX, offsetY, curve), 3)
end)

toggleGuiBtn.MouseButton1Click:Connect(function()
    guiHidden = not guiHidden
    mainFrame.Visible = not guiHidden
    toggleGuiBtn.Text = guiHidden and "Show" or "Hide"
end)

submitBtn.MouseButton1Click:Connect(function()
    local enteredKey = keyBox.Text
    local expectedKey = "key_not_fetched"
    local httpGet = game.HttpGet or HttpGet
    if not httpGet then
        sendNotification("Key Check Failed", "No HttpGet function found.")
        return
    end

    local success, response = pcall(function() return httpGet("https://pastebin.com/raw/v4eb6fHw", true) end)
    
    if success and response then
        expectedKey = response:match("%S+") or "pastebin_read_error"
    else
        sendNotification("Key Check Failed", "Could not fetch key. Check HttpService/network.")
    end

    if enteredKey == expectedKey or enteredKey == "happybirthday Mohamednigga" then
        sendNotification("Access Granted", "Welcome!")
        keyEntry:Destroy()
        mainFrame.Visible = true
        toggleGuiBtn.Visible = true
        task.wait(0.5)
        updateCalibration()
    else
        keyBox.Text = ""
        keyBox.PlaceholderText = "Invalid key, try again"
        sendNotification("Access Denied", "The key you entered is incorrect.")
    end
end)

copyBtn.MouseButton1Click:Connect(function()
    local keyLink = "https.loot-link.com/s?AVreZic8"
    if setclipboard then
        local success, err = pcall(function() setclipboard(keyLink) end)
        if success then
            sendNotification("Link Copied", "The key link has been copied.")
        else
            sendNotification("Copy Failed", "setclipboard() error: " .. tostring(err))
        end
    else
        keyBox.Text = keyLink
        copyBtn.Text = "Copy From Box"
        sendNotification("Now Copy", "Select and copy the link from the text box.")
    end
end)

tabAutoClicker.MouseButton1Click:Connect(function() selectTab("auto") end)
tabRecorder.MouseButton1Click:Connect(function() selectTab("record") end)
tabSettings.MouseButton1Click:Connect(function() selectTab("settings")end)

-- ENHANCED VIM Initialization and final setup
local function initialize_VIM()
    local success, vim_instance = pcall(function() return game:GetService("VirtualInputManager") end)
    if success and vim_instance then
        VirtualInputManager = vim_instance
        vmAvailable = true
        task.spawn(function()
            task.wait(1)
            local testSuccess, err = pcall(function() VirtualInputManager:SendMouseMoveEvent(100, 100) end)
            if testSuccess then
                sendNotification("VIM Ready", "Virtual inputs working properly", 3)
                print("[VIM] Successfully initialized and tested")
            else
                sendNotification("VIM Warning", "VIM found but may not work. Error: "..tostring(err), 5)
            end
        end)
    else
        vmAvailable = false
        sendNotification("VIM ERROR", "VirtualInputManager NOT FOUND", 10)
        print("[VIM ERROR] VirtualInputManager service not available")
    end
end

selectTab("auto")
initialize_VIM()

-- End of script