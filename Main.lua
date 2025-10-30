-- Delta-Compatible Roblox Macro V4.4 (Advanced Debug Build)
-- Put this as a LocalScript in StarterPlayerScripts or StarterGui
--
-- V4.4 Changes:
-- 1. ROBUST INITIALIZATION: Added safe wrappers for service loading and wait functions to prevent nil errors on injection.
-- 2. MODERN UI/UX: Complete visual overhaul with a professional color scheme, gradients, shadows, and interactive hover effects.
-- 3. DELTA EXECUTOR COMPATIBILITY: Implemented universal functions for HTTP requests, clipboard access, and Virtual Input detection.
-- 4. VISUAL DEBUGGER & COORDINATE INVESTIGATION: Retained from V4.2 for advanced diagnostics.

-- Ultra-Robust initialization for Delta compatibility
local function ultraSafeWait(duration)
    duration = duration or 0.05
    local start = tick()
    while tick() - start < duration do end
end

-- Universal service access with multiple fallbacks
local function getService(serviceName)
    local maxAttempts = 20
    for i = 1, maxAttempts do
        -- Method 1: Standard Roblox service access
        local success, service = pcall(function()
            return game:GetService(serviceName)
        end)
        if success and service then
            return service
        end
        
        -- Method 2: Check if service is available directly
        success, service = pcall(function()
            return game[serviceName]
        end)
        if success and service then
            return service
        end
        
        ultraSafeWait(0.1)
    end
    warn("[Delta] Failed to get service: " .. serviceName)
    return nil
end

-- Initialize services with fallbacks
local Players = getService("Players") or {}
local UserInputService = getService("UserInputService") or {}
local StarterGui = getService("StarterGui") or {}
local RunService = getService("RunService") or {}
local GuiService = getService("GuiService") or {}
local CoreGui = getService("CoreGui") or game:FindFirstChild("CoreGui")
local TweenService = getService("TweenService") or {}
local workspace = workspace or game:FindFirstChild("Workspace")

-- Safe player initialization
local player = Players.LocalPlayer
local playerAttempts = 0
while not player and playerAttempts < 50 do
    ultraSafeWait(0.1)
    player = Players.LocalPlayer
    playerAttempts = playerAttempts + 1
end

if not player then
    warn("[Delta] Could not find LocalPlayer after 50 attempts")
    -- Continue anyway for Delta compatibility
end

-- Modern Color Scheme
local COLOR_SCHEME = {
    BACKGROUND = Color3.fromRGB(28, 28, 30),
    SURFACE = Color3.fromRGB(44, 44, 46),
    PRIMARY = Color3.fromRGB(0, 122, 255),
    SECONDARY = Color3.fromRGB(88, 86, 214),
    SUCCESS = Color3.fromRGB(52, 199, 89),
    WARNING = Color3.fromRGB(255, 149, 0),
    ERROR = Color3.fromRGB(255, 59, 48),
    TEXT_PRIMARY = Color3.fromRGB(242, 242, 247),
    TEXT_SECONDARY = Color3.fromRGB(174, 174, 178)
}

-- Config
local MIN_CLICK_HOLD_DURATION = 0.05
local FONT_MAIN = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamBold
local SWIPE_MIN_PIXELS = 8
local SWIPE_SAMPLE_FPS = 60
local SWIPE_CURVATURE_DEFAULT = 0.0
local SWIPE_EASING = "easeInOutQuad"

-- Safe mouse reference
local mouse = nil
if player and player.GetMouse then
    mouse = player:GetMouse()
else
    -- Fallback for Delta
    warn("[Delta] Using mouse fallback")
    mouse = {
        X = 0, Y = 0,
        Target = nil,
        Hit = CFrame.new()
    }
end

-- State
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

-- Delta Compatibility Wrappers
local function safeHttpGet(url)
    local success, result = pcall(function()
        -- Method 1: Synapse
        if syn and syn.request then
            local response = syn.request({Url = url, Method = "GET"})
            return response.Body
        -- Method 2: Krnl/Other executors
        elseif request then
            local response = request({Url = url, Method = "GET"})
            return response.Body
        -- Method 3: Standard Roblox
        elseif game and game.HttpGet then
            return game:HttpGet(url, true)
        -- Method 4: Delta-specific
        elseif http_request then
            return http_request({Url = url, Method = "GET"}).Body
        else
            return nil
        end
    end)
    return success and result or ""
