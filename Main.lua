-- Delta Executor Macro V5.1 | Performance Optimized & Bug Fixed
-- Optimized for Delta - Exact pixel clicking, no humanization
-- FIXED: HttpService nil error, calibration issues, CPU usage, GUI stability

----------------------------------------------------------------
-- CONFIGURATION CONSTANTS
----------------------------------------------------------------
local CONFIG = {
    -- Delta-Specific
    GUI_PARENT = "PlayerGui", -- More stable on Delta
    SHOW_DEBUG_MARKERS = true,
    
    -- Performance Optimized
    CACHE_REFRESH_RATE = 2,
    USE_HEARTBEAT_WAIT = true,
    MIN_CLICK_HOLD = 0.05,
    
    -- Coordinate System
    FALLBACK_INSET = Vector2.new(0, 36),
    CALIBRATION_TIMEOUT = 10,
}

----------------------------------------------------------------
-- SERVICE INITIALIZATION (FIXED)
----------------------------------------------------------------
local Services = {}
local function getService(name)
    local success, service = pcall(function()
        return game:GetService(name)
    end)
    if success and service then return service end
    
    local success2, service2 = pcall(function()
        return game[name]
    end)
    if success2 and service2 then return service2 end
    
    return nil
end

-- Initialize all services safely
Services.Players = getService("Players") or {}
Services.UserInputService = getService("UserInputService") or {}
Services.StarterGui = getService("StarterGui") or {}
Services.RunService = getService("RunService") or {}
Services.GuiService = getService("GuiService") or {}
Services.CoreGui = getService("CoreGui") or game:FindFirstChild("CoreGui")
Services.TweenService = getService("TweenService") or {}
Services.HttpService = getService("HttpService") or {}
Services.Workspace = workspace or game:FindFirstChild("Workspace")

-- Validate critical services
if not Services.TweenService then
    warn("[DeltaMacro] TweenService not available - animations disabled")
    -- Create dummy TweenService
    Services.TweenService = {
        Create = function() return {Play = function() end} end
    }
end

if not Services.HttpService then
    warn("[DeltaMacro] HttpService not available - JSON functions disabled")
end

local LocalPlayer = Services.Players.LocalPlayer
if not LocalPlayer then
    error("[DeltaMacro] CRITICAL: LocalPlayer not found")
end

----------------------------------------------------------------
-- LOGGER MODULE
----------------------------------------------------------------
local Logger = {
    enabled = true,
    prefix = "[DeltaMacro]",
    
    log = function(self, level, message, data)
        if not self.enabled then return end
        local output = string.format("%s %s [%s] %s", 
            self.prefix, os.date("%H:%M:%S"), level, message)
        if data and Services.HttpService then
            local success, json = pcall(function()
                return Services.HttpService:JSONEncode(data)
            end)
            if success then output = output .. " | " .. json end
        end
        print(output)
    end,
    
    info = function(self, message, data) self:log("INFO", message, data) end,
    warn = function(self, message, data) self:log("WARN", message, data) end,
    error = function(self, message, data) self:log("ERROR", message, data) end,
}

----------------------------------------------------------------
-- DELTA COMPATIBILITY LAYER (OPTIMIZED)
----------------------------------------------------------------
local Compatibility = {
    detectedExecutor = "unknown",
    VirtualInputManager = nil,
    vmAvailable = false,
    httpGet = nil,
    setClipboard = nil,
}

function Compatibility:DetectEnvironment()
    -- Delta-first detection
    if http_request then
        self.detectedExecutor = "Delta"
        self.httpGet = function(url) 
            local resp = http_request({Url = url, Method = "GET"})
            return resp and resp.Body or ""
        end
        Logger:info("Delta Executor detected and configured")
    elseif syn and syn.request then
        self.detectedExecutor = "Synapse"
        self.httpGet = function(url) return syn.request({Url = url, Method = "GET"}).Body end
        Logger:info("Synapse detected")
    elseif request then
        self.detectedExecutor = "KRNL/Other"
        self.httpGet = function(url) return request({Url = url, Method = "GET"}).Body end
        Logger:info("KRNL/Other executor detected")
    elseif game.HttpGet then
        self.detectedExecutor = "Standard"
        self.httpGet = function(url) return game:HttpGet(url, true) end
        Logger:warn("Standard HTTP fallback - may have issues")
    else
        Logger:error("No HTTP method found!")
        self.httpGet = function() return "" end
    end
    
    -- Clipboard
    self.setClipboard = function(text)
        local clippers = {setclipboard, writeclipboard, syn and syn.write_clipboard, toclipboard}
        for _, clip in ipairs(clippers) do
            if clip then
                local success = pcall(function() clip(text) end)
                return success
            end
        end
        return false
    end
    
    self:InitializeVIM()
end

function Compatibility:InitializeVIM()
    -- Multiple detection methods for Delta
    local detectors = {
        function() return getService("VirtualInputManager") end,
        function() return (getrenv and getrenv() or {}).VirtualInputManager end,
        function() return (getfenv and getfenv() or {}).VirtualInputManager end,
        function() return shared and shared.VirtualInputManager end,
    }
    
    for _, detector in ipairs(detectors) do
        local success, vim = pcall(detector)
        if success and vim then
            self.VirtualInputManager = vim
            self.vmAvailable = true
            Logger:info("VIM initialized via " .. self.detectedExecutor)
            break
        end
    end
    
    -- Test VIM after delay
    task.delay(1, function()
        if self.vmAvailable then
            local test = pcall(function() self.VirtualInputManager:SendMouseMoveEvent(100, 100) end)
            if test then
                Logger:info("VIM test successful")
            else
                self.vmAvailable = false
                Logger:error("VIM test failed - executor may not support it")
            end
        end
    end)
end

function Compatibility:SafeSendMouseMove(x, y)
    if not self.vmAvailable then return end
    pcall(function() self.VirtualInputManager:SendMouseMoveEvent(x, y, game, 0) end)
end

function Compatibility:SafeSendMouseButton(x, y, button, isDown)
    if not self.vmAvailable then return end
    pcall(function() self.VirtualInputManager:SendMouseButtonEvent(x, y, button, isDown, game, 0) end)
end

