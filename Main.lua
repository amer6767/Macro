-- Roblox Smart Detection & Calibration Suite v2.0
-- Implements Phase 1, 2, and a new User-Friendly Calibration System (Phase 3).
-- Features: Multi-layered detection, adaptive UI, visual feedback, advanced analytics, heat map,
-- and a one-click smart calibration with visual adjustment handles and presets.

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
    LatencyData = {},
    ClickHistory = {},
    IsOverlayVisible = true,
    IsTestRunning = false,
    IsCalibrating = false,
    SnapToGrid = true,
    HeatMapData = {},
    ClickPatterns = { Offsets = {}, Timing = {}, AccuracyTrend = {} },
    SessionStartTime = 0,
    SavedProfiles = {},
}
DetectionSuite.HeatMapCells = {}
DetectionSuite.AdjustmentHandles = {}
DetectionSuite.DetectionSize = 0

-- --- UI Construction (Phase 1, 2 & 3) ---
function DetectionSuite:CreateUI()
    local viewportSize = Workspace.CurrentCamera.ViewportSize
    local maxSize = math.min(viewportSize.X, viewportSize.Y) * 0.8
    local detectionSize = math.min(800, maxSize)
    self.DetectionSize = detectionSize

    local overlay = Instance.new("ScreenGui")
    overlay.Name = "DetectionBoxOverlay"; overlay.ZIndexBehavior = Enum.ZIndexBehavior.Global; overlay.ResetOnSpawn = false
    self.UI.Overlay = overlay

    local overlayFrame = Instance.new("Frame", overlay)
    overlayFrame.Size = UDim2.fromScale(1, 1); overlayFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlayFrame.BackgroundTransparency = 0.7
    self.UI.OverlayFrame = overlayFrame

    local detectionArea = Instance.new("Frame", overlayFrame)
    detectionArea.Size = UDim2.fromOffset(detectionSize, detectionSize)
    detectionArea.Position = UDim2.fromScale(0.5, 0.5)
    detectionArea.AnchorPoint = Vector2.new(0.5, 0.5); detectionArea.BorderSizePixel = 3
    detectionArea.BorderColor3 = Color3.fromRGB(0, 255, 0); detectionArea.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    detectionArea.BackgroundTransparency = 0.9
    detectionArea.ClipsDescendants = true
    self.UI.DetectionArea = detectionArea
    
    self:CreateZones()
    self:CreateGrid()
    self:InitializeHeatMap()

    local controlPanel = Instance.new("Frame", overlay)
    controlPanel.Size = UDim2.new(0, 200, 0, 450); controlPanel.Position = UDim2.new(1, -210, 0, 10)
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
    self.UI.CalibrateBtn = createButton("Smart Calibration", 90, controlPanel)
    self.UI.ToggleGridBtn = createButton("Hide Grid", 130, controlPanel)
    self.UI.SaveProfileBtn = createButton("Save Profile", 170, controlPanel)
    self.UI.ExportDataBtn = createButton("Export Data", 210, controlPanel)

    self.UI.DoneCalibrateBtn = createButton("✓ Done", 90, controlPanel)
    self.UI.DoneCalibrateBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 80); self.UI.DoneCalibrateBtn.Visible = false
    self.UI.CancelCalibrateBtn = createButton("✗ Cancel", 130, controlPanel)
    self.UI.CancelCalibrateBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80); self.UI.CancelCalibrateBtn.Visible = false
    
    local presetFrame = Instance.new("Frame", controlPanel)
    presetFrame.Size = UDim2.new(1, -20, 0, 180); presetFrame.Position = UDim2.new(0.5, 0, 0, 250)
    presetFrame.AnchorPoint = Vector2.new(0.5, 0); presetFrame.BackgroundTransparency = 1
    local presetTitle = Instance.new("TextLabel", presetFrame)
    presetTitle.Size = UDim2.new(1, 0, 0, 20); presetTitle.Text = "Calibration Presets"; presetTitle.Font = Enum.Font.Gotham
    presetTitle.TextSize = 14; presetTitle.TextColor3 = Color3.fromRGB(200, 200, 200); presetTitle.BackgroundTransparency = 1
    self.UI.PresetFrame = presetFrame

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
    self:AddPresetTemplates()
    overlay.Parent = CoreGui
