-- ============================================================
-- Tebak Yuk! Smart Helper v1.0
-- For Delta Executor
-- Features: Auto Ask, Quick Categories, Smart Guesser,
--           Answer Buttons, Custom Input, Activity Log
-- ============================================================

local CoreGui   = game:GetService("CoreGui")
local Players   = game:GetService("Players")
local RS        = game:GetService("ReplicatedStorage")
local UIS       = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================
-- CONFIG
-- ============================================================
local ASK_DELAY         = 1.8    -- delay antar pertanyaan (detik)
local ANSWER_DELAY      = 0.8    -- delay antar jawaban
local MAX_LOGS          = 50
local FRAME_W, FRAME_H  = 360, 420

-- ============================================================
-- SETUP GUI
-- ============================================================
local guiName = "TebakYukHelper_v1"
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
    -- Cari berdasarkan nama di seluruh game
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local name = obj.Name:lower()
            if name == "askquestion" or name == "ask_question" or name == "ask" then
                remoteAsk = obj
            elseif name == "sendanswer" or name == "send_answer" or name == "answer" then
                remoteSend = obj
            end
        end
        if remoteAsk and remoteSend then break end
    end
end

findRemotes()

-- ============================================================
-- SMART QUESTION DATABASE
-- ============================================================
local questionTree = {
    -- FASE 1: Kategori utama
    kategori = {
        "Apakah ini Hewan?",
        "Apakah ini Benda?",
        "Apakah ini Makanan?",
        "Apakah ini Tempat?",
        "Apakah ini Orang/Tokoh?",
        "Apakah ini Tumbuhan?",
    },

    -- FASE 2: Sub-kategori berdasarkan kategori
    hewan = {
        "Apakah hewan ini berkaki 4?",
        "Apakah hewan ini bisa terbang?",
        "Apakah hewan ini hidup di air?",
        "Apakah hewan ini berbulu?",
        "Apakah hewan ini peliharaan?",
        "Apakah hewan ini buas?",
        "Apakah hewan ini ada di Indonesia?",
        "Apakah hewan ini besar?",
        "Apakah hewan ini berwarna putih?",
        "Apakah hewan ini herbivora?",
    },
    benda = {
        "Apakah benda ini ada di rumah?",
        "Apakah benda ini elektronik?",
        "Apakah benda ini bisa dipegang?",
        "Apakah benda ini terbuat dari logam?",
        "Apakah benda ini ada di sekolah?",
        "Apakah benda ini mahal?",
        "Apakah benda ini dipakai sehari-hari?",
        "Apakah benda ini kecil?",
        "Apakah benda ini berwarna?",
        "Apakah benda ini bentuknya kotak?",
    },
    makanan = {
        "Apakah makanan ini manis?",
        "Apakah makanan ini pedas?",
        "Apakah makanan ini dari Indonesia?",
        "Apakah makanan ini berwarna merah?",
        "Apakah makanan ini berwarna kuning?",
        "Apakah makanan ini berwarna hijau?",
        "Apakah makanan ini berwarna coklat?",
        "Apakah makanan ini buah?",
        "Apakah makanan ini sayur?",
        "Apakah makanan ini digoreng?",
        "Apakah makanan ini berkuah?",
        "Apakah makanan ini dari beras?",
    },
    tempat = {
        "Apakah tempat ini di Indonesia?",
        "Apakah tempat ini di Asia?",
        "Apakah tempat ini kota?",
        "Apakah tempat ini ada pantainya?",
        "Apakah tempat ini terkenal?",
        "Apakah tempat ini ada gunungnya?",
        "Apakah tempat ini di pulau Jawa?",
        "Apakah tempat ini destinasi wisata?",
    },
    orang = {
        "Apakah orang ini YouTuber?",
        "Apakah orang ini dari Indonesia?",
        "Apakah orang ini laki-laki?",
        "Apakah orang ini masih hidup?",
        "Apakah orang ini terkenal di internet?",
        "Apakah orang ini penyanyi?",
        "Apakah orang ini atlet?",
        "Apakah orang ini aktor/aktris?",
        "Apakah orang ini politikus?",
        "Apakah orang ini tokoh fiksi?",
    },
    tumbuhan = {
        "Apakah tumbuhan ini berbuah?",
        "Apakah tumbuhan ini berbunga?",
        "Apakah tumbuhan ini besar (pohon)?",
        "Apakah tumbuhan ini bisa dimakan?",
        "Apakah tumbuhan ini berduri?",
        "Apakah tumbuhan ini tropis?",
        "Apakah tumbuhan ini ada di kebun?",
        "Apakah tumbuhan ini berwarna hijau?",
    },

    -- FASE 3: Tebakan spesifik per kategori
    tebakan_hewan = {
        "Kucing?", "Anjing?", "Kelinci?", "Hamster?", "Burung?",
        "Ikan?", "Kuda?", "Sapi?", "Kambing?", "Ayam?",
        "Harimau?", "Singa?", "Gajah?", "Jerapah?", "Monyet?",
        "Ular?", "Buaya?", "Penyu?", "Lumba-lumba?", "Paus?",
        "Kupu-kupu?", "Lebah?", "Semut?", "Laba-laba?", "Elang?",
    },
    tebakan_makanan = {
        "Nasi Goreng?", "Mie Goreng?", "Sate?", "Rendang?", "Bakso?",
        "Soto?", "Gado-gado?", "Pizza?", "Burger?", "Roti?",
        "Apel?", "Jeruk?", "Mangga?", "Pisang?", "Semangka?",
        "Durian?", "Alpukat?", "Anggur?", "Strawberry?", "Melon?",
        "Coklat?", "Es Krim?", "Keripik?", "Permen?", "Donat?",
    },
    tebakan_benda = {
        "HP/Handphone?", "Laptop?", "TV?", "Meja?", "Kursi?",
        "Buku?", "Pensil?", "Tas?", "Sepatu?", "Bola?",
        "Jam?", "Kunci?", "Cermin?", "Lampu?", "AC?",
        "Kulkas?", "Komputer?", "Headset?", "Kamera?", "Payung?",
    },
    tebakan_tempat = {
        "Jakarta?", "Bali?", "Bandung?", "Yogyakarta?", "Surabaya?",
        "Malang?", "Semarang?", "Medan?", "Makassar?", "Solo?",
        "Paris?", "Tokyo?", "New York?", "London?", "Dubai?",
        "Korea?", "Thailand?", "Malaysia?", "Singapura?", "Australia?",
    },
    tebakan_orang = {
        "Jokowi?", "Windah Basudara?", "Atta Halilintar?", "Ria Ricis?",
        "Baim Wong?", "Raffi Ahmad?", "Deddy Corbuzier?", "Jerome Polin?",
        "Tanboy Kun?", "MiawAug?", "Frost Diamond?", "Jess No Limit?",
        "Elon Musk?", "Cristiano Ronaldo?", "Lionel Messi?",
        "BTS?", "Blackpink?", "Taylor Swift?", "Naruto?", "Goku?",
    },
}

