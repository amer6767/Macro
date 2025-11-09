-- Delta Executor Macro V5.0 | Exact-Pixel Edition
-- Optimized for Delta Executor - No humanization, no key system
-- LocalScript in StarterPlayerScripts or StarterGui

----------------------------------------------------------------
-- CONFIGURATION CONSTANTS
----------------------------------------------------------------
local CONFIG = {
    -- Delta-Specific Settings
    GUI_PARENT = "PlayerGui", -- Delta works better with PlayerGui
    USE_RANDOM_JITTER = false, -- Force disabled
    RANDOM_DELAY_FACTOR = 0, -- No randomization
    SHOW_DEBUG_MARKERS = true, -- Visual feedback for testing
    
    -- Performance
    CACHE_REFRESH_RATE = 2,
    USE_HEARTBEAT_WAIT = true,
    
    -- Exact clicking
    MIN_CLICK_HOLD = 0.05,
    DEFAULT_SWIPE_CURVE = 0.0,
    
    -- Coordinate System
    FALLBACK_INSET = Vector2.new(0, 36),
    
    -- Disabled Features
    HUMANIZATION_ENABLED = false, -- Completely disabled
}

----------------------------------------------------------------
-- LOGGER MODULE
----------------------------------------------------------------
local Logger = {
    enabled = true,
    prefix = "[DeltaMacro]",
    log = function(self, level, message, data)
        if not self.enabled then return end
        local timestamp = os.date("%H:%M:%S")
        local output = string.format("%s %s [%s] %s", 
            self.prefix, timestamp, level, message)
        if data then
            output = output .. " | " .. HttpService:JSONEncode(data)
        end
        print(output)
    end,
    info = function(self, message, data) self:log("INFO", message, data) end,
    warn = function(self, message, data) self:log("WARN", message, data) end,
    error = function(self, message, data) self:log("ERROR", message, data) end,
}

----------------------------------------------------------------
-- EXECUTOR COMPATIBILITY LAYER (DELTA PRIORITY)
----------------------------------------------------------------
local Compatibility = {
    detectedExecutor = "unknown",
    VirtualInputManager = nil,
    vmAvailable = false,
    httpGet = nil,
    setClipboard = nil,
}

function Compatibility:DetectEnvironment()
    -- Delta-specific detection first
    local env = getfenv and getfenv() or {}
    local renv = getrenv and getrenv() or {}
    
    if http_request and not syn then
        self.detectedExecutor = "Delta"
        self.httpGet = function(url) return http_request({Url = url, Method = "GET"}).Body end
        Logger:info("Delta Executor detected")
    elseif syn and syn.request then
        self.detectedExecutor = "Synapse"
        self.httpGet = function(url) return syn.request({Url = url, Method = "GET"}).Body end
        Logger:info("Synapse detected")
    elseif request and not syn then
        self.detectedExecutor = "KRNL/Other"
        self.httpGet = function(url) return request({Url = url, Method = "GET"}).Body end
        Logger:info("KRNL/Other executor detected")
    elseif game and game.HttpGet then
        self.detectedExecutor = "Standard"
        self.httpGet = function(url) return game:HttpGet(url, true) end
        Logger:warn("Standard Roblox HTTP detected - may not work with Delta")
    else
        Logger:error("No compatible HTTP method found")
    end
    
    -- Force Delta http_request if available
    if http_request then
        self.httpGet = function(url) return http_request({Url = url, Method = "GET"}).Body end
        self.detectedExecutor = "Delta"
        Logger:info("Forced Delta http_request")
    end
    
    -- Clipboard
    self.setClipboard = function(text)
        local clippers = {setclipboard, writeclipboard, syn and syn.write_clipboard, toclipboard}
        for _, clip in ipairs(clippers) do
            if clip then
                pcall(function() clip(text) end)
                return true
            end
        end
        return false
    end
    
    self:InitializeVIM()
end

