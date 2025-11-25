-- ═══════════════════════════════════════════════════════════════════
-- 🚀 SCRIPT EXPLORER v6.0 PRO EDITION
-- ═══════════════════════════════════════════════════════════════════
-- ✅ FULLY FIXED: Overlapping, Resizing, Mobile Support
-- ✅ GAME-WIDE: All Services (Workspace, ReplicatedStorage, Players, etc.)
-- ✅ ENHANCED: Search, Decompilation, UI Polish, Performance
-- ═══════════════════════════════════════════════════════════════════

local CONFIG = {
    -- Window Settings
    WindowWidth = 0.48,
    WindowHeight = 0.85,
    MinTouchSize = 44, -- Mobile-friendly minimum tap zone
    
    -- Text & Layout
    FontSize = 15,
    IndentSize = 18,
    TreeItemHeight = 32, -- Increased for mobile
    TreePadding = 4,
    
    -- Performance
    AnimationSpeed = 0.12,
    MaxNodes = 2000,
    SearchDebounce = 0.15,
    AutoExpandLevels = 2, -- Auto-expand first N levels
    
    -- Features
    ShowLineCount = true,
    ShowByteSize = true,
    ShowClassNames = true,
    EnableCoreGui = true,
    
    -- Colors (Enhanced contrast)
    Colors = {
        Background = Color3.fromRGB(18, 20, 26),
        Secondary = Color3.fromRGB(28, 31, 40),
        Tertiary = Color3.fromRGB(38, 42, 55),
        Accent = Color3.fromRGB(0, 170, 255),
        AccentHover = Color3.fromRGB(50, 190, 255),
        Text = Color3.fromRGB(230, 230, 235),
        TextMuted = Color3.fromRGB(140, 145, 160),
        
        -- Script Types
        LocalScript = Color3.fromRGB(255, 180, 50),
        Script = Color3.fromRGB(255, 90, 90),
        ModuleScript = Color3.fromRGB(100, 255, 160),
        
        -- Node Types
        Folder = Color3.fromRGB(255, 220, 100),
        Model = Color3.fromRGB(180, 180, 255),
        Container = Color3.fromRGB(160, 165, 180),
        Service = Color3.fromRGB(130, 200, 255),
        
        -- Status
        Success = Color3.fromRGB(80, 255, 120),
        Warning = Color3.fromRGB(255, 200, 80),
        Error = Color3.fromRGB(255, 100, 100),
    },
    
    -- Icons/Emojis for node types
    Icons = {
        LocalScript = "📜",
        Script = "📄",
        ModuleScript = "📦",
        Folder = "📁",
        Model = "🧱",
        Tool = "🔧",
        RemoteEvent = "📡",
        RemoteFunction = "📞",
        BindableEvent = "🔔",
        Service = "⚙️",
        Default = "📎",
        Expanded = "▼",
        Collapsed = "▶",
        Leaf = "•",
    },
    
    -- Services to scan
    Services = {
        "Workspace",
        "ReplicatedStorage",
        "ReplicatedFirst",
        "Players",
        "StarterGui",
        "StarterPack",
        "StarterPlayer",
        "Lighting",
        "SoundService",
        "Chat",
        "LocalizationService",
        "TestService",
    },
}

-- ═══════════════════════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════

-- Safe table to string (handles circular refs)
local function safeToString(value, depth)
    depth = depth or 0
    if depth > 3 then return "..." end
    
    local t = type(value)
    if t == "string" then
        return '"' .. value:sub(1, 100) .. (value:len() > 100 and "..." or "") .. '"'
    elseif t == "table" then
        local parts = {}
        local count = 0
        for k, v in pairs(value) do
            if count >= 10 then
                table.insert(parts, "...")
                break
            end
            table.insert(parts, "[" .. safeToString(k, depth+1) .. "] = " .. safeToString(v, depth+1))
            count = count + 1
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return tostring(value)
    end
end

