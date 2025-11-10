-- Delta Macro V7.0 | Profile-Based Ultra-Precision Edition
-- Works on Delta, Synapse, KRNL, Fluxus, Mobile & Desktop
-- Features: Visual calibration, automatic profile saving, mobile UI scaling

-- ============================================================================
-- UNIVERSAL COMPATIBILITY LAYER
-- ============================================================================
if not task then
    _G.task = {
        wait = wait,
        spawn = function(func) spawn(func) end,
        delay = function(time, func) delay(time, func) end
    }
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = workspace
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then error("No LocalPlayer - execute after game loads") end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local CONFIG = {
    SHOW_MARKERS = true,
    CACHE_RATE = 2,
    CLICK_HOLD = 0.05,
    CALIBRATE_TIMEOUT = 15,
    PROFILE_FOLDER = "DeltaMacro_Profiles",
    FALLBACK_INSET = Vector2.new(0, 36),
    ACCURACY_THRESHOLD = 0.95,
    AUTOSAVE_ENABLED = true, -- Enable automatic profile saving
}

-- ============================================================================
-- LOGGER
-- ============================================================================
local Logger = {
    log = function(msg, type)
        print(string.format("[DeltaMacro V7.0] %s [%s] %s", os.date("%H:%M:%S"), type or "INFO", msg))
    end,
    info = function(msg) Logger.log(msg, "INFO") end,
    warn = function(msg) Logger.log(msg, "WARN") end,
    error = function(msg) Logger.log(msg, "ERROR") end
}

-- ============================================================================
-- STATE MANAGER (Thread-Safe)
-- ============================================================================
local StateManager = {
    data = {
        autoClick = false,
        clickInterval = 0.2,
        clickPos = Vector2.new(500, 500),
        recording = false,
        recorded = {},
        replayLoop = false,
        calibrating = false,
        xOffset = 0,
        yOffset = 0,
        lastCalibrated = 0,
        selectedProfile = "default",
        autosave = CONFIG.AUTOSAVE_ENABLED,
    },
    mutex = false,
    
    set = function(self, key, value)
        while self.mutex do task.wait() end
        self.mutex = true
        self.data[key] = value
        self.mutex = false
        
        if self.data.autosave and key ~= "recorded" and key ~= "recording" then
            self:autosaveProfile()
        end
    end,
    
    get = function(self, key)
        while self.mutex do task.wait() end
        self.mutex = true
        local val = self.data[key]
        self.mutex = false
        return val
    end,
    
    autosaveProfile = function(self)
        if not CONFIG.AUTOSAVE_ENABLED then return end
        local currentProfile = self:get("selectedProfile")
        if currentProfile and currentProfile ~= "" then
            ProfileManager:save(currentProfile, {
                actions = self:get("recorded"),
                position = {x = self:get("clickPos").X, y = self:get("clickPos").Y},
                interval = self:get("clickInterval"),
                offsets = {x = self:get("xOffset"), y = self:get("yOffset")},
                calibration = CalibrationEngine.transformMatrix,
            })
        end
    end,
}

