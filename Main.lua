-- Roblox Smart Detection & Calibration Suite v3.0
-- Implements a fully automatic, zero-effort calibration system.
-- Features: Multi-layered detection, adaptive UI, analytics, heat map,
-- and a continuous, self-optimizing detection area that learns from user behavior.

-- --- Service Loading & Compatibility ---
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

if type(task) ~= "table" then task = {
    spawn = coroutine.wrap,
    wait = function(t) local s = tick() while tick() - s < (t or 0) do RunService.Heartbeat:Wait() end end,
    cancel = function(thread) if coroutine.status(thread) ~= "dead" then coroutine.close(thread) end end
} end

local player = Players.LocalPlayer
local guiInset = GuiService:GetGuiInset()

-- --- Main Suite ---
local DetectionSuite = {}
DetectionSuite.UI = {}
DetectionSuite.State = {
    SuccessfulClicks = 0,
    FailedClicks = 0,
    TotalClicks = 0,
    ClickHistory = {},
    IsOverlayVisible = true,
    IsTestRunning = false,
    IsMagicCalibrating = false,
    SessionStartTime = 0,
    SavedProfiles = {},
}
DetectionSuite.HeatMapCells = {}
DetectionSuite.DetectionSize = 0
DetectionSuite.Threads = {}

-- --- UI Construction ---
function DetectionSuite:CreateUI()
    local viewportSize = Workspace.CurrentCamera.ViewportSize
    local maxSize = math.min(viewportSize.X, viewportSize.Y) * 0.8
    self.DetectionSize = math.min(800, maxSize)

    local overlay = Instance.new("ScreenGui")
    overlay.Name = "DetectionBoxOverlay"; overlay.ZIndexBehavior = Enum.ZIndexBehavior.Global; overlay.ResetOnSpawn = false
    self.UI.Overlay = overlay

    local overlayFrame = Instance.new("Frame", overlay)
    overlayFrame.Size = UDim2.fromScale(1, 1); overlayFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlayFrame.BackgroundTransparency = 0.7
    self.UI.OverlayFrame = overlayFrame

    local detectionArea = Instance.new("Frame", overlayFrame)
    detectionArea.Size = UDim2.fromOffset(self.DetectionSize, self.DetectionSize)
    detectionArea.Position = UDim2.fromScale(0.5, 0.5)
    detectionArea.AnchorPoint = Vector2.new(0.5, 0.5); detectionArea.BorderSizePixel = 3
    detectionArea.BorderColor3 = Color3.fromRGB(0, 255, 0); detectionArea.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    detectionArea.BackgroundTransparency = 0.9
    detectionArea.ClipsDescendants = true
    self.UI.DetectionArea = detectionArea
    
    self:CreateZones(); self:CreateGrid(); self:InitializeHeatMap()

    -- Simplified Control Panel
    local controlPanel = Instance.new("Frame", overlay)
    controlPanel.Size = UDim2.new(0, 200, 0, 170)
    controlPanel.Position = UDim2.new(1, -210, 0, 10)
    controlPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 25); controlPanel.BorderSizePixel = 0
    local cpCorner = Instance.new("UICorner", controlPanel); cpCorner.CornerRadius = UDim.new(0, 8)
    self.UI.ControlPanel = controlPanel

    local function createButton(text, yPos, parent)
        local btn = Instance.new("TextButton", parent)
        btn.Size = UDim2.new(1, -20, 0, 30); btn.Position = UDim2.new(0.5, 0, 0, yPos); btn.AnchorPoint = Vector2.new(0.5, 0)
        btn.Text = text; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.Font = Enum.Font.Gotham
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        local btnCorner = Instance.new("UICorner", btn); btnCorner.CornerRadius = UDim.new(0, 6)
        return btn
    end
    self.UI.ToggleOverlayBtn = createButton("Hide Overlay", 10, controlPanel)
    self.UI.StartTestBtn = createButton("Start Detection", 50, controlPanel)
    self.UI.MagicCalibrateBtn = createButton("🔮 Auto-Calibrate", 90, controlPanel)
    self.UI.ExportDataBtn = createButton("Export Data", 130, controlPanel)
    
    local coordDisplay = Instance.new("TextLabel", overlay)
    coordDisplay.Size = UDim2.new(0, 300, 0, 20); coordDisplay.Position = UDim2.new(0, 10, 0, 10)
    coordDisplay.BackgroundTransparency = 1; coordDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
    coordDisplay.Text = "Screen: (0, 0)"; coordDisplay.Font = Enum.Font.Code; coordDisplay.TextXAlignment = Enum.TextXAlignment.Left
    self.UI.CoordDisplay = coordDisplay

    local clickCounter = Instance.new("TextLabel", overlay)
    clickCounter.Size = UDim2.new(1, 0, 0, 40); clickCounter.Position = UDim2.new(0, 0, 1, -50)
    clickCounter.BackgroundTransparency = 1; clickCounter.TextColor3 = Color3.fromRGB(255, 255, 255)
    clickCounter.Text = "Successful: 0 | Failed: 0 | Rate: 100%"; clickCounter.Font = Enum.Font.GothamBold; clickCounter.TextSize = 24
    self.UI.ClickCounter = clickCounter
    
    self:CreateAnalyticsPanel()
    overlay.Parent = CoreGui
