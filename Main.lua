-- Macro Script - Definitive Fix v6.1: Refactored Input Engine
-- This version fixes critical bugs related to replay accuracy by implementing
-- a robust input simulation engine that correctly handles multiple coordinate systems.

-- --- Service Loading ---
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local mouse = player:GetMouse()

-- --- task Shim for compatibility ---
if typeof(task) ~= "table" then task = {
    spawn = coroutine.wrap,
    wait = function(t) local s = tick() while tick() - s < (t or 0) do RunService.Heartbeat:Wait() end end,
    cancel = function(thread) if coroutine.status(thread) ~= "dead" then coroutine.close(thread) end end
} end

-- --- Helper ---
local function sendNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = duration or 5})
    end)
end

-- --- UI ---
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "MacroV6GUI"; mainGui.IgnoreGuiInset = true; mainGui.ResetOnSpawn = false
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Global; mainGui.Parent = CoreGui

local mainFrame = Instance.new("Frame", mainGui)
mainFrame.Name = "MacroFrame"; mainFrame.Size = UDim2.new(0, 280, 0, 380)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0); mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30); mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
local frameCorner = Instance.new("UICorner", mainFrame); frameCorner.CornerRadius = UDim.new(0, 12)

local dragLayer = Instance.new("Frame", mainFrame)
dragLayer.Size = UDim2.new(1, 0, 0, 40); dragLayer.BackgroundTransparency = 1; dragLayer.Active = true

local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, 0, 0, 40); title.BackgroundTransparency = 1
title.Text = "Macro Recorder v6.1"; title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold; title.TextSize = 22

local contentArea = Instance.new("Frame", mainFrame)
contentArea.Size = UDim2.new(1, -20, 1, -50); contentArea.Position = UDim2.new(0, 10, 0, 40)
contentArea.BackgroundTransparency = 1

local function createButton(text, posY, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30); btn.Position = UDim2.new(0, 0, 0, posY)
    btn.Text = text; btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham; btn.TextSize = 16
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45); btn.Parent = parent
    local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0, 6)
    return btn
end

local btnStartRecording = createButton("Start Recording", 10, contentArea)
local btnReplayClicks = createButton("Replay Once", 50, contentArea)
local btnReplayLoop = createButton("Replay Loop: OFF", 90, contentArea)
local btnClear = createButton("Clear Recording", 130, contentArea)

local statusLabel = Instance.new("TextLabel", contentArea)
statusLabel.Size = UDim2.new(1, 0, 0, 20); statusLabel.Position = UDim2.new(0, 0, 0, 170)
statusLabel.BackgroundTransparency = 1; statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "Idle"; statusLabel.TextSize = 14; statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)

local calibrationTitle = Instance.new("TextLabel", contentArea)
calibrationTitle.Size = UDim2.new(1, 0, 0, 20); calibrationTitle.Position = UDim2.new(0, 0, 0, 200)
calibrationTitle.BackgroundTransparency = 1
calibrationTitle.Text = "Executor Virtual Resolution (IMPORTANT)"; calibrationTitle.Font = Enum.Font.Gotham
calibrationTitle.TextSize = 12; calibrationTitle.TextColor3 = Color3.fromRGB(180, 180, 180)

local virtualWidthInput = Instance.new("TextBox", contentArea)
virtualWidthInput.Size = UDim2.new(0.48, 0, 0, 30); virtualWidthInput.Position = UDim2.new(0, 0, 0, 225)
virtualWidthInput.PlaceholderText = "Width"; virtualWidthInput.Text = "1920"
virtualWidthInput.Font = Enum.Font.Gotham; virtualWidthInput.TextSize = 16
virtualWidthInput.TextColor3 = Color3.fromRGB(255, 255, 255)
virtualWidthInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
local vwCorner = Instance.new("UICorner", virtualWidthInput); vwCorner.CornerRadius = UDim.new(0, 6)

local virtualHeightInput = Instance.new("TextBox", contentArea)
virtualHeightInput.Size = UDim2.new(0.48, 0, 0, 30); virtualHeightInput.Position = UDim2.new(0.52, 0, 0, 225)
virtualHeightInput.PlaceholderText = "Height"; virtualHeightInput.Text = "1080"
virtualHeightInput.Font = Enum.Font.Gotham; virtualHeightInput.TextSize = 16
virtualHeightInput.TextColor3 = Color3.fromRGB(255, 255, 255)
virtualHeightInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
local vhCorner = Instance.new("UICorner", virtualHeightInput); vhCorner.CornerRadius = UDim.new(0, 6)

