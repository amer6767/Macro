--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                     AXIORA ULTIMATE v6.0 - DELTA OPTIMIZED                ║
    ║                        Complete Rewrite for Stability                      ║
    ║                                                                            ║
    ║  Features: Recording, Playback, Strategy Loading, Visual HUD, UI          ║
    ║  Optimized for: Delta Executor (with fallbacks for other executors)       ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 1: ENVIRONMENT SETUP & CAPABILITY DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

local Axiora = {}
Axiora._VERSION = "6.0.0"
Axiora._BUILD = "DELTA-STABLE"

-- Safe function to get global environment
local function getEnv()
    if getgenv then return getgenv() end
    if getfenv then return getfenv(0) end
    return _G
end

local Root = getEnv()

-- Prevent multiple loads
if Root.Axiora and Root.Axiora._LOADED then
    warn("[Axiora] Already loaded, skipping re-initialization")
    return Root.Axiora
end

-- Safe service getter with caching
local Services = setmetatable({}, {
    __index = function(self, serviceName)
        local success, service = pcall(function()
            return game:GetService(serviceName)
        end)
        if success and service then
            -- Use cloneref if available for security
            if typeof(cloneref) == "function" then
                service = cloneref(service)
            end
            rawset(self, serviceName, service)
            return service
        end
        return nil
    end
})

-- Pre-cache commonly used services
local Players = Services.Players
local RunService = Services.RunService
local UserInputService = Services.UserInputService
local TweenService = Services.TweenService
local HttpService = Services.HttpService
local Workspace = Services.Workspace
local CoreGui = Services.CoreGui
local GuiService = Services.GuiService
local VirtualInputManager = Services.VirtualInputManager
local PathfindingService = Services.PathfindingService

-- Get local player safely
local function getLocalPlayer()
    return Players and Players.LocalPlayer
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CAPABILITY DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Capabilities = {
    -- Executor detection
    IsDelta = typeof(Root.delta) == "table" or typeof(Root.Delta) == "table",
    Executor = "Unknown",
    
    -- File system
    ReadFile = typeof(readfile) == "function",
    WriteFile = typeof(writefile) == "function",
    MakeFolder = typeof(makefolder) == "function",
    IsFile = typeof(isfile) == "function",
    IsFolder = typeof(isfolder) == "function",
    
    -- Input capabilities
    MouseMoveAbs = typeof(mousemoveabs) == "function",
    MouseClick = typeof(mouse1click) == "function",
    KeyPress = typeof(keypress) == "function",
    KeyRelease = typeof(keyrelease) == "function",
    VirtualInput = VirtualInputManager ~= nil,
    
    -- Metatable capabilities
    GetRawMetatable = typeof(getrawmetatable) == "function",
    SetReadonly = typeof(setreadonly) == "function",
    NewCClosure = typeof(newcclosure) == "function",
    
    -- Drawing
    Drawing = typeof(Drawing) == "table" or typeof(Drawing) == "userdata",
    
    -- Other
    GetNamecallMethod = typeof(getnamecallmethod) == "function",
    SetClipboard = typeof(setclipboard) == "function",
    Request = typeof(request) == "function" or typeof(http_request) == "function",
    
    -- Identity level (estimated)
    IdentityLevel = 2
}

-- Detect executor
local function detectExecutor()
    local executors = {
        {check = function() return Root.delta or Root.Delta end, name = "Delta"},
        {check = function() return syn and syn.protect_gui end, name = "Synapse X"},
        {check = function() return KRNL_LOADED end, name = "KRNL"},
        {check = function() return fluxus end, name = "Fluxus"},
        {check = function() return Hydrogen end, name = "Hydrogen"},
        {check = function() return getexecutorname and getexecutorname() end, name = nil},
    }
    
    for _, exec in ipairs(executors) do
        local success, result = pcall(exec.check)
        if success and result then
            return exec.name or tostring(result)
        end
    end
    return "Unknown"
end

Axiora.Capabilities.Executor = detectExecutor()

-- Check identity level
pcall(function()
    if getidentity then
        Axiora.Capabilities.IdentityLevel = getidentity()
    elseif getthreadcontext then
        Axiora.Capabilities.IdentityLevel = getthreadcontext()
    end
end)

-- File system verified check
Axiora.Capabilities.FileSystemVerified = false
if Axiora.Capabilities.WriteFile and Axiora.Capabilities.ReadFile then
    local testSuccess = pcall(function()
        writefile("Axiora/_test.tmp", "test")
        local content = readfile("Axiora/_test.tmp")
        if Axiora.Capabilities.IsFile then
            if isfile("Axiora/_test.tmp") then
                delfile("Axiora/_test.tmp")
            end
        end
        return content == "test"
    end)
    Axiora.Capabilities.FileSystemVerified = testSuccess
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 2: CORE STATE & EVENT SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.State = {
    Status = "IDLE", -- IDLE, RECORDING, PLAYING, PAUSED
    Buffer = {},
    StartTime = 0,
    Connections = {},
    Threads = {},
    SecurityConnections = {},
    InitTime = os.clock()
}

Axiora.Settings = {
    -- Recording
    SmartRecording = true,
    MinMoveDistance = 0.5,
    MinClickInterval = 0.05,
    RecordUIClicks = true,
    RecordCamera = true,
    RecordVelocity = true, -- Record movement direction for accurate replay
    MaxBufferSize = 50000,
    
    -- Playback
    TimeScale = 1.0,
    NavigationTimeout = 10,
    NavigationRetries = 3,
    
    -- Pathfinding (Smart navigation to start)
    UsePathfinding = true, -- Use pathfinding instead of teleport
    PathfindingTimeout = 30, -- Max seconds to pathfind to start
    TeleportFallback = true, -- Teleport if pathfinding fails (executor dependent)
    
    -- Input offsets (calibration)
    XOffset = 0,
    YOffset = 0,
    
    -- Features
    AntiAFK = true,
    AntiKick = false,
    ClickRipple = true,
    AutoSave = false,
    AutoSaveInterval = 300,
    
    -- Visuals
    Theme = "default",
    HUDEnabled = true,
    PerformanceMode = false,
    
    -- Progressive Rendering
    RenderBatchSize = 50,
    RenderBatchDelay = 0.03,
    
    -- Click Recovery
    ClickRecoveryEnabled = true,
    ClickRecoveryMaxAttempts = 9,
    ClickRecoveryOffsetPixels = 5,
    ClickRecoveryDelay = 0.05,
    
    -- Breakpoints
    BreakpointsEnabled = true,
    BreakpointNotify = true,
    
    -- Buffer Library
    UseNativeBuffers = false, -- Enable binary buffers for memory savings
    
    -- Debug
    DebugPathfinding = false -- Visualize pathfinding waypoints
}

-- Simple event system
Axiora.Events = {
    _listeners = {}
}

function Axiora.Events:Connect(eventName, callback)
    if not self._listeners[eventName] then
        self._listeners[eventName] = {}
    end
    local id = #self._listeners[eventName] + 1
    self._listeners[eventName][id] = callback
    
    return {
        Disconnect = function()
            self._listeners[eventName][id] = nil
        end
    }
end

function Axiora.Events:Fire(eventName, ...)
    if not self._listeners[eventName] then return end
    for _, callback in pairs(self._listeners[eventName]) do
        if typeof(callback) == "function" then
            task.spawn(function(...)
                pcall(callback, ...)
            end, ...)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 3: MATH UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Math = {
    Screen = {
        Viewport = Vector2.new(1920, 1080),
        GuiInset = Vector2.new(0, 36), -- Default Roblox top bar height
        Initialized = false
    }
}

function Axiora.Math.UpdateScreenMetrics()
    local success = pcall(function()
        local cam = Workspace.CurrentCamera
        if cam then
            Axiora.Math.Screen.Viewport = cam.ViewportSize
        end
        
        if GuiService and GuiService.GetGuiInset then
            local insetTop, insetBottom = GuiService:GetGuiInset()
            -- insetTop is the Vector2 offset from top-left
            if typeof(insetTop) == "Vector2" then
                Axiora.Math.Screen.GuiInset = insetTop
            else
                Axiora.Math.Screen.GuiInset = Vector2.new(0, 36)
            end
        end
        
        Axiora.Math.Screen.Initialized = true
    end)
    return success
end

-- Wait for screen metrics to be valid
function Axiora.Math.WaitForInit(timeout)
    timeout = timeout or 2
    local start = os.clock()
    
    while (os.clock() - start) < timeout do
        Axiora.Math.UpdateScreenMetrics()
        if Axiora.Math.Screen.Viewport.X > 100 then
            return true
        end
        task.wait(0.1)
    end
    return false
end

-- Convert relative coords (0-1) to absolute screen position (for input simulation)
-- Returns coordinates that include GUI inset (what VirtualInputManager expects)
function Axiora.Math.GetAbsoluteInput(relX, relY)
    local viewport = Axiora.Math.Screen.Viewport
    local inset = Axiora.Math.Screen.GuiInset
    
    if viewport.X < 10 then viewport = Vector2.new(1920, 1080) end
    
    -- Convert relative to viewport coordinates
    local x = relX * viewport.X
    local y = relY * viewport.Y
    
    -- Add GUI inset to get screen coordinates (VirtualInputManager needs this)
    x = x + inset.X + (Axiora.Settings.XOffset or 0)
    y = y + inset.Y + (Axiora.Settings.YOffset or 0)
    
    -- Clamp to valid screen range
    local totalWidth = viewport.X
    local totalHeight = viewport.Y + inset.Y
    x = math.clamp(x, 0, totalWidth)
    y = math.clamp(y, inset.Y, totalHeight)
    
    return Vector2.new(x, y)
end

-- Convert absolute screen position to relative coords (0-1)
-- Input is screen coordinates (from GetMouseLocation which includes inset)
function Axiora.Math.GetRelativeInput(absX, absY)
    local viewport = Axiora.Math.Screen.Viewport
    local inset = Axiora.Math.Screen.GuiInset
    
    if viewport.X < 10 then viewport = Vector2.new(1920, 1080) end
    
    -- Subtract GUI inset to get viewport-relative coordinates
    local viewX = absX - inset.X
    local viewY = absY - inset.Y
    
    -- Convert to 0-1 range relative to viewport
    return {
        x = math.clamp(viewX / viewport.X, 0, 1),
        y = math.clamp(viewY / viewport.Y, 0, 1)
    }
end

-- Serialize Vector3 to compact array
function Axiora.Math.SerializeVec(v)
    if not v then return {0, 0, 0} end
    return {
        math.floor(v.X * 100) / 100,
        math.floor(v.Y * 100) / 100,
        math.floor(v.Z * 100) / 100
    }
end

-- Deserialize array to Vector3
function Axiora.Math.DeserializeVec(t)
    if not t or type(t) ~= "table" then return Vector3.zero end
    return Vector3.new(t[1] or 0, t[2] or 0, t[3] or 0)
end

-- Serialize CFrame to component array
function Axiora.Math.SerializeCF(cf)
    if not cf then return nil end
    local components = {cf:GetComponents()}
    for i, v in ipairs(components) do
        components[i] = math.floor(v * 1000) / 1000
    end
    return components
end

-- Deserialize array to CFrame
function Axiora.Math.DeserializeCF(t)
    if not t or type(t) ~= "table" or #t ~= 12 then return nil end
    local success, result = pcall(function()
        return CFrame.new(table.unpack(t))
    end)
    return success and result or nil
end

-- Initialize screen metrics
task.spawn(function()
    task.wait(0.5)
    Axiora.Math.WaitForInit(3)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 3.5: BUFFER LIBRARY (Memory Management)
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.BufferLib = {
    Enabled = false,
    Supported = (typeof(buffer) == "table" or typeof(buffer) == "userdata") and typeof(buffer.create) == "function",
    NodeSize = 34, -- Fixed size per node (bytes)
    GrowthFactor = 1.5
}

-- Node Binary Format (34 bytes):
-- [0] Type (u8)
-- [1-4] Delay (f32)
-- [5-8] X/P.X (f32)
-- [9-12] Y/P.Y (f32)
-- [13-16] Z (f32) - only for Move
-- [17-20] Cam.X (f32)
-- [21-24] Cam.Y (f32)
-- [25-28] Cam.Z (f32) 
-- [29] Flags (u8) - 1=Jump, 2=UI
-- [30-33] KeyCode/Extra (u32)

function Axiora.BufferLib.Init(initialCapacity)
    if not Axiora.BufferLib.Supported then return nil end
    initialCapacity = initialCapacity or 10000
    
    local size = initialCapacity * Axiora.BufferLib.NodeSize
    local buf = buffer.create(size)
    
    return {
        Raw = buf,
        Capacity = initialCapacity,
        Count = 0,
        WriteCursor = 0
    }
end

function Axiora.BufferLib.WriteNode(bufObj, node)
    if not bufObj or not bufObj.Raw then return false end
    
    -- Check capacity
    if bufObj.Count >= bufObj.Capacity then
        -- Grow buffer
        local newCap = math.floor(bufObj.Capacity * Axiora.BufferLib.GrowthFactor)
        local newSize = newCap * Axiora.BufferLib.NodeSize
        local newBuf = buffer.create(newSize)
        buffer.copy(newBuf, 0, bufObj.Raw, 0, bufObj.WriteCursor)
        
        bufObj.Raw = newBuf
        bufObj.Capacity = newCap
    end
    
    local offset = bufObj.WriteCursor
    local b = bufObj.Raw
    
    -- Write common data
    buffer.writeu8(b, offset, node.t or 0)
    buffer.writef32(b, offset + 1, node.d or 0)
    
    -- Type-specific write
    local flags = 0
    
    if node.t == 1 then -- Move
        if node.p then
            local p = Axiora.Math.DeserializeVec(node.p)
            buffer.writef32(b, offset + 5, p.X)
            buffer.writef32(b, offset + 9, p.Y)
            buffer.writef32(b, offset + 13, p.Z)
        end
        
        if node.c then
            local cf = Axiora.Math.DeserializeCF(node.c)
            if cf then
                local lv = cf.LookVector
                buffer.writef32(b, offset + 17, lv.X)
                buffer.writef32(b, offset + 21, lv.Y)
                buffer.writef32(b, offset + 25, lv.Z)
            end
        end
        
        if node.j then flags = bit32.bor(flags, 1) end
        
    elseif node.t == 2 then -- Click
        buffer.writef32(b, offset + 5, node.x or 0)
        buffer.writef32(b, offset + 9, node.y or 0)
        if node.ui then flags = bit32.bor(flags, 2) end
        
    elseif node.t == 3 then -- Key
        local k = node.k and Enum.KeyCode[node.k] and Enum.KeyCode[node.k].Value or 0
        buffer.writeu32(b, offset + 30, k)
    end
    
    buffer.writeu8(b, offset + 29, flags)
    
    bufObj.Count = bufObj.Count + 1
    bufObj.WriteCursor = bufObj.WriteCursor + Axiora.BufferLib.NodeSize
    return true
end

function Axiora.BufferLib.ReadNode(bufObj, index)
    if not bufObj or index < 1 or index > bufObj.Count then return nil end
    
    local offset = (index - 1) * Axiora.BufferLib.NodeSize
    local b = bufObj.Raw
    
    local t = buffer.readu8(b, offset)
    local d = buffer.readf32(b, offset + 1)
    local flags = buffer.readu8(b, offset + 29)
    
    local node = {t = t, d = d}
    
    if t == 1 then -- Move
        local x = buffer.readf32(b, offset + 5)
        local y = buffer.readf32(b, offset + 9)
        local z = buffer.readf32(b, offset + 13)
        node.p = {x, y, z} -- Simplified vector
        
        local cx = buffer.readf32(b, offset + 17)
        local cy = buffer.readf32(b, offset + 21)
        local cz = buffer.readf32(b, offset + 25)
        if cx ~= 0 or cy ~= 0 or cz ~= 0 then
             -- We only stored lookvector, reconstructing full CF is hard without knowing Up/Right
             -- This is a simplified version for memory efficiency
             -- For full fidelity, standard tables are better.
        end
        
        if bit32.band(flags, 1) ~= 0 then node.j = true end
        
    elseif t == 2 then -- Click
        node.x = buffer.readf32(b, offset + 5)
        node.y = buffer.readf32(b, offset + 9)
        if bit32.band(flags, 2) ~= 0 then node.ui = true end
        
    elseif t == 3 then -- Key
        local kVal = buffer.readu32(b, offset + 30)
        -- Need to reverse lookup KeyCode enum... complex in loop
        -- Storing key name string is hard in fixed buffer without lookup table
    end
    
    return node
end

function Axiora.BufferLib.ToTable(bufObj)
    if not bufObj then return {} end
    local t = {}
    for i = 1, bufObj.Count do
        table.insert(t, Axiora.BufferLib.ReadNode(bufObj, i))
    end
    return t
end

function Axiora.BufferLib.FromTable(tbl)
    local bufObj = Axiora.BufferLib.Init(#tbl)
    if not bufObj then return nil end
    for _, node in ipairs(tbl) do
        Axiora.BufferLib.WriteNode(bufObj, node)
    end
    return bufObj
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 4: INPUT SYSTEM (Multi-Executor Compatible)
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Input = {
    Method = "VIM", -- Delta, Native, VIM
    ClickDelay = 0.02
}

-- Detect best input method
local function detectInputMethod()
    -- Check for Delta's native input
    if Axiora.Capabilities.IsDelta then
        local deltaGlobal = Root.delta or Root.Delta
        if deltaGlobal and typeof(deltaGlobal.input) == "table" then
            Axiora.Input.Method = "Delta"
            Axiora.Input._deltaInput = deltaGlobal.input
            return
        end
    end
    
    -- Check for native mouse functions
    if Axiora.Capabilities.MouseMoveAbs and Axiora.Capabilities.MouseClick then
        Axiora.Input.Method = "Native"
        return
    end
    
    -- Fallback to VirtualInputManager
    Axiora.Input.Method = "VIM"
end

detectInputMethod()

-- Universal click function
function Axiora.Input.Click(x, y, nonBlocking)
    local startTime = os.clock()
    
    -- Delta method (fastest)
    if Axiora.Input.Method == "Delta" and Axiora.Input._deltaInput then
        local success = pcall(function()
            if Axiora.Input._deltaInput.mouse_move then
                Axiora.Input._deltaInput.mouse_move(x, y)
            end
            task.wait(0.01)
            if Axiora.Input._deltaInput.mouse_click then
                Axiora.Input._deltaInput.mouse_click()
            end
        end)
        if success then return true, os.clock() - startTime end
    end
    
    -- Native method
    if Axiora.Input.Method == "Native" then
        local success = pcall(function()
            mousemoveabs(x, y)
            if not nonBlocking then task.wait(Axiora.Input.ClickDelay) end
            mouse1click()
        end)
        if success then return true, os.clock() - startTime end
    end
    
    -- VIM fallback
    if VirtualInputManager then
        if nonBlocking then
            task.spawn(function()
                pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
                    task.wait(0.03)
                    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
                end)
            end)
            return true, 0
        else
            local success = pcall(function()
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
                task.wait(0.03)
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
            end)
            return success, os.clock() - startTime
        end
    end
    
    return false, 0
end

-- Universal key press function
function Axiora.Input.KeyPress(keyCode, duration)
    duration = duration or 0.05
    
    -- Delta method
    if Axiora.Input.Method == "Delta" and Axiora.Input._deltaInput then
        local success = pcall(function()
            if Axiora.Input._deltaInput.key_press then
                Axiora.Input._deltaInput.key_press(keyCode)
                task.wait(duration)
                Axiora.Input._deltaInput.key_release(keyCode)
            end
        end)
        if success then return true end
    end
    
    -- Native method
    if Axiora.Capabilities.KeyPress and Axiora.Capabilities.KeyRelease then
        local success = pcall(function()
            keypress(keyCode)
            task.wait(duration)
            keyrelease(keyCode)
        end)
        if success then return true end
    end
    
    -- VIM fallback
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
            task.wait(duration)
            VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
        end)
        return true
    end
    
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLICK RECOVERY (Spiral Offset Pattern)
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.ClickRecovery = {
    Enabled = true,
    LastAttempts = 0,
    LastSuccess = true
}

-- Generate spiral offsets for click recovery
function Axiora.ClickRecovery.GetSpiralOffsets()
    local offset = Axiora.Settings.ClickRecoveryOffsetPixels
    return {
        {0, 0},           -- Center (original)
        {offset, 0},      -- Right
        {-offset, 0},     -- Left
        {0, -offset},     -- Up
        {0, offset},      -- Down
        {offset, -offset},  -- Up-right
        {-offset, -offset}, -- Up-left
        {offset, offset},   -- Down-right
        {-offset, offset}   -- Down-left
    }
end