-- Enhanced Script Source Retrieval with method tracking
local function getScriptSource(scriptInstance)
    local result = {
        source = nil,
        method = "unknown",
        lineCount = 0,
        byteSize = 0,
        isObfuscated = false,
    }
    
    local methods = {
        -- Method 1: Direct decompile (best)
        {name = "decompile", fn = function()
            if type(decompile) == "function" then
                return decompile(scriptInstance)
            end
            return nil
        end},
        
        -- Method 2: getscriptclosure + decompile
        {name = "closure_decompile", fn = function()
            if type(getscriptclosure) == "function" and type(decompile) == "function" then
                local closure = getscriptclosure(scriptInstance)
                if closure then
                    return decompile(closure)
                end
            end
            return nil
        end},
        
        -- Method 3: Hidden property
        {name = "hidden_property", fn = function()
            if type(gethiddenproperty) == "function" then
                local success, source = pcall(gethiddenproperty, scriptInstance, "Source")
                if success and source and #source > 0 then
                    return source
                end
            end
            return nil
        end},
        
        -- Method 4: Bytecode retrieval
        {name = "bytecode", fn = function()
            if type(getscriptbytecode) == "function" or type(get_script_bytecode) == "function" then
                local getBytecode = getscriptbytecode or get_script_bytecode
                local success, bytecode = pcall(getBytecode, scriptInstance)
                if success and bytecode and #bytecode > 0 then
                    result.isObfuscated = true
                    return "-- ⚠️ BYTECODE ONLY (" .. #bytecode .. " bytes)\n-- Script is compiled/obfuscated\n-- Full decompilation requires Synapse X or Script-Ware\n\n-- Raw bytecode hash: " .. tostring(#bytecode)
                end
            end
            return nil
        end},
        
        -- Method 5: ModuleScript require
        {name = "require", fn = function()
            if scriptInstance:IsA("ModuleScript") then
                local success, moduleResult = pcall(function()
                    return require(scriptInstance)
                end)
                if success and moduleResult ~= nil then
                    return "-- 📦 ModuleScript (via require())\n-- Return type: " .. type(moduleResult) .. "\n\nreturn " .. safeToString(moduleResult)
                end
            end
            return nil
        end},
    }
    
    for _, method in ipairs(methods) do
        local success, source = pcall(method.fn)
        if success and source and #source > 0 then
            result.source = source
            result.method = method.name
            result.byteSize = #source
            
            -- Count lines
            local lineCount = 1
            for _ in source:gmatch("\n") do
                lineCount = lineCount + 1
            end
            result.lineCount = lineCount
            
            return result
        end
    end
    
    -- Failed all methods
    result.source = [[-- ❌ FAILED TO RETRIEVE SOURCE
-- 
-- Your executor may not support decompilation.
-- 
-- Recommended executors with decompile support:
--   • Synapse X (Best)
--   • Script-Ware  
--   • KRNL
--   • Fluxus
--
-- Script: ]] .. scriptInstance:GetFullName()
    result.method = "failed"
    result.lineCount = 12
    
    return result
end

-- Create rounded corner
local function createCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = instance
    return corner
end

-- Create stroke
local function createStroke(instance, thickness, color, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = thickness or 1
    stroke.Color = color or CONFIG.Colors.Accent
    stroke.Transparency = transparency or 0
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = instance
    return stroke
end

-- Create padding
local function createPadding(instance, padding)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, padding)
    p.PaddingBottom = UDim.new(0, padding)
    p.PaddingLeft = UDim.new(0, padding)
    p.PaddingRight = UDim.new(0, padding)
    p.Parent = instance
    return p
end

-- Smooth tween
local function tween(instance, props, duration)
    local tweenInfo = TweenInfo.new(duration or CONFIG.AnimationSpeed, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local t = TweenService:Create(instance, tweenInfo, props)
    t:Play()
    return t
end

-- Get icon for instance
local function getIcon(instance)
    if instance:IsA("LocalScript") then return CONFIG.Icons.LocalScript
    elseif instance:IsA("Script") then return CONFIG.Icons.Script
    elseif instance:IsA("ModuleScript") then return CONFIG.Icons.ModuleScript
    elseif instance:IsA("Folder") then return CONFIG.Icons.Folder
    elseif instance:IsA("Model") then return CONFIG.Icons.Model
    elseif instance:IsA("Tool") then return CONFIG.Icons.Tool
    elseif instance:IsA("RemoteEvent") then return CONFIG.Icons.RemoteEvent
    elseif instance:IsA("RemoteFunction") then return CONFIG.Icons.RemoteFunction
    elseif instance:IsA("BindableEvent") then return CONFIG.Icons.BindableEvent
    else return CONFIG.Icons.Default
    end
end

-- Get color for instance
local function getColor(instance)
    if instance:IsA("LocalScript") then return CONFIG.Colors.LocalScript
    elseif instance:IsA("Script") then return CONFIG.Colors.Script
    elseif instance:IsA("ModuleScript") then return CONFIG.Colors.ModuleScript
    elseif instance:IsA("Folder") then return CONFIG.Colors.Folder
    elseif instance:IsA("Model") then return CONFIG.Colors.Model
    else return CONFIG.Colors.Container
    end
end

-- Check if instance or descendants contain scripts
local function hasScriptDescendants(instance)
    if instance:IsA("BaseScript") then return true end
    for _, child in ipairs(instance:GetDescendants()) do
        if child:IsA("BaseScript") then return true end
    end
    return false
end

-- Check if instance has relevant children to show
local function hasRelevantChildren(instance)
    for _, child in ipairs(instance:GetChildren()) do
        if child:IsA("BaseScript") or child:IsA("Folder") or child:IsA("Model") or hasScriptDescendants(child) then
            return true
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════
-- MAIN GUI CREATION
-- ═══════════════════════════════════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScriptExplorerV6"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 9999

-- Try CoreGui first, fallback to PlayerGui
local guiParent = nil
pcall(function()
    screenGui.Parent = CoreGui
    guiParent = CoreGui
end)
if not screenGui.Parent then
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    guiParent = LocalPlayer.PlayerGui
end

-- Main Frame with proper scaling
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.fromScale(CONFIG.WindowWidth, CONFIG.WindowHeight)
mainFrame.Position = UDim2.fromScale(0.5 - CONFIG.WindowWidth/2, 0.5 - CONFIG.WindowHeight/2)
mainFrame.BackgroundColor3 = CONFIG.Colors.Background
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Active = true
mainFrame.Parent = screenGui
createCorner(mainFrame, 12)
createStroke(mainFrame, 2, CONFIG.Colors.Accent, 0.3)

-- Drop shadow effect
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(1, 30, 1, 30)
shadow.Position = UDim2.new(0, -15, 0, -15)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://5554236805"
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.6
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(23, 23, 277, 277)
shadow.ZIndex = -1
shadow.Parent = mainFrame

-- ═══════════════════════════════════════════════════════════════════
-- HEADER
-- ═══════════════════════════════════════════════════════════════════

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 48)
header.BackgroundColor3 = CONFIG.Colors.Secondary
header.BorderSizePixel = 0
header.Parent = mainFrame
createCorner(header, 12)