local toggleGuiBtn = Instance.new("TextButton", mainGui)
toggleGuiBtn.Size = UDim2.new(0, 70, 0, 30); toggleGuiBtn.Position = UDim2.new(0, 10, 0, 70)
toggleGuiBtn.Text = "Hide"; toggleGuiBtn.Font = Enum.Font.Gotham; toggleGuiBtn.TextSize = 14
toggleGuiBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255); toggleGuiBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
local toggleCorner = Instance.new("UICorner", toggleGuiBtn); toggleCorner.CornerRadius = UDim.new(0, 6)

local function makeDraggable(guiObject, dragHandle)
    local dragging = false; local dragStart; local startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; startPos = guiObject.Position; dragStart = UserInputService:GetMouseLocation()
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = UserInputService:GetMouseLocation() - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    dragHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end
makeDraggable(mainFrame, dragLayer); makeDraggable(toggleGuiBtn, toggleGuiBtn)

-- --- CORE LOGIC ---
do
    -- State
    local isRecording, isReplaying, isReplayingLoop = false, false, false
    local recordedActions = {}
    local recordConnections = {}
    local activeInputTrackers = {}
    local lastEventTime = 0
    local currentReplayThread = nil

    -- Calibration
    local guiInset, hardwareScreenSize = Vector2.new(0, 0), Vector2.new(0, 0)
    local virtualScreenSize = Vector2.new(1920, 1080)
    local scaleFactor = Vector2.new(1, 1)

    function updateCalibration()
        local success, result = pcall(function() return GuiService:GetGuiInset() end)
        guiInset = (success and result) or Vector2.new(0, 36)
        
        hardwareScreenSize = mainGui.AbsoluteSize
        
        local vw = tonumber(virtualWidthInput.Text) or 1920
        local vh = tonumber(virtualHeightInput.Text) or 1080
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
        return Vector2.new(
            math.floor(hardwarePos.X * scaleFactor.X + 0.5),
            math.floor(hardwarePos.Y * scaleFactor.Y + 0.5)
        )
    end

    -- Input Simulation Engine
    -- This engine handles the crucial difference between VirtualInputManager (VIM)
    -- and legacy executor globals. VIM typically requires absolute screen coordinates,
    -- while executor globals require coordinates scaled to a virtual resolution.
    -- This fixes the primary cause of misaligned clicks during replay.
    local INPUT_METHOD = "UNKNOWN"
    local VIM = nil
    
    function initialize_input_method()
        local vim_success, vim_instance = pcall(function() return game:GetService("VirtualInputManager") end)
        if vim_success and vim_instance then
            VIM, INPUT_METHOD = vim_instance, "VIM"
            sendNotification("Input Method", "VirtualInputManager (Modern)", 3)
        elseif mouse1press and mouse1release and mousemove then
            INPUT_METHOD = "EXECUTOR_GLOBALS"
            sendNotification("Input Method", "Executor Globals (Fallback)", 3)
        else
            INPUT_METHOD = "NONE"
            sendNotification("Input Error", "No compatible input method found!", 10)
        end
    end

    local function SimulateMouseMove(viewportPos)
        if INPUT_METHOD == "VIM" then
            -- VIM uses absolute screen coordinates (viewport position + GUI inset)
            local screenPos = viewportPos + guiInset
            pcall(VIM.SendMouseMoveEvent, VIM, screenPos.X, screenPos.Y)
        elseif INPUT_METHOD == "EXECUTOR_GLOBALS" then
            -- Executor globals use virtual coordinates (screen position scaled to virtual resolution)
            local executorPos = ViewportToExecutor(viewportPos)
            pcall(mousemove, executorPos.X, executorPos.Y)
        end
    end

    local function SimulateMouseButton(viewportPos, isDown)
        if INPUT_METHOD == "VIM" then
            local screenPos = viewportPos + guiInset
            pcall(VIM.SendMouseButtonEvent, VIM, screenPos.X, screenPos.Y, 0, isDown, false)
        elseif INPUT_METHOD == "EXECUTOR_GLOBALS" then
            -- Globals don't need position; mousemove was just called.
            if isDown then pcall(mouse1press) else pcall(mouse1release) end
        end
    end
    
    -- Main Functions
    local stopAllProcesses;
    
    local function setStatus(text, color)
        statusLabel.Text = text
        statusLabel.TextColor3 = color or Color3.fromRGB(150, 255, 150)
    end
    
    local function isOverOurGUI(pos)
        local s, objs = pcall(mainGui.GetGuiObjectsAtPosition, mainGui, pos.X, pos.Y)
        return s and #objs > 0
    end

    local function recordEvent(event)
        local now = os.clock()
        local delay = now - lastEventTime
        if delay > 0.001 then
            table.insert(recordedActions, {type = "wait", duration = delay})
        end
        table.insert(recordedActions, event)
        lastEventTime = now
    end

    function stopRecording()
        if not isRecording then return end
        isRecording = false
        for _, conn in pairs(recordConnections) do conn:Disconnect() end
        for _, tracker in pairs(activeInputTrackers) do task.cancel(tracker) end
        recordConnections, activeInputTrackers = {}, {}
        btnStartRecording.Text = "Start Recording"
        setStatus(string.format("Idle | %d actions", #recordedActions))
    end

    function startRecording()
        stopAllProcesses()
        isRecording = true
        recordedActions = {}
        lastEventTime = os.clock()
        btnStartRecording.Text = "Stop Recording"
        setStatus("Recording...", Color3.fromRGB(255, 150, 150))

        recordConnections.began = UserInputService.InputBegan:Connect(function(input, gp)
            if gp or not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then return end
            if isOverOurGUI(input.Position) then return end
            
            recordEvent({type = "down", pos = input.Position})

            -- Start tracking movement for this specific input
            activeInputTrackers[input] = task.spawn(function()
                local lastPos = input.Position
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

        recordConnections.ended = UserInputService.InputEnded:Connect(function(input)
            if not activeInputTrackers[input] then return end
            
            task.cancel(activeInputTrackers[input])
            activeInputTrackers[input] = nil
            
            recordEvent({type = "up", pos = input.Position})
        end)
    end
    
    function stopReplay()
        if not isReplaying and not isReplayingLoop then return end
        isReplaying, isReplayingLoop = false, false
        if currentReplayThread then task.cancel(currentReplayThread); currentReplayThread = nil end
        btnReplayClicks.Text = "Replay Once"
        btnReplayLoop.Text = "Replay Loop: OFF"
        setStatus(string.format("Idle | %d actions", #recordedActions))
    end
    
    local function doReplayActions()
        for _, act in ipairs(recordedActions) do
            if not isReplaying and not isReplayingLoop then break end
            
            if act.type == "wait" then
                task.wait(act.duration)
            elseif act.type == "move" then
                SimulateMouseMove(act.pos)
            elseif act.type == "down" then
                SimulateMouseMove(act.pos)
                task.wait(0.02) -- Wait for mouse move to register
                SimulateMouseButton(act.pos, true)
            elseif act.type == "up" then
                SimulateMouseMove(act.pos)
                task.wait(0.02)
                SimulateMouseButton(act.pos, false)
            end
        end
    end
    
    local function startReplay(loop)
        if #recordedActions == 0 then sendNotification("Replay Failed", "No actions recorded yet.", 3) return end
        stopAllProcesses()
        isReplaying = not loop
        isReplayingLoop = loop

        currentReplayThread = task.spawn(function()
            if loop then
                btnReplayLoop.Text = "Replay Loop: ON"
                setStatus("Looping...", Color3.fromRGB(150, 150, 255))
                while isReplayingLoop do
                    doReplayActions()
                    task.wait(0.1)
                end
            else
                btnReplayClicks.Text = "Stop Replay"
                setStatus("Replaying Once...", Color3.fromRGB(150, 150, 255))
                doReplayActions()
            end
            stopReplay()
        end)
    end
    
    function clearRecording()
        stopAllProcesses()
        recordedActions = {}
        setStatus("Idle | Recording Cleared")
    end
    
    stopAllProcesses = function()
        if isRecording then stopRecording() end
        if isReplaying or isReplayingLoop then stopReplay() end
    end
    
    -- Connect GUI
    btnStartRecording.MouseButton1Click:Connect(function() if isRecording then stopRecording() else startRecording() end end)
    btnReplayClicks.MouseButton1Click:Connect(function() if isReplaying then stopReplay() else startReplay(false) end end)
    btnReplayLoop.MouseButton1Click:Connect(function() if isReplayingLoop then stopReplay() else startReplay(true) end end)
    btnClear.MouseButton1Click:Connect(clearRecording)
    
    toggleGuiBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = not mainFrame.Visible
        toggleGuiBtn.Text = mainFrame.Visible and "Hide" or "Show"
    end)
    
    local function onFocusLost() task.wait(0.1); updateCalibration() end
    virtualWidthInput.FocusLost:Connect(onFocusLost)
    virtualHeightInput.FocusLost:Connect(onFocusLost)
    
    -- Initialize
    sendNotification("Macro V6.1 Loaded", "Calibrating...", 2)
    task.wait(0.5)
    initialize_input_method()
    updateCalibration()
end
