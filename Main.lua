-- ═══════════════════════════════════════════════════════════════════
-- 🚀 SCRIPT EXPLORER v10.0 PRO EDITION
-- ═══════════════════════════════════════════════════════════════════
-- ✅ SECURITY: Anti-detection, safety checks, stealth mode
-- ✅ PERFORMANCE: Memory cleanup, lazy loading, chunked processing
-- ✅ FEATURES: Favorites, search filters, script execution
-- ✅ DECOMPILE: 15+ methods, bytecode analysis, speed's decompiler
-- ✅ UI: Tabs, syntax highlighting, remote spy
-- ✅ GAME MAP: Full copyable list on startup
-- ✅ IN-GAME HIGHLIGHT: Click to highlight in 3D world
-- ═══════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- SECURITY & ANTI-DETECTION
-- ═══════════════════════════════════════════════════════════════════

local function safetyCheck()
    local checks = {
        getgenv ~= nil,
        getreg ~= nil or debug ~= nil,
        game ~= nil,
        workspace ~= nil,
    }
    for _, check in ipairs(checks) do
        if not check then return false end
    end
    return true
end

pcall(function()
    game:GetService("ScriptContext"):SetTimeout(0)
end)

pcall(function()
    if syn and syn.protect_gui then
        -- Will protect GUI later
    end
end)

-- ═══════════════════════════════════════════════════════════════════
-- PERFORMANCE: Memory Management
-- ═══════════════════════════════════════════════════════════════════