----------------------------------------------------------------
-- STATE MANAGER
----------------------------------------------------------------
local StateManager = {
    data = {
        autoClickEnabled = false,
        clickInterval = 0.2,
        clickPosition = Vector2.new(500, 500),
        isRecording = false,
        recordedActions = {},
        recordStartTime = 0,
        replayCount = 1,
        isReplaying = false,
        isReplayingLoop = false,
        activeXOffset = 0,
        activeYOffset = 0,
        guiHidden = false,
        lastViewportSize = Vector2.new(1920, 1080),
        lastGuiInset = Vector2.new(0, 36),
        currentProfile = "default",
    },
    
    subscribers = {},
    
    set = function(self, key, value)
        local oldValue = self.data[key]
        self.data[key] = value
        
        if self.subscribers[key] then
            for _, callback in ipairs(self.subscribers[key]) do
                pcall(callback, value, oldValue)
            end
        end
    end,
    
    get = function(self, key)
        return self.data[key]
    end,
    
    subscribe = function(self, key, callback)
        if not self.subscribers[key] then
            self.subscribers[key] = {}
        end
        table.insert(self.subscribers[key], callback)
    end,
}

----------------------------------------------------------------
-- CACHE MODULE (PERFORMANCE)
----------------------------------------------------------------
local Cache = {
    viewportSize = Vector2.new(1920, 1080),
    guiInset = Vector2.new(0, 36),
    lastUpdate = 0,
    
    update = function(self)
        local now = os.clock()
        if now - self.lastUpdate < CONFIG.CACHE_REFRESH_RATE then return end
        self.lastUpdate = now
        
        local success, inset = pcall(function() return Services.GuiService:GetGuiInset() end)
        self.guiInset = success and inset or CONFIG.FALLBACK_INSET
        self.viewportSize = Services.Workspace.CurrentCamera and Services.Workspace.CurrentCamera.ViewportSize or self.viewportSize
        
        StateManager:set("lastViewportSize", self.viewportSize)
        StateManager:set("lastGuiInset", self.guiInset)
    end,
}

----------------------------------------------------------------
-- DISABLED HUMANIZER (PASSTHROUGH)
----------------------------------------------------------------
local Humanizer = {
    applyJitter = function(self, pos) return pos end,
    applyDelay = function(self, baseDelay) return baseDelay end,
    getRandomCurve = function(self) return 0 end,
}

----------------------------------------------------------------
-- COORDINATE SYSTEM (FIXED)
----------------------------------------------------------------
local CoordinateSystem = {
    viewportToExecutor = function(self, viewportPos)
        Cache:update()
        local inset = Cache.guiInset
        local xOffset = StateManager:get("activeXOffset")
        local yOffset = StateManager:get("activeYOffset")
        
        return Vector2.new(
            math.floor(viewportPos.X + inset.X + xOffset),
            math.floor(viewportPos.Y + inset.Y + yOffset)
        )
    end,
}

----------------------------------------------------------------
-- INPUT SIMULATION (EXACT PIXEL)
----------------------------------------------------------------
local InputSimulator = {
    performClick = function(self, viewportPos, button)
        button = button or 0
        local executorPos = CoordinateSystem:viewportToExecutor(viewportPos)
        
        Compatibility:SafeSendMouseMove(executorPos.X, executorPos.Y)
        task.wait(CONFIG.MIN_CLICK_HOLD)
        Compatibility:SafeSendMouseButton(executorPos.X, executorPos.Y, button, true)
        task.wait(CONFIG.MIN_CLICK_HOLD)
        Compatibility:SafeSendMouseButton(executorPos.X, executorPos.Y, button, false)
        
        return executorPos
    end,
    
    performSwipe = function(self, startViewport, endViewport, duration, customCurve)
        local startPos = CoordinateSystem:viewportToExecutor(startViewport)
        local endPos = CoordinateSystem:viewportToExecutor(endViewport)
        local curve = customCurve or 0
        
        local dx, dy = endPos.X - startPos.X, endPos.Y - startPos.Y
        local dist = (endPos - startPos).Magnitude
        local steps = math.max(3, math.floor((duration or 0.2) * 60))
        
        local perpX, perpY = 0, 0
        if curve ~= 0 and dist > 0 then
            perpX = -dy / dist
            perpY = dx / dist
        end
        
        Compatibility:SafeSendMouseMove(startPos.X, startPos.Y)
        task.wait(CONFIG.MIN_CLICK_HOLD)
        Compatibility:SafeSendMouseButton(startPos.X, startPos.Y, 0, true)
        
        for i = 1, steps do
            local t = i / steps
            local eased = self:_easingQuad(t)
            local baseX = startPos.X + (endPos.X - startPos.X) * eased
            local baseY = startPos.Y + (endPos.Y - startPos.Y) * eased
            local curveAmount = curve * dist * (1 - math.abs(2 * t - 1))
            
            Compatibility:SafeSendMouseMove(baseX + perpX * curveAmount, baseY + perpY * curveAmount)
            task.wait(duration / steps)
        end
        
        Compatibility:SafeSendMouseMove(endPos.X, endPos.Y)
        Compatibility:SafeSendMouseButton(endPos.X, endPos.Y, 0, false)
    end,
    
    keyPress = function(self, keyCode, holdTime)
        if not Compatibility.vmAvailable then return end
        holdTime = holdTime or 0.1
        
        pcall(function()
            Compatibility.VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
            task.wait(holdTime)
            Compatibility.VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
        end)
    end,
    
    _easingQuad = function(self, t)
        return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t
    end,
}

----------------------------------------------------------------
-- VISUAL FEEDBACK (OPTIMIZED)
----------------------------------------------------------------
local VisualFeedback = {
    markers = {},
    markerPool = {},
    
    showClickMarker = function(self, viewportPos, color, size, duration)
        if not CONFIG.SHOW_DEBUG_MARKERS then return end
        
        -- Pooling optimization
        local marker = table.remove(self.markerPool)
        if not marker then
            marker = Instance.new("Frame")
            marker.BorderSizePixel = 0
            local corner = Instance.new("UICorner", marker)
            corner.CornerRadius = UDim.new(1, 0)
        end
        
        size = size or 15
        marker.Size = UDim2.new(0, size, 0, size)
        marker.Position = UDim2.new(0, viewportPos.X - size/2, 0, viewportPos.Y - size/2)
        marker.BackgroundColor3 = color or Color3.fromRGB(255, 0, 0)
        marker.BackgroundTransparency = 0.3
        marker.ZIndex = 1000
        marker.Parent = MainGUI
        
        table.insert(self.markers, marker)
        
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
            for i, m in ipairs(self.markers) do
                if m == marker then table.remove(self.markers, i) break end
            end
        end)
    end,
}