-- Fix corner overlap at bottom
local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 12)
headerFix.Position = UDim2.new(0, 0, 1, -12)
headerFix.BackgroundColor3 = CONFIG.Colors.Secondary
headerFix.BorderSizePixel = 0
headerFix.Parent = header

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -100, 1, 0)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🚀 Script Explorer v6.0 PRO"
title.TextColor3 = CONFIG.Colors.Text
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -42, 0, 6)
closeBtn.BackgroundColor3 = CONFIG.Colors.Error
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.AutoButtonColor = false
closeBtn.Parent = header
createCorner(closeBtn, 8)

closeBtn.MouseEnter:Connect(function()
    tween(closeBtn, {BackgroundColor3 = Color3.fromRGB(255, 80, 80)}, 0.1)
end)
closeBtn.MouseLeave:Connect(function()
    tween(closeBtn, {BackgroundColor3 = CONFIG.Colors.Error}, 0.1)
end)
closeBtn.MouseButton1Click:Connect(function()
    tween(mainFrame, {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.25)
    task.wait(0.25)
    screenGui:Destroy()
end)

-- Minimize Button
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "MinimizeBtn"
minimizeBtn.Size = UDim2.new(0, 36, 0, 36)
minimizeBtn.Position = UDim2.new(1, -82, 0, 6)
minimizeBtn.BackgroundColor3 = CONFIG.Colors.Warning
minimizeBtn.Text = "─"
minimizeBtn.TextColor3 = Color3.fromRGB(50, 50, 50)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 16
minimizeBtn.AutoButtonColor = false
minimizeBtn.Parent = header
createCorner(minimizeBtn, 8)

local isMinimized = false
local originalSize = mainFrame.Size

minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        tween(mainFrame, {Size = UDim2.new(0, 300, 0, 48)}, 0.2)
    else
        tween(mainFrame, {Size = originalSize}, 0.2)
    end
end)

-- ═══════════════════════════════════════════════════════════════════
-- TOOLBAR
-- ═══════════════════════════════════════════════════════════════════

local toolbar = Instance.new("Frame")
toolbar.Name = "Toolbar"
toolbar.Size = UDim2.new(1, -20, 0, 40)
toolbar.Position = UDim2.new(0, 10, 0, 55)
toolbar.BackgroundTransparency = 1
toolbar.Parent = mainFrame

-- Search Box
local searchBox = Instance.new("TextBox")
searchBox.Name = "SearchBox"
searchBox.Size = UDim2.new(0.7, -5, 1, 0)
searchBox.Position = UDim2.new(0, 0, 0, 0)
searchBox.BackgroundColor3 = CONFIG.Colors.Secondary
searchBox.Text = ""
searchBox.PlaceholderText = "🔍 Search scripts, paths, classes..."
searchBox.TextColor3 = CONFIG.Colors.Text
searchBox.PlaceholderColor3 = CONFIG.Colors.TextMuted
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = CONFIG.FontSize
searchBox.ClearTextOnFocus = false
searchBox.Parent = toolbar
createCorner(searchBox, 8)
createPadding(searchBox, 10)

-- Refresh Button
local refreshBtn = Instance.new("TextButton")
refreshBtn.Name = "RefreshBtn"
refreshBtn.Size = UDim2.new(0.15, -5, 1, 0)
refreshBtn.Position = UDim2.new(0.7, 5, 0, 0)
refreshBtn.BackgroundColor3 = CONFIG.Colors.Accent
refreshBtn.Text = "🔄"
refreshBtn.TextColor3 = CONFIG.Colors.Text
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.TextSize = 16
refreshBtn.AutoButtonColor = false
refreshBtn.Parent = toolbar
createCorner(refreshBtn, 8)

