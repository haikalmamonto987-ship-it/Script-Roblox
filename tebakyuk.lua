-- ============================================================
-- Tebak Yuk! Smart Helper v1.1 (CLEAN VERSION)
-- For Delta Executor
-- Features: Auto Ask, Smart Guesser, Answer Buttons, 
--           Custom Input, Activity Log, Chat commands
-- ============================================================

local CoreGui          = game:GetService("CoreGui")
local Players          = game:GetService("Players")
local RS               = game:GetService("ReplicatedStorage")
local UIS              = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")

local LocalPlayer      = Players.LocalPlayer
local Camera           = Workspace.CurrentCamera

-- ============================================================
-- CONFIG
-- ============================================================
local ASK_DELAY        = 1.8  
local ANSWER_DELAY     = 0.8  
local MAX_LOGS         = 50
local FRAME_W, FRAME_H = 360, 420

-- ============================================================
-- LOGGING SYSTEM
-- ============================================================
local logOrder2        = 0
local function addLog(text, color)
    if not _G.LogScroll then return end
    logOrder2 = logOrder2 + 1

    local msg = Instance.new("TextLabel")
    msg.Size = UDim2.new(1, 0, 0, 0)
    msg.AutomaticSize = Enum.AutomaticSize.Y
    msg.BackgroundTransparency = 1
    msg.Text = os.date("%H:%M:%S") .. " " .. text
    msg.TextColor3 = color or Color3.fromRGB(180, 180, 200)
    msg.Font = Enum.Font.Code
    msg.TextSize = 9
    msg.TextWrapped = true
    msg.TextXAlignment = Enum.TextXAlignment.Left
    msg.LayoutOrder = logOrder2
    msg.Parent = _G.LogScroll

    -- Limit logs
    local children = _G.LogScroll:GetChildren()
    local count = 0
    for _, c in ipairs(children) do
        if c:IsA("TextLabel") then count = count + 1 end
    end
    if count > MAX_LOGS then
        for _, c in ipairs(children) do
            if c:IsA("TextLabel") then c:Destroy(); break end
        end
    end

    task.defer(function()
        if _G.LogScroll then
            _G.LogScroll.CanvasPosition = Vector2.new(0, math.huge)
        end
    end)
end

-- ============================================================
-- SETUP GUI
-- ============================================================
local guiName = "TebakYukHelper_v1_1"
if CoreGui:FindFirstChild(guiName) then
    CoreGui[guiName]:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = guiName
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 1000
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local ok = pcall(function()
    ScreenGui.Parent = (gethui and gethui()) or CoreGui
end)
if not ok then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- ============================================================
-- FIND REMOTES
-- ============================================================
local remoteAsk = nil
local remoteSend = nil

local function findRemotes()
    local targets = {RS, Workspace}
    for _, service in ipairs(targets) do
        for _, obj in ipairs(service:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local name = obj.Name:lower()
                if name == "askquestion" or name == "ask" then
                    remoteAsk = obj
                elseif name == "sendanswer" or name == "answer" then
                    remoteSend = obj
                end
            end
            if remoteAsk and remoteSend then break end
        end
        if remoteAsk and remoteSend then break end
    end
end

findRemotes()

-- ============================================================
-- SMART QUESTION DATABASE
-- ============================================================
local questionTree = {
    kategori = {
        "Apakah ini Hewan?", "Apakah ini Benda?", "Apakah ini Makanan?",
        "Apakah ini Tempat?", "Apakah ini Orang/Tokoh?", "Apakah ini Tumbuhan?"
    },
    hewan = { "Berkaki 4?", "Terbang?", "Hidup di air?", "Berbulu?", "Peliharaan?", "Buas?" },
    benda = { "Ada di rumah?", "Elektronik?", "Bisa dipegang?", "Logam?", "Sekolah?" },
    makanan = { "Manis?", "Pedas?", "Goreng?", "Buah?", "Sayur?", "Berkuah?" },
    tempat = { "Indonesia?", "Asia?", "Kota?", "Gunung?", "Pantai?" },
    orang = { "YouTuber?", "Laki-laki?", "Masih hidup?", "Artis?", "Atlet?" },
    tumbuhan = { "Berbuah?", "Berbunga?", "Pohon?", "Duri?" },
    tebakan_hewan = { "Kucing?", "Anjing?", "Ayam?", "Gajah?", "Singa?", "Ular?" },
    tebakan_makanan = { "Nasi Goreng?", "Bakso?", "Pizza?", "Burger?", "Apel?" },
    tebakan_benda = { "HP?", "Laptop?", "Meja?", "Buku?", "Tas?" },
    tebakan_tempat = { "Jakarta?", "Bali?", "Paris?", "Tokyo?", "Bandung?" },
    tebakan_orang = { "Windah Basudara?", "Jokowi?", "Atta Halilintar?", "Naruto?" }
}

-- ============================================================
-- UTILITY
-- ============================================================
local function fireAsk(question)
    if remoteAsk then
        if remoteAsk:IsA("RemoteEvent") then remoteAsk:FireServer(question)
        elseif remoteAsk:IsA("RemoteFunction") then pcall(function() remoteAsk:InvokeServer(question) end) end
        return true
    end
    return false
end

local function fireAnswer(answer)
    if remoteSend then
        if remoteSend:IsA("RemoteEvent") then remoteSend:FireServer(answer)
        elseif remoteSend:IsA("RemoteFunction") then pcall(function() remoteSend:InvokeServer(answer) end) end
        return true
    end
    return false
end

-- ============================================================
-- MAIN FRAME
-- ============================================================
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, FRAME_W, 0, FRAME_H)
MainFrame.Position = UDim2.new(0, 20, 0.5, -FRAME_H / 2)
MainFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(100, 60, 180)
MainStroke.Thickness = 1.3
MainStroke.Transparency = 0.2
MainStroke.Parent = MainFrame