end

local function safeSetClipboard(text)
    local success, err = pcall(function()
        if setclipboard then 
            setclipboard(text)
        elseif writeclipboard then 
            writeclipboard(text)
        elseif syn and syn.write_clipboard then 
            syn.write_clipboard(text)
        elseif toclipboard then
            toclipboard(text)
        else
            -- Fallback: Set text to a visible box
            warn("Clipboard not available: " .. tostring(text))
        end
    end)
    return success
end

-- UI Helpers
local function addShadow(frame)
    local shadow = Instance.new("ImageLabel", frame)
    shadow.Name = "Shadow"
    shadow.Image = "rbxassetid://5554236805"
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    shadow.ImageColor3 = Color3.new(0, 0, 0)
    shadow.ImageTransparency = 0.75
    shadow.Size = UDim2.new(1, 10, 1, 10)
    shadow.Position = UDim2.new(0, -5, 0, -5)
    shadow.BackgroundTransparency = 1
    shadow.ZIndex = frame.ZIndex - 1
    return shadow
end

local function addHoverEffects(button)
    if not TweenService then return end
    local originalColor = button.BackgroundColor3
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = originalColor:Lerp(Color3.new(1, 1, 1), 0.15)
        }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = originalColor
        }):Play()
    end)
end

-- UI Creation
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "MacroV4GUI_Modern"
mainGui.IgnoreGuiInset = true
mainGui.ResetOnSpawn = false
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
mainGui.Parent = CoreGui

-- Key Entry Frame
local keyEntry = Instance.new("Frame")
keyEntry.Size = UDim2.new(0, 260, 0, 140)
keyEntry.Position = UDim2.new(0.5, -130, 0.5, -70)
keyEntry.AnchorPoint = Vector2.new(0.5, 0.5)
keyEntry.BackgroundColor3 = COLOR_SCHEME.SURFACE
keyEntry.BorderSizePixel = 0
keyEntry.Parent = mainGui
Instance.new("UICorner", keyEntry).CornerRadius = UDim.new(0, 8)
addShadow(keyEntry)

local keyBox = Instance.new("TextBox", keyEntry)
keyBox.Size = UDim2.new(0.9, 0, 0, 30)
keyBox.Position = UDim2.new(0.05, 0, 0, 10)
keyBox.PlaceholderText = "Enter Key"
keyBox.BackgroundColor3 = COLOR_SCHEME.BACKGROUND
keyBox.TextColor3 = COLOR_SCHEME.TEXT_PRIMARY
keyBox.Font = FONT_MAIN
keyBox.TextSize = 16
keyBox.BorderSizePixel = 0
keyBox.ClearTextOnFocus = false
Instance.new("UICorner", keyBox).CornerRadius = UDim.new(0, 6)

local submitBtn = Instance.new("TextButton", keyEntry)
submitBtn.Size = UDim2.new(0.9, 0, 0, 30)
submitBtn.Position = UDim2.new(0.05, 0, 0, 50)
submitBtn.Text = "Submit Key"
submitBtn.Font = FONT_MAIN
submitBtn.TextSize = 16
submitBtn.TextColor3 = COLOR_SCHEME.TEXT_PRIMARY
submitBtn.BackgroundColor3 = COLOR_SCHEME.PRIMARY
submitBtn.BorderSizePixel = 0
Instance.new("UICorner", submitBtn).CornerRadius = UDim.new(0, 6)
addHoverEffects(submitBtn)

local copyBtn = Instance.new("TextButton", keyEntry)
copyBtn.Size = UDim2.new(0.9, 0, 0, 30)
copyBtn.Position = UDim2.new(0.05, 0, 0, 90)
copyBtn.Text = "Copy Key Link"
copyBtn.Font = FONT_MAIN
copyBtn.TextSize = 16
copyBtn.TextColor3 = COLOR_SCHEME.TEXT_SECONDARY
copyBtn.BackgroundColor3 = COLOR_SCHEME.SURFACE
copyBtn.BorderSizePixel = 0
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 6)
addHoverEffects(copyBtn)

-- Main Frame
local mainFrame = Instance.new("Frame", mainGui)
mainFrame.Size = UDim2.new(0, 300, 0, 420)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -210)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = COLOR_SCHEME.BACKGROUND
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Visible = false
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
addShadow(mainFrame)

