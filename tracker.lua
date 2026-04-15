-- ============================================================
-- Delta Executor Mobile Activity Tracker v3.0
-- Upgraded: Error handling, Remote throttle, Filter system,
--           Clear/Export log, Sound tracking, Drag clamp,
--           Remote args logging
-- ============================================================

local CoreGui       = game:GetService("CoreGui")
local Players       = game:GetService("Players")
local ProximityPS   = game:GetService("ProximityPromptService")
local UIS           = game:GetService("UserInputService")
local RunService    = game:GetService("RunService")
local Workspace     = game:GetService("Workspace")

local LocalPlayer   = Players.LocalPlayer
local Camera        = Workspace.CurrentCamera

-- ============================================================
-- CONFIG
-- ============================================================
local MAX_LOGS              = 80
local REMOTE_THROTTLE_SEC   = 0.15   -- min interval per remote name
local REMOTE_MAX_ARGS_LEN   = 120    -- max chars for args preview
local FRAME_W, FRAME_H      = 340, 260

-- ============================================================
-- SETUP GUI (hapus duplikat saat re-execute)
-- ============================================================
local guiName = "DeltaTrackerUI_v3"
if CoreGui:FindFirstChild(guiName) then
    CoreGui[guiName]:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = guiName
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local ok = pcall(function()
    ScreenGui.Parent = (gethui and gethui()) or CoreGui
end)
if not ok then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- ============================================================
-- UTILITY
-- ============================================================
local connections = {} -- simpan semua connections biar bisa cleanup

local function safeConnect(signal, callback)
    local conn
    conn = signal:Connect(function(...)
        local s, e = pcall(callback, ...)
        if not s then
            warn("[Tracker Error] " .. tostring(e))
        end
    end)
    table.insert(connections, conn)
    return conn
end

local function truncate(str, maxLen)
    if #str > maxLen then
        return string.sub(str, 1, maxLen) .. "..."
    end
    return str
end

local function serializeArgs(...)
    local args = {...}
    if #args == 0 then return "()" end
    local parts = {}
    for i, v in ipairs(args) do
        local t = typeof(v)
        if t == "string" then
            table.insert(parts, '"' .. truncate(v, 30) .. '"')
        elseif t == "Instance" then
            table.insert(parts, v:GetFullName())
        elseif t == "table" then
            local count = 0
            for _ in pairs(v) do count = count + 1 end
            table.insert(parts, "{table:" .. count .. "}")
        else
            table.insert(parts, tostring(v))
        end
    end
    return truncate("(" .. table.concat(parts, ", ") .. ")", REMOTE_MAX_ARGS_LEN)
end

-- ============================================================
-- FRAME UTAMA
-- ============================================================
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, FRAME_W, 0, FRAME_H)
MainFrame.Position = UDim2.new(0.5, -FRAME_W / 2, 0.5, -FRAME_H / 2)
MainFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(70, 70, 130)
MainStroke.Thickness = 1.2
MainStroke.Transparency = 0.3
MainStroke.Parent = MainFrame

-- Drop shadow effect
local Shadow = Instance.new("ImageLabel")
Shadow.Name = "Shadow"
Shadow.BackgroundTransparency = 1
Shadow.Position = UDim2.new(0, -12, 0, -8)
Shadow.Size = UDim2.new(1, 24, 1, 20)
Shadow.ZIndex = -1
Shadow.Image = "rbxassetid://5554236805"
Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
Shadow.ImageTransparency = 0.6
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(23, 23, 277, 277)
Shadow.Parent = MainFrame

-- ============================================================
-- TOPBAR
-- ============================================================
local TOPBAR_H = 30

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, TOPBAR_H)
TopBar.BackgroundColor3 = Color3.fromRGB(26, 26, 40)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 10)
TopCorner.Parent = TopBar

-- Fix sudut bawah topbar
local TopFiller = Instance.new("Frame")
TopFiller.Size = UDim2.new(1, 0, 0, 10)
TopFiller.Position = UDim2.new(0, 0, 1, -10)
TopFiller.BackgroundColor3 = Color3.fromRGB(26, 26, 40)
TopFiller.BorderSizePixel = 0
TopFiller.Parent = TopBar