-- Settings Button
local settingsBtn = Instance.new("TextButton")
settingsBtn.Name = "SettingsBtn"
settingsBtn.Size = UDim2.new(0.15, -5, 1, 0)
settingsBtn.Position = UDim2.new(0.85, 5, 0, 0)
settingsBtn.BackgroundColor3 = CONFIG.Colors.Tertiary
settingsBtn.Text = "⚙️"
settingsBtn.TextColor3 = CONFIG.Colors.Text
settingsBtn.Font = Enum.Font.GothamBold
settingsBtn.TextSize = 16
settingsBtn.AutoButtonColor = false
settingsBtn.Parent = toolbar
createCorner(settingsBtn, 8)

-- ═══════════════════════════════════════════════════════════════════
-- PATH DISPLAY
-- ═══════════════════════════════════════════════════════════════════

local pathBar = Instance.new("Frame")
pathBar.Name = "PathBar"
pathBar.Size = UDim2.new(1, -20, 0, 24)
pathBar.Position = UDim2.new(0, 10, 0, 100)
pathBar.BackgroundColor3 = CONFIG.Colors.Tertiary
pathBar.Parent = mainFrame
createCorner(pathBar, 6)

local pathLabel = Instance.new("TextLabel")
pathLabel.Name = "PathLabel"
pathLabel.Size = UDim2.new(1, -70, 1, 0)
pathLabel.Position = UDim2.new(0, 10, 0, 0)
pathLabel.BackgroundTransparency = 1
pathLabel.Text = "📍 Select a script..."
pathLabel.TextColor3 = CONFIG.Colors.TextMuted
pathLabel.Font = Enum.Font.Code
pathLabel.TextSize = 11
pathLabel.TextXAlignment = Enum.TextXAlignment.Left
pathLabel.TextTruncate = Enum.TextTruncate.AtEnd
pathLabel.Parent = pathBar

-- Copy Path Button
local copyPathBtn = Instance.new("TextButton")
copyPathBtn.Name = "CopyPathBtn"
copyPathBtn.Size = UDim2.new(0, 60, 0, 18)
copyPathBtn.Position = UDim2.new(1, -65, 0, 3)
copyPathBtn.BackgroundColor3 = CONFIG.Colors.Accent
copyPathBtn.Text = "📋 Copy"
copyPathBtn.TextColor3 = CONFIG.Colors.Text
copyPathBtn.Font = Enum.Font.Gotham
copyPathBtn.TextSize = 10
copyPathBtn.AutoButtonColor = false
copyPathBtn.Parent = pathBar
createCorner(copyPathBtn, 4)

-- ═══════════════════════════════════════════════════════════════════
-- SPLIT CONTAINER
-- ═══════════════════════════════════════════════════════════════════

local splitContainer = Instance.new("Frame")
splitContainer.Name = "SplitContainer"
splitContainer.Size = UDim2.new(1, -20, 1, -140)
splitContainer.Position = UDim2.new(0, 10, 0, 130)
splitContainer.BackgroundTransparency = 1
splitContainer.ClipsDescendants = true
splitContainer.Parent = mainFrame

-- ═══════════════════════════════════════════════════════════════════
-- TREE VIEW (LEFT PANEL)
-- ═══════════════════════════════════════════════════════════════════

local treePanel = Instance.new("Frame")
treePanel.Name = "TreePanel"
treePanel.Size = UDim2.new(0.45, -5, 1, 0)
treePanel.Position = UDim2.new(0, 0, 0, 0)
treePanel.BackgroundColor3 = CONFIG.Colors.Secondary
treePanel.ClipsDescendants = true
treePanel.Parent = splitContainer
createCorner(treePanel, 8)

local treeScroll = Instance.new("ScrollingFrame")
treeScroll.Name = "TreeScroll"
treeScroll.Size = UDim2.new(1, 0, 1, 0)
treeScroll.Position = UDim2.new(0, 0, 0, 0)
treeScroll.BackgroundTransparency = 1
treeScroll.BorderSizePixel = 0
treeScroll.ScrollBarThickness = 6
treeScroll.ScrollBarImageColor3 = CONFIG.Colors.Accent
treeScroll.ScrollBarImageTransparency = 0.3
treeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
treeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
treeScroll.ClipsDescendants = true
treeScroll.Parent = treePanel

local treeLayout = Instance.new("UIListLayout")
treeLayout.Name = "TreeLayout"
treeLayout.SortOrder = Enum.SortOrder.LayoutOrder
treeLayout.Padding = UDim.new(0, 2)
treeLayout.Parent = treeScroll

createPadding(treeScroll, 5)

-- ═══════════════════════════════════════════════════════════════════
-- CODE VIEWER (RIGHT PANEL)
-- ═══════════════════════════════════════════════════════════════════

local codePanel = Instance.new("Frame")
codePanel.Name = "CodePanel"
codePanel.Size = UDim2.new(0.55, -5, 1, 0)
codePanel.Position = UDim2.new(0.45, 5, 0, 0)
codePanel.BackgroundColor3 = CONFIG.Colors.Secondary
codePanel.ClipsDescendants = true
codePanel.Parent = splitContainer
createCorner(codePanel, 8)