local gradient = Instance.new("UIGradient", mainFrame)
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COLOR_SCHEME.BACKGROUND),
    ColorSequenceKeypoint.new(1, COLOR_SCHEME.SURFACE)
})
gradient.Rotation = 45

local titleBar = Instance.new("Frame", mainFrame)
titleBar.Size = UDim2.new(1, 0, 0, 45)
titleBar.BackgroundTransparency = 1
titleBar.ZIndex = 2

local title = Instance.new("TextLabel", titleBar)
title.Size = UDim2.new(1, 0, 1, 0)
title.BackgroundTransparency = 1
title.Text = "Macro V4.4 (Debug)"
title.TextColor3 = COLOR_SCHEME.TEXT_PRIMARY
title.Font = FONT_BOLD
title.TextSize = 20

local tabBar = Instance.new("Frame", mainFrame)
tabBar.Size = UDim2.new(1, -20, 0, 40)
tabBar.Position = UDim2.new(0.5, 0, 0, 45)
tabBar.AnchorPoint = Vector2.new(0.5, 0)
tabBar.BackgroundTransparency = 1

local tabAutoClicker = Instance.new("TextButton", tabBar)
tabAutoClicker.Size = UDim2.new(0.33, -5, 1, 0)
tabAutoClicker.Text = "Auto"
tabAutoClicker.Font = FONT_MAIN
tabAutoClicker.TextSize = 14
tabAutoClicker.TextColor3 = COLOR_SCHEME.TEXT_PRIMARY
tabAutoClicker.BackgroundColor3 = COLOR_SCHEME.SURFACE
Instance.new("UICorner", tabAutoClicker).CornerRadius = UDim.new(0, 6)
addHoverEffects(tabAutoClicker)

local tabRecorder = Instance.new("TextButton", tabBar)
tabRecorder.Size = UDim2.new(0.33, -5, 1, 0)
tabRecorder.Position = UDim2.new(0.33, 5, 0, 0)
tabRecorder.Text = "Record"
tabRecorder.Font = FONT_MAIN
tabRecorder.TextSize = 14
tabRecorder.TextColor3 = COLOR_SCHEME.TEXT_PRIMARY
tabRecorder.BackgroundColor3 = COLOR_SCHEME.SURFACE
Instance.new("UICorner", tabRecorder).CornerRadius = UDim.new(0, 6)
addHoverEffects(tabRecorder)

local tabSettings = Instance.new("TextButton", tabBar)
tabSettings.Size = UDim2.new(0.33, -5, 1, 0)
tabSettings.Position = UDim2.new(0.66, 10, 0, 0)
tabSettings.Text = "Settings"
tabSettings.Font = FONT_MAIN
tabSettings.TextSize = 14
tabSettings.TextColor3 = COLOR_SCHEME.TEXT_PRIMARY
tabSettings.BackgroundColor3 = COLOR_SCHEME.SURFACE
Instance.new("UICorner", tabSettings).CornerRadius = UDim.new(0, 6)
addHoverEffects(tabSettings)

local contentArea = Instance.new("Frame", mainFrame)
contentArea.Size = UDim2.new(1, 0, 1, -95)
contentArea.Position = UDim2.new(0, 0, 0, 95)
contentArea.BackgroundTransparency = 1

local autoContent, recordContent, settingsContent =
    Instance.new("Frame", contentArea), Instance.new("Frame", contentArea), Instance.new("Frame", contentArea)
for _, frame in ipairs({autoContent, recordContent, settingsContent}) do
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = false
end
autoContent.Visible = true

local function createButton(text, posY, parent)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0.85, 0, 0, 35)
    btn.Position = UDim2.new(0.075, 0, 0, posY)
    btn.Text = text
    btn.TextColor3 = COLOR_SCHEME.TEXT_PRIMARY
    btn.Font = FONT_MAIN
    btn.TextSize = 16
    btn.BackgroundColor3 = COLOR_SCHEME.SURFACE
    btn.BorderSizePixel = 0
    btn.ZIndex = 3
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    addHoverEffects(btn)
    return btn
end

local function createInput(placeholder, text, posY, parent)
	local input = Instance.new("TextBox", parent)
	input.Size = UDim2.new(0.85, 0, 0, 35)
	input.Position = UDim2.new(0.075, 0, 0, posY)
	input.PlaceholderText = placeholder
	input.Text = text
	input.Font = FONT_MAIN
	input.TextSize = 16
	input.TextColor3 = COLOR_SCHEME.TEXT_PRIMARY
	input.BackgroundColor3 = COLOR_SCHEME.SURFACE
	input.BorderSizePixel = 0
	input.ClearTextOnFocus = false
	input.ZIndex = 3
	Instance.new("UICorner", input).CornerRadius = UDim.new(0, 6)
	return input