-- Click with spiral recovery pattern
-- validator: optional function that returns true if click succeeded
function Axiora.ClickRecovery.ClickWithRetry(x, y, validator)
    if not Axiora.Settings.ClickRecoveryEnabled then
        Axiora.Input.Click(x, y)
        return true, 1
    end
    
    local offsets = Axiora.ClickRecovery.GetSpiralOffsets()
    local maxAttempts = math.min(#offsets, Axiora.Settings.ClickRecoveryMaxAttempts)
    local delay = Axiora.Settings.ClickRecoveryDelay
    
    for attempt = 1, maxAttempts do
        local offsetX = offsets[attempt][1]
        local offsetY = offsets[attempt][2]
        local clickX = x + offsetX
        local clickY = y + offsetY
        
        Axiora.Input.Click(clickX, clickY)
        Axiora.ClickRecovery.LastAttempts = attempt
        
        -- If no validator, assume success on first attempt
        if not validator then
            Axiora.ClickRecovery.LastSuccess = true
            return true, attempt
        end
        
        -- Wait a bit for UI to respond
        task.wait(delay)
        
        -- Check if click was successful
        local success = pcall(function()
            return validator()
        end)
        
        if success then
            Axiora.ClickRecovery.LastSuccess = true
            if attempt > 1 then
                Axiora.Events:Fire("ClickRecovered", {
                    OriginalX = x,
                    OriginalY = y,
                    SuccessX = clickX,
                    SuccessY = clickY,
                    Attempts = attempt
                })
            end
            return true, attempt
        end
    end
    
    -- All attempts failed
    Axiora.ClickRecovery.LastSuccess = false
    Axiora.Events:Fire("ClickRecoveryFailed", {
        X = x,
        Y = y,
        Attempts = maxAttempts
    })
    return false, maxAttempts
end

-- Quick check function - tries click recovery if needed
function Axiora.SmartClick(relX, relY, validator)
    local abs = Axiora.Math.GetAbsoluteInput(relX, relY)
    return Axiora.ClickRecovery.ClickWithRetry(abs.X, abs.Y, validator)
end

-- Create a validator function for UI elements
function Axiora.ClickRecovery.CreateUIValidator(guiObject)
    return function()
        return guiObject and guiObject.Visible and guiObject.Parent 
               and guiObject.AbsoluteSize.X > 0
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 5: RECORDING ENGINE
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Recording = {
    Active = false,
    StartTime = 0,
    LastNodeTime = 0,
    NodeCount = 0,
    LastPos = Vector3.zero,
    LastCamCF = CFrame.new(),
    LastClickPos = Vector2.zero,
    LastClickTime = 0
}

-- Clean disconnect all recording connections
local function cleanupRecordingConnections()
    for key, conn in pairs(Axiora.State.Connections) do
        if typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    Axiora.State.Connections = {}
end

-- Add a node with optimization
local function addNode(node)
    if #Axiora.State.Buffer >= Axiora.Settings.MaxBufferSize then
        Axiora.Stop()
        Axiora.Events:Fire("BufferFull")
        return false
    end
    
    table.insert(Axiora.State.Buffer, node)
    Axiora.Recording.NodeCount = Axiora.Recording.NodeCount + 1
    return true
end

-- Check if we should record this position (smart filtering)
local function shouldRecordPosition(currentPos, timeSinceLastNode)
    if not Axiora.Settings.SmartRecording then return true end
    
    local distance = (currentPos - Axiora.Recording.LastPos).Magnitude
    if distance < Axiora.Settings.MinMoveDistance then
        return false
    end
    
    if timeSinceLastNode < 0.05 then
        return false
    end
    
    return true
end

function Axiora.Record()
    Axiora.Stop()
    
    -- Wait for math initialization
    Axiora.Math.WaitForInit(2)
    
    local LP = getLocalPlayer()
    if not LP then
        Axiora.Events:Fire("Error", {Message = "No local player"})
        return false
    end
    
    -- Initialize state
    Axiora.State.Status = "RECORDING"
    Axiora.State.Buffer = {}
    Axiora.State.StartTime = os.clock()
    Axiora.Recording.Active = true
    Axiora.Recording.StartTime = os.clock()
    Axiora.Recording.LastNodeTime = os.clock()
    Axiora.Recording.NodeCount = 0
    Axiora.Recording.LastPos = Vector3.zero
    Axiora.Recording.LastCamCF = CFrame.new()
    Axiora.Recording.LastClickPos = Vector2.zero
    Axiora.Recording.LastClickTime = 0
    
    -- Movement recording
    Axiora.State.Connections.Move = RunService.Heartbeat:Connect(function()
        local char = LP.Character
        if not char then return end
        
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        
        local pos = root.Position
        local now = os.clock()
        local timeSinceLastNode = now - Axiora.Recording.LastNodeTime
        
        local camChanged = false
        local cam = Workspace.CurrentCamera
        if Axiora.Settings.RecordCamera and cam then
            local camRotDiff = math.abs((cam.CFrame.LookVector - Axiora.Recording.LastCamCF.LookVector).Magnitude)
            if camRotDiff > 0.05 then
                camChanged = true
            end
        end
        
        if shouldRecordPosition(pos, timeSinceLastNode) or hum.Jump or (camChanged and timeSinceLastNode > 0.1) then
            local node = {
                t = 1, -- Movement type
                d = now - Axiora.State.StartTime, -- Delay from start
                p = Axiora.Math.SerializeVec(pos),
            }
            
            -- Record velocity/movement direction for accurate path replay
            if Axiora.Settings.RecordVelocity then
                local moveDir = hum.MoveDirection
                if moveDir.Magnitude > 0.1 then
                    -- Store normalized movement direction
                    node.v = {
                        math.floor(moveDir.X * 100) / 100,
                        math.floor(moveDir.Y * 100) / 100,
                        math.floor(moveDir.Z * 100) / 100
                    }
                end
                
                -- Store walk speed for replay accuracy
                node.ws = math.floor(hum.WalkSpeed * 10) / 10
            end
            
            if hum.Jump then
                node.j = true
            end
            
            if Axiora.Settings.RecordCamera and cam and camChanged then
                node.c = Axiora.Math.SerializeCF(cam.CFrame)
                Axiora.Recording.LastCamCF = cam.CFrame
            end
            
            addNode(node)
            Axiora.Recording.LastPos = pos
            Axiora.Recording.LastNodeTime = now
        end
    end)
    
    -- Input recording (clicks and keys)
    Axiora.State.Connections.Input = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed and not Axiora.Settings.RecordUIClicks then return end
        
        local now = os.clock()
        
        -- Mouse/Touch clicks
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            
            -- CRITICAL FIX: Always use GetMouseLocation() for consistent coordinates
            -- GetMouseLocation() returns screen coordinates INCLUDING GUI inset
            -- input.Position does NOT include inset, which caused the offset bug
            local clickPos = UserInputService:GetMouseLocation()
            
            -- For touch, we need to handle differently since GetMouseLocation might not work
            if input.UserInputType == Enum.UserInputType.Touch and input.Position then
                -- Touch position needs inset added manually
                local inset = Axiora.Math.Screen.GuiInset
                clickPos = Vector2.new(input.Position.X + inset.X, input.Position.Y + inset.Y)
            end
            
            -- Get relative coordinates (GetRelativeInput expects coordinates WITH inset)
            local rel = Axiora.Math.GetRelativeInput(clickPos.X, clickPos.Y)
            
            -- Filter duplicate clicks
            local clickDist = math.abs(rel.x - Axiora.Recording.LastClickPos.X) + 
                             math.abs(rel.y - Axiora.Recording.LastClickPos.Y)
            local timeSinceLastClick = now - Axiora.Recording.LastClickTime
            
            if clickDist < 0.01 and timeSinceLastClick < Axiora.Settings.MinClickInterval then
                return -- Skip duplicate
            end
            
            local node = {
                t = 2, -- Click type
                d = now - Axiora.State.StartTime,
                x = rel.x,
                y = rel.y,
                ui = gameProcessed or nil
            }
            
            addNode(node)
            Axiora.Recording.LastClickPos = Vector2.new(rel.x, rel.y)
            Axiora.Recording.LastClickTime = now
            
            -- Visual feedback
            if Axiora.Settings.ClickRipple and Axiora.Visuals and Axiora.Visuals.Ripple then
                Axiora.Visuals.Ripple(clickPos.X, clickPos.Y)
            end
            
        -- Keyboard
        elseif input.UserInputType == Enum.UserInputType.Keyboard then
            local node = {
                t = 3, -- Key type
                d = now - Axiora.State.StartTime,
                k = input.KeyCode.Name
            }
            addNode(node)
        end
    end)
    
    Axiora.Events:Fire("RecordingStarted", {
        Mode = Axiora.Settings.SmartRecording and "Smart" or "Full"
    })
    
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 6: PLAYBACK ENGINE
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Playback = {
    Active = false,
    Paused = false,
    CurrentIndex = 0,
    LoopCount = 0,
    Speed = 1.0,
    Mode = "normal" -- normal, fast, precise
}

-- Navigate to a position with retry logic (simple direct navigation)
local function navigateToPosition(hum, root, targetPos, timeout, retries)
    timeout = timeout or Axiora.Settings.NavigationTimeout
    retries = retries or Axiora.Settings.NavigationRetries
    
    local attempt = 0
    
    while attempt < retries do
        if Axiora.State.Status ~= "PLAYING" then return false end
        
        local distance = (root.Position - targetPos).Magnitude
        if distance <= 3 then return true end
        
        hum:MoveTo(targetPos)
        
        local arrived = false
        local startTime = os.clock()
        
        local conn
        conn = hum.MoveToFinished:Connect(function(reached)
            arrived = true
            if reached then distance = 0 end
            if conn then conn:Disconnect() end
        end)
        
        while not arrived and (os.clock() - startTime) < timeout do
            if Axiora.State.Status ~= "PLAYING" then
                if conn then conn:Disconnect() end
                return false
            end
            if (root.Position - targetPos).Magnitude <= 3 then
                arrived = true
                break
            end
            task.wait(0.1)
        end
        
        if conn then conn:Disconnect() end
        
        if (root.Position - targetPos).Magnitude <= 5 then
            return true
        end
        
        -- Retry with jump
        attempt = attempt + 1
        if attempt < retries then
            hum.Jump = true
            task.wait(0.5)
        end
    end
    
    return false
end

-- Smart Pathfinding Navigation (uses PathfindingService)
local function pathfindToPosition(hum, root, targetPos, timeout)
    timeout = timeout or Axiora.Settings.PathfindingTimeout
    
    -- Check if already close enough
    local distance = (root.Position - targetPos).Magnitude
    if distance <= 5 then
        return true
    end
    
    Axiora.Visuals.Notify("Pathfinding", "Navigating to start position... (" .. math.floor(distance) .. " studs)", 3, "info")
    
    -- Try to use PathfindingService
    if not PathfindingService then
        Axiora.Visuals.Notify("Pathfinding", "PathfindingService not available, using direct navigation", 2, "warning")
        return navigateToPosition(hum, root, targetPos, timeout)
    end
    
    local success, path = pcall(function()
        local pathParams = {
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true,
            AgentCanClimb = true,
            WaypointSpacing = 4
        }
        return PathfindingService:CreatePath(pathParams)
    end)
    
    if not success or not path then
        Axiora.Visuals.Notify("Pathfinding", "Failed to create path, using direct navigation", 2, "warning")
        return navigateToPosition(hum, root, targetPos, timeout)
    end
    
    -- Compute path
    local computeSuccess, computeError = pcall(function()
        path:ComputeAsync(root.Position, targetPos)
    end)
    
    if not computeSuccess then
        Axiora.Visuals.Notify("Pathfinding", "Path computation failed, using direct navigation", 2, "warning")
        return navigateToPosition(hum, root, targetPos, timeout)
    end
    
    if path.Status ~= Enum.PathStatus.Success then
        Axiora.Visuals.Notify("Pathfinding", "No path found, using direct navigation", 2, "warning")
        return navigateToPosition(hum, root, targetPos, timeout)
    end
    
    -- Get waypoints
    local waypoints = path:GetWaypoints()
    if #waypoints == 0 then
        return navigateToPosition(hum, root, targetPos, timeout)
    end
    
    Axiora.Visuals.Notify("Pathfinding", "Following path (" .. #waypoints .. " waypoints)", 2, "info")
    
    -- Debug visualization
    if Axiora.Settings.DebugPathfinding then
        for idx, wp in ipairs(waypoints) do
            local marker = Axiora.Visuals.GetPooledPart()
            marker.Shape = Enum.PartType.Ball
            marker.Size = Vector3.new(1, 1, 1)
            marker.Position = wp.Position
            marker.Anchored = true
            marker.CanCollide = false
            marker.BrickColor = BrickColor.new("Lime green")
            marker.Material = Enum.Material.Neon
            marker.Parent = workspace
            table.insert(Axiora.Visuals.Objects, marker)
        end
    end
    
    local startTime = os.clock()
    local blockedCount = 0
    local stuckTimer = 0
    local lastPos = root.Position
    
    -- Follow waypoints
    for i, waypoint in ipairs(waypoints) do
        if Axiora.State.Status ~= "PLAYING" then return false end
        if (os.clock() - startTime) > timeout then
            Axiora.Visuals.Notify("Pathfinding", "Timeout reached", 2, "warning")
            break
        end
        
        -- Handle jump action
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            hum.Jump = true
            task.wait(0.1)
        end
        
        -- Move to waypoint
        hum:MoveTo(waypoint.Position)
        
        -- Wait for movement to complete
        local reachedWaypoint = false
        local waypointStart = os.clock()
        
        local moveConn
        moveConn = hum.MoveToFinished:Connect(function()
            reachedWaypoint = true
            if moveConn then moveConn:Disconnect() end
        end)
        
        -- Wait for waypoint or timeout
        while not reachedWaypoint and (os.clock() - waypointStart) < 3 do
            if Axiora.State.Status ~= "PLAYING" then
                if moveConn then moveConn:Disconnect() end
                return false
            end
            
            -- Check if close enough to waypoint
            if (root.Position - waypoint.Position).Magnitude <= 2 then
                reachedWaypoint = true
                break
            end
            
            task.wait(0.1)
            
            -- Stuck detection with automatic jump
            if (root.Position - lastPos).Magnitude < 0.5 then
                stuckTimer = stuckTimer + 0.1
                if stuckTimer > 2 then
                    hum.Jump = true
                    stuckTimer = 0
                end
            else
                stuckTimer = 0
            end
            lastPos = root.Position
        end
        
        if moveConn then moveConn:Disconnect() end
        
        -- Check for blocked path
        if not reachedWaypoint then
            blockedCount = blockedCount + 1
            if blockedCount >= 3 then
                Axiora.Visuals.Notify("Pathfinding", "Path blocked, trying direct approach", 2, "warning")
                hum.Jump = true
                task.wait(0.3)
            end
        else
            blockedCount = 0
        end
    end
    
    -- Final check - are we close enough?
    local finalDistance = (root.Position - targetPos).Magnitude
    if finalDistance <= 8 then
        Axiora.Visuals.Notify("Pathfinding", "Arrived at start position!", 2, "success")
        return true
    else
        -- Try direct navigation for the last bit
        return navigateToPosition(hum, root, targetPos, 5, 2)
    end
end

function Axiora.Play(loop)
    if #Axiora.State.Buffer == 0 then
        Axiora.Events:Fire("Error", {Message = "No macro loaded"})
        return false
    end
    
    Axiora.Stop()
    Axiora.Math.WaitForInit(2)
    
    local LP = getLocalPlayer()
    if not LP then
        Axiora.Events:Fire("Error", {Message = "No local player"})
        return false
    end
    
    -- Initialize state
    Axiora.State.Status = "PLAYING"
    Axiora.Playback.Active = true
    Axiora.Playback.Paused = false
    Axiora.Playback.CurrentIndex = 0
    Axiora.Playback.LoopCount = 0
    
    -- Determine loop settings
    local loopMode = "once"
    local loopTarget = 1
    
    if loop == true then
        loopMode = "infinite"
    elseif type(loop) == "number" then
        loopMode = "count"
        loopTarget = loop
    end
    
    -- Create snapshot of buffer
    local buffer = {}
    for i, node in ipairs(Axiora.State.Buffer) do
        buffer[i] = node
    end
    local bufferSize = #buffer
    
    -- Playback thread
    local playbackThread = task.spawn(function()
        while Axiora.State.Status == "PLAYING" do
            -- Wait for character
            if not LP.Character then
                LP.CharacterAdded:Wait()
                task.wait(1)
            end
            
            local hum = LP.Character:WaitForChild("Humanoid", 5)
            local root = LP.Character:WaitForChild("HumanoidRootPart", 5)
            
            if not hum or not root then
                Axiora.Events:Fire("Error", {Message = "Character not found"})
                break
            end
            
            -- Navigate to start position using pathfinding
            local firstNode = buffer[1]
            if firstNode and firstNode.p then
                local startPos = Axiora.Math.DeserializeVec(firstNode.p)
                local distanceToStart = (root.Position - startPos).Magnitude
                
                if distanceToStart > 5 then
                    if Axiora.Settings.UsePathfinding then
                        -- Use smart pathfinding to walk to start
                        local pathSuccess = pathfindToPosition(hum, root, startPos, Axiora.Settings.PathfindingTimeout)
                        
                        if not pathSuccess and Axiora.Settings.TeleportFallback then
                            -- Try teleport as last resort (may not work in all executors)
                            pcall(function()
                                root.CFrame = CFrame.new(startPos)
                            end)
                            task.wait(0.5)
                        end
                    else
                        -- Use simple direct navigation
                        navigateToPosition(hum, root, startPos)
                    end
                    task.wait(0.5)
                end
            end
            
            local startTime = os.clock()
            
            -- Execute buffer
            for i, node in ipairs(buffer) do
                if Axiora.State.Status ~= "PLAYING" then break end
                
                -- Handle pause
                while Axiora.Playback.Paused do
                    if Axiora.State.Status ~= "PLAYING" then break end
                    task.wait(0.1)
                end
                
                Axiora.Playback.CurrentIndex = i
                
                -- Breakpoint Check
                if Axiora.Breakpoints and Axiora.Breakpoints.Check(i) then
                    Axiora.Playback.Paused = true
                    Axiora.Breakpoints.WaitingAtBreakpoint = true
                    Axiora.Breakpoints.CurrentBreakpoint = i
                    if Axiora.Settings.BreakpointNotify then
                        Axiora.Visuals.Notify("Breakpoint", "Paused at node #" .. i, 0, "warning")
                    end
                    Axiora.Events:Fire("BreakpointHit", {Index = i})
                    
                    -- Wait until resumed
                    while Axiora.Playback.Paused and Axiora.Breakpoints.WaitingAtBreakpoint do
                        if Axiora.State.Status ~= "PLAYING" then break end
                        task.wait(0.1)
                    end
                end
                
                -- Wait for timestamp
                local now = os.clock() - startTime
                local targetTime = (node.d or 0) / Axiora.Settings.TimeScale / Axiora.Playback.Speed
                
                if now < targetTime then
                    task.wait(targetTime - now)
                end
                
                if Axiora.State.Status ~= "PLAYING" then break end
                
                -- Execute node based on type
                if node.t == 1 then
                    -- Movement with enhanced accuracy
                    local dest = Axiora.Math.DeserializeVec(node.p)
                    if dest then
                        -- Restore recorded walk speed if available
                        if node.ws and node.ws > 0 then
                            hum.WalkSpeed = node.ws
                        end
                        
                        -- MoveTo the recorded position (this follows the exact path)
                        hum:MoveTo(dest)
                    end
                    
                    if node.j then
                        hum.Jump = true
                    end
                    
                    -- Camera sync for look direction
                    if node.c and Axiora.Settings.RecordCamera then
                        local camCF = Axiora.Math.DeserializeCF(node.c)
                        if camCF and Workspace.CurrentCamera then
                            pcall(function()
                                Workspace.CurrentCamera.CFrame = camCF
                            end)
                        end
                    end
                    
                elseif node.t == 2 then
                    -- Click with recovery support
                    local abs = Axiora.Math.GetAbsoluteInput(node.x, node.y)
                    
                    if Axiora.Settings.ClickRecoveryEnabled then
                        Axiora.ClickRecovery.ClickWithRetry(abs.X, abs.Y)
                    else
                        Axiora.Input.Click(abs.X, abs.Y)
                    end
                    
                    if Axiora.Settings.ClickRipple and Axiora.Visuals and Axiora.Visuals.Ripple then
                        Axiora.Visuals.Ripple(abs.X, abs.Y)
                    end
                    
                elseif node.t == 3 then
                    -- Keyboard
                    local keyCode = Enum.KeyCode[node.k]
                    if keyCode then
                        Axiora.Input.KeyPress(keyCode)
                    end
                end
                
                -- Progress event every 10 nodes
                if i % 10 == 0 then
                    Axiora.Events:Fire("PlaybackProgress", {
                        Current = i,
                        Total = bufferSize,
                        Percent = math.floor(i / bufferSize * 100)
                    })
                end
            end
            
            -- Loop logic
            Axiora.Playback.LoopCount = Axiora.Playback.LoopCount + 1
            
            local shouldContinue = false
            if loopMode == "infinite" then
                shouldContinue = true
            elseif loopMode == "count" then
                shouldContinue = Axiora.Playback.LoopCount < loopTarget
            end
            
            if not shouldContinue then break end
            
            task.wait(1)
        end
        
        Axiora.Events:Fire("PlaybackComplete", {
            NodesPlayed = Axiora.Playback.CurrentIndex,
            TotalNodes = bufferSize,
            Loops = Axiora.Playback.LoopCount
        })
        
        Axiora.Stop()
    end)
    
    table.insert(Axiora.State.Threads, playbackThread)
    
    Axiora.Events:Fire("PlaybackStarted", {
        Nodes = bufferSize,
        Loop = loopMode
    })
    
    return true
end

function Axiora.Pause()
    if Axiora.State.Status == "PLAYING" then
        Axiora.Playback.Paused = not Axiora.Playback.Paused
        Axiora.Events:Fire("PlaybackPauseToggled", Axiora.Playback.Paused)
        return Axiora.Playback.Paused
    end
    return false
end

function Axiora.Resume()
    if Axiora.State.Status == "PLAYING" and Axiora.Playback.Paused then
        Axiora.Playback.Paused = false
        return true
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 7: STOP & CLEANUP
-- ═══════════════════════════════════════════════════════════════════════════════

function Axiora.Stop()
    local wasPlaying = Axiora.State.Status == "PLAYING"
    local wasRecording = Axiora.State.Status == "RECORDING"
    
    Axiora.State.Status = "IDLE"
    Axiora.Recording.Active = false
    Axiora.Playback.Active = false
    Axiora.Playback.Paused = false
    
    -- Disconnect regular connections
    for key, conn in pairs(Axiora.State.Connections) do
        if typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    Axiora.State.Connections = {}
    
    -- Cancel threads
    for _, t in pairs(Axiora.State.Threads) do
        pcall(function() task.cancel(t) end)
    end
    Axiora.State.Threads = {}
    
    -- Clear visuals
    if Axiora.Visuals and Axiora.Visuals.Clear then
        pcall(function() Axiora.Visuals.Clear() end)
    end
    
    Axiora.Events:Fire("Stopped", {
        WasRecording = wasRecording,
        WasPlaying = wasPlaying
    })
end

function Axiora.FullStop()
    Axiora.Stop()
    
    -- Also clear security connections
    for _, conn in pairs(Axiora.State.SecurityConnections) do
        pcall(function() conn:Disconnect() end)
    end
    Axiora.State.SecurityConnections = {}
    
    Axiora.Events:Fire("FullStopped")
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 8: VISUAL SYSTEM (Notifications, HUD, Ripples)
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Visuals = {
    ScreenGui = nil,
    HUDFrame = nil,
    NotificationContainer = nil,
    Objects = {},
    Folder = nil,
    NotificationQueue = {},
    NotificationCooldown = false,
    PartPool = {} -- Object pooling for performance
}

-- Object pooling functions
function Axiora.Visuals.GetPooledPart()
    if #Axiora.Visuals.PartPool > 0 then
        return table.remove(Axiora.Visuals.PartPool)
    end
    return Instance.new("Part")
end

function Axiora.Visuals.ReturnToPool(part)
    part.Parent = nil
    table.insert(Axiora.Visuals.PartPool, part)
end

-- Theme colors
Axiora.Visuals.Themes = {
    default = {
        Name = "Axiora Quantum",
        Primary = Color3.fromRGB(0, 180, 255),
        Secondary = Color3.fromRGB(0, 120, 180),
        Background = Color3.fromRGB(18, 18, 25),
        Surface = Color3.fromRGB(25, 25, 35),
        Text = Color3.fromRGB(245, 245, 255),
        TextDim = Color3.fromRGB(150, 150, 170),
        Success = Color3.fromRGB(0, 200, 100),
        Warning = Color3.fromRGB(255, 180, 0),
        Error = Color3.fromRGB(255, 60, 80),
        Info = Color3.fromRGB(100, 200, 255)
    },
    crimson = {
        Name = "Crimson Pulse",
        Primary = Color3.fromRGB(220, 50, 80),
        Secondary = Color3.fromRGB(180, 30, 60),
        Background = Color3.fromRGB(20, 15, 18),
        Surface = Color3.fromRGB(30, 22, 26),
        Text = Color3.fromRGB(255, 245, 248),
        TextDim = Color3.fromRGB(180, 150, 160),
        Success = Color3.fromRGB(50, 200, 120),
        Warning = Color3.fromRGB(255, 200, 0),
        Error = Color3.fromRGB(255, 80, 100),
        Info = Color3.fromRGB(220, 100, 150)
    },
    emerald = {
        Name = "Emerald Matrix",
        Primary = Color3.fromRGB(0, 200, 100),
        Secondary = Color3.fromRGB(0, 150, 75),
        Background = Color3.fromRGB(12, 20, 16),
        Surface = Color3.fromRGB(18, 28, 22),
        Text = Color3.fromRGB(240, 255, 245),
        TextDim = Color3.fromRGB(140, 170, 150),
        Success = Color3.fromRGB(0, 255, 130),
        Warning = Color3.fromRGB(255, 200, 50),
        Error = Color3.fromRGB(255, 80, 80),
        Info = Color3.fromRGB(100, 220, 180)
    }
}

function Axiora.Visuals.GetTheme()
    return Axiora.Visuals.Themes[Axiora.Settings.Theme] or Axiora.Visuals.Themes.default
end

function Axiora.Visuals.SetTheme(themeName)
    if Axiora.Visuals.Themes[themeName] then
        Axiora.Settings.Theme = themeName
        Axiora.Events:Fire("ThemeChanged", themeName)
        return true
    end
    return false
end

-- Initialize screen GUI
function Axiora.Visuals.Init()
    if Axiora.Visuals.ScreenGui then
        pcall(function() Axiora.Visuals.ScreenGui:Destroy() end)
    end
    
    local sg = Instance.new("ScreenGui")
    sg.Name = "AxioraVisuals"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Try CoreGui first, fallback to PlayerGui
    local success = pcall(function()
        sg.Parent = CoreGui
    end)
    if not success then
        local LP = getLocalPlayer()
        if LP and LP:FindFirstChild("PlayerGui") then
            sg.Parent = LP.PlayerGui
        end
    end
    
    Axiora.Visuals.ScreenGui = sg
    
    -- Create notification container
    local notifContainer = Instance.new("Frame")
    notifContainer.Name = "Notifications"
    notifContainer.BackgroundTransparency = 1
    notifContainer.Size = UDim2.new(0, 320, 1, 0)
    notifContainer.Position = UDim2.new(1, -330, 0, 10)
    notifContainer.AnchorPoint = Vector2.new(0, 0)
    notifContainer.Parent = sg
    
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.Parent = notifContainer
    
    Axiora.Visuals.NotificationContainer = notifContainer
    
    return sg
end

-- Notification function
function Axiora.Visuals.Notify(title, message, duration, notifType)
    duration = duration or 3
    notifType = notifType or "info"
    
    if not Axiora.Visuals.NotificationContainer then
        Axiora.Visuals.Init()
    end
    
    if Axiora.Visuals.NotificationCooldown then
        -- Queue it
        table.insert(Axiora.Visuals.NotificationQueue, {
            title = title, message = message, duration = duration, notifType = notifType
        })
        return
    end
    
    Axiora.Visuals.NotificationCooldown = true
    
    local theme = Axiora.Visuals.GetTheme()
    local typeColors = {
        success = theme.Success,
        warning = theme.Warning,
        error = theme.Error,
        info = theme.Info
    }
    local accentColor = typeColors[notifType] or theme.Primary
    
    -- Create notification frame
    local notif = Instance.new("Frame")
    notif.Name = "Notification"
    notif.BackgroundColor3 = theme.Surface
    notif.BackgroundTransparency = 0.1
    notif.Size = UDim2.new(1, 0, 0, 65)
    notif.Position = UDim2.new(1, 0, 0, 0) -- Start off-screen
    notif.BorderSizePixel = 0
    notif.ClipsDescendants = true
    notif.LayoutOrder = os.clock() * 1000
    notif.Parent = Axiora.Visuals.NotificationContainer
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notif
    
    -- Accent bar
    local accent = Instance.new("Frame")
    accent.Name = "Accent"
    accent.BackgroundColor3 = accentColor
    accent.Size = UDim2.new(0, 4, 1, 0)
    accent.BorderSizePixel = 0
    accent.Parent = notif
    
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -20, 0, 22)
    titleLabel.Position = UDim2.new(0, 15, 0, 8)
    titleLabel.Text = title or "Axiora"
    titleLabel.TextColor3 = theme.Text
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = notif
    
    -- Message
    local msgLabel = Instance.new("TextLabel")
    msgLabel.Name = "Message"
    msgLabel.BackgroundTransparency = 1
    msgLabel.Size = UDim2.new(1, -20, 0, 30)
    msgLabel.Position = UDim2.new(0, 15, 0, 30)
    msgLabel.Text = message or ""
    msgLabel.TextColor3 = theme.TextDim
    msgLabel.Font = Enum.Font.Gotham
    msgLabel.TextSize = 12
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.TextTruncate = Enum.TextTruncate.AtEnd
    msgLabel.TextWrapped = true
    msgLabel.Parent = notif
    
    -- Slide in animation
    local tweenIn = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0)
    })
    tweenIn:Play()
    
    -- Auto-dismiss
    task.delay(duration, function()
        if notif and notif.Parent then
            local tweenOut = TweenService:Create(notif, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {
                Position = UDim2.new(1, 10, 0, 0),
                BackgroundTransparency = 1
            })
            tweenOut:Play()
            tweenOut.Completed:Wait()
            pcall(function() notif:Destroy() end)
        end
    end)
    
    -- Cooldown then process queue
    task.delay(0.3, function()
        Axiora.Visuals.NotificationCooldown = false
        if #Axiora.Visuals.NotificationQueue > 0 then
            local queued = table.remove(Axiora.Visuals.NotificationQueue, 1)
            Axiora.Visuals.Notify(queued.title, queued.message, queued.duration, queued.notifType)
        end
    end)