-- ============================================================
-- TOPBAR
-- ============================================================
local TOPBAR_H = 30
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, TOPBAR_H)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 10)

local TopFiller = Instance.new("Frame")
TopFiller.Size = UDim2.new(1, 0, 0, 10)
TopFiller.Position = UDim2.new(0, 0, 1, -10)
TopFiller.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
TopFiller.BorderSizePixel = 0
TopFiller.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 24, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🎯 Tebak Yuk! Smart Helper"
Title.TextColor3 = Color3.fromRGB(200, 170, 255)
Title.Font = Enum.Font.Code
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local function makeTopBtn(label, xOffset, bgColor)
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
    btn.Parent = TopBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    return btn
end

local CloseBtn = makeTopBtn("✕", -6, Color3.fromRGB(190, 45, 45))
local MinBtn   = makeTopBtn("−", -34, Color3.fromRGB(55, 55, 75))

-- ============================================================
-- DRAG LOGIC
-- ============================================================
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
local function clampPosition(pos)
    local vpSize = Camera.ViewportSize
    local maxX = vpSize.X - MainFrame.AbsoluteSize.X
    local maxY = vpSize.Y - MainFrame.AbsoluteSize.Y
    return UDim2.new(0, math.clamp(pos.X.Offset, 0, math.max(0, maxX)), 0, math.clamp(pos.Y.Offset, 0, math.max(0, maxY)))
end
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragInput = input; dragStart = input.Position; startPos = UDim2.new(0, MainFrame.AbsolutePosition.X, 0, MainFrame.AbsolutePosition.Y)
    end
end)
TopBar.InputEnded:Connect(function(input) if input == dragInput then dragging = false end end)
UIS.InputChanged:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = clampPosition(UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y))
    end
end)

-- ============================================================
-- CONTENT AREA
-- ============================================================
local ContentFrame = Instance.new("ScrollingFrame")
ContentFrame.Size = UDim2.new(1, 0, 1, -TOPBAR_H)
ContentFrame.Position = UDim2.new(0, 0, 0, TOPBAR_H)
ContentFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
ContentFrame.BorderSizePixel = 0
ContentFrame.ScrollBarThickness = 3
ContentFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 60, 180)
ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ContentFrame.Parent = MainFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Padding = UDim.new(0, 4)
ContentLayout.Parent = ContentFrame

local ContentPad = Instance.new("UIPadding")
ContentPad.PaddingLeft = UDim.new(0, 8)
ContentPad.PaddingRight = UDim.new(0, 8)
ContentPad.PaddingTop = UDim.new(0, 6)
ContentPad.PaddingBottom = UDim.new(0, 6)
ContentPad.Parent = ContentFrame

local layoutOrder = 0
local function nextOrder() layoutOrder = layoutOrder + 1; return layoutOrder end

local function makeSection(title)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 18)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = Color3.fromRGB(130, 100, 200)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = nextOrder()
    label.Parent = ContentFrame
    return label
end

local function makeButtonRow(buttons, height)
    height = height or 28
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, height)
    row.BackgroundTransparency = 1
    row.LayoutOrder = nextOrder()
    row.Parent = ContentFrame
    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Padding = UDim.new(0, 4)
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowLayout.Parent = row
    for i, bData in ipairs(buttons) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, bData.width or 70, 0, height - 4)
        btn.BackgroundColor3 = bData.color or Color3.fromRGB(45, 35, 65)
        btn.BorderSizePixel = 0
        btn.Text = bData.text
        btn.TextColor3 = bData.textColor or Color3.fromRGB(220, 210, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = bData.textSize or 10
        btn.AutoButtonColor = true
        btn.LayoutOrder = i
        btn.Parent = row
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        if bData.callback then btn.MouseButton1Click:Connect(bData.callback) end
    end
end

-- ============================================================
-- UI COMPONENTS
-- ============================================================
makeSection("📡 STATUS")
local StatusFrame = Instance.new("Frame")
StatusFrame.Size = UDim2.new(1, 0, 0, 36)
StatusFrame.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
StatusFrame.BorderSizePixel = 0
StatusFrame.LayoutOrder = nextOrder()
StatusFrame.Parent = ContentFrame
Instance.new("UICorner", StatusFrame).CornerRadius = UDim.new(0, 6)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -12, 0, 16)
StatusLabel.Position = UDim2.new(0, 6, 0, 2)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = (remoteAsk and remoteSend) and "✅ Remote: Connected" or "❌ Remote: Not Found"
StatusLabel.TextColor3 = (remoteAsk and remoteSend) and Color3.fromRGB(80, 255, 150) or Color3.fromRGB(255, 80, 80)
StatusLabel.Font = Enum.Font.Code
StatusLabel.TextSize = 10
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = StatusFrame