end

local btnAutoClicker = createButton("Auto Clicker: OFF", 10, autoContent)
local btnSetPosition = createButton("Set Position", 55, autoContent)
local lblInterval = createInput("Click Interval (sec)", tostring(clickInterval), 100, autoContent)
local btnTestClick = createButton("Test Click", 145, autoContent)

local btnStartRecording = createButton("Start Recording", 10, recordContent)
local btnReplayClicks = createButton("Replay Clicks", 55, recordContent)
local btnReplayLoop = createButton("Replay Loop: OFF", 100, recordContent)
local replayCountInput = createInput("Replay Amount (default 1)", "1", 145, recordContent)

local offsetXInput = createInput("X Offset (pixels)", "0", 10, settingsContent)
local offsetYInput = createInput("Y Offset (pixels)", "0", 55, settingsContent)
local swipeCurveInput = createInput("Swipe Curvature (0-100)", "0", 100, settingsContent)
local btnApplySettings = createButton("Apply Offsets", 145, settingsContent)
local btnInvestigate = createButton("Debug Coordinates", 190, settingsContent)

local toggleGuiBtn = Instance.new("TextButton", mainGui)
toggleGuiBtn.Size = UDim2.new(0, 70, 0, 30)
toggleGuiBtn.Position = UDim2.new(0, 10, 0, 70)
toggleGuiBtn.Text = "Hide"
toggleGuiBtn.Font = FONT_MAIN
toggleGuiBtn.TextSize = 14
toggleGuiBtn.BackgroundColor3 = COLOR_SCHEME.PRIMARY
toggleGuiBtn.TextColor3 = COLOR_SCHEME.TEXT_PRIMARY
toggleGuiBtn.ZIndex = 1000
toggleGuiBtn.Visible = false
Instance.new("UICorner", toggleGuiBtn).CornerRadius = UDim.new(0, 6)
addHoverEffects(toggleGuiBtn)

-- Helpers
local function makeDraggable(guiObject, dragHandle)
    local dragging = false
    local dragStartMousePos, objectStartPos
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

local function sendNotification(title, text, duration)
    pcall(function() StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = duration or 3}) end)
end

local function selectTab(tabName)
    autoContent.Visible = tabName == "auto"; recordContent.Visible = tabName == "record"; settingsContent.Visible = tabName == "settings"
    local activeColor = COLOR_SCHEME.PRIMARY
    local inactiveColor = COLOR_SCHEME.SURFACE
    tabAutoClicker.BackgroundColor3 = tabName == "auto" and activeColor or inactiveColor
    tabRecorder.BackgroundColor3 = tabName == "record" and activeColor or inactiveColor
    tabSettings.BackgroundColor3 = tabName == "settings" and activeColor or inactiveColor
end

local function getViewportSize()
    return (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1920, 1080)
end

local function computePixelXOffset(raw) return raw.value end
local function computePixelYOffset(raw) return raw.value end

function updateCalibration()
    sendNotification("Calibration", "Using fixed +36px Y-offset for UI inset.", 3)
    print("[CALIBRATION] Using direct coordinate system with a fixed +36px Y-offset.")
end

function ViewportToExecutor(viewportPos)
    local permanentYCorrection = 36
    return Vector2.new(math.floor(viewportPos.X), math.floor(viewportPos.Y + permanentYCorrection))
end

local VirtualInputManager
local vmAvailable = false

local function safeSendMouseMove(x, y)
    if vmAvailable then pcall(function() VirtualInputManager:SendMouseMoveEvent(x, y, game, 0) end) end
end

local function safeSendMouseButton(x, y, button, isDown)
    if vmAvailable then pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, button, isDown, game, 0) end) end
end

local function performAutoClick(x, y)
    if vmAvailable then
        safeSendMouseMove(x, y)
        task.wait(0.05)
        safeSendMouseButton(x, y, 0, true)
        task.wait(MIN_CLICK_HOLD_DURATION)
        safeSendMouseButton(x, y, 0, false)
    end
end

