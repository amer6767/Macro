-- Roblox Macro V4 (Fixed, Calibrated, Debugged)
-- Incorporates fixes for syntax, VIM parameters, input reading, and calibration timing.

-- Wait for game.GetService to be available
while not (game and game.GetService) do
    wait(0.05)
end

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local workspace = workspace

-- Player
local player = Players.LocalPlayer
while not player do
    RunService.Heartbeat:Wait()
    player = Players.LocalPlayer
end
local mouse = player:GetMouse()

-- Config
local MIN_CLICK_HOLD_DURATION = 0.05
local FONT_MAIN = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamBold
local SWIPE_MIN_PIXELS = 8
local SWIPE_SAMPLE_FPS = 60
local SWIPE_CURVATURE_DEFAULT = 0.0
local SWIPE_EASING = "easeInOutQuad"

-- State
local autoClickEnabled, clickInterval = false, 0.2
local clickPosition = Vector2.new(500, 500)
local waitingForPosition = false
local isRecording, recordedActions, recordStartTime, recordConnections = false, {}, 0, {}
local isReplaying, replayCount, currentReplayThread = false, 1, nil
local isReplayingLoop, currentReplayLoopThread = false, nil
local activeXOffsetRaw = { mode = "px", value = 0 }
local activeYOffsetRaw = { mode = "px", value = 0 }
local guiHidden = false

-- Calibration State
local guiInset, hardwareScreenSize = Vector2.new(0, 0), Vector2.new(0, 0)
local virtualScreenSize = Vector2.new(1920, 1080)
local scaleFactor = Vector2.new(1, 1)

-- task shim
if type(task) ~= "table" or type(task.spawn) ~= "function" then
    task = {
        spawn = coroutine.wrap,
        wait = function(time)
            local start = tick()
            while tick() - start < (time or 0) do RunService.Heartbeat:Wait() end
        end,
        delay = function(time, func) task.spawn(function() task.wait(time); func() end) end,
        cancel = function(co) if type(co) == "thread" then coroutine.close(co) end end
    }
end

-- UI Creation
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "MacroV4GUI_Fixed"
mainGui.IgnoreGuiInset = true; mainGui.ResetOnSpawn = false
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Global; mainGui.Parent = CoreGui

local keyEntry = Instance.new("Frame")
keyEntry.Size = UDim2.new(0, 260, 0, 140); keyEntry.Position = UDim2.new(0.5, -130, 0.5, -70)
keyEntry.AnchorPoint = Vector2.new(0.5, 0.5); keyEntry.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
keyEntry.BorderSizePixel = 0; keyEntry.Parent = mainGui
local keyEntryCorner = Instance.new("UICorner", keyEntry); keyEntryCorner.CornerRadius = UDim.new(0, 8)

local keyBox = Instance.new("TextBox", keyEntry)
keyBox.Size = UDim2.new(0.9, 0, 0, 30); keyBox.Position = UDim2.new(0.05, 0, 0, 10)
keyBox.PlaceholderText = "Enter Key"; keyBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
keyBox.TextColor3 = Color3.new(1, 1, 1); keyBox.Font = FONT_MAIN; keyBox.TextSize = 16
keyBox.BorderSizePixel = 0; keyBox.ClearTextOnFocus = false
local keyBoxCorner = Instance.new("UICorner", keyBox); keyBoxCorner.CornerRadius = UDim.new(0, 6)

local submitBtn = Instance.new("TextButton", keyEntry)
submitBtn.Size = UDim2.new(0.9, 0, 0, 30); submitBtn.Position = UDim2.new(0.05, 0, 0, 50)
submitBtn.Text = "Submit Key"; submitBtn.Font = FONT_MAIN; submitBtn.TextSize = 16
submitBtn.TextColor3 = Color3.new(1, 1, 1); submitBtn.BackgroundColor3 = Color3.fromRGB(0, 122, 204)
submitBtn.BorderSizePixel = 0
local submitBtnCorner = Instance.new("UICorner", submitBtn); submitBtnCorner.CornerRadius = UDim.new(0, 6)

