-- Roblox Smart Detection & Calibration Suite v1.1
-- Implements a multi-layered detection system with visual feedback, analytics, and a guided calibration assistant.
-- Based on the specification for a comprehensive system to understand and optimize click detection reliability.

-- --- Service Loading & Compatibility ---
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
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
    CalibrationStep = 0,
    CalibrationClicks = {},
    CurrentScale = Vector2.new(1, 1),
    CurrentOffset = Vector2.new(0, 0)
}

-- --- UI Construction (Phase 1) ---
function DetectionSuite:CreateUI()
    -- 1.1: Create DetectionBox GUI
    local overlay = Instance.new("ScreenGui")
    overlay.Name = "DetectionBoxOverlay"; overlay.ZIndexBehavior = Enum.ZIndexBehavior.Global; overlay.ResetOnSpawn = false
    self.UI.Overlay = overlay

    local overlayFrame = Instance.new("Frame", overlay)
    overlayFrame.Size = UDim2.fromScale(1, 1); overlayFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlayFrame.BackgroundTransparency = 0.7
    self.UI.OverlayFrame = overlayFrame

    -- 1.2: Design Detection Area
    local detectionArea = Instance.new("Frame", overlayFrame)
    detectionArea.Size = UDim2.new(0, 1920, 0, 1080); detectionArea.Position = UDim2.fromScale(0.5, 0.5)
    detectionArea.AnchorPoint = Vector2.new(0.5, 0.5); detectionArea.BorderSizePixel = 3
    detectionArea.BorderColor3 = Color3.fromRGB(0, 255, 0); detectionArea.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    detectionArea.BackgroundTransparency = 0.9
    detectionArea.ClipsDescendants = true
    self.UI.DetectionArea = detectionArea
    
    -- Enhancements from feedback
    self:CreateZones()
    self:CreateGrid()

    -- 1.3: Add Control Panel
    local controlPanel = Instance.new("Frame", overlay)
    controlPanel.Size = UDim2.new(0, 200, 0, 150); controlPanel.Position = UDim2.new(1, -210, 0, 10)
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

    -- 2.1: Coordinate Display
    local coordDisplay = Instance.new("TextLabel", overlay)
    coordDisplay.Size = UDim2.new(0, 300, 0, 20); coordDisplay.Position = UDim2.new(0, 10, 0, 10)
    coordDisplay.BackgroundTransparency = 1; coordDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
    coordDisplay.Text = "Screen: (0, 0)"; coordDisplay.Font = Enum.Font.Code; coordDisplay.TextXAlignment = Enum.TextXAlignment.Left
    self.UI.CoordDisplay = coordDisplay

    -- 2.4: Click Counter
    local clickCounter = Instance.new("TextLabel", overlay)
    clickCounter.Size = UDim2.new(1, 0, 0, 40); clickCounter.Position = UDim2.new(0, 0, 1, -50)
    clickCounter.BackgroundTransparency = 1; clickCounter.TextColor3 = Color3.fromRGB(255, 255, 255)
    clickCounter.Text = "Successful: 0 | Failed: 0 | Rate: 100%"; clickCounter.Font = Enum.Font.GothamBold; clickCounter.TextSize = 24
    self.UI.ClickCounter = clickCounter

    overlay.Parent = CoreGui
end

function DetectionSuite:CreateGrid()
    local grid = Instance.new("Frame", self.UI.DetectionArea)
    grid.Name = "GridContainer"
    grid.Size = UDim2.fromScale(1, 1)
    grid.BackgroundTransparency = 1
    
    for x = 0, 1920, 100 do
        local line = Instance.new("Frame", grid)
        line.Size = UDim2.new(0, 1, 1, 0)
        line.Position = UDim2.new(0, x, 0, 0)
        line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        line.BackgroundTransparency = 0.85
        line.BorderSizePixel = 0
    end
    
    for y = 0, 1080, 100 do
        local line = Instance.new("Frame", grid)
        line.Size = UDim2.new(1, 0, 0, 1)
        line.Position = UDim2.new(0, 0, 0, y)
        line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        line.BackgroundTransparency = 0.85
        line.BorderSizePixel = 0
    end