end

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
            vLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255); vLine.BackgroundTransparency = 0.85; vLine.BorderSizePixel = 0
        end
        if pos <= detectionSize.Y then
            local hLine = Instance.new("Frame", grid)
            hLine.Size = UDim2.new(1, 0, 0, 1); hLine.Position = UDim2.new(0, 0, 0, pos)
            hLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255); hLine.BackgroundTransparency = 0.85; hLine.BorderSizePixel = 0
        end
    end
end

function DetectionSuite:CreateZones()
    local safeZone = self.UI.DetectionArea:FindFirstChild("SafeZone") or Instance.new("Frame", self.UI.DetectionArea)
    safeZone.Name = "SafeZone"; safeZone.Size = UDim2.fromScale(0.75, 0.75)
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
    local corner = Instance.new("UICorner", flash); corner.CornerRadius = UDim.new(1, 0)
    
    TweenService:Create(flash, TweenInfo.new(0.5), {BackgroundTransparency = 1, Size = UDim2.new(0, 50, 0, 50)}):Play()
    task.delay(0.5, function() flash:Destroy() end)

    table.insert(self.State.ClickHistory, {Position = position - self.UI.DetectionArea.AbsolutePosition, Time = os.clock()})
    if #self.State.ClickHistory > 1000 then table.remove(self.State.ClickHistory, 1) end
    
    self:UpdateHeatMap(position)
    if #self.State.ClickHistory % 10 == 0 then self:CheckForDrift() end
    
    self:UpdateStats()
end

-- --- Analytics & Visualization (Phase 2) ---
function DetectionSuite:InitializeHeatMap()
    if self.UI.HeatMap then self.UI.HeatMap:Destroy() end
    self.UI.HeatMap = Instance.new("Frame", self.UI.DetectionArea)
    self.UI.HeatMap.Size = UDim2.fromScale(1, 1); self.UI.HeatMap.BackgroundTransparency = 1; self.UI.HeatMap.ZIndex = 5
    
    local detectionSize = self.UI.DetectionArea.AbsoluteSize
    local cellSize = math.max(detectionSize.X, detectionSize.Y) / 8
    
    for x = 1, 8 do
        self.HeatMapCells[x] = {}
        for y = 1, 8 do
            local cell = Instance.new("Frame", self.UI.HeatMap)
            cell.Size = UDim2.fromOffset(cellSize, cellSize)
            cell.Position = UDim2.fromOffset((x-1)*cellSize, (y-1)*cellSize)
            cell.BackgroundColor3 = Color3.fromRGB(0, 0, 0); cell.BackgroundTransparency = 1; cell.BorderSizePixel = 0
            self.HeatMapCells[x][y] = {Frame = cell, Count = 0}
        end
    end
end

function DetectionSuite:UpdateHeatMap(position)
    local relativePos = position - self.UI.DetectionArea.AbsolutePosition
    local detectionSize = self.UI.DetectionArea.AbsoluteSize
    local cellSize = math.max(detectionSize.X, detectionSize.Y) / 8
    local cellX = math.floor(relativePos.X / cellSize) + 1
    local cellY = math.floor(relativePos.Y / cellSize) + 1
    
    if cellX >= 1 and cellX <= 8 and cellY >= 1 and cellY <= 8 then
        local cellData = self.HeatMapCells[cellX][cellY]
        cellData.Count += 1
        local intensity = math.min(cellData.Count / 10, 1)
        cellData.Frame.BackgroundColor3 = Color3.fromHSV(0.6 - (intensity * 0.6), 1, 1)
        cellData.Frame.BackgroundTransparency = 0.9 - (intensity * 0.5)
    end
end

function DetectionSuite:CreateMetricDisplay(label, value, yPos, parent)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, -20, 0, 25); container.Position = UDim2.new(0.5, 0, 0, yPos)
    container.AnchorPoint = Vector2.new(0.5, 0); container.BackgroundTransparency = 1
    local labelTxt = Instance.new("TextLabel", container)
    labelTxt.Size = UDim2.new(0.6, 0, 1, 0); labelTxt.Text = label; labelTxt.Font = Enum.Font.Gotham
    labelTxt.TextColor3 = Color3.fromRGB(200, 200, 200); labelTxt.BackgroundTransparency = 1; labelTxt.TextXAlignment = Enum.TextXAlignment.Left
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
    title.Size = UDim2.new(1, 0, 0, 30); title.Text = "📊 Analytics Dashboard"; title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold; title.BackgroundTransparency = 1
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
    if driftDistance > 15 then self.UI.DriftDisplay.TextColor3 = Color3.fromRGB(255, 100, 100)
    else self.UI.DriftDisplay.TextColor3 = Color3.fromRGB(100, 255, 100) end