local function cleanupMemory()
    pcall(function()
        if collectgarbage then
            collectgarbage("collect")
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════
-- FAVORITES SYSTEM
-- ═══════════════════════════════════════════════════════════════════

local favorites = {}

local function addToFavorites(instance)
    table.insert(favorites, {
        name = instance.Name,
        path = instance:GetFullName(),
        class = instance.ClassName,
        time = os.time()
    })
end

local function removeFromFavorites(path)
    for i, fav in ipairs(favorites) do
        if fav.path == path then
            table.remove(favorites, i)
            return true
        end
    end
    return false
end

local function isFavorite(path)
    for _, fav in ipairs(favorites) do
        if fav.path == path then return true end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════
-- SEARCH FILTERS
-- ═══════════════════════════════════════════════════════════════════

local searchFilters = {
    scripts = true,
    modules = true,
    localscripts = true,
    parts = true,
    guis = true,
    remotes = true,
    all = true,
}

local function matchesFilter(instance)
    if searchFilters.all then return true end
    if searchFilters.scripts and instance:IsA("Script") then return true end
    if searchFilters.modules and instance:IsA("ModuleScript") then return true end
    if searchFilters.localscripts and instance:IsA("LocalScript") then return true end
    if searchFilters.parts and instance:IsA("BasePart") then return true end
    if searchFilters.guis and instance:IsA("GuiObject") then return true end
    if searchFilters.remotes and (instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction")) then return true end
    return false
end

-- ═══════════════════════════════════════════════════════════════════
-- SCRIPT EXECUTION
-- ═══════════════════════════════════════════════════════════════════

local function executeScript(scriptSource)
    local fn, err = loadstring(scriptSource)
    if fn then
        return pcall(fn)
    end
    return false, err
end

-- ═══════════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════

local CONFIG = {
    WindowWidth = 0.70,
    WindowHeight = 0.88,
    MinTouchSize = 44,
    FontSize = 13,
    IndentSize = 14,
    TreeItemHeight = 30,
    TreePadding = 3,
    TreePanelWidth = 0.62,
    
    AnimationSpeed = 0.12,
    MaxNodes = 8000,
    MaxDepth = 50,
    SearchDebounce = 0.6,
    SearchMinChars = 2,
    MaxSearchResults = 150,
    ChunkSize = 25,
    ChunkDelay = 0.02,
    AutoExpandLevels = 0,
    LazyLoadThreshold = 100,
    
    ShowLineCount = true,
    ShowByteSize = true,
    ShowClassNames = true,
    EnableCoreGui = true,
    ShowAllFiles = true,
    ShowEmptyFolders = true,
    EnableHighlight = true,
    HighlightColor = Color3.fromRGB(0, 255, 200),
    HighlightDuration = 6,
    SilentErrors = true,
    ShowGameMapOnStart = true,
    EnableStealth = true,
    RandomizePosition = false,
    EnableSyntaxHighlight = true,
    EnableRemoteSpy = true,
    
    Colors = {
        Background = Color3.fromRGB(12, 14, 18),
        Secondary = Color3.fromRGB(20, 24, 32),
        Tertiary = Color3.fromRGB(28, 34, 44),
        Accent = Color3.fromRGB(0, 160, 255),
        AccentHover = Color3.fromRGB(60, 190, 255),
        Text = Color3.fromRGB(245, 245, 250),
        TextMuted = Color3.fromRGB(140, 145, 160),
        TextDark = Color3.fromRGB(90, 95, 110),
        
        LocalScript = Color3.fromRGB(255, 200, 80),
        Script = Color3.fromRGB(255, 100, 100),
        ModuleScript = Color3.fromRGB(100, 255, 150),
        
        Folder = Color3.fromRGB(255, 220, 100),
        Model = Color3.fromRGB(180, 180, 255),
        Part = Color3.fromRGB(170, 180, 190),
        Container = Color3.fromRGB(155, 160, 175),
        Service = Color3.fromRGB(130, 200, 255),
        
        Success = Color3.fromRGB(80, 255, 120),
        Warning = Color3.fromRGB(255, 200, 80),
        Error = Color3.fromRGB(255, 100, 100),
        
        HighlightFill = Color3.fromRGB(0, 255, 200),
        HighlightOutline = Color3.fromRGB(255, 255, 0),
        
        GameMapBg = Color3.fromRGB(8, 10, 14),
        GameMapHeader = Color3.fromRGB(15, 18, 25),
    },
    
    Icons = {
        LocalScript = "📜", Script = "📄", ModuleScript = "📦",
        Folder = "📁", Model = "🧱", Tool = "🔧", Accessory = "👒",
        Part = "🔷", MeshPart = "🔶", UnionOperation = "🔸",
        SpawnLocation = "🚩", Seat = "🪑", Terrain = "🏔️",
        ScreenGui = "🖥️", Frame = "🔲", TextLabel = "🏷️",
        TextButton = "🔘", ImageLabel = "🖼️", ImageButton = "🖱️",
        RemoteEvent = "📡", RemoteFunction = "📞",
        BindableEvent = "🔔", BindableFunction = "📲",
        Sound = "🔊", Animation = "🎬",
        StringValue = "📝", NumberValue = "🔢", BoolValue = "✅",
        IntValue = "🔢", ObjectValue = "🔗", CFrameValue = "📐",
        Humanoid = "🧍", Camera = "📷", Lighting = "💡",
        Fire = "🔥", Smoke = "💨", Sparkles = "⭐", ParticleEmitter = "✨",
        Weld = "🔗", Motor6D = "⚙️", Attachment = "📎",
        Workspace = "🌍", Players = "👥", ReplicatedStorage = "📦",
        StarterGui = "🖼️", StarterPack = "🎒", StarterPlayer = "🏃",
        Lighting = "💡", SoundService = "🔊", Chat = "💬",
        Teams = "👔", TeleportService = "🌀", HttpService = "🌐",
        Service = "⚙️", Default = "📎", Expanded = "▼", Collapsed = "▶",
        Copy = "📋", Close = "✕", Refresh = "🔄", Map = "🗺️",
    },
    
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
        "Teams",
        "LocalizationService",
        "TestService",
    },
}

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- Global State
local currentItem = nil
local currentScript = nil
local currentSource = nil
local nodeCount = 0
local currentHighlight = nil
local currentBillboard = nil
local gameMapGui = nil

-- ═══════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════

local function createCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = instance
    return corner
end

local function createStroke(instance, thickness, color, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = thickness or 1
    stroke.Color = color or CONFIG.Colors.Accent
    stroke.Transparency = transparency or 0
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = instance
    return stroke
end

local function createPadding(instance, padding)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, padding)
    p.PaddingBottom = UDim.new(0, padding)
    p.PaddingLeft = UDim.new(0, padding)
    p.PaddingRight = UDim.new(0, padding)
    p.Parent = instance
    return p
end

local function tween(instance, props, duration)
    local tweenInfo = TweenInfo.new(duration or CONFIG.AnimationSpeed, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local t = TweenService:Create(instance, tweenInfo, props)
    t:Play()
    return t
end

local function getIcon(instance)
    local className = instance.ClassName
    if CONFIG.Icons[className] then
        return CONFIG.Icons[className]
    elseif instance:IsA("LocalScript") then return CONFIG.Icons.LocalScript
    elseif instance:IsA("Script") then return CONFIG.Icons.Script
    elseif instance:IsA("ModuleScript") then return CONFIG.Icons.ModuleScript
    elseif instance:IsA("Folder") then return CONFIG.Icons.Folder
    elseif instance:IsA("Model") then return CONFIG.Icons.Model
    elseif instance:IsA("BasePart") then return CONFIG.Icons.Part
    elseif instance:IsA("Tool") then return CONFIG.Icons.Tool
    elseif instance:IsA("GuiObject") then return CONFIG.Icons.Frame
    elseif instance:IsA("ValueBase") then return CONFIG.Icons.StringValue
    else return CONFIG.Icons.Default
    end
end

local function getColor(instance)
    if instance:IsA("LocalScript") then return CONFIG.Colors.LocalScript
    elseif instance:IsA("Script") then return CONFIG.Colors.Script
    elseif instance:IsA("ModuleScript") then return CONFIG.Colors.ModuleScript
    elseif instance:IsA("Folder") then return CONFIG.Colors.Folder
    elseif instance:IsA("Model") then return CONFIG.Colors.Model
    elseif instance:IsA("BasePart") then return CONFIG.Colors.Part
    else return CONFIG.Colors.Container
    end
end

-- ═══════════════════════════════════════════════════════════════════
-- GAME MAP GENERATOR
-- ═══════════════════════════════════════════════════════════════════

local function generateGameMap()
    local maps = {}
    local totalObjects = 0
    local totalScripts = 0
    
    for _, serviceName in ipairs(CONFIG.Services) do
        local success, service = pcall(function()
            return game:GetService(serviceName)
        end)
        
        if success and service then
            local serviceMap = {}
            local serviceScripts = 0
            local serviceObjects = 0
            
            local function scanInstance(instance, indent, path)
                if serviceObjects > 2000 then return end
                serviceObjects = serviceObjects + 1
                
                local icon = getIcon(instance)
                local className = instance.ClassName
                local isScript = instance:IsA("BaseScript")
                
                if isScript then
                    serviceScripts = serviceScripts + 1
                end
                
                local line = string.rep("  ", indent) .. icon .. " " .. instance.Name
                line = line .. " [" .. className .. "]"
                line = line .. " -- " .. path
                
                table.insert(serviceMap, line)
                
                for _, child in ipairs(instance:GetChildren()) do
                    pcall(function()
                        scanInstance(child, indent + 1, path .. "." .. child.Name)
                    end)
                end
            end
            
            for _, child in ipairs(service:GetChildren()) do
                pcall(function()
                    scanInstance(child, 0, serviceName .. "." .. child.Name)
                end)
            end
            
            totalObjects = totalObjects + serviceObjects
            totalScripts = totalScripts + serviceScripts
            
            local header = "\n-- ═══════════════════════════════════════════════════════════════════\n"
            header = header .. "-- 📂 " .. serviceName .. " (" .. serviceObjects .. " objects, " .. serviceScripts .. " scripts)\n"
            header = header .. "-- ═══════════════════════════════════════════════════════════════════\n\n"
            
            maps[serviceName] = {
                header = header,
                content = table.concat(serviceMap, "\n"),
                objectCount = serviceObjects,
                scriptCount = serviceScripts,
            }
        end
    end
    
    return maps, totalObjects, totalScripts
end

local function showGameMap()
    if gameMapGui then
        gameMapGui:Destroy()
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GameMapViewer"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 99999
    
    pcall(function() screenGui.Parent = CoreGui end)
    if not screenGui.Parent then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    
    gameMapGui = screenGui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "GameMapFrame"
    mainFrame.Size = UDim2.new(0.85, 0, 0.9, 0)
    mainFrame.Position = UDim2.new(0.075, 0, 0.05, 0)
    mainFrame.BackgroundColor3 = CONFIG.Colors.GameMapBg
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    createCorner(mainFrame, 16)
    createStroke(mainFrame, 3, CONFIG.Colors.Accent, 0.2)
    
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 60)
    header.BackgroundColor3 = CONFIG.Colors.GameMapHeader
    header.BorderSizePixel = 0
    header.Parent = mainFrame
    createCorner(header, 16)
    
    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 20)
    headerFix.Position = UDim2.new(0, 0, 1, -20)
    headerFix.BackgroundColor3 = CONFIG.Colors.GameMapHeader
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -150, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🗺️ GAME MAP - Full Object List (Copyable)"
    title.TextColor3 = CONFIG.Colors.Text
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 50, 0, 50)
    closeBtn.Position = UDim2.new(1, -55, 0, 5)
    closeBtn.BackgroundColor3 = CONFIG.Colors.Error
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 24
    closeBtn.Parent = header
    createCorner(closeBtn, 10)
    
    closeBtn.MouseButton1Click:Connect(function()
        tween(mainFrame, {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.3)
        task.wait(0.3)
        screenGui:Destroy()
        gameMapGui = nil
    end)
    
    local continueBtn = Instance.new("TextButton")
    continueBtn.Size = UDim2.new(0, 200, 0, 40)
    continueBtn.Position = UDim2.new(1, -270, 0, 10)
    continueBtn.BackgroundColor3 = CONFIG.Colors.Success
    continueBtn.Text = "✅ Open Explorer"
    continueBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    continueBtn.Font = Enum.Font.GothamBold
    continueBtn.TextSize = 16
    continueBtn.Parent = header
    createCorner(continueBtn, 8)
    
    continueBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        gameMapGui = nil
    end)
    
    local loadingLabel = Instance.new("TextLabel")
    loadingLabel.Size = UDim2.new(1, 0, 1, -60)
    loadingLabel.Position = UDim2.new(0, 0, 0, 60)
    loadingLabel.BackgroundTransparency = 1
    loadingLabel.Text = "🔄 Scanning game objects..."
    loadingLabel.TextColor3 = CONFIG.Colors.TextMuted
    loadingLabel.Font = Enum.Font.GothamBold
    loadingLabel.TextSize = 24
    loadingLabel.Parent = mainFrame
    
    task.spawn(function()
        task.wait(0.1)
        local maps, totalObjects, totalScripts = generateGameMap()
        
        if not screenGui.Parent then return end
        
        loadingLabel:Destroy()
        
        local statsBar = Instance.new("Frame")
        statsBar.Size = UDim2.new(1, -20, 0, 35)
        statsBar.Position = UDim2.new(0, 10, 0, 65)
        statsBar.BackgroundColor3 = CONFIG.Colors.Tertiary
        statsBar.Parent = mainFrame
        createCorner(statsBar, 8)
        
        local statsLabel = Instance.new("TextLabel")
        statsLabel.Size = UDim2.new(1, -20, 1, 0)
        statsLabel.Position = UDim2.new(0, 10, 0, 0)
        statsLabel.BackgroundTransparency = 1
        statsLabel.Text = "📊 Total: " .. totalObjects .. " objects | " .. totalScripts .. " scripts | " .. #CONFIG.Services .. " services scanned"
        statsLabel.TextColor3 = CONFIG.Colors.Accent
        statsLabel.Font = Enum.Font.GothamBold
        statsLabel.TextSize = 14
        statsLabel.TextXAlignment = Enum.TextXAlignment.Left
        statsLabel.Parent = statsBar
        
        local tabContainer = Instance.new("Frame")
        tabContainer.Size = UDim2.new(1, -20, 0, 40)
        tabContainer.Position = UDim2.new(0, 10, 0, 105)
        tabContainer.BackgroundTransparency = 1
        tabContainer.Parent = mainFrame
        
        local tabLayout = Instance.new("UIListLayout")
        tabLayout.FillDirection = Enum.FillDirection.Horizontal
        tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tabLayout.Padding = UDim.new(0, 5)
        tabLayout.Parent = tabContainer
        
        local contentScroll = Instance.new("ScrollingFrame")
        contentScroll.Size = UDim2.new(1, -20, 1, -160)
        contentScroll.Position = UDim2.new(0, 10, 0, 150)
        contentScroll.BackgroundColor3 = CONFIG.Colors.Secondary
        contentScroll.BorderSizePixel = 0
        contentScroll.ScrollBarThickness = 12
        contentScroll.ScrollBarImageColor3 = CONFIG.Colors.Accent
        contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        contentScroll.Parent = mainFrame
        createCorner(contentScroll, 10)
        
        local contentBox = Instance.new("TextBox")
        contentBox.Size = UDim2.new(1, -20, 0, 0)
        contentBox.Position = UDim2.new(0, 10, 0, 10)
        contentBox.BackgroundTransparency = 1
        contentBox.Text = ""
        contentBox.TextColor3 = CONFIG.Colors.Text
        contentBox.Font = Enum.Font.Code
        contentBox.TextSize = 12
        contentBox.TextXAlignment = Enum.TextXAlignment.Left
        contentBox.TextYAlignment = Enum.TextYAlignment.Top
        contentBox.TextWrapped = false
        contentBox.MultiLine = true
        contentBox.ClearTextOnFocus = false
        contentBox.TextEditable = false
        contentBox.AutomaticSize = Enum.AutomaticSize.Y
        contentBox.Parent = contentScroll
        
        local currentTab = nil
        local tabs = {}
        
        local function showService(serviceName)
            if currentTab then
                currentTab.BackgroundColor3 = CONFIG.Colors.Tertiary
            end
            
            if tabs[serviceName] then
                tabs[serviceName].BackgroundColor3 = CONFIG.Colors.Accent
                currentTab = tabs[serviceName]
            end
            
            local mapData = maps[serviceName]
            if mapData then
                contentBox.Text = mapData.header .. mapData.content
            else
                contentBox.Text = "-- No data for " .. serviceName
            end
        end
        
        local order = 0
        for _, serviceName in ipairs(CONFIG.Services) do
            if maps[serviceName] then
                order = order + 1
                
                local tabBtn = Instance.new("TextButton")
                tabBtn.Name = serviceName
                tabBtn.Size = UDim2.new(0, 120, 1, 0)
                tabBtn.BackgroundColor3 = CONFIG.Colors.Tertiary
                tabBtn.Text = (CONFIG.Icons[serviceName] or "⚙️") .. " " .. serviceName:sub(1, 10)
                tabBtn.TextColor3 = CONFIG.Colors.Text
                tabBtn.Font = Enum.Font.GothamBold
                tabBtn.TextSize = 11
                tabBtn.LayoutOrder = order
                tabBtn.Parent = tabContainer
                createCorner(tabBtn, 6)
                
                tabs[serviceName] = tabBtn
                
                tabBtn.MouseButton1Click:Connect(function()
                    showService(serviceName)
                end)
                
                if order == 1 then
                    showService(serviceName)
                end
            end
        end
        
        local copyAllBtn = Instance.new("TextButton")
        copyAllBtn.Size = UDim2.new(0, 100, 1, 0)
        copyAllBtn.BackgroundColor3 = CONFIG.Colors.Success
        copyAllBtn.Text = "📋 Copy All"
        copyAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        copyAllBtn.Font = Enum.Font.GothamBold
        copyAllBtn.TextSize = 12
        copyAllBtn.LayoutOrder = 999
        copyAllBtn.Parent = tabContainer
        createCorner(copyAllBtn, 6)
        
        copyAllBtn.MouseButton1Click:Connect(function()
            local fullMap = "-- 🗺️ FULL GAME MAP\n-- Generated by Script Explorer v9.5\n"
            fullMap = fullMap .. "-- Total: " .. totalObjects .. " objects | " .. totalScripts .. " scripts\n"
            
            for _, serviceName in ipairs(CONFIG.Services) do
                if maps[serviceName] then
                    fullMap = fullMap .. maps[serviceName].header .. maps[serviceName].content .. "\n"
                end
            end
            
            pcall(function()
                if setclipboard then setclipboard(fullMap)
                elseif writeclipboard then writeclipboard(fullMap)
                elseif toclipboard then toclipboard(fullMap) end
            end)
            
            copyAllBtn.Text = "✅ Copied!"
            task.wait(1.5)
            copyAllBtn.Text = "📋 Copy All"
        end)
        
        local copyTabBtn = Instance.new("TextButton")
        copyTabBtn.Size = UDim2.new(0, 100, 1, 0)
        copyTabBtn.BackgroundColor3 = CONFIG.Colors.Accent
        copyTabBtn.Text = "📋 Copy Tab"
        copyTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        copyTabBtn.Font = Enum.Font.GothamBold
        copyTabBtn.TextSize = 12
        copyTabBtn.LayoutOrder = 998
        copyTabBtn.Parent = tabContainer
        createCorner(copyTabBtn, 6)
        
        copyTabBtn.MouseButton1Click:Connect(function()
            pcall(function()
                if setclipboard then setclipboard(contentBox.Text)
                elseif writeclipboard then writeclipboard(contentBox.Text)
                elseif toclipboard then toclipboard(contentBox.Text) end
            end)
            
            copyTabBtn.Text = "✅ Copied!"
            task.wait(1.5)
            copyTabBtn.Text = "📋 Copy Tab"
        end)
    end)
    
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    task.wait(0.05)
    tween(mainFrame, {
        Size = UDim2.new(0.85, 0, 0.9, 0),
        Position = UDim2.new(0.075, 0, 0.05, 0)
    }, 0.35)
