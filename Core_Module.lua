-- This is Core_Module.lua
-- It contains the "engine": all functions, logic, and state.
-- It is loaded by Main.lua *after* UI_Module.lua.
-- It finds the global UI elements and connects its functions to them.

-- --- Services & Config ---
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local workspace = workspace
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local MIN_CLICK_HOLD_DURATION = 0.05
local SWIPE_MIN_PIXELS = 8
local SWIPE_SAMPLE_FPS = 60
local SWIPE_CURVATURE_DEFAULT = 0.0
local SWIPE_EASING = "easeInOutQuad"

-- --- State Variables ---
-- These are local to the Core module
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
local function sendNotification(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = 3})
    end)
end

-- This function is now local, as it's only called by the tab buttons
local function selectTab(tabName)
    -- Assumes UI elements are global
    autoContent.Visible = tabName == "auto"
    recordContent.Visible = tabName == "record"
    settingsContent.Visible = tabName == "settings"
end

local function getViewportSize()
    local cam = workspace.CurrentCamera
    if cam and cam.ViewportSize then
        return cam.ViewportSize
    end
    return Vector2.new(1920, 1080)
end

-- toNormalized/fromNormalized are only used for % offsets
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
    if t < 0.5 then return 2 * t * t else return -1 + (4 - 2 * t) * t end
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
    if autoClickEnabled then stopAutoClicker() return end
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
    if btnSetPosition.Text ~= "Set Position" then btnSetPosition.Text = "Set Position" end
    if positionSetConnection then
        local connToDisconnect = positionSetConnection
        positionSetConnection = nil
        task.spawn(function()
            pcall(function() connToDisconnect:Disconnect() end)
        end)
    end
end

local function setClickPosition()
    if waitingForPosition then stopSetPosition() return end
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
                if btnSetPosition.Text == "Position Set!" then btnSetPosition.Text = "Set Position" end
            end)
        end
CH_MODULE_UPDATER_HTML -->