----------------------------------------------------------------
-- RECORDING ENGINE (FIXED)
----------------------------------------------------------------
local RecordingEngine = {
    activeInputs = {},
    connections = {},
    
    startRecording = function(self)
        self:stopRecording()
        StateManager:set("isRecording", true)
        StateManager:set("recordedActions", {})
        StateManager:set("recordStartTime", os.clock())
        
        Logger:info("Recording started")
        
        self.connections.began = Services.UserInputService.InputBegan:Connect(function(input, gp)
            if gp or not StateManager:get("isRecording") then return end
            
            local pos = input.Position or Services.UserInputService:GetMouseLocation()
            if self:_isOverGUI(pos) then return end
            
            self.activeInputs[input] = {
                startTime = os.clock(),
                startPos = pos,
                lastPos = pos,
                isDragging = false,
                keyCode = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or nil
            }
            
            if input.UserInputType == Enum.UserInputType.Keyboard and self.activeInputs[input].keyCode then
                table.insert(StateManager:get("recordedActions"), {
                    type = "keyPress",
                    keyCode = self.activeInputs[input].keyCode,
                    delay = 0
                })
            end
        end)
        
        self.connections.changed = Services.UserInputService.InputChanged:Connect(function(input)
            if not StateManager:get("isRecording") or not self.activeInputs[input] then return end
            
            local pos = input.Position or Services.UserInputService:GetMouseLocation()
            local data = self.activeInputs[input]
            
            if not data.isDragging and (pos - data.startPos).Magnitude >= 10 then
                data.isDragging = true
            end
            
            data.lastPos = pos
        end)
        
        self.connections.ended = Services.UserInputService.InputEnded:Connect(function(input, gp)
            if not StateManager:get("isRecording") or not self.activeInputs[input] then return end
            
            local now = os.clock()
            local data = self.activeInputs[input]
            local delay = now - StateManager:get("recordStartTime")
            StateManager:set("recordStartTime", now)
            
            local endPos = input.Position or Services.UserInputService:GetMouseLocation()
            
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then
                if data.isDragging then
                    table.insert(StateManager:get("recordedActions"), {
                        type = "swipe",
                        startPixel = data.startPos,
                        endPixel = endPos,
                        duration = math.max(0.02, now - data.startTime),
                        delay = delay
                    })
                else
                    table.insert(StateManager:get("recordedActions"), {
                        type = "tap",
                        pixelPos = data.startPos,
                        delay = delay
                    })
                end
            elseif input.UserInputType == Enum.UserInputType.Keyboard and data.keyCode then
                table.insert(StateManager:get("recordedActions"), {
                    type = "keyRelease",
                    keyCode = data.keyCode,
                    delay = delay
                })
            end
            
            self.activeInputs[input] = nil
        end)
    end,
    
    stopRecording = function(self)
        StateManager:set("isRecording", false)
        
        for _, conn in pairs(self.connections) do
            pcall(function() conn:Disconnect() end)
        end
        self.connections = {}
        self.activeInputs = {}
        
        Logger:info("Recording stopped. Actions: " .. #StateManager:get("recordedActions"))
    end,
    
    replayActions = function(self, actionList, loop)
        if not actionList or #actionList == 0 then return end
        
        local isLooping = loop or false
        local replayThread = task.spawn(function()
            local iteration = 1
            while true do
                if not StateManager:get("isReplaying") and not StateManager:get("isReplayingLoop") then break end
                
                for _, action in ipairs(actionList) do
                    if not StateManager:get("isReplaying") and not StateManager:get("isReplayingLoop") then break end
                    
                    if action.delay and action.delay > 0 then
                        task.wait(action.delay)
                    end
                    
                    if action.type == "tap" then
                        InputSimulator:performClick(action.pixelPos)
                        VisualFeedback:showClickMarker(action.pixelPos, Color3.fromRGB(0, 255, 0), 10, 0.5)
                    elseif action.type == "swipe" then
                        InputSimulator:performSwipe(action.startPixel, action.endPixel, action.duration, 0)
                    elseif action.type == "keyPress" then
                        InputSimulator:keyPress(action.keyCode, 0.1)
                    end
                end
                
                if not isLooping then
                    iteration = iteration + 1
                    if iteration > StateManager:get("replayCount") then break end
                    task.wait(0.1)
                else
                    task.wait(0.1)
                end
            end
            
            if isLooping then
                StateManager:set("isReplayingLoop", false)
            else
                StateManager:set("isReplaying", false)
            end
        end)
        
        if isLooping then
            StateManager:set("currentReplayLoopThread", replayThread)
        else
            StateManager:set("currentReplayThread", replayThread)
        end
    end,
    
    clearRecording = function(self)
        StateManager:set("recordedActions", {})
        Logger:info("Recording cleared")
    end,
    
    deleteAction = function(self, index)
        local actions = StateManager:get("recordedActions")
        if actions[index] then
            table.remove(actions, index)
            Logger:info("Action deleted at index: " .. index)
        end
    end,
    
    _isOverGUI = function(self, pos)
        local success, result = pcall(function()
            local guiObjects = Services.UserInputService:GetGuiObjectsAtPosition(
                math.floor(pos.X + 0.5), 
                math.floor(pos.Y + 0.5)
            )
            for _, obj in ipairs(guiObjects) do
                if obj:IsDescendantOf(MainGUI) then return true end
            end
            return false
        end)
        return success and result or false
    end,
}

----------------------------------------------------------------
-- PROFILE MANAGER
----------------------------------------------------------------
local ProfileManager = {
    folderName = "DeltaMacro_Profiles",
    
    ensureFolder = function(self)
        if not makefolder then return end
        pcall(function() makefolder(self.folderName) end)
    end,
    
    saveProfile = function(self, name, data)
        if not writefile then Logger:warn("writefile not available"); return false end
        
        name = name or StateManager:get("currentProfile")
        data = data or {
            actions = StateManager:get("recordedActions"),
            position = StateManager:get("clickPosition"),
            offsets = {x = StateManager:get("activeXOffset"), y = StateManager:get("activeYOffset")},
            settings = {
                clickInterval = StateManager:get("clickInterval"),
            },
            timestamp = os.time()
        }
        
        self:ensureFolder()
        local json = Services.HttpService:JSONEncode(data)
        writefile(self.folderName .. "/" .. name .. ".json", json)
        Logger:info("Profile saved: " .. name)
        return true
    end,
    
    loadProfile = function(self, name)
        if not readfile then Logger:warn("readfile not available"); return false end
        
        local success, data = pcall(function()
            local json = readfile(self.folderName .. "/" .. name .. ".json")
            return Services.HttpService:JSONDecode(json)
        end)
        
        if success and data then
            StateManager:set("recordedActions", data.actions or {})
            StateManager:set("clickPosition", data.position or Vector2.new(500, 500))
            StateManager:set("activeXOffset", data.offsets and data.offsets.x or 0)
            StateManager:set("activeYOffset", data.offsets and data.offsets.y or 0)
            StateManager:set("clickInterval", data.settings and data.settings.clickInterval or 0.2)
            
            Logger:info("Profile loaded: " .. name)
            return true
        end
        
        Logger:error("Failed to load profile: " .. name)
        return false
    end,
    
    deleteProfile = function(self, name)
        if not delfile then return false end
        pcall(function() delfile(self.folderName .. "/" .. name .. ".json") end)
        Logger:info("Profile deleted: " .. name)
    end,
    
    listProfiles = function(self)
        if not listfiles then return {} end
        
        local files = listfiles(self.folderName .. "/")
        local profiles = {}
        for _, file in ipairs(files) do
            local name = file:match("([^/]+)%.json$")
            if name then table.insert(profiles, name) end
        end
        return profiles
    end,
}

----------------------------------------------------------------
-- MODERN GUI (OPTIMIZED)
----------------------------------------------------------------
local UIManager = {
    createModernFrame = function(self, props)
        local frame = Instance.new("Frame")
        frame.Size = props.Size or UDim2.new(0, 300, 0, 400)
        frame.Position = props.Position
        frame.BackgroundColor3 = props.Color or Color3.fromRGB(30, 30, 35)
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.ClipsDescendants = true
        
        local corner = Instance.new("UICorner", frame)
        corner.CornerRadius = UDim.new(0, props.CornerRadius or 12)
        
        if props.UseGradient then
            local gradient = Instance.new("UIGradient", frame)
            gradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 35)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 40, 45))
            })
            gradient.Rotation = 45
        end
        
        if props.AddShadow then
            local shadow = Instance.new("ImageLabel", frame)
            shadow.Name = "Shadow"
            shadow.Image = "rbxassetid://1316045217"
            shadow.ScaleType = Enum.ScaleType.Slice
            shadow.SliceCenter = Rect.new(10, 10, 118, 118)
            shadow.ImageColor3 = Color3.new(0, 0, 0)
            shadow.ImageTransparency = 0.7
            shadow.BackgroundTransparency = 1
            shadow.Size = UDim2.new(1, 20, 1, 20)
            shadow.Position = UDim2.new(0, -10, 0, -10)
            shadow.ZIndex = frame.ZIndex - 1
        end
        
        return frame
    end,
    
    createModernButton = function(self, props)
        local button = Instance.new("TextButton")
        button.Size = props.Size or UDim2.new(0.9, 0, 0, 35)
        button.Position = props.Position
        button.Text = props.Text or "Button"
        button.Font = Enum.Font.GothamMedium
        button.TextSize = props.TextSize or 14
        button.TextColor3 = Color3.fromRGB(240, 240, 240)
        button.BackgroundColor3 = props.Color or Color3.fromRGB(60, 60, 65)
        button.BorderSizePixel = 0
        button.ZIndex = props.ZIndex or 1
        button.AutoButtonColor = false -- Performance optimization
        
        local corner = Instance.new("UICorner", button)
        corner.CornerRadius = UDim.new(0, props.CornerRadius or 8)
        
        if props.Hoverable ~= false then
            button.MouseEnter:Connect(function()
                if Services.TweenService then
                    Services.TweenService:Create(button, TweenInfo.new(0.15), {
                        BackgroundColor3 = button.BackgroundColor3:Lerp(Color3.new(1,1,1), 0.1)
                    }):Play()
                else
                    button.BackgroundColor3 = button.BackgroundColor3:Lerp(Color3.new(1,1,1), 0.1)
                end
            end)
            button.MouseLeave:Connect(function()
                if Services.TweenService then
                    Services.TweenService:Create(button, TweenInfo.new(0.15), {
                        BackgroundColor3 = props.Color or Color3.fromRGB(60, 60, 65)
                    }):Play()
                else
                    button.BackgroundColor3 = props.Color or Color3.fromRGB(60, 60, 65)
                end
            end)
        end
        
        return button
    end,
    
    createModernInput = function(self, props)
        local input = Instance.new("TextBox")
        input.Size = props.Size or UDim2.new(0.9, 0, 0, 30)
        input.Position = props.Position
        input.PlaceholderText = props.Placeholder or ""
        input.Text = props.Text or ""
        input.Font = Enum.Font.Gotham
        input.TextSize = props.TextSize or 13
        input.TextColor3 = Color3.fromRGB(240, 240, 240)
        input.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
        input.BorderSizePixel = 0
        input.ClearTextOnFocus = false
        
        local corner = Instance.new("UICorner", input)
        corner.CornerRadius = UDim.new(0, props.CornerRadius or 6)
        
        return input
    end,
}