-- Dot merah + pulse animation
local Dot = Instance.new("Frame")
Dot.Size = UDim2.new(0, 7, 0, 7)
Dot.Position = UDim2.new(0, 10, 0.5, -3)
Dot.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
Dot.BorderSizePixel = 0
Dot.Parent = TopBar
Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)

-- Pulse animation for dot
task.spawn(function()
    while ScreenGui.Parent do
        for i = 0, 10 do
            Dot.BackgroundTransparency = i / 20
            task.wait(0.06)
        end
        for i = 10, 0, -1 do
            Dot.BackgroundTransparency = i / 20
            task.wait(0.06)
        end
    end
end)

-- Title
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -110, 1, 0)
Title.Position = UDim2.new(0, 24, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚡ Tracker v3  [Delta]"
Title.TextColor3 = Color3.fromRGB(190, 190, 255)
Title.Font = Enum.Font.Code
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

-- ============================================================
-- TOPBAR BUTTONS: Close, Minimize, Clear, Export
-- ============================================================
local function makeBtn(label, xOffset, bgColor, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 24, 0, 20)
    btn.Position = UDim2.new(1, xOffset, 0.5, -10)
    btn.BackgroundColor3 = bgColor
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.AutoButtonColor = true
    btn.Parent = parent or TopBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    return btn
end

local CloseBtn  = makeBtn("✕",  -6,  Color3.fromRGB(190, 45, 45))
local MinBtn    = makeBtn("−",  -34, Color3.fromRGB(55, 55, 75))
local ClearBtn  = makeBtn("🗑", -62, Color3.fromRGB(55, 55, 75))
local ExportBtn = makeBtn("📋", -90, Color3.fromRGB(55, 55, 75))

-- ============================================================
-- FILTER BAR
-- ============================================================
local FILTER_H = 24

local FilterBar = Instance.new("Frame")
FilterBar.Size = UDim2.new(1, 0, 0, FILTER_H)
FilterBar.Position = UDim2.new(0, 0, 0, TOPBAR_H)
FilterBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
FilterBar.BorderSizePixel = 0
FilterBar.Parent = MainFrame

local FilterLayout = Instance.new("UIListLayout")
FilterLayout.FillDirection = Enum.FillDirection.Horizontal
FilterLayout.SortOrder = Enum.SortOrder.LayoutOrder
FilterLayout.Padding = UDim.new(0, 3)
FilterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
FilterLayout.Parent = FilterBar

local FilterPad = Instance.new("UIPadding")
FilterPad.PaddingLeft = UDim.new(0, 6)
FilterPad.PaddingTop = UDim.new(0, 2)
FilterPad.PaddingBottom = UDim.new(0, 2)
FilterPad.Parent = FilterBar

-- Filter state
local filterCategories = {
    { tag = "ALL",      color = Color3.fromRGB(180, 180, 255) },
    { tag = "CHAT",     color = Color3.fromRGB(255, 240, 100) },
    { tag = "REMOTE",   color = Color3.fromRGB(80, 200, 255)  },
    { tag = "TOOL",     color = Color3.fromRGB(255, 180, 80)  },
    { tag = "INTERACT", color = Color3.fromRGB(180, 130, 255) },
    { tag = "PLAYER",   color = Color3.fromRGB(100, 255, 130) },
    { tag = "SOUND",    color = Color3.fromRGB(255, 150, 200) },
}

local activeFilter = "ALL"
local filterButtons = {}

local function updateFilterHighlight()
    for tag, btn in pairs(filterButtons) do
        if tag == activeFilter then
            btn.BackgroundColor3 = Color3.fromRGB(70, 70, 110)
            btn.TextTransparency = 0
        else
            btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
            btn.TextTransparency = 0.4
        end
    end
end

local function applyFilter()
    for _, child in ipairs(LogContainer and LogContainer:GetChildren() or {}) do
        if child:IsA("TextLabel") then
            if activeFilter == "ALL" then
                child.Visible = true
            else
                local tag = child:GetAttribute("LogTag") or ""
                child.Visible = (tag == activeFilter)
            end
        end
    end
end

for i, cat in ipairs(filterCategories) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 42, 0, 18)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    btn.BorderSizePixel = 0
    btn.Text = cat.tag
    btn.TextColor3 = cat.color
    btn.Font = Enum.Font.Code
    btn.TextSize = 9
    btn.TextTransparency = 0.4
    btn.LayoutOrder = i
    btn.AutoButtonColor = false
    btn.Parent = FilterBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    filterButtons[cat.tag] = btn

    btn.MouseButton1Click:Connect(function()
        activeFilter = cat.tag
        updateFilterHighlight()
        applyFilter()
    end)
