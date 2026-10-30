--[[
    ═══════════════════════════════════════════════════════════════
    SOCIETY HUB  —  The Lost Front
    Вкладки: Aim & Combat | ESP | Visuals
    Executors: Xeno, Delta, Wave, Solara, Synapse (Drawing API)
    ═══════════════════════════════════════════════════════════════
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

--==================== КОНФИГ ====================--
local Config = {
    -- Aim & Combat
    TriggerBot        = false,
    TriggerDelay      = 0.05,
    AimAssist         = false,
    AimFOV            = 120,
    AimSmooth         = 0.25,
    AimPart           = "Head",       -- "Head" / "HumanoidRootPart"
    TeamCheck         = true,

    -- ESP
    ESP_Enabled       = true,
    ESP_Boxes         = true,
    ESP_Names         = true,
    ESP_Health        = true,
    ESP_Distance      = true,
    ESP_Tracers       = false,
    ESP_MaxDist       = 2000,

    -- Visuals
    Fullbright        = false,
    NoFog             = false,
    PotatoGraphics    = false,        -- низкое качество / «картошка»
}
--================================================--

--==================== DRAWING SETUP ====================--
local espObjects = {}

local function createESP(plr)
    if plr == LocalPlayer or espObjects[plr] then return end
    local set = {}

    set.Box = Drawing.new("Square")
    set.Box.Thickness = 1
    set.Box.Filled = false
    set.Box.Color = Color3.fromRGB(255, 60, 60)
    set.Box.Visible = false

    set.Name = Drawing.new("Text")
    set.Name.Center = true
    set.Name.Outline = true
    set.Name.Size = 14
    set.Name.Color = Color3.fromRGB(255, 255, 255)
    set.Name.Visible = false

    set.HealthBg = Drawing.new("Square")
    set.HealthBg.Filled = true
    set.HealthBg.Color = Color3.fromRGB(0, 0, 0)
    set.HealthBg.Visible = false

    set.Health = Drawing.new("Square")
    set.Health.Filled = true
    set.Health.Color = Color3.fromRGB(0, 255, 0)
    set.Health.Visible = false

    set.Dist = Drawing.new("Text")
    set.Dist.Center = true
    set.Dist.Outline = true
    set.Dist.Size = 12
    set.Dist.Color = Color3.fromRGB(200, 200, 200)
    set.Dist.Visible = false

    set.Tracer = Drawing.new("Line")
    set.Tracer.Thickness = 1
    set.Tracer.Color = Color3.fromRGB(255, 60, 60)
    set.Tracer.Visible = false

    espObjects[plr] = set
end

local function removeESP(plr)
    local set = espObjects[plr]
    if not set then return end
    for _, obj in pairs(set) do
        if typeof(obj) == "Drawing" then obj:Remove() end
    end
    espObjects[plr] = nil
end

for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)
--================================================--

--==================== AIM & COMBAT ====================--
local function getTarget()
    local closest, minDist = nil, Config.AimFOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if Config.TeamCheck and plr.Team and plr.Team == LocalPlayer.Team then continue end

        local char = plr.Character
        if not char then continue end
        local part = char:FindFirstChild(Config.AimPart) or char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not part or not hum or hum.Health <= 0 then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
        if dist < minDist then
            minDist = dist
            closest = part
        end
    end
    return closest
end

-- Trigger Bot: авто-клик, когда враг в прицеле
local triggerCooldown = 0
RunService.RenderStepped:Connect(function(dt)
    if not Config.TriggerBot then return end
    triggerCooldown = triggerCooldown - dt
    if triggerCooldown > 0 then return end

    local target = getTarget()
    if target then
        local screenPos, onScreen = Camera:WorldToViewportPoint(target.Position)
        if onScreen then
            local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
            if dist < 15 then
                mouse1click()
                triggerCooldown = Config.TriggerDelay
            end
        end
    end
end)

-- Aim Assist: плавное наведение на цель
RunService.RenderStepped:Connect(function(dt)
    if not Config.AimAssist then return end
    local target = getTarget()
    if not target then return end

    local targetPos = target.Position
    local currentCF = Camera.CFrame
    local desiredCF = CFrame.lookAt(currentCF.Position, targetPos)
    Camera.CFrame = currentCF:Lerp(desiredCF, Config.AimSmooth)
end)
--================================================--

--==================== ESP ====================--
RunService.RenderStepped:Connect(function()
    for plr, set in pairs(espObjects) do
        if not Config.ESP_Enabled then
            for _, obj in pairs(set) do obj.Visible = false end
            continue
        end

        local char = plr.Character
        if not char then
            for _, obj in pairs(set) do obj.Visible = false end
            continue
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then
            for _, obj in pairs(set) do obj.Visible = false end
            continue
        end

        if Config.TeamCheck and plr.Team and plr.Team == LocalPlayer.Team then
            for _, obj in pairs(set) do obj.Visible = false end
            continue
        end

        local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        if not onScreen then
            for _, obj in pairs(set) do obj.Visible = false end
            continue
        end

        local distance = (Camera.CFrame.Position - hrp.Position).Magnitude
        if distance > Config.ESP_MaxDist then
            for _, obj in pairs(set) do obj.Visible = false end
            continue
        end

        local scale = math.clamp(1000 / distance, 0.7, 2.5)
        local h = 80 * scale
        local w = 45 * scale
        local x, y = pos.X - w/2, pos.Y - h/2

        -- Box
        set.Box.Visible = Config.ESP_Boxes
        if Config.ESP_Boxes then
            set.Box.Size = Vector2.new(w, h)
            set.Box.Position = Vector2.new(x, y)
        end

        -- Name
        set.Name.Visible = Config.ESP_Names
        if Config.ESP_Names then
            set.Name.Text = plr.Name
            set.Name.Position = Vector2.new(pos.X, y - 18)
        end

        -- Health
        set.HealthBg.Visible = Config.ESP_Health
        set.Health.Visible = Config.ESP_Health
        if Config.ESP_Health then
            local frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local bw = 4 * scale
            set.HealthBg.Size = Vector2.new(bw, h)
            set.HealthBg.Position = Vector2.new(x - bw - 4, y)
            set.Health.Size = Vector2.new(bw, h * frac)
            set.Health.Position = Vector2.new(x - bw - 4, y + h * (1 - frac))
        end

        -- Distance
        set.Dist.Visible = Config.ESP_Distance
        if Config.ESP_Distance then
            set.Dist.Text = math.floor(distance) .. "m"
            set.Dist.Position = Vector2.new(pos.X, y + h + 4)
        end

        -- Tracer
        set.Tracer.Visible = Config.ESP_Tracers
        if Config.ESP_Tracers then
            set.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            set.Tracer.To = Vector2.new(pos.X, pos.Y)
        end
    end
end)
--================================================--

--==================== VISUALS ====================--
local originalFogEnd = Lighting.FogEnd
local originalBrightness = Lighting.Brightness
local originalAmbient = Lighting.Ambient

local function applyFullbright(state)
    if state then
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.FogEnd = 100000
    else
        Lighting.Brightness = originalBrightness
        Lighting.Ambient = originalAmbient
        Lighting.FogEnd = originalFogEnd
    end
end

local function applyNoFog(state)
    if state then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
    else
        Lighting.FogEnd = originalFogEnd
    end
end

local function applyPotato(state)
    if state then
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        Lighting.GlobalShadows = false
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") then
                v.Enabled = false
            end
        end
    else
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level10
        Lighting.GlobalShadows = true
    end
end

-- отслеживаем изменения конфига
local lastVisualState = {}
RunService.Heartbeat:Connect(function()
    if lastVisualState.Fullbright ~= Config.Fullbright then
        lastVisualState.Fullbright = Config.Fullbright
        applyFullbright(Config.Fullbright)
    end
    if lastVisualState.NoFog ~= Config.NoFog then
        lastVisualState.NoFog = Config.NoFog
        applyNoFog(Config.NoFog)
    end
    if lastVisualState.Potato ~= Config.PotatoGraphics then
        lastVisualState.Potato = Config.PotatoGraphics
        applyPotato(Config.PotatoGraphics)
    end
end)
--================================================--

--==================== МЕНЮ (ScreenGui) ====================--
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SocietyHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 420, 0, 320)
Main.Position = UDim2.new(0.5, -210, 0.5, -160)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 32)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.BorderSizePixel = 0
Title.Text = "  society hub  |  The Lost Front"
Title.TextColor3 = Color3.fromRGB(220, 220, 220)
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Main

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 30)
TabBar.Position = UDim2.new(0, 0, 0, 32)
TabBar.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
TabBar.BorderSizePixel = 0
TabBar.Parent = Main

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -16, 1, -78)
Content.Position = UDim2.new(0, 8, 0, 66)
Content.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
Content.BorderSizePixel = 0
Content.Parent = Main