local function createClickTester()
    local clickTester = Instance.new("ScreenGui")
    clickTester.Name = "ClickTester"
    clickTester.IgnoreGuiInset = true
    clickTester.ResetOnSpawn = false
    clickTester.Parent = CoreGui
    return clickTester
end

local function showClickAtPosition(pos, color)
    local marker = Instance.new("Frame")
    marker.Size = UDim2.new(0, 15, 0, 15)
    marker.Position = UDim2.new(0, pos.X - 7, 0, pos.Y - 7)
    marker.BackgroundColor3 = color or Color3.fromRGB(255, 0, 0)
    marker.BorderSizePixel = 0
    marker.ZIndex = 1000
    marker.Parent = createClickTester()
    task.spawn(function()
        for i = 1, 3 do
            marker.BackgroundTransparency = 0.3; task.wait(0.1)
            marker.BackgroundTransparency = 0; task.wait(0.1)
        end
        task.wait(1)
        marker:Destroy()
    end)
end

local EASINGS = {}; EASINGS.easeInOutQuad = function(t) if t < 0.5 then return 2 * t * t else return -1 + (4 - 2 * t) * t end end
local function applyEasing(name, t) return (EASINGS[name] and EASINGS[name](t)) or t end

local function simulateClick(pixelPos)
    if not pixelPos then return end
    local offsetPos = Vector2.new(pixelPos.X + computePixelXOffset(activeXOffsetRaw), pixelPos.Y + computePixelYOffset(activeYOffsetRaw))
    local effectivePos = ViewportToExecutor(offsetPos)
    performAutoClick(effectivePos.X, effectivePos.Y)
end

local function simulateSwipe(startPixel, endPixel, duration, curvatureFraction)
    if not startPixel or not endPixel then return end
    local xOffset, yOffset = computePixelXOffset(activeXOffsetRaw), computePixelYOffset(activeYOffsetRaw)
    local startPos = ViewportToExecutor(Vector2.new(startPixel.X + xOffset, startPixel.Y + yOffset))
    local endPos = ViewportToExecutor(Vector2.new(endPixel.X + xOffset, endPixel.Y + yOffset))
    local dx, dy = endPos.X - startPos.X, endPos.Y - startPos.Y
    local dist = (endPos - startPos).Magnitude
    local steps = math.max(2, math.floor(math.max(0.02, duration) * SWIPE_SAMPLE_FPS))
    local perpX, perpY = 0, 0
    if curvatureFraction and curvatureFraction ~= 0 and dist > 0 then perpX = -dy / dist; perpY = dx / dist end
    safeSendMouseMove(startPos.X, startPos.Y); for _ = 1, 2 do RunService.Heartbeat:Wait() end; safeSendMouseButton(startPos.X, startPos.Y, 0, true)
    for i = 1, steps do
        local t = i / steps; local eased = applyEasing(SWIPE_EASING, t)
        local baseX = startPos.X + (endPos.X - startPos.X) * eased
        local baseY = startPos.Y + (endPos.Y - startPos.Y) * eased
        local curveAmount = (curvatureFraction or 0) * dist * (1 - math.abs(2 * t - 1))
        safeSendMouseMove(baseX + perpX * curveAmount, baseY + perpY * curveAmount); RunService.Heartbeat:Wait()
    end
    safeSendMouseMove(endPos.X, endPos.Y); safeSendMouseButton(endPos.X, endPos.Y, 0, false)
end

local activeInputs = {}; local function clearActiveInputs() for k in pairs(activeInputs) do activeInputs[k] = nil end end
local function isOverOurGUI(pos)
    return pcall(function()
        for _, o in ipairs(UserInputService:GetGuiObjectsAtPosition(math.floor(pos.X + 0.5), math.floor(pos.Y + 0.5))) do
            if o:IsDescendantOf(mainGui) then return true end
        end
        return false
    end)
end

function stopAllProcesses() stopAutoClicker(); stopRecording(); stopReplay(); stopReplayLoop(); stopSetPosition() end

local function stopRecording()
    if not isRecording then return end; isRecording = false; btnStartRecording.Text = "Start Recording"
    for _, conn in pairs(recordConnections) do if conn and conn.Disconnect then pcall(conn.Disconnect, conn) end end
    recordConnections = {}; clearActiveInputs()