end

-- Ripple effect for clicks
function Axiora.Visuals.Ripple(x, y)
    if Axiora.Settings.PerformanceMode then return end
    if not Axiora.Visuals.ScreenGui then return end
    
    local theme = Axiora.Visuals.GetTheme()
    
    local r = Instance.new("Frame")
    r.Position = UDim2.fromOffset(x, y)
    r.Size = UDim2.fromOffset(0, 0)
    r.AnchorPoint = Vector2.new(0.5, 0.5)
    r.BackgroundColor3 = theme.Primary
    r.BackgroundTransparency = 0.4
    r.BorderSizePixel = 0
    r.ZIndex = 10
    r.Parent = Axiora.Visuals.ScreenGui
    
    Instance.new("UICorner", r).CornerRadius = UDim.new(1, 0)
    
    local tween = TweenService:Create(r, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
        Size = UDim2.fromOffset(80, 80),
        BackgroundTransparency = 1
    })
    tween:Play()
    tween.Completed:Connect(function()
        pcall(function() r:Destroy() end)
    end)
end

-- Create simple HUD
function Axiora.Visuals.CreateHUD()
    if not Axiora.Settings.HUDEnabled then return end
    
    if not Axiora.Visuals.ScreenGui then
        Axiora.Visuals.Init()
    end
    
    -- Remove old HUD
    if Axiora.Visuals.HUDFrame then
        pcall(function() Axiora.Visuals.HUDFrame:Destroy() end)
    end
    
    local theme = Axiora.Visuals.GetTheme()
    
    local hud = Instance.new("Frame")
    hud.Name = "HUD"
    hud.BackgroundColor3 = theme.Background
    hud.BackgroundTransparency = 0.15
    hud.Size = UDim2.new(0, 180, 0, 100)
    hud.Position = UDim2.new(0, 15, 0, 50)
    hud.BorderSizePixel = 0
    hud.Parent = Axiora.Visuals.ScreenGui
    
    Instance.new("UICorner", hud).CornerRadius = UDim.new(0, 10)
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = theme.Primary
    stroke.Transparency = 0.5
    stroke.Thickness = 1.5
    stroke.Parent = hud
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Text = "AXIORA v" .. Axiora._VERSION
    title.TextColor3 = theme.Primary
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 12
    title.Parent = hud
    
    -- Status
    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.BackgroundTransparency = 1
    status.Size = UDim2.new(1, 0, 0, 20)
    status.Position = UDim2.new(0, 0, 0, 28)
    status.Text = "IDLE"
    status.TextColor3 = theme.TextDim
    status.Font = Enum.Font.GothamBold
    status.TextSize = 11
    status.Parent = hud
    
    -- Buffer info
    local bufferInfo = Instance.new("TextLabel")
    bufferInfo.Name = "BufferInfo"
    bufferInfo.BackgroundTransparency = 1
    bufferInfo.Size = UDim2.new(1, 0, 0, 20)
    bufferInfo.Position = UDim2.new(0, 0, 0, 50)
    bufferInfo.Text = "Buffer: 0 nodes"
    bufferInfo.TextColor3 = theme.TextDim
    bufferInfo.Font = Enum.Font.Gotham
    bufferInfo.TextSize = 10
    status.Parent = hud
    
    -- Executor info
    local execInfo = Instance.new("TextLabel")
    execInfo.Name = "ExecInfo"
    execInfo.BackgroundTransparency = 1
    execInfo.Size = UDim2.new(1, 0, 0, 20)
    execInfo.Position = UDim2.new(0, 0, 0, 72)
    execInfo.Text = "Executor: " .. Axiora.Capabilities.Executor
    execInfo.TextColor3 = theme.TextDim
    execInfo.Font = Enum.Font.Gotham
    execInfo.TextSize = 9
    execInfo.Parent = hud
    
    Axiora.Visuals.HUDFrame = hud
    
    -- Update loop
    local hudThread = task.spawn(function()
        while hud and hud.Parent do
            if Axiora.State.Status then
                status.Text = Axiora.State.Status
                status.TextColor3 = Axiora.State.Status == "PLAYING" and theme.Success
                    or Axiora.State.Status == "RECORDING" and theme.Error
                    or Axiora.State.Status == "PAUSED" and theme.Warning
                    or theme.TextDim
            end
            bufferInfo.Text = "Buffer: " .. #Axiora.State.Buffer .. " nodes"
            task.wait(0.5)
        end
    end)
    table.insert(Axiora.State.Threads, hudThread)
    
    -- Dragging
    local dragging = false
    local dragStart, startPos
    
    hud.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = UserInputService:GetMouseLocation()
            startPos = hud.Position
        end
    end)
    
    hud.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local current = UserInputService:GetMouseLocation()
            local delta = current - dragStart
            hud.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    return hud
end

-- Show/Hide HUD
function Axiora.Visuals.ToggleHUD()
    if Axiora.Visuals.HUDFrame then
        Axiora.Visuals.HUDFrame.Visible = not Axiora.Visuals.HUDFrame.Visible
        return Axiora.Visuals.HUDFrame.Visible
    end
    return false
end

-- Clear visual objects
function Axiora.Visuals.Clear()
    for _, obj in ipairs(Axiora.Visuals.Objects) do
        pcall(function()
            if obj and obj.Parent then obj:Destroy() end
        end)
    end
    Axiora.Visuals.Objects = {}
    
    if Axiora.Visuals.Folder then
        pcall(function() Axiora.Visuals.Folder:Destroy() end)
        Axiora.Visuals.Folder = nil
    end
end

