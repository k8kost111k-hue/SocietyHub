local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Идентификаторы штанов для определения команд в The Lost Front
local ATTACKER_PANTS_ID = "71322661859196"
local DEFENDER_PANTS_ID = "82267040223924"

local Config = {
    -- ESP / Chams
    ESP_Enabled = true,
    ESP_Boxes = true,
    ESP_Names = true,
    ESP_Health = true,
    ESP_Distance = true,
    ESP_Tracers = false,
    ESP_Chams = true,
    ChamsFillTransparency = 0.5,
    ChamsOutlineTransparency = 0,
    ESP_TeamCheck = true,
    ESP_MaxDist = 2000,
    AttackerColor = Color3.fromRGB(255, 50, 50),
    DefenderColor = Color3.fromRGB(50, 150, 255),

    -- Aimbot
    Aim_Enabled = false,
    Aim_FOV = 150,
    Aim_Smooth = 0.25,
    Aim_ShowFOV = true,
    Aim_TeamCheck = true,
    Aim_Part = "Head",

    -- Triggerbot
    Trigger_Enabled = false,
    Trigger_Delay = 0.05
}

-- Служебные таблицы для отслеживания соединений и Drawing-объектов
local connections = {}
local drawings = {}
local espCache = {}
local fovCircle = nil
local triggerCooldown = 0
local safeContainer = Instance.new("Folder")
safeContainer.Name = "SH_Container_" .. math.random(1000, 9999)
safeContainer.Parent = CoreGui

local function addConn(service, event, func)
    local conn = service[event]:Connect(func)
    table.insert(connections, conn)
    return conn
end

local function newDrawing(kind, props)
    local obj = Drawing.new(kind)
    for k, v in pairs(props) do obj[k] = v end
    table.insert(drawings, obj)
    return obj
end

-- Получение цвета и названия команды по штанам персонажа
local function GetTeamInfo(character)
    if not character then return Color3.new(1, 1, 1), "Unknown" end
    local pants = character:FindFirstChildWhichIsA("Pants")
    if pants then
        local template = tostring(pants.PantsTemplate)
        if string.find(template, ATTACKER_PANTS_ID) then
            return Config.AttackerColor, "Attackers"
        elseif string.find(template, DEFENDER_PANTS_ID) then
            return Config.DefenderColor, "Defenders"
        end
    end
    return Color3.new(1, 1, 1), "Lobby"
end

-- Создание кэша Drawing-объектов для ESP
local function createESP(player)
    if player == LocalPlayer or espCache[player] then return end
    local cache = {}
    cache.Box = newDrawing("Square", {Thickness = 1, Filled = false, Visible = false})
    cache.NameText = newDrawing("Text", {Center = true, Outline = true, Size = 13, Visible = false})
    cache.DistanceText = newDrawing("Text", {Center = true, Outline = true, Size = 13, Visible = false})
    cache.HP_BG = newDrawing("Square", {Filled = true, Color = Color3.new(0, 0, 0), Transparency = 0.5, Visible = false})
    cache.HP_Bar = newDrawing("Square", {Filled = true, Color = Color3.new(0, 1, 0), Visible = false})
    cache.Tracer = newDrawing("Line", {Thickness = 1, Visible = false})
    espCache[player] = cache
end

local function removeESP(player)
    local cache = espCache[player]
    if not cache then return end
    for _, obj in pairs(cache) do
        if typeof(obj) == "Drawing" then obj:Remove() end
    end
    if cache.Highlight then cache.Highlight:Destroy() end
    espCache[player] = nil
end

-- Обновление Highlight (Chams)
local function updateChams(player, character, color)
    local cache = espCache[player]
    if not cache then return end
    local highlight = cache.Highlight
    if highlight and highlight.Adornee == character then
        highlight.FillColor = color
        highlight.OutlineColor = color
        highlight.Enabled = (Config.ESP_Chams and Config.ESP_Enabled)
        highlight.FillTransparency = Config.ChamsFillTransparency
        highlight.OutlineTransparency = Config.ChamsOutlineTransparency
        return
    end
    if highlight then highlight:Destroy() end
    highlight = Instance.new("Highlight")
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Enabled = (Config.ESP_Chams and Config.ESP_Enabled)
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = Config.ChamsFillTransparency
    highlight.OutlineTransparency = Config.ChamsOutlineTransparency
    highlight.Parent = safeContainer
    highlight.Adornee = character
    cache.Highlight = highlight