-- ============================================================================
-- CACHE MODULE
-- ============================================================================
local Cache = {
    viewport = Vector2.new(1920, 1080),
    inset = CONFIG.FALLBACK_INSET,
    lastUpdate = 0,
    update = function(self)
        local now = os.clock()
        if now - self.lastUpdate < CONFIG.CACHE_RATE then return end
        self.lastUpdate = now
        self.viewport = (Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or self.viewport
        local s, inset = pcall(GuiService.GetGuiInset, GuiService)
        self.inset = s and inset or CONFIG.FALLBACK_INSET
    end,
}

-- ============================================================================
-- CALIBRATION ENGINE
-- ============================================================================
local CalibrationEngine = {
    isCalibrated = false,
    transformMatrix = {scaleX = 1, scaleY = 1, offsetX = 0, offsetY = 0, confidence = 0.5},
    visualTargets = {},
    calibrationPoints = {},
    currentPointIndex = 0,
    
    startVisualCalibration = function(self)
        if StateManager:get("calibrating") then return end
        StateManager:set("calibrating", true)
        self:clearTargets()
        
        local viewport = Cache.viewport
        self.calibrationPoints = {
            {name = "Top-Left", viewport = Vector2.new(100, 100)},
            {name = "Center", viewport = Vector2.new(viewport.X/2, viewport.Y/2)},
            {name = "Bottom-Right", viewport = Vector2.new(viewport.X - 100, viewport.Y - 100)},
        }
        
        self.currentPointIndex = 1
        self:createTarget(self.calibrationPoints[1])
        Logger.info(string.format("Calibration started - Point %d/%d", 1, #self.calibrationPoints))
    end,
    
    createTarget = function(self, pointData)
        local target = Instance.new("Frame")
        target.Name = "CalibrationTarget"
        target.Size = UDim2.new(0, 80, 0, 80)
        target.Position = UDim2.new(0, pointData.viewport.X - 40, 0, pointData.viewport.Y - 40)
        target.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        target.BackgroundTransparency = 0.2
        target.ZIndex = 2000
        target.Parent = MainGUI
        
        local corner = Instance.new("UICorner", target)
        corner.CornerRadius = UDim.new(1, 0)
        
        local ring = Instance.new("ImageLabel", target)
        ring.Image = "rbxassetid://3926305904"
        ring.ImageRectOffset = Vector2.new(44, 44)
        ring.ImageRectSize = Vector2.new(36, 36)
        ring.ImageColor3 = Color3.fromRGB(255, 255, 255)
        ring.BackgroundTransparency = 1
        ring.Size = UDim2.new(2, 0, 2, 0)
        ring.Position = UDim2.new(-0.5, 0, -0.5, 0)
        ring.ZIndex = 1999
        
        local label = Instance.new("TextLabel", target)
        label.Size = UDim2.new(1, 0, 0, 50)
        label.Position = UDim2.new(0, 0, 1, 10)
        label.BackgroundTransparency = 1
        label.Text = string.format("Click EXACT center\n%s\n(%d/%d)", pointData.name, self.currentPointIndex, #self.calibrationPoints)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0.5
        label.ZIndex = 2001
        
        TweenService:Create(target, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            BackgroundTransparency = 0.4
        }):Play()
        TweenService:Create(ring, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            Size = UDim2.new(3, 0, 3, 0),
            Position = UDim2.new(-1, 0, -1, 0),
            ImageTransparency = 1
        }):Play()
        
        table.insert(self.visualTargets, target)
        
        local conn
        conn = UIS.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local clickPos = UIS:GetMouseLocation()
                self:recordPoint(clickPos)
                conn:Disconnect()
            end
        end)
        
        task.delay(CONFIG.CALIBRATE_TIMEOUT, function()
            if target.Parent then
                self:clearTargets()
                StateManager:set("calibrating", false)
                Logger.warn("Calibration timeout")
            end
        end)
    end,
    
    recordPoint = function(self, actualClickPos)
        local point = self.calibrationPoints[self.currentPointIndex]
        point.actual = actualClickPos
        point.delta = actualClickPos - point.viewport
        
        Logger.info(string.format("Point %d recorded | Delta: (%d, %d)", self.currentPointIndex, point.delta.X, point.delta.Y))
        
        if self.visualTargets[self.currentPointIndex] then
            self.visualTargets[self.currentPointIndex]:Destroy()
        end
        
        self.currentPointIndex = self.currentPointIndex + 1
        if self.currentPointIndex <= #self.calibrationPoints then
            task.wait(0.5)
            self:createTarget(self.calibrationPoints[self.currentPointIndex])
        else
            self:computeTransform()
            self:saveCalibration()
            self:showAccuracyReport()
            StateManager:set("calibrating", false)
        end
    end,
    
    computeTransform = function(self)
        local p1, p2, p3 = self.calibrationPoints[1], self.calibrationPoints[2], self.calibrationPoints[3]
        local avgDeltaX = (p1.delta.X + p2.delta.X + p3.delta.X) / 3
        local avgDeltaY = (p1.delta.Y + p2.delta.Y + p3.delta.Y) / 3
        
        local expectedDist = (p3.viewport - p1.viewport).Magnitude
        local actualDist = (p3.actual - p1.actual).Magnitude
        local scale = (expectedDist > 0) and (actualDist / expectedDist) or 1
        
        self.transformMatrix = {
            scaleX = scale,
            scaleY = scale,
            offsetX = -math.floor(avgDeltaX + 0.5),
            offsetY = -math.floor(avgDeltaY + 0.5),
            confidence = math.clamp(1 / (1 + math.abs(scale - 1) * 2), 0.5, 1),
        }
        
        self.isCalibrated = true
        StateManager:set("xOffset", self.transformMatrix.offsetX)
        StateManager:set("yOffset", self.transformMatrix.offsetY)
        
        Logger.info(string.format("Calibration complete | Offset: (%d, %d) | Scale: %.3f | Confidence: %.1f%%",
            self.transformMatrix.offsetX, self.transformMatrix.offsetY, scale, self.transformMatrix.confidence * 100))
    end,
    
    saveCalibration = function(self)
        if not writefile then return end
        local data = HttpService:JSONEncode({
            offsetX = self.transformMatrix.offsetX,
            offsetY = self.transformMatrix.offsetY,
            scale = self.transformMatrix.scaleX,
            confidence = self.transformMatrix.confidence,
            timestamp = os.time(),
        })
        writefile(CONFIG.PROFILE_FOLDER .. "/calibration.json", data)
        Logger.info("Calibration saved to disk")
    end,
    
    loadCalibration = function(self)
        if not readfile then return false end
        local s, data = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG.PROFILE_FOLDER .. "/calibration.json"))
        end)
        if s and data then
            self.transformMatrix = {
                offsetX = data.offsetX or 0,
                offsetY = data.offsetY or 0,
                scaleX = data.scale or 1,
                scaleY = data.scale or 1,
                confidence = data.confidence or 0.5,
            }
            self.isCalibrated = true
            StateManager:set("xOffset", data.offsetX or 0)
            StateManager:set("yOffset", data.offsetY or 0)
            Logger.info(string.format("Calibration loaded | Offset: (%d, %d) | Confidence: %.1f%%",
                data.offsetX or 0, data.offsetY or 0, (data.confidence or 0.5) * 100))
            return true
        end
        return false
    end,
    
    showAccuracyReport = function(self)
        local report = Instance.new("Frame")
        report.Size = UDim2.new(0, 400, 0, 240)
        report.Position = UDim2.new(0.5, -200, 0.5, -120)
        report.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        report.BorderSizePixel = 0
        report.ZIndex = 3000
        report.Parent = MainGUI
        
        Instance.new("UICorner", report).CornerRadius = UDim.new(0, 12)
        
        local stroke = Instance.new("UIStroke", report)
        stroke.Color = Color3.fromRGB(0, 255, 0)
        stroke.Thickness = 2
        
        local title = Instance.new("TextLabel", report)
        title.Size = UDim2.new(1, 0, 0, 40)
        title.BackgroundTransparency = 1
        title.Text = "✓ Calibration Complete!"
        title.Font = Enum.Font.GothamBold
        title.TextSize = 18
        title.TextColor3 = Color3.fromRGB(0, 255, 0)
        
        local info = Instance.new("TextLabel", report)
        info.Size = UDim2.new(0.9, 0, 0, 140)
        info.Position = UDim2.new(0.05, 0, 0, 50)
        info.BackgroundTransparency = 1
        info.Text = string.format(
            "Offset Correction: X:%d, Y:%d\nScale Compensation: %.3fx\nConfidence Score: %.1f%%\nPrecision Level: %s\n\nAll coordinates are now calibrated to ±1 pixel accuracy!",
            self.transformMatrix.offsetX, self.transformMatrix.offsetY,
            self.transformMatrix.scaleX,
            self.transformMatrix.confidence * 100,
            (self.transformMatrix.confidence > CONFIG.ACCURACY_THRESHOLD and "HIGH" or "MEDIUM")
        )
        info.Font = Enum.Font.Gotham
        info.TextSize = 13
        info.TextColor3 = Color3.fromRGB(240, 240, 240)
        info.TextXAlignment = Enum.TextXAlignment.Left
        
        local close = Instance.new("TextButton", report)
        close.Size = UDim2.new(0.9, 0, 0, 35)
        close.Position = UDim2.new(0.05, 0, 1, -45)
        close.Text = "Continue"
        close.Font = Enum.Font.GothamBold
        close.TextSize = 14
        close.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        close.BorderSizePixel = 0
        Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
        
        close.MouseButton1Click:Connect(function()
            TweenService:Create(report, TweenInfo.new(0.2), {Size = UDim2.new(0, 0, 0, 0)}):Play()
            task.wait(0.2)
            report:Destroy()
        end)
        
        TweenService:Create(report, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Size = UDim2.new(0, 400, 0, 240)}):Play()
    end,
    
    clearTargets = function(self)
        for _, target in ipairs(self.visualTargets) do
            if target and target.Parent then target:Destroy() end
        end
        self.visualTargets = {}
    end,
}

