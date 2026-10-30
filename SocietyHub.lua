local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local ATTACKER_PANTS_ID = "71322661859196"
local DEFENDER_PANTS_ID = "82267040223924"

local Config = {
    ESP_Enabled = true,
    ESP_Boxes = true,
    ESP_Names = true,
    ESP_Health = true,
    ESP_Distance = true,
    ESP_Tracers = false,
    ESP_Skeleton = false,
    ESP_Chams = true,
    ESP_TeamCheck = true,
    ESP_MaxDist = 2000,
    ESP_FPV = false,
    AttackerColor = Color3.fromRGB(255, 50, 50),
    DefenderColor = Color3.fromRGB(50, 150, 255),
    
    AIM_Enabled = false,
    AIM_FOV = 150,
    AIM_Smooth = 0.25,
    AIM_ShowFOV = true,
    AIM_TeamCheck = true,
    AIM_Part = "Head",
    AIM_Silent = false,
    
    Trigger_Enabled = false,
    Trigger_Delay = 0.05,
    
    Visual_Fullbright = false,
    Visual_NoFog = false,
    Visual_Potato = false,
    Visual_RemoveTrees = false,
    Visual_InfiniteJump = false,
    
    Move_Speed = false,
    Move_SpeedVal = 50,
    Move_JumpPower = false,
    Move_JumpVal = 100,
    Move_Fly = false,
    Move_FlySpeed = 50,
    Move_Noclip = false,
    
    Player_AntiAim = false,
    Player_Desync = false,
    
    Misc_AutoPickup = false,
    Misc_Radar = false,
    
    GuiColor = Color3.fromRGB(40, 40, 40),
    ColorR = 40,
    ColorG = 40,
    ColorB = 40,
    MenuKey = Enum.KeyCode.RightShift
}

local connections = {}
local drawings = {}
local espCache = {}
local skelCache = {}
local fovCircle = nil
local radarGui = nil
local flyConn = nil
local noclipConn = nil
local infiniteJumpConn = nil
local triggerCooldown = 0
local isBinding = false
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

local function createESP(player)
    if player == LocalPlayer or espCache[player] then return end
    local cache = {}
    cache.Box = newDrawing("Square", {Thickness = 1, Filled = false, Visible = false})
    cache.NameText = newDrawing("Text", {Center = true, Outline = true, Size = 13, Visible = false})
    cache.DistanceText = newDrawing("Text", {Center = true, Outline = true, Size = 13, Visible = false})
    cache.HP_BG = newDrawing("Square", {Filled = true, Color = Color3.new(0, 0, 0), Transparency = 0.5, Visible = false})
    cache.HP_Bar = newDrawing("Square", {Filled = true, Color = Color3.new(0, 1, 0), Visible = false})
    cache.Tracer = newDrawing("Line", {Thickness = 1, Visible = false})
    cache.AimLine = newDrawing("Line", {Thickness = 1, Color = Color3.fromRGB(255, 255, 0), Visible = false})
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

local function updateChams(player, character, color)
    local cache = espCache[player]
    if not cache then return end
    local highlight = cache.Highlight
    if highlight and highlight.Adornee == character then
        highlight.FillColor = color
        highlight.OutlineColor = color
        highlight.Enabled = (Config.ESP_Chams and Config.ESP_Enabled)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        return
    end
    if highlight then highlight:Destroy() end
    highlight = Instance.new("Highlight")
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Enabled = (Config.ESP_Chams and Config.ESP_Enabled)
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
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

local function getTarget()
    local closest, minDist = nil, Config.AIM_FOV
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    local myColor, myTeam = GetTeamInfo(LocalPlayer.Character)
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local part = char:FindFirstChild(Config.AIM_Part) or char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not part or not hum or hum.Health <= 0 then continue end
        if Config.AIM_TeamCheck then
            local targetColor, targetTeam = GetTeamInfo(char)
            if myTeam ~= "Lobby" and targetTeam == myTeam then continue end
        end
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
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

