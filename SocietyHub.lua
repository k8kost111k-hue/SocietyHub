local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local VIM = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LP:GetMouse()

local cfg = {
    SilentAim = false, SilentFOV = 150, ShowFOV = true, AimPart = "Head",
    AimAssist = false, AimSmooth = 0.25,
    AutoFire = false, FireDelay = 0.05,
    TeamCheck = true,
    ESP = true, Box = true, Name = true, Health = true, Dist = true, Tracer = false, Skeleton = false, Radar = false,
    MaxDist = 2000,
    Fullbright = false, NoFog = false, Potato = false,
    Speed = false, SpeedVal = 50, Fly = false, FlySpeed = 50, Noclip = false,
    AntiAim = false,
    BtnSize = 40
}

local conns = {}
local dw = {}
local espObj = {}
local skelObj = {}
local fovCircle
local flyConn, noclipConn

local function addConn(s, e, f)
    local c = s[e]:Connect(f)
    table.insert(conns, c)
    return c
end

local function newDw(k, p)
    local o = Drawing.new(k)
    for a, b in pairs(p) do o[a] = b end
    table.insert(dw, o)
    return o
end

local function createESP(p)
    if p == LP or espObj[p] then return end
    local s = {}
    s.Box = newDw("Square", {Thickness=1, Filled=false, Color=Color3.fromRGB(255,60,60), Visible=false})
    s.Name = newDw("Text", {Center=true, Outline=true, Size=14, Color=Color3.fromRGB(255,255,255), Visible=false})
    s.HpBg = newDw("Square", {Filled=true, Color=Color3.fromRGB(0,0,0), Visible=false})
    s.Hp = newDw("Square", {Filled=true, Color=Color3.fromRGB(0,255,0), Visible=false})
    s.Dist = newDw("Text", {Center=true, Outline=true, Size=12, Color=Color3.fromRGB(200,200,200), Visible=false})
    s.Tracer = newDw("Line", {Thickness=1, Color=Color3.fromRGB(255,60,60), Visible=false})
    espObj[p] = s
end

local function removeESP(p)
    local s = espObj[p]
    if not s then return end
    for _, o in pairs(s) do if typeof(o) == "Drawing" then o:Remove() end end
    espObj[p] = nil
end

for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
addConn(Players, "PlayerAdded", createESP)
addConn(Players, "PlayerRemoving", removeESP)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if Workspace.CurrentCamera then Camera = Workspace.CurrentCamera end
end)

local function getTarget(fov, part)
    local closest, minDist = nil, fov
    local mPos = Vector2.new(Mouse.X, Mouse.Y)
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        if cfg.TeamCheck and p.Team and p.Team == LP.Team then continue end
        local char = p.Character
        if not char then continue end
        local pPart = char:FindFirstChild(part) or char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not pPart or not hum or hum.Health <= 0 then continue end
        local sPos, onScr = Camera:WorldToViewportPoint(pPart.Position)
        if not onScr then continue end
        local rParams = RaycastParams.new()
        rParams.FilterDescendantsInstances = {char, LP.Character}
        rParams.FilterType = Enum.RaycastFilterType.Exclude
        local rRes = Workspace:Raycast(Camera.CFrame.Position, (pPart.Position - Camera.CFrame.Position).Unit * (pPart.Position - Camera.CFrame.Position).Magnitude, rParams)
        if rRes and rRes.Instance:IsDescendantOf(char) == false then continue end
        local d = (Vector2.new(sPos.X, sPos.Y) - mPos).Magnitude
        if d < minDist then
            minDist = d
            closest = pPart
        end
    end
    return closest
end

local function updFOV()
    if not fovCircle then
        fovCircle = newDw("Circle", {Thickness=1, Filled=false, Color=Color3.fromRGB(255,255,255), Visible=false})
    end
    if cfg.ShowFOV and (cfg.SilentAim or cfg.AimAssist) then
        fovCircle.Visible = true
        fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y)
        fovCircle.Radius = cfg.SilentFOV
        fovCircle.Color = cfg.SilentAim and Color3.fromRGB(80,255,140) or Color3.fromRGB(255,255,255)
    else
        fovCircle.Visible = false
    end