----------------------------------------------------------------
-- MAIN GUI CREATION (OPTIMIZED)
----------------------------------------------------------------
local MainGUI = nil

local function createGUI()
    local guiParent = CONFIG.GUI_PARENT == "PlayerGui" and LocalPlayer:FindFirstChild("PlayerGui") or Services.CoreGui
    if not guiParent then
        Logger:error("No valid GUI parent found")
        return nil
    end
    
    MainGUI = Instance.new("ScreenGui")
    MainGUI.Name = "DeltaMacro_Gui"
    MainGUI.ResetOnSpawn = false
    MainGUI.IgnoreGuiInset = true
    MainGUI.ZIndexBehavior = Enum.ZIndexBehavior.Global
    MainGUI.Parent = guiParent
    
    -- Main Frame
    local mainFrame = UIManager:createModernFrame({
        Size = UDim2.new(0, 380, 0, 520),
        Position = UDim2.new(0.5, -190, 0.5, -260),
        Color = Color3.fromRGB(28, 28, 30),
        AddShadow = true,
        UseGradient = true,
        CornerRadius = 16
    })
    mainFrame.Name = "MainFrame"
    mainFrame.Visible = true
    MainGUI.MainFrame = mainFrame
    
    -- Title
    local titleBar = Instance.new("Frame", mainFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundTransparency = 1
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "Delta Macro V5.1"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.TextColor3 = Color3.fromRGB(0, 255, 0)
    
    -- Tabs
    local tabBar = Instance.new("Frame", mainFrame)
    tabBar.Size = UDim2.new(1, -20, 0, 40)
    tabBar.Position = UDim2.new(0.5, 0, 0, 50)
    tabBar.AnchorPoint = Vector2.new(0.5, 0)
    tabBar.BackgroundTransparency = 1
    
    local tabNames = {"AutoClick", "Recorder", "Settings", "Profiles"}
    local tabs = {}
    for i, name in ipairs(tabNames) do
        local tab = UIManager:createModernButton({
            Size = UDim2.new(0.25, -5, 1, 0),
            Position = UDim2.new((i-1)*0.25, 0, 0, 0),
            Text = name,
            Color = Color3.fromRGB(40, 40, 45)
        })
        tab.Name = name
        tab.Parent = tabBar
        table.insert(tabs, tab)
    end
    
    -- Content Area
    local contentArea = Instance.new("Frame", mainFrame)
    contentArea.Size = UDim2.new(1, 0, 1, -110)
    contentArea.Position = UDim2.new(0, 0, 0, 110)
    contentArea.BackgroundTransparency = 1
    
    -- Tab Contents
    local contents = {}
    for i, name in ipairs(tabNames) do
        local content = Instance.new("ScrollingFrame", contentArea)
        content.Size = UDim2.new(1, 0, 1, 0)
        content.BackgroundTransparency = 1
        content.ScrollBarThickness = 4
        content.Visible = i == 1
        content.Name = name .. "Content"
        content.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65)
        
        local layout = Instance.new("UIListLayout", content)
        layout.Padding = UDim.new(0, 10)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        
        table.insert(contents, content)
    end
    
    -- Build content elements
    local elements = {}
    
    -- AutoClick tab
    local autoContent = contents[1]
    elements.btnAutoToggle = UIManager:createModernButton({Text = "Auto Clicker: OFF", LayoutOrder = 1})
    elements.btnAutoToggle.Parent = autoContent
    
    elements.intervalInput = UIManager:createModernInput({Placeholder = "Click Interval (sec)", Text = "0.2", LayoutOrder = 2})
    elements.intervalInput.Parent = autoContent
    
    elements.btnSetPos = UIManager:createModernButton({Text = "Set Position [Visual]", LayoutOrder = 3})
    elements.btnSetPos.Parent = autoContent
    
    elements.currentPosLabel = Instance.new("TextLabel", autoContent)
    elements.currentPosLabel.Size = UDim2.new(0.9, 0, 0, 20)
    elements.currentPosLabel.BackgroundTransparency = 1
    elements.currentPosLabel.Text = "Current: (500, 500)"
    elements.currentPosLabel.Font = Enum.Font.Gotham
    elements.currentPosLabel.TextSize = 12
    elements.currentPosLabel.TextColor3 = Color3.fromRGB(174, 174, 178)
    elements.currentPosLabel.LayoutOrder = 4
    
    elements.btnTestClick = UIManager:createModernButton({Text = "Test Click [Preview]", LayoutOrder = 5})
    elements.btnTestClick.Parent = autoContent
    
    -- Recorder tab
    local recordContent = contents[2]
    elements.btnRecordToggle = UIManager:createModernButton({Text = "Start Recording", LayoutOrder = 1})
    elements.btnRecordToggle.Parent = recordContent
    
    elements.recordingIndicator = Instance.new("Frame", recordContent)
    elements.recordingIndicator.Size = UDim2.new(0.9, 0, 0, 30)
    elements.recordingIndicator.BackgroundTransparency = 1
    elements.recordingIndicator.LayoutOrder = 2
    
    elements.indicatorDot = Instance.new("Frame", elements.recordingIndicator)
    elements.indicatorDot.Size = UDim2.new(0, 12, 0, 12)
    elements.indicatorDot.Position = UDim2.new(0, 10, 0.5, -6)
    elements.indicatorDot.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    elements.indicatorDot.Visible = false
    Instance.new("UICorner", elements.indicatorDot).CornerRadius = UDim.new(1, 0)
    
    elements.indicatorText = Instance.new("TextLabel", elements.recordingIndicator)
    elements.indicatorText.Size = UDim2.new(1, 0, 1, 0)
    elements.indicatorText.BackgroundTransparency = 1
    elements.indicatorText.Position = UDim2.new(0, 30, 0, 0)
    elements.indicatorText.Text = "Not Recording"
    elements.indicatorText.Font = Enum.Font.Gotham
    elements.indicatorText.TextSize = 13
    elements.indicatorText.TextXAlignment = Enum.TextXAlignment.Left
    elements.indicatorText.TextColor3 = Color3.fromRGB(240, 240, 240)
    
    elements.btnReplayOnce = UIManager:createModernButton({Text = "Replay Once", LayoutOrder = 3})
    elements.btnReplayOnce.Parent = recordContent
    
    elements.replayCountInput = UIManager:createModernInput({Placeholder = "Replay Count", Text = "1", LayoutOrder = 4})
    elements.replayCountInput.Parent = recordContent
    
    elements.btnReplayLoop = UIManager:createModernButton({Text = "Loop Replay: OFF", LayoutOrder = 5})
    elements.btnReplayLoop.Parent = recordContent
    
    elements.btnClearActions = UIManager:createModernButton({Text = "Clear All Actions", Color = Color3.fromRGB(255, 59, 48), LayoutOrder = 6})
    elements.btnClearActions.Parent = recordContent
    
    elements.actionListViewer = Instance.new("ScrollingFrame", recordContent)
    elements.actionListViewer.Size = UDim2.new(0.9, 0, 0, 100)
    elements.actionListViewer.BackgroundTransparency = 0.9
    elements.actionListViewer.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    elements.actionListViewer.BorderSizePixel = 0
    elements.actionListViewer.ScrollBarThickness = 4
    elements.actionListViewer.LayoutOrder = 7
    Instance.new("UIListLayout", elements.actionListViewer).Padding = UDim.new(0, 5)
    Instance.new("UICorner", elements.actionListViewer).CornerRadius = UDim.new(0, 6)
    
    -- Settings tab
    local settingsContent = contents[3]
    elements.offsetXInput = UIManager:createModernInput({Placeholder = "X Offset (px)", Text = "0", LayoutOrder = 1})
    elements.offsetXInput.Parent = settingsContent
    
    elements.offsetYInput = UIManager:createModernInput({Placeholder = "Y Offset (px)", Text = "0", LayoutOrder = 2})
    elements.offsetYInput.Parent = settingsContent
    
    elements.btnCalibrate = UIManager:createModernButton({Text = "Auto-Calibrate [Visual]", Color = Color3.fromRGB(0, 255, 0), LayoutOrder = 3})
    elements.btnCalibrate.Parent = settingsContent
    
    elements.btnApplyOffsets = UIManager:createModernButton({Text = "Apply Offsets", LayoutOrder = 4})
    elements.btnApplyOffsets.Parent = settingsContent
    
    local humanizeLabel = Instance.new("TextLabel", settingsContent)
    humanizeLabel.Size = UDim2.new(0.9, 0, 0, 30)
    humanizeLabel.BackgroundTransparency = 1
    humanizeLabel.Text = "Humanization: DISABLED"
    humanizeLabel.Font = Enum.Font.GothamBold
    humanizeLabel.TextSize = 12
    humanizeLabel.TextColor3 = Color3.fromRGB(255, 59, 48)
    humanizeLabel.LayoutOrder = 5
    
    -- Profiles tab
    local profileContent = contents[4]
    elements.profileList = Instance.new("ScrollingFrame", profileContent)
    elements.profileList.Size = UDim2.new(0.9, 0, 0, 150)
    elements.profileList.BackgroundTransparency = 0.9
    elements.profileList.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    elements.profileList.ScrollBarThickness = 4
    elements.profileList.LayoutOrder = 1
    Instance.new("UIListLayout", elements.profileList).Padding = UDim.new(0, 5)
    Instance.new("UICorner", elements.profileList).CornerRadius = UDim.new(0, 6)
    
    elements.profileNameInput = UIManager:createModernInput({Placeholder = "Profile Name", LayoutOrder = 2})
    elements.profileNameInput.Parent = profileContent
    
    elements.btnSaveProfile = UIManager:createModernButton({Text = "Save Profile", LayoutOrder = 3})
    elements.btnSaveProfile.Parent = profileContent
    
    elements.btnLoadProfile = UIManager:createModernButton({Text = "Load Selected", LayoutOrder = 4})
    elements.btnLoadProfile.Parent = profileContent
    
    -- Toggle Button
    elements.toggleBtn = UIManager:createModernButton({
        Size = UDim2.new(0, 70, 0, 30),
        Position = UDim2.new(0, 10, 0, 10),
        Text = "Hide",
        Color = Color3.fromRGB(0, 255, 0)
    })
    elements.toggleBtn.Parent = MainGUI
    
    -- Status Bar
    elements.statusBar = Instance.new("Frame", mainFrame)
    elements.statusBar.Size = UDim2.new(1, 0, 0, 30)
    elements.statusBar.Position = UDim2.new(0, 0, 1, -30)
    elements.statusBar.BackgroundTransparency = 0.9
    elements.statusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    elements.statusBar.BorderSizePixel = 0
    
    Instance.new("UICorner", elements.statusBar).CornerRadius = UDim.new(0, 0)
    
    elements.statusText = Instance.new("TextLabel", elements.statusBar)
    elements.statusText.Size = UDim2.new(1, -10, 1, 0)
    elements.statusText.Position = UDim2.new(0, 5, 0, 0)
    elements.statusText.BackgroundTransparency = 1
    elements.statusText.Text = "Delta Macro Ready | Actions: 0"
    elements.statusText.Font = Enum.Font.Gotham
    elements.statusText.TextSize = 11
    elements.statusText.TextXAlignment = Enum.TextXAlignment.Left
    elements.statusText.TextColor3 = Color3.fromRGB(174, 174, 178)
    
    -- Crosshair
    elements.crosshair = Instance.new("Frame", MainGUI)
    elements.crosshair.Name = "Crosshair"
    elements.crosshair.Size = UDim2.new(0, 40, 0, 40)
    elements.crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
    elements.crosshair.BackgroundTransparency = 1
    elements.crosshair.Visible = false
    
    local crosshairH = Instance.new("Frame", elements.crosshair)
    crosshairH.Name = "H"
    crosshairH.Size = UDim2.new(1, 0, 0, 2)
    crosshairH.Position = UDim2.new(0, 0, 0.5, -1)
    crosshairH.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    crosshairH.BorderSizePixel = 0
    
    local crosshairV = Instance.new("Frame", elements.crosshair)
    crosshairV.Name = "V"
    crosshairV.Size = UDim2.new(0, 2, 1, 0)
    crosshairV.Position = UDim2.new(0.5, -1, 0, 0)
    crosshairV.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    crosshairV.BorderSizePixel = 0
    
    MainGUI.Elements = elements
    MainGUI.TabButtons = tabs
    MainGUI.Contents = contents
    
    return MainGUI