local function updateFOV()
    if not fovCircle then
        fovCircle = newDrawing("Circle", {Thickness = 1, Filled = false, Color = Color3.fromRGB(80, 255, 140), Visible = false})
    end
    if Config.AIM_ShowFOV and (Config.AIM_Enabled or Config.Trigger_Enabled) then
        fovCircle.Visible = true
        fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y)
        fovCircle.Radius = Config.AIM_FOV
        fovCircle.Color = Config.AIM_Enabled and Color3.fromRGB(80, 255, 140) or Color3.fromRGB(255, 255, 255)
    else
        fovCircle.Visible = false
    end
end

addConn(RunService, "RenderStepped", function()
    if not Config.AIM_Enabled then return end
    local target = getTarget()
    if not target then return end
    if Config.AIM_Silent then
        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, target.Position)
    else
        local currentCF = Camera.CFrame
        local desiredCF = CFrame.lookAt(currentCF.Position, target.Position)
        Camera.CFrame = currentCF:Lerp(desiredCF, Config.AIM_Smooth)
    end
end)

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

local function drawSkeleton(char, player)
    if not Config.ESP_Skeleton then
        if skelCache[player] then for _, l in pairs(skelCache[player]) do l.Visible = false end end
        return
    end
    local bones = {
        {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
        {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"},
        {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
        {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}
    }
    if not skelCache[player] then skelCache[player] = {} end
    for i, pair in ipairs(bones) do
        local p1 = char:FindFirstChild(pair[1])
        local p2 = char:FindFirstChild(pair[2])
        if p1 and p2 then
            local s1, on1 = Camera:WorldToViewportPoint(p1.Position)
            local s2, on2 = Camera:WorldToViewportPoint(p2.Position)
            if on1 and on2 then
                if not skelCache[player][i] then
                    skelCache[player][i] = newDrawing("Line", {Thickness = 1, Color = Color3.fromRGB(255, 255, 255), Visible = false})
                end
                local l = skelCache[player][i]
                l.Visible = true
                l.From = Vector2.new(s1.X, s1.Y)
                l.To = Vector2.new(s2.X, s2.Y)
            else
                if skelCache[player][i] then skelCache[player][i].Visible = false end
            end
        end
    end
end

local function updateRadar()
    if not Config.Misc_Radar then
        if radarGui then radarGui.Visible = false end
        return
    end
    if not radarGui then
        radarGui = Instance.new("Frame")
        radarGui.Size = UDim2.new(0, 120, 0, 120)
        radarGui.Position = UDim2.new(0, 10, 0.5, -60)
        radarGui.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        radarGui.BorderSizePixel = 1
        radarGui.BorderColor3 = Color3.fromRGB(255, 50, 50)
        radarGui.Parent = safeContainer
    end
    radarGui.Visible = true
    for _, child in ipairs(radarGui:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    local center = Vector2.new(radarGui.AbsolutePosition.X + 60, radarGui.AbsolutePosition.Y + 60)
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local rel = hrp.Position - LocalPlayer.Character.HumanoidRootPart.Position
        local angle = math.atan2(rel.Z, rel.X)
        local dist = math.min(rel.Magnitude, 150)
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 6, 0, 6)
        dot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        dot.BorderSizePixel = 0
        dot.Position = UDim2.new(0, center.X + math.cos(angle) * dist - 3, 0, center.Y + math.sin(angle) * dist - 3)
        dot.Parent = radarGui
    end
end

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
            local scaleFactor = 750 / screenPos.Z
            local sizeY = 5 * scaleFactor
            local sizeX = sizeY * 0.6
            local boxPos = Vector2.new(screenPos.X - sizeX / 2, screenPos.Y - sizeY / 2)

            if Config.ESP_Boxes then
                cache.Box.Size = Vector2.new(sizeX, sizeY)
                cache.Box.Position = boxPos
                cache.Box.Color = color
                cache.Box.Visible = true
            else
                cache.Box.Visible = false
            end

            if Config.ESP_Names then
                cache.NameText.Text = player.Name
                cache.NameText.Position = Vector2.new(screenPos.X, boxPos.Y - 16)
                cache.NameText.Color = color
                cache.NameText.Visible = true
            else
                cache.NameText.Visible = false
            end

            if Config.ESP_Distance then
                cache.DistanceText.Text = math.floor(distance) .. "m"
                cache.DistanceText.Position = Vector2.new(screenPos.X, boxPos.Y + sizeY + 2)
                cache.DistanceText.Color = color
                cache.DistanceText.Visible = true
            else
                cache.DistanceText.Visible = false
            end

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

            if Config.ESP_Tracers then
                cache.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                cache.Tracer.To = Vector2.new(screenPos.X, screenPos.Y + sizeY / 2)
                cache.Tracer.Color = color
                cache.Tracer.Visible = true
            else
                cache.Tracer.Visible = false
            end
            
            if Config.ESP_FPV then
                cache.AimLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                cache.AimLine.To = Vector2.new(screenPos.X, screenPos.Y)
                cache.AimLine.Color = color
                cache.AimLine.Visible = true
            else
                cache.AimLine.Visible = false
            end

            drawSkeleton(char, player)
            updateChams(player, char, color)
        else
            for _, obj in pairs(cache) do
                if typeof(obj) == "Drawing" then obj.Visible = false
                elseif typeof(obj) == "Instance" and obj:IsA("Highlight") then obj.Enabled = false end
            end
            if skelCache[player] then for _, l in pairs(skelCache[player]) do l.Visible = false end end
        end
    end
    updateRadar()
    updateFOV()
end)

local origFog, origBright, origAmb, origOutAmb, origQual = Lighting.FogEnd, Lighting.Brightness, Lighting.Ambient, Lighting.OutdoorAmbient, settings().Rendering.QualityLevel

local function applyFullbright(state)
    if state then
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.FogEnd = 100000
    else
        Lighting.Brightness = origBright
        Lighting.Ambient = origAmb
        Lighting.OutdoorAmbient = origOutAmb
        Lighting.FogEnd = origFog
    end
end

local function applyNoFog(state)
    if state then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
    else
        Lighting.FogEnd = origFog
    end
end

local function applyPotato(state)
    if state then
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        Lighting.GlobalShadows = false
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") then v.Enabled = false end
        end
    else
        settings().Rendering.QualityLevel = origQual
        Lighting.GlobalShadows = true
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") then v.Enabled = true end
        end
    end
end

local lastVisual = {}
addConn(RunService, "Heartbeat", function()
    if lastVisual.Full ~= Config.Visual_Fullbright then lastVisual.Full = Config.Visual_Fullbright; applyFullbright(Config.Visual_Fullbright) end
    if lastVisual.Fog ~= Config.Visual_NoFog then lastVisual.Fog = Config.Visual_NoFog; applyNoFog(Config.Visual_NoFog) end
    if lastVisual.Pot ~= Config.Visual_Potato then lastVisual.Pot = Config.Visual_Potato; applyPotato(Config.Visual_Potato) end
end)

local function toggleFly(state)
    if state then
        if flyConn then return end
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.zero
        bv.Parent = LocalPlayer.Character.HumanoidRootPart
        flyConn = addConn(RunService, "RenderStepped", function()
            if not Config.Move_Fly or not LocalPlayer.Character then bv:Destroy() return end
            local md = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then md += Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then md -= Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then md -= Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then md += Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then md += Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then md -= Vector3.yAxis end
            bv.Velocity = md * Config.Move_FlySpeed
        end)
    else
        if flyConn then flyConn:Disconnect() flyConn = nil end
        local bv = LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart:FindFirstChild("BodyVelocity")
        if bv then bv:Destroy() end
    end
end

local function toggleNoclip(state)
    if state then
        if noclipConn then return end
        noclipConn = addConn(RunService, "Stepped", function()
            if not Config.Move_Noclip then return end
            if LocalPlayer.Character then
                for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect() noclipConn = nil end
        if LocalPlayer.Character then
            for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
    end
end

addConn(RunService, "Heartbeat", function()
    if LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            if Config.Move_Speed then hum.WalkSpeed = Config.Move_SpeedVal
            elseif hum.WalkSpeed ~= 16 then hum.WalkSpeed = 16 end
            
            if Config.Move_JumpPower then hum.JumpPower = Config.Move_JumpVal
            elseif hum.JumpPower ~= 50 then hum.JumpPower = 50 end
        end
    end
    if Config.Move_Fly and not flyConn then toggleFly(true) end
    if not Config.Move_Fly and flyConn then toggleFly(false) end
    if Config.Move_Noclip and not noclipConn then toggleNoclip(true) end
    if not Config.Move_Noclip and noclipConn then toggleNoclip(false) end
end)

addConn(RunService, "RenderStepped", function()
    if Config.Player_AntiAim then
        Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(math.random(-10, 10)), math.rad(math.random(-10, 10)), 0)
    end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SocietyHub"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 480, 0, 440)
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -220)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BorderSizePixel = 1
mainFrame.BorderColor3 = Config.GuiColor
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Visible = true
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Config.GuiColor
title.BorderSizePixel = 0
title.Text = "  society hub v5  |  The Lost Front"
title.TextColor3 = Color3.fromRGB(220, 220, 220)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -10, 1, -40)
scrollFrame.Position = UDim2.new(0, 5, 0, 35)
scrollFrame.BackgroundTransparency = 1
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 1500)
scrollFrame.ScrollBarThickness = 4
scrollFrame.Parent = mainFrame

