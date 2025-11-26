--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                    SCRIPT EXPLORER v10.2 FIXED EDITION                    ║
    ║                   All Services • No Lag • Clean Code                      ║
    ╠═══════════════════════════════════════════════════════════════════════════╣
    ║  • Fixed: All services now load properly (not just Workspace)             ║
    ║  • Fixed: Reduced initial lag with delayed scanning                       ║
    ║  • Fixed: Text display issues                                             ║
    ║  • Modular architecture with UI factory                                   ║
    ║  • Chunked copy (100 lines per click)                                     ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]

-- ════════════════════════════════════════════════════════════════════════════
-- MODULE: Config
-- ════════════════════════════════════════════════════════════════════════════

local Config = {
    Version = "10.2 FIXED",
    Window = { Width = 0.75, Height = 0.88 },
    Tree = { PanelWidth = 0.6, ItemHeight = 32, IndentSize = 16, MaxNodes = 5000, MaxDepth = 40 },
    Search = { Debounce = 0.5, MinChars = 2, MaxResults = 80 },
    
    Colors = {
        Background = Color3.fromRGB(18, 20, 26),
        Panel = Color3.fromRGB(26, 30, 40),
        Item = Color3.fromRGB(36, 42, 56),
        Accent = Color3.fromRGB(0, 150, 255),
        Text = Color3.fromRGB(235, 235, 240),
        Muted = Color3.fromRGB(120, 130, 150),
        LocalScript = Color3.fromRGB(255, 195, 70),
        Script = Color3.fromRGB(255, 95, 95),
        ModuleScript = Color3.fromRGB(95, 255, 145),
        Folder = Color3.fromRGB(255, 215, 90),
        Service = Color3.fromRGB(120, 190, 255),
        Success = Color3.fromRGB(75, 255, 120),
        Error = Color3.fromRGB(255, 90, 90),
        Highlight = Color3.fromRGB(0, 255, 200),
    },
    
    Icons = {
        LocalScript = "📜", Script = "📄", ModuleScript = "📦", Folder = "📁",
        Model = "🧱", Part = "🔷", Tool = "🔧", Sound = "🔊", RemoteEvent = "📡",
        RemoteFunction = "📞", ScreenGui = "🖥️", Frame = "🔲", Default = "📎",
    },
    
    -- All services to scan
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
        "TestService"
    },
}

-- ════════════════════════════════════════════════════════════════════════════
-- MODULE: Executor Support
-- ════════════════════════════════════════════════════════════════════════════

local Executor = {}

function Executor.has(name)
    local env = getfenv()
    return type(env[name]) == "function"
end

function Executor.call(name, ...)
    if not Executor.has(name) then return nil end
    local ok, result = pcall(getfenv()[name], ...)
    return ok and result or nil
end

function Executor.clipboard(text)
    if Executor.has("setclipboard") then
        pcall(setclipboard, text)
        return true
    elseif Executor.has("toclipboard") then
        pcall(toclipboard, text)
        return true
    end
    return false
end

-- ════════════════════════════════════════════════════════════════════════════
-- MODULE: State
-- ════════════════════════════════════════════════════════════════════════════

local State = {
    gui = nil,
    mainFrame = nil,
    treeScroll = nil,
    codeLabel = nil,
    pathLabel = nil,
    titleLabel = nil,
    metaLabel = nil,
    selected = nil,
    source = nil,
    nodeCount = 0,
    highlight = nil,
    billboard = nil,
}

-- ════════════════════════════════════════════════════════════════════════════
-- MODULE: UI Factory (No Duplication)
-- ════════════════════════════════════════════════════════════════════════════

local UI = {}

function UI.corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

function UI.stroke(parent, thickness, color, trans)
    local s = Instance.new("UIStroke")
    s.Thickness = thickness or 1
    s.Color = color or Config.Colors.Accent
    s.Transparency = trans or 0
    s.Parent = parent
    return s
end

function UI.padding(parent, size)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, size)
    p.PaddingBottom = UDim.new(0, size)
    p.PaddingLeft = UDim.new(0, size)
    p.PaddingRight = UDim.new(0, size)
    p.Parent = parent
    return p
end

function UI.list(parent, pad, dir)
    local l = Instance.new("UIListLayout")
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, pad or 2)
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.Parent = parent
    return l
end

