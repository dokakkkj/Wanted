-- ============== CARREGAR LIBRARY OBSIDIAN ==============
local repo = 'https://raw.githubusercontent.com/deividcomsono/Obsidian/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()

if not Library then
    game:GetService('StarterGui'):SetCore('SendNotification', {
        Title = '❌ Erro',
        Text = 'Falha ao carregar a biblioteca!',
        Duration = 5
    })
    return
end

-- ============== CARREGAR MÓDULO ESP ==============
local ESPModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/dokakkkj/M-duloESP/refs/heads/main/ModuloESP"))()

-- ============== VARIÁVEIS GLOBAIS ==============
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Settings = {
    Enabled = true,
    FOVRadius = 180,
    WallCheck = true,
}

-- ============== JANELA PRINCIPAL ==============
local Window = Library:CreateWindow({
    Title = 'SexHub | Silent Aim',
    Footer = 'v1.0',
    Center = true,
    AutoShow = true,
})

local Tabs = {
    Silent = Window:AddTab('Silent Aim', 'crosshair'),
    Visual = Window:AddTab('Visual', 'eye'),
    ['UI Settings'] = Window:AddTab('UI Settings', 'settings'),
}

-- ============== FOV CIRCLE (GUI) ==============
local FOVGui = Instance.new("ScreenGui")
FOVGui.Name = "FOVCircleGui"
FOVGui.ResetOnSpawn = false
FOVGui.DisplayOrder = 9999
FOVGui.IgnoreGuiInset = true
FOVGui.Parent = game:GetService("CoreGui")

local FOVCircle = Instance.new("Frame")
FOVCircle.Name = "FOVCircle"
FOVCircle.Size = UDim2.new(0, Settings.FOVRadius * 2, 0, Settings.FOVRadius * 2)
FOVCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.BackgroundColor3 = Color3.new(1, 1, 1)
FOVCircle.BackgroundTransparency = 1
FOVCircle.BorderSizePixel = 0
FOVCircle.Visible = true
FOVCircle.Parent = FOVGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = FOVCircle

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1.5
stroke.Color = Color3.new(1, 1, 1)
stroke.Parent = FOVCircle

-- ============== TRACER ==============
local Tracer = Drawing.new("Line")
Tracer.Thickness = 1.5
Tracer.Color = Color3.fromRGB(255, 0, 0)
Tracer.Transparency = 0.7
Tracer.Visible = false

-- ============== LÓGICA SILENT AIM ==============
local Devv = require(ReplicatedStorage:WaitForChild("Devv"))
local load = Devv.load
local ClientGuns = load("ClientTools").ToolModules.ClientGuns
local ClientTools = load("ClientTools")

-- 🔥 FUNÇÃO DE WALL-CHECK (Raycast)
local function IsVisible(part)
    if not Settings.WallCheck then return true end
    if not part or not part:IsA("BasePart") then return false end
    if not LocalPlayer.Character then return false end

    local origin = Camera.CFrame.Position
    local direction = part.Position - origin

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {
        LocalPlayer.Character,
        part.Parent,
    }
    raycastParams.IgnoreWater = true

    local result = workspace:Raycast(origin, direction, raycastParams)

    if not result then return true end
    if result.Instance == part then return true end
    if result.Instance.Parent == part.Parent then return true end

    return false
end

-- Função para pegar inimigos
local function getEnemies()
    local enemies = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer 
           and player.Character 
           and player.Character:FindFirstChild("Humanoid") 
           and player.Character.Humanoid.Health > 0 
        then
            table.insert(enemies, player)
        end
    end
    return enemies
end

-- Função que calcula a direção mirada
local function getAimedDirection(originalCFrame, toolId, ownerId)
    if ownerId ~= LocalPlayer.UserId then return originalCFrame end
    if not Settings.Enabled then return originalCFrame end

    local muzzlePos = originalCFrame.Position
    local bestTarget = nil
    local bestDist = Settings.FOVRadius

    for _, enemy in ipairs(getEnemies()) do
        local head = enemy.Character and enemy.Character:FindFirstChild("Head")
        if head then
            if IsVisible(head) then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        bestTarget = head.Position
                    end
                end
            end
        end
    end

    return bestTarget and CFrame.lookAt(muzzlePos, bestTarget) or originalCFrame
end