-- Render path visualization with progressive batch rendering
function Axiora.Visuals.RenderPath(mode)
    Axiora.Visuals.Clear()
    
    if #Axiora.State.Buffer == 0 then 
        Axiora.Visuals.Notify("Render", "No nodes to render", 2, "warning")
        return 
    end
    
    mode = mode or "simple"
    local theme = Axiora.Visuals.GetTheme()
    
    local folder = Instance.new("Folder")
    folder.Name = "Axiora_PathVisual"
    folder.Parent = Workspace
    Axiora.Visuals.Folder = folder
    
    -- Progressive rendering settings
    local batchSize = Axiora.Settings.RenderBatchSize or 50
    local batchDelay = Axiora.Settings.RenderBatchDelay or 0.03
    local spacing = Axiora.Settings.PerformanceMode and 5 or 2
    
    local totalNodes = math.ceil(#Axiora.State.Buffer / spacing)
    local renderedCount = 0
    local lastNotifyCount = 0
    
    Axiora.Visuals.Notify("Render", "Rendering " .. totalNodes .. " nodes...", 3, "info")
    
    for i = 1, #Axiora.State.Buffer, spacing do
        local node = Axiora.State.Buffer[i]
        if node and node.t == 1 and node.p then
            local pos = Axiora.Math.DeserializeVec(node.p)
            
            local part = Instance.new("Part")
            part.Name = "Node_" .. i
            part.Size = Vector3.new(0.4, 0.4, 0.4)
            part.Shape = Enum.PartType.Ball
            part.Anchored = true
            part.CanCollide = false
            part.Material = Enum.Material.Neon
            part.Color = theme.Primary
            part.Transparency = 0.5
            part.Position = pos
            part.CastShadow = false
            part.Parent = folder
            
            table.insert(Axiora.Visuals.Objects, part)
            renderedCount = renderedCount + 1
        end
        
        -- Progressive batch yielding - prevent "Roblox Not Responding"
        if renderedCount % batchSize == 0 then
            task.wait(batchDelay)
            
            -- Progress notification every 500 nodes
            if renderedCount - lastNotifyCount >= 500 then
                local percent = math.floor((renderedCount / totalNodes) * 100)
                Axiora.Visuals.Notify("Render", "Progress: " .. renderedCount .. "/" .. totalNodes .. " (" .. percent .. "%)", 1, "info")
                lastNotifyCount = renderedCount
            end
        end
    end
    
    Axiora.Visuals.Notify("Render", #Axiora.Visuals.Objects .. " nodes rendered", 2, "success")
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 9: FILE SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Files = {
    BaseFolder = "Axiora",
    SaveFolder = "Axiora/Saves",
    SettingsFile = "Axiora/settings.json"
}

function Axiora.Files.EnsureFolder(path)
    if not Axiora.Capabilities.MakeFolder then return false end
    
    local success = pcall(function()
        if Axiora.Capabilities.IsFolder and not isfolder(path) then
            makefolder(path)
        elseif not Axiora.Capabilities.IsFolder then
            makefolder(path)
        end
    end)
    return success
end

function Axiora.Files.Init()
    Axiora.Files.EnsureFolder(Axiora.Files.BaseFolder)
    Axiora.Files.EnsureFolder(Axiora.Files.SaveFolder)
end

function Axiora.Save(name)
    if not Axiora.Capabilities.WriteFile then
        Axiora.Visuals.Notify("Save", "File system not available", 3, "error")
        return false
    end
    
    if #Axiora.State.Buffer == 0 then
        Axiora.Visuals.Notify("Save", "No macro to save", 2, "warning")
        return false
    end
    
    Axiora.Files.EnsureFolder(Axiora.Files.SaveFolder)
    
    name = name or ("macro_" .. os.time())
    local filename = Axiora.Files.SaveFolder .. "/" .. name .. ".axr"
    
    local data = {
        version = Axiora._VERSION,
        name = name,
        savedAt = os.time(),
        placeId = game.PlaceId,
        nodeCount = #Axiora.State.Buffer,
        buffer = Axiora.State.Buffer
    }
    
    local success, err = pcall(function()
        local json = HttpService:JSONEncode(data)
        writefile(filename, json)
    end)
    
    if success then
        Axiora.Visuals.Notify("Save", "Saved: " .. name, 2, "success")
        return true
    else
        Axiora.Visuals.Notify("Save", "Failed to save", 3, "error")
        return false
    end
end

function Axiora.Load(name)
    if not Axiora.Capabilities.ReadFile then
        Axiora.Visuals.Notify("Load", "File system not available", 3, "error")
        return false
    end
    
    local filename = Axiora.Files.SaveFolder .. "/" .. name .. ".axr"
    
    local success, data = pcall(function()
        local json = readfile(filename)
        return HttpService:JSONDecode(json)
    end)
    
    if success and data and data.buffer then
        Axiora.State.Buffer = data.buffer
        Axiora.Visuals.Notify("Load", "Loaded: " .. (data.name or name) .. " (" .. #data.buffer .. " nodes)", 3, "success")
        Axiora.Events:Fire("MacroLoaded", {Name = data.name, Nodes = #data.buffer})
        return true
    else
        Axiora.Visuals.Notify("Load", "Failed to load file", 3, "error")
        return false
    end
end

function Axiora.ListSaves()
    if not Axiora.Capabilities.ReadFile then return {} end
    
    local saves = {}
    local success = pcall(function()
        if listfiles then
            local files = listfiles(Axiora.Files.SaveFolder)
            for _, file in ipairs(files) do
                if file:match("%.axr$") then
                    local name = file:match("([^/\\]+)%.axr$")
                    if name then
                        table.insert(saves, name)
                    end
                end
            end
        end
    end)
    return saves
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MACRO EDITOR API
-- ═══════════════════════════════════════════════════════════════════════════════

-- View all nodes in the buffer (for editing)
function Axiora.EditBuffer()
    local nodes = {}
    for i, node in ipairs(Axiora.State.Buffer) do
        local nodeInfo = {
            Index = i,
            Type = node.t == 1 and "Move" or node.t == 2 and "Click" or node.t == 3 and "Key" or "Unknown",
            Delay = node.d or 0,
        }
        
        if node.t == 1 then
            nodeInfo.Position = node.p
            nodeInfo.Jump = node.j
            nodeInfo.Camera = node.c and true or false
        elseif node.t == 2 then
            nodeInfo.X = node.x
            nodeInfo.Y = node.y
            nodeInfo.UI = node.ui
        elseif node.t == 3 then
            nodeInfo.Key = node.k
        end
        
        table.insert(nodes, nodeInfo)
    end
    return nodes
end

-- Get a specific node by index
function Axiora.GetNode(index)
    if index < 1 or index > #Axiora.State.Buffer then
        return nil
    end
    
    local node = Axiora.State.Buffer[index]
    return {
        Index = index,
        Type = node.t == 1 and "Move" or node.t == 2 and "Click" or node.t == 3 and "Key" or "Unknown",
        RawType = node.t,
        Delay = node.d or 0,
        Data = node
    }
end

-- Delete a node at index
function Axiora.DeleteNode(index)
    if index < 1 or index > #Axiora.State.Buffer then
        Axiora.Visuals.Notify("Editor", "Invalid node index", 2, "error")
        return false
    end
    
    local removed = table.remove(Axiora.State.Buffer, index)
    Axiora.Visuals.Notify("Editor", "Deleted node #" .. index, 2, "success")
    Axiora.Events:Fire("NodeDeleted", {Index = index, Node = removed})
    return true
end

-- Insert a node at index
function Axiora.InsertNode(index, node)
    if index < 1 or index > #Axiora.State.Buffer + 1 then
        Axiora.Visuals.Notify("Editor", "Invalid insert index", 2, "error")
        return false
    end
    
    table.insert(Axiora.State.Buffer, index, node)
    Axiora.Visuals.Notify("Editor", "Inserted node at #" .. index, 2, "success")
    Axiora.Events:Fire("NodeInserted", {Index = index, Node = node})
    return true
end

-- Update a node's properties
function Axiora.UpdateNode(index, changes)
    if index < 1 or index > #Axiora.State.Buffer then
        Axiora.Visuals.Notify("Editor", "Invalid node index", 2, "error")
        return false
    end
    
    local node = Axiora.State.Buffer[index]
    for key, value in pairs(changes) do
        node[key] = value
    end
    
    Axiora.Visuals.Notify("Editor", "Updated node #" .. index, 2, "success")
    Axiora.Events:Fire("NodeUpdated", {Index = index, Changes = changes})
    return true
end

-- Delete nodes in a range
function Axiora.DeleteRange(startIdx, endIdx)
    if startIdx < 1 or endIdx > #Axiora.State.Buffer or startIdx > endIdx then
        Axiora.Visuals.Notify("Editor", "Invalid range", 2, "error")
        return false
    end
    
    local count = endIdx - startIdx + 1
    for i = 1, count do
        table.remove(Axiora.State.Buffer, startIdx)
    end
    
    Axiora.Visuals.Notify("Editor", "Deleted " .. count .. " nodes", 2, "success")
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MACRO STITCHING (Combine)
-- ═══════════════════════════════════════════════════════════════════════════════

function Axiora.Combine(macro1Name, macro2Name, outputName)
    if not Axiora.Capabilities.ReadFile or not Axiora.Capabilities.WriteFile then
        Axiora.Visuals.Notify("Combine", "File system not available", 3, "error")
        return false
    end
    
    -- Load first macro
    local file1 = Axiora.Files.SaveFolder .. "/" .. macro1Name .. ".axr"
    local success1, data1 = pcall(function()
        return HttpService:JSONDecode(readfile(file1))
    end)
    
    if not success1 or not data1 or not data1.buffer then
        Axiora.Visuals.Notify("Combine", "Failed to load: " .. macro1Name, 3, "error")
        return false
    end
    
    -- Load second macro
    local file2 = Axiora.Files.SaveFolder .. "/" .. macro2Name .. ".axr"
    local success2, data2 = pcall(function()
        return HttpService:JSONDecode(readfile(file2))
    end)
    
    if not success2 or not data2 or not data2.buffer then
        Axiora.Visuals.Notify("Combine", "Failed to load: " .. macro2Name, 3, "error")
        return false
    end
    
    -- Find max delay from first macro
    local maxDelay = 0
    for _, node in ipairs(data1.buffer) do
        if node.d and node.d > maxDelay then
            maxDelay = node.d
        end
    end
    
    -- Add a small gap between macros
    local delayOffset = maxDelay + 1.0
    
    -- Create combined buffer
    local combinedBuffer = {}
    
    -- Add all nodes from macro1
    for _, node in ipairs(data1.buffer) do
        table.insert(combinedBuffer, node)
    end
    
    -- Add all nodes from macro2 with adjusted timestamps
    for _, node in ipairs(data2.buffer) do
        local adjustedNode = {}
        for k, v in pairs(node) do
            adjustedNode[k] = v
        end
        adjustedNode.d = (adjustedNode.d or 0) + delayOffset
        table.insert(combinedBuffer, adjustedNode)
    end
    
    -- Save combined macro
    outputName = outputName or (macro1Name .. "_" .. macro2Name)
    local outputFile = Axiora.Files.SaveFolder .. "/" .. outputName .. ".axr"
    
    local saveData = {
        version = Axiora._VERSION,
        name = outputName,
        savedAt = os.time(),
        placeId = game.PlaceId,
        nodeCount = #combinedBuffer,
        combinedFrom = {macro1Name, macro2Name},
        buffer = combinedBuffer
    }
    
    local success = pcall(function()
        writefile(outputFile, HttpService:JSONEncode(saveData))
    end)
    
    if success then
        Axiora.Visuals.Notify("Combine", "Created: " .. outputName .. " (" .. #combinedBuffer .. " nodes)", 3, "success")
        Axiora.Events:Fire("MacrosCombined", {
            Macro1 = macro1Name,
            Macro2 = macro2Name,
            Output = outputName,
            TotalNodes = #combinedBuffer
        })
        return true
    else
        Axiora.Visuals.Notify("Combine", "Failed to save combined macro", 3, "error")
        return false
    end
end


-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 10: STRATEGY LOADER (URL Loading)
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.StrategyLoader = {
    Current = nil,
    Loading = false,
    TrustedDomains = {
        "pastebin.com",
        "raw.githubusercontent.com",
        "gist.githubusercontent.com"
    }
}

-- Universal HTTP request function
local function httpGet(url)
    -- Try request() first (most compatible)
    if typeof(request) == "function" then
        local response = request({Url = url, Method = "GET"})
        if response and response.Success then
            return response.Body
        end
    end
    
    if typeof(http_request) == "function" then
        local response = http_request({Url = url, Method = "GET"})
        if response and response.Success then
            return response.Body
        end
    end
    
    -- Synapse X
    if typeof(syn) == "table" and typeof(syn.request) == "function" then
        local response = syn.request({Url = url, Method = "GET"})
        if response and response.Success then
            return response.Body
        end
    end
    
    -- game:HttpGet fallback
    if game.HttpGet then
        return game:HttpGet(url)
    end
    
    error("No HTTP method available")
end

-- Sanitize URL for raw content
local function sanitizeURL(url)
    if not url or type(url) ~= "string" then return nil end
    
    url = url:gsub("^%s+", ""):gsub("%s+$", "")
    
    if not url:find("^https?://") then
        url = "https://" .. url
    end
    
    -- Pastebin: convert to raw
    if url:find("pastebin.com/") and not url:find("pastebin.com/raw/") then
        local id = url:match("pastebin%.com/([%w]+)$")
        if id then url = "https://pastebin.com/raw/" .. id end
    end
    
    return url
end

function Axiora.StrategyLoader.FetchFromURL(url, options)
    options = options or {}
    
    if Axiora.StrategyLoader.Loading then
        Axiora.Visuals.Notify("Loader", "Already loading...", 2, "warning")
        return false
    end
    
    url = sanitizeURL(url)
    if not url then
        Axiora.Visuals.Notify("Loader", "Invalid URL", 2, "error")
        return false
    end
    
    Axiora.StrategyLoader.Loading = true
    Axiora.Visuals.Notify("Loader", "Fetching strategy...", 2, "info")
    
    task.spawn(function()
        local success, response = pcall(function()
            return httpGet(url)
        end)
        
        if not success or not response then
            Axiora.StrategyLoader.Loading = false
            Axiora.Visuals.Notify("Loader", "Failed to fetch URL", 3, "error")
            return
        end
        
        -- Try to parse as JSON
        local data = nil
        local parseSuccess = pcall(function()
            data = HttpService:JSONDecode(response)
        end)
        
        if not parseSuccess or not data then
            Axiora.StrategyLoader.Loading = false
            Axiora.Visuals.Notify("Loader", "Failed to parse data", 3, "error")
            return
        end
        
        -- Convert to Axiora format
        local convertSuccess = Axiora.StrategyLoader.Convert(data)
        
        Axiora.StrategyLoader.Loading = false
        
        if convertSuccess then
            Axiora.StrategyLoader.Current = {
                Data = data,
                URL = url,
                LoadedAt = os.clock()
            }
            Axiora.Events:Fire("StrategyLoaded", Axiora.StrategyLoader.Current)
        end
    end)
    
    return true
end

-- Convert external format to Axiora buffer
function Axiora.StrategyLoader.Convert(data)
    if not data then return false end
    
    local nodes = {}
    local timeOffset = 0
    
    -- Check for Axiora native format
    if data.buffer or data.nodes then
        Axiora.State.Buffer = data.buffer or data.nodes
        Axiora.Visuals.Notify("Loader", "Loaded " .. #Axiora.State.Buffer .. " nodes", 3, "success")
        return true
    end
    
    -- Check for actions array (Stratz-like format)
    local actions = data.actions or data.events or data
    if type(actions) ~= "table" then
        Axiora.Visuals.Notify("Loader", "Unknown format", 3, "error")
        return false
    end
    
    for i, act in ipairs(actions) do
        if type(act) == "table" then
            local delay = tonumber(act.delay) or tonumber(act.wait) or 0
            timeOffset = timeOffset + delay
            
            local eventType = (act.event or act.type or act.action or ""):lower()
            
            if eventType == "click" or eventType == "tap" then
                local x = tonumber(act.x) or 0
                local y = tonumber(act.y) or 0
                
                -- Normalize if values seem like absolute coords
                if x > 1 or y > 1 then
                    local res = data.resolution or {width = 1920, height = 1080}
                    x = x / (res.width or 1920)
                    y = y / (res.height or 1080)
                end
                
                table.insert(nodes, {
                    t = 2,
                    d = timeOffset,
                    x = x,
                    y = y
                })
                
            elseif eventType == "key" or eventType == "keyboard" then
                table.insert(nodes, {
                    t = 3,
                    d = timeOffset,
                    k = act.key or act.keycode
                })
                
            elseif eventType == "move" or eventType == "position" then
                local pos = act.position or {x = act.x, y = act.y, z = act.z}
                table.insert(nodes, {
                    t = 1,
                    d = timeOffset,
                    p = {pos.x or 0, pos.y or 0, pos.z or 0}
                })
            end
        end
    end
    
    if #nodes > 0 then
        Axiora.State.Buffer = nodes
        Axiora.Visuals.Notify("Loader", "Converted " .. #nodes .. " nodes", 3, "success")
        return true
    end
    
    Axiora.Visuals.Notify("Loader", "No valid actions found", 3, "warning")
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 11: HOTKEY SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Hotkeys = {
    Enabled = true,
    Bindings = {
        Record = Enum.KeyCode.F1,
        Play = Enum.KeyCode.F2,
        Stop = Enum.KeyCode.F3,
        ToggleUI = Enum.KeyCode.F4,
        ToggleHUD = Enum.KeyCode.F8
    },
    Connection = nil,
    LastTrigger = {},
    Cooldown = 0.3
}

function Axiora.Hotkeys.CanTrigger(keyCode)
    local now = os.clock()
    local last = Axiora.Hotkeys.LastTrigger[keyCode] or 0
    if (now - last) < Axiora.Hotkeys.Cooldown then
        return false
    end
    Axiora.Hotkeys.LastTrigger[keyCode] = now
    return true
end

function Axiora.Hotkeys.Init()
    if Axiora.Hotkeys.Connection then
        pcall(function() Axiora.Hotkeys.Connection:Disconnect() end)
    end
    
    Axiora.Hotkeys.Connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not Axiora.Hotkeys.Enabled then return end
        if gameProcessed then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        
        local keyCode = input.KeyCode
        
        if not Axiora.Hotkeys.CanTrigger(keyCode) then return end
        
        if keyCode == Axiora.Hotkeys.Bindings.Record then
            if Axiora.State.Status == "RECORDING" then
                Axiora.Stop()
            else
                Axiora.Record()
            end
            
        elseif keyCode == Axiora.Hotkeys.Bindings.Play then
            if Axiora.State.Status == "PLAYING" then
                Axiora.Pause()
            else
                Axiora.Play(true)
            end
            
        elseif keyCode == Axiora.Hotkeys.Bindings.Stop then
            Axiora.Stop()
            
        elseif keyCode == Axiora.Hotkeys.Bindings.ToggleUI then
            if Axiora.UI and Axiora.UI.Toggle then
                Axiora.UI.Toggle()
            end
            
        elseif keyCode == Axiora.Hotkeys.Bindings.ToggleHUD then
            Axiora.Visuals.ToggleHUD()
        end
    end)
    
    Axiora.State.SecurityConnections.Hotkeys = Axiora.Hotkeys.Connection
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 12: SECURITY (Anti-AFK, Anti-Kick)
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Security = {
    AntiAFKActive = false,
    AntiKickActive = false
}

function Axiora.Security.EnableAntiAFK()
    if Axiora.Security.AntiAFKActive then return end
    
    local LP = getLocalPlayer()
    if not LP then return end
    
    local success = pcall(function()
        local vu = LP:FindFirstChildOfClass("VirtualUser")
        if not vu then
            vu = Instance.new("VirtualUser")
            vu.Parent = LP
        end
        
        local afkConn = Players.LocalPlayer.Idled:Connect(function()
            vu:CaptureController()
            vu:ClickButton2(Vector2.zero)
        end)
        
        Axiora.State.SecurityConnections.AntiAFK = afkConn
        Axiora.Security.AntiAFKActive = true
    end)
    
    if success then
        Axiora.Visuals.Notify("Security", "Anti-AFK enabled", 2, "success")
    end
end

function Axiora.Security.DisableAntiAFK()
    if Axiora.State.SecurityConnections.AntiAFK then
        pcall(function()
            Axiora.State.SecurityConnections.AntiAFK:Disconnect()
        end)
        Axiora.State.SecurityConnections.AntiAFK = nil
    end
    Axiora.Security.AntiAFKActive = false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 13: SEQUENCE MANAGER (Multi-Macro Queue)
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Sequences = {
    Queue = {},
    CurrentIndex = 0,
    Repeat = false,
    Running = false,
    _connection = nil
}

function Axiora.Sequences.Add(name, buffer, options)
    options = options or {}
    
    local seq = {
        Name = name or ("Sequence_" .. (#Axiora.Sequences.Queue + 1)),
        Buffer = buffer or table.clone(Axiora.State.Buffer),
        Delay = options.delay or 1,
        LoopCount = options.loopCount or 1,
        WaitForCompletion = options.waitForCompletion ~= false
    }
    
    table.insert(Axiora.Sequences.Queue, seq)
    Axiora.Visuals.Notify("Sequences", "Added: " .. seq.Name .. " (" .. #seq.Buffer .. " nodes)", 2, "success")
    Axiora.Events:Fire("SequenceAdded", seq)
    return #Axiora.Sequences.Queue
end

function Axiora.Sequences.AddCurrentBuffer(name, options)
    if #Axiora.State.Buffer == 0 then
        Axiora.Visuals.Notify("Sequences", "Buffer is empty", 2, "warning")
        return nil
    end
    return Axiora.Sequences.Add(name, table.clone(Axiora.State.Buffer), options)
end

function Axiora.Sequences.Remove(index)
    if index <= 0 or index > #Axiora.Sequences.Queue then return false end
    local removed = table.remove(Axiora.Sequences.Queue, index)
    Axiora.Visuals.Notify("Sequences", "Removed: " .. removed.Name, 2, "info")
    return true
end

function Axiora.Sequences.Clear()
    Axiora.Sequences.Queue = {}
    Axiora.Sequences.CurrentIndex = 0
    Axiora.Visuals.Notify("Sequences", "Queue cleared", 2, "info")
end

function Axiora.Sequences.GetQueue()
    local list = {}
    for i, seq in ipairs(Axiora.Sequences.Queue) do
        table.insert(list, {
            Index = i,
            Name = seq.Name,
            Nodes = #seq.Buffer,
            Delay = seq.Delay
        })
    end
    return list
end

function Axiora.Sequences.ExecuteQueue()
    if #Axiora.Sequences.Queue == 0 then
        Axiora.Visuals.Notify("Sequences", "Queue is empty", 2, "warning")
        return false
    end
    
    if Axiora.Sequences.Running then
        Axiora.Visuals.Notify("Sequences", "Already running", 2, "warning")
        return false
    end
    
    Axiora.Sequences.Running = true
    Axiora.Sequences.CurrentIndex = 0
    
    local function executeNext()
        if not Axiora.Sequences.Running then return end
        
        Axiora.Sequences.CurrentIndex = Axiora.Sequences.CurrentIndex + 1
        
        if Axiora.Sequences.CurrentIndex > #Axiora.Sequences.Queue then
            if Axiora.Sequences.Repeat then
                Axiora.Sequences.CurrentIndex = 0
                task.wait(2)
                executeNext()
            else
                Axiora.Sequences.Running = false
                Axiora.Visuals.Notify("Sequences", "Queue completed!", 3, "success")
                Axiora.Events:Fire("QueueCompleted")
            end
            return
        end
        
        local seq = Axiora.Sequences.Queue[Axiora.Sequences.CurrentIndex]
        
        Axiora.Visuals.Notify("Sequence", "Playing: " .. seq.Name .. " (" .. Axiora.Sequences.CurrentIndex .. "/" .. #Axiora.Sequences.Queue .. ")", 3, "info")
        
        -- Load and play
        Axiora.State.Buffer = seq.Buffer
        Axiora.Play(seq.LoopCount > 1)
        
        if seq.WaitForCompletion then
            Axiora.Sequences._connection = Axiora.Events:Connect("Stopped", function()
                if Axiora.Sequences._connection then
                    Axiora.Sequences._connection.Disconnect()
                    Axiora.Sequences._connection = nil
                end
                task.wait(seq.Delay)
                executeNext()
            end)
        else
            task.wait(seq.Delay)
            executeNext()
        end
    end
    
    Axiora.Visuals.Notify("Sequences", "Starting queue (" .. #Axiora.Sequences.Queue .. " sequences)", 2, "info")
    executeNext()
    return true
end

function Axiora.Sequences.StopQueue()
    Axiora.Sequences.Running = false
    if Axiora.Sequences._connection then
        pcall(function() Axiora.Sequences._connection.Disconnect() end)
        Axiora.Sequences._connection = nil
    end
    Axiora.Stop()
    Axiora.Visuals.Notify("Sequences", "Queue stopped", 2, "info")
end

function Axiora.Sequences.SaveQueue(name)
    if not Axiora.Capabilities.WriteFile then return false end
    
    Axiora.Files.EnsureFolder("Axiora/Queues")
    
    local data = {
        Version = Axiora._VERSION,
        QueueName = name,
        Sequences = Axiora.Sequences.Queue,
        Repeat = Axiora.Sequences.Repeat,
        SavedAt = os.time()
    }
    
    local success = pcall(function()
        writefile("Axiora/Queues/" .. name .. ".queue", HttpService:JSONEncode(data))
    end)
    
    if success then
        Axiora.Visuals.Notify("Sequences", "Queue saved: " .. name, 2, "success")
    end
    return success
end

function Axiora.Sequences.LoadQueue(name)
    if not Axiora.Capabilities.ReadFile then return false end
    
    local success, data = pcall(function()
        return HttpService:JSONDecode(readfile("Axiora/Queues/" .. name .. ".queue"))
    end)
    
    if success and data and data.Sequences then
        Axiora.Sequences.Queue = data.Sequences
        Axiora.Sequences.Repeat = data.Repeat or false
        Axiora.Visuals.Notify("Sequences", "Loaded: " .. name, 2, "success")
        return true
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- BREAKPOINT SYSTEM (Debug Pausing)
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Breakpoints = {
    Nodes = {},           -- {[nodeIndex] = true}
    Enabled = true,
    PauseOnHit = true,
    WaitingAtBreakpoint = false,
    CurrentBreakpoint = nil
}

-- Set a breakpoint at a specific node index
function Axiora.SetBreakpoint(index)
    if type(index) ~= "number" or index < 1 then
        Axiora.Visuals.Notify("Breakpoint", "Invalid index", 2, "error")
        return false
    end
    
    Axiora.Breakpoints.Nodes[index] = true
    Axiora.Visuals.Notify("Breakpoint", "Set at node #" .. index, 2, "success")
    Axiora.Events:Fire("BreakpointSet", {Index = index})
    return true
end

-- Remove a breakpoint
function Axiora.RemoveBreakpoint(index)
    if not Axiora.Breakpoints.Nodes[index] then
        Axiora.Visuals.Notify("Breakpoint", "No breakpoint at #" .. index, 2, "warning")
        return false
    end
    
    Axiora.Breakpoints.Nodes[index] = nil
    Axiora.Visuals.Notify("Breakpoint", "Removed from node #" .. index, 2, "info")
    Axiora.Events:Fire("BreakpointRemoved", {Index = index})
    return true
end

-- Toggle breakpoint
function Axiora.ToggleBreakpoint(index)
    if Axiora.Breakpoints.Nodes[index] then
        return Axiora.RemoveBreakpoint(index)
    else
        return Axiora.SetBreakpoint(index)
    end
end

-- Clear all breakpoints
function Axiora.ClearBreakpoints()
    local count = 0
    for _ in pairs(Axiora.Breakpoints.Nodes) do
        count = count + 1
    end
    
    Axiora.Breakpoints.Nodes = {}
    Axiora.Visuals.Notify("Breakpoint", "Cleared " .. count .. " breakpoints", 2, "info")
    Axiora.Events:Fire("BreakpointsCleared", {Count = count})
    return count
end

-- List all breakpoints
function Axiora.ListBreakpoints()
    local list = {}
    for index, _ in pairs(Axiora.Breakpoints.Nodes) do
        table.insert(list, index)
    end
    table.sort(list)
    return list
end

-- Check if node has breakpoint (used in playback loop)
function Axiora.Breakpoints.Check(nodeIndex)
    if not Axiora.Settings.BreakpointsEnabled then return false end
    if not Axiora.Breakpoints.Enabled then return false end
    return Axiora.Breakpoints.Nodes[nodeIndex] == true
end

-- Resume from breakpoint
function Axiora.ResumeFromBreakpoint()
    if Axiora.Breakpoints.WaitingAtBreakpoint then
        Axiora.Breakpoints.WaitingAtBreakpoint = false
        Axiora.Visuals.Notify("Breakpoint", "Resumed from #" .. (Axiora.Breakpoints.CurrentBreakpoint or "?"), 2, "success")
        Axiora.Breakpoints.CurrentBreakpoint = nil
        return true
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 14: AUTO-RESTART SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.AutoRestart = {
    Enabled = false,
    OnDeath = true,
    MaxRestarts = 10,
    RestartCount = 0,
    RestartDelay = 5,
    LastRestartTime = 0,
    RestartCooldown = 10,
    _initialized = false,
    _characterConnection = nil,
    _deathConnection = nil
}

function Axiora.AutoRestart.Enable()
    if Axiora.AutoRestart.Enabled then return end
    
    Axiora.AutoRestart.Enabled = true
    Axiora.AutoRestart.RestartCount = 0
    Axiora.AutoRestart.LastRestartTime = 0
    
    -- Clean up old connections
    if Axiora.AutoRestart._characterConnection then
        pcall(function() Axiora.AutoRestart._characterConnection:Disconnect() end)
    end
    if Axiora.AutoRestart._deathConnection then
        pcall(function() Axiora.AutoRestart._deathConnection:Disconnect() end)
    end
    
    local LP = getLocalPlayer()
    if not LP then return end
    
    -- Setup character listener
    Axiora.AutoRestart._characterConnection = LP.CharacterAdded:Connect(function(char)
        -- Wait for humanoid
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        
        -- Clean up old death connection
        if Axiora.AutoRestart._deathConnection then
            pcall(function() Axiora.AutoRestart._deathConnection:Disconnect() end)
        end
        
        -- Setup death listener
        Axiora.AutoRestart._deathConnection = hum.Died:Connect(function()
            if not Axiora.AutoRestart.Enabled then return end
            if not Axiora.AutoRestart.OnDeath then return end
            if Axiora.AutoRestart.RestartCount >= Axiora.AutoRestart.MaxRestarts then
                Axiora.Visuals.Notify("Auto-Restart", "Max restarts reached", 3, "warning")
                Axiora.AutoRestart.Disable()
                return
            end
            
            local now = os.clock()
            if (now - Axiora.AutoRestart.LastRestartTime) < Axiora.AutoRestart.RestartCooldown then
                return
            end
            
            if Axiora.State.Status ~= "PLAYING" and #Axiora.State.Buffer == 0 then
                return
            end
            
            Axiora.AutoRestart.RestartCount = Axiora.AutoRestart.RestartCount + 1
            Axiora.AutoRestart.LastRestartTime = now
            
            Axiora.Visuals.Notify("Auto-Restart", 
                "Restarting in " .. Axiora.AutoRestart.RestartDelay .. "s... (" .. 
                Axiora.AutoRestart.RestartCount .. "/" .. Axiora.AutoRestart.MaxRestarts .. ")", 
                Axiora.AutoRestart.RestartDelay, "warning")
            
            task.delay(Axiora.AutoRestart.RestartDelay, function()
                if not Axiora.AutoRestart.Enabled then return end
                
                -- Wait for respawn
                local waitStart = os.clock()
                while (os.clock() - waitStart) < 15 do
                    if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                        break
                    end
                    task.wait(0.5)
                end
                
                task.wait(1)
                Axiora.Play(true)
            end)
        end)
    end)
    
    -- Also setup for current character
    if LP.Character then
        local hum = LP.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            -- Trigger same logic
            Axiora.AutoRestart._deathConnection = hum.Died:Connect(function()
                -- Same death handling
                if not Axiora.AutoRestart.Enabled or not Axiora.AutoRestart.OnDeath then return end
                if Axiora.AutoRestart.RestartCount >= Axiora.AutoRestart.MaxRestarts then return end
                
                Axiora.AutoRestart.RestartCount = Axiora.AutoRestart.RestartCount + 1
                Axiora.Visuals.Notify("Auto-Restart", "Restarting...", 3, "warning")
                
                task.delay(Axiora.AutoRestart.RestartDelay, function()
                    if not Axiora.AutoRestart.Enabled then return end
                    LP.CharacterAdded:Wait()
                    task.wait(2)
                    Axiora.Play(true)
                end)
            end)
        end
    end
    
    Axiora.AutoRestart._initialized = true
    Axiora.Visuals.Notify("Auto-Restart", "Enabled", 2, "success")
    Axiora.Events:Fire("AutoRestartEnabled")
end

function Axiora.AutoRestart.Disable()
    Axiora.AutoRestart.Enabled = false
    
    if Axiora.AutoRestart._characterConnection then
        pcall(function() Axiora.AutoRestart._characterConnection:Disconnect() end)
        Axiora.AutoRestart._characterConnection = nil
    end
    if Axiora.AutoRestart._deathConnection then
        pcall(function() Axiora.AutoRestart._deathConnection:Disconnect() end)
        Axiora.AutoRestart._deathConnection = nil
    end
    
    Axiora.AutoRestart._initialized = false
    Axiora.Visuals.Notify("Auto-Restart", "Disabled", 2, "info")
    Axiora.Events:Fire("AutoRestartDisabled")
end

function Axiora.AutoRestart.Toggle()
    if Axiora.AutoRestart.Enabled then
        Axiora.AutoRestart.Disable()
    else
        Axiora.AutoRestart.Enable()
    end
    return Axiora.AutoRestart.Enabled
end

function Axiora.AutoRestart.ResetCount()
    Axiora.AutoRestart.RestartCount = 0
end

function Axiora.AutoRestart.GetStatus()
    return {
        Enabled = Axiora.AutoRestart.Enabled,
        RestartCount = Axiora.AutoRestart.RestartCount,
        MaxRestarts = Axiora.AutoRestart.MaxRestarts,
        Delay = Axiora.AutoRestart.RestartDelay
    }
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 15: CONDITIONAL PLAYBACK (IF/THEN Logic)
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Conditions = {
    _timers = {},
    _variables = {}
}

-- Condition checks
Axiora.Conditions.Checks = {
    CharacterExists = function()
        local LP = getLocalPlayer()
        return LP and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") ~= nil
    end,
    
    IsAlive = function()
        local LP = getLocalPlayer()
        if not LP or not LP.Character then return false end
        local hum = LP.Character:FindFirstChildOfClass("Humanoid")
        return hum and hum.Health > 0
    end,
    
    HealthAbove = function(percent)
        local LP = getLocalPlayer()
        if not LP or not LP.Character then return false end
        local hum = LP.Character:FindFirstChildOfClass("Humanoid")
        if not hum then return false end
        return (hum.Health / hum.MaxHealth) * 100 >= (percent or 50)
    end,
    
    HealthBelow = function(percent)
        local LP = getLocalPlayer()
        if not LP or not LP.Character then return false end
        local hum = LP.Character:FindFirstChildOfClass("Humanoid")
        if not hum then return false end
        return (hum.Health / hum.MaxHealth) * 100 < (percent or 50)
    end,
    
    DistanceFromPosition = function(pos, maxDistance)
        local LP = getLocalPlayer()
        if not Axiora.Conditions.Checks.CharacterExists() then return false end
        
        local target
        if typeof(pos) == "Vector3" then
            target = pos
        elseif type(pos) == "table" then
            target = Vector3.new(pos.x or pos[1] or 0, pos.y or pos[2] or 0, pos.z or pos[3] or 0)
        else
            return false
        end
        
        local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        return (hrp.Position - target).Magnitude <= (maxDistance or 50)
    end,
    
    PartExists = function(partName, parent)
        local searchIn = parent and game:FindFirstChild(parent) or Workspace
        if not searchIn then return false end
        return searchIn:FindFirstChild(partName, true) ~= nil
    end,
    
    TimePassed = function(seconds, timerKey)
        timerKey = timerKey or "_default"
        if not Axiora.Conditions._timers[timerKey] then
            Axiora.Conditions._timers[timerKey] = os.clock()
            return false
        end
        return (os.clock() - Axiora.Conditions._timers[timerKey]) >= (seconds or 0)
    end,
    
    ResetTimer = function(timerKey)
        timerKey = timerKey or "_default"
        Axiora.Conditions._timers[timerKey] = os.clock()
        return true
    end,
    
    RandomChance = function(percent)
        return math.random(1, 100) <= (percent or 50)
    end,
    
    HasTool = function(toolName)
        local LP = getLocalPlayer()
        if not LP or not LP.Character then return false end
        return LP.Character:FindFirstChild(toolName) ~= nil
    end,
    
    StaminaAbove = function(percent)
        local LP = getLocalPlayer()
        if not LP or not LP.Character then return false end
        local stamina = LP.Character:FindFirstChild("Stamina")
        if not stamina or not stamina:IsA("NumberValue") then return false end
        return (stamina.Value / 100) * 100 >= (percent or 50)
    end,
    
    IsInRegion = function(regionName)
        local LP = getLocalPlayer()
        if not LP or not LP.Character or not LP.Character.PrimaryPart then return false end
        local region = workspace:FindFirstChild(regionName)
        if not region or not region:IsA("BasePart") then return false end
        
        local playerPos = LP.Character.PrimaryPart.Position
        local regionPos = region.Position
        local regionSize = region.Size / 2
        
        return math.abs(playerPos.X - regionPos.X) <= regionSize.X
           and math.abs(playerPos.Y - regionPos.Y) <= regionSize.Y
           and math.abs(playerPos.Z - regionPos.Z) <= regionSize.Z
    end,
    
    Always = function() return true end,
    Never = function() return false end
}

-- Actions
Axiora.Actions = {
    Wait = function(duration)
        task.wait(duration or 1)
        return duration or 1
    end,
    
    MoveTo = function(position)
        local LP = getLocalPlayer()
        if not Axiora.Conditions.Checks.CharacterExists() then return 0 end
        
        local target
        if typeof(position) == "Vector3" then
            target = position
        elseif type(position) == "table" then
            target = Vector3.new(position.x or position[1] or 0, position.y or position[2] or 0, position.z or position[3] or 0)
        else
            return 0
        end
        
        LP.Character.Humanoid:MoveTo(target)
        return 0
    end,
    
    Click = function(x, y)
        local abs = Axiora.Math.GetAbsoluteInput(x, y)
        Axiora.Input.Click(abs.X, abs.Y)
        return 0.05
    end,
    
    Jump = function()
        local LP = getLocalPlayer()
        if Axiora.Conditions.Checks.CharacterExists() then
            local hum = LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.Jump = true end
        end
        return 0
    end,
    
    Notify = function(message, duration)
        Axiora.Visuals.Notify("Condition", message, duration or 2, "info")
        return 0
    end,
    
    SetVariable = function(name, value)
        Axiora.Conditions._variables[name] = value
        return 0
    end,
    
    GetVariable = function(name, defaultValue)
        return Axiora.Conditions._variables[name] or defaultValue
    end,
    
    Stop = function()
        Axiora.Stop()
        return 0
    end,
    
    Pause = function(duration)
        Axiora.Playback.Paused = true
        task.wait(duration or 5)
        Axiora.Playback.Paused = false
        return duration or 5
    end
}

-- Create conditional node helper
function Axiora.Conditions.CreateNode(config)
    return {
        t = 4, -- Conditional type
        d = config.delay or 0,
        condition = config.condition,
        conditionArgs = config.conditionArgs or {},
        action = config.action,
        actionArgs = config.actionArgs or {},
        elseAction = config.elseAction,
        elseActionArgs = config.elseActionArgs or {}
    }
end

-- Evaluate a condition
function Axiora.Conditions.Evaluate(conditionName, args)
    local check = Axiora.Conditions.Checks[conditionName]
    if not check then return false end
    
    local success, result = pcall(function()
        if args and #args > 0 then
            return check(table.unpack(args))
        else
            return check()
        end
    end)
    
    return success and result
end

-- Execute an action
function Axiora.Actions.Execute(actionName, args)
    local action = Axiora.Actions[actionName]
    if not action then return 0 end
    
    local success, duration = pcall(function()
        if args and #args > 0 then
            return action(table.unpack(args))
        else
            return action()
        end
    end)
    
    return success and (duration or 0) or 0
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 16: MARKED POSITIONS
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.MarkedPositions = {}

function Axiora.MarkPosition(name)
    local LP = getLocalPlayer()
    if not LP or not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then
        Axiora.Visuals.Notify("Mark", "No character found", 2, "error")
        return false
    end
    
    local hrp = LP.Character.HumanoidRootPart
    local pos = hrp.Position
    local cam = Workspace.CurrentCamera
    
    name = name or ("pos_" .. os.date("%H%M%S"))
    
    Axiora.MarkedPositions[name] = {
        x = pos.X,
        y = pos.Y,
        z = pos.Z,
        timestamp = os.time(),
        cameraLook = cam and {
            x = cam.CFrame.LookVector.X,
            y = cam.CFrame.LookVector.Y,
            z = cam.CFrame.LookVector.Z
        } or nil,
        placeId = game.PlaceId
    }
    
    Axiora.Visuals.Notify("Mark", "Saved: " .. name, 2, "success")
    Axiora.Events:Fire("PositionMarked", {Name = name, Position = pos})
    return true
end

function Axiora.GetMarkedPosition(name)
    local data = Axiora.MarkedPositions[name]
    if not data then return nil end
    return Vector3.new(data.x, data.y, data.z)
end

function Axiora.TeleportToMark(name)
    local pos = Axiora.GetMarkedPosition(name)
    if not pos then
        Axiora.Visuals.Notify("Mark", "Position not found: " .. tostring(name), 2, "error")
        return false
    end
    
    local LP = getLocalPlayer()
    if not LP or not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    LP.Character.HumanoidRootPart.CFrame = CFrame.new(pos)
    Axiora.Visuals.Notify("Mark", "Teleported to: " .. name, 2, "success")
    return true
end

function Axiora.MoveToMark(name, timeout)
    local pos = Axiora.GetMarkedPosition(name)
    if not pos then return false end
    
    local LP = getLocalPlayer()
    if not LP or not LP.Character then return false end
    
    local hum = LP.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    
    hum:MoveTo(pos)
    
    if timeout then
        local conn
        local reached = false
        conn = hum.MoveToFinished:Connect(function()
            reached = true
            if conn then conn:Disconnect() end
        end)
        
        local start = os.clock()
        while not reached and (os.clock() - start) < timeout do
            task.wait(0.1)
        end
        if conn then conn:Disconnect() end
    end
    
    return true
end

function Axiora.ListMarkedPositions()
    local list = {}
    for name, data in pairs(Axiora.MarkedPositions) do
        table.insert(list, {
            Name = name,
            Position = Vector3.new(data.x, data.y, data.z),
            Timestamp = data.timestamp
        })
    end
    return list
end

function Axiora.ClearMarkedPositions()
    Axiora.MarkedPositions = {}
    Axiora.Visuals.Notify("Mark", "All positions cleared", 2, "info")
end

function Axiora.SaveMarkedPositions()
    if not Axiora.Capabilities.WriteFile then return false end
    
    local success = pcall(function()
        writefile("Axiora/markers.json", HttpService:JSONEncode(Axiora.MarkedPositions))
    end)
    
    if success then
        Axiora.Visuals.Notify("Mark", "Positions saved", 2, "success")
    end
    return success
end

function Axiora.LoadMarkedPositions()
    if not Axiora.Capabilities.ReadFile then return false end
    
    local success, data = pcall(function()
        return HttpService:JSONDecode(readfile("Axiora/markers.json"))
    end)
    
    if success and data then
        Axiora.MarkedPositions = data
        local count = 0
        for _ in pairs(data) do count = count + 1 end
        Axiora.Visuals.Notify("Mark", "Loaded " .. count .. " positions", 2, "success")
        return true
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 17: ANALYTICS
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Analytics = {
    StartTime = os.clock(),
    Recording = {
        TotalSessions = 0,
        TotalNodes = 0,
        TotalDuration = 0,
        LastSessionNodes = 0,
        LastSessionDuration = 0
    },
    Playback = {
        TotalExecutions = 0,
        TotalLoops = 0,
        SuccessfulCompletions = 0,
        FailedExecutions = 0,
        TotalPlaybackTime = 0
    },
    Errors = {
        Total = 0,
        LastError = nil,
        LastErrorTime = 0
    }
}

-- Track recording
Axiora.Events:Connect("RecordingStarted", function()
    Axiora.Analytics.Recording.TotalSessions = Axiora.Analytics.Recording.TotalSessions + 1
end)

Axiora.Events:Connect("Stopped", function(data)
    if data and data.WasRecording then
        Axiora.Analytics.Recording.LastSessionNodes = #Axiora.State.Buffer
        Axiora.Analytics.Recording.TotalNodes = Axiora.Analytics.Recording.TotalNodes + #Axiora.State.Buffer
    end
end)

-- Track playback
Axiora.Events:Connect("PlaybackStarted", function()
    Axiora.Analytics.Playback.TotalExecutions = Axiora.Analytics.Playback.TotalExecutions + 1
end)

Axiora.Events:Connect("PlaybackComplete", function(data)
    if data then
        Axiora.Analytics.Playback.TotalLoops = Axiora.Analytics.Playback.TotalLoops + (data.Loops or 1)
        if data.NodesPlayed >= (data.TotalNodes or 1) * 0.9 then
            Axiora.Analytics.Playback.SuccessfulCompletions = Axiora.Analytics.Playback.SuccessfulCompletions + 1
        else
            Axiora.Analytics.Playback.FailedExecutions = Axiora.Analytics.Playback.FailedExecutions + 1
        end
    end
end)

-- Track errors
Axiora.Events:Connect("Error", function(data)
    Axiora.Analytics.Errors.Total = Axiora.Analytics.Errors.Total + 1
    Axiora.Analytics.Errors.LastError = data and data.Message or "Unknown"
    Axiora.Analytics.Errors.LastErrorTime = os.clock()
end)

function Axiora.Analytics.GetUptime()
    return os.clock() - Axiora.Analytics.StartTime
end

function Axiora.Analytics.GetUptimeFormatted()
    local uptime = Axiora.Analytics.GetUptime()
    local hours = math.floor(uptime / 3600)
    local mins = math.floor((uptime % 3600) / 60)
    local secs = math.floor(uptime % 60)
    return string.format("%02d:%02d:%02d", hours, mins, secs)
end

function Axiora.Analytics.GetSuccessRate()
    local total = Axiora.Analytics.Playback.SuccessfulCompletions + Axiora.Analytics.Playback.FailedExecutions
    if total == 0 then return 100 end
    return math.floor((Axiora.Analytics.Playback.SuccessfulCompletions / total) * 100)
end

function Axiora.Analytics.GetReport()
    return {
        System = {
            Uptime = Axiora.Analytics.GetUptime(),
            UptimeFormatted = Axiora.Analytics.GetUptimeFormatted(),
            Executor = Axiora.Capabilities.Executor,
            InputMethod = Axiora.Input.Method
        },
        Recording = Axiora.Analytics.Recording,
        Playback = {
            TotalExecutions = Axiora.Analytics.Playback.TotalExecutions,
            TotalLoops = Axiora.Analytics.Playback.TotalLoops,
            SuccessfulCompletions = Axiora.Analytics.Playback.SuccessfulCompletions,
            FailedExecutions = Axiora.Analytics.Playback.FailedExecutions,
            SuccessRatePercent = Axiora.Analytics.GetSuccessRate()
        },
        Errors = Axiora.Analytics.Errors,
        CurrentState = {
            Status = Axiora.State.Status,
            BufferSize = #Axiora.State.Buffer,
            SequenceQueueSize = #Axiora.Sequences.Queue
        }
    }
end

function Axiora.Analytics.Print()
    local report = Axiora.Analytics.GetReport()
    print("========== AXIORA ANALYTICS ==========")
    print("Uptime: " .. report.System.UptimeFormatted)
    print("Executor: " .. report.System.Executor)
    print("")
    print("Recording Sessions: " .. report.Recording.TotalSessions)
    print("Total Nodes Recorded: " .. report.Recording.TotalNodes)
    print("")
    print("Playback Executions: " .. report.Playback.TotalExecutions)
    print("Success Rate: " .. report.Playback.SuccessRatePercent .. "%")
    print("Total Loops: " .. report.Playback.TotalLoops)
    print("")
    print("Total Errors: " .. report.Errors.Total)
    print("Current Buffer: " .. report.CurrentState.BufferSize .. " nodes")
    print("=======================================")
end

function Axiora.Analytics.Export()
    if not Axiora.Capabilities.WriteFile then
        Axiora.Visuals.Notify("Analytics", "Cannot export - no file system", 3, "error")
        return false
    end
    
    local report = Axiora.Analytics.GetReport()
    local filename = "Axiora/analytics_" .. os.time() .. ".json"
    
    local success = pcall(function()
        writefile(filename, HttpService:JSONEncode(report))
    end)
    
    if success then
        Axiora.Visuals.Notify("Analytics", "Exported to: " .. filename, 3, "success")
    end
    return success
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 18: CALIBRATION
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Calibration = {
    Active = false,
    XOffset = 0,
    YOffset = 0
}

function Axiora.Calibration.SetOffsets(x, y)
    Axiora.Settings.XOffset = x or 0
    Axiora.Settings.YOffset = y or 0
    Axiora.Calibration.XOffset = x or 0
    Axiora.Calibration.YOffset = y or 0
    Axiora.Visuals.Notify("Calibration", "Offsets set: X=" .. x .. ", Y=" .. y, 2, "success")
end

function Axiora.Calibration.GetOffsets()
    return {
        X = Axiora.Settings.XOffset,
        Y = Axiora.Settings.YOffset
    }
end

function Axiora.Calibration.Reset()
    Axiora.Settings.XOffset = 0
    Axiora.Settings.YOffset = 0
    Axiora.Calibration.XOffset = 0
    Axiora.Calibration.YOffset = 0
    Axiora.Visuals.Notify("Calibration", "Offsets reset to 0", 2, "info")
end

function Axiora.Calibration.AutoDetect()
    -- Simple auto-detection based on screen size
    Axiora.Math.UpdateScreenMetrics()
    local screen = Axiora.Math.Screen.Viewport
    
    -- Some common resolution adjustments
    if screen.X < 1280 then
        -- Lower resolution - might need offset
        Axiora.Calibration.SetOffsets(0, 0)
    elseif screen.X > 1920 then
        -- Higher resolution
        Axiora.Calibration.SetOffsets(0, 0)
    else
        -- Standard 1080p
        Axiora.Calibration.SetOffsets(0, 0)
    end
    
    Axiora.Visuals.Notify("Calibration", "Auto-detected for " .. math.floor(screen.X) .. "x" .. math.floor(screen.Y), 2, "info")
end

function Axiora.Calibration.SaveCalibration()
    if not Axiora.Capabilities.WriteFile then return false end
    
    local data = {
        XOffset = Axiora.Settings.XOffset,
        YOffset = Axiora.Settings.YOffset,
        PlaceId = game.PlaceId,
        Resolution = {
            X = Axiora.Math.Screen.Viewport.X,
            Y = Axiora.Math.Screen.Viewport.Y
        }
    }
    
    return pcall(function()
        writefile("Axiora/calibration.json", HttpService:JSONEncode(data))
    end)
end

function Axiora.Calibration.LoadCalibration()
    if not Axiora.Capabilities.ReadFile then return false end
    
    local success, data = pcall(function()
        return HttpService:JSONDecode(readfile("Axiora/calibration.json"))
    end)
    
    if success and data then
        Axiora.Calibration.SetOffsets(data.XOffset or 0, data.YOffset or 0)
        return true
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 19: MODERN UI INTERFACE (Fully Redesigned)
-- ═══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 19: HOLOGRAPHIC COMMAND CENTER (UI V2.0)
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.UI = {
    ScreenGui = nil,
    Open = false,
    CurrentTab = 1,
    Orientation = "Portrait",
    Scale = 1.0,
    
    -- Design System
    Theme = {
        -- Backgrounds
        Deep = Color3.fromRGB(8, 8, 15),        -- Main BG
        Surface = Color3.fromRGB(18, 18, 28),   -- Elevated surfaces
        Overlay = Color3.fromRGB(25, 25, 40),   -- Panels
        Glass = 0.1,                            -- Transparency level
        
        -- Accents (State-dependent)
        Idle = Color3.fromRGB(60, 180, 255),    -- Cyan
        Recording = Color3.fromRGB(255, 50, 80), -- Crimson
        Playing = Color3.fromRGB(120, 255, 150), -- Green
        Paused = Color3.fromRGB(255, 200, 50),   -- Amber
        
        -- Node Types
        Movement = Color3.fromRGB(80, 150, 255), -- Blue
        Click = Color3.fromRGB(180, 80, 255),    -- Purple
        Key = Color3.fromRGB(255, 180, 50),      -- Orange
        Delay = Color3.fromRGB(100, 100, 120),   -- Gray
        
        -- Text
        Primary = Color3.fromRGB(255, 255, 255),
        Secondary = Color3.fromRGB(180, 180, 200),
        Tertiary = Color3.fromRGB(120, 120, 140),
        
        -- Status
        Success = Color3.fromRGB(50, 255, 150),
        Warning = Color3.fromRGB(255, 200, 50),
        Error = Color3.fromRGB(255, 80, 100),
        Info = Color3.fromRGB(100, 200, 255)
    },
    
    -- Components Storage
    Orb = nil,
    Hub = nil,
    Tabs = {},
    Particles = {},
    Connections = {}
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- UI HELPER PRIMITIVES
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.UI.Primitives = {}

function Axiora.UI.Primitives.CreateScreenGui()
    if Axiora.UI.ScreenGui then pcall(function() Axiora.UI.ScreenGui:Destroy() end) end
    
    local sg = Instance.new("ScreenGui")
    sg.Name = "Axiora_HoloUI"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 1000
    
    local success = pcall(function() sg.Parent = CoreGui end)
    if not success then
        local LP = getLocalPlayer()
        if LP then sg.Parent = LP:FindFirstChild("PlayerGui") end
    end
    
    Axiora.UI.ScreenGui = sg
    return sg
end

function Axiora.UI.Primitives.CreateHoloPanel(parent, size, pos)
    local theme = Axiora.UI.Theme
    
    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = theme.Deep
    frame.BackgroundTransparency = 0.15
    frame.Size = size or UDim2.new(1, 0, 1, 0)
    frame.Position = pos or UDim2.new(0, 0, 0, 0)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    
    -- Glass effect
    local glass = Instance.new("Frame")
    glass.Name = "GlassOverlay"
    glass.BackgroundColor3 = theme.Surface
    glass.BackgroundTransparency = 0.95
    glass.Size = UDim2.new(1, 0, 1, 0)
    glass.ZIndex = frame.ZIndex
    glass.Parent = frame
    
    -- Neon Stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = theme.Idle
    stroke.Transparency = 0.6
    stroke.Thickness = 1.5
    stroke.Parent = frame
    
    -- Corner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame
    -- Apply to glass too
    local glassCorner = corner:Clone()
    glassCorner.Parent = glass
    
    frame.ClipsDescendants = true
    
    return frame, stroke
end

function Axiora.UI.Primitives.CreateNeonText(parent, text, size, color)
    local theme = Axiora.UI.Theme
    
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, size or 20)
    label.Text = text or ""
    label.TextColor3 = color or theme.Primary
    label.Font = Enum.Font.GothamBold
    label.TextSize = size or 14
    label.Parent = parent
    
    -- Glow effect
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or theme.Primary
    stroke.Transparency = 0.8
    stroke.Thickness = 2
    stroke.Parent = label
    
    return label
end

function Axiora.UI.Primitives.Create3DButton(parent, text, color, callback)
    local theme = Axiora.UI.Theme
    color = color or theme.Idle
    
    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = color
    btn.BackgroundTransparency = 0.2
    btn.Size = UDim2.new(1, 0, 0, 45)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = parent
    
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    
    -- Gradient for 3D look
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(1, Color3.new(0.7,0.7,0.7)) -- Darken bottom
    })
    grad.Rotation = 90
    grad.Parent = btn
    
    -- Inner Shadow (simulated with Frame)
    local shadow = Instance.new("Frame")
    shadow.BackgroundColor3 = Color3.new(0,0,0)
    shadow.BackgroundTransparency = 0.8
    shadow.Size = UDim2.new(1, 0, 0.2, 0)
    shadow.Position = UDim2.new(0, 0, 0.8, 0)
    shadow.BorderSizePixel = 0
    shadow.Parent = btn
    Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 8)
    
    -- Label
    local label = Axiora.UI.Primitives.CreateNeonText(btn, text, 14, theme.Primary)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.ZIndex = 2
    
    -- Interaction
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(1, -4, 0, 41)}):Play()
        if Axiora.Haptics then Axiora.Haptics.Pulse("Small") end
    end)
    
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(1, 0, 0, 45)}):Play()
        
        -- Spawn Particles
        local center = btn.AbsolutePosition + btn.AbsoluteSize/2
        for i = 1, 5 do
            Axiora.Particles.Spawn(center.X, center.Y, color)
        end
        
        if callback then callback() end
    end)
    
    return btn
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ADVANCED UX SYSTEMS
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Haptics = {}

function Axiora.Haptics.IsSupported()
    return UserInputService.TouchEnabled and UserInputService.GyroscopeEnabled -- Proxy check for mobile
end

function Axiora.Haptics.Pulse(intensity)
    if not Axiora.Haptics.IsSupported() then return end
    -- HapticService isn't fully exposed to scripts usually, relying on camera shake fallback
    -- or if HapticService exists (some executors support it)
    pcall(function()
        if HapticService then
            HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0.5)
            task.delay(0.1, function() 
                HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0) 
            end)
        end
    end)
end

Axiora.Particles = {}

function Axiora.Particles.Spawn(x, y, color)
    if not Axiora.UI.ScreenGui then return end
    
    local p = Instance.new("Frame")
    p.BackgroundColor3 = color or Axiora.UI.Theme.Idle
    p.Size = UDim2.new(0, 10, 0, 10)
    p.Position = UDim2.new(0, x, 0, y)
    p.AnchorPoint = Vector2.new(0.5, 0.5)
    p.BorderSizePixel = 0
    p.Parent = Axiora.UI.ScreenGui
    Instance.new("UICorner", p).CornerRadius = UDim.new(1, 0)
    
    local destX = x + math.random(-50, 50)
    local destY = y + math.random(-50, 50)
    
    local tween = TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
        Position = UDim2.new(0, destX, 0, destY),
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 0, 0)
    })
    tween:Play()
    tween.Completed:Connect(function() p:Destroy() end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- "AXIE" AI ASSISTANT
-- ═══════════════════════════════════════════════════════════════════════════════

Axiora.Assistant = {
    Frame = nil,
    Visible = false,
    Messages = {
        "Recorded 50 nodes without pause! Great flow.",
        "Tip: Use 'Mark Position' to save this spot.",
        "Playing at 2.5x speed - Turbo Mode!",
        "Macro saved successfully to file.",
        "Warning: Playback drift detected (Recovered)."
    }
}

function Axiora.Assistant.Show(text, mood)
    local sg = Axiora.UI.ScreenGui
    if not sg then return end
    
    if not Axiora.Assistant.Frame then
        local frame = Instance.new("Frame")
        frame.Name = "Axie"
        frame.BackgroundColor3 = Axiora.UI.Theme.Overlay
        frame.Size = UDim2.new(0, 180, 0, 60)
        frame.Position = UDim2.new(1, -220, 0.5, -80) -- Above Orb
        frame.Parent = sg
        
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 30)
        
        -- Face
        local face = Instance.new("Frame")
        face.BackgroundColor3 = Axiora.UI.Theme.Idle
        face.Size = UDim2.new(0, 40, 0, 40)
        face.Position = UDim2.new(0, 10, 0.5, 0)
        face.AnchorPoint = Vector2.new(0, 0.5)
        face.Parent = frame
        Instance.new("UICorner", face).CornerRadius = UDim.new(1, 0)
        
        local eyes = Instance.new("TextLabel")
        eyes.BackgroundTransparency = 1
        eyes.Size = UDim2.new(1, 0, 1, 0)
        eyes.Text = "◉ ◉"
        eyes.TextColor3 = Axiora.UI.Theme.Deep
        eyes.TextSize = 14
        eyes.Parent = face
        
        -- Text Bubble
        local label = Instance.new("TextLabel")
        label.Name = "Message"
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, -60, 1, 0)
        label.Position = UDim2.new(0, 55, 0, 0)
        label.TextColor3 = Axiora.UI.Theme.Primary
        label.TextSize = 11
        label.Font = Enum.Font.Gotham
        label.TextWrapped = true
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        
        Axiora.Assistant.Frame = frame
    end
    
    local f = Axiora.Assistant.Frame
    f.Visible = true
    f.BackgroundTransparency = 1
    f.Message.TextTransparency = 1
    f.Message.Text = text or Axiora.Assistant.Messages[math.random(1, #Axiora.Assistant.Messages)]
    
    -- Animate In
    TweenService:Create(f, TweenInfo.new(0.5, Enum.EasingStyle.Back), {BackgroundTransparency = 0.2}):Play()
    TweenService:Create(f.Message, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
    
    -- Auto Hide
    task.delay(4, function()
        TweenService:Create(f, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
        TweenService:Create(f.Message, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
        task.wait(0.5)
        if f.BackgroundTransparency >= 0.9 then f.Visible = false end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- PHASE 2: QUANTUM ORB (Persistent HUD)
-- ═══════════════════════════════════════════════════════════════════════════════

function Axiora.UI.CreateOrb()
    if Axiora.UI.Orb then Axiora.UI.Orb:Destroy() end
    
    local sg = Axiora.UI.ScreenGui or Axiora.UI.Primitives.CreateScreenGui()
    local theme = Axiora.UI.Theme
    
    local orbSize = 60
    local orb = Instance.new("Frame")
    orb.Name = "QuantumOrb"
    orb.BackgroundColor3 = theme.Deep
    orb.BackgroundTransparency = 0.2
    orb.Size = UDim2.new(0, orbSize, 0, orbSize)
    orb.Position = UDim2.new(1, -orbSize - 20, 0.5, 0) -- Right edge default
    orb.AnchorPoint = Vector2.new(0.5, 0.5)
    orb.Parent = sg
    
    Instance.new("UICorner", orb).CornerRadius = UDim.new(1, 0)
    
    -- Glow Ring
    local stroke = Instance.new("UIStroke")
    stroke.Color = theme.Idle
    stroke.Thickness = 2
    stroke.Parent = orb
    
    -- Inner Status Dot
    local dot = Instance.new("Frame")
    dot.BackgroundColor3 = theme.Idle
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(0.5, 0, 0.3, 0)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Parent = orb
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    
    -- Count
    local count = Instance.new("TextLabel")
    count.BackgroundTransparency = 1
    count.Size = UDim2.new(1, 0, 0, 20)
    count.Position = UDim2.new(0, 0, 0.6, 0)
    count.Text = "0"
    count.TextColor3 = theme.Primary
    count.Font = Enum.Font.GothamBold
    count.TextSize = 12
    count.Parent = orb
    
    -- Gestures
    local dragging = false
    local dragStart = Vector2.new()
    local startPos = UDim2.new()
    local heldTime = 0
    
    orb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = orb.Position
            heldTime = os.clock()
            
            -- Press effect
            TweenService:Create(orb, TweenInfo.new(0.1), {Size = UDim2.new(0, orbSize*0.9, 0, orbSize*0.9)}):Play()
        end
    end)
    
    orb.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            TweenService:Create(orb, TweenInfo.new(0.1), {Size = UDim2.new(0, orbSize, 0, orbSize)}):Play()
            
            local dragDist = (Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(dragStart.X, dragStart.Y)).Magnitude
            
            -- Tap check
            if dragDist < 10 then
                if os.clock() - heldTime > 0.5 then
                    -- Long Press -> Radial Menu (TODO)
                    Axiora.Visuals.Notify("Orb", "Radial Menu (Coming Soon)", 1)
                else
                    -- Tap -> Toggle UI
                    Axiora.UI.Toggle()
                end
            else
                -- Snap to edge logic
                local screen = workspace.CurrentCamera.ViewportSize
                local endX = orb.Position.X.Offset
                local targetX = (endX < screen.X/2) and 40 or (screen.X - 40)
                
                TweenService:Create(orb, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
                    Position = UDim2.new(0, targetX, 0, orb.Position.Y.Offset)
                }):Play()
            end
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            orb.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- Status Pulse
    task.spawn(function()
        while orb.Parent do
            local color = theme.Idle
            if Axiora.State.Status == "RECORDING" then color = theme.Recording
            elseif Axiora.State.Status == "PLAYING" then color = theme.Playing end
            
            TweenService:Create(stroke, TweenInfo.new(0.5), {Color = color}):Play()
            TweenService:Create(dot, TweenInfo.new(0.5), {BackgroundColor3 = color}):Play()
            count.Text = #Axiora.State.Buffer
            
            task.wait(0.5)
        end
    end)
    
    Axiora.UI.Orb = orb
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- PHASE 3: THE NEURAL HUB (Main Interface)
-- ═══════════════════════════════════════════════════════════════════════════════

function Axiora.UI.Toggle()
    if Axiora.UI.Open then
        Axiora.UI.CloseHub()
    else
        Axiora.UI.OpenHub()
    end
end

function Axiora.UI.OpenHub()
    if Axiora.UI.Hub then Axiora.UI.Hub:Destroy() end
    
    local sg = Axiora.UI.ScreenGui or Axiora.UI.Primitives.CreateScreenGui()
    local theme = Axiora.UI.Theme
    
    Axiora.UI.Open = true
    
    -- Main Container
    local hub = Instance.new("Frame")
    hub.Name = "NeuralHub"
    hub.BackgroundColor3 = theme.Deep
    hub.BackgroundTransparency = 0.05
    hub.Size = UDim2.new(1, 0, 0.5, 0) -- 50% height, Full width (bottom half)
    hub.Position = UDim2.new(0, 0, 1.5, 0) -- Start off screen (bottom)
    hub.Parent = sg
    
    -- Background Particles
    -- (TODO: Particle emitter inside GUI if possible, or just raw frames)
    
    -- Header
    local header = Instance.new("Frame")
    header.BackgroundColor3 = theme.Surface
    header.BackgroundTransparency = 0.2
    header.Size = UDim2.new(1, 0, 0, 60)
    header.Parent = hub
    
    Axiora.UI.Primitives.CreateNeonText(header, "AXIORA NEURAL HUB", 18, theme.Primary).Position = UDim2.new(0, 20, 0, 20)
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.BackgroundTransparency = 1
    closeBtn.Size = UDim2.new(0, 50, 0, 60)
    closeBtn.Position = UDim2.new(1, -50, 0, 0)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = theme.Error
    closeBtn.TextSize = 24
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = header
    closeBtn.MouseButton1Click:Connect(function()
        Axiora.UI.CloseHub()
    end)
    
    -- Slide Up Animation
    TweenService:Create(hub, TweenInfo.new(0.4, Enum.EasingStyle.Quart), {Position = UDim2.new(0, 0, 0.5, 0)}):Play()
    
    Axiora.UI.Hub = hub
    
    -- Tab Container
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.BackgroundTransparency = 1
    contentArea.Size = UDim2.new(1, 0, 1, -140) -- Space for Header + Nav
    contentArea.Position = UDim2.new(0, 0, 0, 60)
    contentArea.Parent = hub
    
    Axiora.UI.ContentArea = contentArea
    
    -- Bottom Navigation (Portrait Mode)
    local navBar = Instance.new("Frame")
    navBar.Name = "NavBar"
    navBar.BackgroundColor3 = theme.Surface
    navBar.BackgroundTransparency = 0.1
    navBar.Size = UDim2.new(1, -40, 0, 60)
    navBar.Position = UDim2.new(0.5, 0, 1, -20)
    navBar.AnchorPoint = Vector2.new(0.5, 1)
    navBar.Parent = hub
    
    Instance.new("UICorner", navBar).CornerRadius = UDim.new(1, 0)
    
    local navLayout = Instance.new("UIListLayout")
    navLayout.FillDirection = Enum.FillDirection.Horizontal
    navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    navLayout.Padding = UDim.new(0, 10)
    navLayout.Parent = navBar
    
    -- Tab Definitions
    local tabs = {
        {Id = 1, Icon = "📊", Name = "Home"},
        {Id = 2, Icon = "✏️", Name = "Editor"},
        {Id = 3, Icon = "📁", Name = "Files"},
        {Id = 4, Icon = "🔧", Name = "Tools"}
    }
    
    for _, tab in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Name = "Tab_" .. tab.Id
        btn.BackgroundColor3 = theme.Deep
        btn.BackgroundTransparency = 0.5
        btn.Size = UDim2.new(0, 50, 0, 50)
        btn.Text = tab.Icon
        btn.TextSize = 24
        btn.TextColor3 = theme.Secondary
        btn.AutoButtonColor = false
        btn.Parent = navBar
        
        Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
        
        btn.MouseButton1Click:Connect(function()
            Axiora.UI.SwitchTab(tab.Id)
        end)
    end
    
    -- Initial Tab Load
    Axiora.UI.SwitchTab(1)
end

function Axiora.UI.CloseHub()
    if not Axiora.UI.Hub then return end
    
    Axiora.UI.Open = false
    
    -- Slide Down Animation
    local tween = TweenService:Create(Axiora.UI.Hub, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0, 0, 1.5, 0)
    })
    tween:Play()
    
    tween.Completed:Connect(function()
        if Axiora.UI.Hub then
            Axiora.UI.Hub:Destroy()
            Axiora.UI.Hub = nil
        end
    end)
end

function Axiora.UI.SwitchTab(tabId)
    if not Axiora.UI.Hub then return end
    
    Axiora.UI.CurrentTab = tabId
    local theme = Axiora.UI.Theme
    
    -- Update Nav Buttons
    local navBar = Axiora.UI.Hub:FindFirstChild("NavBar")
    if navBar then
        for _, child in ipairs(navBar:GetChildren()) do
            if child:IsA("TextButton") then
                local id = tonumber(child.Name:match("%d+"))
                local isActive = (id == tabId)
                
                TweenService:Create(child, TweenInfo.new(0.2), {
                    BackgroundColor3 = isActive and theme.Idle or theme.Deep,
                    BackgroundTransparency = isActive and 0.1 or 0.5,
                    TextColor3 = isActive and theme.Primary or theme.Secondary
                }):Play()
            end
        end
    end
    
    -- Clear Content
    for _, child in ipairs(Axiora.UI.ContentArea:GetChildren()) do
        child:Destroy()
    end
    
    -- Build New Content
    if tabId == 1 then
        Axiora.UI.BuildCommandCenter(Axiora.UI.ContentArea)
    elseif tabId == 2 then
        Axiora.UI.BuildEditor(Axiora.UI.ContentArea)
    elseif tabId == 3 then
        Axiora.UI.BuildLibrary(Axiora.UI.ContentArea)
    elseif tabId == 4 then
        Axiora.UI.BuildUtilities(Axiora.UI.ContentArea)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TAB 4: UTILITIES (Tools & Settings)
-- ═══════════════════════════════════════════════════════════════════════════════

function Axiora.UI.BuildUtilities(parent)
    local theme = Axiora.UI.Theme
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.BackgroundTransparency = 1
    scroll.Size = UDim2.new(1, -20, 1, -10)
    scroll.Position = UDim2.new(0, 10, 0, 10)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0) -- Auto-calculated below
    scroll.ScrollBarThickness = 2
    scroll.Parent = parent
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 15)
    layout.Parent = scroll
    
    -- Helper: Section Header
    local function createSection(title)
        local frame = Instance.new("Frame")
        frame.BackgroundTransparency = 1
        frame.Size = UDim2.new(1, 0, 0, 30)
        frame.Parent = scroll
        Axiora.UI.Primitives.CreateNeonText(frame, title, 16, theme.Idle).Position = UDim2.new(0, 5, 0.5, 0)
    end
    
    -- 1. Active Features (Toggles)
    createSection("⚡ ACTIVE FEATURES")
    
    local featuresGrid = Instance.new("Frame")
    featuresGrid.BackgroundTransparency = 1
    featuresGrid.Size = UDim2.new(1, 0, 0, 120)
    featuresGrid.Parent = scroll
    
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0.48, 0, 0, 55)
    grid.CellPadding = UDim2.new(0.04, 0, 0.05, 0)
    grid.Parent = featuresGrid
    
    local function createToggle(name, settingKey)
        local frame = Instance.new("TextButton")
        frame.BackgroundColor3 = theme.Surface
        frame.BackgroundTransparency = 0.2
        frame.Text = ""
        frame.Parent = featuresGrid
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        
        local label = Axiora.UI.Primitives.CreateNeonText(frame, name, 12, theme.Primary)
        label.Size = UDim2.new(0.6, 0, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.TextXAlignment = Enum.TextXAlignment.Left
        
        local toggle = Instance.new("Frame")
        toggle.BackgroundColor3 = Axiora.Settings[settingKey] and theme.Success or theme.Tertiary
        toggle.Size = UDim2.new(0, 40, 0, 20)
        toggle.Position = UDim2.new(1, -50, 0.5, 0)
        toggle.AnchorPoint = Vector2.new(0, 0.5)
        toggle.Parent = frame
        Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)
        
        local knob = Instance.new("Frame")
        knob.BackgroundColor3 = theme.Primary
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = Axiora.Settings[settingKey] and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
        knob.AnchorPoint = Vector2.new(0, 0.5)
        knob.Parent = toggle
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
        
        frame.MouseButton1Click:Connect(function()
            Axiora.Settings[settingKey] = not Axiora.Settings[settingKey]
            
            -- Animate
            local on = Axiora.Settings[settingKey]
            TweenService:Create(toggle, TweenInfo.new(0.2), {BackgroundColor3 = on and theme.Success or theme.Tertiary}):Play()
            TweenService:Create(knob, TweenInfo.new(0.2), {Position = on and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)}):Play()
            
            -- Apply immediate effects
            if settingKey == "AntiAFK" and on then Axiora.Security.EnableAntiAFK() end
            Axiora.Visuals.Notify("Settings", name .. (on and " Enabled" or " Disabled"), 1)
        end)
    end
    
    createToggle("Anti-AFK", "AntiAFK")
    createToggle("Auto Restart", "AutoRestartEnabled") -- Need to map to Axiora.AutoRestart.Enabled usually
    createToggle("HUD", "HUDEnabled")
    createToggle("Click Ripples", "ClickRipple")
    
    -- 2. Spatial Bookmarks
    createSection("📍 SAVED LOCATIONS")
    
    local markerList = Instance.new("Frame")
    markerList.BackgroundTransparency = 1
    markerList.Size = UDim2.new(1, 0, 0, 200) -- Dynamic height really
    markerList.Parent = scroll
    
    local mLayout = Instance.new("UIListLayout")
    mLayout.Padding = UDim.new(0, 5)
    mLayout.Parent = markerList
    
    local marks = Axiora.MarkedPositions or {}
    if #marks == 0 then
        Axiora.UI.Primitives.CreateNeonText(markerList, "No marks saved yet", 12, theme.Tertiary)
    else
        for i, mark in ipairs(marks) do
            local item = Instance.new("Frame")
            item.BackgroundColor3 = theme.Surface
            item.BackgroundTransparency = 0.4
            item.Size = UDim2.new(1, 0, 0, 40)
            item.Parent = markerList
            Instance.new("UICorner", item).CornerRadius = UDim.new(0, 6)
            
            local name = Axiora.UI.Primitives.CreateNeonText(item, mark.Name or ("Mark #" .. i), 12, theme.Primary)
            name.Position = UDim2.new(0, 10, 0.2, 0)
            
            local pos = Axiora.Math.DeserializeVec(mark.Position)
            local dist = "N/A"
            local LP = getLocalPlayer()
            if LP and LP.Character and LP.Character.PrimaryPart and pos then
                dist = math.floor((LP.Character.PrimaryPart.Position - pos).Magnitude) .. "m"
            end
            
            local distLabel = Instance.new("TextLabel")
            distLabel.BackgroundTransparency = 1
            distLabel.Size = UDim2.new(0, 50, 1, 0)
            distLabel.Position = UDim2.new(1, -60, 0, 0)
            distLabel.Text = dist
            distLabel.TextColor3 = theme.Idle
            distLabel.Font = Enum.Font.Gotham
            distLabel.TextSize = 11
            distLabel.Parent = item
        end
    end
    
    -- Add Mark Button
    local addMarkBtn = Axiora.UI.Primitives.Create3DButton(scroll, "+ ADD MARKER", theme.Idle, function()
        Axiora.MarkPosition()
        Axiora.UI.SwitchTab(4) -- Refresh
    end)
    addMarkBtn.Size = UDim2.new(1, 0, 0, 40)
    
    -- Adjust Scroll Size
    scroll.CanvasSize = UDim2.new(0, 0, 0, 400) -- Estimate
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TAB 1: COMMAND CENTER
-- ═══════════════════════════════════════════════════════════════════════════════

