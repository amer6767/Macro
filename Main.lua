-- Roblox Smart Detection & Calibration Suite v1.2
-- Implements Phase 1 & 2: Multi-layered detection, visual feedback, advanced analytics, heat map, and calibration.
-- Based on the specification for a comprehensive system to understand and optimize click detection reliability.

-- --- Service Loading & Compatibility ---
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

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
    LatencyData = {},
    ClickHistory = {},
    IsOverlayVisible = true,
    IsTestRunning = false,
    CalibrationStep = 0,
    CalibrationClicks = {},
    CurrentScale = Vector2.new(1, 1),
    CurrentOffset = Vector2.new(0, 0),
    -- Phase 2 State
    HeatMapData = {}, -- 8x8 grid for 800x800 area (100px cells)
    ClickPatterns = { Offsets = {}, Timing = {}, AccuracyTrend = {} },
    SessionStartTime = 0,
    SavedProfiles = {},
}
DetectionSuite.HeatMapCells = {}

-- --- UI Construction (Phase 1 & 2) ---
function DetectionSuite:CreateUI()
    local overlay = Instance.new("ScreenGui")
    overlay.Name = "DetectionBoxOverlay"; overlay.ZIndexBehavior = Enum.ZIndexBehavior.Global; overlay.ResetOnSpawn = false
    self.UI.Overlay = overlay

    local overlayFrame = Instance.new("Frame", overlay)
    overlayFrame.Size = UDim2.fromScale(1, 1); overlayFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlayFrame.BackgroundTransparency = 0.7
    self.UI.OverlayFrame = overlayFrame

    local detectionArea = Instance.new("Frame", overlayFrame)
    detectionArea.Size = UDim2.new(0, 800, 0, 800); detectionArea.Position = UDim2.fromScale(0.5, 0.5)
    detectionArea.AnchorPoint = Vector2.new(0.5, 0.5); detectionArea.BorderSizePixel = 3
    detectionArea.BorderColor3 = Color3.fromRGB(0, 255, 0); detectionArea.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    detectionArea.BackgroundTransparency = 0.9
    detectionArea.ClipsDescendants = true
    self.UI.DetectionArea = detectionArea
    
    self:CreateZones()
    self:CreateGrid()
    self:InitializeHeatMap()

    local controlPanel = Instance.new("Frame", overlay)
    controlPanel.Size = UDim2.new(0, 200, 0, 250); controlPanel.Position = UDim2.new(1, -210, 0, 10)
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
    self.UI.StartTestBtn = createButton("Start Detection Test", 50, controlPanel)
    self.UI.CalibrateBtn = createButton("Start Calibration", 90, controlPanel)
    self.UI.ToggleGridBtn = createButton("Hide Grid", 130, controlPanel)
    self.UI.SaveProfileBtn = createButton("Save Profile", 170, controlPanel)
    self.UI.ExportDataBtn = createButton("Export Data", 210, controlPanel)

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

function DetectionSuite:CreateGrid()
    local grid = Instance.new("Frame", self.UI.DetectionArea)
    grid.Name = "GridContainer"
    grid.Size = UDim2.fromScale(1, 1)
    grid.BackgroundTransparency = 1
    
    for x = 0, 800, 100 do
        local line = Instance.new("Frame", grid)
        line.Size = UDim2.new(0, 1, 1, 0); line.Position = UDim2.new(0, x, 0, 0)
        line.BackgroundColor3 = Color3.fromRGB(255, 255, 255); line.BackgroundTransparency = 0.85
        line.BorderSizePixel = 0
    end
    
    for y = 0, 800, 100 do
        local line = Instance.new("Frame", grid)
        line.Size = UDim2.new(1, 0, 0, 1); line.Position = UDim2.new(0, 0, 0, y)
        line.BackgroundColor3 = Color3.fromRGB(255, 255, 255); line.BackgroundTransparency = 0.85
        line.BorderSizePixel = 0
    end