end

addConn(RunService, "RenderStepped", function()
    if cfg.SilentAim then
        local t = getTarget(cfg.SilentFOV, cfg.AimPart)
        if t then
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, t.Position), 1)
        end
    end
end)

addConn(RunService, "RenderStepped", function()
    if cfg.AimAssist then
        local t = getTarget(cfg.SilentFOV, cfg.AimPart)
        if t then
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, t.Position), cfg.AimSmooth)
        end
    end
end)

local fCd = 0
addConn(RunService, "RenderStepped", function(dt)
    if not cfg.AutoFire then return end
    fCd = fCd - dt
    if fCd > 0 then return end
    local t = getTarget(15, cfg.AimPart)
    if t then
        local sPos, on = Camera:WorldToViewportPoint(t.Position)
        if on and (Vector2.new(sPos.X, sPos.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude < 15 then
            VIM:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true, game, 1)
            task.wait(0.01)
            VIM:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 1)
            fCd = cfg.FireDelay
        end
    end
end)

local function drawSkel(char, p)
    if not cfg.Skeleton then
        if skelObj[p] then for _, l in pairs(skelObj[p]) do l.Visible = false end end
        return
    end
    local b = {
        {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
        {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"},
        {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
        {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}
    }
    if not skelObj[p] then skelObj[p] = {} end
    for i, pr in ipairs(b) do
        local p1, p2 = char:FindFirstChild(pr[1]), char:FindFirstChild(pr[2])
        if p1 and p2 then
            local s1, o1 = Camera:WorldToViewportPoint(p1.Position)
            local s2, o2 = Camera:WorldToViewportPoint(p2.Position)
            if o1 and o2 then
                if not skelObj[p][i] then
                    skelObj[p][i] = newDw("Line", {Thickness=1, Color=Color3.fromRGB(255,255,255), Visible=false})
                end
                local l = skelObj[p][i]
                l.Visible = true
                l.From = Vector2.new(s1.X, s1.Y)
                l.To = Vector2.new(s2.X, s2.Y)
            else
                if skelObj[p][i] then skelObj[p][i].Visible = false end
            end
        end
    end
end

local radarGui
local function updRadar()
    if not cfg.Radar then
        if radarGui then radarGui.Visible = false end
        return
    end
    if not radarGui then
        radarGui = Instance.new("Frame")
        radarGui.Size = UDim2.new(0, 120, 0, 120)
        radarGui.Position = UDim2.new(0, 10, 0.5, -60)
        radarGui.BackgroundColor3 = Color3.fromRGB(20,20,20)
        radarGui.BorderSizePixel = 1
        radarGui.BorderColor3 = Color3.fromRGB(255,50,50)
        radarGui.Parent = game:GetService("CoreGui")
    end
    radarGui.Visible = true
    for _, c in ipairs(radarGui:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local ctr = Vector2.new(radarGui.AbsolutePosition.X + 60, radarGui.AbsolutePosition.Y + 60)
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        local char = p.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local rel = hrp.Position - LP.Character.HumanoidRootPart.Position
        local ang = math.atan2(rel.Z, rel.X)
        local d = math.min(rel.Magnitude, 150)
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 6, 0, 6)
        dot.BackgroundColor3 = Color3.fromRGB(255,50,50)
        dot.BorderSizePixel = 0
        dot.Position = UDim2.new(0, ctr.X + math.cos(ang)*d - 3, 0, ctr.Y + math.sin(ang)*d - 3)
        dot.Parent = radarGui
    end
end

addConn(RunService, "RenderStepped", function()
    for p, s in pairs(espObj) do
        local vis = false
        local char = p.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if cfg.ESP and hrp and hum and hum.Health > 0 then
            if not (cfg.TeamCheck and p.Team and p.Team == LP.Team) then
                local pos, on = Camera:WorldToViewportPoint(hrp.Position)
                local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                if on and d <= cfg.MaxDist then
                    vis = true
                    local sc = math.clamp(1000 / d, 0.5, 2.5)
                    local h, w = 80 * sc, 45 * sc
                    local x, y = pos.X - w/2, pos.Y - h/2
                    
                    s.Box.Visible = cfg.Box
                    if cfg.Box then
                        s.Box.Size = Vector2.new(w, h)
                        s.Box.Position = Vector2.new(x, y)
                    end
                    
                    s.Name.Visible = cfg.Name
                    if cfg.Name then
                        s.Name.Text = p.Name
                        s.Name.Position = Vector2.new(pos.X, y - 18)
                    end
                    
                    s.HpBg.Visible = cfg.Health
                    s.Hp.Visible = cfg.Health
                    if cfg.Health then
                        local fr = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        local bw = 4 * sc
                        s.HpBg.Size = Vector2.new(bw, h)
                        s.HpBg.Position = Vector2.new(x - bw - 4, y)
                        s.Hp.Size = Vector2.new(bw, h * fr)
                        s.Hp.Position = Vector2.new(x - bw - 4, y + h * (1 - fr))
                    end
                    
                    s.Dist.Visible = cfg.Dist
                    if cfg.Dist then
                        s.Dist.Text = math.floor(d) .. "m"
                        s.Dist.Position = Vector2.new(pos.X, y + h + 4)
                    end
                    
                    s.Tracer.Visible = cfg.Tracer
                    if cfg.Tracer then
                        s.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        s.Tracer.To = Vector2.new(pos.X, pos.Y)
                    end
                    
                    drawSkel(char, p)
                end
            end
        end
        if not vis then
            for _, o in pairs(s) do o.Visible = false end
            if skelObj[p] then for _, l in pairs(skelObj[p]) do l.Visible = false end end
        end
    end
    updRadar()
    updFOV()
end)

local origFog, origBright, origAmb, origOutAmb, origQual = Lighting.FogEnd, Lighting.Brightness, Lighting.Ambient, Lighting.OutdoorAmbient, settings().Rendering.QualityLevel

local function appFull(st)
    if st then
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

local function appFog(st)
    if st then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
    else
        Lighting.FogEnd = origFog
    end
end

local function appPot(st)
    if st then
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

local lastState = {}
addConn(RunService, "Heartbeat", function()
    if lastState.Full ~= cfg.Fullbright then lastState.Full = cfg.Fullbright; appFull(cfg.Fullbright) end
    if lastState.Fog ~= cfg.NoFog then lastState.Fog = cfg.NoFog; appFog(cfg.NoFog) end
    if lastState.Pot ~= cfg.Potato then lastState.Pot = cfg.Potato; appPot(cfg.Potato) end
end)

local function toggleFly(st)
    if st then
        if flyConn then return end
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.zero
        bv.Parent = LP.Character.HumanoidRootPart
        flyConn = addConn(RunService, "RenderStepped", function()
            if not cfg.Fly or not LP.Character then bv:Destroy() return end
            local md = Vector3.zero
            if UIS:IsKeyDown(Enum.KeyCode.W) then md += Camera.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then md -= Camera.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then md -= Camera.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then md += Camera.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then md += Vector3.yAxis end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then md -= Vector3.yAxis end
            bv.Velocity = md * cfg.FlySpeed
        end)
    else
        if flyConn then flyConn:Disconnect() flyConn = nil end
        local bv = LP.Character and LP.Character.HumanoidRootPart:FindFirstChild("BodyVelocity")
        if bv then bv:Destroy() end
    end
end

local function toggleNoclip(st)
    if st then
        if noclipConn then return end
        noclipConn = addConn(RunService, "Stepped", function()
            if not cfg.Noclip then return end
            if LP.Character then
                for _, p in ipairs(LP.Character:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect() noclipConn = nil end
        if LP.Character then
            for _, p in ipairs(LP.Character:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
    end
end

addConn(RunService, "Heartbeat", function()
    if cfg.Speed and LP.Character then
        local h = LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = cfg.SpeedVal end
    elseif not cfg.Speed and LP.Character then
        local h = LP.Character:FindFirstChildOfClass("Humanoid")
        if h and h.WalkSpeed ~= 16 then h.WalkSpeed = 16 end
    end
    if cfg.Fly and not flyConn then toggleFly(true) end
    if not cfg.Fly and flyConn then toggleFly(false) end
    if cfg.Noclip and not noclipConn then toggleNoclip(true) end
    if not cfg.Noclip and noclipConn then toggleNoclip(false) end
end)

addConn(RunService, "RenderStepped", function()
    if cfg.AntiAim then
        Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(math.random(-10,10)), math.rad(math.random(-10,10)), 0)
    end
end)

local sg = Instance.new("ScreenGui")
sg.Name = "SocietyHub"
sg.ResetOnSpawn = false
sg.Parent = game:GetService("CoreGui")

local tBtn = Instance.new("TextButton")
tBtn.Size = UDim2.new(0, cfg.BtnSize, 0, cfg.BtnSize)
tBtn.Position = UDim2.new(0, 20, 0.5, -20)
tBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
tBtn.Text = "SH"
tBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
tBtn.TextSize = 18
tBtn.Font = Enum.Font.GothamBold
tBtn.BorderSizePixel = 1
tBtn.BorderColor3 = Color3.fromRGB(255, 60, 60)
tBtn.Active = true
tBtn.Draggable = true
tBtn.Parent = sg

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 520, 0, 400)
main.Position = UDim2.new(0.5, -260, 0.5, -200)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Visible = false
main.Parent = sg

tBtn.MouseButton1Click:Connect(function() main.Visible = not main.Visible end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
title.BorderSizePixel = 0
title.Text = "  society hub  |  The Lost Front"
title.TextColor3 = Color3.fromRGB(220, 220, 220)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 30)
tabBar.Position = UDim2.new(0, 0, 0, 32)
tabBar.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
tabBar.BorderSizePixel = 0
tabBar.Parent = main

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -16, 1, -78)
content.Position = UDim2.new(0, 8, 0, 66)
content.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
content.BorderSizePixel = 0
content.Parent = main

local tabs = {"Aim", "ESP", "Visuals", "Move", "Player", "Settings"}
local tabBtns, pages = {}, {}

for i, n in ipairs(tabs) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 520/6, 1, 0)
    b.Position = UDim2.new(0, (i-1)*520/6, 0, 0)
    b.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    b.BorderSizePixel = 0
    b.Text = n
    b.TextColor3 = Color3.fromRGB(180, 180, 180)
    b.TextSize = 12
    b.Font = Enum.Font.GothamSemibold
    b.Parent = tabBar
    tabBtns[n] = b
end

for i, n in ipairs(tabs) do
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = content
    pages[n] = f
end

local function switchTab(n)
    for k, f in pairs(pages) do f.Visible = (k == n) end
    for k, b in pairs(tabBtns) do b.BackgroundColor3 = (k == n) and Color3.fromRGB(50,50,50) or Color3.fromRGB(30,30,30) end
end

for n, b in pairs(tabBtns) do b.MouseButton1Click:Connect(function() switchTab(n) end) end

local function addTgl(par, txt, key, y)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, 28)
    r.Position = UDim2.new(0, 0, 0, y)
    r.BackgroundTransparency = 1
    r.Parent = par
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, 250, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(200, 200, 200)
    l.TextSize = 13
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = r
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 60, 0, 22)
    b.Position = UDim2.new(1, -70, 0, 3)
    b.BackgroundColor3 = cfg[key] and Color3.fromRGB(60,180,80) or Color3.fromRGB(60,60,60)
    b.BorderSizePixel = 0
    b.Text = cfg[key] and "ON" or "OFF"
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.Parent = r
    b.MouseButton1Click:Connect(function()
        cfg[key] = not cfg[key]
        b.Text = cfg[key] and "ON" or "OFF"
        b.BackgroundColor3 = cfg[key] and Color3.fromRGB(60,180,80) or Color3.fromRGB(60,60,60)
    end)
