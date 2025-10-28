-- This is the COMBINED Macro Script (Recorder Only)
-- Execute this single file in Delta.
-- DEFINITIVE FIX v4: Dynamic Scaling Calibration Engine
-- This version abandons hardcoded insets and introduces a robust,
-- dynamic calibration system to fix multiplicative coordinate errors.

-- --- Wait for Services ---
while not (game and game.GetService and game.HttpGet) do
    wait(0.05)
end

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
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
        StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = 5})
    end)
end

-- --- START OF UI CODE ---

local FONT_MAIN = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamBold

-- --- Main ScreenGui ---
mainGui = Instance.new("ScreenGui")
mainGui.Name = "MacroV4GUI"
mainGui.IgnoreGuiInset = true
mainGui.ResetOnSpawn = false
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
mainGui.Parent = CoreGui

-- --- Main Frame ---
mainFrame = Instance.new("Frame", mainGui)
mainFrame.Name = "MacroFrame"
mainFrame.Size = UDim2.new(0, 280, 0, 310) -- Increased size
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Visible = false -- Will be made visible at the end
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
title.Text = "Macro Recorder"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = FONT_BOLD
title.TextSize = 22
title.ZIndex = 2

-- --- Content Area ---
contentArea = Instance.new("Frame", mainFrame)
contentArea.Size = UDim2.new(1, -20, 1, -50)
contentArea.Position = UDim2.new(0, 10, 0, 40)
contentArea.BackgroundTransparency = 1

-- --- Button Factory ---
local function createButton(text, posY, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.Position = UDim2.new(0, 0, 0, posY)
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

-- --- Recorder Content ---
btnStartRecording = createButton("Start Recording", 10, contentArea)
btnReplayClicks = createButton("Replay Clicks", 50, contentArea)
btnReplayLoop = createButton("Replay Loop: OFF", 90, contentArea)

replayCountInput = Instance.new("TextBox", contentArea)
replayCountInput.Size = UDim2.new(1, 0, 0, 30)
replayCountInput.Position = UDim2.new(0, 0, 0, 130)
replayCountInput.PlaceholderText = "Replay Amount (default 1)"
replayCountInput.Text = "1"
replayCountInput.Font = FONT_MAIN
replayCountInput.TextSize = 16
replayCountInput.TextColor3 = Color3.fromRGB(255, 255, 255)
replayCountInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
replayCountInput.BorderSizePixel = 0
replayCountInput.ZIndex = 3
replayCountInput.Parent = contentArea
local replayCorner = Instance.new("UICorner", replayCountInput)
replayCorner.CornerRadius = UDim.new(0, 6)

-- --- Calibration UI ---
local calibrationTitle = Instance.new("TextLabel", contentArea)
calibrationTitle.Size = UDim2.new(1, 0, 0, 20)
calibrationTitle.Position = UDim2.new(0, 0, 0, 175)
calibrationTitle.BackgroundTransparency = 1
calibrationTitle.Text = "Executor Virtual Resolution (Default: 1920x1080)"
calibrationTitle.Font = FONT_MAIN
calibrationTitle.TextSize = 12
calibrationTitle.TextColor3 = Color3.fromRGB(180, 180, 180)

virtualWidthInput = Instance.new("TextBox", contentArea)
virtualWidthInput.Size = UDim2.new(0.48, 0, 0, 30)
virtualWidthInput.Position = UDim2.new(0, 0, 0, 200)
virtualWidthInput.PlaceholderText = "Width"
virtualWidthInput.Text = "1920"
virtualWidthInput.Font = FONT_MAIN
virtualWidthInput.TextSize = 16
virtualWidthInput.TextColor3 = Color3.fromRGB(255, 255, 255)
virtualWidthInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
virtualWidthInput.BorderSizePixel = 0
virtualWidthInput.ZIndex = 3
local vwCorner = Instance.new("UICorner", virtualWidthInput)
vwCorner.CornerRadius = UDim.new(0, 6)

virtualHeightInput = Instance.new("TextBox", contentArea)
virtualHeightInput.Size = UDim2.new(0.48, 0, 0, 30)
virtualHeightInput.Position = UDim2.new(0.52, 0, 0, 200)
virtualHeightInput.PlaceholderText = "Height"
virtualHeightInput.Text = "1080"
virtualHeightInput.Font = FONT_MAIN
virtualHeightInput.TextSize = 16
virtualHeightInput.TextColor3 = Color3.fromRGB(255, 255, 255)
virtualHeightInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
virtualHeightInput.BorderSizePixel = 0
virtualHeightInput.ZIndex = 3
local vhCorner = Instance.new("UICorner", virtualHeightInput)
vhCorner.CornerRadius = UDim.new(0, 6)

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
toggleGuiBtn.Visible = false
toggleGuiBtn.Active = true
local toggleCorner = Instance.new("UICorner", toggleGuiBtn)
toggleCorner.CornerRadius = UDim.new(0, 6)

-- --- Draggability ---
local function makeDraggable(guiObject, dragHandle)
    local dragging = false; local dragStartMousePos; local objectStartPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStartMousePos = UserInputService:GetMouseLocation(); objectStartPos = guiObject.Position
        end
    end)
    dragHandle.InputChanged:Connect(function(changedInput)
        if not dragging then return end
        if changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch then
            local delta = UserInputService:GetMouseLocation() - dragStartMousePos
            guiObject.Position = UDim2.new(objectStartPos.X.Scale, objectStartPos.X.Offset + delta.X, objectStartPos.Y.Scale, objectStartPos.Y.Offset + delta.Y)
        end
    end)
    dragHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end