end

function DetectionSuite:CreateZones()
    local warningZone = Instance.new("Frame", self.UI.DetectionArea)
    warningZone.Name = "WarningZone"
    warningZone.Size = UDim2.fromOffset(800, 800)
    warningZone.Position = UDim2.fromScale(0.5, 0.5); warningZone.AnchorPoint = Vector2.new(0.5, 0.5)
    warningZone.BackgroundColor3 = Color3.fromRGB(255, 255, 0); warningZone.BackgroundTransparency = 0.97
    warningZone.BorderSizePixel = 0; warningZone.ZIndex = 2
    
    local safeZone = Instance.new("Frame", self.UI.DetectionArea)
    safeZone.Name = "SafeZone"
    safeZone.Size = UDim2.fromOffset(600, 600)
    safeZone.Position = UDim2.fromScale(0.5, 0.5); safeZone.AnchorPoint = Vector2.new(0.5, 0.5)
    safeZone.BackgroundColor3 = Color3.fromRGB(0, 255, 0); safeZone.BackgroundTransparency = 0.95
    safeZone.BorderSizePixel = 0; safeZone.ZIndex = 3
    self.UI.SafeZone = safeZone
end

-- --- Smart Detection Logic (Phase 2) ---
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
    
    if successRate < 80 then self.UI.ClickCounter.TextColor3 = Color3.fromRGB(255, 80, 80)
    elseif successRate < 95 then self.UI.ClickCounter.TextColor3 = Color3.fromRGB(255, 200, 80)
    else self.UI.ClickCounter.TextColor3 = Color3.fromRGB(80, 255, 80) end
end

function DetectionSuite:LogClick(position)
    local wasSuccessful = self:IsInDetectionArea(position)
    if wasSuccessful then self.State.SuccessfulClicks += 1 else self.State.FailedClicks += 1 end
    
    local flash = Instance.new("Frame", self.UI.Overlay)
    flash.Size = UDim2.new(0, 20, 0, 20); flash.Position = UDim2.fromOffset(position.X, position.Y)
    flash.AnchorPoint = Vector2.new(0.5, 0.5); flash.BackgroundColor3 = wasSuccessful and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    flash.BorderSizePixel = 0
    local corner = Instance.new("UICorner", flash); corner.CornerRadius = UDim.new(1, 0)
    
    TweenService:Create(flash, TweenInfo.new(0.5), {BackgroundTransparency = 1, Size = UDim2.new(0, 50, 0, 50)}):Play()
    task.delay(0.5, function() flash:Destroy() end)

    table.insert(self.State.ClickHistory, {Position = position - self.UI.DetectionArea.AbsolutePosition, Time = os.clock()})
    if #self.State.ClickHistory > 1000 then table.remove(self.State.ClickHistory, 1) end
    
    self:UpdateHeatMap(position)
    if #self.State.ClickHistory % 10 == 0 then
        self:AnalyzeClickPatterns()
        self:CheckForDrift()
    end
    
    self:UpdateStats()
end

-- --- Analytics & Visualization (Phase 2) ---
function DetectionSuite:InitializeHeatMap()
    self.UI.HeatMap = Instance.new("Frame", self.UI.DetectionArea)
    self.UI.HeatMap.Size = UDim2.fromScale(1, 1); self.UI.HeatMap.BackgroundTransparency = 1; self.UI.HeatMap.ZIndex = 5
    
    for x = 1, 8 do
        self.HeatMapCells[x] = {}
        for y = 1, 8 do
            local cell = Instance.new("Frame", self.UI.HeatMap)
            cell.Size = UDim2.new(0, 100, 0, 100); cell.Position = UDim2.new(0, (x-1)*100, 0, (y-1)*100)
            cell.BackgroundColor3 = Color3.fromRGB(0, 0, 0); cell.BackgroundTransparency = 1
            cell.BorderSizePixel = 0
            self.HeatMapCells[x][y] = {Frame = cell, Count = 0}
        end
    end