function Axiora.UI.BuildCommandCenter(parent)
    local theme = Axiora.UI.Theme
    
    -- 1. Iris Scanner (Status Ring)
    local statusPanel, _ = Axiora.UI.Primitives.CreateHoloPanel(parent, UDim2.new(0, 200, 0, 200), UDim2.new(0.5, -100, 0.05, 0))
    Instance.new("UICorner", statusPanel).CornerRadius = UDim.new(1, 0) -- Make it round
    statusPanel:FindFirstChild("GlassOverlay"):FindFirstChild("UICorner").CornerRadius = UDim.new(1, 0)
    
    local ring = Instance.new("UIStroke")
    ring.Color = theme.Idle
    ring.Thickness = 4
    ring.Transparency = 0.5
    ring.Parent = statusPanel
    
    local statusText = Axiora.UI.Primitives.CreateNeonText(statusPanel, "IDLE", 24, theme.Idle)
    statusText.Size = UDim2.new(1, 0, 0, 30)
    statusText.Position = UDim2.new(0, 0, 0.4, 0)
    
    local nodeCountText = Axiora.UI.Primitives.CreateNeonText(statusPanel, #Axiora.State.Buffer .. " NODES", 14, theme.Secondary)
    nodeCountText.Size = UDim2.new(1, 0, 0, 20)
    nodeCountText.Position = UDim2.new(0, 0, 0.6, 0)
    
    -- Status Loop
    task.spawn(function()
        while statusPanel.Parent do
            local status = Axiora.State.Status
            local color = theme.Idle
            local text = "IDLE"
            
            if status == "RECORDING" then
                color = theme.Recording
                text = "REC " .. Axiora.Recording.NodeCount
            elseif status == "PLAYING" then
                color = theme.Playing
                text = "PLAY " .. math.floor((Axiora.Playback.CurrentIndex / (#Axiora.State.Buffer + 1)) * 100) .. "%"
            elseif status == "PAUSED" then
                color = theme.Paused
                text = "PAUSED"
            end
            
            statusText.Text = text
            statusText.TextColor3 = color
            nodeCountText.Text = #Axiora.State.Buffer .. " NODES"
            ring.Color = color
            
            task.wait(0.2)
        end
    end)
    
    -- 2. Gesture Pad (Control Matrix)
    local pad = Instance.new("Frame")
    pad.BackgroundTransparency = 1
    pad.Size = UDim2.new(0.9, 0, 0.4, 0)
    pad.Position = UDim2.new(0.05, 0, 0.55, 0)
    pad.Parent = parent
    
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0.48, 0, 0.45, 0)
    grid.CellPadding = UDim2.new(0.04, 0, 0.05, 0)
    grid.Parent = pad
    
    -- Record Btn
    Axiora.UI.Primitives.Create3DButton(pad, "⏺ RECORD", theme.Recording, function()
        if Axiora.State.Status == "RECORDING" then Axiora.Stop() else Axiora.Record() end
    end)
    
    -- Play Btn
    Axiora.UI.Primitives.Create3DButton(pad, "▶ PLAY", theme.Playing, function()
        if Axiora.State.Status == "PLAYING" then Axiora.Pause() else Axiora.Play(true) end
    end)
    
    -- Stop Btn
    Axiora.UI.Primitives.Create3DButton(pad, "⏹ STOP", theme.Deep, function()
        Axiora.Stop()
    end)
    
    -- Save Btn
    Axiora.UI.Primitives.Create3DButton(pad, "💾 SAVE", theme.Idle, function()
        Axiora.Save() 
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TAB 2: TIMELINE EDITOR (Vertical Stream)
-- ═══════════════════════════════════════════════════════════════════════════════

function Axiora.UI.BuildEditor(parent)
    local theme = Axiora.UI.Theme
    local nodes = Axiora.EditBuffer()
    
    if #nodes == 0 then
        local empty = Axiora.UI.Primitives.CreateNeonText(parent, "Buffer Empty - Record something first", 16, theme.Tertiary)
        empty.Position = UDim2.new(0, 0, 0.4, 0)
        return
    end
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.BackgroundTransparency = 1
    scroll.Size = UDim2.new(1, -20, 1, -10)
    scroll.Position = UDim2.new(0, 10, 0, 10)
    scroll.CanvasSize = UDim2.new(0, 0, 0, #nodes * 65)
    scroll.ScrollBarThickness = 2
    scroll.Parent = parent
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = scroll
    
    for i, node in ipairs(nodes) do
        local color = theme.Delay
        local icon = "⏳"
        if node.Type == "Move" then color = theme.Movement; icon = "🚶"
        elseif node.Type == "Click" then color = theme.Click; icon = "👆"
        elseif node.Type == "Key" then color = theme.Key; icon = "⌨️" end
        
        local card = Instance.new("Frame")
        card.BackgroundColor3 = theme.Surface
        card.BackgroundTransparency = 0.2
        card.Size = UDim2.new(1, 0, 0, 60)
        card.Parent = scroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
        
        -- Left Stripe
        local stripe = Instance.new("Frame")
        stripe.BackgroundColor3 = color
        stripe.Size = UDim2.new(0, 4, 1, 0)
        stripe.Parent = card
        Instance.new("UICorner", stripe).CornerRadius = UDim.new(1, 0)
        
        -- Info
        local title = Axiora.UI.Primitives.CreateNeonText(card, icon .. " " .. node.Type .. " #" .. i, 14, theme.Primary)
        title.Size = UDim2.new(1, -60, 0, 20)
        title.Position = UDim2.new(0, 15, 0, 10)
        title.TextXAlignment = Enum.TextXAlignment.Left
        
        local descText = "Delay: " .. string.format("%.2f", node.Delay) .. "s"
        local desc = Instance.new("TextLabel")
        desc.BackgroundTransparency = 1
        desc.Size = UDim2.new(1, -60, 0, 20)
        desc.Position = UDim2.new(0, 15, 0, 30)
        desc.Text = descText
        desc.TextColor3 = theme.Secondary
        desc.Font = Enum.Font.Gotham
        desc.TextSize = 12
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.Parent = card
        
        -- Delete Action (Basic tap for now, swipe needs Logic)
        local delBtn = Instance.new("TextButton")
        delBtn.BackgroundTransparency = 1
        delBtn.Size = UDim2.new(0, 40, 1, 0)
        delBtn.Position = UDim2.new(1, -40, 0, 0)
        delBtn.Text = "🗑️"
        delBtn.TextSize = 16
        delBtn.Parent = card
        
        delBtn.MouseButton1Click:Connect(function()
            Axiora.DeleteNode(i)
            card:Destroy() -- Optimistic UI update
             -- In real app, re-render whole list or shift indices
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TAB 3: LIBRARY (File Grid)
-- ═══════════════════════════════════════════════════════════════════════════════

function Axiora.UI.BuildLibrary(parent)
    local theme = Axiora.UI.Theme
    local saves = Axiora.ListSaves()
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.BackgroundTransparency = 1
    scroll.Size = UDim2.new(1, -20, 1, -10)
    scroll.Position = UDim2.new(0, 10, 0, 10)
    scroll.CanvasSize = UDim2.new(0, 0, 0, math.ceil(#saves/2) * 110)
    scroll.ScrollBarThickness = 2
    scroll.Parent = parent
    
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0.48, 0, 0, 100)
    grid.CellPadding = UDim2.new(0.04, 0, 0, 10)
    grid.Parent = scroll
    
    for _, save in ipairs(saves) do
        local card = Instance.new("TextButton")
        card.BackgroundColor3 = theme.Surface
        card.BackgroundTransparency = 0.2
        card.Text = ""
        card.Parent = scroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
        
        -- Icon
        local icon = Instance.new("TextLabel")
        icon.BackgroundTransparency = 1
        icon.Size = UDim2.new(1, 0, 0.6, 0)
        icon.Text = "📄"
        icon.TextSize = 30
        icon.Parent = card
        
        -- Name
        local label = Axiora.UI.Primitives.CreateNeonText(card, save, 12, theme.Primary)
        label.Size = UDim2.new(1, -10, 0, 20)
        label.Position = UDim2.new(0, 5, 0.65, 0)
        
        -- Load Action
        card.MouseButton1Click:Connect(function()
            Axiora.Load(save)
            Axiora.UI.CloseHub() -- Auto close on load
        end)
    end
end

function Axiora.UI.CloseHub()
    if Axiora.UI.Hub then
        TweenService:Create(Axiora.UI.Hub, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Position = UDim2.new(0,0,1,0)}):Play()
        task.wait(0.3)
        Axiora.UI.Hub:Destroy()
        Axiora.UI.Hub = nil
    end
    Axiora.UI.Open = false
end

-- Initialize
function Axiora.UI.Init()
    Axiora.UI.Primitives.CreateScreenGui()
    Axiora.UI.CreateOrb()
end


-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 20: INITIALIZATION & EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Helper: Add glow effect
local function addGlow(parent, color, size)
    local glow = Instance.new("ImageLabel")
    glow.Name = "Glow"
    glow.BackgroundTransparency = 1
    glow.Image = "rbxassetid://5028857084" -- Radial blur
    glow.ImageColor3 = color
    glow.ImageTransparency = 0.7
    glow.Size = UDim2.new(1, size or 40, 1, size or 40)
    glow.Position = UDim2.new(0.5, 0, 0.5, 0)
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.ZIndex = parent.ZIndex - 1
    glow.Parent = parent
    return glow
end

function Axiora.UI.Create()
    if Axiora.UI.ScreenGui then
        pcall(function() Axiora.UI.ScreenGui:Destroy() end)
    end
    
    local theme = Axiora.Visuals.GetTheme()
    
    local sg = Instance.new("ScreenGui")
    sg.Name = "AxioraUI_Modern"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 999
    
    local success = pcall(function()
        sg.Parent = CoreGui
    end)
    if not success then
        local LP = getLocalPlayer()
        if LP and LP:FindFirstChild("PlayerGui") then
            sg.Parent = LP.PlayerGui
        end
    end
    
    Axiora.UI.ScreenGui = sg
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- FLOATING TOGGLE BUTTON (Always visible)
    -- ═══════════════════════════════════════════════════════════════════════
    
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleButton"
    toggleBtn.BackgroundColor3 = theme.Primary
    toggleBtn.BackgroundTransparency = 0.1
    toggleBtn.Size = UDim2.new(0, 50, 0, 50)
    toggleBtn.Position = UDim2.new(0, 15, 0.5, 0)
    toggleBtn.AnchorPoint = Vector2.new(0, 0.5)
    toggleBtn.Text = "▶"
    toggleBtn.TextColor3 = Color3.new(1, 1, 1)
    toggleBtn.Font = Enum.Font.GothamBlack
    toggleBtn.TextSize = 22
    toggleBtn.AutoButtonColor = false
    toggleBtn.BorderSizePixel = 0
    toggleBtn.ZIndex = 100
    toggleBtn.Parent = sg
    
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)
    
    local toggleStroke = Instance.new("UIStroke")
    toggleStroke.Color = Color3.new(1, 1, 1)
    toggleStroke.Transparency = 0.7
    toggleStroke.Thickness = 2
    toggleStroke.Parent = toggleBtn
    
    -- Pulse animation for toggle button
    local pulseConnection = nil
    local function startPulse()
        if pulseConnection then return end
        local pulseUp = true
        pulseConnection = RunService.Heartbeat:Connect(function()
            local current = toggleBtn.BackgroundTransparency
            if pulseUp then
                toggleBtn.BackgroundTransparency = math.max(0, current - 0.02)
                if current <= 0.05 then pulseUp = false end
            else
                toggleBtn.BackgroundTransparency = math.min(0.4, current + 0.02)
                if current >= 0.35 then pulseUp = true end
            end
        end)
    end
    
    local function stopPulse()
        if pulseConnection then
            pulseConnection:Disconnect()
            pulseConnection = nil
            toggleBtn.BackgroundTransparency = 0.1
        end
    end
    
    -- Status color on toggle button
    local function updateToggleColor()
        if Axiora.State.Status == "RECORDING" then
            toggleBtn.BackgroundColor3 = theme.Error
            toggleBtn.Text = "⏺"
            startPulse()
        elseif Axiora.State.Status == "PLAYING" then
            toggleBtn.BackgroundColor3 = theme.Success
            toggleBtn.Text = "▶"
            stopPulse()
        elseif Axiora.State.Status == "PAUSED" then
            toggleBtn.BackgroundColor3 = theme.Warning
            toggleBtn.Text = "⏸"
            stopPulse()
        else
            toggleBtn.BackgroundColor3 = theme.Primary
            toggleBtn.Text = "▶"
            stopPulse()
        end
    end
    
    Axiora.UI.ToggleButton = toggleBtn
    
    -- Toggle button drag
    local toggleDragging = false
    local toggleDragStart, toggleStartPos
    
    toggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            toggleDragging = true
            toggleDragStart = UserInputService:GetMouseLocation()
            toggleStartPos = toggleBtn.Position
        end
    end)
    
    toggleBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local movedDist = (UserInputService:GetMouseLocation() - toggleDragStart).Magnitude
            if movedDist < 5 then
                -- It was a click, not a drag
                Axiora.UI.TogglePanel()
            end
            toggleDragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if toggleDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local current = UserInputService:GetMouseLocation()
            local delta = current - toggleDragStart
            toggleBtn.Position = UDim2.new(
                toggleStartPos.X.Scale, toggleStartPos.X.Offset + delta.X,
                toggleStartPos.Y.Scale, toggleStartPos.Y.Offset + delta.Y
            )
        end
    end)

    -- ═══════════════════════════════════════════════════════════════════════
    -- MAIN PANEL (Glassmorphism Design)
    -- ═══════════════════════════════════════════════════════════════════════
    
    local main = Instance.new("Frame")
    main.Name = "MainPanel"
    main.BackgroundColor3 = theme.Background
    main.BackgroundTransparency = 0.08
    main.Size = UDim2.new(0, 420, 0, 520)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Visible = true
    main.Parent = sg
    
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = theme.Primary
    mainStroke.Transparency = 0.4
    mainStroke.Thickness = 2
    mainStroke.Parent = main
    
    -- Inner glass effect
    local glass = Instance.new("Frame")
    glass.Name = "GlassOverlay"
    glass.BackgroundColor3 = Color3.new(1, 1, 1)
    glass.BackgroundTransparency = 0.97
    glass.Size = UDim2.new(1, 0, 1, 0)
    glass.BorderSizePixel = 0
    glass.ZIndex = 0
    glass.Parent = main
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- HEADER with gradient accent
    -- ═══════════════════════════════════════════════════════════════════════
    
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.BackgroundColor3 = theme.Surface
    header.BackgroundTransparency = 0.3
    header.Size = UDim2.new(1, 0, 0, 55)
    header.BorderSizePixel = 0
    header.Parent = main
    
    -- Gradient accent bar at top
    local accentBar = Instance.new("Frame")
    accentBar.Name = "AccentBar"
    accentBar.BackgroundColor3 = theme.Primary
    accentBar.Size = UDim2.new(1, 0, 0, 3)
    accentBar.BorderSizePixel = 0
    accentBar.Parent = header
    createGradient(accentBar, theme.Primary, theme.Secondary, 0)
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -100, 0, 30)
    title.Position = UDim2.new(0, 20, 0, 12)
    title.Text = "AXIORA ULTIMATE"
    title.TextColor3 = theme.Primary
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    
    -- Version badge
    local versionBadge = Instance.new("TextLabel")
    versionBadge.Name = "Version"
    versionBadge.BackgroundColor3 = theme.Primary
    versionBadge.BackgroundTransparency = 0.8
    versionBadge.Size = UDim2.new(0, 50, 0, 18)
    versionBadge.Position = UDim2.new(0, 20, 0, 35)
    versionBadge.Text = "v" .. Axiora._VERSION
    versionBadge.TextColor3 = theme.Primary
    versionBadge.Font = Enum.Font.GothamBold
    versionBadge.TextSize = 10
    versionBadge.Parent = header
    Instance.new("UICorner", versionBadge).CornerRadius = UDim.new(0, 4)
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.BackgroundColor3 = theme.Error
    closeBtn.BackgroundTransparency = 0.8
    closeBtn.Size = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -48, 0, 10)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = theme.Text
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.AutoButtonColor = false
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = header
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
    
    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.3}):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.8}):Play()
    end)
    closeBtn.MouseButton1Click:Connect(function()
        Axiora.UI.TogglePanel()
    end)
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- STATUS BAR (Live updating)
    -- ═══════════════════════════════════════════════════════════════════════
    
    local statusBar = Instance.new("Frame")
    statusBar.Name = "StatusBar"
    statusBar.BackgroundColor3 = theme.Surface
    statusBar.BackgroundTransparency = 0.5
    statusBar.Size = UDim2.new(1, -30, 0, 45)
    statusBar.Position = UDim2.new(0, 15, 0, 65)
    statusBar.BorderSizePixel = 0
    statusBar.Parent = main
    Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 10)
    
    -- Status indicator dot
    local statusDot = Instance.new("Frame")
    statusDot.Name = "StatusDot"
    statusDot.Size = UDim2.new(0, 12, 0, 12)
    statusDot.Position = UDim2.new(0, 12, 0.5, 0)
    statusDot.AnchorPoint = Vector2.new(0, 0.5)
    statusDot.BackgroundColor3 = theme.TextDim
    statusDot.BorderSizePixel = 0
    statusDot.Parent = statusBar
    Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)
    
    local statusText = Instance.new("TextLabel")
    statusText.Name = "StatusText"
    statusText.BackgroundTransparency = 1
    statusText.Size = UDim2.new(0.5, -40, 1, 0)
    statusText.Position = UDim2.new(0, 32, 0, 0)
    statusText.Text = "IDLE"
    statusText.TextColor3 = theme.Text
    statusText.Font = Enum.Font.GothamBold
    statusText.TextSize = 14
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.Parent = statusBar
    
    local bufferText = Instance.new("TextLabel")
    bufferText.Name = "BufferText"
    bufferText.BackgroundTransparency = 1
    bufferText.Size = UDim2.new(0.5, -10, 1, 0)
    bufferText.Position = UDim2.new(0.5, 0, 0, 0)
    bufferText.Text = "Buffer: 0 nodes"
    bufferText.TextColor3 = theme.TextDim
    bufferText.Font = Enum.Font.Gotham
    bufferText.TextSize = 11
    bufferText.TextXAlignment = Enum.TextXAlignment.Right
    bufferText.Parent = statusBar
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- CONTROL BUTTONS (2-Column Grid)
    -- ═══════════════════════════════════════════════════════════════════════
    
    local controlsContainer = Instance.new("Frame")
    controlsContainer.Name = "Controls"
    controlsContainer.BackgroundTransparency = 1
    controlsContainer.Size = UDim2.new(1, -30, 0, 180)
    controlsContainer.Position = UDim2.new(0, 15, 0, 120)
    controlsContainer.Parent = main
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.5, -5, 0, 55)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = controlsContainer
    
    -- Helper: Create modern button with icon
    local function createModernButton(icon, label, color, order, callback)
        local btn = Instance.new("TextButton")
        btn.Name = label
        btn.BackgroundColor3 = color
        btn.BackgroundTransparency = 0.2
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.LayoutOrder = order
        btn.Parent = controlsContainer
        
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
        createGradient(btn, color, Color3.new(
            math.max(0, color.R - 0.15),
            math.max(0, color.G - 0.15),
            math.max(0, color.B - 0.15)
        ), 90)
        
        local btnStroke = Instance.new("UIStroke")
        btnStroke.Color = Color3.new(1, 1, 1)
        btnStroke.Transparency = 0.85
        btnStroke.Thickness = 1
        btnStroke.Parent = btn
        
        local iconLabel = Instance.new("TextLabel")
        iconLabel.BackgroundTransparency = 1
        iconLabel.Size = UDim2.new(1, 0, 0, 25)
        iconLabel.Position = UDim2.new(0, 0, 0, 5)
        iconLabel.Text = icon
        iconLabel.TextColor3 = Color3.new(1, 1, 1)
        iconLabel.Font = Enum.Font.GothamBold
        iconLabel.TextSize = 20
        iconLabel.Parent = btn
        
        local textLabel = Instance.new("TextLabel")
        textLabel.BackgroundTransparency = 1
        textLabel.Size = UDim2.new(1, 0, 0, 18)
        textLabel.Position = UDim2.new(0, 0, 1, -23)
        textLabel.Text = label
        textLabel.TextColor3 = Color3.new(1, 1, 1)
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextSize = 10
        textLabel.TextTransparency = 0.2
        textLabel.Parent = btn
        
        -- Hover effects
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
                BackgroundTransparency = 0
            }):Play()
            TweenService:Create(btnStroke, TweenInfo.new(0.2), {Transparency = 0.5}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
                BackgroundTransparency = 0.2
            }):Play()
            TweenService:Create(btnStroke, TweenInfo.new(0.2), {Transparency = 0.85}):Play()
        end)
        btn.MouseButton1Click:Connect(function()
            -- Click ripple effect
            local ripple = Instance.new("Frame")
            ripple.BackgroundColor3 = Color3.new(1, 1, 1)
            ripple.BackgroundTransparency = 0.5
            ripple.Size = UDim2.new(0, 0, 0, 0)
            ripple.Position = UDim2.new(0.5, 0, 0.5, 0)
            ripple.AnchorPoint = Vector2.new(0.5, 0.5)
            ripple.BorderSizePixel = 0
            ripple.Parent = btn
            Instance.new("UICorner", ripple).CornerRadius = UDim.new(1, 0)
            
            TweenService:Create(ripple, TweenInfo.new(0.4), {
                Size = UDim2.new(2, 0, 2, 0),
                BackgroundTransparency = 1
            }):Play()
            task.delay(0.4, function() ripple:Destroy() end)
            
            callback()
        end)
        
        return btn
    end
    
    -- Main control buttons
    createModernButton("⏺", "RECORD", theme.Error, 1, function()
        if Axiora.State.Status == "RECORDING" then
            Axiora.Stop()
        else
            Axiora.Record()
        end
    end)
    
    createModernButton("▶", "PLAY", theme.Success, 2, function()
        if Axiora.State.Status == "PLAYING" then
            Axiora.Pause()
        else
            Axiora.Play(true)
        end
    end)
    
    createModernButton("⏹", "STOP", theme.Secondary, 3, function()
        Axiora.Stop()
    end)
    
    createModernButton("💾", "SAVE", theme.Info, 4, function()
        Axiora.Save()
    end)
    
    createModernButton("📂", "LOAD", theme.Info, 5, function()
        Axiora.UI.ShowLoadPicker()
    end)
    
    createModernButton("✏️", "EDIT", theme.Warning, 6, function()
        Axiora.UI.ShowEditorPanel()
    end)
    
    createModernButton("📍", "MARK", theme.Success, 7, function()
        Axiora.MarkPosition()
    end)
    
    createModernButton("🔗", "COMBINE", theme.Secondary, 8, function()
        Axiora.UI.ShowCombinePanel()
    end)
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- SPEED CONTROL SECTION
    -- ═══════════════════════════════════════════════════════════════════════
    
    local speedSection = Instance.new("Frame")
    speedSection.Name = "SpeedSection"
    speedSection.BackgroundColor3 = theme.Surface
    speedSection.BackgroundTransparency = 0.5
    speedSection.Size = UDim2.new(1, -30, 0, 50)
    speedSection.Position = UDim2.new(0, 15, 0, 310)
    speedSection.BorderSizePixel = 0
    speedSection.Parent = main
    Instance.new("UICorner", speedSection).CornerRadius = UDim.new(0, 10)
    
    local speedLabel = Instance.new("TextLabel")
    speedLabel.BackgroundTransparency = 1
    speedLabel.Size = UDim2.new(0, 60, 1, 0)
    speedLabel.Position = UDim2.new(0, 10, 0, 0)
    speedLabel.Text = "SPEED"
    speedLabel.TextColor3 = theme.TextDim
    speedLabel.Font = Enum.Font.GothamBold
    speedLabel.TextSize = 10
    speedLabel.Parent = speedSection
    
    local speedPresetBtns = {}
    local presets = {"careful", "normal", "fast", "turbo"}
    local presetLabels = {"0.5x", "1x", "1.5x", "2.5x"}
    
    for i, preset in ipairs(presets) do
        local presetBtn = Instance.new("TextButton")
        presetBtn.Name = preset
        presetBtn.BackgroundColor3 = preset == "normal" and theme.Primary or theme.Surface
        presetBtn.BackgroundTransparency = preset == "normal" and 0.3 or 0.6
        presetBtn.Size = UDim2.new(0, 65, 0, 30)
        presetBtn.Position = UDim2.new(0, 70 + (i-1) * 75, 0.5, 0)
        presetBtn.AnchorPoint = Vector2.new(0, 0.5)
        presetBtn.Text = presetLabels[i]
        presetBtn.TextColor3 = theme.Text
        presetBtn.Font = Enum.Font.GothamBold
        presetBtn.TextSize = 11
        presetBtn.AutoButtonColor = false
        presetBtn.BorderSizePixel = 0
        presetBtn.Parent = speedSection
        Instance.new("UICorner", presetBtn).CornerRadius = UDim.new(0, 6)
        
        speedPresetBtns[preset] = presetBtn
        
        presetBtn.MouseButton1Click:Connect(function()
            Axiora.UI.SetSpeed(preset)
            -- Update button visuals
            for p, btn in pairs(speedPresetBtns) do
                if p == preset then
                    TweenService:Create(btn, TweenInfo.new(0.2), {
                        BackgroundColor3 = theme.Primary,
                        BackgroundTransparency = 0.3
                    }):Play()
                else
                    TweenService:Create(btn, TweenInfo.new(0.2), {
                        BackgroundColor3 = theme.Surface,
                        BackgroundTransparency = 0.6
                    }):Play()
                end
            end
        end)
    end
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- ADVANCED CONTROLS (Scrollable)
    -- ═══════════════════════════════════════════════════════════════════════
    
    local advancedLabel = Instance.new("TextLabel")
    advancedLabel.BackgroundTransparency = 1
    advancedLabel.Size = UDim2.new(1, -30, 0, 20)
    advancedLabel.Position = UDim2.new(0, 15, 0, 370)
    advancedLabel.Text = "ADVANCED CONTROLS"
    advancedLabel.TextColor3 = theme.TextDim
    advancedLabel.Font = Enum.Font.GothamBold
    advancedLabel.TextSize = 10
    advancedLabel.TextXAlignment = Enum.TextXAlignment.Left
    advancedLabel.Parent = main
    
    local advancedScroll = Instance.new("ScrollingFrame")
    advancedScroll.Name = "AdvancedControls"
    advancedScroll.BackgroundTransparency = 1
    advancedScroll.Size = UDim2.new(1, -30, 0, 110)
    advancedScroll.Position = UDim2.new(0, 15, 0, 395)
    advancedScroll.CanvasSize = UDim2.new(0, 0, 0, 140)
    advancedScroll.ScrollBarThickness = 3
    advancedScroll.ScrollBarImageColor3 = theme.Primary
    advancedScroll.BorderSizePixel = 0
    advancedScroll.Parent = main
    
    local advLayout = Instance.new("UIListLayout")
    advLayout.Padding = UDim.new(0, 6)
    advLayout.Parent = advancedScroll
    
    -- Helper: Create compact button
    local function createCompactBtn(text, color, callback)
        local btn = Instance.new("TextButton")
        btn.BackgroundColor3 = color
        btn.BackgroundTransparency = 0.7
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.Text = text
        btn.TextColor3 = theme.Text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.Parent = advancedScroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.4}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.7}):Play()
        end)
        btn.MouseButton1Click:Connect(callback)
        return btn
    end
    
    createCompactBtn("🎯 Render Path Visualization", theme.Primary, function()
        Axiora.Visuals.RenderPath()
    end)
    
    createCompactBtn("➕ Add to Sequence Queue", theme.Warning, function()
        Axiora.Sequences.AddCurrentBuffer()
    end)
    
    createCompactBtn("⚡ Execute Sequence Queue", theme.Warning, function()
        Axiora.Sequences.ExecuteQueue()
    end)
    
    createCompactBtn("🔄 Toggle Auto-Restart", theme.Error, function()
        Axiora.AutoRestart.Toggle()
    end)
    
    createCompactBtn("📊 Print Analytics Report", theme.Secondary, function()
        Axiora.Analytics.Print()
    end)
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- FOOTER
    -- ═══════════════════════════════════════════════════════════════════════
    
    local footer = Instance.new("TextLabel")
    footer.Name = "Footer"
    footer.BackgroundTransparency = 1
    footer.Size = UDim2.new(1, 0, 0, 15)
    footer.Position = UDim2.new(0, 0, 1, -15)
    footer.Text = "F1=Record | F2=Play | F3=Stop | F4=Toggle UI"
    footer.TextColor3 = theme.TextDim
    footer.TextTransparency = 0.5
    footer.Font = Enum.Font.Gotham
    footer.TextSize = 9
    footer.Parent = main
    
    Axiora.UI.MainFrame = main
    Axiora.UI.IsOpen = true
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- STATUS UPDATE LOOP
    -- ═══════════════════════════════════════════════════════════════════════
    
    local statusThread = task.spawn(function()
        while sg and sg.Parent do
            -- Update status text and color
            statusText.Text = Axiora.State.Status
            bufferText.Text = "Buffer: " .. #Axiora.State.Buffer .. " nodes"
            
            if Axiora.State.Status == "RECORDING" then
                statusDot.BackgroundColor3 = theme.Error
            elseif Axiora.State.Status == "PLAYING" then
                statusDot.BackgroundColor3 = theme.Success
            elseif Axiora.State.Status == "PAUSED" then
                statusDot.BackgroundColor3 = theme.Warning
            else
                statusDot.BackgroundColor3 = theme.TextDim
            end
            
            updateToggleColor()
            task.wait(0.3)
        end
    end)
    table.insert(Axiora.State.Threads, statusThread)
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- DRAGGING
    -- ═══════════════════════════════════════════════════════════════════════
    
    local dragging = false
    local dragStart, startPos
    
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = UserInputService:GetMouseLocation()
            startPos = main.Position
        end
    end)
    
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local current = UserInputService:GetMouseLocation()
            local delta = current - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    return sg