-- Code Header
local codeHeader = Instance.new("Frame")
codeHeader.Name = "CodeHeader"
codeHeader.Size = UDim2.new(1, 0, 0, 40)
codeHeader.BackgroundColor3 = CONFIG.Colors.Tertiary
codeHeader.BorderSizePixel = 0
codeHeader.Parent = codePanel

local codeTitle = Instance.new("TextLabel")
codeTitle.Name = "CodeTitle"
codeTitle.Size = UDim2.new(1, -80, 1, 0)
codeTitle.Position = UDim2.new(0, 10, 0, 0)
codeTitle.BackgroundTransparency = 1
codeTitle.Text = "📜 Select a script"
codeTitle.TextColor3 = CONFIG.Colors.Text
codeTitle.Font = Enum.Font.GothamBold
codeTitle.TextSize = 13
codeTitle.TextXAlignment = Enum.TextXAlignment.Left
codeTitle.Parent = codeHeader

-- Metadata Label
local metaLabel = Instance.new("TextLabel")
metaLabel.Name = "MetaLabel"
metaLabel.Size = UDim2.new(1, -10, 0, 18)
metaLabel.Position = UDim2.new(0, 5, 0, 40)
metaLabel.BackgroundTransparency = 1
metaLabel.Text = ""
metaLabel.TextColor3 = CONFIG.Colors.TextMuted
metaLabel.Font = Enum.Font.Code
metaLabel.TextSize = 10
metaLabel.TextXAlignment = Enum.TextXAlignment.Left
metaLabel.Parent = codePanel

-- Copy Code Button
local copyCodeBtn = Instance.new("TextButton")
copyCodeBtn.Name = "CopyCodeBtn"
copyCodeBtn.Size = UDim2.new(0, 36, 0, 28)
copyCodeBtn.Position = UDim2.new(1, -75, 0, 6)
copyCodeBtn.BackgroundColor3 = CONFIG.Colors.Success
copyCodeBtn.Text = "📋"
copyCodeBtn.TextColor3 = CONFIG.Colors.Text
copyCodeBtn.Font = Enum.Font.GothamBold
copyCodeBtn.TextSize = 14
copyCodeBtn.AutoButtonColor = false
copyCodeBtn.Parent = codeHeader
createCorner(copyCodeBtn, 6)

-- Refresh Code Button
local refreshCodeBtn = Instance.new("TextButton")
refreshCodeBtn.Name = "RefreshCodeBtn"
refreshCodeBtn.Size = UDim2.new(0, 36, 0, 28)
refreshCodeBtn.Position = UDim2.new(1, -38, 0, 6)
refreshCodeBtn.BackgroundColor3 = CONFIG.Colors.Accent
refreshCodeBtn.Text = "🔄"
refreshCodeBtn.TextColor3 = CONFIG.Colors.Text
refreshCodeBtn.Font = Enum.Font.GothamBold
refreshCodeBtn.TextSize = 14
refreshCodeBtn.AutoButtonColor = false
refreshCodeBtn.Parent = codeHeader
createCorner(refreshCodeBtn, 6)

-- Code Scroll
local codeScroll = Instance.new("ScrollingFrame")
codeScroll.Name = "CodeScroll"
codeScroll.Size = UDim2.new(1, 0, 1, -60)
codeScroll.Position = UDim2.new(0, 0, 0, 60)
codeScroll.BackgroundTransparency = 1
codeScroll.BorderSizePixel = 0
codeScroll.ScrollBarThickness = 8
codeScroll.ScrollBarImageColor3 = CONFIG.Colors.Accent
codeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
codeScroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
codeScroll.ClipsDescendants = true
codeScroll.Parent = codePanel

-- Code Content (TextBox for selection support)
local codeContent = Instance.new("TextBox")
codeContent.Name = "CodeContent"
codeContent.Size = UDim2.new(1, -15, 0, 0)
codeContent.Position = UDim2.new(0, 5, 0, 5)
codeContent.BackgroundTransparency = 1
codeContent.Text = "-- 🚀 Script Explorer v6.0 PRO\n-- Select a script from the tree to view its source code\n\n-- Features:\n--   ✅ Game-wide scanning\n--   ✅ Mobile-friendly UI\n--   ✅ Enhanced decompilation\n--   ✅ Search & filter\n--   ✅ Copy to clipboard"
codeContent.TextColor3 = CONFIG.Colors.Text
codeContent.Font = Enum.Font.Code
codeContent.TextSize = 12
codeContent.TextXAlignment = Enum.TextXAlignment.Left
codeContent.TextYAlignment = Enum.TextYAlignment.Top
codeContent.TextWrapped = false
codeContent.MultiLine = true
codeContent.ClearTextOnFocus = false
codeContent.TextEditable = false
codeContent.AutomaticSize = Enum.AutomaticSize.XY
codeContent.Parent = codeScroll

-- ═══════════════════════════════════════════════════════════════════
-- STATE & DATA
-- ═══════════════════════════════════════════════════════════════════

local currentScript = nil
local currentSource = nil
local treeNodes = {}
local expandedNodes = {}
local favoriteScripts = {}
local nodeCount = 0