-- Hook na função MakeGunProjectiles
local originalMakeGunProjectiles = ClientGuns.MakeGunProjectiles
ClientGuns.MakeGunProjectiles = function(ownerId, toolId, muzzleCFrame, projectilesData)
    local newProjectilesData = {}
    for _, proj in ipairs(projectilesData) do
        local projId = proj[1]
        local aimCFrame = proj[2]
        local newAimCFrame = getAimedDirection(aimCFrame, toolId, ownerId)
        table.insert(newProjectilesData, {projId, newAimCFrame})
    end
    return originalMakeGunProjectiles(ownerId, toolId, muzzleCFrame, newProjectilesData)
end

-- ============== ATUALIZAÇÃO DO FOV E TRACER ==============
local hue = 0

RunService.RenderStepped:Connect(function()
    FOVCircle.Visible = Settings.Enabled
    FOVCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
    FOVCircle.Size = UDim2.new(0, Settings.FOVRadius * 2, 0, Settings.FOVRadius * 2)
    
    hue = (hue + 0.005) % 1
    stroke.Color = Color3.fromHSV(hue, 1, 1)
    
    if Settings.Enabled then
        local bestTarget = nil
        local bestDist = Settings.FOVRadius
        
        for _, enemy in ipairs(getEnemies()) do
            local head = enemy.Character and enemy.Character:FindFirstChild("Head")
            if head then
                if IsVisible(head) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if dist < bestDist then
                            bestDist = dist
                            bestTarget = head.Position
                        end
                    end
                end
            end
        end
        
        if bestTarget then
            local targetScreenPos, onScreen = Camera:WorldToViewportPoint(bestTarget)
            if onScreen then
                Tracer.Visible = true
                local centerScreen = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                Tracer.From = centerScreen
                Tracer.To = Vector2.new(targetScreenPos.X, targetScreenPos.Y)
            else
                Tracer.Visible = false
            end
        else
            Tracer.Visible = false
        end
    else
        Tracer.Visible = false
    end
end)

-- ============== ABA SILENT AIM (UI) ==============
local silentGroup = Tabs.Silent:AddLeftGroupbox('Silent Aim')

silentGroup:AddToggle('SilentEnabled', {
    Text = 'Ativar Silent Aim',
    Default = true,
    Callback = function(v)
        Settings.Enabled = v
        print('Silent Aim:', v)
    end
})

silentGroup:AddSlider('FOVRadius', {
    Text = 'FOV Radius',
    Default = 180,
    Min = 20,
    Max = 300,
    Rounding = 0,
    Callback = function(v)
        Settings.FOVRadius = v
        print('FOV:', v)
    end
})

silentGroup:AddToggle('WallCheck', {
    Text = 'Wall Check',
    Default = true,
    Callback = function(v)
        Settings.WallCheck = v
        print('Wall-Check:', v)
    end
})

-- ============== ABA VISUAL (UI) ==============
local visualGroup = Tabs.Visual:AddLeftGroupbox('FOV & Tracer')

visualGroup:AddToggle('ShowFOV', {
    Text = 'Mostrar Círculo do FOV',
    Default = true,
    Callback = function(v)
        FOVCircle.Visible = v and Settings.Enabled
    end
})

visualGroup:AddToggle('ShowTracer', {
    Text = 'Mostrar Tracer',
    Default = true,
    Callback = function(v)
        if not v then Tracer.Visible = false end
    end
})

visualGroup:AddLabel('FOV Circle & Tracer são atualizados automaticamente'):AddColorPicker('FOVColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Cor do FOV',
    Callback = function(color)
        stroke.Color = color
    end
})

-- ============== SISTEMA DE CONFIGURAÇÃO E TEMAS ==============
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()

ThemeManager:SetFolder("SexHub")
SaveManager:SetFolder("SexHub")
SaveManager:SetSubFolder("SilentAim")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

SaveManager:LoadAutoloadConfig()

-- ============== NOTIFICAÇÃO DE CARREGAMENTO ==============
Library:Notify('✅ Silent Aim carregado com sucesso!', 5)

print('🔥 Silent Aim (Obsidian UI) carregado!')
print('🎯 Mira no inimigo mais próximo dentro do FOV!')
print('🧱 Wall-Check ATIVADO!')
print('👁️ ESP Module carregado com sucesso!')