function Compatibility:InitializeVIM()
    -- Delta-specific VIM detection
    local vimDetectors = {
        function() return getService("VirtualInputManager") end,
        function() return (getrenv and getrenv() or {}).VirtualInputManager end,
        function() return (getfenv and getfenv() or {}).VirtualInputManager end,
    }
    
    for _, detector in ipairs(vimDetectors) do
        local success, vim = pcall(detector)
        if success and vim then
            self.VirtualInputManager = vim
            self.vmAvailable = true
            Logger:info("VirtualInputManager initialized for " .. self.detectedExecutor)
            break
        end
    end
    
    -- Test VIM
    task.delay(1, function()
        if self.vmAvailable then
            local testSuccess = pcall(function() self.VirtualInputManager:SendMouseMoveEvent(100, 100) end)
            if testSuccess then
                Logger:info("VIM test successful")
            else
                self.vmAvailable = false
                Logger:error("VIM test failed")
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
        waitingForPosition = false,
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
        profiles = {},
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
-- CACHE & PERFORMANCE
----------------------------------------------------------------
local Cache = {
    viewportSize = Vector2.new(1920, 1080),
    guiInset = Vector2.new(0, 36),
    lastUpdate = 0,
    
    update = function(self)
        local now = os.clock()
        if now - self.lastUpdate < CONFIG.CACHE_REFRESH_RATE then return end
        self.lastUpdate = now
        
        local success, inset = pcall(function() return GuiService:GetGuiInset() end)
        self.guiInset = success and inset or CONFIG.FALLBACK_INSET
        self.viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or self.viewportSize
        
        StateManager:set("lastViewportSize", self.viewportSize)
        StateManager:set("lastGuiInset", self.guiInset)
    end,
}

----------------------------------------------------------------
-- DISABLED HUMANIZER (PASSTHROUGH)
----------------------------------------------------------------
local Humanizer = {
    applyJitter = function(self, pos) return pos end, -- NO JITTER
    applyDelay = function(self, baseDelay) return baseDelay end, -- NO DELAY
    getRandomCurve = function(self) return 0 end, -- NO CURVE
}

----------------------------------------------------------------
-- COORDINATE SYSTEM
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
        
        -- EXACT movement and click - no randomization
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
-- VISUAL FEEDBACK
----------------------------------------------------------------
local VisualFeedback = {
    markers = {},
    
    showClickMarker = function(self, viewportPos, color, size, duration)
        if not CONFIG.SHOW_DEBUG_MARKERS then return end
        
        local marker = Instance.new("Frame")
        marker.Size = UDim2.new(0, size or 15, 0, size or 15)
        marker.Position = UDim2.new(0, viewportPos.X - (size or 15)/2, 0, viewportPos.Y - (size or 15)/2)
        marker.BackgroundColor3 = color or Color3.fromRGB(255, 0, 0)
        marker.BackgroundTransparency = 0.3
        marker.BorderSizePixel = 0
        marker.ZIndex = 1000
        
        local corner = Instance.new("UICorner", marker)
        corner.CornerRadius = UDim.new(1, 0)
        
        marker.Parent = MainGUI
        
        table.insert(self.markers, marker)
        
        task.spawn(function()
            for i = 1, 3 do
                marker.BackgroundTransparency = 0.3
                task.wait(0.1)
                marker.BackgroundTransparency = 0
                task.wait(0.1)
            end
            task.wait(duration or 1)
            marker:Destroy()
            for i, m in ipairs(self.markers) do
                if m == marker then table.remove(self.markers, i) break end
            end
        end)
    end,
}

----------------------------------------------------------------
-- RECORDING ENGINE
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
        
        self.connections.began = UserInputService.InputBegan:Connect(function(input, gp)
            if gp or not StateManager:get("isRecording") then return end
            
            local pos = input.Position or UserInputService:GetMouseLocation()
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
        
        self.connections.changed = UserInputService.InputChanged:Connect(function(input)
            if not StateManager:get("isRecording") or not self.activeInputs[input] then return end
            
            local pos = input.Position or UserInputService:GetMouseLocation()
            local data = self.activeInputs[input]
            
            if not data.isDragging and (pos - data.startPos).Magnitude >= 10 then
                data.isDragging = true
            end
            
            data.lastPos = pos
        end)
        
        self.connections.ended = UserInputService.InputEnded:Connect(function(input, gp)
            if not StateManager:get("isRecording") or not self.activeInputs[input] then return end
            
            local now = os.clock()
            local data = self.activeInputs[input]
            local delay = now - StateManager:get("recordStartTime")
            StateManager:set("recordStartTime", now)
            
            local endPos = input.Position or UserInputService:GetMouseLocation()
            
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
            local guiObjects = UserInputService:GetGuiObjectsAtPosition(
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
        
        local json = HttpService:JSONEncode(data)
        writefile("DeltaMacro_Profiles/" .. name .. ".json", json)
        Logger:info("Profile saved: " .. name)
        return true
    end,
    
    loadProfile = function(self, name)
        if not readfile then Logger:warn("readfile not available"); return false end
        
        local success, data = pcall(function()
            local json = readfile("DeltaMacro_Profiles/" .. name .. ".json")
            return HttpService:JSONDecode(json)
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
        pcall(function() delfile("DeltaMacro_Profiles/" .. name .. ".json") end)
        Logger:info("Profile deleted: " .. name)
    end,
    
    listProfiles = function(self)
        if not listfiles then return {} end
        
        local files = listfiles("DeltaMacro_Profiles/")
        local profiles = {}
        for _, file in ipairs(files) do
            local name = file:match("([^/]+)%.json$")
            if name then table.insert(profiles, name) end
        end
        return profiles
    end,
}

----------------------------------------------------------------
-- EVENT SYSTEM
----------------------------------------------------------------
local Events = {
    listeners = {},
    
    Connect = function(self, event, callback)
        if not self.listeners[event] then self.listeners[event] = {} end
        table.insert(self.listeners[event], callback)
        return {Disconnect = function()
            for i, cb in ipairs(self.listeners[event]) do
                if cb == callback then table.remove(self.listeners[event], i) break end
            end
        end}
    end,
    
    Fire = function(self, event, ...)
        if not self.listeners[event] then return end
        for _, callback in ipairs(self.listeners[event]) do
            pcall(callback, ...)
        end
    end,
}

----------------------------------------------------------------
-- MODERN GUI CREATION
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
        
        local corner = Instance.new("UICorner", button)
        corner.CornerRadius = UDim.new(0, props.CornerRadius or 8)
        
        if props.Hoverable ~= false then
            button.MouseEnter:Connect(function()
                TweenService:Create(button, TweenInfo.new(0.2), {
                    BackgroundColor3 = button.BackgroundColor3:Lerp(Color3.new(1,1,1), 0.1)
                }):Play()
            end)
            button.MouseLeave:Connect(function()
                TweenService:Create(button, TweenInfo.new(0.2), {
                    BackgroundColor3 = props.Color or Color3.fromRGB(60, 60, 65)
                }):Play()
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
-- MAIN GUI
----------------------------------------------------------------
local MainGUI = nil

local function createGUI()
    local guiParent = CONFIG.GUI_PARENT == "PlayerGui" and LocalPlayer:FindFirstChild("PlayerGui") or CoreGui
    MainGUI = Instance.new("ScreenGui")
    MainGUI.Name = "DeltaMacro_Gui"
    MainGUI.ResetOnSpawn = false
    MainGUI.IgnoreGuiInset = true
    MainGUI.ZIndexBehavior = Enum.ZIndexBehavior.Global
    MainGUI.Parent = guiParent
    
    -- NO KEY ENTRY - Main Interface Directly
    local mainFrame = UIManager:createModernFrame({
        Size = UDim2.new(0, 380, 0, 520),
        Position = UDim2.new(0.5, -190, 0.5, -260),
        Color = Color3.fromRGB(28, 28, 30),
        AddShadow = true,
        UseGradient = true,
        CornerRadius = 16
    })
    mainFrame.Name = "MainFrame"
    mainFrame.Visible = true -- Visible immediately
    MainGUI.MainFrame = mainFrame
    
    -- Title Bar
    local titleBar = Instance.new("Frame", mainFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundTransparency = 1
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "Delta Macro V5.0"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.TextColor3 = Color3.fromRGB(0, 255, 0) -- Delta green
    
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
        
        local layout = Instance.new("UIListLayout", content)
        layout.Padding = UDim.new(0, 10)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        
        table.insert(contents, content)
    end
    
    -- AutoClick Content
    local autoContent = contents[1]
    local btnAutoToggle = UIManager:createModernButton({
        Text = "Auto Clicker: OFF",
        Position = UDim2.new(0.05, 0, 0, 10)
    })
    btnAutoToggle.LayoutOrder = 1
    btnAutoToggle.Parent = autoContent
    
    local intervalInput = UIManager:createModernInput({
        Placeholder = "Click Interval (seconds)",
        Text = "0.2",
        Position = UDim2.new(0.05, 0, 0, 55)
    })
    intervalInput.LayoutOrder = 2
    intervalInput.Parent = autoContent
    
    local btnSetPos = UIManager:createModernButton({
        Text = "Set Position [Visual]",
        Position = UDim2.new(0.05, 0, 0, 100)
    })
    btnSetPos.LayoutOrder = 3
    btnSetPos.Parent = autoContent
    
    local currentPosLabel = Instance.new("TextLabel", autoContent)
    currentPosLabel.Size = UDim2.new(0.9, 0, 0, 20)
    currentPosLabel.Position = UDim2.new(0.05, 0, 0, 145)
    currentPosLabel.BackgroundTransparency = 1
    currentPosLabel.Text = "Current: (500, 500)"
    currentPosLabel.Font = Enum.Font.Gotham
    currentPosLabel.TextSize = 12
    currentPosLabel.TextColor3 = Color3.fromRGB(174, 174, 178)
    currentPosLabel.LayoutOrder = 4
    
    local btnTestClick = UIManager:createModernButton({
        Text = "Test Click [Preview]",
        Position = UDim2.new(0.05, 0, 0, 175)
    })
    btnTestClick.LayoutOrder = 5
    btnTestClick.Parent = autoContent
    
    -- Recorder Content
    local recordContent = contents[2]
    local btnRecordToggle = UIManager:createModernButton({
        Text = "Start Recording",
        Position = UDim2.new(0.05, 0, 0, 10)
    })
    btnRecordToggle.LayoutOrder = 1
    btnRecordToggle.Parent = recordContent
    
    local recordingIndicator = Instance.new("Frame", recordContent)
    recordingIndicator.Size = UDim2.new(0.9, 0, 0, 30)
    recordingIndicator.Position = UDim2.new(0.05, 0, 0, 55)
    recordingIndicator.BackgroundTransparency = 1
    recordingIndicator.LayoutOrder = 2
    
    local indicatorDot = Instance.new("Frame", recordingIndicator)
    indicatorDot.Size = UDim2.new(0, 12, 0, 12)
    indicatorDot.Position = UDim2.new(0, 10, 0.5, -6)
    indicatorDot.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    indicatorDot.Visible = false
    
    local corner = Instance.new("UICorner", indicatorDot)
    corner.CornerRadius = UDim.new(1, 0)
    
    local indicatorText = Instance.new("TextLabel", recordingIndicator)
    indicatorText.Size = UDim2.new(1, 0, 1, 0)
    indicatorText.BackgroundTransparency = 1
    indicatorText.Position = UDim2.new(0, 30, 0, 0)
    indicatorText.Text = "Not Recording"
    indicatorText.Font = Enum.Font.Gotham
    indicatorText.TextSize = 13
    indicatorText.TextXAlignment = Enum.TextXAlignment.Left
    indicatorText.TextColor3 = Color3.fromRGB(240, 240, 240)
    
    local btnReplayOnce = UIManager:createModernButton({
        Text = "Replay Once",
        Position = UDim2.new(0.05, 0, 0, 100)
    })
    btnReplayOnce.LayoutOrder = 3
    btnReplayOnce.Parent = recordContent
    
    local replayCountInput = UIManager:createModernInput({
        Placeholder = "Replay Count",
        Text = "1",
        Position = UDim2.new(0.05, 0, 0, 145)
    })
    replayCountInput.LayoutOrder = 4
    replayCountInput.Parent = recordContent
    
    local btnReplayLoop = UIManager:createModernButton({
        Text = "Loop Replay: OFF",
        Position = UDim2.new(0.05, 0, 0, 190)
    })
    btnReplayLoop.LayoutOrder = 5
    btnReplayLoop.Parent = recordContent
    
    local btnClearActions = UIManager:createModernButton({
        Text = "Clear All Actions",
        Color = Color3.fromRGB(255, 59, 48),
        Position = UDim2.new(0.05, 0, 0, 235)
    })
    btnClearActions.LayoutOrder = 6
    btnClearActions.Parent = recordContent
    
    local actionListViewer = Instance.new("ScrollingFrame", recordContent)
    actionListViewer.Size = UDim2.new(0.9, 0, 0, 100)
    actionListViewer.Position = UDim2.new(0.05, 0, 0, 280)
    actionListViewer.BackgroundTransparency = 0.9
    actionListViewer.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    actionListViewer.BorderSizePixel = 0
    actionListViewer.ScrollBarThickness = 4
    actionListViewer.LayoutOrder = 7
    
    local corner = Instance.new("UICorner", actionListViewer)
    corner.CornerRadius = UDim.new(0, 6)
    
    local listLayout = Instance.new("UIListLayout", actionListViewer)
    listLayout.Padding = UDim.new(0, 5)
    
    -- Settings Content
    local settingsContent = contents[3]
    local offsetXInput = UIManager:createModernInput({
        Placeholder = "X Offset (px)",
        Text = "0",
        Position = UDim2.new(0.05, 0, 0, 10)
    })
    offsetXInput.LayoutOrder = 1
    offsetXInput.Parent = settingsContent
    
    local offsetYInput = UIManager:createModernInput({
        Placeholder = "Y Offset (px)",
        Text = "0",
        Position = UDim2.new(0.05, 0, 0, 55)
    })
    offsetYInput.LayoutOrder = 2
    offsetYInput.Parent = settingsContent
    
    local btnCalibrate = UIManager:createModernButton({
        Text = "Auto-Calibrate [Visual]",
        Color = Color3.fromRGB(0, 255, 0),
        Position = UDim2.new(0.05, 0, 0, 100)
    })
    btnCalibrate.LayoutOrder = 3
    btnCalibrate.Parent = settingsContent
    
    local btnApplyOffsets = UIManager:createModernButton({
        Text = "Apply Offsets",
        Position = UDim2.new(0.05, 0, 0, 145)
    })
    btnApplyOffsets.LayoutOrder = 4
    btnApplyOffsets.Parent = settingsContent
    
    local label = Instance.new("TextLabel", settingsContent)
    label.Size = UDim2.new(0.9, 0, 0, 30)
    label.Position = UDim2.new(0.05, 0, 0, 190)
    label.BackgroundTransparency = 1
    label.Text = "Humanization: DISABLED"
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(255, 59, 48)
    label.LayoutOrder = 5
    
    -- Profiles Content
    local profileContent = contents[4]
    local profileList = Instance.new("ScrollingFrame", profileContent)
    profileList.Size = UDim2.new(0.9, 0, 0, 150)
    profileList.Position = UDim2.new(0.05, 0, 0, 10)
    profileList.BackgroundTransparency = 0.9
    profileList.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    profileList.ScrollBarThickness = 4
    profileList.LayoutOrder = 1
    
    local corner = Instance.new("UICorner", profileList)
    corner.CornerRadius = UDim.new(0, 6)
    
    local listLayout = Instance.new("UIListLayout", profileList)
    listLayout.Padding = UDim.new(0, 5)
    
    local profileNameInput = UIManager:createModernInput({
        Placeholder = "Profile Name",
        Position = UDim2.new(0.05, 0, 0, 170)
    })
    profileNameInput.LayoutOrder = 2
    profileNameInput.Parent = profileContent
    
    local btnSaveProfile = UIManager:createModernButton({
        Text = "Save Profile",
        Position = UDim2.new(0.05, 0, 0, 215)
    })
    btnSaveProfile.LayoutOrder = 3
    btnSaveProfile.Parent = profileContent
    
    local btnLoadProfile = UIManager:createModernButton({
        Text = "Load Selected",
        Position = UDim2.new(0.05, 0, 0, 260)
    })
    btnLoadProfile.LayoutOrder = 4
    btnLoadProfile.Parent = profileContent
    
    -- Toggle Button
    local toggleBtn = UIManager:createModernButton({
        Size = UDim2.new(0, 70, 0, 30),
        Position = UDim2.new(0, 10, 0, 10),
        Text = "Hide",
        Color = Color3.fromRGB(0, 255, 0)
    })
    toggleBtn.Parent = MainGUI
    
    -- Status Bar
    local statusBar = Instance.new("Frame", mainFrame)
    statusBar.Size = UDim2.new(1, 0, 0, 30)
    statusBar.Position = UDim2.new(0, 0, 1, -30)
    statusBar.BackgroundTransparency = 0.9
    statusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    statusBar.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner", statusBar)
    corner.CornerRadius = UDim.new(0, 0)
    
    local statusText = Instance.new("TextLabel", statusBar)
    statusText.Size = UDim2.new(1, -10, 1, 0)
    statusText.Position = UDim2.new(0, 5, 0, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = "Delta Macro Ready | Actions: 0"
    statusText.Font = Enum.Font.Gotham
    statusText.TextSize = 11
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.TextColor3 = Color3.fromRGB(174, 174, 178)
    
    -- Crosshair for position picker
    local crosshair = Instance.new("Frame", MainGUI)
    crosshair.Name = "Crosshair"
    crosshair.Size = UDim2.new(0, 40, 0, 40)
    crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
    crosshair.BackgroundTransparency = 1
    crosshair.Visible = false
    
    local crosshairH = Instance.new("Frame", crosshair)
    crosshairH.Size = UDim2.new(1, 0, 0, 2)
    crosshairH.Position = UDim2.new(0, 0, 0.5, -1)
    crosshairH.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    crosshairH.BorderSizePixel = 0
    
    local crosshairV = Instance.new("Frame", crosshair)
    crosshairV.Size = UDim2.new(0, 2, 1, 0)
    crosshairV.Position = UDim2.new(0.5, -1, 0, 0)
    crosshairV.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    crosshairV.BorderSizePixel = 0
    
    MainGUI.StatusText = statusText
    MainGUI.ToggleButton = toggleBtn
    MainGUI.Crosshair = crosshair
    
    MainGUI.Elements = {
        btnAutoToggle = btnAutoToggle,
        intervalInput = intervalInput,
        btnSetPos = btnSetPos,
        currentPosLabel = currentPosLabel,
        btnTestClick = btnTestClick,
        btnRecordToggle = btnRecordToggle,
        recordingIndicator = recordingIndicator,
        indicatorDot = indicatorDot,
        indicatorText = indicatorText,
        btnReplayOnce = btnReplayOnce,
        replayCountInput = replayCountInput,
        btnReplayLoop = btnReplayLoop,
        btnClearActions = btnClearActions,
        actionListViewer = actionListViewer,
        offsetXInput = offsetXInput,
        offsetYInput = offsetYInput,
        btnCalibrate = btnCalibrate,
        btnApplyOffsets = btnApplyOffsets,
        profileNameInput = profileNameInput,
        btnSaveProfile = btnSaveProfile,
        btnLoadProfile = btnLoadProfile,
        profileList = profileList,
    }
    
    return MainGUI
end

----------------------------------------------------------------
-- VISUAL POSITION PICKER
----------------------------------------------------------------
local VisualPicker = {
    isActive = false,
    connection = nil,
    
    start = function(self)
        self.isActive = true
        MainGUI.Crosshair.Visible = true
        
        self.connection = RunService.RenderStepped:Connect(function()
            local mousePos = UserInputService:GetMouseLocation()
            MainGUI.Crosshair.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
        end)
        
        local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
        TweenService:Create(MainGUI.Crosshair.H, tweenInfo, {BackgroundTransparency = 0.5}):Play()
        TweenService:Create(MainGUI.Crosshair.V, tweenInfo, {BackgroundTransparency = 0.5}):Play()
        
        Logger:info("Visual picker activated")
    end,
    
    stop = function(self)
        self.isActive = false
        if self.connection then
            self.connection:Disconnect()
            self.connection = nil
        end
        
        MainGUI.Crosshair.Visible = false
        TweenService:Create(MainGUI.Crosshair.H, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
        TweenService:Create(MainGUI.Crosshair.V, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
        
        Logger:info("Visual picker deactivated")
    end,
}

----------------------------------------------------------------
-- UPDATE UI HELPERS
----------------------------------------------------------------
local function updateActionList()
    local viewer = MainGUI.Elements.actionListViewer
    local actions = StateManager:get("recordedActions")
    
    for _, child in ipairs(viewer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    for i, action in ipairs(actions) do
        local item = Instance.new("Frame", viewer)
        item.Size = UDim2.new(1, -10, 0, 30)
        item.BackgroundTransparency = 0.95
        item.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        item.BorderSizePixel = 0
        
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
            Color = Color3.fromRGB(255, 59, 48)
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
    
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    for _, profile in ipairs(profiles) do
        local item = Instance.new("Frame", list)
        item.Size = UDim2.new(1, -10, 0, 35)
        item.BackgroundTransparency = 0.95
        item.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        item.BorderSizePixel = 0
        
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
            Color = Color3.fromRGB(255, 59, 48)
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
-- BUTTON CONNECTIONS
----------------------------------------------------------------
local function connectButtons()
    -- AutoClick
    MainGUI.Elements.btnAutoToggle.MouseButton1Click:Connect(function()
        local interval = tonumber(MainGUI.Elements.intervalInput.Text) or 0.2
        StateManager:set("clickInterval", interval)
        
        if StateManager:get("autoClickEnabled") then
            StateManager:set("autoClickEnabled", false)
            MainGUI.Elements.btnAutoToggle.Text = "Auto Clicker: OFF"
        else
            if StateManager:get("clickPosition") == Vector2.new(500, 500) then
                MainGUI.StatusText.Text = "Error: Set click position first"
                return
            end
            
            StateManager:set("autoClickEnabled", true)
            MainGUI.Elements.btnAutoToggle.Text = "Auto Clicker: ON"
            
            task.spawn(function()
                local count = 0
                while StateManager:get("autoClickEnabled") do
                    InputSimulator:performClick(StateManager:get("clickPosition"))
                    count = count + 1
                    if count % 10 == 0 then
                        MainGUI.Elements.btnAutoToggle.Text = string.format("Clicks: %d", count)
                    end
                    task.wait(StateManager:get("clickInterval"))
                end
            end)
        end
    end)
    
    -- Visual position picker
    MainGUI.Elements.btnSetPos.MouseButton1Click:Connect(function()
        if VisualPicker.isActive then
            VisualPicker:stop()
            MainGUI.Elements.btnSetPos.Text = "Set Position [Visual]"
        else
            VisualPicker:start()
            MainGUI.Elements.btnSetPos.Text = "Click to Set..."
            
            local conn
            conn = UserInputService.InputBegan:Connect(function(input, gp)
                if gp or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                
                if VisualPicker.isActive then
                    local pos = UserInputService:GetMouseLocation()
                    StateManager:set("clickPosition", pos)
                    
                    VisualPicker:stop()
                    MainGUI.Elements.btnSetPos.Text = "Position Set!"
                    MainGUI.Elements.currentPosLabel.Text = string.format("Current: (%d, %d)", pos.X, pos.Y)
                    
                    VisualFeedback:showClickMarker(pos, Color3.fromRGB(0, 255, 0), 20, 1)
                    
                    task.delay(2, function()
                        MainGUI.Elements.btnSetPos.Text = "Set Position [Visual]"
                    end)
                    
                    conn:Disconnect()
                end
            end)
        end
    end)
    
    -- Test click
    MainGUI.Elements.btnTestClick.MouseButton1Click:Connect(function()
        if StateManager:get("clickPosition") == Vector2.new(500, 500) then
            MainGUI.StatusText.Text = "Error: Set position first"
            return
        end
        
        local pos = StateManager:get("clickPosition")
        VisualFeedback:showClickMarker(pos, Color3.fromRGB(0, 255, 0), 15, 1)
        InputSimulator:performClick(pos)
    end)
    
    -- Recorder
    MainGUI.Elements.btnRecordToggle.MouseButton1Click:Connect(function()
        if StateManager:get("isRecording") then
            RecordingEngine:stopRecording()
            MainGUI.Elements.btnRecordToggle.Text = "Start Recording"
            MainGUI.Elements.indicatorDot.Visible = false
            MainGUI.Elements.indicatorText.Text = "Not Recording"
        else
            RecordingEngine:startRecording()
            MainGUI.Elements.btnRecordToggle.Text = "Stop Recording"
            MainGUI.Elements.indicatorDot.Visible = true
            MainGUI.Elements.indicatorText.Text = "Recording..."
            
            task.spawn(function()
                while StateManager:get("isRecording") do
                    MainGUI.Elements.indicatorDot.BackgroundTransparency = 0
                    task.wait(0.5)
                    MainGUI.Elements.indicatorDot.BackgroundTransparency = 0.5
                    task.wait(0.5)
                end
            end)
        end
        updateActionList()
    end)
    
    MainGUI.Elements.btnReplayOnce.MouseButton1Click:Connect(function()
        if #StateManager:get("recordedActions") == 0 then
            MainGUI.StatusText.Text = "Error: No actions recorded"
            return
        end
        
        local count = tonumber(MainGUI.Elements.replayCountInput.Text) or 1
        StateManager:set("replayCount", count)
        
        if StateManager:get("isReplaying") then
            StateManager:set("isReplaying", false)
            MainGUI.Elements.btnReplayOnce.Text = "Replay Once"
        else
            StateManager:set("isReplaying", true)
            MainGUI.Elements.btnReplayOnce.Text = "Stop Replay"
            RecordingEngine:replayActions(StateManager:get("recordedActions"), false)
        end
    end)
    
    MainGUI.Elements.btnReplayLoop.MouseButton1Click:Connect(function()
        if #StateManager:get("recordedActions") == 0 then
            MainGUI.StatusText.Text = "Error: No actions recorded"
            return
        end
        
        if StateManager:get("isReplayingLoop") then
            StateManager:set("isReplayingLoop", false)
            MainGUI.Elements.btnReplayLoop.Text = "Loop Replay: OFF"
        else
            StateManager:set("isReplayingLoop", true)
            MainGUI.Elements.btnReplayLoop.Text = "Loop Replay: ON"
            RecordingEngine:replayActions(StateManager:get("recordedActions"), true)
        end
    end)
    
    MainGUI.Elements.btnClearActions.MouseButton1Click:Connect(function()
        RecordingEngine:clearRecording()
        updateActionList()
        MainGUI.StatusText.Text = "Actions cleared"
    end)
    
    -- Settings
    MainGUI.Elements.btnCalibrate.MouseButton1Click:Connect(function()
        MainGUI.StatusText.Text = "Calibration: Click the center"
        
        local viewportSize = Cache.viewportSize
        local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
        
        local target = Instance.new("Frame", MainGUI)
        target.Size = UDim2.new(0, 30, 0, 30)
        target.Position = UDim2.new(0, center.X - 15, 0, center.Y - 15)
        target.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        target.BackgroundTransparency = 0.3
        
        local corner = Instance.new("UICorner", target)
        corner.CornerRadius = UDim.new(1, 0)
        
        local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
        TweenService:Create(target, tweenInfo, {BackgroundTransparency = 0.6}):Play()
        
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            
            local clickPos = UserInputService:GetMouseLocation()
            local diff = clickPos - center
            
            StateManager:set("activeXOffset", -math.floor(diff.X))
            StateManager:set("activeYOffset", -math.floor(diff.Y))
            
            MainGUI.Elements.offsetXInput.Text = tostring(-math.floor(diff.X))
            MainGUI.Elements.offsetYInput.Text = tostring(-math.floor(diff.Y))
            
            target:Destroy()
            conn:Disconnect()
            
            MainGUI.StatusText.Text = string.format("Calibrated: X=%d, Y=%d", -math.floor(diff.X), -math.floor(diff.Y))
            Logger:info("Calibration complete", {offsetX = -math.floor(diff.X), offsetY = -math.floor(diff.Y)})
        end)
        
        task.wait(10)
        if target.Parent then
            target:Destroy()
            conn:Disconnect()
            MainGUI.StatusText.Text = "Calibration timed out"
        end
    end)
    
    MainGUI.Elements.btnApplyOffsets.MouseButton1Click:Connect(function()
        local x = tonumber(MainGUI.Elements.offsetXInput.Text) or 0
        local y = tonumber(MainGUI.Elements.offsetYInput.Text) or 0
        
        StateManager:set("activeXOffset", x)
        StateManager:set("activeYOffset", y)
        
        MainGUI.StatusText.Text = string.format("Offsets: X=%d, Y=%d", x, y)
    end)
    
    -- Profiles
    MainGUI.Elements.btnSaveProfile.MouseButton1Click:Connect(function()
        local name = MainGUI.Elements.profileNameInput.Text
        if not name or name == "" then name = "default" end
        
        ProfileManager:saveProfile(name)
        updateProfileList()
        MainGUI.Elements.profileNameInput.Text = ""
        MainGUI.StatusText.Text = "Saved: " .. name
    end)
    
    MainGUI.Elements.btnLoadProfile.MouseButton1Click:Connect(function()
        local selected = StateManager:get("currentProfile")
        if selected and selected ~= "" then
            ProfileManager:loadProfile(selected)
            updateActionList()
            MainGUI.StatusText.Text = "Loaded: " .. selected
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
    
    -- Toggle GUI
    MainGUI.ToggleButton.MouseButton1Click:Connect(function()
        local hidden = not StateManager:get("guiHidden")
        StateManager:set("guiHidden", hidden)
        
        mainFrame.Visible = not hidden
        MainGUI.ToggleButton.Text = hidden and "Show" or "Hide"
    end)
    
    -- State subscriptions
    StateManager:subscribe("autoClickEnabled", function(value)
        MainGUI.Elements.btnAutoToggle.Text = value and "Auto Clicker: ON" or "Auto Clicker: OFF"
    end)
    
    StateManager:subscribe("isReplaying", function(value)
        MainGUI.Elements.btnReplayOnce.Text = value and "Stop Replay" or "Replay Once"
    end)
    
    StateManager:subscribe("isReplayingLoop", function(value)
        MainGUI.Elements.btnReplayLoop.Text = value and "Loop Replay: ON" or "Loop Replay: OFF"
    end)
    
    StateManager:subscribe("clickPosition", function(pos)
        MainGUI.Elements.currentPosLabel.Text = string.format("Current: (%d, %d)", pos.X, pos.Y)
    end)
    
    StateManager:subscribe("recordedActions", function(actions)
        updateActionList()
        MainGUI.StatusText.Text = string.format("Delta Macro | Actions: %d", #actions)
    end)
end

----------------------------------------------------------------
-- MAIN INITIALIZATION
----------------------------------------------------------------
local function initialize()
    -- Initialize services
    Players = getService("Players") or {}
    UserInputService = getService("UserInputService") or {}
    StarterGui = getService("StarterGui") or {}
    RunService = getService("RunService") or {}
    GuiService = getService("GuiService") or {}
    CoreGui = getService("CoreGui") or game:FindFirstChild("CoreGui")
    TweenService = getService("TweenService") or {}
    LocalPlayer = Players.LocalPlayer
    
    if not LocalPlayer then
        Logger:error("LocalPlayer not found")
        return
    end
    
    Compatibility:DetectEnvironment()
    createGUI()
    connectButtons()
    
    task.spawn(function()
        while task.wait(CONFIG.CACHE_REFRESH_RATE) do
            Cache:update()
        end
    end)
    
    UserInputService.WindowFocusReleased:Connect(function()
        Logger:warn("Focus lost - stopping all macros")
        StateManager:set("autoClickEnabled", false)
        StateManager:set("isRecording", false)
        StateManager:set("isReplaying", false)
        StateManager:set("isReplayingLoop", false)
    end)
    
    Logger:info("Delta Macro initialized")
    MainGUI.StatusText.Text = "Delta Macro Ready | Actions: 0"
end

-- Start
initialize()