end

updateFilterHighlight()

-- ============================================================
-- LOG CONTAINER (ScrollingFrame)
-- ============================================================
local LogContainer = Instance.new("ScrollingFrame")
LogContainer.Size = UDim2.new(1, 0, 1, -(TOPBAR_H + FILTER_H))
LogContainer.Position = UDim2.new(0, 0, 0, TOPBAR_H + FILTER_H)
LogContainer.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
LogContainer.BorderSizePixel = 0
LogContainer.ScrollBarThickness = 3
LogContainer.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 170)
LogContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
LogContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogContainer.Parent = MainFrame

-- Rounded bottom corners
local LogCorner = Instance.new("UICorner")
LogCorner.CornerRadius = UDim.new(0, 10)
LogCorner.Parent = LogContainer

-- Fix: top corners LogContainer supaya rata
local LogTopFill = Instance.new("Frame")
LogTopFill.Size = UDim2.new(1, 0, 0, 10)
LogTopFill.Position = UDim2.new(0, 0, 0, 0)
LogTopFill.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
LogTopFill.BorderSizePixel = 0
LogTopFill.ZIndex = 2
LogTopFill.Parent = LogContainer

local UIList = Instance.new("UIListLayout")
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 1)
UIList.Parent = LogContainer

local UIPad = Instance.new("UIPadding")
UIPad.PaddingLeft = UDim.new(0, 6)
UIPad.PaddingRight = UDim.new(0, 6)
UIPad.PaddingTop = UDim.new(0, 4)
UIPad.Parent = LogContainer

-- Re-wire applyFilter now that LogContainer exists
applyFilter = function()
    for _, child in ipairs(LogContainer:GetChildren()) do
        if child:IsA("TextLabel") then
            if activeFilter == "ALL" then
                child.Visible = true
            else
                local tag = child:GetAttribute("LogTag") or ""
                child.Visible = (tag == activeFilter)
            end
        end
    end
end

-- ============================================================
-- DRAG LOGIC (Mouse & Touch) + VIEWPORT CLAMP
-- ============================================================
local dragging = false
local dragInput = nil
local dragStart = nil
local startPos  = nil

local function clampPosition(pos)
    local vpSize = Camera.ViewportSize
    local maxX = vpSize.X - MainFrame.AbsoluteSize.X
    local maxY = vpSize.Y - MainFrame.AbsoluteSize.Y

    local x = math.clamp(pos.X.Offset, 0, math.max(0, maxX))
    local y = math.clamp(pos.Y.Offset, 0, math.max(0, maxY))
    return UDim2.new(0, x, 0, y)
end

local function updateDrag(input)
    if dragging and dragStart then
        local delta = input.Position - dragStart
        local newPos = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
        MainFrame.Position = clampPosition(newPos)
    end
end

TopBar.InputBegan:Connect(function(input)
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
        dragging = true
        dragInput = input
        dragStart = input.Position
        -- Konversi posisi ke offset murni untuk clamping yang akurat
        startPos = UDim2.new(
            0, MainFrame.AbsolutePosition.X,
            0, MainFrame.AbsolutePosition.Y
        )
    end
end)

TopBar.InputEnded:Connect(function(input)
    if input == dragInput then
        dragging = false
        dragInput = nil
    end
end)