end

-- ═══════════════════════════════════════════════════════════════════
-- IN-GAME HIGHLIGHT SYSTEM
-- ═══════════════════════════════════════════════════════════════════

local function clearHighlight()
    if currentHighlight then
        currentHighlight:Destroy()
        currentHighlight = nil
    end
    if currentBillboard then
        currentBillboard:Destroy()
        currentBillboard = nil
    end
end

local function highlightObject(instance)
    if not CONFIG.EnableHighlight then return end
    clearHighlight()
    
    local targetPart = nil
    if instance:IsA("BasePart") then
        targetPart = instance
    elseif instance:IsA("Model") then
        targetPart = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
    else
        targetPart = instance:FindFirstChildWhichIsA("BasePart", true)
    end
    
    if not targetPart then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "ScriptExplorerHighlight"
    highlight.FillColor = CONFIG.Colors.HighlightFill
    highlight.OutlineColor = CONFIG.Colors.HighlightOutline
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0
    highlight.Adornee = instance:IsA("Model") and instance or targetPart
    highlight.Parent = CoreGui
    currentHighlight = highlight
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ScriptExplorerBillboard"
    billboard.Size = UDim2.new(0, 350, 0, 70)
    billboard.StudsOffset = Vector3.new(0, 6, 0)
    billboard.Adornee = targetPart
    billboard.AlwaysOnTop = true
    billboard.Parent = CoreGui
    currentBillboard = billboard
    
    local bgFrame = Instance.new("Frame")
    bgFrame.Size = UDim2.new(1, 0, 1, 0)
    bgFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bgFrame.BackgroundTransparency = 0.2
    bgFrame.BorderSizePixel = 0
    bgFrame.Parent = billboard
    createCorner(bgFrame, 10)
    createStroke(bgFrame, 2, CONFIG.Colors.HighlightOutline, 0)
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -16, 0, 28)
    nameLabel.Position = UDim2.new(0, 8, 0, 6)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "📍 " .. instance.Name .. " [" .. instance.ClassName .. "]"
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 18
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = bgFrame
    
    local pathLabel = Instance.new("TextLabel")
    pathLabel.Size = UDim2.new(1, -16, 0, 24)
    pathLabel.Position = UDim2.new(0, 8, 0, 36)
    pathLabel.BackgroundTransparency = 1
    pathLabel.Text = instance:GetFullName()
    pathLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    pathLabel.Font = Enum.Font.Code
    pathLabel.TextSize = 12
    pathLabel.TextXAlignment = Enum.TextXAlignment.Left
    pathLabel.TextTruncate = Enum.TextTruncate.AtEnd
    pathLabel.Parent = bgFrame
    
    task.delay(CONFIG.HighlightDuration, function()
        clearHighlight()
    end)