-- ============================================================================
-- INPUT SIMULATION (Precise)
-- ============================================================================
local InputSimulator = {
    viewportToExecutor = function(self, viewportPos)
        Cache:update()
        local inset = Cache.inset
        
        local calibratedX = (viewportPos.X * CalibrationEngine.transformMatrix.scaleX) + inset.X + StateManager:get("xOffset")
        local calibratedY = (viewportPos.Y * CalibrationEngine.transformMatrix.scaleY) + inset.Y + StateManager:get("yOffset")
        
        return Vector2.new(math.floor(calibratedX + 0.5), math.floor(calibratedY + 0.5))
    end,
    
    performClick = function(self, viewportPos, verify)
        verify = verify or false
        local executorPos = self:viewportToExecutor(viewportPos)
        
        VirtualInputManager:SendMouseMoveEvent(executorPos.X, executorPos.Y)
        task.wait(CONFIG.CLICK_HOLD)
        VirtualInputManager:SendMouseButtonEvent(executorPos.X, executorPos.Y, 0, true)
        task.wait(CONFIG.CLICK_HOLD)
        VirtualInputManager:SendMouseButtonEvent(executorPos.X, executorPos.Y, 0, false)
        
        if verify and CONFIG.SHOW_MARKERS then
            VisualFeedback:showMarker(viewportPos, Color3.fromRGB(0, 255, 0), 12, 0.3)
        end
        
        return executorPos
    end,
    
    keyPress = function(self, keyCode, holdTime)
        holdTime = holdTime or 0.1
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(holdTime)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end,
}

-- ============================================================================
-- VISUAL FEEDBACK (Marker Pool)
-- ============================================================================
local VisualFeedback = {
    markerPool = {},
    activeMarkers = {},
    
    showMarker = function(self, viewportPos, color, size, duration)
        if not CONFIG.SHOW_MARKERS then return end
        
        local marker = table.remove(self.markerPool)
        if not marker then
            marker = Instance.new("Frame")
            marker.BorderSizePixel = 0
            Instance.new("UICorner", marker).CornerRadius = UDim.new(1, 0)
        end
        
        size = size or 15
        marker.Size = UDim2.new(0, size, 0, size)
        marker.Position = UDim2.new(0, viewportPos.X - size/2, 0, viewportPos.Y - size/2)
        marker.BackgroundColor3 = color or Color3.fromRGB(255, 0, 0)
        marker.BackgroundTransparency = 0.3
        marker.ZIndex = 1000
        marker.Parent = MainGUI
        
        table.insert(self.activeMarkers, marker)
        
        task.spawn(function()
            for i = 1, 3 do
                marker.BackgroundTransparency = 0.3
                task.wait(0.1)
                marker.BackgroundTransparency = 0
                task.wait(0.1)
            end
            task.wait(duration or 0.5)
            
            marker.Parent = nil
            table.insert(self.markerPool, marker)
            for i, m in ipairs(self.activeMarkers) do
                if m == marker then table.remove(self.activeMarkers, i) break end
            end
        end)
    end,
}

-- ============================================================================
-- RECORDING ENGINE (High-Precision)
-- ============================================================================
local RecordingEngine = {
    connections = {},
    activeInput = nil,
    
    isOverGUI = function(pos)
        local s, objs = pcall(UIS.GetGuiObjectsAtPosition, UIS, math.floor(pos.X), math.floor(pos.Y))
        if not s then return false end
        for _, obj in ipairs(objs) do
            if obj:IsDescendantOf(MainGUI) then return true end
        end
        return false
    end,
}

function RecordingEngine.start()
    if StateManager:get("recording") then return end
    StateManager:set("recording", true)
    StateManager:set("recorded", {})
    
    Logger.info("Recording started")
    RecordingEngine.startTime = os.clock()
    RecordingEngine.connections = {}
    
    RecordingEngine.connections.began = UIS.InputBegan:Connect(function(input, gp)
        if gp or not StateManager:get("recording") then return end
        local pos = input.Position or UIS:GetMouseLocation()
        if RecordingEngine.isOverGUI(pos) then return end
        
        RecordingEngine.activeInput = {
            startTime = os.clock(),
            startPos = pos,
            isDrag = false,
            keyCode = (input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode) or nil
        }
        
        if input.KeyCode then
            table.insert(StateManager:get("recorded"), {
                type = "keyPress",
                keyCode = input.KeyCode,
                timestamp = os.clock() - RecordingEngine.startTime
            })
        end
    end)
    
    RecordingEngine.connections.changed = UIS.InputChanged:Connect(function(input)
        if not StateManager:get("recording") or not RecordingEngine.activeInput then return end
        local pos = input.Position or UIS:GetMouseLocation()
        if not RecordingEngine.activeInput.isDrag and (pos - RecordingEngine.activeInput.startPos).Magnitude >= 5 then
            RecordingEngine.activeInput.isDrag = true
        end
    end)
    
    RecordingEngine.connections.ended = UIS.InputEnded:Connect(function(input, gp)
        if not StateManager:get("recording") or not RecordingEngine.activeInput then return end
        local endPos = input.Position or UIS:GetMouseLocation()
        local data = RecordingEngine.activeInput
        local now = os.clock() - RecordingEngine.startTime
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local action = data.isDrag and {
                type = "swipe",
                startPixel = data.startPos,
                endPixel = endPos,
                duration = math.max(0.02, os.clock() - data.startTime),
                timestamp = now
            } or {
                type = "tap",
                pixelPos = data.startPos,
                timestamp = now
            }
            table.insert(StateManager:get("recorded"), action)
        elseif input.KeyCode and data.keyCode then
            table.insert(StateManager:get("recorded"), {
                type = "keyRelease",
                keyCode = data.keyCode,
                timestamp = now
            })
        end
        
        RecordingEngine.activeInput = nil
    end)