end

-- --- User-Friendly Calibration System (Phase 3) ---
function DetectionSuite:StartSmartCalibration()
    if self.State.IsCalibrating then return end
    self.State.IsCalibrating = true; self.State.IsTestRunning = false
    self.UI.StartTestBtn.Text = "Start Detection Test"
    
    self.UI.ClickCounter.Text = "Drag handles to adjust or choose a preset."
    self.UI.CalibrateBtn.Visible, self.UI.ToggleGridBtn.Visible = false, false
    self.UI.SaveProfileBtn.Visible, self.UI.ExportDataBtn.Visible = false, false
    self.UI.StartTestBtn.Visible = false
    self.UI.DoneCalibrateBtn.Visible, self.UI.CancelCalibrateBtn.Visible = true, true
    
    self.OriginalCalibrationState = {Position = self.UI.DetectionArea.Position, Size = self.UI.DetectionArea.Size}
    self:ShowAdjustmentHandles(); self:ShowRealTimePreview()
end

function DetectionSuite:EndCalibration(wasSaved)
    if not self.State.IsCalibrating then return end
    
    if wasSaved then
        self:ShowCalibrationSuccess()
        StarterGui:SetCore("SendNotification", {Title = "Calibration Applied", Text = "Detection area updated.", Duration = 5})
        self:CreateGrid(); self:InitializeHeatMap(); self:CreateZones()
    else
        self.UI.DetectionArea.Position = self.OriginalCalibrationState.Position
        self.UI.DetectionArea.Size = self.OriginalCalibrationState.Size
    end
    
    if self.DetectionPreview then self.DetectionPreview:Destroy(); self.DetectionPreview = nil end
    self:HideAdjustmentHandles()

    self.UI.ClickCounter.Text = "Successful: 0 | Failed: 0 | Rate: 100%"
    self.UI.CalibrateBtn.Visible, self.UI.ToggleGridBtn.Visible = true, true
    self.UI.SaveProfileBtn.Visible, self.UI.ExportDataBtn.Visible = true, true
    self.UI.StartTestBtn.Visible = true
    self.UI.DoneCalibrateBtn.Visible, self.UI.CancelCalibrateBtn.Visible = false, false
    self.State.IsCalibrating = false
end

function DetectionSuite:ShowRealTimePreview()
    if self.DetectionPreview then self.DetectionPreview:Destroy() end
    local preview = Instance.new("Frame", self.UI.DetectionArea.Parent)
    preview.Name = "DetectionPreview"; preview.Size = self.UI.DetectionArea.Size
    preview.Position = self.UI.DetectionArea.Position; preview.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    preview.BackgroundTransparency = 0.8; preview.BorderSizePixel = 2; preview.BorderColor3 = Color3.fromRGB(255, 255, 255)
    preview.ZIndex = 1; self.DetectionPreview = preview
end

function DetectionSuite:SnapToGrid(position)
    if not self.State.SnapToGrid then return position end
    local snap = 10; return Vector2.new(math.floor(position.X/snap + 0.5)*snap, math.floor(position.Y/snap + 0.5)*snap)
end

function DetectionSuite:MakeHandleDraggable(handle, handleType)
    local detectionArea = self.UI.DetectionArea
    local dragging = false; local dragStart, startPos, startSize

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = UserInputService:GetMouseLocation()
            startPos = detectionArea.AbsolutePosition; startSize = detectionArea.AbsoluteSize
            if not self.DetectionPreview then self:ShowRealTimePreview() end
            self.DetectionPreview.Visible = true
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = UserInputService:GetMouseLocation() - dragStart
            local newPos, newSize = startPos, startSize
            
            if string.find(handleType, "Left") then newPos = Vector2.new(startPos.X + delta.X, newPos.Y); newSize = Vector2.new(startSize.X - delta.X, newSize.Y) end
            if string.find(handleType, "Right") then newSize = Vector2.new(startSize.X + delta.X, newSize.Y) end
            if string.find(handleType, "Top") then newPos = Vector2.new(newPos.X, startPos.Y + delta.Y); newSize = Vector2.new(newSize.X, startSize.Y - delta.Y) end
            if string.find(handleType, "Bottom") then newSize = Vector2.new(newSize.X, startSize.Y + delta.Y) end
            
            local snappedEndPos = self:SnapToGrid(newPos + newSize)
            newPos = self:SnapToGrid(newPos); newSize = snappedEndPos - newPos

            detectionArea.Position = UDim2.fromOffset(newPos.X, newPos.Y)
            detectionArea.Size = UDim2.fromOffset(math.max(newSize.X, 20), math.max(newSize.Y, 20))
            self.DetectionPreview.Position, self.DetectionPreview.Size = detectionArea.Position, detectionArea.Size
        end
    end)
    handle.InputEnded:Connect(function(input) if dragging then dragging = false end end)