-- ============================================================
-- UTILITY
-- ============================================================
local function fireAsk(question)
    if remoteAsk then
        if remoteAsk:IsA("RemoteEvent") then
            remoteAsk:FireServer(question)
        elseif remoteAsk:IsA("RemoteFunction") then
            pcall(function() remoteAsk:InvokeServer(question) end)
        end
        return true
    end
    return false
end

local function fireAnswer(answer)
    if remoteSend then
        if remoteSend:IsA("RemoteEvent") then
            remoteSend:FireServer(answer)
        elseif remoteSend:IsA("RemoteFunction") then
            pcall(function() remoteSend:InvokeServer(answer) end)
        end
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

-- Shadow
local Shadow = Instance.new("ImageLabel")
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

-- Dot ungu
local Dot = Instance.new("Frame")
Dot.Size = UDim2.new(0, 7, 0, 7)
Dot.Position = UDim2.new(0, 10, 0.5, -3)
Dot.BackgroundColor3 = Color3.fromRGB(160, 80, 255)
Dot.BorderSizePixel = 0
Dot.Parent = TopBar
Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)

-- Pulse
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
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 24, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🎯 Tebak Yuk! Helper"
Title.TextColor3 = Color3.fromRGB(200, 170, 255)
Title.Font = Enum.Font.Code
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

-- Buttons
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
-- DRAG LOGIC + CLAMP
-- ============================================================
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil

local function clampPosition(pos)
    local vpSize = Camera.ViewportSize
    local maxX = vpSize.X - MainFrame.AbsoluteSize.X
    local maxY = vpSize.Y - MainFrame.AbsoluteSize.Y
    local x = math.clamp(pos.X.Offset, 0, math.max(0, maxX))
    local y = math.clamp(pos.Y.Offset, 0, math.max(0, maxY))
    return UDim2.new(0, x, 0, y)
end

TopBar.InputBegan:Connect(function(input)
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
        dragging = true
        dragInput = input
        dragStart = input.Position
        startPos = UDim2.new(0, MainFrame.AbsolutePosition.X, 0, MainFrame.AbsolutePosition.Y)
    end
end)

TopBar.InputEnded:Connect(function(input)
    if input == dragInput then dragging = false; dragInput = nil end
end)

UIS.InputChanged:Connect(function(input)
    local t = input.UserInputType
    if (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) and dragging and dragStart then
        local delta = input.Position - dragStart
        MainFrame.Position = clampPosition(UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y))
    end
end)

-- ============================================================
-- CONTENT AREA (ScrollingFrame)
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

-- ============================================================
-- UI BUILDERS
-- ============================================================
local layoutOrder = 0

local function nextOrder()
    layoutOrder = layoutOrder + 1
    return layoutOrder
end

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

local function makeDivider()
    local div = Instance.new("Frame")
    div.Size = UDim2.new(1, 0, 0, 1)
    div.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
    div.BorderSizePixel = 0
    div.LayoutOrder = nextOrder()
    div.Parent = ContentFrame
    return div
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

    local createdButtons = {}
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

        if bData.callback then
            btn.MouseButton1Click:Connect(bData.callback)
        end

        table.insert(createdButtons, btn)
    end

    return row, createdButtons
end

-- ============================================================
-- STATUS DISPLAY
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
StatusLabel.Text = "Remote: Searching..."
StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
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

-- Update status
local function updateRemoteStatus()
    if remoteAsk and remoteSend then
        StatusLabel.Text = "✅ Remote: Connected"
        StatusLabel.TextColor3 = Color3.fromRGB(80, 255, 150)
    elseif remoteAsk or remoteSend then
        StatusLabel.Text = "⚠ Remote: Partial (" .. (remoteAsk and "Ask✓" or "Ask✗") .. " " .. (remoteSend and "Ans✓" or "Ans✗") .. ")"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
    else
        StatusLabel.Text = "❌ Remote: Not Found"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    end
end

updateRemoteStatus()

makeDivider()

-- ============================================================
-- AUTO MODE SECTION
-- ============================================================
makeSection("🤖 AUTO MODE")

local autoRunning = false
local autoPhase = "idle"      -- idle, kategori, sub, tebak
local autoCategory = nil
local autoQuestionIndex = 0

local function setAutoStatus(text)
    StatusLabel2.Text = "Mode: " .. text
end

local _, autoBtns = makeButtonRow({
    { text = "▶ Auto Smart", width = 90, color = Color3.fromRGB(40, 120, 60), textColor = Color3.fromRGB(180, 255, 200), callback = function()
        if autoRunning then return end
        autoRunning = true
        autoPhase = "kategori"
        autoCategory = nil
        autoQuestionIndex = 1
        setAutoStatus("🤖 Auto Smart - Fase Kategori")

        task.spawn(function()
            local questions = questionTree.kategori
            -- Fase 1: Tanya kategori
            while autoRunning and autoQuestionIndex <= #questions do
                local q = questions[autoQuestionIndex]
                fireAsk(q)
                addLog("📤 [ASK] " .. q, Color3.fromRGB(180, 140, 255))
                autoQuestionIndex = autoQuestionIndex + 1
                task.wait(ASK_DELAY)
            end

            if not autoRunning then return end

            -- Fase 2: Sub-kategori (default ke makanan jika tidak ada input)
            local subKeys = {"hewan", "benda", "makanan", "tempat", "orang", "tumbuhan"}
            for _, key in ipairs(subKeys) do
                if not autoRunning then break end
                local subQ = questionTree[key]
                if subQ then
                    setAutoStatus("🤖 Sub: " .. key)
                    for _, q in ipairs(subQ) do
                        if not autoRunning then break end
                        fireAsk(q)
                        addLog("📤 [ASK] " .. q, Color3.fromRGB(180, 140, 255))
                        task.wait(ASK_DELAY)
                    end
                end
            end

            if not autoRunning then return end

            -- Fase 3: Tebakan
            local tebakanKeys = {"tebakan_hewan", "tebakan_makanan", "tebakan_benda", "tebakan_tempat", "tebakan_orang"}
            for _, key in ipairs(tebakanKeys) do
                if not autoRunning then break end
                local guesses = questionTree[key]
                if guesses then
                    setAutoStatus("🎯 Menebak: " .. key)
                    for _, g in ipairs(guesses) do
                        if not autoRunning then break end
                        fireAsk(g)
                        addLog("🎯 [GUESS] " .. g, Color3.fromRGB(255, 200, 100))
                        task.wait(ASK_DELAY)
                    end
                end
            end

            autoRunning = false
            setAutoStatus("✅ Selesai")
        end)
    end},
    { text = "⏹ Stop", width = 65, color = Color3.fromRGB(160, 40, 40), textColor = Color3.fromRGB(255, 200, 200), callback = function()
        autoRunning = false
        setAutoStatus("⏹ Stopped")
    end},
    { text = "🔄 Retry Remote", width = 100, color = Color3.fromRGB(50, 50, 80), callback = function()
        findRemotes()
        updateRemoteStatus()
        addLog("🔄 Remote search refreshed", Color3.fromRGB(150, 150, 200))
    end},
})