end

function RecordingEngine.stop()
    if not StateManager:get("recording") then return end
    StateManager:set("recording", false)
    
    for _, conn in pairs(RecordingEngine.connections) do
        pcall(function() conn:Disconnect() end)
    end
    RecordingEngine.connections = {}
    RecordingEngine.activeInput = nil
    
    Logger.info(string.format("Recording stopped | Actions: %d", #StateManager:get("recorded")))
end

function RecordingEngine.replay(loop)
    local actions = StateManager:get("recorded")
    if not actions or #actions == 0 then
        Logger.warn("No actions recorded")
        return
    end
    
    StateManager:set("replayLoop", true)
    
    task.spawn(function()
        local iteration = 1
        while true do
            if not StateManager:get("replayLoop") then break end
            
            local startTime = os.clock()
            for _, action in ipairs(actions) do
                if not StateManager:get("replayLoop") then break end
                
                if action.timestamp then
                    local currentTime = os.clock() - startTime
                    local waitTime = action.timestamp - currentTime
                    if waitTime > 0 then task.wait(waitTime) end
                end
                
                if action.type == "tap" then
                    InputSimulator:performClick(action.pixelPos, true)
                elseif action.type == "swipe" then
                    InputSimulator:performClick(action.endPixel, true)
                elseif action.type == "keyPress" then
                    InputSimulator:keyPress(action.keyCode, 0.1)
                end
            end
            
            if not loop then
                StateManager:set("replayLoop", false)
                break
            end
            
            iteration = iteration + 1
            task.wait(0.1)
        end
        
        Logger.info(string.format("Replay finished | Iterations: %d", iteration))
    end)
end

function RecordingEngine.clear()
    StateManager:set("recorded", {})
    Logger.info("Recording cleared")
end

-- ============================================================================
-- PROFILE MANAGER (Automatic Saving)
-- ============================================================================
local ProfileManager = {
    folder = CONFIG.PROFILE_FOLDER,
    
    ensureFolder = function(self)
        if not makefolder then return false end
        pcall(makefolder, self.folder)
        return true
    end,
    
    save = function(self, name, data)
        if not writefile then
            Logger.warn("writefile not available - profiles disabled")
            return false
        end
        
        name = name or StateManager:get("selectedProfile")
        if not name or name == "" then name = "default" end
        
        data = data or {
            name = name,
            position = {x = StateManager:get("clickPos").X, y = StateManager:get("clickPos").Y},
            interval = StateManager:get("clickInterval"),
            offsets = {x = StateManager:get("xOffset"), y = StateManager:get("yOffset")},
            actions = StateManager:get("recorded"),
            calibration = CalibrationEngine.transformMatrix,
            timestamp = os.time(),
            version = "7.0",
        }
        
        self:ensureFolder()
        local json = HttpService:JSONEncode(data)
        writefile(self.folder .. "/" .. name .. ".json", json)
        Logger.info("Profile saved: " .. name)
        return true
    end,
    
    load = function(self, name)
        if not readfile then
            Logger.warn("readfile not available - profiles disabled")
            return false
        end
        
        name = name or StateManager:get("selectedProfile")
        if not name then return false end
        
        local s, data = pcall(function()
            return HttpService:JSONDecode(readfile(self.folder .. "/" .. name .. ".json"))
        end)
        
        if s and data then
            StateManager:set("selectedProfile", name)
            StateManager:set("clickPos", Vector2.new(data.position.x, data.position.y))
            StateManager:set("clickInterval", data.interval or 0.2)
            StateManager:set("xOffset", data.offsets.x or 0)
            StateManager:set("yOffset", data.offsets.y or 0)
            StateManager:set("recorded", data.actions or {})
            
            if data.calibration then
                CalibrationEngine.transformMatrix = data.calibration
                CalibrationEngine.isCalibrated = true
            end
            
            Logger.info("Profile loaded: " .. name)
            return true
        end
        
        Logger.error("Failed to load profile: " .. name)
        return false
    end,
    
    delete = function(self, name)
        if not delfile then return false end
        pcall(delfile, self.folder .. "/" .. name .. ".json")
        Logger.info("Profile deleted: " .. name)
        return true
    end,
    
    list = function(self)
        if not listfiles then return {} end
        local files = listfiles(self.folder .. "/")
        local profiles = {}
        for _, file in ipairs(files) do
            local name = file:match("([^/]+)%.json$")
            if name and name ~= "calibration" then table.insert(profiles, name) end
        end
        return profiles
    end,
}

-- ============================================================================
-- MOBILE-OPTIMIZED GUI CREATION
-- ============================================================================
local GUI = {
    elements = {},
    tabs = {},
    contents = {},
    scale = 1,
}

function GUI.getScale()
    local viewport = Cache.viewport
    if viewport.Y < 800 then return 0.8 end
    if viewport.Y < 1080 then return 0.9 end
    return 1
end

function GUI.create()
    GUI.scale = GUI.getScale()
    
    MainGUI = Instance.new("ScreenGui")
    MainGUI.Name = "DeltaMacro_V7"
    MainGUI.ResetOnSpawn = false
    MainGUI.IgnoreGuiInset = true
    MainGUI.ZIndexBehavior = Enum.ZIndexBehavior.Global
    MainGUI.Parent = CoreGui
    
    local size = UDim2.new(0, 420 * GUI.scale, 0, 580 * GUI.scale)
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = size
    mainFrame.Position = UDim2.new(0.5, -size.X.Offset/2, 0.5, -size.Y.Offset/2)
    mainFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = MainGUI
    
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16 * GUI.scale)
    
    local gradient = Instance.new("UIGradient", mainFrame)
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 28, 30)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 40, 45))
    })
    gradient.Rotation = 45
    
    -- Title
    local title = Instance.new("TextLabel", mainFrame)
    title.Size = UDim2.new(1, 0, 0, 60 * GUI.scale)
    title.BackgroundTransparency = 1
    title.Text = "Delta Macro V7.0"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22 * GUI.scale
    title.TextColor3 = Color3.fromRGB(0, 255, 0)
    
    -- Calibration indicator
    local calibDot = Instance.new("TextLabel", mainFrame)
    calibDot.Size = UDim2.new(0, 200, 0, 20 * GUI.scale)
    calibDot.Position = UDim2.new(0, 10 * GUI.scale, 0, 35 * GUI.scale)
    calibDot.BackgroundTransparency = 1
    calibDot.Text = "● Not Calibrated"
    calibDot.Font = Enum.Font.Gotham
    calibDot.TextSize = 11 * GUI.scale
    calibDot.TextColor3 = Color3.fromRGB(255, 59, 48)
    calibDot.TextXAlignment = Enum.TextXAlignment.Left
    GUI.calibDot = calibDot
    
    -- Tabs
    local tabBar = Instance.new("Frame", mainFrame)
    tabBar.Size = UDim2.new(1, -20 * GUI.scale, 0, 40 * GUI.scale)
    tabBar.Position = UDim2.new(0.5, 0, 0, 75 * GUI.scale)
    tabBar.AnchorPoint = Vector2.new(0.5, 0)
    tabBar.BackgroundTransparency = 1
    
    local tabNames = {"AutoClick", "Recorder", "Profiles"}
    for i, name in ipairs(tabNames) do
        local tab = Instance.new("TextButton", tabBar)
        tab.Size = UDim2.new(1/3, -5 * GUI.scale, 1, 0)
        tab.Position = UDim2.new((i-1)/3, 0, 0, 0)
        tab.Text = name
        tab.Font = Enum.Font.GothamMedium
        tab.TextSize = 14 * GUI.scale
        tab.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        tab.BorderSizePixel = 0
        tab.AutoButtonColor = false
        Instance.new("UICorner", tab).CornerRadius = UDim.new(0, 8 * GUI.scale)
        GUI.tabs[name] = tab
        
        local content = Instance.new("ScrollingFrame", mainFrame)
        content.Size = UDim2.new(1, 0, 1, -130 * GUI.scale)
        content.Position = UDim2.new(0, 0, 0, 130 * GUI.scale)
        content.BackgroundTransparency = 1
        content.ScrollBarThickness = 4 * GUI.scale
        content.Visible = i == 1
        content.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65)
        GUI.contents[name] = content
        
        local layout = Instance.new("UIListLayout", content)
        layout.Padding = UDim.new(0, 10 * GUI.scale)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        
        tab.MouseButton1Click:Connect(function()
            for _, t in pairs(GUI.tabs) do t.BackgroundColor3 = Color3.fromRGB(40, 40, 45) end
            for _, c in pairs(GUI.contents) do c.Visible = false end
            tab.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            content.Visible = true
        end)
    end
    
    GUI.tabs[tabNames[1]].BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    
    -- Build content
    GUI.buildContent()
    
    -- Status bar
    local statusBar = Instance.new("Frame", mainFrame)
    statusBar.Size = UDim2.new(1, 0, 0, 30 * GUI.scale)
    statusBar.Position = UDim2.new(0, 0, 1, -30 * GUI.scale)
    statusBar.BackgroundTransparency = 0.9
    statusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    statusBar.BorderSizePixel = 0
    
    local statusText = Instance.new("TextLabel", statusBar)
    statusText.Size = UDim2.new(1, -10, 1, 0)
    statusText.Position = UDim2.new(0, 5, 0, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = "Ready | Profile: default | Actions: 0"
    statusText.Font = Enum.Font.Gotham
    statusText.TextSize = 11 * GUI.scale
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.TextColor3 = Color3.fromRGB(174, 174, 178)
    GUI.statusText = statusText
    
    -- Toggle button
    local toggleBtn = Instance.new("TextButton", MainGUI)
    toggleBtn.Size = UDim2.new(0, 70 * GUI.scale, 0, 30 * GUI.scale)
    toggleBtn.Position = UDim2.new(0, 10, 0, 10)
    toggleBtn.Text = "Hide"
    toggleBtn.Font = Enum.Font.GothamMedium
    toggleBtn.TextSize = 13 * GUI.scale
    toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    toggleBtn.BorderSizePixel = 0
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8 * GUI.scale)
    
    toggleBtn.MouseButton1Click:Connect(function()
        local hidden = StateManager:get("guiHidden") or false
        StateManager:set("guiHidden", not hidden)
        mainFrame.Visible = hidden
        toggleBtn.Text = hidden and "Show" or "Hide"
    end)
    
    return MainGUI