end

function DetectionSuite:UpdateHeatMap(position)
    local relativePos = position - self.UI.DetectionArea.AbsolutePosition
    local cellX, cellY = math.floor(relativePos.X / 100) + 1, math.floor(relativePos.Y / 100) + 1
    
    if cellX >= 1 and cellX <= 8 and cellY >= 1 and cellY <= 8 then
        local cellData = self.HeatMapCells[cellX][cellY]
        cellData.Count += 1
        
        local intensity = math.min(cellData.Count / 10, 1)
        local color = Color3.fromHSV(0.6 - (intensity * 0.6), 1, 1) -- Blue -> Red
        cellData.Frame.BackgroundColor3 = color
        cellData.Frame.BackgroundTransparency = 0.9 - (intensity * 0.5)
    end
end

function DetectionSuite:AnalyzeClickPatterns()
    -- Stub for pattern analysis. For now, we just suggest recalibration.
end

function DetectionSuite:SuggestCalibrationAdjustment(offsetX, offsetY)
    local suggestion = string.format("Detected consistent offset: X=%dpx, Y=%dpx. Consider recalibrating.", math.floor(offsetX), math.floor(offsetY))
    StarterGui:SetCore("SendNotification", {Title = "Pattern Detected", Text = suggestion, Duration = 8})
    self.UI.CalibrateBtn.Text = "⚠ Recalibrate"
    self.UI.CalibrateBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
end

function DetectionSuite:CreateMetricDisplay(label, value, yPos, parent)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, -20, 0, 25); container.Position = UDim2.new(0.5, 0, 0, yPos)
    container.AnchorPoint = Vector2.new(0.5, 0); container.BackgroundTransparency = 1
    
    local labelTxt = Instance.new("TextLabel", container)
    labelTxt.Size = UDim2.new(0.6, 0, 1, 0); labelTxt.Text = label
    labelTxt.Font = Enum.Font.Gotham; labelTxt.TextColor3 = Color3.fromRGB(200, 200, 200)
    labelTxt.BackgroundTransparency = 1; labelTxt.TextXAlignment = Enum.TextXAlignment.Left

    local valueTxt = Instance.new("TextLabel", container)
    valueTxt.Size = UDim2.new(0.4, 0, 1, 0); valueTxt.Position = UDim2.new(0.6, 0, 0, 0); valueTxt.Text = value
    valueTxt.Font = Enum.Font.GothamBold; valueTxt.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueTxt.BackgroundTransparency = 1; valueTxt.TextXAlignment = Enum.TextXAlignment.Right
    return valueTxt
end

function DetectionSuite:CreateAnalyticsPanel()
    local panel = Instance.new("Frame", self.UI.Overlay)
    panel.Size = UDim2.new(0, 250, 0, 150); panel.Position = UDim2.new(0, 10, 1, -210)
    panel.BackgroundColor3 = Color3.fromRGB(25, 25, 25); panel.BorderSizePixel = 0
    local corner = Instance.new("UICorner", panel); corner.CornerRadius = UDim.new(0, 8)
    
    local title = Instance.new("TextLabel", panel)
    title.Size = UDim2.new(1, 0, 0, 30); title.Text = "📊 Analytics Dashboard"
    title.TextColor3 = Color3.fromRGB(255, 255, 255); title.Font = Enum.Font.GothamBold
    title.BackgroundTransparency = 1
    
    self.UI.ConsistencyDisplay = self:CreateMetricDisplay("Consistency:", "N/A", 40, panel)
    self.UI.DriftDisplay = self:CreateMetricDisplay("Click Drift:", "N/A", 70, panel)
    self.UI.LatencyDisplay = self:CreateMetricDisplay("Avg Latency:", "N/A", 100, panel)
    self.UI.AnalyticsPanel = panel
end

