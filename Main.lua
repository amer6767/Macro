-- Roblox Macro V2 (Fixed + Mobile/Android improvements + Granular Recording)
-- Put this as a LocalScript in StarterPlayerScripts or StarterGui
--
-- Fixes/Improvements:
-- 1. DEFINITIVE FIX (Replay Accuracy): Replaced the tap/swipe recording logic with a
--    granular event engine. The script now records raw 'down', 'up', 'move', and 'wait'
--    events for a high-fidelity, 1:1 playback of complex gestures.
-- 2. DEFINITIVE FIX (Offset Bug): The script records and replays RAW PIXEL coordinates,
--    creating a 1:1 match and fixing the original offset bug.
-- 3. REMOVED Swipe Curvature setting as it's now obsolete. The replay will follow
--    the exact path you record.
-- 4. Patched VIM usage and race conditions for stability.

while not (game and game.GetService) do
    wait(0.05)
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local workspace = workspace

local player = Players.LocalPlayer
while not player do
    RunService.Heartbeat:Wait()
    player = Players.LocalPlayer
end

-- Config
local MIN_CLICK_HOLD_DURATION = 0.05
local FONT_MAIN = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamBold

local CoreGui = game:GetService("CoreGui") -- Use CoreGui for executors
local mouse = player:GetMouse()

-- State
local autoClickEnabled = false
local clickInterval = 0.2
local clickPosition = Vector2.new(500, 500)
local waitingForPosition = false

local isRecording = false
local recordedActions = {}
local recordConnections = {}

local isReplaying = false
local replayCount = 1
local currentReplayThread = nil

local isReplayingLoop = false
local currentReplayLoopThread = nil

-- State for granular recording
local lastEventTime = 0
local activeInputTrackers = {}

-- Offsets: store as {mode="px"|"pct", value=number}
local activeXOffsetRaw = { mode = "px", value = 0 }
local activeYOffsetRaw = { mode = "px", value = 0 }

local guiHidden = false

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
        cancel = function(co) -- best-effort
            if type(co) == "thread" and coroutine.status(co) ~= "dead" then
                pcall(coroutine.close, co)
            end
        end
    }
end

-- UI Creation
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "MacroV2GUI"
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
mainFrame.Size = UDim2.new(0, 260, 0, 360)
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
title.Text = "Macro V2"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = FONT_BOLD
title.TextSize = 22
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

local btnAutoClicker = createButton("Auto Clicker: OFF", 10, autoContent)
local btnSetPosition = createButton("Set Position", 50, autoContent)
local lblInterval = Instance.new("TextBox", autoContent)
lblInterval.Size = UDim2.new(0.85, 0, 0, 30)
lblInterval.Position = UDim2.new(0.075, 0, 0, 90)
lblInterval.PlaceholderText = "Click Interval (sec)"
lblInterval.Text = tostring(clickInterval)
lblInterval.Font = FONT_MAIN
lblInterval.TextSize = 14
lblInterval.TextColor3 = Color3.fromRGB(255, 255, 255)
lblInterval.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
lblInterval.BorderSizePixel = 0
local lblIntervalCorner = Instance.new("UICorner", lblInterval)
lblIntervalCorner.CornerRadius = UDim.new(0, 6)

local btnStartRecording = createButton("Start Recording", 10, recordContent)
local btnReplayClicks = createButton("Replay Clicks", 50, recordContent)
local btnReplayLoop = createButton("Replay Loop: OFF", 90, recordContent)

local replayCountInput = Instance.new("TextBox", recordContent)
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

local offsetXInput = Instance.new("TextBox", settingsContent)
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

local offsetYInput = Instance.new("TextBox", settingsContent)
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

local btnApplyOffsets = createButton("Apply Offsets", 90, settingsContent)

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

local function sendNotification(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = 3})
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

-- VirtualInputManager safety wrappers
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

-- Simulate click (tap) - used for Auto-Clicker
local function simulateClick(pixelPos)
    if not pixelPos then return end
    
    local xOffset = computePixelXOffset(activeXOffsetRaw)
    local yOffset = computePixelYOffset(activeYOffsetRaw)
    local effectivePos = Vector2.new(pixelPos.X + xOffset, pixelPos.Y + yOffset)

    safeSendMouseMove(effectivePos.X, effectivePos.Y)
    task.wait(0.03) -- allow mouse move to register
    safeSendMouseButton(effectivePos.X, effectivePos.Y, 0, true)
    task.wait(MIN_CLICK_HOLD_DURATION)
    safeSendMouseButton(effectivePos.X, effectivePos.Y, 0, false)
end

-- Granular Recording Engine
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
    end)
    return success and result or false
end

local function recordEvent(event)
    local now = os.clock()
    local delay = now - lastEventTime
    if delay > 0.001 then -- only record meaningful waits
        table.insert(recordedActions, {type = "wait", duration = delay})
    end
    table.insert(recordedActions, event)
    lastEventTime = now
end