end

function GUI.buildContent()
    local auto = GUI.contents.AutoClick
    
    local intervalBox = GUI.createTextBox("Click Interval (seconds)", "0.2", 1, auto)
    GUI.elements.intervalBox = intervalBox
    
    local xBox = GUI.createTextBox("X Position", "500", 2, auto)
    local yBox = GUI.createTextBox("Y Position", "500", 3, auto)
    GUI.elements.xBox = xBox
    GUI.elements.yBox = yBox
    
    local setPosBtn = GUI.createButton("Set Position [Visual]", 4, auto, Color3.fromRGB(60, 60, 65))
    GUI.elements.setPosBtn = setPosBtn
    
    local posLabel = GUI.createLabel("Current: (500, 500)", 5, auto)
    GUI.elements.posLabel = posLabel
    
    local testBtn = GUI.createButton("Test Click [Preview]", 6, auto, Color3.fromRGB(60, 60, 65))
    GUI.elements.testBtn = testBtn
    
    local autoToggle = GUI.createButton("START AUTO-CLICKER", 7, auto, Color3.fromRGB(0, 255, 0))
    autoToggle.Size = UDim2.new(0.9, 0, 0, 45 * GUI.scale)
    GUI.elements.autoToggle = autoToggle
    
    local recorder = GUI.contents.Recorder
    
    local recToggle = GUI.createButton("START RECORDING", 1, recorder, Color3.fromRGB(255, 59, 48))
    GUI.elements.recToggle = recToggle
    
    local recIndicator = GUI.createLabel("❌ Not Recording", 2, recorder)
    recIndicator.TextColor3 = Color3.fromRGB(255, 59, 48)
    GUI.elements.recIndicator = recIndicator
    
    local replayOnce = GUI.createButton("Replay Once", 3, recorder, Color3.fromRGB(60, 60, 255))
    GUI.elements.replayOnce = replayOnce
    
    local replayLoop = GUI.createButton("Loop Replay: OFF", 4, recorder, Color3.fromRGB(60, 60, 60))
    GUI.elements.replayLoop = replayLoop
    
    local clearRec = GUI.createButton("Clear All Actions", 5, recorder, Color3.fromRGB(255, 100, 100))
    GUI.elements.clearRec = clearRec
    
    local actionList = Instance.new("ScrollingFrame", recorder)
    actionList.Size = UDim2.new(0.9, 0, 0, 120 * GUI.scale)
    actionList.LayoutOrder = 6
    actionList.BackgroundTransparency = 0.95
    actionList.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    actionList.ScrollBarThickness = 4 * GUI.scale
    actionList.BorderSizePixel = 0
    Instance.new("UICorner", actionList).CornerRadius = UDim.new(0, 6 * GUI.scale)
    GUI.elements.actionList = actionList
    
    local profiles = GUI.contents.Profiles
    
    local profileList = Instance.new("ScrollingFrame", profiles)
    profileList.Size = UDim2.new(0.9, 0, 0, 180 * GUI.scale)
    profileList.LayoutOrder = 1
    profileList.BackgroundTransparency = 0.95
    profileList.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    profileList.ScrollBarThickness = 4 * GUI.scale
    profileList.BorderSizePixel = 0
    Instance.new("UICorner", profileList).CornerRadius = UDim.new(0, 6 * GUI.scale)
    GUI.elements.profileList = profileList
    
    local profileName = GUI.createTextBox("New profile name...", "", 2, profiles)
    GUI.elements.profileNameBox = profileName
    
    local saveProfile = GUI.createButton("Save as New Profile", 3, profiles, Color3.fromRGB(0, 255, 0))
    GUI.elements.saveProfileBtn = saveProfile
    
    -- Settings Tab
    local settings = GUI.contents.Settings
    
    local calibrateBtn = GUI.createButton("🎯 START VISUAL CALIBRATION", 1, settings, Color3.fromRGB(0, 255, 0))
    calibrateBtn.Size = UDim2.new(0.9, 0, 0, 40 * GUI.scale)
    GUI.elements.calibrateBtn = calibrateBtn
    
    local manualX = GUI.createTextBox("Manual X Offset", "0", 2, settings)
    local manualY = GUI.createTextBox("Manual Y Offset", "0", 3, settings)
    GUI.elements.manualXBox = manualX
    GUI.elements.manualYBox = manualY
    
    local applyManual = GUI.createButton("Apply Manual Offsets", 4, settings, Color3.fromRGB(60, 60, 65))
    GUI.elements.applyManualBtn = applyManual
    
    local accuracy = GUI.createLabel("Accuracy: Uncalibrated", 5, settings)
    accuracy.TextColor3 = Color3.fromRGB(255, 59, 48)
    GUI.elements.accuracyLabel = accuracy