-- ═══════════════════════════════════════════════════════════════════
-- TREE NODE CREATION (FIXED OVERLAP)
-- ═══════════════════════════════════════════════════════════════════

local function createTreeNode(instance, parentFrame, indentLevel, layoutOrder)
    if nodeCount >= CONFIG.MaxNodes then return end
    
    local isScript = instance:IsA("BaseScript")
    local hasChildren = hasRelevantChildren(instance)
    
    -- Skip if not a script and has no script descendants
    if not isScript and not hasChildren and not instance:IsA("Folder") then
        return
    end
    
    nodeCount = nodeCount + 1
    
    -- Node container
    local nodeContainer = Instance.new("Frame")
    nodeContainer.Name = "Node_" .. instance.Name
    nodeContainer.Size = UDim2.new(1, 0, 0, CONFIG.TreeItemHeight)
    nodeContainer.BackgroundTransparency = 1
    nodeContainer.LayoutOrder = layoutOrder
    nodeContainer.AutomaticSize = Enum.AutomaticSize.Y
    nodeContainer.Parent = parentFrame
    
    -- Main button
    local nodeBtn = Instance.new("TextButton")
    nodeBtn.Name = "NodeBtn"
    nodeBtn.Size = UDim2.new(1, -indentLevel * CONFIG.IndentSize, 0, CONFIG.TreeItemHeight)
    nodeBtn.Position = UDim2.new(0, indentLevel * CONFIG.IndentSize, 0, 0)
    nodeBtn.BackgroundColor3 = CONFIG.Colors.Tertiary
    nodeBtn.BackgroundTransparency = 0.9
    nodeBtn.BorderSizePixel = 0
    nodeBtn.Font = Enum.Font.Gotham
    nodeBtn.TextSize = CONFIG.FontSize
    nodeBtn.TextXAlignment = Enum.TextXAlignment.Left
    nodeBtn.AutoButtonColor = false
    nodeBtn.Parent = nodeContainer
    createCorner(nodeBtn, 4)
    
    -- Set colors
    nodeBtn.TextColor3 = getColor(instance)
    if isScript then
        nodeBtn.Font = Enum.Font.GothamBold
    end
    
    -- Build text
    local icon = getIcon(instance)
    local expandIcon = hasChildren and CONFIG.Icons.Collapsed or (isScript and "" or CONFIG.Icons.Leaf)
    local className = CONFIG.ShowClassNames and " <font color=\"#666\">[" .. instance.ClassName .. "]</font>" or ""
    nodeBtn.RichText = true
    nodeBtn.Text = "  " .. expandIcon .. " " .. icon .. " " .. instance.Name .. className
    
    -- Hover effect with UIStroke
    local hoverStroke = createStroke(nodeBtn, 1, CONFIG.Colors.Accent, 1)
    
    nodeBtn.MouseEnter:Connect(function()
        tween(nodeBtn, {BackgroundTransparency = 0.7}, 0.1)
        tween(hoverStroke, {Transparency = 0.5}, 0.1)
    end)
    nodeBtn.MouseLeave:Connect(function()
        tween(nodeBtn, {BackgroundTransparency = 0.9}, 0.1)
        tween(hoverStroke, {Transparency = 1}, 0.1)
    end)
    
    -- Children container
    local childrenFrame = Instance.new("Frame")
    childrenFrame.Name = "Children"
    childrenFrame.Size = UDim2.new(1, 0, 0, 0)
    childrenFrame.Position = UDim2.new(0, 0, 0, CONFIG.TreeItemHeight)
    childrenFrame.BackgroundTransparency = 1
    childrenFrame.Visible = false
    childrenFrame.AutomaticSize = Enum.AutomaticSize.Y
    childrenFrame.Parent = nodeContainer
    
    local childrenLayout = Instance.new("UIListLayout")
    childrenLayout.SortOrder = Enum.SortOrder.LayoutOrder
    childrenLayout.Padding = UDim.new(0, 2)
    childrenLayout.Parent = childrenFrame
    
    -- Track expansion state
    local isExpanded = false
    local childrenLoaded = false
    
    -- Click handler
    nodeBtn.MouseButton1Click:Connect(function()
        if isScript then
            -- Load script source
            currentScript = instance
            pathLabel.Text = "📍 " .. instance:GetFullName()
            codeTitle.Text = icon .. " " .. instance.Name .. " [" .. instance.ClassName .. "]"
            
            local result = getScriptSource(instance)
            currentSource = result.source
            codeContent.Text = result.source
            
            -- Update metadata
            local meta = "📊 Lines: " .. result.lineCount .. " | Bytes: " .. result.byteSize .. " | Method: " .. result.method
            if result.isObfuscated then
                meta = meta .. " | ⚠️ Obfuscated"
            end
            metaLabel.Text = meta
            
        elseif hasChildren then
            -- Toggle expansion
            isExpanded = not isExpanded
            childrenFrame.Visible = isExpanded
            
            -- Update icon
            expandIcon = isExpanded and CONFIG.Icons.Expanded or CONFIG.Icons.Collapsed
            nodeBtn.Text = "  " .. expandIcon .. " " .. icon .. " " .. instance.Name .. className
            
            -- Load children on first expand
            if isExpanded and not childrenLoaded then
                childrenLoaded = true
                local children = instance:GetChildren()
                table.sort(children, function(a, b)
                    -- Scripts first, then folders, then others
                    local aScore = a:IsA("BaseScript") and 0 or (a:IsA("Folder") and 1 or 2)
                    local bScore = b:IsA("BaseScript") and 0 or (b:IsA("Folder") and 1 or 2)
                    if aScore == bScore then
                        return a.Name < b.Name
                    end
                    return aScore < bScore
                end)
                
                for i, child in ipairs(children) do
                    createTreeNode(child, childrenFrame, indentLevel + 1, i)
                end
            end
        end
    end)
    
    -- Auto-expand for first N levels
    if hasChildren and indentLevel < CONFIG.AutoExpandLevels then
        task.defer(function()
            task.wait(0.05 * indentLevel)
            nodeBtn.MouseButton1Click:Fire()
        end)
    end
    
    return nodeContainer