makeDraggable(mainFrame, dragLayer); makeDraggable(toggleGuiBtn, toggleGuiBtn)

-- --- END OF UI CODE ---

-- --- START OF CORE CODE ---

-- --- Config ---
local MIN_CLICK_HOLD_DURATION = 0.05
local SWIPE_MIN_PIXELS = 8
local SWIPE_SAMPLE_FPS = 60
local SWIPE_CURVATURE_DEFAULT = 0.0
local SWIPE_EASING = "easeInOutQuad"

-- --- State Variables ---
local isRecording, recordedActions, recordStartTime, recordConnections = false, {}, 0, {}
local isReplaying, replayCount, currentReplayThread = false, 1, nil
local isReplayingLoop, currentReplayLoopThread = false, nil
local guiHidden = false

-- --- task Shim ---
if type(task) ~= "table" then task = {spawn = coroutine.wrap, wait = function(t) local s = tick() while tick() - s < (t or 0) do RunService.Heartbeat:Wait() end end, cancel = function() end} end

-- --- DYNAMIC CALIBRATION ENGINE ---
local guiInset = Vector2.new(0, 0)
local hardwareScreenSize = Vector2.new(0, 0)
local virtualScreenSize = Vector2.new(1920, 1080)
local scaleFactor = Vector2.new(1, 1)

local function updateCalibration()
    -- 1. Get GuiInset (the device's "safe area" or "black bars")
    local success, result = pcall(function() return GuiService:GetGuiInset() end)
    guiInset = (success and result) or Vector2.new(0, 0)

    -- 2. Get Hardware Screen Size by measuring a temporary full-screen frame
    local measurer = Instance.new("Frame")
    measurer.Size = UDim2.new(1, 0, 1, 0)
    measurer.IgnoreGuiInset = true
    measurer.Parent = mainGui
    task.wait() -- Wait a frame for size to be calculated
    hardwareScreenSize = measurer.AbsoluteSize
    measurer:Destroy()
    
    -- 3. Get Virtual Screen Size from UI inputs
    local vw = tonumber(virtualWidthInput.Text) or 1920
    local vh = tonumber(virtualHeightInput.Text) or 1080
    virtualScreenSize = Vector2.new(vw, vh)

    -- 4. Calculate the final multiplicative scaling factor
    if hardwareScreenSize.X > 1 and hardwareScreenSize.Y > 1 then
        scaleFactor = Vector2.new(
            virtualScreenSize.X / hardwareScreenSize.X,
            virtualScreenSize.Y / hardwareScreenSize.Y
        )
    else
        scaleFactor = Vector2.new(1, 1) -- Fallback
    end
    
    sendNotification("Calibrated", string.format("Scale: (%.2f, %.2f)", scaleFactor.X, scaleFactor.Y))
end

-- The definitive coordinate conversion function.
local function ViewportToExecutor(viewportPos)
    -- Step 1: Convert from Viewport space (where input is recorded) to Hardware space
    local hardwarePos = viewportPos + guiInset
    
    -- Step 2: Scale from Hardware space to the Executor's Virtual space
    local executorPos = Vector2.new(
        math.floor(hardwarePos.X * scaleFactor.X + 0.5),
        math.floor(hardwarePos.Y * scaleFactor.Y + 0.5)
    )
    return executorPos
end

-- --- VIM (Click Engine) ---
local VirtualInputManager
local vmAvailable do local s,r = pcall(function() return game:GetService("VirtualInputManager") end) vmAvailable = s if s then VirtualInputManager = r end end
local function safeSendMouseMove(x, y) if vmAvailable then pcall(function() VirtualInputManager:SendMouseMoveEvent(x, y, game, 0) end) end end
local function safeSendMouseButton(x, y, button, isDown) if vmAvailable then pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, button, isDown, game, 0) end) end end