local function updateGuiColor()
    Config.GuiColor = Color3.fromRGB(Config.ColorR, Config.ColorG, Config.ColorB)
    title.BackgroundColor3 = Config.GuiColor
    mainFrame.BorderColor3 = Config.GuiColor
end

local function addToggle(parent, text, key, y)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 26)
    row.Position = UDim2.new(0, 0, 0, y)
    row.BackgroundTransparency = 1
    row.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 300, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 60, 0, 20)
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

local function addSlider(parent, text, key, min, max, y, step)
    step = step or 5
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 26)
    row.Position = UDim2.new(0, 0, 0, y)
    row.BackgroundTransparency = 1
    row.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 250, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. Config[key]
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row
    local btn1 = Instance.new("TextButton")
    btn1.Size = UDim2.new(0, 40, 0, 20)
    btn1.Position = UDim2.new(1, -50, 0, 3)
    btn1.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn1.Text = "▲"
    btn1.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn1.Parent = row
    local btn2 = Instance.new("TextButton")
    btn2.Size = UDim2.new(0, 40, 0, 20)
    btn2.Position = UDim2.new(1, -95, 0, 3)
    btn2.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn2.Text = "▼"
    btn2.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn2.Parent = row
    btn1.MouseButton1Click:Connect(function()
        Config[key] = math.min(max, Config[key] + step)
        label.Text = text .. ": " .. Config[key]
        if key:match("Color") then updateGuiColor() end
    end)
    btn2.MouseButton1Click:Connect(function()
        Config[key] = math.max(min, Config[key] - step)
        label.Text = text .. ": " .. Config[key]
        if key:match("Color") then updateGuiColor() end
    end)