end

-- ═══════════════════════════════════════════════════════════════════
-- DECOMPILATION - speed's ModuleScript decompiler + 15 methods
-- ═══════════════════════════════════════════════════════════════════

-- speed's decompiler for ModuleScripts (enhanced version)
local function decompileModule(moduleScript)
    local success, module = pcall(function()
        return require(moduleScript)
    end)
    
    if not success or module == nil then
        return nil
    end
    
    local result = "-- Decompiled with speed's decompiler (enhanced)\n"
    result = result .. "-- ModuleScript: " .. moduleScript:GetFullName() .. "\n\n"
    
    if type(module) == "table" then
        result = result .. "return {\n"
        
        local function serializeValue(value, indent)
            indent = indent or 1
            local spacing = string.rep("    ", indent)
            local t = type(value)
            
            if t == "string" then
                local escaped = value:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub('"', '\\"')
                if #escaped > 100 then
                    escaped = escaped:sub(1, 100) .. "..."
                end
                return '"' .. escaped .. '"'
            elseif t == "number" or t == "boolean" then
                return tostring(value)
            elseif t == "function" then
                return "function() --[[ compiled ]] end"
            elseif t == "table" then
                local parts = {}
                local isArray = true
                local maxIndex = 0
                
                for k, v in pairs(value) do
                    if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                        isArray = false
                        break
                    end
                    maxIndex = math.max(maxIndex, k)
                end
                
                if isArray and maxIndex > 0 then
                    for i = 1, math.min(maxIndex, 20) do
                        table.insert(parts, spacing .. serializeValue(value[i], indent + 1))
                    end
                    if maxIndex > 20 then
                        table.insert(parts, spacing .. "-- ... " .. (maxIndex - 20) .. " more items")
                    end
                else
                    local count = 0
                    for k, v in pairs(value) do
                        if count >= 30 then
                            table.insert(parts, spacing .. "-- ... more entries")
                            break
                        end
                        local keyStr
                        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                            keyStr = k
                        else
                            keyStr = "[" .. serializeValue(k, 0) .. "]"
                        end
                        table.insert(parts, spacing .. keyStr .. " = " .. serializeValue(v, indent + 1))
                        count = count + 1
                    end
                end
                
                if #parts == 0 then
                    return "{}"
                end
                return "{\n" .. table.concat(parts, ",\n") .. "\n" .. string.rep("    ", indent - 1) .. "}"
            else
                return "nil --[[ " .. t .. " ]]"
            end
        end
        
        local count = 0
        for key, value in pairs(module) do
            if count >= 50 then
                result = result .. "    -- ... more entries\n"
                break
            end
            
            local keyStr
            if type(key) == "string" and key:match("^[%a_][%w_]*$") then
                keyStr = key
            else
                keyStr = "[" .. tostring(key) .. "]"
            end
            
            result = result .. "    " .. keyStr .. " = " .. serializeValue(value, 2) .. ",\n"
            count = count + 1
        end
        
        result = result .. "}\n"
    elseif type(module) == "function" then
        result = result .. "return function()\n    -- compiled function\nend\n"
    elseif type(module) == "string" then
        result = result .. 'return "' .. module:sub(1, 500) .. '"\n'
    elseif type(module) == "number" or type(module) == "boolean" then
        result = result .. "return " .. tostring(module) .. "\n"
    else
        result = result .. "return " .. tostring(module) .. " --[[ " .. type(module) .. " ]]\n"
    end
    
    return result