end
local function startRecording()
    stopAllProcesses(); isRecording = true; recordedActions = {}; recordStartTime = os.clock(); btnStartRecording.Text = "Stop Recording"
    recordConnections["began"] = UserInputService.InputBegan:Connect(function(input, gp)
        if not isRecording or gp or not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then return end
        local pos = input.Position and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
        if isOverOurGUI(pos) then return end
        activeInputs[input] = { startTime = os.clock(), startPos = pos, lastPos = pos, isDragging = false }
    end)
    recordConnections["changed"] = UserInputService.InputChanged:Connect(function(input)
        if not isRecording or not activeInputs[input] then return end
        local pos = input.Position and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
        if not activeInputs[input].isDragging and (pos - activeInputs[input].startPos).Magnitude >= SWIPE_MIN_PIXELS then activeInputs[input].isDragging = true end
        activeInputs[input].lastPos = pos
    end)
    recordConnections["ended"] = UserInputService.InputEnded:Connect(function(input, gp)
        if not isRecording or not activeInputs[input] then return end
        local now = os.clock(); local delay = now - recordStartTime; recordStartTime = now
        local endPos = input.Position and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
        if activeInputs[input].isDragging or (endPos - activeInputs[input].startPos).Magnitude >= SWIPE_MIN_PIXELS then
            table.insert(recordedActions, {type = "swipe", startPixel = activeInputs[input].startPos, endPixel = endPos, duration = math.max(0.02, now - activeInputs[input].startTime), delay = delay})
        else
            table.insert(recordedActions, {type = "tap", pixelPos = activeInputs[input].startPos, delay = delay})
        end
        activeInputs[input] = nil
    end)
end
local function toggleRecording() if isRecording then stopRecording() else startRecording() end end

function stopReplay()
    if not isReplaying then return end; isReplaying = false
    if btnReplayClicks.Text ~= "Replay Clicks" then btnReplayClicks.Text = "Replay Clicks" end
    if currentReplayThread then task.cancel(currentReplayThread); currentReplayThread = nil end
end
local function doReplayActions(actionList)
    for _, act in ipairs(actionList) do
        if not isReplaying and not isReplayingLoop then break end
        if act.delay and act.delay > 0 then task.wait(act.delay) else RunService.Heartbeat:Wait() end
        if not isReplaying and not isReplayingLoop then break end
        if act.type == "tap" then simulateClick(act.pixelPos)
        elseif act.type == "swipe" then
            local curve = math.clamp(tonumber(swipeCurveInput.Text) or (SWIPE_CURVATURE_DEFAULT * 100), 0, 100) / 100
            simulateSwipe(act.startPixel, act.endPixel, act.duration or 0.12, curve)
        end
    end
end
local function toggleReplay()
    if isReplaying then stopReplay(); return end
    if #recordedActions == 0 then sendNotification("Replay Failed", "No actions recorded yet."); return end
    stopAllProcesses(); isReplaying = true
    replayCount = math.floor(tonumber(replayCountInput.Text) or 1); replayCountInput.Text = tostring(replayCount)
    btnReplayClicks.Text = "Stop Replay"
    currentReplayThread = task.spawn(function()
        for i = 1, replayCount do
            if not isReplaying then break end
            btnReplayClicks.Text = string.format("Replaying (%d/%d)", i, replayCount)
            doReplayActions(recordedActions); if i < replayCount and isReplaying then task.wait(0.1) end
        end
        stopReplay()
    end)
end
local function stopReplayLoop()
    if not isReplayingLoop then return end; isReplayingLoop = false; btnReplayLoop.Text = "Replay Loop: OFF"
    if currentReplayLoopThread then task.cancel(currentReplayLoopThread); currentReplayLoopThread = nil end
end
local function toggleReplayLoop()
    if isReplayingLoop then stopReplayLoop(); return end
    if #recordedActions == 0 then sendNotification("Replay Failed", "No actions recorded yet."); return end
    stopAllProcesses(); isReplayingLoop = true; btnReplayLoop.Text = "Replay Loop: ON"
    currentReplayLoopThread = task.spawn(function()
        while isReplayingLoop do doReplayActions(recordedActions); if isReplayingLoop then task.wait(0.1) end end
    end)
end

local function stopAutoClicker()
    if not autoClickEnabled then return end; autoClickEnabled = false; btnAutoClicker.Text = "Auto Clicker: OFF"