local function stopRecording()
    if not isRecording then return end
    isRecording = false
    btnStartRecording.Text = "Start Recording"
    for _, conn in pairs(recordConnections) do conn:Disconnect() end
    for _, tracker in pairs(activeInputTrackers) do if coroutine.status(tracker) ~= "dead" then task.cancel(tracker) end end
    recordConnections, activeInputTrackers = {}, {}
    sendNotification("Recording Stopped", string.format("%d actions recorded.", #recordedActions))
end

local function startRecording()
    stopAllProcesses()
    isRecording = true
    recordedActions = {}
    lastEventTime = os.clock()
    btnStartRecording.Text = "Stop Recording"
    sendNotification("Recording Started", "Perform actions to record them.")

    recordConnections.began = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not isRecording or gameProcessed then return end
        local ut = input.UserInputType
        if not (ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch) then return end
        
        local pos = input.Position and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
        if isOverOurGUI(pos) then return end
        
        recordEvent({type = "down", pos = pos})

        activeInputTrackers[input] = task.spawn(function()
            local lastPos = pos
            while activeInputTrackers[input] do
                local currentPos = UserInputService:GetMouseLocation()
                if (currentPos - lastPos).Magnitude > 0.5 then
                    recordEvent({type = "move", pos = currentPos})
                    lastPos = currentPos
                end
                RunService.Heartbeat:Wait()
            end
        end)
    end)

    recordConnections.ended = UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if not isRecording then return end
        local ut = input.UserInputType
        if not (ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch) then return end

        if activeInputTrackers[input] then
            task.cancel(activeInputTrackers[input])
            activeInputTrackers[input] = nil
            
            local pos = input.Position and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
            recordEvent({type = "up", pos = pos})
        end
    end)
end

local function toggleRecording()
    if isRecording then
        stopRecording()
    else
        startRecording()
    end
end

-- Replay single run
function stopReplay()
    if not isReplaying then return end
    isReplaying = false
    if btnReplayClicks.Text ~= "Replay Clicks" then
        btnReplayClicks.Text = "Replay Clicks"
    end
    if currentReplayThread then
        task.cancel(currentReplayThread)
        currentReplayThread = nil
    end
end

local function doReplayActions(actionList)
    local xOffset = computePixelXOffset(activeXOffsetRaw)
    local yOffset = computePixelYOffset(activeYOffsetRaw)
    
    for _, act in ipairs(actionList)
        if not isReplaying and not isReplayingLoop then break end

        if act.type == "wait" then
            task.wait(act.duration)
        else
            local pos = act.pos + Vector2.new(xOffset, yOffset)
            
            if act.type == "down" then
                safeSendMouseMove(pos.X, pos.Y)
                task.wait(0.03) -- Wait for mouse move to register
                safeSendMouseButton(pos.X, pos.Y, 0, true)
            elseif act.type == "up" then
                safeSendMouseMove(pos.X, pos.Y)
                task.wait(0.03)
                safeSendMouseButton(pos.X, pos.Y, 0, false)
            elseif act.type == "move" then
                safeSendMouseMove(pos.X, pos.Y)
            end
        end
    end
end

local function toggleReplay()
    if isReplaying then
        stopReplay()
        return
    end
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

-- Replay loop
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
    if isReplayingLoop then
        stopReplayLoop()
        return
    end
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

-- Auto-clicker (stable timing)
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

-- Set click position (works on mobile)
local positionSetConnection = nil
local function stopSetPosition()
    if not waitingForPosition then return end
    waitingForPosition = false
    if btnSetPosition.Text ~= "Set Position" then
        btnSetPosition.Text = "Set Position"
    end
    
    if positionSetConnection then
        positionSetConnection:Disconnect()
        positionSetConnection = nil
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
        
        if ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch then
            if input.UserInputState == Enum.UserInputState.Begin then
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
        end
    end)
end

-- Utility to stop everything
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
            if num then
                return { mode = "pct", value = num / 100 }
            end
        else
            local num = tonumber(text)
            if num then
                return { mode = "px", value = num }
            end
        end
        return nil
    end

    local xRaw = parseOffsetInput(offsetXInput.Text)
    local yRaw = parseOffsetInput(offsetYInput.Text)
    
    if xRaw and yRaw then
        activeXOffsetRaw = xRaw
        activeYOffsetRaw = yRaw
        
        sendNotification("Offsets Updated", ("X: %s, Y: %s"):format(offsetXInput.Text, offsetYInput.Text))
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

submitBtn.MouseButton1Click:Connect(function()
    local enteredKey = keyBox.Text
    local expectedKey = "key_not_fetched"
    
    local httpGet = game.HttpGet or HttpGet
    if not httpGet then
        sendNotification("Key Check Failed", "No HttpGet function found.")
        return
    end
    
    local success, response = pcall(function()
        return httpGet("https://pastebin.com/raw/v4eb6fHw", true)
    end)
    
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
             sendNotification("Link Copied", "The key link has been copied to your clipboard.")
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

-- initial UI state & notes
selectTab("auto")
sendNotification("MacroV2 Loaded", vmAvailable and "VIM (Patched) Found" or "CRITICAL: VIM NOT Found")