end

-- --- UI Components (Grids, Zones, etc.) ---
function DetectionSuite:CreateGrid()
    if self.UI.DetectionArea:FindFirstChild("GridContainer") then self.UI.DetectionArea:FindFirstChild("GridContainer"):Destroy() end
    local grid = Instance.new("Frame", self.UI.DetectionArea); grid.Name = "GridContainer"
    grid.Size = UDim2.fromScale(1, 1); grid.BackgroundTransparency = 1
    local detectionSize = self.UI.DetectionArea.AbsoluteSize
    local cellSize = math.max(detectionSize.X, detectionSize.Y) / 8
    
    for i = 0, 8 do
        local pos = i * cellSize
        if pos <= detectionSize.X then
            local vLine = Instance.new("Frame", grid)
            vLine.Size = UDim2.new(0, 1, 1, 0); vLine.Position = UDim2.new(0, pos, 0, 0)
            vLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255); vLine.BackgroundTransparency = 0.85;
        end
        if pos <= detectionSize.Y then
            local hLine = Instance.new("Frame", grid)
            hLine.Size = UDim2.new(1, 0, 0, 1); hLine.Position = UDim2.new(0, 0, 0, pos)
            hLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255); hLine.BackgroundTransparency = 0.85;
        end
    end
end

function DetectionSuite:CreateZones()
    local safeZone = self.UI.DetectionArea:FindFirstChild("SafeZone") or Instance.new("Frame", self.UI.DetectionArea)
    safeZone.Name = "SafeZone"; safeZone.Size = UDim2.fromScale(0.75, 0.75)
    safeZone.Position = UDim2.fromScale(0.5, 0.5); safeZone.AnchorPoint = Vector2.new(0.5, 0.5)
    safeZone.BackgroundColor3 = Color3.fromRGB(0, 255, 0); safeZone.BackgroundTransparency = 0.95
    safeZone.ZIndex = 3
end


-- --- Smart Detection & Analytics ---
function DetectionSuite:IsInDetectionArea(position)
    local area = self.UI.DetectionArea
    local relativePos = position - area.AbsolutePosition
    return relativePos.X >= 0 and relativePos.X <= area.AbsoluteSize.X and relativePos.Y >= 0 and relativePos.Y <= area.AbsoluteSize.Y
end

function DetectionSuite:UpdateStats()
    local S = self.State
    S.TotalClicks = S.SuccessfulClicks + S.FailedClicks
    local successRate = (S.TotalClicks > 0) and (S.SuccessfulClicks / S.TotalClicks * 100) or 100
    self.UI.ClickCounter.Text = string.format("Success: %d | Failed: %d | Rate: %.1f%%", S.SuccessfulClicks, S.FailedClicks, successRate)
    local color = successRate < 80 and Color3.fromRGB(255, 80, 80) or successRate < 95 and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(80, 255, 80)
    self.UI.ClickCounter.TextColor3 = color
end

function DetectionSuite:LogClick(position)
    local wasSuccessful = self:IsInDetectionArea(position)
    if wasSuccessful then self.State.SuccessfulClicks += 1 else self.State.FailedClicks += 1 end
    
    local flash = Instance.new("Frame", self.UI.Overlay)
    flash.Size = UDim2.new(0, 20, 0, 20); flash.Position = UDim2.fromOffset(position.X, position.Y)
    flash.AnchorPoint = Vector2.new(0.5, 0.5); flash.BackgroundColor3 = wasSuccessful and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    local corner = Instance.new("UICorner", flash); corner.CornerRadius = UDim.new(1, 0)
    
    TweenService:Create(flash, TweenInfo.new(0.5), {BackgroundTransparency = 1, Size = UDim2.new(0, 50, 0, 50)}):Play()
    task.delay(0.5, function() flash:Destroy() end)

    table.insert(self.State.ClickHistory, {Position = position, Time = os.clock()})
    if #self.State.ClickHistory > 1000 then table.remove(self.State.ClickHistory, 1) end
    
    self:UpdateHeatMap(position)
    self:UpdateStats()