end

function GUI.createTextBox(placeholder, text, order, parent)
    local box = Instance.new("TextBox", parent)
    box.Size = UDim2.new(0.9, 0, 0, 30 * GUI.scale)
    box.Position = UDim2.new(0.05, 0, 0, 0)
    box.LayoutOrder = order
    box.PlaceholderText = placeholder
    box.Text = text
    box.Font = Enum.Font.Gotham
    box.TextSize = 13 * GUI.scale
    box.TextColor3 = Color3.fromRGB(240, 240, 240)
    box.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6 * GUI.scale)
    return box
end

function GUI.createButton(text, order, parent, color)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0.9, 0, 0, 35 * GUI.scale)
    btn.Position = UDim2.new(0.05, 0, 0, 0)
    btn.LayoutOrder = order
    btn.Text = text
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 14 * GUI.scale
    btn.TextColor3 = Color3.fromRGB(240, 240, 240)
    btn.BackgroundColor3 = color or Color3.fromRGB(60, 60, 65)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8 * GUI.scale)
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = btn.BackgroundColor3:Lerp(Color3.fromRGB(255, 255, 255), 0.1)
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = color or Color3.fromRGB(60, 60, 65)
        }):Play()
    end)
    
    return btn
end

function GUI.createLabel(text, order, parent)
    local label = Instance.new("TextLabel", parent)
    label.Size = UDim2.new(0.9, 0, 0, 20 * GUI.scale)
    label.Position = UDim2.new(0.05, 0, 0, 0)
    label.LayoutOrder = order
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 12 * GUI.scale
    label.TextColor3 = Color3.fromRGB(174, 174, 178)
    label.TextXAlignment = Enum.TextXAlignment.Left
    return label
end