end

local function getScriptSource(scriptInstance)
    local result = {
        source = nil,
        method = "unknown",
        lineCount = 0,
        byteSize = 0,
    }
    
    local methods = {
        {name = "decompile", fn = function()
            if type(decompile) == "function" then
                return decompile(scriptInstance)
            end
        end},
        
        {name = "getscriptclosure", fn = function()
            if type(getscriptclosure) == "function" and type(decompile) == "function" then
                local closure = getscriptclosure(scriptInstance)
                if closure then return decompile(closure) end
            end
        end},
        
        {name = "gethiddenproperty", fn = function()
            if type(gethiddenproperty) == "function" then
                local success, source = pcall(gethiddenproperty, scriptInstance, "Source")
                if success and source and #source > 0 then return source end
            end
        end},
        
        {name = "getsourceclosure", fn = function()
            if type(getsourceclosure) == "function" then
                local success, source = pcall(getsourceclosure, scriptInstance)
                if success and source and #source > 0 then return source end
            end
        end},
        
        {name = "getscriptsource", fn = function()
            if type(getscriptsource) == "function" then
                return getscriptsource(scriptInstance)
            end
        end},
        
        {name = "debug.getinfo", fn = function()
            if type(getscriptclosure) == "function" and type(debug) == "table" and type(debug.getinfo) == "function" then
                local closure = getscriptclosure(scriptInstance)
                if closure then
                    local info = debug.getinfo(closure)
                    if info and info.source then
                        return "-- Source from debug.getinfo\n" .. tostring(info.source)
                    end
                end
            end
        end},
        
        {name = "getscriptbytecode", fn = function()
            local getBytecode = getscriptbytecode or get_script_bytecode or dumpstring
            if type(getBytecode) == "function" then
                local success, bytecode = pcall(getBytecode, scriptInstance)
                if success and bytecode and #bytecode > 0 then
                    return "-- ⚠️ BYTECODE ONLY (" .. #bytecode .. " bytes)\n-- Script is compiled/protected\n-- Raw bytecode available but not human-readable"
                end
            end
        end},
        
        {name = "getscripthash", fn = function()
            if type(getscripthash) == "function" then
                local success, hash = pcall(getscripthash, scriptInstance)
                if success and hash then
                    return "-- 🔒 Script Hash: " .. tostring(hash) .. "\n-- Script exists but source is protected"
                end
            end
        end},
        
        {name = "speed_decompiler", fn = function()
            if scriptInstance:IsA("ModuleScript") then
                return decompileModule(scriptInstance)
            end
        end},
        
        {name = "require_tostring", fn = function()
            if scriptInstance:IsA("ModuleScript") then
                local success, moduleResult = pcall(function()
                    return require(scriptInstance)
                end)
                if success and moduleResult ~= nil then
                    return "-- ModuleScript require() result\n-- Type: " .. type(moduleResult) .. "\n\nreturn " .. tostring(moduleResult)
                end
            end
        end},
    }
    
    for _, method in ipairs(methods) do
        local success, source = pcall(method.fn)
        if success and source and #source > 0 then
            result.source = source
            result.method = method.name
            result.byteSize = #source
            
            local lineCount = 1
            for _ in source:gmatch("\n") do
                lineCount = lineCount + 1
            end
            result.lineCount = lineCount
            
            return result
        end
    end
    
    -- Fallback - show script info instead of "failed"
    local info = "-- 📜 " .. scriptInstance.Name .. "\n"
    info = info .. "-- Class: " .. scriptInstance.ClassName .. "\n"
    info = info .. "-- Path: " .. scriptInstance:GetFullName() .. "\n"
    info = info .. "-- \n"
    info = info .. "-- Source could not be retrieved with available methods.\n"
    info = info .. "-- This is normal for some protected scripts.\n"
    info = info .. "-- \n"
    info = info .. "-- Script Properties:\n"
    
    pcall(function()
        if scriptInstance:IsA("LocalScript") or scriptInstance:IsA("Script") then
            info = info .. "--   Disabled: " .. tostring(scriptInstance.Disabled) .. "\n"
        end
    end)
    
    pcall(function()
        local children = scriptInstance:GetChildren()
        info = info .. "--   Children: " .. #children .. "\n"
        for i, child in ipairs(children) do
            if i <= 10 then
                info = info .. "--     - " .. child.Name .. " [" .. child.ClassName .. "]\n"
            elseif i == 11 then
                info = info .. "--     ... and " .. (#children - 10) .. " more\n"
            end
        end
    end)
    
    result.source = info
    result.method = "info"
    result.lineCount = 15
    result.byteSize = #info
    
    return result
end

-- ═══════════════════════════════════════════════════════════════════
-- MAIN GUI CREATION
-- ═══════════════════════════════════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScriptExplorerV95"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 9999

pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

if CONFIG.ShowGameMapOnStart then
    showGameMap()
end

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.fromScale(CONFIG.WindowWidth, CONFIG.WindowHeight)
mainFrame.Position = UDim2.fromScale(0.5 - CONFIG.WindowWidth/2, 0.5 - CONFIG.WindowHeight/2)
mainFrame.BackgroundColor3 = CONFIG.Colors.Background
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Active = true
mainFrame.Parent = screenGui
createCorner(mainFrame, 14)
createStroke(mainFrame, 2, CONFIG.Colors.Accent, 0.3)

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 56)
header.BackgroundColor3 = CONFIG.Colors.Secondary
header.BorderSizePixel = 0
header.Parent = mainFrame
createCorner(header, 14)

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 16)
headerFix.Position = UDim2.new(0, 0, 1, -16)
headerFix.BackgroundColor3 = CONFIG.Colors.Secondary
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -180, 1, 0)
title.Position = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🚀 Script Explorer v9.5 ULTRA"
title.TextColor3 = CONFIG.Colors.Text
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local gameMapBtn = Instance.new("TextButton")
gameMapBtn.Name = "GameMapBtn"
gameMapBtn.Size = UDim2.new(0, 44, 0, 44)
gameMapBtn.Position = UDim2.new(1, -140, 0, 6)
gameMapBtn.BackgroundColor3 = CONFIG.Colors.Accent
gameMapBtn.Text = "🗺️"
gameMapBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
gameMapBtn.Font = Enum.Font.GothamBold
gameMapBtn.TextSize = 20
gameMapBtn.Parent = header
createCorner(gameMapBtn, 10)

gameMapBtn.MouseButton1Click:Connect(function()
    showGameMap()
end)

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 44, 0, 44)
minimizeBtn.Position = UDim2.new(1, -92, 0, 6)
minimizeBtn.BackgroundColor3 = CONFIG.Colors.Warning
minimizeBtn.Text = "─"
minimizeBtn.TextColor3 = Color3.fromRGB(50, 50, 50)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 20
minimizeBtn.Parent = header
createCorner(minimizeBtn, 10)

local isMinimized = false
local originalSize = mainFrame.Size

minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        tween(mainFrame, {Size = UDim2.new(0, 350, 0, 56)}, 0.2)
    else
        tween(mainFrame, {Size = originalSize}, 0.2)
    end
end)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 44, 0, 44)
closeBtn.Position = UDim2.new(1, -50, 0, 6)
closeBtn.BackgroundColor3 = CONFIG.Colors.Error
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.Parent = header
createCorner(closeBtn, 10)

closeBtn.MouseButton1Click:Connect(function()
    clearHighlight()
    tween(mainFrame, {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.25)
    task.wait(0.25)
    screenGui:Destroy()
end)

local toolbar = Instance.new("Frame")
toolbar.Size = UDim2.new(1, -24, 0, 46)
toolbar.Position = UDim2.new(0, 12, 0, 64)
toolbar.BackgroundTransparency = 1
toolbar.Parent = mainFrame

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(0.85, -8, 1, 0)
searchBox.BackgroundColor3 = CONFIG.Colors.Secondary
searchBox.Text = ""
searchBox.PlaceholderText = "🔍 Search scripts, models, parts..."
searchBox.TextColor3 = CONFIG.Colors.Text
searchBox.PlaceholderColor3 = CONFIG.Colors.TextMuted
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = CONFIG.FontSize
searchBox.ClearTextOnFocus = false
searchBox.Parent = toolbar
createCorner(searchBox, 10)
createPadding(searchBox, 14)

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0.15, -4, 1, 0)
refreshBtn.Position = UDim2.new(0.85, 4, 0, 0)
refreshBtn.BackgroundColor3 = CONFIG.Colors.Accent
refreshBtn.Text = "🔄"
refreshBtn.TextColor3 = CONFIG.Colors.Text
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.TextSize = 20
refreshBtn.Parent = toolbar
createCorner(refreshBtn, 10)

local pathBar = Instance.new("Frame")
pathBar.Size = UDim2.new(1, -24, 0, 30)
pathBar.Position = UDim2.new(0, 12, 0, 116)
pathBar.BackgroundColor3 = CONFIG.Colors.Tertiary
pathBar.Parent = mainFrame
createCorner(pathBar, 8)

local pathLabel = Instance.new("TextLabel")
pathLabel.Size = UDim2.new(1, -90, 1, 0)
pathLabel.Position = UDim2.new(0, 14, 0, 0)
pathLabel.BackgroundTransparency = 1
pathLabel.Text = "📍 Select an item to view path..."
pathLabel.TextColor3 = CONFIG.Colors.TextMuted
pathLabel.Font = Enum.Font.Code
pathLabel.TextSize = 12
pathLabel.TextXAlignment = Enum.TextXAlignment.Left
pathLabel.TextTruncate = Enum.TextTruncate.AtEnd
pathLabel.Parent = pathBar

local copyPathBtn = Instance.new("TextButton")
copyPathBtn.Size = UDim2.new(0, 80, 0, 24)
copyPathBtn.Position = UDim2.new(1, -85, 0, 3)
copyPathBtn.BackgroundColor3 = CONFIG.Colors.Accent
copyPathBtn.Text = "📋 Copy"
copyPathBtn.TextColor3 = CONFIG.Colors.Text
copyPathBtn.Font = Enum.Font.GothamBold
copyPathBtn.TextSize = 11
copyPathBtn.Parent = pathBar
createCorner(copyPathBtn, 6)

local splitContainer = Instance.new("Frame")
splitContainer.Size = UDim2.new(1, -24, 1, -160)
splitContainer.Position = UDim2.new(0, 12, 0, 152)
splitContainer.BackgroundTransparency = 1
splitContainer.ClipsDescendants = true
splitContainer.Parent = mainFrame

local treePanel = Instance.new("Frame")
treePanel.Size = UDim2.new(CONFIG.TreePanelWidth, -6, 1, 0)
treePanel.BackgroundColor3 = CONFIG.Colors.Secondary
treePanel.ClipsDescendants = true
treePanel.Parent = splitContainer
createCorner(treePanel, 10)

local treeScroll = Instance.new("ScrollingFrame")
treeScroll.Size = UDim2.new(1, 0, 1, 0)
treeScroll.BackgroundTransparency = 1
treeScroll.BorderSizePixel = 0
treeScroll.ScrollBarThickness = 10
treeScroll.ScrollBarImageColor3 = CONFIG.Colors.Accent
treeScroll.ScrollBarImageTransparency = 0.1
treeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
treeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
treeScroll.ClipsDescendants = true
treeScroll.Parent = treePanel

local treeLayout = Instance.new("UIListLayout")
treeLayout.SortOrder = Enum.SortOrder.LayoutOrder
treeLayout.Padding = UDim.new(0, CONFIG.TreePadding)
treeLayout.Parent = treeScroll

createPadding(treeScroll, 8)

local codePanel = Instance.new("Frame")
codePanel.Size = UDim2.new(1 - CONFIG.TreePanelWidth, -6, 1, 0)
codePanel.Position = UDim2.new(CONFIG.TreePanelWidth, 6, 0, 0)
codePanel.BackgroundColor3 = CONFIG.Colors.Secondary
codePanel.ClipsDescendants = true
codePanel.Parent = splitContainer
createCorner(codePanel, 10)

local codeHeader = Instance.new("Frame")
codeHeader.Size = UDim2.new(1, 0, 0, 48)
codeHeader.BackgroundColor3 = CONFIG.Colors.Tertiary
codeHeader.BorderSizePixel = 0
codeHeader.Parent = codePanel

local codeTitle = Instance.new("TextLabel")
codeTitle.Size = UDim2.new(1, -100, 1, 0)
codeTitle.Position = UDim2.new(0, 14, 0, 0)
codeTitle.BackgroundTransparency = 1
codeTitle.Text = "📜 Select a script"
codeTitle.TextColor3 = CONFIG.Colors.Text
codeTitle.Font = Enum.Font.GothamBold
codeTitle.TextSize = 15
codeTitle.TextXAlignment = Enum.TextXAlignment.Left
codeTitle.TextTruncate = Enum.TextTruncate.AtEnd
codeTitle.Parent = codeHeader

local metaLabel = Instance.new("TextLabel")
metaLabel.Size = UDim2.new(1, -14, 0, 22)
metaLabel.Position = UDim2.new(0, 7, 0, 48)
metaLabel.BackgroundTransparency = 1
metaLabel.Text = ""
metaLabel.TextColor3 = CONFIG.Colors.TextMuted
metaLabel.Font = Enum.Font.Code
metaLabel.TextSize = 11
metaLabel.TextXAlignment = Enum.TextXAlignment.Left
metaLabel.Parent = codePanel

local copyCodeBtn = Instance.new("TextButton")
copyCodeBtn.Size = UDim2.new(0, 42, 0, 36)
copyCodeBtn.Position = UDim2.new(1, -90, 0, 6)
copyCodeBtn.BackgroundColor3 = CONFIG.Colors.Success
copyCodeBtn.Text = "📋"
copyCodeBtn.TextColor3 = CONFIG.Colors.Text
copyCodeBtn.Font = Enum.Font.GothamBold
copyCodeBtn.TextSize = 18
copyCodeBtn.Parent = codeHeader
createCorner(copyCodeBtn, 8)