local copyBtn = Instance.new("TextButton", keyEntry)
copyBtn.Size = UDim2.new(0.9, 0, 0, 30); copyBtn.Position = UDim2.new(0.05, 0, 0, 90)
copyBtn.Text = "Copy Key Link"; copyBtn.Font = FONT_MAIN; copyBtn.TextSize = 16
copyBtn.TextColor3 = Color3.fromRGB(220, 220, 220); copyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
copyBtn.BorderSizePixel = 0
local copyBtnCorner = Instance.new("UICorner", copyBtn); copyBtnCorner.CornerRadius = UDim.new(0, 6)

local mainFrame = Instance.new("Frame", mainGui)
mainFrame.Size = UDim2.new(0, 260, 0, 440); mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5); mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0; mainFrame.ClipsDescendants = true; mainFrame.Visible = false
local frameCorner = Instance.new("UICorner", mainFrame); frameCorner.CornerRadius = UDim.new(0, 12)

local dragLayer = Instance.new("Frame", mainFrame)
dragLayer.Size = UDim2.new(1, 0, 0, 40); dragLayer.BackgroundTransparency = 1; dragLayer.ZIndex = 1; dragLayer.Active = true

local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, 0, 0, 40); title.BackgroundTransparency = 1; title.Text = "Macro V4 (Fixed)"
title.TextColor3 = Color3.fromRGB(255, 255, 255); title.Font = FONT_BOLD; title.TextSize = 20; title.ZIndex = 2

local tabBar = Instance.new("Frame", mainFrame)
tabBar.Size = UDim2.new(1, 0, 0, 40); tabBar.Position = UDim2.new(0, 0, 0, 40); tabBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)

local tabAutoClicker = Instance.new("TextButton", tabBar)
tabAutoClicker.Size = UDim2.new(0, 75, 1, 0); tabAutoClicker.Text = "Auto"; tabAutoClicker.Font = FONT_MAIN
tabAutoClicker.TextSize = 14; tabAutoClicker.TextColor3 = Color3.new(1, 1, 1); tabAutoClicker.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
local tabAutoCorner = Instance.new("UICorner", tabAutoClicker); tabAutoCorner.CornerRadius = UDim.new(0, 4)

local tabRecorder = Instance.new("TextButton", tabBar)
tabRecorder.Size = UDim2.new(0, 75, 1, 0); tabRecorder.Position = UDim2.new(0, 75, 0, 0); tabRecorder.Text = "Record"
tabRecorder.Font = FONT_MAIN; tabRecorder.TextSize = 14; tabRecorder.TextColor3 = Color3.new(1, 1, 1)
tabRecorder.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
local tabRecordCorner = Instance.new("UICorner", tabRecorder); tabRecordCorner.CornerRadius = UDim.new(0, 4)

local tabSettings = Instance.new("TextButton", tabBar)
tabSettings.Size = UDim2.new(0, 75, 1, 0); tabSettings.Position = UDim2.new(0, 150, 0, 0); tabSettings.Text = "Settings"
tabSettings.Font = FONT_MAIN; tabSettings.TextSize = 14; tabSettings.TextColor3 = Color3.new(1, 1, 1)
tabSettings.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
local tabSettingsCorner = Instance.new("UICorner", tabSettings); tabSettingsCorner.CornerRadius = UDim.new(0, 4)

local contentArea = Instance.new("Frame", mainFrame)
contentArea.Size = UDim2.new(1, 0, 1, -80); contentArea.Position = UDim2.new(0, 0, 0, 80); contentArea.BackgroundTransparency = 1

local autoContent = Instance.new("Frame", contentArea)
autoContent.Size = UDim2.new(1, 0, 1, 0); autoContent.BackgroundTransparency = 1; autoContent.Visible = true