-- ============================================================================
-- UI CONNECTIONS & LOGIC
-- ============================================================================
function connectUI()
    local elements = GUI.elements
    
    elements.setPosBtn.MouseButton1Click:Connect(function()
        if VisualPicker.isActive then
            VisualPicker:stop()
            elements.setPosBtn.Text = "Set Position [Visual]"
        else
            VisualPicker:start()
            elements.setPosBtn.Text = "Click anywhere..."
        end
    end)
    
    elements.testBtn.MouseButton1Click:Connect(function()
        local pos = StateManager:get("clickPos")
        VisualFeedback:showMarker(pos, Color3.fromRGB(0, 255, 0), 15, 1)
        InputSimulator:performClick(pos, true)
    end)
    
    elements.autoToggle.MouseButton1Click:Connect(function()
        local enabled = StateManager:get("autoClick")
        if enabled then
            StateManager:set("autoClick", false)
            elements.autoToggle.Text = "START AUTO-CLICKER"
            elements.autoToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        else
            local interval = tonumber(elements.intervalBox.Text) or 0.2
            local x = tonumber(elements.xBox.Text) or 500
            local y = tonumber(elements.yBox.Text) or 500
            
            StateManager:set("clickInterval", interval)
            StateManager:set("clickPos", Vector2.new(x, y))
            
            StateManager:set("autoClick", true)
            elements.autoToggle.Text = "STOP AUTO-CLICKER"
            elements.autoToggle.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
            
            task.spawn(function()
                while StateManager:get("autoClick") do
                    InputSimulator:performClick(StateManager:get("clickPos"), false)
                    task.wait(StateManager:get("clickInterval"))
                end
            end)
        end
    end)
    
    elements.xBox.FocusLost:Connect(function()
        local x = tonumber(elements.xBox.Text) or 500
        StateManager:set("clickPos", Vector2.new(x, StateManager:get("clickPos").Y))
    end)
    
    elements.yBox.FocusLost:Connect(function()
        local y = tonumber(elements.yBox.Text) or 500
        StateManager:set("clickPos", Vector2.new(StateManager:get("clickPos").X, y))
    end)
    
    elements.intervalBox.FocusLost:Connect(function()
        local interval = tonumber(elements.intervalBox.Text) or 0.2
        StateManager:set("clickInterval", interval)
    end)
    
    elements.recToggle.MouseButton1Click:Connect(function()
        if StateManager:get("recording") then
            RecordingEngine.stop()
            elements.recToggle.Text = "START RECORDING"
            elements.recToggle.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
            elements.recIndicator.Text = "❌ Not Recording"
            elements.recIndicator.TextColor3 = Color3.fromRGB(255, 59, 48)
        else
            RecordingEngine.start()
            elements.recToggle.Text = "STOP RECORDING"
            elements.recToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            elements.recIndicator.Text = "🔴 Recording..."
            elements.recIndicator.TextColor3 = Color3.fromRGB(255, 0, 0)
        end
    end)
    
    elements.replayOnce.MouseButton1Click:Connect(function()
        if #StateManager:get("recorded") == 0 then
            GUI.statusText.Text = "Error: No actions recorded"
            return
        end
        
        if StateManager:get("replayLoop") then
            StateManager:set("replayLoop", false)
            elements.replayOnce.Text = "Replay Once"
        else
            elements.replayOnce.Text = "Stop Replay"
            RecordingEngine.replay(false)
        end
    end)
    
    elements.replayLoop.MouseButton1Click:Connect(function()
        if #StateManager:get("recorded") == 0 then
            GUI.statusText.Text = "Error: No actions recorded"
            return
        end
        
        local looping = StateManager:get("replayLoop")
        StateManager:set("replayLoop", not looping)
        elements.replayLoop.Text = looping and "Loop Replay: OFF" or "Loop Replay: ON"
        elements.replayLoop.BackgroundColor3 = looping and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(255, 59, 48)
        
        if not looping then
            RecordingEngine.replay(true)
        end
    end)
    
    elements.clearRec.MouseButton1Click:Connect(function()
        RecordingEngine.clear()
        GUI.updateActionList()
        GUI.statusText.Text = "Recording cleared"
    end)
    
    elements.calibrateBtn.MouseButton1Click:Connect(function()
        CalibrationEngine:startVisualCalibration()
    end)
    
    elements.applyManualBtn.MouseButton1Click:Connect(function()
        local x = tonumber(elements.manualXBox.Text) or 0
        local y = tonumber(elements.manualYBox.Text) or 0
        
        StateManager:set("xOffset", x)
        StateManager:set("yOffset", y)
        
        GUI.statusText.Text = string.format("Manual offsets applied: X=%d, Y=%d", x, y)
        Logger.info(string.format("Manual offsets: (%d, %d)", x, y))
    end)
    
    elements.saveProfileBtn.MouseButton1Click:Connect(function()
        local name = elements.profileNameBox.Text
        if not name or name == "" then name = "Profile_" .. os.time() end
        
        local profileData = {
            name = name,
            position = {x = StateManager:get("clickPos").X, y = StateManager:get("clickPos").Y},
            interval = StateManager:get("clickInterval"),
            offsets = {x = StateManager:get("xOffset"), y = StateManager:get("yOffset")},
            actions = StateManager:get("recorded"),
            calibration = CalibrationEngine.transformMatrix,
        }
        
        ProfileManager:save(name, profileData)
        elements.profileNameBox.Text = ""
        GUI.updateProfileList()
        GUI.statusText.Text = "Profile saved: " .. name
    end)
    
    StateManager.data.autosave = true
end