end

local function addSld(par, txt, key, min, max, y, st)
    st = st or 5
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, 28)
    r.Position = UDim2.new(0, 0, 0, y)
    r.BackgroundTransparency = 1
    r.Parent = par
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, 200, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = txt .. ": " .. cfg[key]
    l.TextColor3 = Color3.fromRGB(200, 200, 200)
    l.TextSize = 13
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = r
    local b1 = Instance.new("TextButton")
    b1.Size = UDim2.new(0, 40, 0, 22)
    b1.Position = UDim2.new(1, -50, 0, 3)
    b1.BackgroundColor3 = Color3.fromRGB(60,60,60)
    b1.Text = "▲"
    b1.TextColor3 = Color3.fromRGB(255, 255, 255)
    b1.Parent = r
    local b2 = Instance.new("TextButton")
    b2.Size = UDim2.new(0, 40, 0, 22)
    b2.Position = UDim2.new(1, -95, 0, 3)
    b2.BackgroundColor3 = Color3.fromRGB(60,60,60)
    b2.Text = "▼"
    b2.TextColor3 = Color3.fromRGB(255, 255, 255)
    b2.Parent = r
    b1.MouseButton1Click:Connect(function()
        cfg[key] = math.min(max, cfg[key] + st)
        l.Text = txt .. ": " .. cfg[key]
    end)
    b2.MouseButton1Click:Connect(function()
        cfg[key] = math.max(min, cfg[key] - st)
        l.Text = txt .. ": " .. cfg[key]
    end)