local recordContent = Instance.new("Frame", contentArea)
recordContent.Size = UDim2.new(1, 0, 1, 0); recordContent.BackgroundTransparency = 1; recordContent.Visible = false

local settingsContent = Instance.new("Frame", contentArea)
settingsContent.Size = UDim2.new(1, 0, 1, 0); settingsContent.BackgroundTransparency = 1; settingsContent.Visible = false

local function createButton(text, posY, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.85, 0, 0, 30); btn.Position = UDim2.new(0.075, 0, 0, posY)
    btn.Text = text; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.Font = FONT_MAIN
    btn.TextSize = 16; btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45); btn.BorderSizePixel = 0
    btn.ZIndex = 3; btn.Parent = parent
    local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0, 6)
    return btn
end

local function createInput(placeholder, text, posY, parent)
	local input = Instance.new("TextBox")
	input.Size = UDim2.new(0.85, 0, 0, 30); input.Position = UDim2.new(0.075, 0, 0, posY)
	input.PlaceholderText = placeholder; input.Text = text; input.Font = FONT_MAIN; input.TextSize = 16
	input.TextColor3 = Color3.fromRGB(255, 255, 255); input.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	input.BorderSizePixel = 0; input.ClearTextOnFocus = false; input.ZIndex = 3; input.Parent = parent
	local corner = Instance.new("UICorner", input); corner.CornerRadius = UDim.new(0, 6)
	return input
end

local btnAutoClicker = createButton("Auto Clicker: OFF", 10, autoContent)
local btnSetPosition = createButton("Set Position", 50, autoContent)
local lblInterval = createInput("Click Interval (sec)", tostring(clickInterval), 90, autoContent)

local btnStartRecording = createButton("Start Recording", 10, recordContent)
local btnReplayClicks = createButton("Replay Clicks", 50, recordContent)
local btnReplayLoop = createButton("Replay Loop: OFF", 90, recordContent)
local replayCountInput = createInput("Replay Amount (default 1)", "1", 130, recordContent)

local offsetXInput = createInput("Set X Offset (px or % e.g. 10 or 2%)", "0", 10, settingsContent)
local offsetYInput = createInput("Set Y Offset (px or % e.g. -5 or -1%)", "0", 50, settingsContent)
local swipeCurveInput = createInput("Swipe Curvature (0..50%)", tostring(SWIPE_CURVATURE_DEFAULT * 100), 90, settingsContent)
local virtualWidthInput = createInput("Virtual Width (e.g. 1920)", "1920", 130, settingsContent)
local virtualHeightInput = createInput("Virtual Height (e.g. 1080)", "1080", 170, settingsContent)
local btnApplySettings = createButton("Apply Settings & Calibrate", 210, settingsContent)

local toggleGuiBtn = Instance.new("TextButton", mainGui)
toggleGuiBtn.Size = UDim2.new(0, 70, 0, 30); toggleGuiBtn.Position = UDim2.new(0, 10, 0, 70)
toggleGuiBtn.Text = "Hide"; toggleGuiBtn.Font = FONT_MAIN; toggleGuiBtn.TextSize = 14
toggleGuiBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255); toggleGuiBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleGuiBtn.ZIndex = 1000; toggleGuiBtn.Visible = false; toggleGuiBtn.Active = true
local toggleCorner = Instance.new("UICorner", toggleGuiBtn); toggleCorner.CornerRadius = UDim.new(0, 6)

-- Helpers
local function makeDraggable(guiObject, dragHandle)
    local dragging, dragStartMousePos, objectStartPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStartMousePos, objectStartPos = true, UserInputService:GetMouseLocation(), guiObject.Position
        end
    end)
    dragHandle.InputChanged:Connect(function(changedInput)
        if dragging and (changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch) then
            local delta = UserInputService:GetMouseLocation() - dragStartMousePos
            guiObject.Position = UDim2.new(objectStartPos.X.Scale, objectStartPos.X.Offset + delta.X, objectStartPos.Y.Scale, objectStartPos.Y.Offset + delta.Y)
        end
    end)
    dragHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function sendNotification(title, text, duration)
    pcall(function() StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = duration or 3}) end)