makeDivider()

-- ============================================================
-- AUTO ANSWER SECTION
-- ============================================================
makeSection("🗳️ AUTO ANSWER (Penjawab)")

local autoAnswering = false
local autoAnswerType = "Yes"

local _, answerAutoBtns = makeButtonRow({
    { text = "🔁 Auto Yes", width = 80, color = Color3.fromRGB(40, 100, 50), textColor = Color3.fromRGB(180, 255, 200), callback = function()
        if autoAnswering then return end
        autoAnswering = true
        autoAnswerType = "Yes"
        setAutoStatus("🔁 Auto Answer: Yes")
        task.spawn(function()
            while autoAnswering and ScreenGui.Parent do
                fireAnswer("Yes")
                addLog("📤 [ANS] Yes", Color3.fromRGB(100, 255, 130))
                task.wait(ANSWER_DELAY)
            end
        end)
    end},
    { text = "🔁 Auto No", width = 80, color = Color3.fromRGB(120, 40, 40), textColor = Color3.fromRGB(255, 200, 200), callback = function()
        if autoAnswering then return end
        autoAnswering = true
        autoAnswerType = "No"
        setAutoStatus("🔁 Auto Answer: No")
        task.spawn(function()
            while autoAnswering and ScreenGui.Parent do
                fireAnswer("No")
                addLog("📤 [ANS] No", Color3.fromRGB(255, 100, 100))
                task.wait(ANSWER_DELAY)
            end
        end)
    end},
    { text = "⏹ Stop", width = 65, color = Color3.fromRGB(80, 50, 50), textColor = Color3.fromRGB(255, 180, 180), callback = function()
        autoAnswering = false
        setAutoStatus("⏹ Auto Answer Stopped")
    end},
})

makeDivider()

-- ============================================================
-- QUICK CATEGORY ASK
-- ============================================================
makeSection("❓ QUICK ASK (Penanya)")

makeButtonRow({
    { text = "🐾 Hewan?", width = 72, color = Color3.fromRGB(50, 80, 45), textColor = Color3.fromRGB(180, 255, 180), callback = function()
        fireAsk("Apakah ini Hewan?")
        addLog("📤 Hewan?", Color3.fromRGB(180, 255, 180))
    end},
    { text = "📦 Benda?", width = 72, color = Color3.fromRGB(50, 55, 85), textColor = Color3.fromRGB(180, 200, 255), callback = function()
        fireAsk("Apakah ini Benda?")
        addLog("📤 Benda?", Color3.fromRGB(180, 200, 255))
    end},
    { text = "🍔 Makanan?", width = 82, color = Color3.fromRGB(85, 60, 30), textColor = Color3.fromRGB(255, 220, 150), callback = function()
        fireAsk("Apakah ini Makanan?")
        addLog("📤 Makanan?", Color3.fromRGB(255, 220, 150))
    end},
    { text = "📍 Tempat?", width = 72, color = Color3.fromRGB(80, 40, 40), textColor = Color3.fromRGB(255, 180, 180), callback = function()
        fireAsk("Apakah ini Tempat?")
        addLog("📤 Tempat?", Color3.fromRGB(255, 180, 180))
    end},
})