end

addTgl(pages["Aim"], "Silent Aim", "SilentAim", 5)
addTgl(pages["Aim"], "Show FOV", "ShowFOV", 40)
addSld(pages["Aim"], "FOV Size", "SilentFOV", 50, 500, 75)
addTgl(pages["Aim"], "Aim Assist", "AimAssist", 110)
addTgl(pages["Aim"], "Auto Fire", "AutoFire", 145)
addTgl(pages["Aim"], "Team Check", "TeamCheck", 180)

addTgl(pages["ESP"], "ESP Enabled", "ESP", 5)
addTgl(pages["ESP"], "Boxes", "Box", 40)
addTgl(pages["ESP"], "Names", "Name", 75)
addTgl(pages["ESP"], "Health", "Health", 110)
addTgl(pages["ESP"], "Distance", "Dist", 145)
addTgl(pages["ESP"], "Tracers", "Tracer", 180)
addTgl(pages["ESP"], "Skeleton", "Skeleton", 215)
addTgl(pages["ESP"], "Radar", "Radar", 250)

addTgl(pages["Visuals"], "Fullbright", "Fullbright", 5)
addTgl(pages["Visuals"], "No Fog", "NoFog", 40)
addTgl(pages["Visuals"], "Potato Graphics", "Potato", 75)