function UI.tween(inst, props, dur)
    local ti = TweenInfo.new(dur or 0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    game:GetService("TweenService"):Create(inst, ti, props):Play()
end

function UI.frame(props)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = props.Color or Config.Colors.Panel
    f.BackgroundTransparency = props.Transparency or 0
    f.Size = props.Size or UDim2.new(1, 0, 1, 0)
    f.Position = props.Position or UDim2.new(0, 0, 0, 0)
    f.BorderSizePixel = 0
    f.ClipsDescendants = props.Clip or false
    if props.Corner then UI.corner(f, props.Corner) end
    f.Parent = props.Parent
    return f
end

function UI.label(props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = props.Size or UDim2.new(1, 0, 0, 20)
    l.Position = props.Position or UDim2.new(0, 0, 0, 0)
    l.Text = props.Text or ""
    l.TextColor3 = props.Color or Config.Colors.Text
    l.Font = props.Bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextSize = props.TextSize or 14
    l.TextXAlignment = props.AlignX or Enum.TextXAlignment.Left
    l.TextYAlignment = props.AlignY or Enum.TextYAlignment.Center
    l.TextTruncate = props.Truncate or Enum.TextTruncate.None
    l.RichText = props.Rich or false
    l.TextWrapped = props.Wrap or false
    l.Parent = props.Parent
    return l
end

function UI.button(props)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = props.Color or Config.Colors.Accent
    b.Size = props.Size or UDim2.new(0, 44, 0, 44)
    b.Position = props.Position or UDim2.new(0, 0, 0, 0)
    b.Text = props.Text or ""
    b.TextColor3 = props.TextColor or Config.Colors.Text
    b.Font = Enum.Font.GothamBold
    b.TextSize = props.TextSize or 18
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    UI.corner(b, props.Corner or 10)
    b.Parent = props.Parent
    if props.OnClick then b.MouseButton1Click:Connect(props.OnClick) end
    return b
end

function UI.scroll(props)
    local s = Instance.new("ScrollingFrame")
    s.BackgroundTransparency = props.Transparency or 1
    s.Size = props.Size or UDim2.new(1, 0, 1, 0)
    s.Position = props.Position or UDim2.new(0, 0, 0, 0)
    s.BorderSizePixel = 0
    s.ScrollBarThickness = 8
    s.ScrollBarImageColor3 = Config.Colors.Accent
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.CanvasSize = UDim2.new(0, 0, 0, 0)
    s.ClipsDescendants = true
    s.Parent = props.Parent
    return s
end

function UI.input(props)
    local t = Instance.new("TextBox")
    t.BackgroundColor3 = props.Color or Config.Colors.Panel
    t.Size = props.Size or UDim2.new(1, 0, 0, 40)
    t.Position = props.Position or UDim2.new(0, 0, 0, 0)
    t.Text = props.Text or ""
    t.PlaceholderText = props.Placeholder or ""
    t.TextColor3 = Config.Colors.Text
    t.PlaceholderColor3 = Config.Colors.Muted
    t.Font = Enum.Font.Gotham
    t.TextSize = props.TextSize or 14
    t.ClearTextOnFocus = false
    t.BorderSizePixel = 0
    UI.corner(t, props.Corner or 8)
    UI.padding(t, 10)
    t.Parent = props.Parent
    return t
end

-- ════════════════════════════════════════════════════════════════════════════
-- MODULE: Toast Notifications
-- ════════════════════════════════════════════════════════════════════════════

local Toast = { container = nil }

function Toast.init(parent)
    Toast.container = UI.frame({ 
        Size = UDim2.new(0, 300, 1, 0), 
        Position = UDim2.new(1, -310, 0, 0), 
        Transparency = 1, 
        Parent = parent 
    })
    UI.list(Toast.container, 8)
    UI.padding(Toast.container, 15)
end

function Toast.show(msg, dur, col)
    if not Toast.container then return end
    
    local toast = UI.frame({ 
        Size = UDim2.new(1, 0, 0, 0), 
        Color = col or Config.Colors.Panel, 
        Corner = 10, 
        Parent = Toast.container 
    })
    toast.AutomaticSize = Enum.AutomaticSize.Y
    UI.stroke(toast, 1, Config.Colors.Accent, 0.5)
    
    local txt = UI.label({ 
        Text = msg, 
        Size = UDim2.new(1, -16, 0, 0), 
        Position = UDim2.new(0, 8, 0, 8), 
        Wrap = true, 
        Parent = toast, 
        Bold = true, 
        TextSize = 12 
    })
    txt.AutomaticSize = Enum.AutomaticSize.Y
    
    -- Padding at bottom
    local pad = Instance.new("Frame")
    pad.Size = UDim2.new(1, 0, 0, 8)
    pad.BackgroundTransparency = 1
    pad.Parent = toast
    
    task.delay(dur or 3, function()
        if toast and toast.Parent then
            UI.tween(toast, {BackgroundTransparency = 1}, 0.3)
            UI.tween(txt, {TextTransparency = 1}, 0.3)
            task.wait(0.35)
            if toast.Parent then toast:Destroy() end
        end
    end)
end

-- ════════════════════════════════════════════════════════════════════════════
-- MODULE: Decompiler
-- ════════════════════════════════════════════════════════════════════════════

local Decompiler = {}

local function serializeTable(tbl, depth)
    if depth > 4 then return "{...}" end
    depth = depth or 1
    local indent = string.rep("    ", depth)
    local parts = {}
    local count = 0
    
    for k, v in pairs(tbl) do
        count = count + 1
        if count > 20 then
            table.insert(parts, indent .. "-- ... more entries")
            break
        end
        
        local key
        if type(k) == "string" then
            key = k:match("^[%a_][%w_]*$") and k or ('["' .. k .. '"]')
        else
            key = "[" .. tostring(k) .. "]"
        end
        
        local val
        if type(v) == "string" then
            local short = v:sub(1, 60):gsub('"', '\\"'):gsub("\n", "\\n")
            val = '"' .. short .. (v:len() > 60 and "..." or "") .. '"'
        elseif type(v) == "table" then
            val = serializeTable(v, depth + 1)
        elseif type(v) == "function" then
            val = "function() end"
        else
            val = tostring(v)
        end
        
        table.insert(parts, indent .. key .. " = " .. val)
    end
    
    if #parts == 0 then return "{}" end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. string.rep("    ", depth - 1) .. "}"
end

function Decompiler.decompileModule(mod)
    local ok, result = pcall(require, mod)
    if not ok or result == nil then return nil end
    
    local out = "-- ModuleScript Decompiled (speed's decompiler)\n"
    out = out .. "-- Path: " .. mod:GetFullName() .. "\n\n"
    
    if type(result) == "table" then
        out = out .. "return " .. serializeTable(result, 1)
    elseif type(result) == "function" then
        out = out .. "return function() end -- compiled"
    else
        out = out .. "return " .. tostring(result)
    end
    
    return out
end

function Decompiler.getSource(script)
    -- Try multiple decompile methods
    local methods = {
        function() return Executor.call("decompile", script) end,
        function() 
            local cl = Executor.call("getscriptclosure", script)
            return cl and Executor.call("decompile", cl)
        end,
        function()
            local ok, src = pcall(function() return gethiddenproperty(script, "Source") end)
            return ok and src and #src > 0 and src
        end,
        function() return Executor.call("getscriptsource", script) end,
        function()
            if script:IsA("ModuleScript") then
                return Decompiler.decompileModule(script)
            end
        end,
    }
    
    for _, method in ipairs(methods) do
        local ok, result = pcall(method)
        if ok and result and type(result) == "string" and #result > 10 then
            local lines = 1
            for _ in result:gmatch("\n") do lines = lines + 1 end
            return { source = result, lines = lines, bytes = #result }
        end
    end
    
    -- Fallback: show script info
    local info = "-- " .. script.Name .. " (" .. script.ClassName .. ")\n"
    info = info .. "-- Path: " .. script:GetFullName() .. "\n\n"
    info = info .. "-- Source requires decompiler support\n"
    info = info .. "-- Children: " .. #script:GetChildren()
    
    return { source = info, lines = 5, bytes = #info }
end

-- ════════════════════════════════════════════════════════════════════════════
-- MODULE: Highlighter (3D World)
-- ════════════════════════════════════════════════════════════════════════════

local Highlighter = {}

function Highlighter.clear()
    if State.highlight then 
        pcall(function() State.highlight:Destroy() end)
        State.highlight = nil 
    end
    if State.billboard then 
        pcall(function() State.billboard:Destroy() end)
        State.billboard = nil 
    end
end

function Highlighter.show(instance)
    Highlighter.clear()
    
    -- Find a part to highlight
    local target = nil
    if instance:IsA("BasePart") then
        target = instance
    elseif instance:IsA("Model") then
        target = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
    else
        target = instance:FindFirstChildWhichIsA("BasePart", true)
    end
    
    if not target then return end
    
    local CoreGui = game:GetService("CoreGui")
    
    -- Create highlight
    State.highlight = Instance.new("Highlight")
    State.highlight.FillColor = Config.Colors.Highlight
    State.highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
    State.highlight.FillTransparency = 0.6
    State.highlight.Adornee = instance:IsA("Model") and instance or target
    pcall(function() State.highlight.Parent = CoreGui end)
    
    -- Create billboard
    State.billboard = Instance.new("BillboardGui")
    State.billboard.Size = UDim2.new(0, 280, 0, 55)
    State.billboard.StudsOffset = Vector3.new(0, 4, 0)
    State.billboard.Adornee = target
    State.billboard.AlwaysOnTop = true
    pcall(function() State.billboard.Parent = CoreGui end)
    
    local bg = UI.frame({ Color = Color3.new(0, 0, 0), Corner = 8, Parent = State.billboard })
    bg.BackgroundTransparency = 0.25
    UI.stroke(bg, 2, Color3.fromRGB(255, 255, 0))
    
    UI.label({ 
        Text = "📍 " .. instance.Name .. " [" .. instance.ClassName .. "]", 
        Size = UDim2.new(1, -10, 0, 22), 
        Position = UDim2.new(0, 5, 0, 4),
        Color = Color3.fromRGB(255, 255, 100), 
        Bold = true, 
        TextSize = 14, 
        Parent = bg 
    })
    
    UI.label({ 
        Text = instance:GetFullName(), 
        Size = UDim2.new(1, -10, 0, 18), 
        Position = UDim2.new(0, 5, 0, 28),
        Color = Color3.fromRGB(200, 200, 200), 
        TextSize = 10, 
        Truncate = Enum.TextTruncate.AtEnd, 
        Parent = bg 
    })
    
    task.delay(5, Highlighter.clear)
end

-- ════════════════════════════════════════════════════════════════════════════
-- MODULE: Scanner
-- ════════════════════════════════════════════════════════════════════════════

local Scanner = {}

function Scanner.getIcon(inst)
    return Config.Icons[inst.ClassName] 
        or (inst:IsA("BaseScript") and Config.Icons.Script)
        or (inst:IsA("BasePart") and Config.Icons.Part)
        or (inst:IsA("Folder") and Config.Icons.Folder)
        or (inst:IsA("Model") and Config.Icons.Model)
        or Config.Icons.Default
end

function Scanner.getColor(inst)
    if inst:IsA("LocalScript") then return Config.Colors.LocalScript
    elseif inst:IsA("Script") then return Config.Colors.Script
    elseif inst:IsA("ModuleScript") then return Config.Colors.ModuleScript
    elseif inst:IsA("Folder") then return Config.Colors.Folder
    else return Config.Colors.Muted end
end

function Scanner.generateMap()
    local maps = {}
    local totalObjs = 0
    local totalScripts = 0
    
    for _, serviceName in ipairs(Config.Services) do
        local ok, service = pcall(function()
            return game:GetService(serviceName)
        end)
        
        if ok and service then
            local lines = {}
            local objs = 0
            local scripts = 0
            
            local function scan(inst, depth, path)
                objs = objs + 1
                if inst:IsA("BaseScript") then scripts = scripts + 1 end
                
                local icon = Scanner.getIcon(inst)
                local line = string.rep("  ", depth) .. icon .. " " .. inst.Name .. " [" .. inst.ClassName .. "] -- " .. path
                table.insert(lines, line)
                
                local children = {}
                pcall(function() children = inst:GetChildren() end)
                
                for _, child in ipairs(children) do
                    pcall(function()
                        scan(child, depth + 1, path .. "." .. child.Name)
                    end)
                end
            end
            
            local serviceChildren = {}
            pcall(function() serviceChildren = service:GetChildren() end)
            
            for _, child in ipairs(serviceChildren) do
                pcall(function()
                    scan(child, 0, serviceName .. "." .. child.Name)
                end)
            end
            
            totalObjs = totalObjs + objs
            totalScripts = totalScripts + scripts
            
            if #lines > 0 then
                maps[serviceName] = { 
                    lines = lines, 
                    objs = objs, 
                    scripts = scripts 
                }
            end
        end
    end
    
    return maps, totalObjs, totalScripts
end

function Scanner.search(query)
    local results = {}
    query = query:lower()
    
    local function searchIn(instance)
        if #results >= Config.Search.MaxResults then return end
        
        local children = {}
        pcall(function() children = instance:GetChildren() end)
        
        for _, child in ipairs(children) do
            if #results >= Config.Search.MaxResults then return end
            
            local nameMatch = child.Name:lower():find(query, 1, true)
            local classMatch = child.ClassName:lower():find(query, 1, true)
            
            if nameMatch or classMatch then
                table.insert(results, child)
            end
            
            pcall(function() searchIn(child) end)
        end
    end
    
    for _, serviceName in ipairs(Config.Services) do
        if #results >= Config.Search.MaxResults then break end
        local ok, service = pcall(game.GetService, game, serviceName)
        if ok and service then
            pcall(function() searchIn(service) end)
        end
    end
    
    return results
end

-- ════════════════════════════════════════════════════════════════════════════
-- MODULE: Explorer
-- ════════════════════════════════════════════════════════════════════════════

local Explorer = {}

function Explorer.selectItem(instance)
    State.selected = instance
    
    if State.pathLabel then 
        State.pathLabel.Text = "📍 " .. instance:GetFullName() 
    end
    
    local icon = Scanner.getIcon(instance)
    if State.titleLabel then 
        State.titleLabel.Text = icon .. " " .. instance.Name 
    end
    
    -- Highlight in 3D world
    Highlighter.show(instance)
    
    -- Show toast
    Toast.show(icon .. " " .. instance.Name .. "\n[" .. instance.ClassName .. "]", 2)
    
    -- Get source or info
    if instance:IsA("BaseScript") then
        local result = Decompiler.getSource(instance)
        State.source = result.source
        if State.codeLabel then State.codeLabel.Text = result.source end
        if State.metaLabel then State.metaLabel.Text = "📊 " .. result.lines .. " lines | " .. result.bytes .. " bytes" end
    else
        local info = "-- " .. instance.Name .. "\n"
        info = info .. "-- Class: " .. instance.ClassName .. "\n"
        info = info .. "-- Path: " .. instance:GetFullName() .. "\n"
        info = info .. "-- Children: " .. #instance:GetChildren()
        
        pcall(function()
            if instance:IsA("BasePart") then
                info = info .. "\n-- Position: " .. tostring(instance.Position)
                info = info .. "\n-- Size: " .. tostring(instance.Size)
            elseif instance:IsA("ValueBase") then
                info = info .. "\n-- Value: " .. tostring(instance.Value)
            end
        end)
        
        State.source = info
        if State.codeLabel then State.codeLabel.Text = info end
        if State.metaLabel then State.metaLabel.Text = "📌 " .. instance.ClassName end
    end
end

function Explorer.createNode(instance, parent, indent, order)
    if State.nodeCount >= Config.Tree.MaxNodes then return end
    if indent > Config.Tree.MaxDepth then return end
    State.nodeCount = State.nodeCount + 1
    
    local isScript = instance:IsA("BaseScript")
    local childCount = 0
    pcall(function() childCount = #instance:GetChildren() end)
    local hasChildren = childCount > 0
    
    local container = UI.frame({ 
        Size = UDim2.new(1, 0, 0, Config.Tree.ItemHeight), 
        Transparency = 1, 
        Parent = parent 
    })
    container.LayoutOrder = order
    container.AutomaticSize = Enum.AutomaticSize.Y
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -indent * Config.Tree.IndentSize, 0, Config.Tree.ItemHeight)
    btn.Position = UDim2.new(0, indent * Config.Tree.IndentSize, 0, 0)
    btn.BackgroundColor3 = Config.Colors.Item
    btn.BackgroundTransparency = 0.92
    btn.BorderSizePixel = 0
    btn.Font = isScript and Enum.Font.GothamBold or Enum.Font.Gotham
    btn.TextSize = 12
    btn.TextColor3 = Scanner.getColor(instance)
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.RichText = true
    btn.AutoButtonColor = false
    btn.Parent = container
    UI.corner(btn, 5)
    
    local icon = Scanner.getIcon(instance)
    local arrow = hasChildren and "▶" or ""
    btn.Text = "  " .. arrow .. " " .. icon .. " " .. instance.Name .. 
               ' <font color="#666">[' .. instance.ClassName .. ']</font>' ..
               (hasChildren and ' <font color="#555">(' .. childCount .. ')</font>' or "")
    
    -- Hover effect
    btn.MouseEnter:Connect(function() 
        UI.tween(btn, {BackgroundTransparency = 0.75}, 0.1) 
    end)
    btn.MouseLeave:Connect(function() 
        UI.tween(btn, {BackgroundTransparency = 0.92}, 0.1) 
    end)
    
    -- Children container
    local childrenFrame = UI.frame({ 
        Size = UDim2.new(1, 0, 0, 0), 
        Position = UDim2.new(0, 0, 0, Config.Tree.ItemHeight), 
        Transparency = 1, 
        Parent = container 
    })
    childrenFrame.Visible = false
    childrenFrame.AutomaticSize = Enum.AutomaticSize.Y
    UI.list(childrenFrame, 1)
    
    local isExpanded = false
    local childrenLoaded = false
    
    btn.MouseButton1Click:Connect(function()
        Explorer.selectItem(instance)
        
        if hasChildren then
            isExpanded = not isExpanded
            childrenFrame.Visible = isExpanded
            
            arrow = isExpanded and "▼" or "▶"
            btn.Text = "  " .. arrow .. " " .. icon .. " " .. instance.Name .. 
                       ' <font color="#666">[' .. instance.ClassName .. ']</font>' ..
                       ' <font color="#555">(' .. childCount .. ')</font>'
            
            if isExpanded and not childrenLoaded then
                childrenLoaded = true
                
                local children = {}
                pcall(function() children = instance:GetChildren() end)
                
                table.sort(children, function(a, b)
                    local aScore = a:IsA("BaseScript") and 0 or (a:IsA("Folder") and 1 or 2)
                    local bScore = b:IsA("BaseScript") and 0 or (b:IsA("Folder") and 1 or 2)
                    if aScore == bScore then return a.Name < b.Name end
                    return aScore < bScore
                end)
                
                for i, child in ipairs(children) do
                    pcall(function()
                        Explorer.createNode(child, childrenFrame, indent + 1, i)
                    end)
                end
            end
        end
    end)
end

function Explorer.buildTree(query)
    -- Clear existing
    for _, child in ipairs(State.treeScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    State.nodeCount = 0
    
    if query and #query >= Config.Search.MinChars then
        local results = Scanner.search(query)
        for i, instance in ipairs(results) do
            pcall(function()
                Explorer.createNode(instance, State.treeScroll, 0, i)
            end)
        end
    else
        local order = 0
        for _, serviceName in ipairs(Config.Services) do
            local ok, service = pcall(game.GetService, game, serviceName)
            if not ok or not service then continue end
            
            local childCount = 0
            pcall(function() childCount = #service:GetChildren() end)
            if childCount == 0 then continue end
            
            order = order + 1
            
            local serviceNode = UI.frame({ 
                Size = UDim2.new(1, 0, 0, Config.Tree.ItemHeight), 
                Transparency = 1, 
                Parent = State.treeScroll 
            })
            serviceNode.LayoutOrder = order
            serviceNode.AutomaticSize = Enum.AutomaticSize.Y
            
            local serviceBtn = Instance.new("TextButton")
            serviceBtn.Size = UDim2.new(1, 0, 0, Config.Tree.ItemHeight)
            serviceBtn.BackgroundColor3 = Config.Colors.Service
            serviceBtn.BackgroundTransparency = 0.88
            serviceBtn.BorderSizePixel = 0
            serviceBtn.Font = Enum.Font.GothamBold
            serviceBtn.TextSize = 12
            serviceBtn.TextColor3 = Config.Colors.Service
            serviceBtn.TextXAlignment = Enum.TextXAlignment.Left
            serviceBtn.RichText = true
            serviceBtn.Text = '  ▶ 📂 ' .. serviceName .. ' <font color="#555">(' .. childCount .. ')</font>'
            serviceBtn.AutoButtonColor = false
            serviceBtn.Parent = serviceNode
            UI.corner(serviceBtn, 5)
            
            local serviceChildren = UI.frame({ 
                Size = UDim2.new(1, 0, 0, 0), 
                Position = UDim2.new(0, 0, 0, Config.Tree.ItemHeight), 
                Transparency = 1, 
                Parent = serviceNode 
            })
            serviceChildren.Visible = false
            serviceChildren.AutomaticSize = Enum.AutomaticSize.Y
            UI.list(serviceChildren, 1)
            
            local serviceExpanded = false
            local serviceLoaded = false
            
            serviceBtn.MouseButton1Click:Connect(function()
                serviceExpanded = not serviceExpanded
                serviceChildren.Visible = serviceExpanded
                serviceBtn.Text = '  ' .. (serviceExpanded and "▼" or "▶") .. ' 📂 ' .. serviceName .. ' <font color="#555">(' .. childCount .. ')</font>'
                
                if serviceExpanded and not serviceLoaded then
                    serviceLoaded = true
                    
                    local children = {}
                    pcall(function() children = service:GetChildren() end)
                    table.sort(children, function(a, b) return a.Name < b.Name end)
                    
                    for i, child in ipairs(children) do
                        pcall(function()
                            Explorer.createNode(child, serviceChildren, 1, i)
                        end)
                    end
                end
            end)
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════════
-- MODULE: GameMap (Full Object List)
-- ════════════════════════════════════════════════════════════════════════════

local GameMap = {}

function GameMap.show()
    local Players = game:GetService("Players")
    local CoreGui = game:GetService("CoreGui")
    
    local mapGui = Instance.new("ScreenGui")
    mapGui.Name = "GameMapViewer"
    mapGui.ResetOnSpawn = false
    mapGui.DisplayOrder = 99999
    mapGui.IgnoreGuiInset = true
    pcall(function() mapGui.Parent = CoreGui end)
    if not mapGui.Parent then 
        mapGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") 
    end
    
    local mapFrame = UI.frame({ 
        Size = UDim2.new(0.85, 0, 0.9, 0), 
        Position = UDim2.new(0.075, 0, 0.05, 0), 
        Color = Config.Colors.Background, 
        Corner = 16, 
        Parent = mapGui 
    })
    UI.stroke(mapFrame, 3, Config.Colors.Accent, 0.2)
    
    -- Header
    local header = UI.frame({ 
        Size = UDim2.new(1, 0, 0, 55), 
        Color = Config.Colors.Panel, 
        Corner = 16, 
        Parent = mapFrame 
    })
    UI.label({ 
        Text = "🗺️ GAME MAP - Full Object List", 
        Size = UDim2.new(1, -250, 1, 0), 
        Position = UDim2.new(0, 20, 0, 0), 
        Bold = true, 
        TextSize = 20, 
        Parent = header 
    })
    
    UI.button({ 
        Text = "✕", 
        Size = UDim2.new(0, 45, 0, 45), 
        Position = UDim2.new(1, -50, 0, 5), 
        Color = Config.Colors.Error, 
        OnClick = function() mapGui:Destroy() end, 
        Parent = header 
    })
    
    UI.button({ 
        Text = "✅ Open Explorer", 
        Size = UDim2.new(0, 150, 0, 38), 
        Position = UDim2.new(1, -210, 0, 8), 
        Color = Config.Colors.Success, 
        TextSize = 14,
        OnClick = function() mapGui:Destroy() end, 
        Parent = header 
    })
    
    -- Loading text
    local loading = UI.label({ 
        Text = "🔄 Scanning game... (this may take a moment)", 
        Size = UDim2.new(1, 0, 1, -55), 
        Position = UDim2.new(0, 0, 0, 55), 
        AlignX = Enum.TextXAlignment.Center, 
        TextSize = 20, 
        Color = Config.Colors.Muted, 
        Parent = mapFrame 
    })
    
    -- Delayed scan to prevent lag
    task.delay(0.5, function()
        if not mapGui.Parent then return end
        
        local maps, totalObjs, totalScripts = Scanner.generateMap()
        
        if not mapGui.Parent then return end
        loading:Destroy()
        
        -- Stats bar
        local stats = UI.frame({ 
            Size = UDim2.new(1, -20, 0, 32), 
            Position = UDim2.new(0, 10, 0, 62), 
            Color = Config.Colors.Item, 
            Corner = 8, 
            Parent = mapFrame 
        })
        UI.label({ 
            Text = "📊 Total: " .. totalObjs .. " objects | " .. totalScripts .. " scripts", 
            Size = UDim2.new(1, -20, 1, 0), 
            Position = UDim2.new(0, 10, 0, 0), 
            Color = Config.Colors.Accent, 
            Bold = true, 
            Parent = stats 
        })
        
        -- Tabs container
        local tabs = UI.scroll({ 
            Size = UDim2.new(1, -20, 0, 40), 
            Position = UDim2.new(0, 10, 0, 100), 
            Parent = mapFrame 
        })
        tabs.ScrollBarThickness = 0
        tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
        UI.list(tabs, 5, Enum.FillDirection.Horizontal)
        
        -- Content area
        local content = UI.scroll({ 
            Size = UDim2.new(1, -20, 1, -155), 
            Position = UDim2.new(0, 10, 0, 148), 
            Parent = mapFrame 
        })
        content.BackgroundColor3 = Config.Colors.Panel
        content.BackgroundTransparency = 0
        UI.corner(content, 10)
        
        -- Use TextLabel for maximum compatibility and reliable auto sizing
        local contentBox = Instance.new("TextLabel")
        contentBox.Size = UDim2.new(1, -20, 0, 0)
        contentBox.Position = UDim2.new(0, 10, 0, 10)
        contentBox.BackgroundTransparency = 1
        contentBox.TextColor3 = Config.Colors.Text
        contentBox.Font = Enum.Font.Code
        contentBox.TextSize = 11
        contentBox.TextXAlignment = Enum.TextXAlignment.Left
        contentBox.TextYAlignment = Enum.TextYAlignment.Top
        contentBox.TextWrapped = false
        contentBox.AutomaticSize = Enum.AutomaticSize.Y
        contentBox.Parent = content
        
        local currentTab = nil
        local tabButtons = {}
        local currentServiceName = nil
        
        -- Chunked copy state
        local copyTabIndex = 0
        local copyAllIndex = 0
        local copyAllLines = {}
        local LINES_PER_COPY = 300
        local copyCurrent

        -- Limit for how much text we put into the on-screen label.
        -- Roblox Text objects cannot exceed 200,000 characters.
        local MAX_DISPLAY_CHARS = 180000

        local function buildDisplayText(serviceName)
            local data = maps[serviceName]
            if not (data and data.lines and #data.lines > 0) then
                return "-- No data for " .. serviceName
            end

            local headerText = "-- " .. serviceName .. " (" .. data.objs .. " objects, " .. data.scripts .. " scripts)" .. string.char(10) .. string.char(10)
            local buffer = { headerText }
            local totalLen = #headerText

            for i, line in ipairs(data.lines) do
                local part = line .. string.char(10)
                local newLen = totalLen + #part
                if newLen > MAX_DISPLAY_CHARS then
                    table.insert(buffer, string.char(10))
                    table.insert(buffer, "-- [Display truncated at " .. (i - 1) .. " lines]")
                    table.insert(buffer, string.char(10))
                    table.insert(buffer, "-- Use the copy buttons to get the full content in chunks of 300 lines.")
                    table.insert(buffer, string.char(10))
                    break
                end
                table.insert(buffer, part)
                totalLen = newLen
            end

            return table.concat(buffer)
        end

        local function getBaseStart(serviceName, totalLines)
            local baseStart = ((serviceName == "Workspace") or (serviceName == "ReplicatedStorage")) and 1500 or 1
            if baseStart > totalLines then
                baseStart = 1
            end
            return baseStart
        end
        
        local function showService(serviceName)
            if currentTab then 
                currentTab.BackgroundColor3 = Config.Colors.Item 
            end
            if tabButtons[serviceName] then
                tabButtons[serviceName].BackgroundColor3 = Config.Colors.Accent
                currentTab = tabButtons[serviceName]
            end
            
            currentServiceName = serviceName
            copyTabIndex = 0
            
            contentBox.Text = buildDisplayText(serviceName)

            -- Update copy button label for this service
            if copyCurrent and maps[serviceName] and maps[serviceName].lines then
                local totalLines = #maps[serviceName].lines
                local baseStart = getBaseStart(serviceName, totalLines)
                local baseEnd = math.min(baseStart + LINES_PER_COPY - 1, totalLines)
                if baseStart == 1 then
                    copyCurrent.Text = "📋 Copy 1-" .. baseEnd
                else
                    copyCurrent.Text = "📋 " .. baseStart .. "-" .. baseEnd
                end
            end

            -- Force update of scroll area so content is always visible
            task.delay(0, function()
                pcall(function()
                    content.CanvasSize = UDim2.new(0, 0, 0, contentBox.TextBounds.Y + 20)
                end)
            end)
        end
        
        -- Copy Tab Button (300 lines per click)
        copyCurrent = UI.button({ 
            Text = "📋 Copy 1-300", 
            Size = UDim2.new(0, 100, 0, 32), 
            Color = Config.Colors.Accent, 
            TextSize = 10, 
            Corner = 6, 
            Parent = tabs 
        })
        copyCurrent.LayoutOrder = 998
        
        copyCurrent.MouseButton1Click:Connect(function()
            if currentServiceName and maps[currentServiceName] then
                local allLines = maps[currentServiceName].lines
                local totalLines = #allLines
                local baseStart = getBaseStart(currentServiceName, totalLines)
                local startLine = baseStart + copyTabIndex * LINES_PER_COPY
                local endLine = math.min(startLine + LINES_PER_COPY - 1, totalLines)
                
                if startLine > totalLines then
                    copyTabIndex = 0
                    startLine = baseStart
                    endLine = math.min(startLine + LINES_PER_COPY - 1, totalLines)
                end
                
                local chunk = {}
                for i = startLine, endLine do
                    table.insert(chunk, allLines[i])
                end
                
                local hdr = "-- " .. currentServiceName .. " [Lines " .. startLine .. "-" .. endLine .. " of " .. totalLines .. "]" .. string.char(10) .. string.char(10)
                Executor.clipboard(hdr .. table.concat(chunk, string.char(10)))
                
                copyCurrent.Text = "✅ " .. startLine .. "-" .. endLine
                copyTabIndex = copyTabIndex + 1
                
                local nextStart = baseStart + copyTabIndex * LINES_PER_COPY
                task.wait(1)
                if nextStart > totalLines then
                    local baseEnd = math.min(baseStart + LINES_PER_COPY - 1, totalLines)
                    if baseStart == 1 then
                        copyCurrent.Text = "📋 Copy 1-" .. baseEnd
                    else
                        copyCurrent.Text = "📋 " .. baseStart .. "-" .. baseEnd
                    end
                    copyTabIndex = 0
                else
                    local nextEnd = math.min(nextStart + LINES_PER_COPY - 1, totalLines)
                    copyCurrent.Text = "📋 " .. nextStart .. "-" .. nextEnd
                end
            end
        end)
        
        -- Copy All Button
        local copyAll = UI.button({ 
            Text = "📋 All 1-300", 
            Size = UDim2.new(0, 100, 0, 32), 
            Color = Config.Colors.Success, 
            TextSize = 10, 
            Corner = 6, 
            Parent = tabs 
        })
        copyAll.LayoutOrder = 999
        
        copyAll.MouseButton1Click:Connect(function()
            -- Build full lines array if empty
            if #copyAllLines == 0 then
                copyAllLines = {"-- FULL GAME MAP", "-- Script Explorer v" .. Config.Version, ""}
                for _, sn in ipairs(Config.Services) do
                    local data = maps[sn]
                    if data and data.lines and #data.lines > 0 then
                        table.insert(copyAllLines, "-- ═══════════════════════════════════════")
                        table.insert(copyAllLines, "-- " .. sn .. " (" .. data.objs .. " objects, " .. data.scripts .. " scripts)")
                        table.insert(copyAllLines, "-- ═══════════════════════════════════════")
                        table.insert(copyAllLines, "")
                        for _, line in ipairs(data.lines) do
                            table.insert(copyAllLines, line)
                        end
                        table.insert(copyAllLines, "")
                    end
                end
            end
            
            local totalLines = #copyAllLines
            local startLine = copyAllIndex * LINES_PER_COPY + 1
            local endLine = math.min(startLine + LINES_PER_COPY - 1, totalLines)
            
            if startLine > totalLines then
                copyAllIndex = 0
                startLine = 1
                endLine = math.min(LINES_PER_COPY, totalLines)
            end
            
            local chunk = {}
            for i = startLine, endLine do
                table.insert(chunk, copyAllLines[i])
            end
            
            local hdr = "-- [Lines " .. startLine .. "-" .. endLine .. " of " .. totalLines .. "]" .. string.char(10) .. string.char(10)
            Executor.clipboard(hdr .. table.concat(chunk, string.char(10)))
            
            copyAll.Text = "✅ " .. startLine .. "-" .. endLine
            copyAllIndex = copyAllIndex + 1
            
            local nextStart = copyAllIndex * LINES_PER_COPY + 1
            task.wait(1)
            if nextStart > totalLines then
                copyAll.Text = "📋 All 1-300"
                copyAllIndex = 0
                copyAllLines = {}
            else
                local nextEnd = math.min(nextStart + LINES_PER_COPY - 1, totalLines)
                copyAll.Text = "📋 All " .. nextStart .. "-" .. nextEnd
            end
        end)
        
        -- Save Files Button (writes per-service maps into executor files)
        local saveBtn = UI.button({ 
            Text = "💾 Save Files", 
            Size = UDim2.new(0, 110, 0, 32), 
            Color = Config.Colors.Item, 
            TextSize = 10, 
            Corner = 6, 
            Parent = tabs 
        })
        saveBtn.LayoutOrder = 997

        saveBtn.MouseButton1Click:Connect(function()
            local saved = 0

            -- Prefer executor filesystem if available
            if Executor.has("writefile") then
                local folderName = "ScriptExplorer_Maps"
                pcall(function()
                    if Executor.has("isfolder") then
                        if not Executor.call("isfolder", folderName) then
                            Executor.call("makefolder", folderName)
                        end
                    elseif Executor.has("makefolder") then
                        Executor.call("makefolder", folderName)
                    end
                end)

                for serviceName, data in pairs(maps) do
                    if data and data.lines and #data.lines > 0 then
                        local filePath = folderName .. "/" .. serviceName .. ".txt"
                        local header = "-- " .. serviceName .. " (" .. data.objs .. " objects, " .. data.scripts .. " scripts)" .. string.char(10) .. string.char(10)
                        local ok = pcall(function()
                            Executor.call("writefile", filePath, header .. table.concat(data.lines, string.char(10)))
                        end)
                        if ok then
                            saved = saved + 1
                        end
                    end
                end

                if saved > 0 then
                    Toast.show("💾 Saved " .. saved .. " files to /" .. folderName, 3, Config.Colors.Success)
                else
                    Toast.show("⚠️ Nothing to save", 3, Config.Colors.Error)
                end
                return
            end

            -- Fallback: save into Workspace / Workspace.Delta as StringValues
            local root = game:GetService("Workspace")
            local parentFolder = root:FindFirstChild("Delta") or root

            local mapsFolder = parentFolder:FindFirstChild("ScriptExplorer_Maps")
            if not mapsFolder then
                mapsFolder = Instance.new("Folder")
                mapsFolder.Name = "ScriptExplorer_Maps"
                mapsFolder.Parent = parentFolder
            end

            -- Clear previous contents
            for _, child in ipairs(mapsFolder:GetChildren()) do
                pcall(function() child:Destroy() end)
            end

            local MAX_CHUNK = 180000 -- keep below Roblox's 200k StringValue limit

            for serviceName, data in pairs(maps) do
                if data and data.lines and #data.lines > 0 then
                    local serviceFolder = Instance.new("Folder")
                    serviceFolder.Name = serviceName
                    serviceFolder.Parent = mapsFolder

                    local header = "-- " .. serviceName .. " (" .. data.objs .. " objects, " .. data.scripts .. " scripts)"
                    local combined = {header, ""}
                    for _, line in ipairs(data.lines) do
                        table.insert(combined, line)
                    end
                    local fullText = table.concat(combined, string.char(10))

                    local index = 1
                    while #fullText > 0 do
                        local chunk = fullText:sub(1, MAX_CHUNK)
                        fullText = fullText:sub(#chunk + 1)

                        local sv = Instance.new("StringValue")
                        sv.Name = serviceName .. "_part" .. index
                        sv.Value = chunk
                        sv.Parent = serviceFolder
                        index = index + 1
                    end

                    saved = saved + 1
                end
            end

            if saved > 0 then
                local locName = (parentFolder == root) and "workspace" or ("workspace." .. parentFolder.Name)
                Toast.show("💾 Saved " .. saved .. " maps under " .. locName .. ".ScriptExplorer_Maps", 4, Config.Colors.Success)
            else
                Toast.show("⚠️ Nothing to save", 3, Config.Colors.Error)
            end
        end)
        
        -- Create tabs for each service
        local order = 0
        for _, serviceName in ipairs(Config.Services) do
            local data = maps[serviceName]
            if data and data.lines and #data.lines > 0 then
                order = order + 1
                local tabBtn = UI.button({ 
                    Text = "📂 " .. serviceName:sub(1, 10), 
                    Size = UDim2.new(0, 110, 0, 32), 
                    Color = Config.Colors.Item, 
                    TextSize = 10, 
                    Corner = 6, 
                    Parent = tabs 
                })
                tabBtn.LayoutOrder = order
                tabButtons[serviceName] = tabBtn
                
                tabBtn.MouseButton1Click:Connect(function() 
                    showService(serviceName) 
                end)
                
                -- Show first service by default
                if order == 1 then 
                    showService(serviceName) 
                end
            end
        end
    end)
end

-- ════════════════════════════════════════════════════════════════════════════
-- MAIN INIT
-- ════════════════════════════════════════════════════════════════════════════

local function init()
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local CoreGui = game:GetService("CoreGui")
    local LocalPlayer = Players.LocalPlayer
    
    -- Create ScreenGui
    State.gui = Instance.new("ScreenGui")
    State.gui.Name = "ScriptExplorer"
    State.gui.ResetOnSpawn = false
    State.gui.DisplayOrder = 9999
    State.gui.IgnoreGuiInset = true
    pcall(function() State.gui.Parent = CoreGui end)
    if not State.gui.Parent then 
        State.gui.Parent = LocalPlayer:WaitForChild("PlayerGui") 
    end
    
    Toast.init(State.gui)
    
    -- Show Game Map first
    GameMap.show()
    
    -- Main Frame
    State.mainFrame = UI.frame({ 
        Size = UDim2.fromScale(Config.Window.Width, Config.Window.Height),
        Position = UDim2.fromScale(0.5 - Config.Window.Width/2, 0.5 - Config.Window.Height/2),
        Color = Config.Colors.Background, 
        Corner = 14, 
        Clip = true, 
        Parent = State.gui 
    })
    State.mainFrame.Active = true
    UI.stroke(State.mainFrame, 2, Config.Colors.Accent, 0.3)
    
    -- Header
    local header = UI.frame({ 
        Size = UDim2.new(1, 0, 0, 50), 
        Color = Config.Colors.Panel, 
        Corner = 14, 
        Parent = State.mainFrame 
    })
    UI.label({ 
        Text = "🚀 Script Explorer v" .. Config.Version, 
        Size = UDim2.new(1, -180, 1, 0), 
        Position = UDim2.new(0, 18, 0, 0), 
        Bold = true, 
        TextSize = 18, 
        Parent = header 
    })
    
    -- Map button
    UI.button({ 
        Text = "🗺️", 
        Size = UDim2.new(0, 40, 0, 40), 
        Position = UDim2.new(1, -170, 0, 5), 
        OnClick = GameMap.show, 
        Parent = header 
    })
    
    -- Minimize button
    local isMin = false
    local minBtn = UI.button({ 
        Text = "─", 
        Size = UDim2.new(0, 40, 0, 40), 
        Position = UDim2.new(1, -125, 0, 5), 
        Color = Config.Colors.Folder, 
        Parent = header 
    })
    minBtn.MouseButton1Click:Connect(function()
        isMin = not isMin
        UI.tween(State.mainFrame, {
            Size = isMin and UDim2.new(0, 340, 0, 50) or UDim2.fromScale(Config.Window.Width, Config.Window.Height)
        }, 0.2)
    end)
    
    -- Close button
    UI.button({ 
        Text = "✕", 
        Size = UDim2.new(0, 40, 0, 40), 
        Position = UDim2.new(1, -80, 0, 5), 
        Color = Config.Colors.Error,
        OnClick = function() 
            Highlighter.clear() 
            State.gui:Destroy() 
        end, 
        Parent = header 
    })
    
    -- Toolbar
    local toolbar = UI.frame({ 
        Size = UDim2.new(1, -20, 0, 40), 
        Position = UDim2.new(0, 10, 0, 56), 
        Transparency = 1, 
        Parent = State.mainFrame 
    })
    
    local searchBox = UI.input({ 
        Size = UDim2.new(1, -100, 1, 0), 
        Placeholder = "🔍 Search...", 
        Parent = toolbar 
    })
    
    UI.button({ 
        Text = "🔄", 
        Size = UDim2.new(0, 40, 1, 0), 
        Position = UDim2.new(1, -90, 0, 0), 
        OnClick = function() Explorer.buildTree() end, 
        Parent = toolbar 
    })
    
    UI.button({ 
        Text = "⭐", 
        Size = UDim2.new(0, 40, 1, 0), 
        Position = UDim2.new(1, -45, 0, 0), 
        Color = Config.Colors.Folder, 
        Parent = toolbar 
    })
    
    -- Search debounce
    local debounce = nil
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = searchBox.Text
        if debounce then task.cancel(debounce) end
        debounce = task.delay(Config.Search.Debounce, function() 
            Explorer.buildTree(q) 
        end)
    end)
    
    -- Path bar
    local pathBar = UI.frame({ 
        Size = UDim2.new(1, -20, 0, 26), 
        Position = UDim2.new(0, 10, 0, 102), 
        Color = Config.Colors.Item, 
        Corner = 8, 
        Parent = State.mainFrame 
    })
    State.pathLabel = UI.label({ 
        Text = "📍 Select an item...", 
        Size = UDim2.new(1, -85, 1, 0), 
        Position = UDim2.new(0, 10, 0, 0), 
        Color = Config.Colors.Muted, 
        TextSize = 11, 
        Truncate = Enum.TextTruncate.AtEnd, 
        Parent = pathBar 
    })
    
    UI.button({ 
        Text = "📋", 
        Size = UDim2.new(0, 65, 0, 20), 
        Position = UDim2.new(1, -75, 0, 3), 
        TextSize = 11, 
        Corner = 5,
        OnClick = function() 
            if State.selected then 
                Executor.clipboard(State.selected:GetFullName()) 
                Toast.show("📋 Path copied!", 2) 
            end 
        end, 
        Parent = pathBar 
    })
    
    -- Split container
    local split = UI.frame({ 
        Size = UDim2.new(1, -20, 1, -140), 
        Position = UDim2.new(0, 10, 0, 134), 
        Transparency = 1, 
        Clip = true, 
        Parent = State.mainFrame 
    })
    
    -- Tree panel
    local treePanel = UI.frame({ 
        Size = UDim2.new(Config.Tree.PanelWidth, -5, 1, 0), 
        Color = Config.Colors.Panel, 
        Corner = 10, 
        Clip = true, 
        Parent = split 
    })
    State.treeScroll = UI.scroll({ Parent = treePanel })
    UI.list(State.treeScroll, 1)
    UI.padding(State.treeScroll, 5)
    
    -- Code panel
    local codePanel = UI.frame({ 
        Size = UDim2.new(1 - Config.Tree.PanelWidth, -5, 1, 0), 
        Position = UDim2.new(Config.Tree.PanelWidth, 5, 0, 0), 
        Color = Config.Colors.Panel, 
        Corner = 10, 
        Clip = true, 
        Parent = split 
    })
    
    local codeHeader = UI.frame({ 
        Size = UDim2.new(1, 0, 0, 42), 
        Color = Config.Colors.Item, 
        Parent = codePanel 
    })
    State.titleLabel = UI.label({ 
        Text = "📜 Select a script", 
        Size = UDim2.new(1, -135, 1, 0), 
        Position = UDim2.new(0, 10, 0, 0), 
        Bold = true, 
        TextSize = 13, 
        Truncate = Enum.TextTruncate.AtEnd, 
        Parent = codeHeader 
    })
    
    -- Execute button
    UI.button({ 
        Text = "▶", 
        Size = UDim2.new(0, 36, 0, 32), 
        Position = UDim2.new(1, -125, 0, 5), 
        Color = Config.Colors.Success, 
        TextSize = 14,
        OnClick = function()
            if State.source then
                local fn, err = loadstring(State.source)
                if fn then 
                    pcall(fn) 
                    Toast.show("✅ Executed!", 2, Config.Colors.Success)
                else 
                    Toast.show("❌ " .. tostring(err):sub(1, 50), 3, Config.Colors.Error) 
                end
            end
        end, 
        Parent = codeHeader 
    })
    
    -- Copy button
    UI.button({ 
        Text = "📋", 
        Size = UDim2.new(0, 36, 0, 32), 
        Position = UDim2.new(1, -85, 0, 5),
        OnClick = function() 
            if State.source then 
                Executor.clipboard(State.source) 
                Toast.show("📋 Copied!", 2) 
            end 
        end, 
        Parent = codeHeader 
    })
    
    -- Refresh button
    UI.button({ 
        Text = "🔄", 
        Size = UDim2.new(0, 36, 0, 32), 
        Position = UDim2.new(1, -45, 0, 5),
        OnClick = function() 
            if State.selected and State.selected:IsA("BaseScript") then 
                Explorer.selectItem(State.selected) 
            end 
        end, 
        Parent = codeHeader 
    })
    
    State.metaLabel = UI.label({ 
        Text = "", 
        Size = UDim2.new(1, -10, 0, 18), 
        Position = UDim2.new(0, 5, 0, 44), 
        Color = Config.Colors.Muted, 
        TextSize = 10, 
        Parent = codePanel 
    })
    
    local codeScroll = UI.scroll({ 
        Size = UDim2.new(1, 0, 1, -66), 
        Position = UDim2.new(0, 0, 0, 66), 
        Parent = codePanel 
    })
    
    State.codeLabel = Instance.new("TextBox")
    State.codeLabel.Size = UDim2.new(1, -14, 0, 0)
    State.codeLabel.Position = UDim2.new(0, 7, 0, 7)
    State.codeLabel.BackgroundTransparency = 1
    State.codeLabel.Text = "-- Select a script to view source"
    State.codeLabel.TextColor3 = Config.Colors.Text
    State.codeLabel.Font = Enum.Font.Code
    State.codeLabel.TextSize = 12
    State.codeLabel.TextXAlignment = Enum.TextXAlignment.Left
    State.codeLabel.TextYAlignment = Enum.TextYAlignment.Top
    State.codeLabel.TextWrapped = false
    State.codeLabel.MultiLine = true
    State.codeLabel.ClearTextOnFocus = false
    State.codeLabel.TextEditable = false
    State.codeLabel.AutomaticSize = Enum.AutomaticSize.XY
    State.codeLabel.Parent = codeScroll
    
    -- Dragging
    local dragging, dragStart, startPos = false, nil, nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = State.mainFrame.Position
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
            State.mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X, 
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- Build tree
    Explorer.buildTree()
    
    -- Animate in
    State.mainFrame.Size = UDim2.new(0, 0, 0, 0)
    State.mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    task.wait(0.1)
    UI.tween(State.mainFrame, {
        Size = UDim2.fromScale(Config.Window.Width, Config.Window.Height),
        Position = UDim2.fromScale(0.5 - Config.Window.Width/2, 0.5 - Config.Window.Height/2)
    }, 0.3)
    
    print("✅ Script Explorer v" .. Config.Version .. " loaded!")
end

init()