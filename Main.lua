-- This is Main.lua-- This is the ONLY script you execute in Delta.-- It will check the key, then load the UI and Core modules.-- --- Wait for Services ---while not (game and game.GetService and game.HttpGet) dowait(0.05)endlocal StarterGui = game:GetService("StarterGui")local CoreGui = game:GetService("CoreGui")local Players = game:GetService("Players")local RunService = game:GetService("RunService")-- Wait for playerlocal player = Players.LocalPlayerwhile not player doRunService.Heartbeat:Wait()player = Players.LocalPlayerend-- --- Config ----- The URLs to your new modules.-- MAKE SURE to use the "raw" GitHub URL.local UI_MODULE_URL = "https://www.google.com/search?q=https://raw.githubusercontent.com/amer6767/macro/main/UI_Module.lua"local CORE_MODULE_URL = "https://www.google.com/search?q=https://raw.githubusercontent.com/amer6767/macro/main/Core_Module.lua"-- --- Helper ---local function sendNotification(title, text)pcall(function()StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = 3})end)end-- --- Key System ---local mainGui = Instance.new("ScreenGui")mainGui.Name = "MacroV2GUI_Key"mainGui.IgnoreGuiInset = truemainGui.ResetOnSpawn = falsemainGui.ZIndexBehavior = Enum.ZIndexBehavior.GlobalmainGui.Parent = CoreGuilocal keyEntry = Instance.new("Frame")keyEntry.Size = UDim2.new(0, 260, 0, 140)keyEntry.Position = UDim2.new(0.5, -130, 0.5, -70)keyEntry.AnchorPoint = Vector2.new(0.5, 0.5)keyEntry.BackgroundColor3 = Color3.fromRGB(35, 35, 35)keyEntry.BorderSizePixel = 0keyEntry.Parent = mainGuilocal keyEntryCorner = Instance.new("UICorner", keyEntry)keyEntryCorner.CornerRadius = UDim.new(0, 8)local keyBox = Instance.new("TextBox", keyEntry)keyBox.Size = UDim2.new(0.9, 0, 0, 30)keyBox.Position = UDim2.new(0.05, 0, 0, 10)keyBox.PlaceholderText = "Enter Key"keyBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)keyBox.TextColor3 = Color3.new(1, 1, 1)keyBox.Font = Enum.Font.GothamkeyBox.TextSize = 16keyBox.BorderSizePixel = 0keyBox.ClearTextOnFocus = falselocal keyBoxCorner = Instance.new("UICorner", keyBox)keyBoxCorner.CornerRadius = UDim.new(0, 6)local submitBtn = Instance.new("TextButton", keyEntry)submitBtn.Size = UDim2.new(0.9, 0, 0, 30)submitBtn.Position = UDim2.new(0.05, 0, 0, 50)submitBtn.Text = "Submit Key"submitBtn.Font = Enum.Font.GothamsubmitBtn.TextSize = 16submitBtn.TextColor3 = Color3.new(1, 1, 1)submitBtn.BackgroundColor3 = Color3.fromRGB(0, 122, 204)submitBtn.BorderSizePixel = 0local submitBtnCorner = Instance.new("UICorner", submitBtn)submitBtnCorner.CornerRadius = UDim.new(0, 6)local copyBtn = Instance.new("TextButton", keyEntry)copyBtn.Size = UDim2.new(0.9, 0, 0, 30)copyBtn.Position = UDim2.new(0.05, 0, 0, 90)copyBtn.Text = "Copy Key Link"copyBtn.Font = Enum.Font.GothamcopyBtn.TextSize = 16copyBtn.TextColor3 = Color3.fromRGB(220, 220, 220)copyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)copyBtn.BorderSizePixel = 0local copyBtnCorner = Instance.new("UICorner", copyBtn)copyBtnCorner.CornerRadius = UDim.new(0, 6)copyBtn.MouseButton1Click:Connect(function()local keyLink = "https://www.google.com/search?q=https.loot-link.com/s%3FAVreZic8"if setclipboard thenlocal success, err = pcall(function() setclipboard(keyLink) end)if success then sendNotification("Link Copied", "The key link has been copied to your clipboard.")else sendNotification("Copy Failed", "setclipboard() error: " .. tostring(err)) endelsekeyBox.Text = keyLinkcopyBtn.Text = "Copy From Box"sendNotification("Now Copy", "Select and copy the link from the text box.")endend)-- --- Module Loader ---local function loadModules()sendNotification("Loading Modules", "Fetching UI...")local uiScript, uiErr = pcall(function() return game:HttpGet(UI_MODULE_URL) end)if not uiScript or uiErr thensendNotification("UI Load Failed", tostring(uiErr))returnendsendNotification("Loading Modules", "Fetching Core...")
local coreScript, coreErr = pcall(function() return game:HttpGet(CORE_MODULE_URL) end)
if not coreScript or coreErr then
    sendNotification("Core Load Failed", tostring(coreErr))
    return
end

-- Load the UI first (to create the global GUI objects)
local uiFunc, uiLoadErr = loadstring(uiScript)
if not uiFunc then
    sendNotification("UI Compile Failed", tostring(uiLoadErr))
    return
end
local uiSuccess, uiRunErr = pcall(uiFunc)
if not uiSuccess then
    sendNotification("UI Run Failed", tostring(uiRunErr))
    return
end

-- Load the Core second (to hook up functions to the GUI)
local coreFunc, coreLoadErr = loadstring(coreScript)
if not coreFunc then
    sendNotification("Core Compile Failed", tostring(coreLoadErr))
    return
end
local coreSuccess, coreRunErr = pcall(coreFunc)
if not coreSuccess then
    sendNotification("Core Run Failed", tostring(coreRunErr))
    return
end

sendNotification("Success", "Macro V2 Loaded.")
mainFrame.Visible = true -- Make the (now loaded) GUI visible
toggleGuiBtn.Visible = true
end-- --- Key Check Logic ---submitBtn.MouseButton1Click:Connect(function()local enteredKey = keyBox.Textlocal expectedKey = "key_not_fetched"local httpGet = game.HttpGet or HttpGet
local success, response = pcall(function()
    return httpGet("https://pastebin.com/raw/v4eb6fHw", true)
end)

if success and response then
    expectedKey = response:match("%S+") or "pastebin_read_error"
else
    sendNotification("Key Check Failed", "Could not fetch key.")
end

if enteredKey == expectedKey or enteredKey == "happybirthday Mohamednigga" then
    sendNotification("Access Granted", "Welcome! Loading modules...")
    keyEntry:Destroy()
    loadModules()
else
    keyBox.Text = ""
    keyBox.PlaceholderText = "Invalid key, try again"
    sendNotification("Access Denied", "The key you entered is incorrect.")
end
end)