end

----------------------------------------------------------------
-- VISUAL PICKER (OPTIMIZED)
----------------------------------------------------------------
local VisualPicker = {
    isActive = false,
    connection = nil,
    
    start = function(self)
        if self.isActive then return end
        self.isActive = true
        
        MainGUI.Elements.crosshair.Visible = true
        
        -- Single RenderStepped connection (optimized)
        self.connection = Services.RunService.RenderStepped:Connect(function()
            local mousePos = Services.UserInputService:GetMouseLocation()
            MainGUI.Elements.crosshair.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
        end)
        
        -- Smooth pulsing animation
        if Services.TweenService then
            local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
            Services.TweenService:Create(MainGUI.Elements.crosshair.H, tweenInfo, {BackgroundTransparency = 0.5}):Play()
            Services.TweenService:Create(MainGUI.Elements.crosshair.V, tweenInfo, {BackgroundTransparency = 0.5}):Play()
        end
        
        Logger:info("Visual picker activated")
    end,
    
    stop = function(self)
        if not self.isActive then return end
        self.isActive = false
        
        if self.connection then
            self.connection:Disconnect()
            self.connection = nil
        end
        
        MainGUI.Elements.crosshair.Visible = false
        
        -- Reset transparency
        MainGUI.Elements.crosshair.H.BackgroundTransparency = 0
        MainGUI.Elements.crosshair.V.BackgroundTransparency = 0
        
        Logger:info("Visual picker deactivated")
    end,
}