makeButtonRow({
    { text = "👤 Orang?", width = 72, color = Color3.fromRGB(60, 50, 80), textColor = Color3.fromRGB(220, 200, 255), callback = function()
        fireAsk("Apakah ini Orang/Tokoh?")
        addLog("📤 Orang?", Color3.fromRGB(220, 200, 255))
    end},
    { text = "🌿 Tumbuhan?", width = 88, color = Color3.fromRGB(35, 70, 45), textColor = Color3.fromRGB(150, 255, 170), callback = function()
        fireAsk("Apakah ini Tumbuhan?")
        addLog("📤 Tumbuhan?", Color3.fromRGB(150, 255, 170))
    end},
    { text = "🎨 Warna?", width = 72, color = Color3.fromRGB(70, 40, 70), textColor = Color3.fromRGB(255, 180, 255), callback = function()
        fireAsk("Apakah berwarna?")
        addLog("📤 Warna?", Color3.fromRGB(255, 180, 255))
    end},
})

makeDivider()

-- ============================================================
-- MANUAL ANSWER BUTTONS
-- ============================================================
makeSection("✅ QUICK ANSWER (Penjawab)")

makeButtonRow({
    { text = "✅ Ya", width = 80, color = Color3.fromRGB(30, 110, 50), textColor = Color3.fromRGB(150, 255, 180), callback = function()
        fireAnswer("Yes")
        addLog("📤 [ANS] Yes", Color3.fromRGB(100, 255, 130))
    end},
    { text = "❌ Tidak", width = 80, color = Color3.fromRGB(140, 35, 35), textColor = Color3.fromRGB(255, 180, 180), callback = function()
        fireAnswer("No")
        addLog("📤 [ANS] No", Color3.fromRGB(255, 100, 100))
    end},
    { text = "🤔 Bisa Jadi", width = 90, color = Color3.fromRGB(100, 80, 20), textColor = Color3.fromRGB(255, 240, 150), callback = function()
        fireAnswer("Maybe")
        addLog("📤 [ANS] Maybe", Color3.fromRGB(255, 240, 100))
    end},
})

makeDivider()

-- ============================================================
-- CUSTOM INPUT
-- ============================================================
makeSection("✏️ CUSTOM INPUT")

local InputRow = Instance.new("Frame")
InputRow.Size = UDim2.new(1, 0, 0, 30)
InputRow.BackgroundTransparency = 1
InputRow.LayoutOrder = nextOrder()
InputRow.Parent = ContentFrame

local InputBox = Instance.new("TextBox")
InputBox.Size = UDim2.new(1, -120, 0, 28)
InputBox.Position = UDim2.new(0, 0, 0, 0)
InputBox.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
InputBox.BorderSizePixel = 0
InputBox.Text = ""
InputBox.PlaceholderText = "Ketik pertanyaan/tebakan..."
InputBox.PlaceholderColor3 = Color3.fromRGB(80, 70, 100)
InputBox.TextColor3 = Color3.fromRGB(220, 210, 255)
InputBox.Font = Enum.Font.Code
InputBox.TextSize = 11
InputBox.TextXAlignment = Enum.TextXAlignment.Left
InputBox.ClearTextOnFocus = false
InputBox.Parent = InputRow
Instance.new("UICorner", InputBox).CornerRadius = UDim.new(0, 6)

local InputPad = Instance.new("UIPadding")
InputPad.PaddingLeft = UDim.new(0, 8)
InputPad.Parent = InputBox

local SendAskBtn = Instance.new("TextButton")
SendAskBtn.Size = UDim2.new(0, 54, 0, 28)
SendAskBtn.Position = UDim2.new(1, -112, 0, 0)
SendAskBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 140)
SendAskBtn.BorderSizePixel = 0
SendAskBtn.Text = "📤 Ask"
SendAskBtn.TextColor3 = Color3.fromRGB(220, 200, 255)
SendAskBtn.Font = Enum.Font.GothamBold
SendAskBtn.TextSize = 10
SendAskBtn.AutoButtonColor = true
SendAskBtn.Parent = InputRow
Instance.new("UICorner", SendAskBtn).CornerRadius = UDim.new(0, 6)