local function makeTab(name, xOffset)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 130, 1, 0)
    btn.Position = UDim2.new(0, xOffset, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = TabBar
    return btn
end

local tabAim = makeTab("Aim & Combat", 0)
local tabESP = makeTab("ESP", 130)
local tabVisual = makeTab("Visuals", 260)

local pages = {}
local function newPage(name)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = false
    frame.Parent = Content
    pages[name] = frame
    return frame
end

local pageAim = newPage("Aim")
local pageESP = newPage("ESP")
local pageVisual = newPage("Visuals")

local function showPage(name)
    for n, f in pairs(pages) do f.Visible = (n == name) end
    tabAim.BackgroundColor3 = name == "Aim" and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(30, 30, 30)
    tabESP.BackgroundColor3 = name == "ESP" and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(30, 30, 30)
    tabVisual.BackgroundColor3 = name == "Visuals" and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(30, 30, 30)
end

tabAim.MouseButton1Click:Connect(function() showPage("Aim") end)
tabESP.MouseButton1Click:Connect(function() showPage("ESP") end)
tabVisual.MouseButton1Click:Connect(function() showPage("Visuals") end)

-- helper: строка с переключателем
local function addToggle(parent, text, key, y)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 28)
    row.Position = UDim2.new(0, 0, 0, y)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 200, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 60, 0, 22)
    btn.Position = UDim2.new(1, -70, 0, 3)
    btn.BackgroundColor3 = Config[key] and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(60, 60, 60)
    btn.BorderSizePixel = 0
    btn.Text = Config[key] and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.Parent = row

    btn.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        btn.Text = Config[key] and "ON" or "OFF"
        btn.BackgroundColor3 = Config[key] and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(60, 60, 60)
    end)
end

-- Aim & Combat
addToggle(pageAim, "Trigger Bot", "TriggerBot", 5)
addToggle(pageAim, "Aim Assist", "AimAssist", 40)
addToggle(pageAim, "Team Check", "TeamCheck", 75)

-- ESP
addToggle(pageESP, "ESP Enabled", "ESP_Enabled", 5)
addToggle(pageESP, "Boxes", "ESP_Boxes", 40)
addToggle(pageESP, "Names", "ESP_Names", 75)
addToggle(pageESP, "Health Bars", "ESP_Health", 110)
addToggle(pageESP, "Distance", "ESP_Distance", 145)
addToggle(pageESP, "Tracers", "ESP_Tracers", 180)

-- Visuals
addToggle(pageVisual, "Fullbright", "Fullbright", 5)
addToggle(pageVisual, "No Fog", "NoFog", 40)
addToggle(pageVisual, "Potato Graphics", "PotatoGraphics", 75)

showPage("Aim")

-- Закрытие по INSERT
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        Main.Visible = not Main.Visible
    end
end)
--================================================--