end

local function addSection(parent, text, y)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Position = UDim2.new(0, 0, 0, y)
    label.BackgroundTransparency = 1
    label.Text = "— " .. text .. " —"
    label.TextColor3 = Color3.fromRGB(150, 150, 150)
    label.TextSize = 11
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
end

-- ESP
addSection(scrollFrame, "ESP", 5)
addToggle(scrollFrame, "ESP Enabled", "ESP_Enabled", 30)
addToggle(scrollFrame, "Boxes", "ESP_Boxes", 60)
addToggle(scrollFrame, "Names", "ESP_Names", 90)
addToggle(scrollFrame, "Health", "ESP_Health", 120)
addToggle(scrollFrame, "Distance", "ESP_Distance", 150)
addToggle(scrollFrame, "Tracers", "ESP_Tracers", 180)
addToggle(scrollFrame, "Skeleton", "ESP_Skeleton", 210)
addToggle(scrollFrame, "Chams", "ESP_Chams", 240)
addToggle(scrollFrame, "Team Check", "ESP_TeamCheck", 270)
addToggle(scrollFrame, "FPV ESP", "ESP_FPV", 300)

-- AIM
addSection(scrollFrame, "AIM & COMBAT", 335)
addToggle(scrollFrame, "Aimbot", "AIM_Enabled", 360)
addToggle(scrollFrame, "Silent Aim", "AIM_Silent", 390)
addToggle(scrollFrame, "Show FOV", "AIM_ShowFOV", 420)
addSlider(scrollFrame, "FOV Size", "AIM_FOV", 50, 500, 450)
addToggle(scrollFrame, "Aim Team Check", "AIM_TeamCheck", 480)
addToggle(scrollFrame, "Triggerbot", "Trigger_Enabled", 510)
addSlider(scrollFrame, "Trigger Delay", "Trigger_Delay", 10, 500, 540, 10)