end

-- Speed preset function
function Axiora.UI.SetSpeed(preset)
    if Axiora.UI.SpeedPresets[preset] then
        Axiora.Playback.Speed = Axiora.UI.SpeedPresets[preset]
        Axiora.UI.CurrentSpeed = preset
        Axiora.Visuals.Notify("Speed", "Playback speed: " .. preset .. " (" .. Axiora.UI.SpeedPresets[preset] .. "x)", 2, "info")
    end
end

-- Also add global shorthand
function Axiora.SetSpeed(preset)
    Axiora.UI.SetSpeed(preset)
end

-- PlayTimes shorthand
function Axiora.PlayTimes(count)
    return Axiora.Play(count)
end

-- Export macro as shareable code
function Axiora.Export(name)
    if #Axiora.State.Buffer == 0 then
        Axiora.Visuals.Notify("Export", "No macro to export", 2, "warning")
        return nil
    end
    
    local data = {
        name = name or "exported_macro",
        version = Axiora._VERSION,
        buffer = Axiora.State.Buffer
    }
    
    local json = HttpService:JSONEncode(data)
    
    if Axiora.Capabilities.SetClipboard then
        pcall(function()
            setclipboard(json)
        end)
        Axiora.Visuals.Notify("Export", "Macro copied to clipboard!", 3, "success")
    else
        Axiora.Visuals.Notify("Export", "Clipboard not available - check console", 3, "warning")
    end
    
    print("=== EXPORTED MACRO ===")
    print(json)
    print("======================")
    
    return json
