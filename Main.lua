-- This is the COMBINED Macro Script (Recorder Only)
-- Execute this single file in Delta.
-- Key, AutoClicker, and Settings have been removed.
-- DEFINITIVE FIX v2: Hardcoded a (44, 36) inset.
-- The pcall() fails, and (0, 36) was wrong for the X-axis.
-- 44px is a standard "safe area" inset for mobile.

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

-- --- START OF UI CODE ---

local FONT_MAIN = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamBold

-- --- Main ScreenGui ---
mainGui = Instance.new("ScreenGui")
mainGui.Name = "MacroV2GUI"
mainGui.IgnoreGuiInset = true
mainGui.ResetOnSpawn = false
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
mainGui.Parent = CoreGui

-- --- Main Frame ---
mainFrame = Instance.new("Frame", mainGui)
mainFrame.Name = "MacroFrame"
mainFrame.Size = UDim2.new(0, 260, 0, 220) -- Reduced height
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
title.Text = "Macro Recorder" -- Renamed title
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = FONT_BOLD
title.TextSize = 22
title.ZIndex = 2

-- --- Content Area (No tabs needed) ---
contentArea = Instance.new("Frame", mainFrame)
contentArea.Size = UDim2.new(1, 0, 1, -40) -- Fills space below title
contentArea.Position = UDim2.new(0, 0, 0, 40)
contentArea.BackgroundTransparency = 1

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

-- --- Recorder Content (placed directly in contentArea) ---
btnStartRecording = createButton("Start Recording", 10, contentArea)
btnReplayClicks = createButton("Replay Clicks", 50, contentArea)
btnReplayLoop = createButton("Replay Loop: OFF", 90, contentArea)

replayCountInput = Instance.new("TextBox", contentArea)
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
toggleGuiBtn.Visible = false -- Will be made visible at the end
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

-- --- END OF UI CODE ---


-- --- START OF CORE CODE ---

-- --- Config ---
local MIN_CLICK_HOLD_DURATION = 0.05
local SWIPE_MIN_PIXELS = 8
local SWIPE_SAMPLE_FPS = 60
local SWIPE_CURVATURE_DEFAULT = 0.0 -- Hard-coded curvature
local SWIPE_EASING = "easeInOutQuad"

-- --- State Variables ---
local isRecording = false
local recordedActions = {}
local recordStartTime = 0
local recordConnections = {}

local isReplaying = false
local replayCount = 1
local currentReplayThread = nil

local isReplayingLoop = false
local currentReplayLoopThread = nil

local guiHidden = false

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

-- --- DEFINITIVE FIX v2: Hardcode a (44, 36) Inset ---
-- The pcall() to StarterGui:GetGuiInset() fails in executors.
-- We hardcode a 36px Y offset (Top Bar) and a 44px X offset (Mobile Safe Area).
local HARDCODED_INSET = Vector2.new(44, 36)

-- Helper to convert recorded viewport coordinates to absolute VIM coordinates
local function ViewportToAbsolute(viewportPos)
    -- VIM expects absolute screen coordinates, but input.Position
    -- gives viewport coordinates (below the top bar). We add the inset.
    return viewportPos + HARDCODED_INSET
end
-- --- END OF FIX ---


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
    
    -- FIX: Convert viewport coordinates to absolute coordinates for VIM
    local effectivePos = ViewportToAbsolute(pixelPos)
    
    safeSendMouseMove(effectivePos.X, effectivePos.Y)
    for _ = 1, 3 do RunService.Heartbeat:Wait() end
    safeSendMouseButton(effectivePos.X, effectivePos.Y, 0, true)
    task.wait(MIN_CLICK_HOLD_DURATION)
    safeSendMouseButton(effectivePos.X, effectivePos.Y, 0, false)
end

local function simulateSwipe(startPixel, endPixel, duration, curvatureFraction)
    if not startPixel or not endPixel then return end

    -- FIX: Convert viewport coordinates to absolute coordinates for VIM
    local startPos = ViewportToAbsolute(startPixel)
    local endPos = ViewportToAbsolute(endPixel)

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
    local stopRecording_impl
    local stopReplay_impl
    local stopReplayLoop_impl

    function stopAllProcesses()
        if stopRecording_impl then stopRecording_impl() end
        if stopReplay_impl then stopReplay_impl() end
        if stopReplayLoop_impl then stopReplayLoop_impl() end
    end
    
    return function(impls)
        stopRecording_impl = impls.stopRecording
        stopReplay_impl = impls.stopReplay
        stopReplayLoop_impl = impls.stopReplayLoop
    end
end

local assignStopFunctions = stopAllProcesses()

-- --- Recording Logic ---
local activeInputs = {}
local function clearActiveInputs()
    for k in pairs(activeInputs) do activeInputs[k] = nil end
end

local function isOverOurGUI(pos)
    local x, y = math.floor(pos.X + 0.5), math.floor(pos.Y + 0.5)
    local success, result = pcall(function()
        -- We record input.Position (Viewport), so we check against
        -- GetGuiObjectsAtPosition (also Viewport). This is consistent.
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
        
        -- Get Viewport coordinates
        local pos = input.Position and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
        
        if isOverOurGUI(pos) then return end
        activeInputs[input] = { startTime = os.clock(), startPos = pos, lastPos = pos, isDragging = false }
    end)

    recordConnections["changed"] = UserInputService.InputChanged:Connect(function(input)
        if not isRecording then return end
        local data = activeInputs[input]
        if not data then return end
        
        -- Get Viewport coordinates
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
        
        -- Get Viewfport coordinates
        local endPos = input.Position and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
        local moved = (endPos - data.startPos).Magnitude

        if data.isDragging or moved >= SWIPE_MIN_PIXELS then
            table.insert(recordedActions, {
                type = "swipe",
                startPixel = data.startPos, -- Store raw Viewport pos
                endPixel = endPos,         -- Store raw Viewport pos
                duration = math.max(0.02, now - data.startTime),
                delay = delay
            })
        else
            table.insert(recordedActions, {
                type = "tap",
                pixelPos = data.startPos, -- Store raw Viewport pos
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
            simulateClick(act.pixelPos) -- Pass raw Viewport pos
        elseif act.type == "swipe" then
            -- Use hard-coded curvature default since settings are removed
            simulateSwipe(act.startPixel, act.endPixel, act.duration or 0.12, SWIPE_CURVATURE_DEFAULT) -- Pass raw Viewport pos
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

-- --- Assign Stop Functions ---
assignStopFunctions({
    stopRecording = stopRecording,
    stopReplay = stopReplay,
    stopReplayLoop = stopReplayLoop
})

-- --- GUI Connections ---
btnStartRecording.MouseButton1Click:Connect(toggleRecording)
btnReplayClicks.MouseButton1Click:Connect(toggleReplay)
btnReplayLoop.MouseButton1Click:Connect(toggleReplayLoop)

toggleGuiBtn.MouseButton1Click:Connect(function()
    guiHidden = not guiHidden
    mainFrame.Visible = not guiHidden
    toggleGuiBtn.Text = guiHidden and "Show" or "Hide"
end)

-- --- Initial State ---
sendNotification("Macro Recorder Loaded", vmAvailable and "VIM (Patched) Found" or "CRITICAL: VIM NOT Found")

-- Make GUI visible now that script is loaded
mainFrame.Visible = true
toggleGuiBtn.Visible = true

-- --- END OF CORE CODE ---