local StatusLabel2 = Instance.new("TextLabel")
StatusLabel2.Size = UDim2.new(1, -12, 0, 16)
StatusLabel2.Position = UDim2.new(0, 6, 0, 18)
StatusLabel2.BackgroundTransparency = 1
StatusLabel2.Text = "Mode: Idle"
StatusLabel2.TextColor3 = Color3.fromRGB(160, 160, 200)
StatusLabel2.Font = Enum.Font.Code
StatusLabel2.TextSize = 10
StatusLabel2.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel2.Parent = StatusFrame

makeSection("🤖 AUTO MODE")
local autoRunning = false
makeButtonRow({
    { text = "▶ Auto Smart", width = 90, color = Color3.fromRGB(40, 120, 60), callback = function()
        if autoRunning then return end
        autoRunning = true
        task.spawn(function()
            for phase, list in pairs(questionTree) do
                if not autoRunning or not ScreenGui.Parent then break end
                if not phase:find("tebakan") then
                    for _, q in ipairs(list) do
                        if not autoRunning or not ScreenGui.Parent then break end
                        fireAsk(q); addLog("📤 [ASK] " .. q); task.wait(ASK_DELAY)
                    end
                end
            end
            autoRunning = false
            if ScreenGui.Parent then StatusLabel2.Text = "Mode: Selesai" end
        end)
    end},
    { text = "⏹ Stop", width = 60, color = Color3.fromRGB(120, 40, 40), callback = function() autoRunning = false end}
})

makeSection("✅ QUICK ANSWER")
makeButtonRow({
    { text = "Ya", width = 60, color = Color3.fromRGB(30, 110, 50), callback = function() fireAnswer("Yes"); addLog("📤 Yes") end},
    { text = "Tidak", width = 60, color = Color3.fromRGB(110, 30, 30), callback = function() fireAnswer("No"); addLog("📤 No") end},
    { text = "Bisa Jadi", width = 80, color = Color3.fromRGB(100, 80, 20), callback = function() fireAnswer("Maybe"); addLog("📤 Maybe") end}
})

makeSection("✏️ CUSTOM")
local InputBox = Instance.new("TextBox")
InputBox.Size = UDim2.new(1, 0, 0, 28)
InputBox.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
InputBox.BorderSizePixel = 0
InputBox.Text = ""
InputBox.PlaceholderText = "Ketik disini..."
InputBox.TextColor3 = Color3.fromRGB(220, 210, 255)
InputBox.Font = Enum.Font.Code
InputBox.TextSize = 11
InputBox.LayoutOrder = nextOrder()
InputBox.Parent = ContentFrame
Instance.new("UICorner", InputBox).CornerRadius = UDim.new(0, 6)

makeButtonRow({
    { text = "Kirim Tanya", width = 100, color = Color3.fromRGB(80, 50, 140), callback = function() fireAsk(InputBox.Text); addLog("📤 " .. InputBox.Text); InputBox.Text = "" end},
    { text = "Kirim Jawab", width = 100, color = Color3.fromRGB(50, 100, 60), callback = function() fireAnswer(InputBox.Text); addLog("📩 " .. InputBox.Text); InputBox.Text = "" end}
})

makeSection("📋 LOG")
local LogContainer = Instance.new("Frame")
LogContainer.Size = UDim2.new(1, 0, 0, 100)
LogContainer.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
LogContainer.LayoutOrder = nextOrder()
LogContainer.Parent = ContentFrame
Instance.new("UICorner", LogContainer).CornerRadius = UDim.new(0, 6)

local LogScroll = Instance.new("ScrollingFrame")
LogScroll.Size = UDim2.new(1, 0, 1, 0)
LogScroll.BackgroundTransparency = 1
LogScroll.CanvasSize = UDim2.new(0,0,0,0)
LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogScroll.Parent = LogContainer
_G.LogScroll = LogScroll

local LogLayout = Instance.new("UIListLayout")
LogLayout.SortOrder = Enum.SortOrder.LayoutOrder
LogLayout.Parent = LogScroll

-- ============================================================
-- STARTUP
-- ============================================================
addLog("🎯 Tebak Yuk! Helper v1.1 Loaded", Color3.fromRGB(80, 255, 150))

CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
MinBtn.MouseButton1Click:Connect(function() ContentFrame.Visible = not ContentFrame.Visible; MainFrame.Size = ContentFrame.Visible and UDim2.new(0, FRAME_W, 0, FRAME_H) or UDim2.new(0, FRAME_W, 0, TOPBAR_H) end)