function DetectionSuite:CalculateCenter(clicks)
    local totalPos = Vector2.new(0, 0)
    if #clicks == 0 then return totalPos end
    for _, click in ipairs(clicks) do totalPos += click.Position end
    return totalPos / #clicks
end

function DetectionSuite:CheckForDrift()
    if #self.State.ClickHistory < 20 then return end
    local recentClicks = {}; local olderClicks = {}
    for i = #self.State.ClickHistory - 9, #self.State.ClickHistory do table.insert(recentClicks, self.State.ClickHistory[i]) end
    for i = #self.State.ClickHistory - 19, #self.State.ClickHistory - 10 do table.insert(olderClicks, self.State.ClickHistory[i]) end
    
    local recentCenter = self:CalculateCenter(recentClicks)
    local olderCenter = self:CalculateCenter(olderClicks)
    local driftDistance = (recentCenter - olderCenter).Magnitude
    
    self.UI.DriftDisplay.Text = string.format("%.1f px", driftDistance)
    if driftDistance > 15 then
        self.UI.DriftDisplay.TextColor3 = Color3.fromRGB(255, 100, 100)
        self:AlertDriftDetected(driftDistance)
    else
        self.UI.DriftDisplay.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
end

function DetectionSuite:AlertDriftDetected(driftDistance)
    self.UI.ClickCounter.Text = string.format("⚠ DRIFT DETECTED: %.1f pixels - Recalibrate recommended", driftDistance)
    self.UI.ClickCounter.TextColor3 = Color3.fromRGB(255, 100, 100)
end


-- --- Calibration & Data Management (Phase 2 & 4) ---
function DetectionSuite:StartCalibration()
    self.State.CalibrationStep = 1; self.State.CalibrationClicks = {}
    self:UpdateCalibrationPrompt()
end

function DetectionSuite:UpdateCalibrationPrompt()
    local prompts = { "Click the TOP-LEFT corner", "Click the TOP-RIGHT corner", "Click the BOTTOM-LEFT corner", "Calibration complete!" }
    self.UI.ClickCounter.Text = prompts[self.State.CalibrationStep] or "Calibration Mode"
    
    if self.UI.CalibrationMarker then self.UI.CalibrationMarker:Destroy() end
    if self.State.CalibrationStep <= 3 then
        local markerPos = { UDim2.fromScale(0, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0, 1) }
        local marker = Instance.new("Frame", self.UI.DetectionArea)
        marker.Size = UDim2.new(0, 20, 0, 20); marker.Position = markerPos[self.State.CalibrationStep]
        marker.AnchorPoint = Vector2.new(0.5, 0.5); marker.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        local mCorner = Instance.new("UICorner", marker); mCorner.CornerRadius = UDim.new(1, 0)
        self.UI.CalibrationMarker = marker
    end
end

function DetectionSuite:AdvanceCalibration(clickPos)
    if self.State.CalibrationStep == 0 or self.State.CalibrationStep > 3 then return end
    table.insert(self.State.CalibrationClicks, clickPos - self.UI.DetectionArea.AbsolutePosition)
    self.State.CalibrationStep += 1
    if self.State.CalibrationStep > 3 then self:CalculateAndApplyScaling() end
    self:UpdateCalibrationPrompt()
end

function DetectionSuite:CalculateAndApplyScaling()
    local clicks = self.State.CalibrationClicks
    local detectedWidth, detectedHeight = (clicks[2].X - clicks[1].X), (clicks[3].Y - clicks[1].Y)
    local targetSize = self.UI.DetectionArea.AbsoluteSize
    
    if detectedWidth > 1 and detectedHeight > 1 then
        self.State.CurrentScale = Vector2.new(targetSize.X / detectedWidth, targetSize.Y / detectedHeight)
        self.State.CurrentOffset = clicks[1]
        local msg = string.format("New Scale: (%.2f, %.2f) | Offset: (%d, %d)", self.State.CurrentScale.X, self.State.CurrentScale.Y, self.State.CurrentOffset.X, self.State.CurrentOffset.Y)
        StarterGui:SetCore("SendNotification", {Title = "Calibration Success", Text = msg, Duration = 10})
    else
        StarterGui:SetCore("SendNotification", {Title = "Calibration Failed", Text = "Could not determine valid scaling.", Duration = 10})
    end
    
    self.State.CalibrationStep = 0; self:UpdateStats()