end

function DetectionSuite:CreateZones()
    local safeZone = Instance.new("Frame", self.UI.DetectionArea)
    safeZone.Name = "SafeZone"
    safeZone.Size = UDim2.fromOffset(1600, 880)
    safeZone.Position = UDim2.fromScale(0.5, 0.5)
    safeZone.AnchorPoint = Vector2.new(0.5, 0.5)
    safeZone.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    safeZone.BackgroundTransparency = 0.95
    safeZone.BorderSizePixel = 0
    self.UI.SafeZone = safeZone
end

-- --- Smart Detection Logic (Phase 2) ---
function DetectionSuite:IsInDetectionArea(position)
    local area = self.UI.DetectionArea
    local relativePos = position - area.AbsolutePosition
    return relativePos.X >= 0 and relativePos.X <= area.AbsoluteSize.X and relativePos.Y >= 0 and relativePos.Y <= area.AbsoluteSize.Y
end

function DetectionSuite:CalculateAverageLatency()
    local S = self.State
    if #S.LatencyData == 0 then return 0 end
    local totalLatency = 0
    for _, latency in ipairs(S.LatencyData) do
        totalLatency = totalLatency + latency
    end
    return (totalLatency / #S.LatencyData) * 1000 -- Convert to ms
end

function DetectionSuite:UpdateStats()
    local S = self.State
    S.TotalClicks = S.SuccessfulClicks + S.FailedClicks
    local successRate = (S.TotalClicks > 0) and (S.SuccessfulClicks / S.TotalClicks * 100) or 100
    
    local avgLatency = #S.LatencyData > 0 and self:CalculateAverageLatency() or 0
    self.UI.ClickCounter.Text = string.format(
        "Success: %d | Failed: %d | Rate: %.1f%% | Latency: %.1fms", 
        S.SuccessfulClicks, S.FailedClicks, successRate, avgLatency
    )
    
    if successRate < 80 then 
        self.UI.ClickCounter.TextColor3 = Color3.fromRGB(255, 80, 80)
    elseif successRate < 95 then 
        self.UI.ClickCounter.TextColor3 = Color3.fromRGB(255, 200, 80)
    else 
        self.UI.ClickCounter.TextColor3 = Color3.fromRGB(80, 255, 80) 
    end
end

function DetectionSuite:LogClick(position)
    local wasSuccessful = self:IsInDetectionArea(position)
    if wasSuccessful then self.State.SuccessfulClicks += 1
    else self.State.FailedClicks += 1 end
    
    local flash = Instance.new("Frame", self.UI.Overlay)
    flash.Size = UDim2.new(0, 20, 0, 20); flash.Position = UDim2.fromOffset(position.X, position.Y)
    flash.AnchorPoint = Vector2.new(0.5, 0.5); flash.BackgroundColor3 = wasSuccessful and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    flash.BorderSizePixel = 0
    local corner = Instance.new("UICorner", flash); corner.CornerRadius = UDim.new(1, 0)
    
    game:GetService("TweenService"):Create(flash, TweenInfo.new(0.5), {BackgroundTransparency = 1, Size = UDim2.new(0, 50, 0, 50)}):Play()
    task.delay(0.5, function() flash:Destroy() end)
    
    self:UpdateStats()
end

-- --- Calibration Assistant (Phase 2 & 4) ---
function DetectionSuite:StartCalibration()
    self.State.CalibrationStep = 1
    self.State.CalibrationClicks = {}
    self:UpdateCalibrationPrompt()
end

function DetectionSuite:UpdateCalibrationPrompt()
    local step = self.State.CalibrationStep
    local prompts = { "Click the TOP-LEFT corner of the green box.", "Click the TOP-RIGHT corner.", "Click the BOTTOM-LEFT corner.", "Calibration complete!" }
    self.UI.ClickCounter.Text = prompts[step]
    
    local markerPos = {
        UDim2.fromScale(0, 0),
        UDim2.fromScale(1, 0),
        UDim2.fromScale(0, 1)
    }
    
    if self.UI.CalibrationMarker then self.UI.CalibrationMarker:Destroy() end
    if step <= 3 then
        local marker = Instance.new("Frame", self.UI.DetectionArea)
        marker.Size = UDim2.new(0, 20, 0, 20); marker.Position = markerPos[step]; marker.AnchorPoint = Vector2.new(0.5, 0.5)
        marker.BackgroundColor3 = Color3.fromRGB(255, 50, 50); marker.BorderSizePixel = 0
        local mCorner = Instance.new("UICorner", marker); mCorner.CornerRadius = UDim.new(1, 0)
        self.UI.CalibrationMarker = marker
    end
end

function DetectionSuite:AdvanceCalibration(clickPos)
    local step = self.State.CalibrationStep
    if step == 0 or step > 3 then return end
    
    table.insert(self.State.CalibrationClicks, clickPos - self.UI.DetectionArea.AbsolutePosition)
    self.State.CalibrationStep += 1
    
    if self.State.CalibrationStep > 3 then
        self:CalculateAndApplyScaling()
    end
    self:UpdateCalibrationPrompt()
end

function DetectionSuite:CalculateAndApplyScaling()
    local clicks = self.State.CalibrationClicks
    local detectedWidth = clicks[2].X - clicks[1].X
    local detectedHeight = clicks[3].Y - clicks[1].Y
    
    local targetSize = self.UI.DetectionArea.AbsoluteSize
    
    if detectedWidth > 1 and detectedHeight > 1 then
        self.State.CurrentScale = Vector2.new(targetSize.X / detectedWidth, targetSize.Y / detectedHeight)
        self.State.CurrentOffset = clicks[1]
        
        local msg = string.format("New Scale: (%.2f, %.2f) | Offset: (%d, %d)", self.State.CurrentScale.X, self.State.CurrentScale.Y, self.State.CurrentOffset.X, self.State.CurrentOffset.Y)
        StarterGui:SetCore("SendNotification", {Title = "Calibration Success", Text = msg, Duration = 10})
    else
        StarterGui:SetCore("SendNotification", {Title = "Calibration Failed", Text = "Could not determine valid scaling.", Duration = 10})
    end
    
    self.State.CalibrationStep = 0
    self:UpdateStats()
end

-- --- Event Handling & Initialization ---
function DetectionSuite:Initialize()
    self:CreateUI()
    
    -- 3.1 & 3.3: Primary Detection and Event Logging
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        
        local pos = input.Position
        
        if self.State.CalibrationStep > 0 then
            self:AdvanceCalibration(pos)
        elseif self.State.IsTestRunning then
            self:LogClick(pos)
        end
    end)
    
    -- 3.2: Secondary Detection (Mouse Tracking)
    RunService.Heartbeat:Connect(function()
        if not self.State.IsOverlayVisible then return end
        local mousePos = UserInputService:GetMouseLocation() - guiInset
        self.UI.CoordDisplay.Position = UDim2.fromOffset(mousePos.X + 15, mousePos.Y + 15)
        
        local relativePos = mousePos - self.UI.DetectionArea.AbsolutePosition
        self.UI.CoordDisplay.Text = string.format("Screen: (%d, %d) | Area: (%d, %d)", mousePos.X, mousePos.Y, relativePos.X, relativePos.Y)
        
        -- 2.3: Zone Coloring (Visual Feedback)
        if self:IsInDetectionArea(mousePos) then self.UI.CoordDisplay.TextColor3 = Color3.fromRGB(150, 255, 150)
        else self.UI.CoordDisplay.TextColor3 = Color3.fromRGB(255, 150, 150) end
    end)
    
    -- Control Panel Button Connections
    self.UI.ToggleOverlayBtn.MouseButton1Click:Connect(function()
        self.State.IsOverlayVisible = not self.State.IsOverlayVisible
        self.UI.OverlayFrame.Visible = self.State.IsOverlayVisible
        self.UI.CoordDisplay.Visible = self.State.IsOverlayVisible
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
            self.UI.StartTestBtn.Text = "Start Detection Test"
            self:UpdateStats()
        end
    end)
    
    self.UI.CalibrateBtn.MouseButton1Click:Connect(function() self:StartCalibration() end)
end

-- --- Run the suite ---
DetectionSuite:Initialize()