end

local function selectTab(tabName)
    autoContent.Visible = (tabName == "auto")
    recordContent.Visible = (tabName == "record")
    settingsContent.Visible = (tabName == "settings")
    tabAutoClicker.BackgroundColor3 = (tabName == "auto") and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(50, 50, 50)
    tabRecorder.BackgroundColor3 = (tabName == "record") and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(50, 50, 50)
    tabSettings.BackgroundColor3 = (tabName == "settings") and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(50, 50, 50)
end

local function getViewportSize()
    return (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1920, 1080)
end

local function computePixelXOffset(raw)
    if raw.mode == "px" then return raw.value else return raw.value * getViewportSize().X end
end

local function computePixelYOffset(raw)
    if raw.mode == "px" then return raw.value else return raw.value * getViewportSize().Y end
end

-- Calibration Logic
function updateCalibration()
    local success, result = pcall(function() return GuiService:GetGuiInset() end)
    guiInset = (success and result) or Vector2.new(0, 36)
    hardwareScreenSize = mainGui.AbsoluteSize
    local vw, vh = tonumber(virtualWidthInput.Text) or 1920, tonumber(virtualHeightInput.Text) or 1080
    virtualScreenSize = Vector2.new(vw, vh)
    if hardwareScreenSize.X > 1 and hardwareScreenSize.Y > 1 then
        scaleFactor = Vector2.new(virtualScreenSize.X / hardwareScreenSize.X, virtualScreenSize.Y / hardwareScreenSize.Y)
    else
        scaleFactor = Vector2.new(1, 1) -- Fallback
    end
    sendNotification("Calibrated", string.format("Scale: (%.2f, %.2f)", scaleFactor.X, scaleFactor.Y), 3)
end

function ViewportToExecutor(viewportPos)
    local hardwarePos = viewportPos + guiInset
    return Vector2.new(math.floor(hardwarePos.X * scaleFactor.X + 0.5), math.floor(hardwarePos.Y * scaleFactor.Y + 0.5))
end

-- VirtualInputManager & Simulation
local VirtualInputManager = nil
local vmAvailable = false
local function initialize_VIM()
    local success, vim_instance = pcall(function() return game:GetService("VirtualInputManager") end)
    if success and vim_instance then
        VirtualInputManager = vim_instance
        vmAvailable = true
        sendNotification("VIM Status", "VirtualInputManager Found")
    else
        sendNotification("VIM ERROR", "VirtualInputManager NOT FOUND - Clicks won't work!", 10)
    end
end

local function safeSendMouseMove(x, y)
    if vmAvailable then
        pcall(function() VirtualInputManager:SendMouseMoveEvent(x, y) end)
    end
end

local function safeSendMouseButton(x, y, button, isDown)
    if vmAvailable then
        pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, button, isDown, false) end)
    end
end

-- Easing
local EASINGS = { easeInOutQuad = function(t) return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t end }
local function applyEasing(name, t) return (EASINGS[name] and EASINGS[name](t)) or t end

-- Simulate Actions
local function simulateClick(pixelPos)
    if not pixelPos then return end
    local offsetPos = Vector2.new(pixelPos.X + computePixelXOffset(activeXOffsetRaw), pixelPos.Y + computePixelYOffset(activeYOffsetRaw))
    local effectivePos = ViewportToExecutor(offsetPos)
    safeSendMouseMove(effectivePos.X, effectivePos.Y)
    task.wait(0.01)
    safeSendMouseButton(effectivePos.X, effectivePos.Y, 0, true)
    task.wait(MIN_CLICK_HOLD_DURATION)
    safeSendMouseButton(effectivePos.X, effectivePos.Y, 0, false)