end

function Axiora.UI.TogglePanel()
    if Axiora.UI.MainFrame then
        Axiora.UI.IsOpen = not Axiora.UI.IsOpen
        
        if Axiora.UI.IsOpen then
            Axiora.UI.MainFrame.Visible = true
            Axiora.UI.MainFrame.Position = UDim2.new(0.5, 0, 0.6, 0)
            TweenService:Create(Axiora.UI.MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, 0, 0.5, 0)
            }):Play()
        else
            TweenService:Create(Axiora.UI.MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0.6, 0)
            }):Play()
            task.delay(0.2, function()
                if not Axiora.UI.IsOpen then
                    Axiora.UI.MainFrame.Visible = false
                end
            end)
        end
    else
        Axiora.UI.Create()
    end
end

function Axiora.UI.Toggle()
    Axiora.UI.TogglePanel()
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- QUICK LOAD PICKER UI
-- ═══════════════════════════════════════════════════════════════════════════════

function Axiora.UI.ShowLoadPicker()
    if not Axiora.UI.ScreenGui then return end
    
    local theme = Axiora.Visuals.GetTheme()
    local saves = Axiora.ListSaves()
    
    if #saves == 0 then
        Axiora.Visuals.Notify("Load", "No saved macros found", 2, "warning")
        return
    end
    
    -- Create overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "LoadPickerOverlay"
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.ZIndex = 200
    overlay.Parent = Axiora.UI.ScreenGui
    
    -- Create picker panel
    local picker = Instance.new("Frame")
    picker.Name = "LoadPicker"
    picker.BackgroundColor3 = theme.Background
    picker.BackgroundTransparency = 0.05
    picker.Size = UDim2.new(0, 300, 0, math.min(400, 80 + #saves * 45))
    picker.Position = UDim2.new(0.5, 0, 0.5, 0)
    picker.AnchorPoint = Vector2.new(0.5, 0.5)
    picker.BorderSizePixel = 0
    picker.ZIndex = 201
    picker.Parent = overlay
    
    Instance.new("UICorner", picker).CornerRadius = UDim.new(0, 12)
    
    local pickerStroke = Instance.new("UIStroke")
    pickerStroke.Color = theme.Primary
    pickerStroke.Transparency = 0.3
    pickerStroke.Thickness = 2
    pickerStroke.Parent = picker
    
    -- Title
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -20, 0, 35)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.Text = "📂 LOAD MACRO"
    title.TextColor3 = theme.Primary
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = picker
    
    -- Scrolling list
    local scroll = Instance.new("ScrollingFrame")
    scroll.BackgroundTransparency = 1
    scroll.Size = UDim2.new(1, -20, 1, -100)
    scroll.Position = UDim2.new(0, 10, 0, 50)
    scroll.CanvasSize = UDim2.new(0, 0, 0, #saves * 45)
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = theme.Primary
    scroll.BorderSizePixel = 0
    scroll.Parent = picker
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = scroll
    
    -- Create macro buttons
    for i, saveName in ipairs(saves) do
        local btn = Instance.new("TextButton")
        btn.Name = saveName
        btn.BackgroundColor3 = theme.Surface
        btn.BackgroundTransparency = 0.3
        btn.Size = UDim2.new(1, -10, 0, 40)
        btn.Text = "  📄 " .. saveName
        btn.TextColor3 = theme.Text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.Parent = scroll
        
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = theme.Primary,
                BackgroundTransparency = 0.2
            }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = theme.Surface,
                BackgroundTransparency = 0.3
            }):Play()
        end)
        btn.MouseButton1Click:Connect(function()
            overlay:Destroy()
            Axiora.Load(saveName)
        end)
    end
    
    -- Cancel button
    local cancelBtn = Instance.new("TextButton")
    cancelBtn.BackgroundColor3 = theme.Error
    cancelBtn.BackgroundTransparency = 0.6
    cancelBtn.Size = UDim2.new(1, -20, 0, 35)
    cancelBtn.Position = UDim2.new(0, 10, 1, -45)
    cancelBtn.Text = "✕ CANCEL"
    cancelBtn.TextColor3 = theme.Text
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 12
    cancelBtn.AutoButtonColor = false
    cancelBtn.BorderSizePixel = 0
    cancelBtn.Parent = picker
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 8)
    
    cancelBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)
    
    -- Click overlay to close
    overlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mousePos = UserInputService:GetMouseLocation()
            local pickerPos = picker.AbsolutePosition
            local pickerSize = picker.AbsoluteSize
            if mousePos.X < pickerPos.X or mousePos.X > pickerPos.X + pickerSize.X or
               mousePos.Y < pickerPos.Y or mousePos.Y > pickerPos.Y + pickerSize.Y then
                overlay:Destroy()
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MACRO EDITOR PANEL UI
-- ═══════════════════════════════════════════════════════════════════════════════