----------------------------------------------------------------
-- UI UPDATE HELPERS
----------------------------------------------------------------
local function updateActionList()
    local viewer = MainGUI.Elements.actionListViewer
    local actions = StateManager:get("recordedActions")
    
    -- Clear existing (optimized)
    for i = #viewer:GetChildren(), 1, -1 do
        local child = viewer:GetChildren()[i]
        if child:IsA("Frame") then child:Destroy() end
    end
    
    -- Add actions
    for i, action in ipairs(actions) do
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -10, 0, 30)
        item.BackgroundTransparency = 0.95
        item.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        item.BorderSizePixel = 0
        item.Parent = viewer
        
        local label = Instance.new("TextLabel", item)
        label.Size = UDim2.new(1, -30, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = string.format("%d. %s", i, action.type)
        label.Font = Enum.Font.Gotham
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = Color3.fromRGB(240, 240, 240)
        
        local deleteBtn = UIManager:createModernButton({
            Size = UDim2.new(0, 25, 0, 25),
            Position = UDim2.new(1, -30, 0.5, -12),
            Text = "X",
            TextSize = 11,
            Color = Color3.fromRGB(255, 59, 48),
            Hoverable = false
        })
        deleteBtn.Parent = item
        deleteBtn.MouseButton1Click:Connect(function()
            RecordingEngine:deleteAction(i)
            updateActionList()
        end)
    end
    
    MainGUI.Elements.indicatorText.Text = string.format("Recording: %d actions", #actions)
end

local function updateProfileList()
    local list = MainGUI.Elements.profileList
    local profiles = ProfileManager:listProfiles()
    
    -- Clear existing
    for i = #list:GetChildren(), 1, -1 do
        local child = list:GetChildren()[i]
        if child:IsA("Frame") then child:Destroy() end
    end
    
    -- Add profiles
    for _, profile in ipairs(profiles) do
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -10, 0, 35)
        item.BackgroundTransparency = 0.95
        item.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        item.BorderSizePixel = 0
        item.Parent = list
        
        local label = Instance.new("TextLabel", item)
        label.Size = UDim2.new(1, -35, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = profile
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = Color3.fromRGB(240, 240, 240)
        
        local deleteBtn = UIManager:createModernButton({
            Size = UDim2.new(0, 30, 0, 30),
            Position = UDim2.new(1, -35, 0.5, -15),
            Text = "🗑",
            TextSize = 13,
            Color = Color3.fromRGB(255, 59, 48),
            Hoverable = false
        })
        deleteBtn.Parent = item
        deleteBtn.MouseButton1Click:Connect(function()
            ProfileManager:deleteProfile(profile)
            updateProfileList()
        end)
        
        item.MouseButton1Click:Connect(function()
            StateManager:set("currentProfile", profile)
            for _, other in ipairs(list:GetChildren()) do
                if other:IsA("Frame") then
                    other.BackgroundTransparency = 0.95
                end
            end
            item.BackgroundTransparency = 0.8
        end)
    end
end

----------------------------------------------------------------
-- BUTTON CONNECTIONS (OPTIMIZED)
----------------------------------------------------------------
local function connectButtons()
    local elements = MainGUI.Elements
    
    -- AutoClick
    elements.btnAutoToggle.MouseButton1Click:Connect(function()
        local interval = tonumber(elements.intervalInput.Text) or 0.2
        StateManager:set("clickInterval", interval)
        
        if StateManager:get("autoClickEnabled") then
            StateManager:set("autoClickEnabled", false)
        else
            if StateManager:get("clickPosition") == Vector2.new(500, 500) then
                elements.statusText.Text = "Error: Set click position first"
                return
            end
            
            StateManager:set("autoClickEnabled", true)
            
            task.spawn(function()
                local count = 0
                while StateManager:get("autoClickEnabled") do
                    InputSimulator:performClick(StateManager:get("clickPosition"))
                    count = count + 1
                    if count % 10 == 0 then
                        elements.btnAutoToggle.Text = string.format("Clicks: %d", count)
                    end
                    task.wait(StateManager:get("clickInterval"))
                end
            end)
        end
    end)
    
    -- Visual position picker
    elements.btnSetPos.MouseButton1Click:Connect(function()
        if VisualPicker.isActive then
            VisualPicker:stop()
            elements.btnSetPos.Text = "Set Position [Visual]"
        else
            VisualPicker:start()
            elements.btnSetPos.Text = "Click to Set..."
            
            local conn
            conn = Services.UserInputService.InputBegan:Connect(function(input, gp)
                if gp or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                
                if VisualPicker.isActive then
                    local pos = Services.UserInputService:GetMouseLocation()
                    StateManager:set("clickPosition", pos)
                    
                    VisualPicker:stop()
                    elements.btnSetPos.Text = "Position Set!"
                    elements.currentPosLabel.Text = string.format("Current: (%d, %d)", pos.X, pos.Y)
                    
                    VisualFeedback:showClickMarker(pos, Color3.fromRGB(0, 255, 0), 20, 1)
                    
                    task.delay(2, function()
                        elements.btnSetPos.Text = "Set Position [Visual]"
                    end)
                    
                    conn:Disconnect()
                end
            end)
        end
    end)
    
    -- Test click
    elements.btnTestClick.MouseButton1Click:Connect(function()
        if StateManager:get("clickPosition") == Vector2.new(500, 500) then
            elements.statusText.Text = "Error: Set position first"
            return
        end
        
        local pos = StateManager:get("clickPosition")
        VisualFeedback:showClickMarker(pos, Color3.fromRGB(0, 255, 0), 15, 1)
        InputSimulator:performClick(pos)
    end)
    
    -- Recorder
    elements.btnRecordToggle.MouseButton1Click:Connect(function()
        if StateManager:get("isRecording") then
            RecordingEngine:stopRecording()
        else
            RecordingEngine:startRecording()
        end
    end)
    
    elements.btnReplayOnce.MouseButton1Click:Connect(function()
        if #StateManager:get("recordedActions") == 0 then
            elements.statusText.Text = "Error: No actions recorded"
            return
        end
        
        local count = tonumber(elements.replayCountInput.Text) or 1
        StateManager:set("replayCount", count)
        
        if StateManager:get("isReplaying") then
            StateManager:set("isReplaying", false)
        else
            StateManager:set("isReplaying", true)
            RecordingEngine:replayActions(StateManager:get("recordedActions"), false)
        end
    end)
    
    elements.btnReplayLoop.MouseButton1Click:Connect(function()
        if #StateManager:get("recordedActions") == 0 then
            elements.statusText.Text = "Error: No actions recorded"
            return
        end
        
        if StateManager:get("isReplayingLoop") then
            StateManager:set("isReplayingLoop", false)
        else
            StateManager:set("isReplayingLoop", true)
            RecordingEngine:replayActions(StateManager:get("recordedActions"), true)
        end
    end)
    
    elements.btnClearActions.MouseButton1Click:Connect(function()
        RecordingEngine:clearRecording()
        updateActionList()
        elements.statusText.Text = "Actions cleared"
    end)
    
    -- Settings
    elements.btnCalibrate.MouseButton1Click:Connect(function()
        elements.statusText.Text = "Calibration: Click center of screen"
        
        local viewportSize = Cache.viewportSize
        local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
        
        -- FIXED: Use proper center calculation including GuiInset
        Cache:update()
        local centerWithInset = Vector2.new(
            viewportSize.X / 2 + Cache.guiInset.X,
            viewportSize.Y / 2 + Cache.guiInset.Y
        )
        
        local target = Instance.new("Frame", MainGUI)
        target.Name = "CalibrationTarget"
        target.Size = UDim2.new(0, 30, 0, 30)
        target.Position = UDim2.new(0, center.X - 15, 0, center.Y - 15)
        target.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        target.BackgroundTransparency = 0.3
        Instance.new("UICorner", target).CornerRadius = UDim.new(1, 0)
        
        -- Pulse animation
        if Services.TweenService then
            local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
            Services.TweenService:Create(target, tweenInfo, {BackgroundTransparency = 0.6}):Play()
        end
        
        local conn
        local timeout = task.delay(CONFIG.CALIBRATION_TIMEOUT, function()
            if target.Parent then
                target:Destroy()
                elements.statusText.Text = "Calibration timed out"
            end
        end)
        
        conn = Services.UserInputService.InputBegan:Connect(function(input, gp)
            if gp or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            
            local clickPos = Services.UserInputService:GetMouseLocation()
            -- Calculate difference from center (not centerWithInset - user sees center)
            local diff = clickPos - center
            
            StateManager:set("activeXOffset", -math.floor(diff.X))
            StateManager:set("activeYOffset", -math.floor(diff.Y))
            
            elements.offsetXInput.Text = tostring(-math.floor(diff.X))
            elements.offsetYInput.Text = tostring(-math.floor(diff.Y))
            
            pcall(function()
                target:Destroy()
                conn:Disconnect()
                task.cancel(timeout)
            end)
            
            elements.statusText.Text = string.format("Calibrated: X=%d, Y=%d", -math.floor(diff.X), -math.floor(diff.Y))
            Logger:info("Calibration complete", {offsetX = -math.floor(diff.X), offsetY = -math.floor(diff.Y)})
        end)
    end)
    
    elements.btnApplyOffsets.MouseButton1Click:Connect(function()
        local x = tonumber(elements.offsetXInput.Text) or 0
        local y = tonumber(elements.offsetYInput.Text) or 0
        
        StateManager:set("activeXOffset", x)
        StateManager:set("activeYOffset", y)
        
        elements.statusText.Text = string.format("Offsets: X=%d, Y=%d", x, y)
        Logger:info("Offsets applied", {x = x, y = y})
    end)
    
    -- Profiles
    elements.btnSaveProfile.MouseButton1Click:Connect(function()
        local name = elements.profileNameInput.Text
        if not name or name == "" then name = "default" end
        
        ProfileManager:saveProfile(name)
        updateProfileList()
        elements.profileNameInput.Text = ""
        elements.statusText.Text = "Saved: " .. name
    end)
    
    elements.btnLoadProfile.MouseButton1Click:Connect(function()
        local selected = StateManager:get("currentProfile")
        if selected and selected ~= "" then
            ProfileManager:loadProfile(selected)
            updateActionList()
            elements.statusText.Text = "Loaded: " .. selected
        end
    end)
    
    -- Tabs
    for i, tab in ipairs(tabs) do
        tab.MouseButton1Click:Connect(function()
            for _, t in ipairs(tabs) do
                t.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
            end
            tab.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            
            for _, content in ipairs(contents) do
                content.Visible = false
            end
            contents[i].Visible = true
        end)
    end
    tabs[1].BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- Default active
    
    -- Toggle GUI
    elements.toggleBtn.MouseButton1Click:Connect(function()
        local hidden = not StateManager:get("guiHidden")
        StateManager:set("guiHidden", hidden)
        
        mainFrame.Visible = not hidden
        elements.toggleBtn.Text = hidden and "Show" or "Hide"
    end)
    
    -- State subscriptions
    StateManager:subscribe("autoClickEnabled", function(value)
        elements.btnAutoToggle.Text = value and "Auto Clicker: ON" or "Auto Clicker: OFF"
    end)
    
    StateManager:subscribe("isRecording", function(value)
        elements.btnRecordToggle.Text = value and "Stop Recording" or "Start Recording"
        elements.indicatorDot.Visible = value
        elements.indicatorText.Text = value and "Recording..." or "Not Recording"
    end)
    
    StateManager:subscribe("isReplaying", function(value)
        elements.btnReplayOnce.Text = value and "Stop Replay" or "Replay Once"
    end)
    
    StateManager:subscribe("isReplayingLoop", function(value)
        elements.btnReplayLoop.Text = value and "Loop Replay: ON" or "Loop Replay: OFF"
    end)
    
    StateManager:subscribe("clickPosition", function(pos)
        elements.currentPosLabel.Text = string.format("Current: (%d, %d)", pos.X, pos.Y)
    end)
    
    StateManager:subscribe("recordedActions", function(actions)
        updateActionList()
        elements.statusText.Text = string.format("Delta Macro | Actions: %d", #actions)
    end)
end

----------------------------------------------------------------
-- MAIN INITIALIZATION (FIXED)
----------------------------------------------------------------
local function initialize()
    Logger:info("Initializing Delta Macro V5.1...")
    
    Compatibility:DetectEnvironment()
    
    MainGUI = createGUI()
    if not MainGUI then
        Logger:error("Failed to create GUI")
        return
    end
    
    connectButtons()
    
    -- Load default profile
    ProfileManager:loadProfile("default")
    updateActionList()
    updateProfileList()
    
    -- Start cache updater
    task.spawn(function()
        while task.wait(CONFIG.CACHE_REFRESH_RATE) do
            Cache:update()
        end
    end)
    
    -- Handle focus loss (critical for Delta)
    Services.UserInputService.WindowFocusReleased:Connect(function()
        Logger:warn("Window focus lost - stopping all macros")
        StateManager:set("autoClickEnabled", false)
        StateManager:set("isRecording", false)
        StateManager:set("isReplaying", false)
        StateManager:set("isReplayingLoop", false)
    end)
    
    Logger:info("Delta Macro V5.1 initialized successfully")
    Logger:info("Executor: " .. Compatibility.detectedExecutor)
    Logger:info("VIM Available: " .. tostring(Compatibility.vmAvailable))
    Logger:info("Click 'Auto-Calibrate [Visual]' in Settings to fix alignment")
end

-- Start with error handling
local success, err = pcall(initialize)
if not success then
    Logger:error("Initialization failed: " .. tostring(err))
    error(err)
end