end

local function simulateSwipe(startPixel, endPixel, duration, curvatureFraction)
    if not startPixel or not endPixel then return end
    local xOffset, yOffset = computePixelXOffset(activeXOffsetRaw), computePixelYOffset(activeYOffsetRaw)
    local startPos = ViewportToExecutor(Vector2.new(startPixel.X + xOffset, startPixel.Y + yOffset))
    local endPos = ViewportToExecutor(Vector2.new(endPixel.X + xOffset, endPixel.Y + yOffset))
    local dx, dy = endPos.X - startPos.X, endPos.Y - startPos.Y
    local dist = math.sqrt(dx * dx + dy * dy)
    local steps = math.max(2, math.floor(math.max(0.02, duration) * SWIPE_SAMPLE_FPS))
    local perpX, perpY = 0, 0
    if curvatureFraction and curvatureFraction ~= 0 and dist > 0 then
        perpX, perpY = -dy / dist, dx / dist
    end
    safeSendMouseMove(startPos.X, startPos.Y); task.wait(0.01)
    safeSendMouseButton(startPos.X, startPos.Y, 0, true)
    for i = 1, steps do
        local t = i / steps; local eased = applyEasing(SWIPE_EASING, t)
        local baseX, baseY = startPos.X + dx * eased, startPos.Y + dy * eased
        local curveAmount = (curvatureFraction or 0) * dist * (1 - math.abs(2 * t - 1))
        safeSendMouseMove(baseX + perpX * curveAmount, baseY + perpY * curveAmount)
        RunService.Heartbeat:Wait()
    end
    safeSendMouseMove(endPos.X, endPos.Y)
    safeSendMouseButton(endPos.X, endPos.Y, 0, false)
end

-- Recording Logic
local activeInputs = {}
local function clearActiveInputs() for k in pairs(activeInputs) do activeInputs[k] = nil end end
local function isOverOurGUI(pos)
    local success, result = pcall(function()
        for _, o in ipairs(UserInputService:GetGuiObjectsAtPosition(pos.X, pos.Y)) do
            if o:IsDescendantOf(mainGui) then return true end
        end
    end)
    return success and result
end

local function debugRecordedActions()
    print("=== RECORDED ACTIONS DEBUG ===")
    print("Total actions:", #recordedActions)
    for i, act in ipairs(recordedActions) do
        if act.type == "tap" then
            print(string.format("[%d] TAP at (%.0f, %.0f) delay:%.2f", i, act.pixelPos.X, act.pixelPos.Y, act.delay))
        elseif act.type == "swipe" then
            print(string.format("[%d] SWIPE from (%.0f, %.0f) to (%.0f, %.0f) duration:%.2f delay:%.2f", i, act.startPixel.X, act.startPixel.Y, act.endPixel.X, act.endPixel.Y, act.duration, act.delay))
        end
    end
    print("=== END DEBUG ===")
end

local stopAllProcesses; -- Forward declaration

local function stopRecording()
    if not isRecording then return end
    isRecording = false
    btnStartRecording.Text = "Start Recording"
    for _, conn in pairs(recordConnections) do if conn and conn.Disconnect then pcall(conn.Disconnect, conn) end end
    recordConnections = {}
    clearActiveInputs()
    debugRecordedActions()
end

local function startRecording()
    stopAllProcesses()
    isRecording, recordedActions, recordStartTime = true, {}, os.clock()
    btnStartRecording.Text = "Stop Recording"

    recordConnections["began"] = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not isRecording or gameProcessed then return end
        if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then return end
        local pos = Vector2.new(input.Position.X, input.Position.Y)
        if isOverOurGUI(pos) then return end
        activeInputs[input] = { startTime = os.clock(), startPos = pos, lastPos = pos, isDragging = false }
    end)

    recordConnections["changed"] = UserInputService.InputChanged:Connect(function(input)
        local data = activeInputs[input]
        if not isRecording or not data then return end
        local pos = Vector2.new(input.Position.X, input.Position.Y)
        if not data.isDragging and (pos - data.startPos).Magnitude >= SWIPE_MIN_PIXELS then
            data.isDragging = true
        end
        data.lastPos = pos
    end)

    recordConnections["ended"] = UserInputService.InputEnded:Connect(function(input)
        local data = activeInputs[input]
        if not isRecording or not data then return end
        local now, delay = os.clock(), os.clock() - recordStartTime
        recordStartTime = now
        local endPos = Vector2.new(input.Position.X, input.Position.Y)
        if data.isDragging or (endPos - data.startPos).Magnitude >= SWIPE_MIN_PIXELS then
            table.insert(recordedActions, { type = "swipe", startPixel = data.startPos, endPixel = endPos, duration = math.max(0.02, now - data.startTime), delay = delay })
        else
            table.insert(recordedActions, { type = "tap", pixelPos = data.startPos, delay = delay })
        end
        activeInputs[input] = nil
    end)