addTgl(pages["Move"], "Speed", "Speed", 5)
addSld(pages["Move"], "Speed Val", "SpeedVal", 16, 200, 40)
addTgl(pages["Move"], "Fly", "Fly", 75)
addSld(pages["Move"], "Fly Speed", "FlySpeed", 10, 200, 110)
addTgl(pages["Move"], "Noclip", "Noclip", 145)

addTgl(pages["Player"], "Anti-Aim", "AntiAim", 5)

addSld(pages["Settings"], "Open Btn Size", "BtnSize", 20, 100, 5)
addConn(RunService, "Heartbeat", function() tBtn.Size = UDim2.new(0, cfg.BtnSize, 0, cfg.BtnSize) end)

local unhookBtn = Instance.new("TextButton")
unhookBtn.Size = UDim2.new(0, 150, 0, 30)
unhookBtn.Position = UDim2.new(0, 0, 0, 50)
unhookBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
unhookBtn.BorderSizePixel = 0
unhookBtn.Text = "UNHOOK"
unhookBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
unhookBtn.TextSize = 14
unhookBtn.Font = Enum.Font.GothamBold
unhookBtn.Parent = pages["Settings"]

local function unhook()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    for _, d in ipairs(dw) do pcall(function() d:Remove() end) end
    appFull(false); appFog(false); appPot(false)
    if LP.Character then
        local h = LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = 16 end
        for _, p in ipairs(LP.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
        local bv = LP.Character.HumanoidRootPart:FindFirstChild("BodyVelocity")
        if bv then bv:Destroy() end
    end
    if sg then sg:Destroy() end
    if radarGui then radarGui:Destroy() end
end

unhookBtn.MouseButton1Click:Connect(unhook)

switchTab("Aim")

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    end
end)