end

for _, player in ipairs(Players:GetPlayers()) do createESP(player) end
addConn(Players, "PlayerAdded", createESP)
addConn(Players, "PlayerRemoving", removeESP)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if Workspace.CurrentCamera then Camera = Workspace.CurrentCamera end
end)

-- Поиск цели для аимбота с проверкой команды
local function getTarget()
    local closest, minDist = nil, Config.Aim_FOV
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    local myColor, myTeam = GetTeamInfo(LocalPlayer.Character)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local part = char:FindFirstChild(Config.Aim_Part) or char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not part or not hum or hum.Health <= 0 then continue end

        -- Проверка команды
        if Config.Aim_TeamCheck then
            local targetColor, targetTeam = GetTeamInfo(char)
            if myTeam ~= "Lobby" and targetTeam == myTeam then continue end
        end

        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        -- Проверка видимости (Raycast)
        local rayOrigin = Camera.CFrame.Position
        local rayDir = (part.Position - rayOrigin).Unit * (part.Position - rayOrigin).Magnitude
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {char, LocalPlayer.Character}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local rayResult = Workspace:Raycast(rayOrigin, rayDir, rayParams)
        if rayResult and not rayResult.Instance:IsDescendantOf(char) then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if dist < minDist then
            minDist = dist
            closest = part
        end
    end
    return closest
end

-- FOV круг
local function updateFOV()
    if not fovCircle then
        fovCircle = newDrawing("Circle", {Thickness = 1, Filled = false, Color = Color3.fromRGB(80, 255, 140), Visible = false})
    end
    if Config.Aim_ShowFOV and (Config.Aim_Enabled or Config.Trigger_Enabled) then
        fovCircle.Visible = true
        fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y)
        fovCircle.Radius = Config.Aim_FOV
        fovCircle.Color = Config.Aim_Enabled and Color3.fromRGB(80, 255, 140) or Color3.fromRGB(255, 255, 255)
    else
        fovCircle.Visible = false
    end
end

-- Аимбот
addConn(RunService, "RenderStepped", function()
    if not Config.Aim_Enabled then return end
    local target = getTarget()
    if not target then return end
    local currentCF = Camera.CFrame
    local desiredCF = CFrame.lookAt(currentCF.Position, target.Position)
    Camera.CFrame = currentCF:Lerp(desiredCF, Config.Aim_Smooth)
end)

-- Триггербот
addConn(RunService, "RenderStepped", function(dt)
    if not Config.Trigger_Enabled then return end
    triggerCooldown = triggerCooldown - dt
    if triggerCooldown > 0 then return end
    local target = getTarget()
    if target then
        local screenPos, onScreen = Camera:WorldToViewportPoint(target.Position)
        if onScreen then
            local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
            if dist < 15 then
                VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true, game, 1)
                task.wait(0.01)
                VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 1)
                triggerCooldown = Config.Trigger_Delay
            end
        end
    end
end)