-- --- Easing ---
local EASINGS = {easeInOutQuad = function(t) return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t end}
local function applyEasing(name, t) return (EASINGS[name] and EASINGS[name](t)) or t end

-- --- Simulation Functions (The "Engine") ---
local function simulateClick(pixelPos)
    if not pixelPos then return end
    local effectivePos = ViewportToExecutor(pixelPos)
    safeSendMouseMove(effectivePos.X, effectivePos.Y)
    task.wait(0.01)
    safeSendMouseButton(effectivePos.X, effectivePos.Y, 0, true)
    task.wait(MIN_CLICK_HOLD_DURATION)
    safeSendMouseButton(effectivePos.X, effectivePos.Y, 0, false)
end

local function simulateSwipe(startPixel, endPixel, duration, curvatureFraction)
    if not startPixel or not endPixel then return end
    local startPos = ViewportToExecutor(startPixel)
    local endPos = ViewportToExecutor(endPixel)
    local dx = endPos.X - startPos.X; local dy = endPos.Y - startPos.Y
    local dist = math.sqrt(dx * dx + dy * dy); local steps = math.max(2, math.floor(math.max(0.02, duration) * SWIPE_SAMPLE_FPS))
    local perpX, perpY = 0, 0
    if curvatureFraction and curvatureFraction ~= 0 and dist > 0 then perpX = -dy / dist; perpY = dx / dist end
    safeSendMouseMove(startPos.X, startPos.Y); task.wait(0.01)
    safeSendMouseButton(startPos.X, startPos.Y, 0, true)
    for i = 1, steps do
        local t = i / steps; local eased = applyEasing(SWIPE_EASING, t)
        local baseX = startPos.X + (endPos.X - startPos.X) * eased; local baseY = startPos.Y + (endPos.Y - startPos.Y) * eased
        local curveAmount = (curvatureFraction or 0) * dist * (1 - math.abs(2 * t - 1))
        local x = baseX + perpX * curveAmount; local y = baseY + perpY * curveAmount
        safeSendMouseMove(x, y); RunService.Heartbeat:Wait()
    end
    safeSendMouseMove(endPos.X, endPos.Y); safeSendMouseButton(endPos.X, endPos.Y, 0, false)
end

-- --- Stop All ---
local function stopAllProcesses() local s,r,l function stopAllProcesses() if s then s() end; if r then r() end; if l then l() end end return function(i) s=i.stopRecording;r=i.stopReplay;l=i.stopReplayLoop end end
local assignStopFunctions = stopAllProcesses()

-- --- Recording Logic ---
local activeInputs = {}
local function clearActiveInputs() for k in pairs(activeInputs) do activeInputs[k] = nil end end
local function isOverOurGUI(pos)
    local s, objs = pcall(UserInputService.GetGuiObjectsAtPosition, UserInputService, pos.X, pos.Y)
    if not s or #objs == 0 then return false end
    for _, o in ipairs(objs) do if o:IsDescendantOf(mainGui) then return true end end
    return false
end
local function stopRecording()
    if not isRecording then return end
    isRecording = false; btnStartRecording.Text = "Start Recording"
    for _, conn in pairs(recordConnections) do conn:Disconnect() end
    recordConnections = {}; clearActiveInputs()