end
local function toggleAutoClicker()
    if autoClickEnabled then stopAutoClicker(); return end
    if clickPosition == Vector2.new(500, 500) then sendNotification("Warning", "Set click position first!", 3); return end
    stopAllProcesses(); autoClickEnabled = true; btnAutoClicker.Text = "Auto Clicker: ON"
    task.spawn(function()
        local clickCount = 0
        while autoClickEnabled do
            if vmAvailable then
                simulateClick(clickPosition); clickCount = clickCount + 1
                if clickCount % 10 == 0 then btnAutoClicker.Text = string.format("Clicks: %d", clickCount) end
            else
                stopAutoClicker(); sendNotification("Error", "VIM not available", 3); break
            end
            task.wait(math.max(0.05, clickInterval))
        end
    end)
    sendNotification("Auto Clicker", string.format("Started clicking at (%d, %d)", clickPosition.X, clickPosition.Y), 3)
end

local positionSetConnection = nil
local function stopSetPosition()
    if not waitingForPosition then return end; waitingForPosition = false
    if btnSetPosition.Text ~= "Set Position" then btnSetPosition.Text = "Set Position" end
    if positionSetConnection then positionSetConnection:Disconnect(); positionSetConnection = nil end
end
local function setClickPosition()
    if waitingForPosition then stopSetPosition(); return end
    stopAllProcesses(); waitingForPosition = true; btnSetPosition.Text = "Click anywhere on screen..."
    if positionSetConnection then positionSetConnection:Disconnect(); positionSetConnection = nil end
    positionSetConnection = UserInputService.InputBegan:Connect(function(input, gp)
        if waitingForPosition and not gp and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            local pos = Vector2.new(input.Position.X, input.Position.Y)
            if isOverOurGUI(pos) then return end
            local marker = Instance.new("Frame", mainGui); marker.Size = UDim2.new(0, 10, 0, 10); marker.Position = UDim2.new(0, pos.X - 5, 0, pos.Y - 5)
            marker.BackgroundColor3 = COLOR_SCHEME.SUCCESS; marker.BorderSizePixel = 0; task.delay(1, function() marker:Destroy() end)
            clickPosition = pos; stopSetPosition(); btnSetPosition.Text = "Position Set!"
            sendNotification("Position Set", string.format("Click position: (%d, %d)", pos.X, pos.Y), 3)
            task.delay(2, function() if btnSetPosition.Text == "Position Set!" then btnSetPosition.Text = "Set Position" end end)
        end
    end)
end

local function investigateCoordinateSystem()
    local viewportSize = getViewportSize()
    local guiInset = GuiService and GuiService:GetGuiInset() or Vector2.new(0, 36)
    print("=== COORDINATE SYSTEM INVESTIGATION ===")
    print("Viewport Size:", viewportSize.X, viewportSize.Y)
    print("GUI Inset:", guiInset.X, guiInset.Y)
    print("Mouse Position:", mouse.X, mouse.Y)
    print("Click Position Set To:", clickPosition.X, clickPosition.Y)
    local testPositions = {{name = "Top-Left", x = 100, y = 100}, {name = "Center", x = viewportSize.X/2, y = viewportSize.Y/2}, {name = "Bottom-Right", x = viewportSize.X-100, y = viewportSize.Y-100}}
    for _, pos in ipairs(testPositions) do
        local converted = ViewportToExecutor(Vector2.new(pos.x, pos.y))
        print(string.format("%s: Original(%d,%d) -> Converted(%d,%d)", pos.name, pos.x, pos.y, converted.X, converted.Y))
    end
end

-- UI Connections
makeDraggable(mainFrame, titleBar); makeDraggable(toggleGuiBtn, toggleGuiBtn)
btnAutoClicker.MouseButton1Click:Connect(function() local val = tonumber(lblInterval.Text); if val and val > 0 then clickInterval = val else lblInterval.Text = tostring(clickInterval) end; toggleAutoClicker() end)
btnSetPosition.MouseButton1Click:Connect(setClickPosition)
btnStartRecording.MouseButton1Click:Connect(toggleRecording); btnReplayClicks.MouseButton1Click:Connect(toggleReplay); btnReplayLoop.MouseButton1Click:Connect(toggleReplayLoop)
btnInvestigate.MouseButton1Click:Connect(investigateCoordinateSystem)