end

local function toggleRecording()
    if isRecording then stopRecording() else startRecording() end
end

-- Replay Logic
function stopReplay()
    if not isReplaying then return end
    isReplaying = false
    btnReplayClicks.Text = "Replay Clicks"
    if currentReplayThread then task.cancel(currentReplayThread); currentReplayThread = nil end
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
            simulateSwipe(act.startPixel, act.endPixel, act.duration or 0.12, math.clamp(curve, 0, 100) / 100)
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

-- Replay Loop Logic
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

-- Auto-Clicker Logic
local function stopAutoClicker()
    if not autoClickEnabled then return end
    autoClickEnabled = false
    btnAutoClicker.Text = "Auto Clicker: OFF"
end

local function toggleAutoClicker()
    if autoClickEnabled then stopAutoClicker(); return end
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
            if waitTime > 0 then task.wait(waitTime) else RunService.Heartbeat:Wait(); nextTime = tick() end
        end
    end)
end

-- Set Click Position Logic
local positionSetConnection = nil
local function stopSetPosition()
    if not waitingForPosition then return end
    waitingForPosition = false
    btnSetPosition.Text = "Set Position"
    if positionSetConnection then positionSetConnection:Disconnect(); positionSetConnection = nil end
end

local function setClickPosition()
    if waitingForPosition then stopSetPosition(); return end
    stopAllProcesses()
    waitingForPosition = true
    btnSetPosition.Text = "Tap anywhere..."
    positionSetConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if waitingForPosition and not gameProcessed and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            local pos = Vector2.new(input.Position.X, input.Position.Y)
            if isOverOurGUI(pos) then return end
            clickPosition = pos
            stopSetPosition()
            btnSetPosition.Text = "Position Set!"
            task.delay(1, function() if btnSetPosition.Text == "Position Set!" then btnSetPosition.Text = "Set Position" end end)
        end
    end)
end

-- Utility
stopAllProcesses = function()
    stopAutoClicker(); stopRecording(); stopReplay(); stopReplayLoop(); stopSetPosition()
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
btnStartRecording.MouseButton1Click:Connect(toggleRecording)
btnReplayClicks.MouseButton1Click:Connect(toggleReplay)
btnReplayLoop.MouseButton1Click:Connect(toggleReplayLoop)