end

function DetectionSuite:CreateResizeHandle(name, position)
    local handle = Instance.new("Frame", self.UI.DetectionArea)
    handle.Name = name; handle.Size = UDim2.fromOffset(12, 12); handle.Position = position
    handle.BackgroundColor3 = Color3.fromRGB(255, 255, 0); handle.BorderSizePixel = 1; handle.BorderColor3 = Color3.fromRGB(0,0,0)
    handle.ZIndex = 10; handle.AnchorPoint = Vector2.new(0.5, 0.5)
    self:MakeHandleDraggable(handle, name); return handle
end

function DetectionSuite:ShowAdjustmentHandles()
    self:HideAdjustmentHandles()
    local positions = {
        {"TopLeft",UDim2.fromScale(0,0)},{"TopMiddle",UDim2.fromScale(0.5,0)},{"TopRight",UDim2.fromScale(1,0)},
        {"MiddleLeft",UDim2.fromScale(0,0.5)},{"MiddleRight",UDim2.fromScale(1,0.5)},{"BottomLeft",UDim2.fromScale(0,1)},
        {"BottomMiddle",UDim2.fromScale(0.5,1)},{"BottomRight",UDim2.fromScale(1,1)}
    }
    for _, d in ipairs(positions) do table.insert(self.AdjustmentHandles, self:CreateResizeHandle(d[1], d[2])) end
end

function DetectionSuite:HideAdjustmentHandles()
    for _, h in ipairs(self.AdjustmentHandles) do h:Destroy() end; self.AdjustmentHandles = {}
end

function DetectionSuite:CreatePresetButton(text, yPos)
    local btn = Instance.new("TextButton", self.UI.PresetFrame)
    btn.Size = UDim2.new(1, 0, 0, 30); btn.Position = UDim2.new(0, 0, 0, yPos + 20)
    btn.Text = text; btn.TextColor3 = Color3.fromRGB(220, 220, 220); btn.Font = Enum.Font.Gotham
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    local c = Instance.new("UICorner", btn); c.CornerRadius = UDim.new(0, 4); return btn
end

function DetectionSuite:AddPresetTemplates()
    local vp = Workspace.CurrentCamera.ViewportSize
    local presets = {
        {"Center 50%", UDim2.fromScale(0.25, 0.25), UDim2.fromScale(0.5, 0.5)},
        {"Full Screen", UDim2.fromOffset(0, 0), UDim2.fromOffset(vp.X, vp.Y)},
        {"Top Half", UDim2.fromOffset(0, 0), UDim2.fromOffset(vp.X, vp.Y * 0.5)},
        {"Bottom Half", UDim2.fromOffset(0, vp.Y * 0.5), UDim2.fromOffset(vp.X, vp.Y * 0.5)},
    }
    for i, p in ipairs(presets) do
        local btn = self:CreatePresetButton(p[1], (i-1)*35)
        btn.MouseButton1Click:Connect(function() if self.State.IsCalibrating then self:ApplyPreset(p[2], p[3]) end end)
    end
end

function DetectionSuite:ApplyPreset(position, size)
    local area = self.UI.DetectionArea
    if size.X.Scale > 0 or size.Y.Scale > 0 then
        area.Position = position; area.Size = size
    else
        area.Position = UDim2.fromOffset(position.X.Offset, position.Y.Offset)
        area.Size = UDim2.fromOffset(size.X.Offset, size.Y.Offset)
    end
    if self.DetectionPreview then self.DetectionPreview.Position, self.DetectionPreview.Size = area.Position, area.Size end
end