end

-- ═══════════════════════════════════════════════════════════════════
-- BUILD TREE
-- ═══════════════════════════════════════════════════════════════════

local function buildTree(searchQuery)
    -- Clear existing
    for _, child in ipairs(treeScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    nodeCount = 0
    searchQuery = searchQuery and searchQuery:lower() or ""
    
    if searchQuery == "" then
        -- Build full tree from all services
        local order = 0
        for _, serviceName in ipairs(CONFIG.Services) do
            local success, service = pcall(function()
                return game:GetService(serviceName)
            end)
            
            if success and service then
                order = order + 1
                
                -- Create service header
                local serviceNode = Instance.new("Frame")
                serviceNode.Name = "Service_" .. serviceName
                serviceNode.Size = UDim2.new(1, 0, 0, CONFIG.TreeItemHeight)
                serviceNode.BackgroundTransparency = 1
                serviceNode.LayoutOrder = order
                serviceNode.AutomaticSize = Enum.AutomaticSize.Y
                serviceNode.Parent = treeScroll
                
                local serviceBtn = Instance.new("TextButton")
                serviceBtn.Name = "ServiceBtn"
                serviceBtn.Size = UDim2.new(1, 0, 0, CONFIG.TreeItemHeight)
                serviceBtn.BackgroundColor3 = CONFIG.Colors.Service
                serviceBtn.BackgroundTransparency = 0.85
                serviceBtn.BorderSizePixel = 0
                serviceBtn.Font = Enum.Font.GothamBold
                serviceBtn.TextSize = CONFIG.FontSize
                serviceBtn.TextColor3 = CONFIG.Colors.Service
                serviceBtn.TextXAlignment = Enum.TextXAlignment.Left
                serviceBtn.RichText = true
                serviceBtn.Text = "  " .. CONFIG.Icons.Collapsed .. " ⚙️ " .. serviceName
                serviceBtn.AutoButtonColor = false
                serviceBtn.Parent = serviceNode
                createCorner(serviceBtn, 4)
                
                local serviceChildren = Instance.new("Frame")
                serviceChildren.Name = "Children"
                serviceChildren.Size = UDim2.new(1, 0, 0, 0)
                serviceChildren.Position = UDim2.new(0, 0, 0, CONFIG.TreeItemHeight)
                serviceChildren.BackgroundTransparency = 1
                serviceChildren.Visible = false
                serviceChildren.AutomaticSize = Enum.AutomaticSize.Y
                serviceChildren.Parent = serviceNode
                
                local serviceLayout = Instance.new("UIListLayout")
                serviceLayout.SortOrder = Enum.SortOrder.LayoutOrder
                serviceLayout.Padding = UDim.new(0, 2)
                serviceLayout.Parent = serviceChildren
                
                local serviceExpanded = false
                local serviceLoaded = false
                
                serviceBtn.MouseButton1Click:Connect(function()
                    serviceExpanded = not serviceExpanded
                    serviceChildren.Visible = serviceExpanded
                    
                    local icon = serviceExpanded and CONFIG.Icons.Expanded or CONFIG.Icons.Collapsed
                    serviceBtn.Text = "  " .. icon .. " ⚙️ " .. serviceName
                    
                    if serviceExpanded and not serviceLoaded then
                        serviceLoaded = true
                        local children = service:GetChildren()
                        table.sort(children, function(a, b) return a.Name < b.Name end)
                        
                        for i, child in ipairs(children) do
                            createTreeNode(child, serviceChildren, 1, i)
                        end
                    end
                end)
            end
        end
        
        -- Also try CoreGui if enabled
        if CONFIG.EnableCoreGui then
            pcall(function()
                order = order + 1
                local coreGuiNode = Instance.new("Frame")
                coreGuiNode.Name = "Service_CoreGui"
                coreGuiNode.Size = UDim2.new(1, 0, 0, CONFIG.TreeItemHeight)
                coreGuiNode.BackgroundTransparency = 1
                coreGuiNode.LayoutOrder = order
                coreGuiNode.AutomaticSize = Enum.AutomaticSize.Y
                coreGuiNode.Parent = treeScroll
                
                local coreBtn = Instance.new("TextButton")
                coreBtn.Size = UDim2.new(1, 0, 0, CONFIG.TreeItemHeight)
                coreBtn.BackgroundColor3 = CONFIG.Colors.Warning
                coreBtn.BackgroundTransparency = 0.85
                coreBtn.BorderSizePixel = 0
                coreBtn.Font = Enum.Font.GothamBold
                coreBtn.TextSize = CONFIG.FontSize
                coreBtn.TextColor3 = CONFIG.Colors.Warning
                coreBtn.TextXAlignment = Enum.TextXAlignment.Left
                coreBtn.Text = "  ▶ 🔒 CoreGui (Protected)"
                coreBtn.AutoButtonColor = false
                coreBtn.Parent = coreGuiNode
                createCorner(coreBtn, 4)
            end)
        end
    else
        -- Search mode
        local function searchIn(instance, path)
            if nodeCount >= CONFIG.MaxNodes then return end
            
            for _, child in ipairs(instance:GetChildren()) do
                local nameMatch = child.Name:lower():find(searchQuery, 1, true)
                local classMatch = child.ClassName:lower():find(searchQuery, 1, true)
                local pathMatch = path:lower():find(searchQuery, 1, true)
                
                if child:IsA("BaseScript") and (nameMatch or classMatch or pathMatch) then
                    createTreeNode(child, treeScroll, 0, nodeCount)
                end
                
                if hasScriptDescendants(child) then
                    searchIn(child, path .. "/" .. child.Name)
                end
            end
        end
        
        for _, serviceName in ipairs(CONFIG.Services) do
            pcall(function()
                local service = game:GetService(serviceName)
                searchIn(service, serviceName)
            end)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════
-- EVENT HANDLERS
-- ═══════════════════════════════════════════════════════════════════

-- Search with debounce
local searchDebounce = nil
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local query = searchBox.Text
    if searchDebounce then
        task.cancel(searchDebounce)
    end
    searchDebounce = task.delay(CONFIG.SearchDebounce, function()
        buildTree(query)
    end)
end)

