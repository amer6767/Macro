-- This is UI_Module.lua
-- It contains ONLY the GUI creation code.
-- It is loaded by Main.lua and creates global variables for all UI elements
-- so that Core_Module.lua can connect to them.

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local FONT_MAIN = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamBold

-- --- Main ScreenGui ---
-- 'mainGui' will be a global variable in the loadstring environment.
mainGui = Instance.new("ScreenGui")
mainGui.Name = "MacroV2GUI"
mainGui.IgnoreGuiInset = true
mainGui.ResetOnSpawn = false
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
mainGui.Parent = CoreGui

-- --- Main Frame ---
mainFrame = Instance.new("Frame", mainGui)
mainFrame.Size = UDim2.new(0, 260, 0, 360)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Visible = false -- Main.lua will make this visible
local frameCorner = Instance.new("UICorner", mainFrame)
frameCorner.CornerRadius = UDim.new(0, 12)

dragLayer = Instance.new("Frame", mainFrame)
dragLayer.Size = UDim2.new(1, 0, 0, 40)
dragLayer.BackgroundTransparency = 1
dragLayer.ZIndex = 1
dragLayer.Active = true

local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "Macro V2"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = FONT_BOLD
title.TextSize = 22
title.ZIndex = 2

-- --- Tab Bar ---
tabBar = Instance.new("Frame", mainFrame)
tabBar.Size = UDim2.new(1, 0, 0, 40)
tabBar.Position = UDim2.new(0, 0, 0, 40)
tabBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)

tabAutoClicker = Instance.new("TextButton", tabBar)
tabAutoClicker.Size = UDim2.new(0, 75, 1, 0)
tabAutoClicker.Text = "Auto"
tabAutoClicker.Font = FONT_MAIN
tabAutoClicker.TextSize = 14
tabAutoClicker.TextColor3 = Color3.new(1, 1, 1)
tabAutoClicker.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
local tabAutoCorner = Instance.new("UICorner", tabAutoClicker)
tabAutoCorner.CornerRadius = UDim.new(0, 4)

tabRecorder = Instance.new("TextButton", tabBar)
tabRecorder.Size = UDim2.new(0, 75, 1, 0)
tabRecorder.Position = UDim2.new(0, 75, 0, 0)
tabRecorder.Text = "Record"
tabRecorder.Font = FONT_MAIN
tabRecorder.TextSize = 14
tabRecorder.TextColor3 = Color3.new(1, 1, 1)
tabRecorder.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
local tabRecordCorner = Instance.new("UICorner", tabRecorder)
tabRecordCorner.CornerRadius = UDim.new(0, 4)

tabSettings = Instance.new("TextButton", tabBar)
tabSettings.Size = UDim2.new(0, 75, 1, 0)
tabSettings.Position = UDim2.new(0, 150, 0, 0)
tabSettings.Text = "Settings"
tabSettings.Font = FONT_MAIN
tabSettings.TextSize = 14
tabSettings.TextColor3 = Color3.new(1, 1, 1)
tabSettings.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
local tabSettingsCorner = Instance.new("UICorner", tabSettings)
tabSettingsCorner.CornerRadius = UDim.new(0, 4)

-- --- Content Areas ---
contentArea = Instance.new("Frame", mainFrame)
contentArea.Size = UDim2.new(1, 0, 1, -80)
contentArea.Position = UDim2.new(0, 0, 0, 80)
contentArea.BackgroundTransparency = 1

autoContent = Instance.new("Frame", contentArea)
autoContent.Size = UDim2.new(1, 0, 1, 0)
autoContent.BackgroundTransparency = 1
autoContent.Visible = true

recordContent = Instance.new("Frame", contentArea)
recordContent.Size = UDim2.new(1, 0, 1, 0)
recordContent.BackgroundTransparency = 1
recordContent.Visible = false

settingsContent = Instance.new("Frame", contentArea)
settingsContent.Size = UDim2.new(1, 0, 1, 0)
settingsContent.BackgroundTransparency = 1
settingsContent.Visible = false

-- --- Button Factory ---
local function createButton(text, posY, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.85, 0, 0, 30)
    btn.Position = UDim2.new(0.075, 0, 0, posY)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = FONT_MAIN
    btn.TextSize = 16
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    btn.BorderSizePixel = 0
    btn.ZIndex = 3
    btn.Parent = parent
    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 6)
    return btn
end

-- --- Auto Tab Content ---
btnAutoClicker = createButton("Auto Clicker: OFF", 10, autoContent)
btnSetPosition = createButton("Set Position", 50, autoContent)
lblInterval = Instance.new("TextBox", autoContent)
lblInterval.Size = UDim2.new(0.85, 0, 0, 30)
lblInterval.Position = UDim2.new(0.075, 0, 0, 90)
lblInterval.PlaceholderText = "Click Interval (sec)"
lblInterval.Text = "0.2" -- Default
lblInterval.Font = FONT_MAIN
lblInterval.TextSize = 14
lblInterval.TextColor3 = Color3.fromRGB(255, 255, 255)
lblInterval.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
lblInterval.BorderSizePixel = 0
local lblIntervalCorner = Instance.new("UICorner", lblInterval)
lblIntervalCorner.CornerRadius = UDim.new(0, 6)

-- --- Record Tab Content ---
btnStartRecording = createButton("Start Recording", 10, recordContent)
btnReplayClicks = createButton("Replay Clicks", 50, recordContent)
btnReplayLoop = createButton("Replay Loop: OFF", 90, recordContent)