function DetectionSuite:ShowCalibrationSuccess()
    for i = 1, 10 do
        task.spawn(function()
            local p = Instance.new("Frame", self.UI.DetectionArea)
            p.Size=UDim2.fromOffset(10,10); p.Position=UDim2.fromScale(math.random(),math.random())
            p.BackgroundColor3=Color3.fromHSV(math.random(),1,1); p.AnchorPoint=Vector2.new(0.5,0.5)
            local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(1,0)
            TweenService:Create(p,TweenInfo.new(0.7),{Size=UDim2.fromOffset(2,2),BackgroundTransparency=1}):Play()
            task.delay(0.7, function() p:Destroy() end)
        end); task.wait(0.05)
    end
end

-- --- Data Management ---
function DetectionSuite:SaveCalibrationProfile()
    local profile = {
        Name = os.date("%Y-%m-%d %H:%M"),
        Position = {XS=self.UI.DetectionArea.Position.X.Scale, XO=self.UI.DetectionArea.Position.X.Offset, YS=self.UI.DetectionArea.Position.Y.Scale, YO=self.UI.DetectionArea.Position.Y.Offset},
        Size = {XS=self.UI.DetectionArea.Size.X.Scale, XO=self.UI.DetectionArea.Size.X.Offset, YS=self.UI.DetectionArea.Size.Y.Scale, YO=self.UI.DetectionArea.Size.Y.Offset},
        SuccessRate = self.State.SuccessfulClicks / math.max(1, self.State.TotalClicks), Timestamp = os.time(),
    }
    table.insert(self.State.SavedProfiles, profile)
    StarterGui:SetCore("SendNotification", {Title="Profile Saved",Text="Current calibration profile saved.",Duration=5})
end

function DetectionSuite:ExportSessionData()
    local heatMapData = {}; for x=1,8 do heatMapData[x]={}; for y=1,8 do heatMapData[x][y]=self.HeatMapCells[x][y].Count end end
    local exportData = {
        SessionSummary = {TotalClicks=self.State.TotalClicks,SuccessfulClicks=self.State.SuccessfulClicks,FailedClicks=self.State.FailedClicks,
            SuccessRate=self.State.SuccessfulClicks/math.max(1,self.State.TotalClicks),Duration=os.clock()-self.State.SessionStartTime,
            DetectionAreaSize={Width=self.UI.DetectionArea.AbsoluteSize.X,Height=self.UI.DetectionArea.AbsoluteSize.Y}},
        HeatMap=heatMapData, CalibrationProfiles=self.State.SavedProfiles, ExportTimestamp=os.date("%Y-%m-%d %H:%M:%S")
    }
    local s,e = pcall(function() return HttpService:JSONEncode(exportData) end)
    if s and setclipboard then setclipboard(e); StarterGui:SetCore("SendNotification", {Title="Data Exported",Text="Session data copied to clipboard",Duration=3})
    else StarterGui:SetCore("SendNotification", {Title="Export Failed",Text="Could not export data",Duration=5}) end
end

-- --- Event Handling & Initialization ---
function DetectionSuite:Initialize()
    if not Workspace.CurrentCamera then task.wait() end
    self:CreateUI()
    self.State.SessionStartTime = os.clock()
    
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp or input.UserInputType ~= Enum.UserInputType.MouseButton1 or self.State.IsCalibrating then return end
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
            self:UpdateStats(); self.UI.StartTestBtn.Text = "Stop Test"
            self.UI.ClickCounter.Text = "Click anywhere to test detection accuracy."
        else self.UI.StartTestBtn.Text = "Start Detection Test"; self:UpdateStats() end
    end)
    
    self.UI.ToggleGridBtn.MouseButton1Click:Connect(function()
        local grid = self.UI.DetectionArea:FindFirstChild("GridContainer")
        if grid then grid.Visible = not grid.Visible; self.UI.ToggleGridBtn.Text = grid.Visible and "Hide Grid" or "Show Grid" end
    end)

    self.UI.CalibrateBtn.MouseButton1Click:Connect(function() self:StartSmartCalibration() end)
    self.UI.DoneCalibrateBtn.MouseButton1Click:Connect(function() self:EndCalibration(true) end)
    self.UI.CancelCalibrateBtn.MouseButton1Click:Connect(function() self:EndCalibration(false) end)
    self.UI.SaveProfileBtn.MouseButton1Click:Connect(function() self:SaveCalibrationProfile() end)
    self.UI.ExportDataBtn.MouseButton1Click:Connect(function() self:ExportSessionData() end)
end

-- --- Run the suite ---
DetectionSuite:Initialize()