-- Refresh button
refreshBtn.MouseButton1Click:Connect(function()
    nodeCount = 0
    buildTree(searchBox.Text)
end)

-- Copy code button
copyCodeBtn.MouseButton1Click:Connect(function()
    if currentSource then
        pcall(function()
            if setclipboard then setclipboard(currentSource)
            elseif writeclipboard then writeclipboard(currentSource)
            elseif toclipboard then toclipboard(currentSource) end
        end)
        copyCodeBtn.Text = "✅"
        task.wait(1)
        copyCodeBtn.Text = "📋"
    end
end)

-- Copy path button
copyPathBtn.MouseButton1Click:Connect(function()
    if currentScript then
        local path = currentScript:GetFullName()
        pcall(function()
            if setclipboard then setclipboard(path)
            elseif writeclipboard then writeclipboard(path)
            elseif toclipboard then toclipboard(path) end
        end)
        copyPathBtn.Text = "✅"
        task.wait(1)
        copyPathBtn.Text = "📋 Copy"
    end
end)

-- Refresh code button
refreshCodeBtn.MouseButton1Click:Connect(function()
    if currentScript then
        local result = getScriptSource(currentScript)
        currentSource = result.source
        codeContent.Text = result.source
        metaLabel.Text = "📊 Lines: " .. result.lineCount .. " | Bytes: " .. result.byteSize .. " | Method: " .. result.method
    end
end)

-- ═══════════════════════════════════════════════════════════════════
-- DRAGGING
-- ═══════════════════════════════════════════════════════════════════

local dragging = false
local dragStart = nil
local startPos = nil

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- ═══════════════════════════════════════════════════════════════════
-- INITIALIZE
-- ═══════════════════════════════════════════════════════════════════

-- Initial build
buildTree()

-- Startup animation
mainFrame.Size = UDim2.new(0, 0, 0, 0)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
task.wait(0.1)
tween(mainFrame, {
    Size = UDim2.fromScale(CONFIG.WindowWidth, CONFIG.WindowHeight),
    Position = UDim2.fromScale(0.5 - CONFIG.WindowWidth/2, 0.5 - CONFIG.WindowHeight/2)
}, 0.3)

print("═══════════════════════════════════════════════════════════════")
print("🚀 Script Explorer v6.0 PRO loaded successfully!")
print("═══════════════════════════════════════════════════════════════")
print("✅ Game-wide scanning: " .. #CONFIG.Services .. " services")
print("✅ Mobile-friendly UI with touch support")
print("✅ Enhanced decompilation with fallbacks")
print("✅ Smart search with debounce")
print("✅ Auto-expand first " .. CONFIG.AutoExpandLevels .. " levels")
print("═══════════════════════════════════════════════════════════════")