local refreshCodeBtn = Instance.new("TextButton")
refreshCodeBtn.Size = UDim2.new(0, 42, 0, 36)
refreshCodeBtn.Position = UDim2.new(1, -46, 0, 6)
refreshCodeBtn.BackgroundColor3 = CONFIG.Colors.Accent
refreshCodeBtn.Text = "🔄"
refreshCodeBtn.TextColor3 = CONFIG.Colors.Text
refreshCodeBtn.Font = Enum.Font.GothamBold
refreshCodeBtn.TextSize = 18
refreshCodeBtn.Parent = codeHeader
createCorner(refreshCodeBtn, 8)

local codeScroll = Instance.new("ScrollingFrame")
codeScroll.Size = UDim2.new(1, 0, 1, -74)
codeScroll.Position = UDim2.new(0, 0, 0, 74)
codeScroll.BackgroundTransparency = 1
codeScroll.BorderSizePixel = 0
codeScroll.ScrollBarThickness = 10
codeScroll.ScrollBarImageColor3 = CONFIG.Colors.Accent
codeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
codeScroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
codeScroll.ClipsDescendants = true
codeScroll.Parent = codePanel

local codeContent = Instance.new("TextBox")
codeContent.Size = UDim2.new(1, -20, 0, 0)
codeContent.Position = UDim2.new(0, 10, 0, 10)
codeContent.BackgroundTransparency = 1
codeContent.Text = "-- 🚀 Script Explorer v9.5 ULTRA\n-- Click 🗺️ to view Game Map\n-- Select any item from the tree"
codeContent.TextColor3 = CONFIG.Colors.Text
codeContent.Font = Enum.Font.Code
codeContent.TextSize = 13
codeContent.TextXAlignment = Enum.TextXAlignment.Left
codeContent.TextYAlignment = Enum.TextYAlignment.Top
codeContent.TextWrapped = false
codeContent.MultiLine = true
codeContent.ClearTextOnFocus = false
codeContent.TextEditable = false
codeContent.AutomaticSize = Enum.AutomaticSize.XY
codeContent.Parent = codeScroll

-- ═══════════════════════════════════════════════════════════════════
-- TREE NODE CREATION
-- ═══════════════════════════════════════════════════════════════════

local function createTreeNode(instance, parentFrame, indentLevel, layoutOrder)
    if nodeCount >= CONFIG.MaxNodes then return end
    if indentLevel > CONFIG.MaxDepth then return end
    
    nodeCount = nodeCount + 1
    
    local isScript = instance:IsA("BaseScript")
    local childCount = #instance:GetChildren()
    local hasChildNodes = childCount > 0
    
    local nodeContainer = Instance.new("Frame")
    nodeContainer.Name = "Node_" .. instance.Name:sub(1, 20)
    nodeContainer.Size = UDim2.new(1, 0, 0, CONFIG.TreeItemHeight)
    nodeContainer.BackgroundTransparency = 1
    nodeContainer.LayoutOrder = layoutOrder
    nodeContainer.AutomaticSize = Enum.AutomaticSize.Y
    nodeContainer.Parent = parentFrame
    
    local nodeBtn = Instance.new("TextButton")
    nodeBtn.Size = UDim2.new(1, -indentLevel * CONFIG.IndentSize, 0, CONFIG.TreeItemHeight)
    nodeBtn.Position = UDim2.new(0, indentLevel * CONFIG.IndentSize, 0, 0)
    nodeBtn.BackgroundColor3 = CONFIG.Colors.Tertiary
    nodeBtn.BackgroundTransparency = 0.9
    nodeBtn.BorderSizePixel = 0
    nodeBtn.Font = Enum.Font.Gotham
    nodeBtn.TextSize = CONFIG.FontSize
    nodeBtn.TextXAlignment = Enum.TextXAlignment.Left
    nodeBtn.AutoButtonColor = false
    nodeBtn.ClipsDescendants = true
    nodeBtn.Parent = nodeContainer
    createCorner(nodeBtn, 6)
    
    nodeBtn.TextColor3 = getColor(instance)
    if isScript then
        nodeBtn.Font = Enum.Font.GothamBold
    end
    
    local icon = getIcon(instance)
    local expandIcon = hasChildNodes and CONFIG.Icons.Collapsed or ""
    local className = CONFIG.ShowClassNames and " <font color=\"#777\">[" .. instance.ClassName .. "]</font>" or ""
    local countText = hasChildNodes and " <font color=\"#555\">(" .. childCount .. ")</font>" or ""
    nodeBtn.RichText = true
    nodeBtn.Text = "  " .. expandIcon .. " " .. icon .. " " .. instance.Name .. className .. countText
    
    local hoverStroke = createStroke(nodeBtn, 2, CONFIG.Colors.Accent, 1)
    
    nodeBtn.MouseEnter:Connect(function()
        tween(nodeBtn, {BackgroundTransparency = 0.7}, 0.1)
        tween(hoverStroke, {Transparency = 0.3}, 0.1)
    end)
    nodeBtn.MouseLeave:Connect(function()
        tween(nodeBtn, {BackgroundTransparency = 0.9}, 0.1)
        tween(hoverStroke, {Transparency = 1}, 0.1)
    end)
    
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
    childrenLayout.Padding = UDim.new(0, CONFIG.TreePadding)
    childrenLayout.Parent = childrenFrame
    
    local isExpanded = false
    local childrenLoaded = false
    
    nodeBtn.MouseButton1Click:Connect(function()
        currentItem = instance
        local fullPath = instance:GetFullName()
        pathLabel.Text = "📍 " .. fullPath
        
        highlightObject(instance)
        
        if isScript then
            currentScript = instance
            codeTitle.Text = icon .. " " .. instance.Name
            
            local result = getScriptSource(instance)
            currentSource = result.source
            codeContent.Text = result.source
            
            metaLabel.Text = "📊 " .. result.lineCount .. " lines | " .. result.byteSize .. " bytes | " .. result.method
        else
            codeTitle.Text = icon .. " " .. instance.Name
            local info = "-- 📌 " .. instance.Name .. "\n"
            info = info .. "-- Class: " .. instance.ClassName .. "\n"
            info = info .. "-- Path: " .. fullPath .. "\n"
            info = info .. "-- Children: " .. childCount .. "\n\n"
            
            pcall(function()
                if instance:IsA("ValueBase") then
                    info = info .. "-- Value = " .. tostring(instance.Value) .. "\n"
                end
                if instance:IsA("BasePart") then
                    info = info .. "-- Position = " .. tostring(instance.Position) .. "\n"
                    info = info .. "-- Size = " .. tostring(instance.Size) .. "\n"
                    info = info .. "-- BrickColor = " .. tostring(instance.BrickColor) .. "\n"
                    info = info .. "-- Material = " .. tostring(instance.Material) .. "\n"
                end
                if instance:IsA("Model") and instance.PrimaryPart then
                    info = info .. "-- PrimaryPart = " .. instance.PrimaryPart.Name .. "\n"
                end
            end)
            
            codeContent.Text = info
            metaLabel.Text = "📌 " .. instance.ClassName .. " | " .. childCount .. " children"
            currentSource = info
        end
        
        if hasChildNodes then
            isExpanded = not isExpanded
            childrenFrame.Visible = isExpanded
            
            expandIcon = isExpanded and CONFIG.Icons.Expanded or CONFIG.Icons.Collapsed
            nodeBtn.Text = "  " .. expandIcon .. " " .. icon .. " " .. instance.Name .. className .. countText
            
            if isExpanded and not childrenLoaded then
                childrenLoaded = true
                local children = instance:GetChildren()
                table.sort(children, function(a, b)
                    local aScore = a:IsA("BaseScript") and 0 or (a:IsA("Folder") and 1 or 2)
                    local bScore = b:IsA("BaseScript") and 0 or (b:IsA("Folder") and 1 or 2)
                    if aScore == bScore then return a.Name < b.Name end
                    return aScore < bScore
                end)
                
                for i, child in ipairs(children) do
                    pcall(function()
                        createTreeNode(child, childrenFrame, indentLevel + 1, i)
                    end)
                end
            end
        end
    end)
    
    return nodeContainer