local SendAnsBtn = Instance.new("TextButton")
SendAnsBtn.Size = UDim2.new(0, 54, 0, 28)
SendAnsBtn.Position = UDim2.new(1, -54, 0, 0)
SendAnsBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 60)
SendAnsBtn.BorderSizePixel = 0
SendAnsBtn.Text = "📩 Ans"
SendAnsBtn.TextColor3 = Color3.fromRGB(200, 255, 210)
SendAnsBtn.Font = Enum.Font.GothamBold
SendAnsBtn.TextSize = 10
SendAnsBtn.AutoButtonColor = true
SendAnsBtn.Parent = InputRow
Instance.new("UICorner", SendAnsBtn).CornerRadius = UDim.new(0, 6)

SendAskBtn.MouseButton1Click:Connect(function()
    local text = InputBox.Text
    if text and text ~= "" then
        fireAsk(text)
        addLog("📤 [ASK] " .. text, Color3.fromRGB(180, 140, 255))
        InputBox.Text = ""
    end
end)

SendAnsBtn.MouseButton1Click:Connect(function()
    local text = InputBox.Text
    if text and text ~= "" then
        fireAnswer(text)
        addLog("📤 [ANS] " .. text, Color3.fromRGB(100, 255, 130))
        InputBox.Text = ""
    end
end)

makeDivider()

-- ============================================================
-- DELAY SETTINGS
-- ============================================================
makeSection("⚙️ SETTINGS")

local SettingsRow = Instance.new("Frame")
SettingsRow.Size = UDim2.new(1, 0, 0, 26)
SettingsRow.BackgroundTransparency = 1
SettingsRow.LayoutOrder = nextOrder()
SettingsRow.Parent = ContentFrame

local DelayLabel = Instance.new("TextLabel")
DelayLabel.Size = UDim2.new(0, 80, 0, 24)
DelayLabel.BackgroundTransparency = 1
DelayLabel.Text = "Ask Delay:"
DelayLabel.TextColor3 = Color3.fromRGB(160, 150, 200)
DelayLabel.Font = Enum.Font.Code
DelayLabel.TextSize = 10
DelayLabel.TextXAlignment = Enum.TextXAlignment.Left
DelayLabel.Parent = SettingsRow

local DelayInput = Instance.new("TextBox")
DelayInput.Size = UDim2.new(0, 50, 0, 22)
DelayInput.Position = UDim2.new(0, 80, 0, 1)
DelayInput.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
DelayInput.BorderSizePixel = 0
DelayInput.Text = tostring(ASK_DELAY)
DelayInput.TextColor3 = Color3.fromRGB(255, 200, 100)
DelayInput.Font = Enum.Font.Code
DelayInput.TextSize = 11
DelayInput.Parent = SettingsRow
Instance.new("UICorner", DelayInput).CornerRadius = UDim.new(0, 4)

local DelayUnit = Instance.new("TextLabel")
DelayUnit.Size = UDim2.new(0, 20, 0, 24)
DelayUnit.Position = UDim2.new(0, 134, 0, 0)
DelayUnit.BackgroundTransparency = 1
DelayUnit.Text = "s"
DelayUnit.TextColor3 = Color3.fromRGB(120, 110, 150)
DelayUnit.Font = Enum.Font.Code
DelayUnit.TextSize = 10
DelayUnit.TextXAlignment = Enum.TextXAlignment.Left
DelayUnit.Parent = SettingsRow

DelayInput.FocusLost:Connect(function()
    local val = tonumber(DelayInput.Text)
    if val and val >= 0.3 and val <= 10 then
        ASK_DELAY = val
        addLog("⚙️ Delay set to " .. val .. "s", Color3.fromRGB(150, 150, 200))
    else
        DelayInput.Text = tostring(ASK_DELAY)
        addLog("⚠ Invalid delay (0.3-10s)", Color3.fromRGB(255, 120, 80))
    end
end)

-- Answer delay
local ADelayLabel = Instance.new("TextLabel")
ADelayLabel.Size = UDim2.new(0, 80, 0, 24)
ADelayLabel.Position = UDim2.new(0, 170, 0, 0)
ADelayLabel.BackgroundTransparency = 1
ADelayLabel.Text = "Ans Delay:"
ADelayLabel.TextColor3 = Color3.fromRGB(160, 150, 200)
ADelayLabel.Font = Enum.Font.Code
ADelayLabel.TextSize = 10
ADelayLabel.TextXAlignment = Enum.TextXAlignment.Left
ADelayLabel.Parent = SettingsRow