-- Основной цикл отрисовки ESP
addConn(RunService, "RenderStepped", function()
    if not Config.ESP_Enabled then
        for _, cache in pairs(espCache) do
            for _, obj in pairs(cache) do
                if typeof(obj) == "Drawing" then obj.Visible = false
                elseif typeof(obj) == "Instance" and obj:IsA("Highlight") then obj.Enabled = false end
            end
        end
        return
    end

    for player, cache in pairs(espCache) do
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then
            for _, obj in pairs(cache) do
                if typeof(obj) == "Drawing" then obj.Visible = false
                elseif typeof(obj) == "Instance" and obj:IsA("Highlight") then obj.Enabled = false end
            end
            continue
        end

        local rootPart = char.HumanoidRootPart
        local hum = char.Humanoid
        local color, teamName = GetTeamInfo(char)

        -- Проверка команды для ESP
        if Config.ESP_TeamCheck then
            local myColor, myTeam = GetTeamInfo(LocalPlayer.Character)
            if myTeam ~= "Lobby" and teamName == myTeam then
                for _, obj in pairs(cache) do
                    if typeof(obj) == "Drawing" then obj.Visible = false
                    elseif typeof(obj) == "Instance" and obj:IsA("Highlight") then obj.Enabled = false end
                end
                continue
            end
        end

        local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
        local distance = (Camera.CFrame.Position - rootPart.Position).Magnitude

        if onScreen and distance <= Config.ESP_MaxDist then
            -- Формула из Varap228: чем больше Z (расстояние), тем меньше множитель, и наоборот
            local scaleFactor = 750 / screenPos.Z
            local sizeY = 5 * scaleFactor
            local sizeX = sizeY * 0.6
            local boxPos = Vector2.new(screenPos.X - sizeX / 2, screenPos.Y - sizeY / 2)

            -- Боксы
            if Config.ESP_Boxes then
                cache.Box.Size = Vector2.new(sizeX, sizeY)
                cache.Box.Position = boxPos
                cache.Box.Color = color
                cache.Box.Visible = true
            else
                cache.Box.Visible = false
            end

            -- Имена
            if Config.ESP_Names then
                cache.NameText.Text = player.Name
                cache.NameText.Position = Vector2.new(screenPos.X, boxPos.Y - 16)
                cache.NameText.Color = color
                cache.NameText.Visible = true
            else
                cache.NameText.Visible = false
            end

            -- Дистанция
            if Config.ESP_Distance then
                cache.DistanceText.Text = math.floor(distance) .. "m"
                cache.DistanceText.Position = Vector2.new(screenPos.X, boxPos.Y + sizeY + 2)
                cache.DistanceText.Color = color
                cache.DistanceText.Visible = true
            else
                cache.DistanceText.Visible = false
            end

            -- Здоровье
            if Config.ESP_Health then
                local hpPercent = hum.Health / hum.MaxHealth
                local barHeight = sizeY * hpPercent
                cache.HP_BG.Size = Vector2.new(2, sizeY)
                cache.HP_BG.Position = Vector2.new(boxPos.X - 5, boxPos.Y)
                cache.HP_BG.Visible = true
                cache.HP_Bar.Size = Vector2.new(2, barHeight)
                cache.HP_Bar.Position = Vector2.new(boxPos.X - 5, boxPos.Y + (sizeY - barHeight))
                cache.HP_Bar.Color = Color3.fromHSV(hpPercent * 0.3, 1, 1)
                cache.HP_Bar.Visible = true
            else
                cache.HP_BG.Visible = false
                cache.HP_Bar.Visible = false
            end

            -- Трейсеры
            if Config.ESP_Tracers then
                cache.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                cache.Tracer.To = Vector2.new(screenPos.X, screenPos.Y + sizeY / 2)
                cache.Tracer.Color = color
                cache.Tracer.Visible = true
            else
                cache.Tracer.Visible = false
            end

            -- Чамсы (Highlight)
            updateChams(player, char, color)

        else
            for _, obj in pairs(cache) do
                if typeof(obj) == "Drawing" then obj.Visible = false
                elseif typeof(obj) == "Instance" and obj:IsA("Highlight") then obj.Enabled = false end
            end
        end
    end

    updateFOV()
end)

-- Меню (простое, на ScreenGui)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SocietyHub"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 400, 0, 300)
mainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Visible = true
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
title.BorderSizePixel = 0
title.Text = "  society hub  |  The Lost Front"
title.TextColor3 = Color3.fromRGB(220, 220, 220)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -10, 1, -40)
content.Position = UDim2.new(0, 5, 0, 35)
content.BackgroundTransparency = 1
content.Parent = mainFrame

local function addToggle(parent, text, key, y)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 26)
    row.Position = UDim2.new(0, 0, 0, y)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 250, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 60, 0, 20)
    btn.Position = UDim2.new(1, -65, 0, 3)
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

addToggle(content, "ESP Enabled", "ESP_Enabled", 5)
addToggle(content, "Boxes", "ESP_Boxes", 35)
addToggle(content, "Names", "ESP_Names", 65)
addToggle(content, "Health", "ESP_Health", 95)
addToggle(content, "Distance", "ESP_Distance", 125)
addToggle(content, "Tracers", "ESP_Tracers", 155)
addToggle(content, "Chams", "ESP_Chams", 185)
addToggle(content, "Aimbot", "Aim_Enabled", 215)
addToggle(content, "Triggerbot", "Trigger_Enabled", 245)

-- Кнопка скрытия меню по RightShift
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        mainFrame.Visible = not mainFrame.Visible
    end
end)