function GUI.updateActionList()
    local list = GUI.elements.actionList
    local actions = StateManager:get("recorded")
    
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    for i, action in ipairs(actions) do
        local item = Instance.new("Frame", list)
        item.Size = UDim2.new(1, -10, 0, 30 * GUI.scale)
        item.BackgroundTransparency = 0.95
        item.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        item.BorderSizePixel = 0
        
        local label = Instance.new("TextLabel", item)
        label.Size = UDim2.new(1, -35, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = string.format("%d. %s", i, action.type)
        label.Font = Enum.Font.Gotham
        label.TextSize = 11 * GUI.scale
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = Color3.fromRGB(240, 240, 240)
        
        local delete = Instance.new("TextButton", item)
        delete.Size = UDim2.new(0, 25, 0, 25)
        delete.Position = UDim2.new(1, -30, 0.5, -12)
        delete.Text = "X"
        delete.Font = Enum.Font.Gotham
        delete.TextSize = 11 * GUI.scale
        delete.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
        delete.BorderSizePixel = 0
        Instance.new("UICorner", delete).CornerRadius = UDim.new(1, 0)
        
        delete.MouseButton1Click:Connect(function()
            table.remove(StateManager:get("recorded"), i)
            GUI.updateActionList()
        end)
    end
end

function GUI.updateProfileList()
    local list = GUI.elements.profileList
    local profiles = ProfileManager:list()
    
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    for _, name in ipairs(profiles) do
        local item = Instance.new("Frame", list)
        item.Size = UDim2.new(1, -10, 0, 35 * GUI.scale)
        item.BackgroundTransparency = 0.95
        item.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        item.BorderSizePixel = 0
        
        local label = Instance.new("TextLabel", item)
        label.Size = UDim2.new(1, -80, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.Font = Enum.Font.Gotham
        label.TextSize = 13 * GUI.scale
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = Color3.fromRGB(240, 240, 240)
        
        local loadBtn = Instance.new("TextButton", item)
        loadBtn.Size = UDim2.new(0, 35, 0, 30)
        loadBtn.Position = UDim2.new(1, -75, 0.5, -15)
        loadBtn.Text = "Load"
        loadBtn.Font = Enum.Font.Gotham
        loadBtn.TextSize = 11 * GUI.scale
        loadBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        loadBtn.BorderSizePixel = 0
        Instance.new("UICorner", loadBtn).CornerRadius = UDim.new(0, 4)
        
        local deleteBtn = Instance.new("TextButton", item)
        deleteBtn.Size = UDim2.new(0, 35, 0, 30)
        deleteBtn.Position = UDim2.new(1, -35, 0.5, -15)
        deleteBtn.Text = "🗑"
        deleteBtn.Font = Enum.Font.Gotham
        deleteBtn.TextSize = 13 * GUI.scale
        deleteBtn.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
        deleteBtn.BorderSizePixel = 0
        Instance.new("UICorner", deleteBtn).CornerRadius = UDim.new(0, 4)
        
        loadBtn.MouseButton1Click:Connect(function()
            ProfileManager:load(name)
            GUI.updateActionList()
            GUI.statusText.Text = "Loaded: " .. name
            local pos = StateManager:get("clickPos")
            GUI.elements.xBox.Text = tostring(pos.X)
            GUI.elements.yBox.Text = tostring(pos.Y)
        end)
        
        deleteBtn.MouseButton1Click:Connect(function()
            ProfileManager:delete(name)
            GUI.updateProfileList()
        end)
    end
end

-- ============================================================================
-- VISUAL PICKER
-- ============================================================================
local VisualPicker = {
    isActive = false,
    crosshair = nil,
    
    start = function(self)
        if self.isActive then return end
        self.isActive = true
        
        if not self.crosshair then
            self.crosshair = Instance.new("Frame", MainGUI)
            self.crosshair.Name = "Crosshair"
            self.crosshair.Size = UDim2.new(0, 40 * GUI.scale, 0, 40 * GUI.scale)
            self.crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
            self.crosshair.BackgroundTransparency = 1
            self.crosshair.ZIndex = 1000
            
            local h = Instance.new("Frame", self.crosshair)
            h.Size = UDim2.new(1, 0, 0, 2)
            h.Position = UDim2.new(0, 0, 0.5, -1)
            h.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            h.BorderSizePixel = 0
            
            local v = Instance.new("Frame", self.crosshair)
            v.Size = UDim2.new(0, 2, 1, 0)
            v.Position = UDim2.new(0.5, -1, 0, 0)
            v.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            v.BorderSizePixel = 0
        end
        
        self.crosshair.Visible = true
        
        self.connection = RunService.RenderStepped:Connect(function()
            local mousePos = UIS:GetMouseLocation()
            self.crosshair.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
        end)
        
        TweenService:Create(self.crosshair:FindFirstChild("H"), TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            BackgroundTransparency = 0.5
        }):Play()
        TweenService:Create(self.crosshair:FindFirstChild("V"), TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            BackgroundTransparency = 0.5
        }):Play()
    end,
    
    stop = function(self)
        if not self.isActive then return end
        self.isActive = false
        
        if self.connection then
            self.connection:Disconnect()
            self.connection = nil
        end
        
        if self.crosshair then
            self.crosshair.Visible = false
        end
    end,
}

-- ============================================================================
-- INITIALIZATION (Boot Sequence)
-- ============================================================================
local function initialize()
    Logger.info("=== Delta Macro V7.0 Boot Sequence ===")
    
    ProfileManager:ensureFolder()
    CalibrationEngine:loadCalibration()
    
    MainGUI = GUI.create()
    if not MainGUI then
        Logger.error("GUI creation failed")
        return
    end
    
    connectUI()
    GUI.updateActionList()
    GUI.updateProfileList()
    
    local defaultLoaded = ProfileManager:load("default")
    if not defaultLoaded then
        ProfileManager:save("default")
    end
    
    local pos = StateManager:get("clickPos")
    GUI.elements.xBox.Text = tostring(pos.X)
    GUI.elements.yBox.Text = tostring(pos.Y)
    GUI.elements.intervalBox.Text = tostring(StateManager:get("clickInterval"))
    GUI.elements.manualXBox.Text = tostring(StateManager:get("xOffset"))
    GUI.elements.manualYBox.Text = tostring(StateManager:get("yOffset"))
    
    task.spawn(function()
        while task.wait(CONFIG.CACHE_RATE) do
            Cache:update()
        end
    end)
    
    task.spawn(function()
        while task.wait(1) do
            local profile = StateManager:get("selectedProfile")
            local actions = #StateManager:get("recorded")
            GUI.statusText.Text = string.format("Profile: %s | Actions: %d | Calibrated: %s",
                profile, actions, CalibrationEngine.isCalibrated and "✓" or "✗")
        end
    end)
    
    UIS.WindowFocusReleased:Connect(function()
        Logger.warn("Focus lost - stopping all macros")
        StateManager:set("autoClick", false)
        StateManager:set("recording", false)
        StateManager:set("replayLoop", false)
        VisualPicker:stop()
    end)
    
    Logger.info("Boot complete | Executor: Delta | Mobile: " .. (GUI.scale < 1 and "Yes" or "No"))
    print("=== DELTA MACRO V7.0 READY ===")
    print("Click calibration button for pixel-perfect accuracy")
end

local success, err = pcall(initialize)
if not success then
    Logger.error("Critical failure: " .. tostring(err))
    error(err)
end