local ADelayInput = Instance.new("TextBox")
ADelayInput.Size = UDim2.new(0, 50, 0, 22)
ADelayInput.Position = UDim2.new(0, 248, 0, 1)
ADelayInput.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
ADelayInput.BorderSizePixel = 0
ADelayInput.Text = tostring(ANSWER_DELAY)
ADelayInput.TextColor3 = Color3.fromRGB(255, 200, 100)
ADelayInput.Font = Enum.Font.Code
ADelayInput.TextSize = 11
ADelayInput.Parent = SettingsRow
Instance.new("UICorner", ADelayInput).CornerRadius = UDim.new(0, 4)

ADelayInput.FocusLost:Connect(function()
    local val = tonumber(ADelayInput.Text)
    if val and val >= 0.3 and val <= 10 then
        ANSWER_DELAY = val
        addLog("⚙️ Answer delay set to " .. val .. "s", Color3.fromRGB(150, 150, 200))
    else
        ADelayInput.Text = tostring(ANSWER_DELAY)
    end
end)

makeDivider()

-- ============================================================
-- ACTIVITY LOG
-- ============================================================
makeSection("📋 LOG")

local LogContainer = Instance.new("Frame")
LogContainer.Size = UDim2.new(1, 0, 0, 120)
LogContainer.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
LogContainer.BorderSizePixel = 0
LogContainer.LayoutOrder = nextOrder()
LogContainer.ClipsDescendants = true
LogContainer.Parent = ContentFrame
Instance.new("UICorner", LogContainer).CornerRadius = UDim.new(0, 6)

local LogScroll = Instance.new("ScrollingFrame")
LogScroll.Size = UDim2.new(1, 0, 1, 0)
LogScroll.BackgroundTransparency = 1
LogScroll.ScrollBarThickness = 2
LogScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 60, 180)
LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogScroll.Parent = LogContainer

local LogLayout = Instance.new("UIListLayout")
LogLayout.SortOrder = Enum.SortOrder.LayoutOrder
LogLayout.Padding = UDim.new(0, 1)
LogLayout.Parent = LogScroll

local LogPad = Instance.new("UIPadding")
LogPad.PaddingLeft = UDim.new(0, 4)
LogPad.PaddingRight = UDim.new(0, 4)
LogPad.PaddingTop = UDim.new(0, 3)
LogPad.Parent = LogScroll

local logOrder2 = 0

function addLog(text, color)
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
    msg.Parent = LogScroll

    -- Limit logs
    local children = LogScroll:GetChildren()
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
        LogScroll.CanvasPosition = Vector2.new(0, math.huge)
    end)
end

-- ============================================================
-- MINIMIZE & CLOSE
-- ============================================================
local minimized = false

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        MainFrame.Size = UDim2.new(0, FRAME_W, 0, TOPBAR_H)
        ContentFrame.Visible = false
        MinBtn.Text = "+"
    else
        MainFrame.Size = UDim2.new(0, FRAME_W, 0, FRAME_H)
        ContentFrame.Visible = true
        MinBtn.Text = "−"
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    autoRunning = false
    autoAnswering = false
    ScreenGui:Destroy()
end)

-- ============================================================
-- STARTUP
-- ============================================================
addLog("🎯 Tebak Yuk! Helper v1.0 loaded!", Color3.fromRGB(80, 255, 150))

if remoteAsk then
    addLog("✅ AskQuestion remote found: " .. remoteAsk:GetFullName(), Color3.fromRGB(100, 255, 200))
else
    addLog("⚠ AskQuestion remote not found", Color3.fromRGB(255, 120, 80))
end

if remoteSend then
    addLog("✅ SendAnswer remote found: " .. remoteSend:GetFullName(), Color3.fromRGB(100, 255, 200))
else
    addLog("⚠ SendAnswer remote not found", Color3.fromRGB(255, 120, 80))
end

addLog("💡 Klik 🔄 Retry Remote jika remote belum ditemukan", Color3.fromRGB(180, 180, 220))
addLog("📱 Game: " .. tostring(game.PlaceId), Color3.fromRGB(140, 140, 180))