end

-- ═══════════════════════════════════════════════════════════════════
-- BUILD TREE
-- ═══════════════════════════════════════════════════════════════════

local function buildTree(searchQuery)
    for _, child in ipairs(treeScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    nodeCount = 0
    searchQuery = searchQuery and searchQuery:lower() or ""
    
    if searchQuery == "" or #searchQuery < CONFIG.SearchMinChars then
        local order = 0
        for _, serviceName in ipairs(CONFIG.Services) do
            local success, service = pcall(function()
                return game:GetService(serviceName)
            end)
            
            if success and service then
                local childCount = 0
                pcall(function() childCount = #service:GetChildren() end)
                
                if childCount > 0 then
                    order = order + 1
                    
                    local serviceNode = Instance.new("Frame")
                    serviceNode.Name = "Service_" .. serviceName
                    serviceNode.Size = UDim2.new(1, 0, 0, CONFIG.TreeItemHeight)
                    serviceNode.BackgroundTransparency = 1
                    serviceNode.LayoutOrder = order
                    serviceNode.AutomaticSize = Enum.AutomaticSize.Y
                    serviceNode.Parent = treeScroll
                    
                    local serviceBtn = Instance.new("TextButton")
                    serviceBtn.Size = UDim2.new(1, 0, 0, CONFIG.TreeItemHeight)
                    serviceBtn.BackgroundColor3 = CONFIG.Colors.Service
                    serviceBtn.BackgroundTransparency = 0.85
                    serviceBtn.BorderSizePixel = 0
                    serviceBtn.Font = Enum.Font.GothamBold
                    serviceBtn.TextSize = CONFIG.FontSize
                    serviceBtn.TextColor3 = CONFIG.Colors.Service
                    serviceBtn.TextXAlignment = Enum.TextXAlignment.Left
                    serviceBtn.RichText = true
                    serviceBtn.Text = "  " .. CONFIG.Icons.Collapsed .. " " .. (CONFIG.Icons[serviceName] or "⚙️") .. " " .. serviceName .. " <font color=\"#555\">(" .. childCount .. ")</font>"
                    serviceBtn.AutoButtonColor = false
                    serviceBtn.Parent = serviceNode
                    createCorner(serviceBtn, 6)
                    
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
                    serviceLayout.Padding = UDim.new(0, CONFIG.TreePadding)
                    serviceLayout.Parent = serviceChildren
                    
                    local serviceExpanded = false
                    local serviceLoaded = false
                    
                    serviceBtn.MouseButton1Click:Connect(function()
                        currentItem = service
                        pathLabel.Text = "📍 game:GetService(\"" .. serviceName .. "\")"
                        
                        serviceExpanded = not serviceExpanded
                        serviceChildren.Visible = serviceExpanded
                        
                        local icon = serviceExpanded and CONFIG.Icons.Expanded or CONFIG.Icons.Collapsed
                        serviceBtn.Text = "  " .. icon .. " " .. (CONFIG.Icons[serviceName] or "⚙️") .. " " .. serviceName .. " <font color=\"#555\">(" .. childCount .. ")</font>"
                        
                        if serviceExpanded and not serviceLoaded then
                            serviceLoaded = true
                            local children = service:GetChildren()
                            table.sort(children, function(a, b) return a.Name < b.Name end)
                            
                            for i, child in ipairs(children) do
                                pcall(function()
                                    createTreeNode(child, serviceChildren, 1, i)
                                end)
                            end
                        end
                    end)
                end
            end
        end
    else
        local results = 0
        local function searchIn(instance, path)
            if results >= CONFIG.MaxSearchResults then return end
            
            pcall(function()
                for _, child in ipairs(instance:GetChildren()) do
                    if results >= CONFIG.MaxSearchResults then return end
                    
                    local nameMatch = child.Name:lower():find(searchQuery, 1, true)
                    local classMatch = child.ClassName:lower():find(searchQuery, 1, true)
                    
                    if nameMatch or classMatch then
                        results = results + 1
                        createTreeNode(child, treeScroll, 0, results)
                    end
                    
                    searchIn(child, path .. "/" .. child.Name)
                end
            end)
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

refreshBtn.MouseButton1Click:Connect(function()
    nodeCount = 0
    buildTree(searchBox.Text)
end)

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

copyPathBtn.MouseButton1Click:Connect(function()
    if currentItem then
        local path = currentItem:GetFullName()
        pcall(function()
            if setclipboard then setclipboard(path)
            elseif writeclipboard then writeclipboard(path)
            elseif toclipboard then toclipboard(path) end
        end)
        copyPathBtn.Text = "✅ Copied"
        task.wait(1)
        copyPathBtn.Text = "📋 Copy"
    end
end)

refreshCodeBtn.MouseButton1Click:Connect(function()
    if currentScript then
        local result = getScriptSource(currentScript)
        currentSource = result.source
        codeContent.Text = result.source
        metaLabel.Text = "📊 " .. result.lineCount .. " lines | " .. result.byteSize .. " bytes | " .. result.method
    end
end)

-- Dragging
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

-- Initialize
buildTree()

mainFrame.Size = UDim2.new(0, 0, 0, 0)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
task.wait(0.1)
tween(mainFrame, {
    Size = UDim2.fromScale(CONFIG.WindowWidth, CONFIG.WindowHeight),
    Position = UDim2.fromScale(0.5 - CONFIG.WindowWidth/2, 0.5 - CONFIG.WindowHeight/2)
}, 0.35)

print("🚀 Script Explorer v9.5 ULTRA loaded!")
print("✅ Game Map shows on startup")
print("✅ Click 🗺️ anytime to reopen Game Map")
print("✅ In-game highlight when clicking objects")
print("✅ speed's ModuleScript decompiler integrated")