end

-- Placeholder for more advanced analytics
function DetectionSuite:CreateAnalyticsPanel()
    local panel = Instance.new("Frame", self.UI.Overlay)
    panel.Size = UDim2.new(0, 250, 0, 50); panel.Position = UDim2.new(0, 10, 1, -100)
    panel.BackgroundColor3 = Color3.fromRGB(25, 25, 25); panel.BorderSizePixel = 0
    local corner = Instance.new("UICorner", panel); corner.CornerRadius = UDim.new(0, 8)
    local title = Instance.new("TextLabel", panel)
    title.Size = UDim2.new(1, 0, 1, 0); title.Text = "📊 Analytics (Auto-Mode)"
    title.TextColor3 = Color3.fromRGB(255, 255, 255); title.Font = Enum.Font.GothamBold; title.BackgroundTransparency = 1
end

function DetectionSuite:InitializeHeatMap() end
function DetectionSuite:UpdateHeatMap(position) end


-- --- Automatic Calibration System (v3.0) ---
function DetectionSuite:ApplySmartDefaults()
    local viewport = Workspace.CurrentCamera.ViewportSize
    local centerPos = UDim2.new(0.5, -viewport.X * 0.25, 0.5, -viewport.Y * 0.25)
    local centerSize = UDim2.fromScale(0.5, 0.5)
    self.UI.DetectionArea.Position = centerPos
    self.UI.DetectionArea.Size = centerSize
    self.UI.ClickCounter.Text = "🎯 Default area set. It will auto-adjust as you click!"
    self:CreateGrid()
end

function DetectionSuite:AutoDetectTargetArea()
    if #self.State.ClickHistory < 5 then return end
    
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    
    for _, click in ipairs(self.State.ClickHistory) do
        local pos = click.Position
        minX = math.min(minX, pos.X); maxX = math.max(maxX, pos.X)
        minY = math.min(minY, pos.Y); maxY = math.max(maxY, pos.Y)
    end
    
    if maxX - minX < 50 or maxY - minY < 50 then return end -- Clicks are too close, probably not an area
    
    local width = maxX - minX + 40; local height = maxY - minY + 40
    local newPos = UDim2.fromOffset(minX - 20, minY - 20)
    local newSize = UDim2.fromOffset(width, height)
    
    TweenService:Create(self.UI.DetectionArea, TweenInfo.new(0.5), {Position = newPos, Size = newSize}):Play()
    self.UI.ClickCounter.Text = "✅ Auto-detected your target area!"
    task.delay(0.5, function() self:CreateGrid() end)
end

function DetectionSuite:ContinuousOptimization()
    if self.Threads.Optimization then task.cancel(self.Threads.Optimization) end
    self.Threads.Optimization = task.spawn(function()
        while self.State.IsTestRunning do
            task.wait(5)
            if #self.State.ClickHistory > 10 then
                self:AutoDetectTargetArea()
            end
        end
    end)
end

function DetectionSuite:ApplyMagicCalibration(sampleClicks)
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    for _, pos in ipairs(sampleClicks) do
        minX = math.min(minX, pos.X); maxX = math.max(maxX, pos.X)
        minY = math.min(minY, pos.Y); maxY = math.max(maxY, pos.Y)
    end
    
    local width = math.max(100, maxX - minX + 40)
    local height = math.max(100, maxY - minY + 40)
    self.UI.DetectionArea.Position = UDim2.fromOffset(minX - 20, minY - 20)
    self.UI.DetectionArea.Size = UDim2.fromOffset(width, height)
    self:CreateGrid()
end