UIS.InputChanged:Connect(function(input)
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
        updateDrag(input)
    end
end)

-- ============================================================
-- MINIMIZE & CLOSE
-- ============================================================
local minimized = false

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        MainFrame.Size = UDim2.new(0, FRAME_W, 0, TOPBAR_H)
        LogContainer.Visible = false
        FilterBar.Visible = false
        MinBtn.Text = "+"
    else
        MainFrame.Size = UDim2.new(0, FRAME_W, 0, FRAME_H)
        LogContainer.Visible = true
        FilterBar.Visible = true
        MinBtn.Text = "−"
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    -- Disconnect all event connections
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}
    ScreenGui:Destroy()
end)

-- ============================================================
-- LOGGING SYSTEM
-- ============================================================
local logOrder = 0
local allLogTexts = {} -- simpan teks untuk export

local function addLog(text, color, tag)
    logOrder = logOrder + 1
    tag = tag or "SYSTEM"

    -- Simpan untuk export
    local fullText = os.date("%H:%M:%S") .. "  " .. text
    table.insert(allLogTexts, fullText)
    if #allLogTexts > MAX_LOGS * 2 then
        table.remove(allLogTexts, 1)
    end

    local msg = Instance.new("TextLabel")
    msg.Size = UDim2.new(1, 0, 0, 0)
    msg.AutomaticSize = Enum.AutomaticSize.Y
    msg.BackgroundTransparency = 1
    msg.Text = fullText
    msg.TextColor3 = color or Color3.fromRGB(200, 200, 200)
    msg.Font = Enum.Font.Code
    msg.TextSize = 11
    msg.TextWrapped = true
    msg.TextXAlignment = Enum.TextXAlignment.Left
    msg.RichText = false
    msg.LayoutOrder = logOrder
    msg:SetAttribute("LogTag", tag)
    msg.Parent = LogContainer

    -- Visibility sesuai filter aktif
    if activeFilter ~= "ALL" and tag ~= activeFilter then
        msg.Visible = false
    end

    -- Hapus log tertua jika melebihi batas
    local children = LogContainer:GetChildren()
    local count = 0
    for _, c in ipairs(children) do
        if c:IsA("TextLabel") then count = count + 1 end
    end
    if count > MAX_LOGS then
        for _, c in ipairs(children) do
            if c:IsA("TextLabel") then
                c:Destroy()
                break
            end
        end
    end

    -- Auto scroll ke bawah
    task.defer(function()
        LogContainer.CanvasPosition = Vector2.new(0, math.huge)
    end)
end