btnApplySettings.MouseButton1Click:Connect(function()
    local function parseOffset(text)
        text = tostring(text or ""):gsub("%s+", "")
        if text:match("%%$") then
            local num = tonumber(text:sub(1, -2)); if num then return { mode = "pct", value = num / 100 } end
        else
            local num = tonumber(text); if num then return { mode = "px", value = num } end
        end
    end
    local xRaw, yRaw, curve = parseOffset(offsetXInput.Text), parseOffset(offsetYInput.Text), tonumber(swipeCurveInput.Text)
    if xRaw and yRaw and curve ~= nil then
        activeXOffsetRaw, activeYOffsetRaw = xRaw, yRaw
        local c = math.clamp(curve, 0, 100) / 100; swipeCurveInput.Text = tostring(c * 100)
        updateCalibration()
        sendNotification("Settings Updated", ("X: %s, Y: %s, Curve: %.1f%%. Calibrated."):format(offsetXInput.Text, offsetYInput.Text, c * 100))
    else
        sendNotification("Invalid Input", "Offsets must be numbers (px) or percent (e.g. 2%).")
        offsetXInput.Text = (activeXOffsetRaw.mode == "px") and tostring(activeXOffsetRaw.value) or tostring(activeXOffsetRaw.value * 100) .. "%"
        offsetYInput.Text = (activeYOffsetRaw.mode == "px") and tostring(activeYOffsetRaw.value) or tostring(activeYOffsetRaw.value * 100) .. "%"
    end
end)

toggleGuiBtn.MouseButton1Click:Connect(function()
    guiHidden = not guiHidden; mainFrame.Visible = not guiHidden
    toggleGuiBtn.Text = guiHidden and "Show" or "Hide"
end)

submitBtn.MouseButton1Click:Connect(function()
    local enteredKey = keyBox.Text
    local expectedKey = "key_not_fetched"
    local httpGet = game.HttpGet or HttpGet
    if not httpGet then sendNotification("Key Check Failed", "No HttpGet function found."); return end
    local success, response = pcall(function() return httpGet("https://pastebin.com/raw/v4eb6fHw", true) end)
    if success and response then expectedKey = response:match("%S+") or "pastebin_read_error"
    else sendNotification("Key Check Failed", "Could not fetch key. Check network.") end
    
    if enteredKey == expectedKey or enteredKey == "happybirthday Mohamednigga" then
        sendNotification("Access Granted", "Welcome!")
        keyEntry:Destroy()
        mainFrame.Visible = true; toggleGuiBtn.Visible = true
        task.wait(1)
        local measurer = Instance.new("Frame", mainGui)
        measurer.Size = UDim2.new(1, 0, 1, 0); measurer.IgnoreGuiInset = true
        task.wait(0.1)
        measurer:Destroy()
        updateCalibration()
    else
        keyBox.Text = ""; keyBox.PlaceholderText = "Invalid key, try again"
        sendNotification("Access Denied", "Incorrect key.")
    end
end)

copyBtn.MouseButton1Click:Connect(function()
    local keyLink = "https.loot-link.com/s?AVreZic8"
    if setclipboard then
        local success, err = pcall(function() setclipboard(keyLink) end)
        if success then sendNotification("Link Copied", "Key link copied to clipboard.")
        else sendNotification("Copy Failed", "setclipboard() error: " .. tostring(err)) end
    else
        keyBox.Text = keyLink; copyBtn.Text = "Copy From Box"
        sendNotification("Now Copy", "Select and copy the link from the text box.")
    end
end)

tabAutoClicker.MouseButton1Click:Connect(function() selectTab("auto") end)
tabRecorder.MouseButton1Click:Connect(function() selectTab("record") end)
tabSettings.MouseButton1Click:Connect(function() selectTab("settings")end)

-- Initial UI state & notes
selectTab("auto")
task.spawn(initialize_VIM)

--[[
-- QUICK VIM TEST SCRIPT
task.spawn(function()
    task.wait(5)
    print("Testing VIM...")
    if vmAvailable and VirtualInputManager then
        print("VIM exists!")
        pcall(function()
            VirtualInputManager:SendMouseMoveEvent(500, 500)
            print("Move success!")
            task.wait(0.1)
            VirtualInputManager:SendMouseButtonEvent(500, 500, 0, true, false)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(500, 500, 0, false, false)
            print("Click success!")
        end)
    else
        print("VIM NOT AVAILABLE!")
    end
end)
]]