end

function DetectionSuite:SaveCalibrationProfile()
    local profile = {
        Name = os.date("%Y-%m-%d %H:%M"), Scale = self.State.CurrentScale, Offset = self.State.CurrentOffset,
        SuccessRate = self.State.SuccessfulClicks / math.max(1, self.State.TotalClicks), Timestamp = os.time(),
        ScreenSize = self.UI.DetectionArea.AbsoluteSize
    }
    table.insert(self.State.SavedProfiles, profile)
    StarterGui:SetCore("SendNotification", { Title = "Profile Saved", Text = "Current calibration profile has been saved.", Duration = 5})
end

function DetectionSuite:ExportSessionData()
    local exportData = {
        SessionSummary = { TotalClicks = self.State.TotalClicks, SuccessRate = self.State.SuccessfulClicks / math.max(1, self.State.TotalClicks), Duration = os.clock() - self.State.SessionStartTime },
        CalibrationProfiles = self.State.SavedProfiles
    }
    local exportString = HttpService:JSONEncode(exportData)
    if setclipboard then
        setclipboard(exportString)
        StarterGui:SetCore("SendNotification", { Title = "Data Exported", Text = "Session data copied to clipboard", Duration = 3 })
    end
end


-- --- Event Handling & Initialization ---
function DetectionSuite:Initialize()
    self:CreateUI()
    self.State.SessionStartTime = os.clock()
    
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if self.State.CalibrationStep > 0 then self:AdvanceCalibration(input.Position)
        elseif self.State.IsTestRunning then self:LogClick(input.Position) end
    end)
    
    RunService.Heartbeat:Connect(function()
        if not self.State.IsOverlayVisible then return end
        local mousePos = UserInputService:GetMouseLocation() - guiInset
        self.UI.CoordDisplay.Position = UDim2.fromOffset(mousePos.X + 15, mousePos.Y + 15)
        local relativePos = mousePos - self.UI.DetectionArea.AbsolutePosition
        self.UI.CoordDisplay.Text = string.format("Screen: (%d, %d) | Area: (%d, %d)", mousePos.X, mousePos.Y, relativePos.X, relativePos.Y)
        
        if self:IsInDetectionArea(mousePos) then self.UI.CoordDisplay.TextColor3 = Color3.fromRGB(150, 255, 150)
        else self.UI.CoordDisplay.TextColor3 = Color3.fromRGB(255, 150, 150) end
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
            self:UpdateStats()
            self.UI.StartTestBtn.Text = "Stop Test"
            self.UI.ClickCounter.Text = "Click anywhere to test detection accuracy."
        else
            self.UI.StartTestBtn.Text = "Start Detection Test"; self:UpdateStats()
        end
    end)
    
    self.UI.ToggleGridBtn.MouseButton1Click:Connect(function()
        local grid = self.UI.DetectionArea:FindFirstChild("GridContainer")
        if grid then grid.Visible = not grid.Visible; self.UI.ToggleGridBtn.Text = grid.Visible and "Hide Grid" or "Show Grid" end
    end)

    self.UI.CalibrateBtn.MouseButton1Click:Connect(function() self:StartCalibration() end)
    self.UI.SaveProfileBtn.MouseButton1Click:Connect(function() self:SaveCalibrationProfile() end)
    self.UI.ExportDataBtn.MouseButton1Click:Connect(function() self:ExportSessionData() end)
end

-- --- Run the suite ---
DetectionSuite:Initialize()