-- VISUALS
addSection(scrollFrame, "VISUALS", 575)
addToggle(scrollFrame, "Fullbright", "Visual_Fullbright", 600)
addToggle(scrollFrame, "No Fog", "Visual_NoFog", 630)
addToggle(scrollFrame, "Potato Graphics", "Visual_Potato", 660)
addToggle(scrollFrame, "Remove Trees", "Visual_RemoveTrees", 690)
addToggle(scrollFrame, "Infinite Jump", "Visual_InfiniteJump", 720)

-- MOVEMENT
addSection(scrollFrame, "MOVEMENT", 755)
addToggle(scrollFrame, "Speed", "Move_Speed", 780)
addSlider(scrollFrame, "Speed Value", "Move_SpeedVal", 16, 200, 810)
addToggle(scrollFrame, "Jump Power", "Move_JumpPower", 840)
addSlider(scrollFrame, "Jump Value", "Move_JumpVal", 50, 500, 870)
addToggle(scrollFrame, "Fly", "Move_Fly", 900)
addSlider(scrollFrame, "Fly Speed", "Move_FlySpeed", 10, 200, 930)
addToggle(scrollFrame, "Noclip", "Move_Noclip", 960)

-- PLAYER
addSection(scrollFrame, "PLAYER", 995)
addToggle(scrollFrame, "Anti-Aim", "Player_AntiAim", 1020)
addToggle(scrollFrame, "Desync", "Player_Desync", 1050)

-- MISC
addSection(scrollFrame, "MISC", 1085)
addToggle(scrollFrame, "Auto Pickup", "Misc_AutoPickup", 1110)
addToggle(scrollFrame, "Radar", "Misc_Radar", 1140)

-- UI SETTINGS
addSection(scrollFrame, "UI SETTINGS", 1175)
addSlider(scrollFrame, "Menu Color R", "ColorR", 0, 255, 1200, 5)
addSlider(scrollFrame, "Menu Color G", "ColorG", 0, 255, 1230, 5)
addSlider(scrollFrame, "Menu Color B", "ColorB", 0, 255, 1260, 5)

local bindBtn = Instance.new("TextButton")
bindBtn.Size = UDim2.new(0, 180, 0, 24)
bindBtn.Position = UDim2.new(0, 0, 0, 1295)
bindBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
bindBtn.BorderSizePixel = 0
bindBtn.Text = "Toggle Key: " .. Config.MenuKey.Name
bindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
bindBtn.Font = Enum.Font.GothamBold
bindBtn.TextSize = 12
bindBtn.Parent = scrollFrame

bindBtn.MouseButton1Click:Connect(function()
    isBinding = true
    bindBtn.Text = "Press a key..."
end)

local unhookBtn = Instance.new("TextButton")
unhookBtn.Size = UDim2.new(0, 120, 0, 24)
unhookBtn.Position = UDim2.new(0, 0, 0, 1330)
unhookBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
unhookBtn.BorderSizePixel = 0
unhookBtn.Text = "UNHOOK"
unhookBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
unhookBtn.TextSize = 12
unhookBtn.Font = Enum.Font.GothamBold
unhookBtn.Parent = scrollFrame

local function unhook()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for _, d in ipairs(drawings) do pcall(function() d:Remove() end) end
    applyFullbright(false); applyNoFog(false); applyPotato(false)
    if LocalPlayer.Character then
        local h = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = 16; h.JumpPower = 50 end
        for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
        local bv = LocalPlayer.Character.HumanoidRootPart:FindFirstChild("BodyVelocity")
        if bv then bv:Destroy() end
    end
    if screenGui then screenGui:Destroy() end
    if safeContainer then safeContainer:Destroy() end
end

unhookBtn.MouseButton1Click:Connect(unhook)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if isBinding then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            Config.MenuKey = input.KeyCode
            bindBtn.Text = "Toggle Key: " .. Config.MenuKey.Name
            isBinding = false
        end
        return
    end
    if input.KeyCode == Config.MenuKey then
        mainFrame.Visible = not mainFrame.Visible
    end
end)