-- ============================================================
-- CLEAR LOG
-- ============================================================
ClearBtn.MouseButton1Click:Connect(function()
    for _, child in ipairs(LogContainer:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    allLogTexts = {}
    logOrder = 0
    addLog("🗑 Log cleared", Color3.fromRGB(150, 150, 180), "SYSTEM")
end)

-- ============================================================
-- EXPORT LOG TO CLIPBOARD
-- ============================================================
ExportBtn.MouseButton1Click:Connect(function()
    local text = table.concat(allLogTexts, "\n")
    if setclipboard then
        setclipboard(text)
        addLog("📋 Log copied to clipboard! (" .. #allLogTexts .. " entries)", Color3.fromRGB(100, 255, 200), "SYSTEM")
    elseif toclipboard then
        toclipboard(text)
        addLog("📋 Log copied to clipboard! (" .. #allLogTexts .. " entries)", Color3.fromRGB(100, 255, 200), "SYSTEM")
    else
        addLog("⚠ Clipboard not supported by executor", Color3.fromRGB(255, 120, 80), "SYSTEM")
    end
end)

-- ============================================================
-- START LOG
-- ============================================================
addLog("✅ Tracker v3 Started!", Color3.fromRGB(80, 255, 150), "SYSTEM")
addLog("📱 Game: " .. tostring(game.PlaceId) .. " | Players: " .. #Players:GetPlayers(), Color3.fromRGB(160, 160, 200), "SYSTEM")

-- ============================================================
-- 1. PLAYER JOIN / LEAVE / CHAT / SPAWN
-- ============================================================
local function hookPlayer(player)
    safeConnect(player.Chatted, function(msg)
        addLog("[CHAT] " .. player.Name .. ": " .. msg, Color3.fromRGB(255, 240, 100), "CHAT")
    end)
    safeConnect(player.CharacterAdded, function()
        addLog("[SPAWN] " .. player.Name .. " respawned", Color3.fromRGB(150, 220, 255), "PLAYER")
    end)
end

safeConnect(Players.PlayerAdded, function(player)
    addLog("➕ " .. player.Name .. " joined (Total: " .. #Players:GetPlayers() .. ")", Color3.fromRGB(100, 255, 130), "PLAYER")
    hookPlayer(player)
end)

safeConnect(Players.PlayerRemoving, function(player)
    addLog("➖ " .. player.Name .. " left (Total: " .. (#Players:GetPlayers() - 1) .. ")", Color3.fromRGB(255, 100, 100), "PLAYER")
end)

-- Hook existing players
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        hookPlayer(player)
    end
end
hookPlayer(LocalPlayer)

-- ============================================================
-- 2. PROXIMITY PROMPT
-- ============================================================
safeConnect(ProximityPS.PromptTriggered, function(prompt, player)
    local objName = (prompt.Parent and prompt.Parent.Name) or "Unknown"
    local pName = player and player.Name or "?"
    addLog("[INTERACT] " .. pName .. " → " .. objName, Color3.fromRGB(180, 130, 255), "INTERACT")
end)

-- ============================================================
-- 3. TOOL / WEAPON EQUIPPED (LocalPlayer)
-- ============================================================
local function watchCharacter(character)
    if not character then return end
    safeConnect(character.ChildAdded, function(child)
        if child:IsA("Tool") then
            addLog("[TOOL] Equipped: " .. child.Name, Color3.fromRGB(255, 180, 80), "TOOL")
        end
    end)
    safeConnect(character.ChildRemoved, function(child)
        if child:IsA("Tool") then
            addLog("[TOOL] Unequipped: " .. child.Name, Color3.fromRGB(200, 140, 60), "TOOL")
        end
    end)
end

if LocalPlayer.Character then
    watchCharacter(LocalPlayer.Character)
end
safeConnect(LocalPlayer.CharacterAdded, watchCharacter)

-- ============================================================
-- 4. SOUND TRACKING
-- ============================================================
local trackedSounds = {}

local function trackSound(sound)
    if not sound:IsA("Sound") then return end
    if trackedSounds[sound] then return end
    trackedSounds[sound] = true

    safeConnect(sound.Played, function()
        local path = sound.Parent and sound.Parent.Name or "?"
        local id = tostring(sound.SoundId)
        -- Filter out ambient/music yang terlalu sering
        if sound.Looped then return end
        addLog("[SOUND] " .. path .. "/" .. sound.Name .. " (" .. id .. ")", Color3.fromRGB(255, 150, 200), "SOUND")
    end)
end

-- Track sounds yang ada di character
local function trackCharacterSounds(char)
    if not char then return end
    for _, desc in ipairs(char:GetDescendants()) do
        trackSound(desc)
    end
    safeConnect(char.DescendantAdded, function(desc)
        task.defer(function()
            trackSound(desc)
        end)
    end)
end

if LocalPlayer.Character then
    trackCharacterSounds(LocalPlayer.Character)
end
safeConnect(LocalPlayer.CharacterAdded, trackCharacterSounds)

-- Track sounds di workspace (top-level saja agar tidak overload)
for _, child in ipairs(Workspace:GetChildren()) do
    if child:IsA("Sound") then
        trackSound(child)
    end
end
safeConnect(Workspace.ChildAdded, function(child)
    if child:IsA("Sound") then
        task.defer(function() trackSound(child) end)
    end
end)

-- ============================================================
-- 5. INSTANCE TRACKING (significant objects di workspace)
-- ============================================================
local trackedClasses = {
    ["Explosion"]       = true,
    ["ParticleEmitter"] = true,
    ["Fire"]            = true,
    ["Smoke"]           = true,
}

safeConnect(Workspace.DescendantAdded, function(desc)
    if trackedClasses[desc.ClassName] then
        local parentName = desc.Parent and desc.Parent.Name or "?"
        addLog("[FX] " .. desc.ClassName .. " @ " .. parentName, Color3.fromRGB(255, 200, 100), "INTERACT")
    end
end)

-- ============================================================
-- 6. REMOTE EVENT SPY (hookmetamethod) + THROTTLE + ARGS
-- ============================================================
if getnamecallmethod and hookmetamethod and checkcaller then
    local remoteThrottleMap = {} -- remoteName → lastTime

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
            local remoteName = tostring(self)
            local now = tick()

            -- Throttle: skip jika remote sama di-fire terlalu cepat
            if remoteThrottleMap[remoteName] and (now - remoteThrottleMap[remoteName]) < REMOTE_THROTTLE_SEC then
                return oldNamecall(self, ...)
            end
            remoteThrottleMap[remoteName] = now

            local args = {...}
            task.spawn(function()
                local argsStr = serializeArgs(unpack(args))
                addLog("[REMOTE] " .. method .. " → " .. remoteName .. " " .. argsStr, Color3.fromRGB(80, 200, 255), "REMOTE")
            end)
        end
        return oldNamecall(self, ...)
    end)

    -- Cleanup throttle map periodically
    task.spawn(function()
        while ScreenGui.Parent do
            task.wait(30)
            local now = tick()
            for k, v in pairs(remoteThrottleMap) do
                if now - v > 10 then
                    remoteThrottleMap[k] = nil
                end
            end
        end
    end)

    addLog("🔗 Remote Spy aktif (throttled)", Color3.fromRGB(80, 255, 200), "SYSTEM")
else
    addLog("⚠ Executor tidak support metamethod hook", Color3.fromRGB(255, 120, 80), "SYSTEM")
end

-- ============================================================
-- 7. STATUS BAR (bottom)
-- ============================================================
local StatusBar = Instance.new("Frame")
StatusBar.Size = UDim2.new(1, 0, 0, 16)
StatusBar.Position = UDim2.new(0, 0, 1, -16)
StatusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
StatusBar.BorderSizePixel = 0
StatusBar.ZIndex = 5
StatusBar.Parent = MainFrame

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 10)
StatusCorner.Parent = StatusBar

local StatusFiller = Instance.new("Frame")
StatusFiller.Size = UDim2.new(1, 0, 0, 10)
StatusFiller.Position = UDim2.new(0, 0, 0, 0)
StatusFiller.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
StatusFiller.BorderSizePixel = 0
StatusFiller.ZIndex = 5
StatusFiller.Parent = StatusBar

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -12, 1, 0)
StatusLabel.Position = UDim2.new(0, 6, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Ready"
StatusLabel.TextColor3 = Color3.fromRGB(100, 100, 140)
StatusLabel.Font = Enum.Font.Code
StatusLabel.TextSize = 9
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.ZIndex = 6
StatusLabel.Parent = StatusBar

-- Update status bar periodically
task.spawn(function()
    while ScreenGui.Parent do
        local playerCount = #Players:GetPlayers()
        local logCount = 0
        for _, c in ipairs(LogContainer:GetChildren()) do
            if c:IsA("TextLabel") then logCount = logCount + 1 end
        end
        StatusLabel.Text = "Players: " .. playerCount .. "  |  Logs: " .. logCount .. "/" .. MAX_LOGS .. "  |  FPS: " .. math.floor(1 / RunService.Heartbeat:Wait())
    end
end)

-- Adjust LogContainer to account for status bar
LogContainer.Size = UDim2.new(1, 0, 1, -(TOPBAR_H + FILTER_H + 16))

addLog("🎯 All systems ready — happy tracking!", Color3.fromRGB(130, 200, 255), "SYSTEM")