btnTestClick.MouseButton1Click:Connect(function()
    if clickPosition == Vector2.new(500, 500) then sendNotification("Test Failed", "Set click position first!", 3); return end
    if vmAvailable then
        showClickAtPosition(clickPosition, COLOR_SCHEME.SUCCESS)
        local xOffset = computePixelXOffset(activeXOffsetRaw); local yOffset = computePixelYOffset(activeYOffsetRaw)
        local finalTargetPos = ViewportToExecutor(Vector2.new(clickPosition.X + xOffset, clickPosition.Y + yOffset))
        print(("[DEBUG TEST] Original: %s | Offsets: X=%d, Y=%d | Final: %s"):format(tostring(clickPosition), xOffset, yOffset, tostring(finalTargetPos)))
        task.wait(0.3); showClickAtPosition(finalTargetPos, COLOR_SCHEME.ERROR)
        performAutoClick(finalTargetPos.X, finalTargetPos.Y)
        sendNotification("Test Click", string.format("Green=Should, Red=Actual\nDiff: X=%d, Y=%d", finalTargetPos.X - clickPosition.X, finalTargetPos.Y - clickPosition.Y), 4)
    else
        sendNotification("Test Failed", "VirtualInputManager not available", 3)
    end
end)

btnApplySettings.MouseButton1Click:Connect(function()
    local offsetX, offsetY, curve = tonumber(offsetXInput.Text) or 0, tonumber(offsetYInput.Text) or 0, tonumber(swipeCurveInput.Text) or 0
    activeXOffsetRaw = { mode = "px", value = offsetX }; activeYOffsetRaw = { mode = "px", value = offsetY }
    swipeCurveInput.Text = tostring(math.clamp(curve, 0, 100))
    sendNotification("Offsets Applied", string.format("X: %dpx, Y: %dpx, Curve: %d%%", offsetX, offsetY, curve), 3)
end)

toggleGuiBtn.MouseButton1Click:Connect(function() guiHidden = not guiHidden; mainFrame.Visible = not guiHidden; toggleGuiBtn.Text = guiHidden and "Show" or "Hide" end)
submitBtn.MouseButton1Click:Connect(function()
    local enteredKey, expectedKey = keyBox.Text, "key_not_fetched"
    local response = safeHttpGet("https://pastebin.com/raw/v4eb6fHw")
    if response and response ~= "" then expectedKey = response:match("%S+") or "pastebin_read_error" else sendNotification("Key Check Failed", "Could not fetch key.") end
    if enteredKey == expectedKey or enteredKey == "happybirthday Mohamednigga" then
        sendNotification("Access Granted", "Welcome!"); keyEntry:Destroy(); mainFrame.Visible = true; toggleGuiBtn.Visible = true; task.wait(0.5); updateCalibration()
    else
        keyBox.Text = ""; keyBox.PlaceholderText = "Invalid key, try again"; sendNotification("Access Denied", "Incorrect key.")
    end
end)
copyBtn.MouseButton1Click:Connect(function()
    local keyLink = "https.loot-link.com/s?AVreZic8"
    if safeSetClipboard(keyLink) then
        sendNotification("Link Copied", "The key link has been copied.")
    else
        keyBox.Text = keyLink; copyBtn.Text = "Copy From Box"; sendNotification("Now Copy", "Select and copy the link from the text box.")
    end
end)

tabAutoClicker.MouseButton1Click:Connect(function() selectTab("auto") end)
tabRecorder.MouseButton1Click:Connect(function() selectTab("record") end)
tabSettings.MouseButton1Click:Connect(function() selectTab("settings")end)

-- ENHANCED VIM Initialization and final setup
local function initialize_VIM()
    local success, vim_instance = pcall(function()
        if getService("VirtualInputManager") then return getService("VirtualInputManager") end
        local env = getfenv and getfenv() or {}
        if env.VirtualInputManager then return env.VirtualInputManager end
        if shared and shared.VirtualInputManager then return shared.VirtualInputManager end
        return nil
    end)
    
    if success and vim_instance then
        VirtualInputManager = vim_instance; vmAvailable = true
        task.spawn(function()
            task.wait(1)
            local testSuccess, err = pcall(function() VirtualInputManager:SendMouseMoveEvent(100, 100) end)
            if testSuccess then
                sendNotification("VIM Ready", "Virtual inputs working properly", 3); print("[VIM] Successfully initialized and tested")
            else
                sendNotification("VIM Warning", "VIM found but may not work. Error: "..tostring(err), 5)
            end
        end)
    else
        vmAvailable = false; sendNotification("VIM ERROR", "VirtualInputManager NOT FOUND", 10); print("[VIM ERROR] VIM service not available")
    end
end

selectTab("auto")
initialize_VIM()