replayCountInput = Instance.new("TextBox", recordContent)
replayCountInput.Size = UDim2.new(0.85, 0, 0, 30)
replayCountInput.Position = UDim2.new(0.075, 0, 0, 130)
replayCountInput.PlaceholderText = "Replay Amount (default 1)"
replayCountInput.Text = "1"
replayCountInput.Font = FONT_MAIN
replayCountInput.TextSize = 16
replayCountInput.TextColor3 = Color3.fromRGB(255, 255, 255)
replayCountInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
replayCountInput.BorderSizePixel = 0
replayCountInput.ZIndex = 3
local replayCorner = Instance.new("UICorner", replayCountInput)
replayCorner.CornerRadius = UDim.new(0, 6)

-- --- Settings Tab Content ---
offsetXInput = Instance.new("TextBox", settingsContent)
offsetXInput.Size = UDim2.new(0.85, 0, 0, 30)
offsetXInput.Position = UDim2.new(0.075, 0, 0, 10)
offsetXInput.PlaceholderText = "Set X Offset (px or % e.g. 10 or 2%)"
offsetXInput.Text = "0"
offsetXInput.Font = FONT_MAIN
offsetXInput.TextSize = 16
offsetXInput.TextColor3 = Color3.fromRGB(255, 255, 255)
offsetXInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
offsetXInput.BorderSizePixel = 0
offsetXInput.ClearTextOnFocus = false
offsetXInput.ZIndex = 3
local offsetXCorner = Instance.new("UICorner", offsetXInput)
offsetXCorner.CornerRadius = UDim.new(0, 6)

offsetYInput = Instance.new("TextBox", settingsContent)
offsetYInput.Size = UDim2.new(0.85, 0, 0, 30)
offsetYInput.Position = UDim2.new(0.075, 0, 0, 50)
offsetYInput.PlaceholderText = "Set Y Offset (px or % e.g. -5 or -1%)"
offsetYInput.Text = "0"
offsetYInput.Font = FONT_MAIN
offsetYInput.TextSize = 16
offsetYInput.TextColor3 = Color3.fromRGB(255, 255, 255)
offsetYInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
offsetYInput.BorderSizePixel = 0
offsetYInput.ClearTextOnFocus = false
offsetYInput.ZIndex = 3
local offsetYCorner = Instance.new("UICorner", offsetYInput)
offsetYCorner.CornerRadius = UDim.new(0, 6)

swipeCurveInput = Instance.new("TextBox", settingsContent)
swipeCurveInput.Size = UDim2.new(0.85, 0, 0, 30)
swipeCurveInput.Position = UDim2.new(0.075, 0, 0, 90)
swipeCurveInput.PlaceholderText = "Swipe Curvature (0..50%)"
swipeCurveInput.Text = "0" -- Default
swipeCurveInput.Font = FONT_MAIN
swipeCurveInput.TextSize = 16
swipeCurveInput.TextColor3 = Color3.fromRGB(255, 255, 255)
swipeCurveInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
swipeCurveInput.BorderSizePixel = 0
swipeCurveInput.ClearTextOnFocus = false
swipeCurveInput.ZIndex = 3
local swipeCorner = Instance.new("UICorner", swipeCurveInput)
swipeCorner.CornerRadius = UDim.new(0, 6)

btnApplyOffsets = createButton("Apply Offsets & Swipe Curve", 130, settingsContent)

-- --- Toggle Button ---
toggleGuiBtn = Instance.new("TextButton", mainGui)
toggleGuiBtn.Size = UDim2.new(0, 70, 0, 30)
toggleGuiBtn.Position = UDim2.new(0, 10, 0, 70)
toggleGuiBtn.Text = "Hide"
toggleGuiBtn.Font = FONT_MAIN
toggleGuiBtn.TextSize = 14
toggleGuiBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
toggleGuiBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleGuiBtn.ZIndex = 1000
toggleGuiBtn.Visible = false -- Main.lua will make this visible
toggleGuiBtn.Active = true
local toggleCorner = Instance.new("UICorner", toggleGuiBtn)
toggleCorner.CornerRadius = UDim.new(0, 6)

-- --- Draggability ---
local function makeDraggable(guiObject, dragHandle)
    local dragging = false
    local dragStartMousePos
    local objectStartPos

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStartMousePos = UserInputService:GetMouseLocation()
            objectStartPos = guiObject.Position
        end
    end)

    dragHandle.InputChanged:Connect(function(changedInput)
        if not dragging then return end
        if changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch then
            local currentMousePos = UserInputService:GetMouseLocation()
            local delta = currentMousePos - dragStartMousePos
            guiObject.Position = UDim2.new(
                objectStartPos.X.Scale, objectStartPos.X.Offset + delta.X,
                objectStartPos.Y.Scale, objectStartPos.Y.Offset + delta.Y
            )
        end
    end)

    dragHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

makeDraggable(mainFrame, dragLayer)
makeDraggable(toggleGuiBtn, toggleGuiBtn)


-- Tab switching is local to the UI, so we can connect it.
tabAutoClicker.MouseButton1Click:Connect(function() 
    autoContent.Visible = true
    recordContent.Visible = false
    settingsContent.Visible = false
    tabAutoClicker.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    tabRecorder.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    tabSettings.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
end)
tabRecorder.MouseButton1Click:Connect(function() 
    autoContent.Visible = false
    recordContent.Visible = true
    settingsContent.Visible = false
    tabAutoClicker.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    tabRecorder.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    tabSettings.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
end)
tabSettings.MouseButton1Click:Connect(function() 
    autoContent.Visible = false
    recordContent.Visible = false
    settingsContent.Visible = true
    tabAutoClicker.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    tabRecorder.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    tabSettings.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
end)

-- Set initial state
tabAutoClicker.BackgroundColor3 = Color3.fromRGB(60, 60, 60) -- Set "Auto" as active
