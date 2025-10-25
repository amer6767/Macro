-- InsetFinder.lua
-- Run this script and tap the TOP-LEFT corner of your game (not the black bars).
-- Report the (X, Y) numbers from the console.

while not (game and game.GetService) do wait(0.05) end

local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local function sendNotification(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = 6})
    end)
end

sendNotification("Calibrator Active", "Please tap the TOP-LEFT corner of the 3D game world.")
print("[CALIBRATOR]: Waiting for tap at top-left corner...")

local conn
conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    local ut = input.UserInputType
    if not (ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch) then return end
    
    local pos = input.Position
    local msg = string.format("[INSET CALIBRATION]: X = %d, Y = %d", math.floor(pos.X), math.floor(pos.Y))
    
    -- Print to console (for dev) and send notification (for user)
    print(msg)
    sendNotification("Inset Found!", msg)
    
    -- Disconnect to prevent spam
    if conn then
        conn:Disconnect()
    end
end)