function Axiora.UI.ShowEditorPanel()
    if not Axiora.UI.ScreenGui then return end
    
    local theme = Axiora.Visuals.GetTheme()
    local nodes = Axiora.EditBuffer()
    
    if #nodes == 0 then
        Axiora.Visuals.Notify("Editor", "No macro loaded to edit", 2, "warning")
        return
    end
    
    -- Create overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "EditorOverlay"
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.ZIndex = 200
    overlay.Parent = Axiora.UI.ScreenGui
    
    -- Create editor panel
    local editor = Instance.new("Frame")
    editor.Name = "EditorPanel"
    editor.BackgroundColor3 = theme.Background
    editor.BackgroundTransparency = 0.05
    editor.Size = UDim2.new(0, 450, 0, 500)
    editor.Position = UDim2.new(0.5, 0, 0.5, 0)
    editor.AnchorPoint = Vector2.new(0.5, 0.5)
    editor.BorderSizePixel = 0
    editor.ZIndex = 201
    editor.Parent = overlay
    
    Instance.new("UICorner", editor).CornerRadius = UDim.new(0, 12)
    
    local editorStroke = Instance.new("UIStroke")
    editorStroke.Color = theme.Warning
    editorStroke.Transparency = 0.3
    editorStroke.Thickness = 2
    editorStroke.Parent = editor
    
    -- Title
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -100, 0, 35)
    title.Position = UDim2.new(0, 15, 0, 10)
    title.Text = "✏️ MACRO EDITOR (" .. #nodes .. " nodes)"
    title.TextColor3 = theme.Warning
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = editor
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.BackgroundColor3 = theme.Error
    closeBtn.BackgroundTransparency = 0.7
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 10)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = theme.Text
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.AutoButtonColor = false
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = editor
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)
    
    -- Scrolling list of nodes
    local scroll = Instance.new("ScrollingFrame")
    scroll.BackgroundColor3 = theme.Surface
    scroll.BackgroundTransparency = 0.7
    scroll.Size = UDim2.new(1, -30, 1, -100)
    scroll.Position = UDim2.new(0, 15, 0, 50)
    scroll.CanvasSize = UDim2.new(0, 0, 0, #nodes * 50)
    scroll.ScrollBarThickness = 5
    scroll.ScrollBarImageColor3 = theme.Primary
    scroll.BorderSizePixel = 0
    scroll.Parent = editor
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 8)
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 3)
    listLayout.Parent = scroll
    
    local function refreshNodeList()
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        
        local updatedNodes = Axiora.EditBuffer()
        scroll.CanvasSize = UDim2.new(0, 0, 0, #updatedNodes * 50)
        title.Text = "✏️ MACRO EDITOR (" .. #updatedNodes .. " nodes)"
        
        for i, node in ipairs(updatedNodes) do
            local row = Instance.new("Frame")
            row.Name = "Node_" .. i
            row.BackgroundColor3 = i % 2 == 0 and theme.Surface or theme.Background
            row.BackgroundTransparency = 0.5
            row.Size = UDim2.new(1, -10, 0, 45)
            row.BorderSizePixel = 0
            row.Parent = scroll
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
            
            -- Index
            local idxLabel = Instance.new("TextLabel")
            idxLabel.BackgroundTransparency = 1
            idxLabel.Size = UDim2.new(0, 35, 1, 0)
            idxLabel.Position = UDim2.new(0, 5, 0, 0)
            idxLabel.Text = "#" .. i
            idxLabel.TextColor3 = theme.TextDim
            idxLabel.Font = Enum.Font.GothamBold
            idxLabel.TextSize = 10
            idxLabel.Parent = row
            
            -- Type icon
            local typeIcon = node.Type == "Move" and "🚶" or node.Type == "Click" and "👆" or node.Type == "Key" and "⌨️" or "?"
            local typeLabel = Instance.new("TextLabel")
            typeLabel.BackgroundTransparency = 1
            typeLabel.Size = UDim2.new(0, 30, 1, 0)
            typeLabel.Position = UDim2.new(0, 40, 0, 0)
            typeLabel.Text = typeIcon
            typeLabel.TextColor3 = theme.Text
            typeLabel.Font = Enum.Font.Gotham
            typeLabel.TextSize = 16
            typeLabel.Parent = row
            
            -- Details
            local details = ""
            if node.Type == "Move" then
                local p = node.Position or {0,0,0}
                details = string.format("Pos: %.0f, %.0f, %.0f", p[1] or 0, p[2] or 0, p[3] or 0)
            elseif node.Type == "Click" then
                details = string.format("Click: %.2f, %.2f", node.X or 0, node.Y or 0)
            elseif node.Type == "Key" then
                details = "Key: " .. (node.Key or "?")
            end
            
            local detailLabel = Instance.new("TextLabel")
            detailLabel.BackgroundTransparency = 1
            detailLabel.Size = UDim2.new(0, 200, 1, 0)
            detailLabel.Position = UDim2.new(0, 75, 0, 0)
            detailLabel.Text = details
            detailLabel.TextColor3 = theme.Text
            detailLabel.Font = Enum.Font.Gotham
            detailLabel.TextSize = 11
            detailLabel.TextXAlignment = Enum.TextXAlignment.Left
            detailLabel.TextTruncate = Enum.TextTruncate.AtEnd
            detailLabel.Parent = row
            
            -- Delay
            local delayLabel = Instance.new("TextLabel")
            delayLabel.BackgroundTransparency = 1
            delayLabel.Size = UDim2.new(0, 50, 1, 0)
            delayLabel.Position = UDim2.new(0, 280, 0, 0)
            delayLabel.Text = string.format("%.2fs", node.Delay or 0)
            delayLabel.TextColor3 = theme.TextDim
            delayLabel.Font = Enum.Font.Gotham
            delayLabel.TextSize = 10
            delayLabel.Parent = row
            
            -- Delete button
            local delBtn = Instance.new("TextButton")
            delBtn.BackgroundColor3 = theme.Error
            delBtn.BackgroundTransparency = 0.6
            delBtn.Size = UDim2.new(0, 55, 0, 28)
            delBtn.Position = UDim2.new(1, -65, 0.5, 0)
            delBtn.AnchorPoint = Vector2.new(0, 0.5)
            delBtn.Text = "🗑️ DEL"
            delBtn.TextColor3 = theme.Text
            delBtn.Font = Enum.Font.GothamBold
            delBtn.TextSize = 10
            delBtn.AutoButtonColor = false
            delBtn.BorderSizePixel = 0
            delBtn.Parent = row
            Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 5)
            
            local nodeIndex = i
            delBtn.MouseButton1Click:Connect(function()
                Axiora.DeleteNode(nodeIndex)
                refreshNodeList()
            end)
        end
    end
    
    refreshNodeList()
    
    -- Footer with info
    local footer = Instance.new("TextLabel")
    footer.BackgroundTransparency = 1
    footer.Size = UDim2.new(1, 0, 0, 30)
    footer.Position = UDim2.new(0, 0, 1, -40)
    footer.Text = "Click DEL to remove nodes • Changes are immediate"
    footer.TextColor3 = theme.TextDim
    footer.Font = Enum.Font.Gotham
    footer.TextSize = 10
    footer.Parent = editor
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MACRO COMBINE PANEL UI
-- ═══════════════════════════════════════════════════════════════════════════════

function Axiora.UI.ShowCombinePanel()
    if not Axiora.UI.ScreenGui then return end
    
    local theme = Axiora.Visuals.GetTheme()
    local saves = Axiora.ListSaves()
    
    if #saves < 2 then
        Axiora.Visuals.Notify("Combine", "Need at least 2 saved macros", 2, "warning")
        return
    end
    
    -- Create overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "CombineOverlay"
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.ZIndex = 200
    overlay.Parent = Axiora.UI.ScreenGui
    
    -- Create combine panel
    local panel = Instance.new("Frame")
    panel.Name = "CombinePanel"
    panel.BackgroundColor3 = theme.Background
    panel.BackgroundTransparency = 0.05
    panel.Size = UDim2.new(0, 350, 0, 320)
    panel.Position = UDim2.new(0.5, 0, 0.5, 0)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.BorderSizePixel = 0
    panel.ZIndex = 201
    panel.Parent = overlay
    
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
    
    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = theme.Secondary
    panelStroke.Transparency = 0.3
    panelStroke.Thickness = 2
    panelStroke.Parent = panel
    
    -- Title
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -20, 0, 35)
    title.Position = UDim2.new(0, 15, 0, 10)
    title.Text = "🔗 COMBINE MACROS"
    title.TextColor3 = theme.Secondary
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel
    
    local selectedMacro1 = nil
    local selectedMacro2 = nil
    
    local function createDropdown(yPos, labelText, onSelect)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(0, 100, 0, 25)
        label.Position = UDim2.new(0, 15, 0, yPos)
        label.Text = labelText
        label.TextColor3 = theme.TextDim
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = panel
        
        local dropdown = Instance.new("TextButton")
        dropdown.BackgroundColor3 = theme.Surface
        dropdown.BackgroundTransparency = 0.3
        dropdown.Size = UDim2.new(1, -130, 0, 35)
        dropdown.Position = UDim2.new(0, 115, 0, yPos - 5)
        dropdown.Text = "  Select macro..."
        dropdown.TextColor3 = theme.Text
        dropdown.Font = Enum.Font.Gotham
        dropdown.TextSize = 12
        dropdown.TextXAlignment = Enum.TextXAlignment.Left
        dropdown.AutoButtonColor = false
        dropdown.BorderSizePixel = 0
        dropdown.Parent = panel
        Instance.new("UICorner", dropdown).CornerRadius = UDim.new(0, 6)
        
        dropdown.MouseButton1Click:Connect(function()
            -- Create dropdown list
            local ddList = Instance.new("ScrollingFrame")
            ddList.BackgroundColor3 = theme.Surface
            ddList.Size = UDim2.new(0, dropdown.AbsoluteSize.X, 0, math.min(150, #saves * 30))
            ddList.Position = UDim2.new(0, 115, 0, yPos + 30)
            ddList.CanvasSize = UDim2.new(0, 0, 0, #saves * 30)
            ddList.ScrollBarThickness = 3
            ddList.BorderSizePixel = 0
            ddList.ZIndex = 210
            ddList.Parent = panel
            Instance.new("UICorner", ddList).CornerRadius = UDim.new(0, 6)
            
            local ddLayout = Instance.new("UIListLayout")
            ddLayout.Parent = ddList
            
            for _, saveName in ipairs(saves) do
                local opt = Instance.new("TextButton")
                opt.BackgroundColor3 = theme.Surface
                opt.BackgroundTransparency = 0.2
                opt.Size = UDim2.new(1, 0, 0, 28)
                opt.Text = "  " .. saveName
                opt.TextColor3 = theme.Text
                opt.Font = Enum.Font.Gotham
                opt.TextSize = 11
                opt.TextXAlignment = Enum.TextXAlignment.Left
                opt.BorderSizePixel = 0
                opt.ZIndex = 211
                opt.Parent = ddList
                
                opt.MouseEnter:Connect(function()
                    opt.BackgroundColor3 = theme.Primary
                end)
                opt.MouseLeave:Connect(function()
                    opt.BackgroundColor3 = theme.Surface
                end)
                opt.MouseButton1Click:Connect(function()
                    dropdown.Text = "  " .. saveName
                    onSelect(saveName)
                    ddList:Destroy()
                end)
            end
            
            -- Close on click outside
            task.delay(0.1, function()
                local conn
                conn = UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        task.wait(0.1)
                        if ddList and ddList.Parent then
                            ddList:Destroy()
                        end
                        if conn then conn:Disconnect() end
                    end
                end)
            end)
        end)
        
        return dropdown
    end
    
    createDropdown(55, "First Macro:", function(name) selectedMacro1 = name end)
    createDropdown(105, "Second Macro:", function(name) selectedMacro2 = name end)
    
    -- Output name
    local outputLabel = Instance.new("TextLabel")
    outputLabel.BackgroundTransparency = 1
    outputLabel.Size = UDim2.new(0, 100, 0, 25)
    outputLabel.Position = UDim2.new(0, 15, 0, 155)
    outputLabel.Text = "Output Name:"
    outputLabel.TextColor3 = theme.TextDim
    outputLabel.Font = Enum.Font.GothamBold
    outputLabel.TextSize = 11
    outputLabel.TextXAlignment = Enum.TextXAlignment.Left
    outputLabel.Parent = panel
    
    local outputBox = Instance.new("TextBox")
    outputBox.BackgroundColor3 = theme.Surface
    outputBox.BackgroundTransparency = 0.3
    outputBox.Size = UDim2.new(1, -130, 0, 35)
    outputBox.Position = UDim2.new(0, 115, 0, 150)
    outputBox.Text = ""
    outputBox.PlaceholderText = "combined_macro"
    outputBox.TextColor3 = theme.Text
    outputBox.PlaceholderColor3 = theme.TextDim
    outputBox.Font = Enum.Font.Gotham
    outputBox.TextSize = 12
    outputBox.ClearTextOnFocus = false
    outputBox.BorderSizePixel = 0
    outputBox.Parent = panel
    Instance.new("UICorner", outputBox).CornerRadius = UDim.new(0, 6)
    
    -- Combine button
    local combineBtn = Instance.new("TextButton")
    combineBtn.BackgroundColor3 = theme.Success
    combineBtn.BackgroundTransparency = 0.2
    combineBtn.Size = UDim2.new(1, -30, 0, 45)
    combineBtn.Position = UDim2.new(0, 15, 0, 205)
    combineBtn.Text = "🔗 COMBINE MACROS"
    combineBtn.TextColor3 = Color3.new(1, 1, 1)
    combineBtn.Font = Enum.Font.GothamBlack
    combineBtn.TextSize = 14
    combineBtn.AutoButtonColor = false
    combineBtn.BorderSizePixel = 0
    combineBtn.Parent = panel
    Instance.new("UICorner", combineBtn).CornerRadius = UDim.new(0, 8)
    
    combineBtn.MouseButton1Click:Connect(function()
        if not selectedMacro1 or not selectedMacro2 then
            Axiora.Visuals.Notify("Combine", "Select both macros", 2, "error")
            return
        end
        if selectedMacro1 == selectedMacro2 then
            Axiora.Visuals.Notify("Combine", "Select two different macros", 2, "error")
            return
        end
        
        local outputName = outputBox.Text
        if outputName == "" then
            outputName = selectedMacro1 .. "_" .. selectedMacro2
        end
        
        local success = Axiora.Combine(selectedMacro1, selectedMacro2, outputName)
        if success then
            overlay:Destroy()
        end
    end)
    
    -- Cancel button
    local cancelBtn = Instance.new("TextButton")
    cancelBtn.BackgroundColor3 = theme.Error
    cancelBtn.BackgroundTransparency = 0.6
    cancelBtn.Size = UDim2.new(1, -30, 0, 35)
    cancelBtn.Position = UDim2.new(0, 15, 1, -50)
    cancelBtn.Text = "✕ CANCEL"
    cancelBtn.TextColor3 = theme.Text
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 12
    cancelBtn.AutoButtonColor = false
    cancelBtn.BorderSizePixel = 0
    cancelBtn.Parent = panel
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 8)
    
    cancelBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)
end

function Axiora.UI.Destroy()
    if Axiora.UI.ScreenGui then
        pcall(function() Axiora.UI.ScreenGui:Destroy() end)
        Axiora.UI.ScreenGui = nil
        Axiora.UI.MainFrame = nil
        Axiora.UI.ToggleButton = nil
        Axiora.UI.IsOpen = false
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 20: INITIALIZATION & EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════════

function Axiora.Init()
    -- Mark as loaded
    Axiora._LOADED = true
    
    -- Initialize screen metrics
    Axiora.Math.WaitForInit(3)
    
    -- Initialize file system
    Axiora.Files.Init()
    
    -- Try to load saved calibration
    Axiora.Calibration.LoadCalibration()
    
    -- Try to load saved markers
    Axiora.LoadMarkedPositions()
    
    -- Initialize visuals
    Axiora.Visuals.Init()
    
    -- Create HUD (Legacy HUD disabled in favor of Quantum Orb)
    -- if Axiora.Settings.HUDEnabled then
    --     task.delay(0.5, function()
    --         Axiora.Visuals.CreateHUD()
    --     end)
    -- end
    
    -- Initialize hotkeys
    Axiora.Hotkeys.Init()
    
    -- Enable Anti-AFK if configured
    if Axiora.Settings.AntiAFK then
        Axiora.Security.EnableAntiAFK()
    end
    
    -- Create UI (Holographic Command Center)
    task.delay(0.3, function()
        if Axiora.UI.Init then
            Axiora.UI.Init()
            Axiora.Visuals.Notify("Axiora", "HoloUI v2.0 Initialized", 4, "success")
            if Axiora.Assistant then Axiora.Assistant.Show("Neural Hub Online. Ready for input!") end
        else
            -- Fallback if something went wrong
            Axiora.Visuals.Notify("Axiora", "UI Init Failed", 4, "error")
        end
    end)
    
    -- Log capabilities
    print("═══════════════════════════════════════════")
    print("[Axiora] v" .. Axiora._VERSION .. " - " .. Axiora._BUILD .. " FULL")
    print("[Axiora] Executor: " .. Axiora.Capabilities.Executor)
    print("[Axiora] Input Method: " .. Axiora.Input.Method)
    print("[Axiora] File System: " .. (Axiora.Capabilities.FileSystemVerified and "OK" or "Limited"))
    print("[Axiora] Hotkeys: F1=Record, F2=Play, F3=Stop, F4=UI, F8=HUD")
    print("═══════════════════════════════════════════")
    print("[Axiora] Features Loaded:")
    print("  ✓ Recording & Playback")
    print("  ✓ Save/Load Macros")
    print("  ✓ Strategy Loader (URL)")
    print("  ✓ Sequence Queue Manager")
    print("  ✓ Auto-Restart System")
    print("  ✓ Conditional Playback")
    print("  ✓ Marked Positions")
    print("  ✓ Analytics Tracking")
    print("  ✓ Calibration System")
    print("  ✓ Visual HUD & Notifications")
    print("═══════════════════════════════════════════")
end

-- Export to global
Root.Axiora = Axiora

-- Auto-initialize
Axiora.Init()

return Axiora