end
local function startRecording()
    stopAllProcesses(); isRecording = true; recordedActions = {}; recordStartTime = os.clock()
    btnStartRecording.Text = "Stop Recording"
    recordConnections.began = UserInputService.InputBegan:Connect(function(input, gp)
        if not isRecording or gp then return end
        local ut = input.UserInputType
        if not (ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch) then return end
        local pos = input.Position
        if isOverOurGUI(pos) then return end
        activeInputs[input] = { startTime = os.clock(), startPos = pos, lastPos = pos, isDragging = false }
    end)
    recordConnections.changed = UserInputService.InputChanged:Connect(function(input)
        if not isRecording then return end
        local data = activeInputs[input]
        if not data then return end
        local pos = input.Position
        if not data.isDragging and (pos - data.startPos).Magnitude >= SWIPE_MIN_PIXELS then data.isDragging = true end
        data.lastPos = pos
    end)
    recordConnections.ended = UserInputService.InputEnded:Connect(function(input)
        if not isRecording then return end
        local data = activeInputs[input]; if not data then return end
        local now = os.clock(); local delay = now - recordStartTime; recordStartTime = now
        local endPos = input.Position
        if data.isDragging or (endPos - data.startPos).Magnitude >= SWIPE_MIN_PIXELS then
            table.insert(recordedActions, {type = "swipe", startPixel = data.startPos, endPixel = endPos, duration = math.max(0.02, now - data.startTime), delay = delay})
        else
            table.insert(recordedActions, {type = "tap", pixelPos = data.startPos, delay = delay})
        end
        activeInputs[input] = nil
    end)
end
local function toggleRecording() if isRecording then stopRecording() else startRecording() end end

-- --- Replay Logic ---
local function doReplayActions(actionList)
    for _, act in ipairs(actionList) do
        if not isReplaying and not isReplayingLoop then break end
        if act.delay and act.delay > 0 then task.wait(act.delay) else RunService.Heartbeat:Wait() end
        if not isReplaying and not isReplayingLoop then break end
        if act.type == "tap" then simulateClick(act.pixelPos)
        elseif act.type == "swipe" then simulateSwipe(act.startPixel, act.endPixel, act.duration or 0.12, SWIPE_CURVATURE_DEFAULT) end
    end
end
local function stopReplay() if not isReplaying then return end; isReplaying = false; btnReplayClicks.Text = "Replay Clicks"; if currentReplayThread then task.cancel(currentReplayThread); currentReplayThread = nil end end
local function toggleReplay()
    if isReplaying then stopReplay() return end; if #recordedActions == 0 then sendNotification("Replay Failed", "No actions recorded yet.") return end
    stopAllProcesses(); isReplaying = true
    local num = tonumber(replayCountInput.Text); replayCount = (num and num > 0) and math.floor(num) or 1
    replayCountInput.Text = tostring(replayCount); btnReplayClicks.Text = "Stop Replay"
    currentReplayThread = task.spawn(function()
        for i = 1, replayCount do if not isReplaying then break end
            btnReplayClicks.Text = string.format("Replaying (%d/%d)", i, replayCount); doReplayActions(recordedActions)
            if i < replayCount and isReplaying then task.wait(0.1) end
        end; stopReplay()
    end)
end

-- --- Replay Loop ---
local function stopReplayLoop() if not isReplayingLoop then return end; isReplayingLoop = false; btnReplayLoop.Text = "Replay Loop: OFF"; if currentReplayLoopThread then task.cancel(currentReplayLoopThread); currentReplayLoopThread = nil end end
local function toggleReplayLoop()
    if isReplayingLoop then stopReplayLoop() return end; if #recordedActions == 0 then sendNotification("Replay Failed", "No actions recorded yet.") return end
    stopAllProcesses(); isReplayingLoop = true; btnReplayLoop.Text = "Replay Loop: ON"
    currentReplayLoopThread = task.spawn(function() while isReplayingLoop do doReplayActions(recordedActions); if isReplayingLoop then task.wait(0.1) end end end)
end

-- --- Assign Stop Functions ---
assignStopFunctions({stopRecording = stopRecording, stopReplay = stopReplay, stopReplayLoop = stopReplayLoop})

-- --- GUI Connections ---
btnStartRecording.MouseButton1Click:Connect(toggleRecording)
btnReplayClicks.MouseButton1Click:Connect(toggleReplay)
btnReplayLoop.MouseButton1Click:Connect(toggleReplayLoop)
toggleGuiBtn.MouseButton1Click:Connect(function()
    guiHidden = not guiHidden; mainFrame.Visible = not guiHidden
    toggleGuiBtn.Text = guiHidden and "Show" or "Hide"
end)
local function onFocusLost() task.wait(0.1); updateCalibration() end
virtualWidthInput.FocusLost:Connect(onFocusLost)
virtualHeightInput.FocusLost:Connect(onFocusLost)

-- --- Initial State ---
sendNotification("Macro Recorder Loaded", vmAvailable and "Dynamic Scaling Engine Active" or "CRITICAL: VIM NOT Found")
mainFrame.Visible = true
toggleGuiBtn.Visible = true
task.wait(0.5) -- Wait for GUI to fully render before initial calibration
updateCalibration()

-- --- END OF CORE CODE ---