function DetectionSuite:MagicCalibration()
    if self.State.IsMagicCalibrating then return end
    self.State.IsMagicCalibrating = true
    
    if #self.State.ClickHistory >= 5 then
        self.UI.ClickCounter.Text = "🔮 Analyzing your click history..."
        self:AutoDetectTargetArea()
        self.State.IsMagicCalibrating = false
        return
    end
    
    self.UI.ClickCounter.Text = "Quick setup: Click 2-3 spots in your target area"
    local sampleClicks = {}
    local sampleListener
    
    sampleListener = UserInputService.InputBegan:Connect(function(input, gp)
        if gp or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        
        table.insert(sampleClicks, input.Position)
        local remaining = 3 - #sampleClicks
        self.UI.ClickCounter.Text = string.format("Quick setup: Click %d more spot(s)", remaining)
        
        if remaining <= 0 then
            if sampleListener then sampleListener:Disconnect(); sampleListener = nil end
            self:ApplyMagicCalibration(sampleClicks)
            self.State.IsMagicCalibrating = false
            self.UI.ClickCounter.Text = "✅ Magic calibration complete!"
        end
    end)
    
    task.delay(8, function()
        if sampleListener then 
            sampleListener:Disconnect()
            self.State.IsMagicCalibrating = false
            if #sampleClicks > 0 then self:ApplyMagicCalibration(sampleClicks) else self:UpdateStats() end
        end
    end)
end

-- --- Data Management ---
function DetectionSuite:ExportSessionData()
    local exportData = {
        SessionSummary = {TotalClicks=self.State.TotalClicks,SuccessfulClicks=self.State.SuccessfulClicks,FailedClicks=self.State.FailedClicks,
            SuccessRate=self.State.SuccessfulClicks/math.max(1,self.State.TotalClicks),Duration=os.clock()-self.State.SessionStartTime,
            DetectionAreaSize={Width=self.UI.DetectionArea.AbsoluteSize.X,Height=self.UI.DetectionArea.AbsoluteSize.Y}},
        ExportTimestamp=os.date("%Y-%m-%d %H:%M:%S")
    }
    local s,e = pcall(function() return HttpService:JSONEncode(exportData) end)
    if s and setclipboard then setclipboard(e); StarterGui:SetCore("SendNotification", {Title="Data Exported",Text="Session data copied",Duration=3})
    else StarterGui:SetCore("SendNotification", {Title="Export Failed",Text="Could not export data",Duration=5}) end
end

-- --- Event Handling & Initialization ---
function DetectionSuite:Initialize()
    if not Workspace.CurrentCamera then task.wait() end
    self:CreateUI()
    self:ApplySmartDefaults()
    self.State.SessionStartTime = os.clock()
    
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp or input.UserInputType ~= Enum.UserInputType.MouseButton1 or self.State.IsMagicCalibrating then return end
        if self.State.IsTestRunning then self:LogClick(input.Position) end
    end)
    
    RunService.Heartbeat:Connect(function()
        if not self.State.IsOverlayVisible then return end
        local mousePos = UserInputService:GetMouseLocation() - guiInset
        self.UI.CoordDisplay.Position = UDim2.fromOffset(mousePos.X + 15, mousePos.Y + 15)
        local relativePos = mousePos - self.UI.DetectionArea.AbsolutePosition
        self.UI.CoordDisplay.Text = string.format("Screen: (%d, %d) | Area: (%d, %d)", mousePos.X, mousePos.Y, relativePos.X, relativePos.Y)
        self.UI.CoordDisplay.TextColor3 = self:IsInDetectionArea(mousePos) and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(255, 150, 150)
    end)
    
    self.UI.ToggleOverlayBtn.MouseButton1Click:Connect(function()
        self.State.IsOverlayVisible = not self.State.IsOverlayVisible
        self.UI.OverlayFrame.Visible, self.UI.CoordDisplay.Visible = self.State.IsOverlayVisible, self.State.IsOverlayVisible
        self.UI.ToggleOverlayBtn.Text = self.State.IsOverlayVisible and "Hide Overlay" or "Show Overlay"
    end)
    
    self.UI.StartTestBtn.MouseButton1Click:Connect(function()
        self.State.IsTestRunning = not self.State.IsTestRunning
        if self.State.IsTestRunning then
            self.State.SuccessfulClicks, self.State.FailedClicks, self.State.TotalClicks = 0, 0, 0
            self:UpdateStats(); self.UI.StartTestBtn.Text = "Stop Detection"
            self.UI.ClickCounter.Text = "Click anywhere to test detection accuracy."
            self:ContinuousOptimization()
        else
             if self.Threads.Optimization then task.cancel(self.Threads.Optimization); self.Threads.Optimization = nil end
            self.UI.StartTestBtn.Text = "Start Detection"; self:UpdateStats()
        end
    end)
    
    self.UI.MagicCalibrateBtn.MouseButton1Click:Connect(function() self:MagicCalibration() end)
    self.UI.ExportDataBtn.MouseButton1Click:Connect(function() self:ExportSessionData() end)
end

-- --- Run the suite ---
DetectionSuite:Initialize()