local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local IsPoolGame = game.PlaceId == 107430170196919
if not LocalPlayer then
    return
end

local PreviousController = rawget(_G, "CelvynAimController")
if type(PreviousController) == "table" and type(PreviousController.Cleanup) == "function" then
    pcall(function()
        PreviousController:Cleanup()
    end)
end

local Settings = {
    Enabled = false,
    TeamCheck = false,
    ShowFOV = false,
    AimPart = "Head",
    FOV = 135
}

local ESPSettings = {
    Enabled = not IsPoolGame,
    TeamCheck = false,
    TeamColor = false,
    MaxDistance = 1000,
    CornerLength = 0.28,
    BoxThickness = 1.5,
    DefaultColor = Color3.fromRGB(255, 255, 255),
    TextColor = Color3.fromRGB(245, 245, 250),
    HealthColor = true,
    ShowName = true,
    ShowDistance = true,
    ShowHealth = true,
    LineESP = false,
    LineOrigin = "Middle"
}

local Colors = {
    Accent = Color3.fromRGB(163, 143, 255),
    FOV = Color3.fromRGB(163, 143, 255)
}

local AimParts = {"Head", "UpperTorso", "HumanoidRootPart"}
local CurrentTarget = nil
local SelectionTimer = 0
local Camera = workspace.CurrentCamera
local FOVRing = nil
local Window = nil

pcall(function()
    FOVRing = Drawing.new("Circle")
    FOVRing.Visible = Settings.ShowFOV
    FOVRing.Thickness = 1.5
    FOVRing.Filled = false
    FOVRing.NumSides = 72
    FOVRing.Radius = Settings.FOV
    FOVRing.Color = Colors.FOV
    FOVRing.Transparency = 0.85
end)

local DrawingSupported = false
local testLine, testText
local drawingProbeOK = pcall(function()
    testLine = Drawing.new("Line")
    testText = Drawing.new("Text")
end)
if testLine then pcall(function() testLine:Remove() end) end
if testText then pcall(function() testText:Remove() end) end
DrawingSupported = drawingProbeOK and testLine ~= nil and testText ~= nil

local ESPObjects = {}
local ESPWasActive = false
local PoolObjects = {}

local function CreateLine()
    local Line = Drawing.new("Line")
    Line.Thickness = ESPSettings.BoxThickness
    Line.Transparency = 1
    Line.Visible = false
    return Line
end

local function CreateText(Size)
    local Text = Drawing.new("Text")
    Text.Size = Size
    Text.Center = true
    Text.Outline = true
    Text.OutlineColor = Color3.fromRGB(0, 0, 0)
    Text.Color = ESPSettings.TextColor
    Text.Visible = false
    return Text
end

local function BuildESPData()
    local Data = {
        Lines = {},
        HealthBackground = CreateLine(),
        HealthBar = CreateLine(),
        Username = CreateText(13),
        Distance = CreateText(12),
        HealthText = CreateText(12),
        Tracer = CreateLine(),
        Hidden = true,
        LastBoxColor = nil,
        LastBoxThickness = nil,
        LastNameText = nil,
        LastDistanceText = nil,
        LastHealthText = nil,
    }

    for i = 1, 8 do
        Data.Lines[i] = CreateLine()
    end

    Data.HealthBackground.Color = Color3.fromRGB(30, 30, 35)
    Data.HealthBackground.Thickness = 4
    Data.HealthBar.Thickness = 2
    Data.Tracer.Transparency = 0.9

    Data.All = {
        Data.HealthBackground, Data.HealthBar, Data.Username,
        Data.Distance, Data.HealthText, Data.Tracer,
    }
    for i = 1, #Data.Lines do
        Data.All[#Data.All + 1] = Data.Lines[i]
    end
    return Data
end

local function CreateESP(Player)
    if not DrawingSupported or ESPObjects[Player] then
        return
    end

    local ok, Data = pcall(BuildESPData)
    if ok and Data then
        ESPObjects[Player] = Data
    end
end

local function HideESP(Data)
    if not Data or Data.Hidden then
        return
    end
    Data.Hidden = true
    for i = 1, #Data.All do
        Data.All[i].Visible = false
    end
end

local function RemoveESP(Player)
    local Data = ESPObjects[Player]
    if not Data then
        return
    end

    for i = 1, #Data.All do
        local Object = Data.All[i]
        pcall(function()
            Object:Remove()
        end)
    end
    ESPObjects[Player] = nil
end

local function RemoveAllESP()
    for Player in pairs(ESPObjects) do
        RemoveESP(Player)
    end
end

local Controller = {
    Connections = {},
    Ring = FOVRing,
    Window = nil,
    Cleaned = false
}

function Controller:Cleanup(skipWindow)
    if self.Cleaned then
        return
    end
    self.Cleaned = true

    pcall(function()
        RunService:UnbindFromRenderStep("CelvynAimLock")
    end)
    local nativeGuidelineCleanup = rawget(_G, "CelvynNativeGuidelineCleanup")
    if type(nativeGuidelineCleanup) == "function" then
        pcall(nativeGuidelineCleanup)
    end

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(self.Connections)

    pcall(RemoveAllESP)
    for _, group in pairs(PoolObjects) do
        for _, object in pairs(group) do
            pcall(function()
                object.Visible = false
                object:Remove()
            end)
        end
    end
    table.clear(PoolObjects)

    if self.Ring then
        pcall(function()
            self.Ring.Visible = false
            self.Ring:Remove()
        end)
        self.Ring = nil
    end

    if not skipWindow and self.Window then
        pcall(function()
            self.Window:Destroy()
        end)
    end

    if rawget(_G, "CelvynAimController") == self then
        _G.CelvynAimController = nil
    end
end

_G.CelvynAimController = Controller

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IsStudio = RunService:IsStudio()
local ImGui

local libraryLoaded, libraryResult = pcall(function()
    if IsStudio then
        return require(ReplicatedStorage:WaitForChild("ImGui"))
    end

    local SourceURL = "https://raw.githubusercontent.com/4ozCy/imgui/refs/heads/main/ImGui.lua"
    return loadstring(game:HttpGet(SourceURL))()
end)

if not libraryLoaded or type(libraryResult) ~= "table" then
    warn("ImGui could not be loaded.")
    Controller:Cleanup(true)
    return
end

ImGui = libraryResult
ImGui.CreateMobileButton = nil

local windowLoaded, windowError = pcall(function()
    Window = ImGui:CreateWindow({
        Title = "AIMBOT.gpt & ESP.claude",
        Size = UDim2.new(0, 420, 0, 470),
        Position = UDim2.new(0.5, 0, 0, 70),
        MobileButton = false,
    })
    assert(Window, "CreateWindow returned nil")
    Controller.Window = Window
    if type(Window.Center) == "function" then
        Window:Center()
    end
end)

if not windowLoaded or not Window then
    warn("ImGui window creation failed: " .. tostring(windowError))
    Controller:Cleanup(true)
    return
end

Controller.Window = Window

local AimTab, ESPTab, PoolTab
local tabsLoaded, tabsError = pcall(function()
    if IsPoolGame then
        PoolTab = Window:CreateTab({Name = "Pool"})
        assert(PoolTab, "CreateTab returned nil for Pool")
        Window:ShowTab(PoolTab)
    else
        AimTab = Window:CreateTab({Name = "Aimbot"})
        ESPTab = Window:CreateTab({Name = "ESP"})
        assert(AimTab, "CreateTab returned nil for Aimbot")
        assert(ESPTab, "CreateTab returned nil for ESP")
        Window:ShowTab(AimTab)
    end
end)

if not tabsLoaded then
    warn("ImGui tab creation failed: " .. tostring(tabsError))
    Controller:Cleanup()
    return
end

if not IsPoolGame then
AimTab:Checkbox({
    Label = "Enable Aimbot",
    Value = Settings.Enabled,
    Callback = function(_, value)
        Settings.Enabled = value == true
        if not Settings.Enabled then
            CurrentTarget = nil
            SelectionTimer = 0
        end
    end,
})

AimTab:Combo({
    Label = "Aim Part",
    Selected = Settings.AimPart,
    Items = AimParts,
    Callback = function(_, value)
        if table.find(AimParts, value) then
            Settings.AimPart = value
            CurrentTarget = nil
            SelectionTimer = 0
        end
    end,
})



AimTab:Checkbox({
    Label = "Team Check",
    Value = Settings.TeamCheck,
    Callback = function(_, value)
        Settings.TeamCheck = value == true
        CurrentTarget = nil
        SelectionTimer = 0
    end,
})

AimTab:Button({
    Text = "Clear Current Target",
    Callback = function()
        CurrentTarget = nil
        SelectionTimer = 0
    end,
})

AimTab:Keybind({
    Label = "Toggle UI",
    Value = Enum.KeyCode.RightControl,
    Callback = function()
        Window:SetVisible(not Window.Visible)
    end,
})

AimTab:Checkbox({
    Label = "Show FOV",
    Value = Settings.ShowFOV,
    Callback = function(_, value)
        Settings.ShowFOV = value == true
        if FOVRing then
            pcall(function()
                FOVRing.Visible = Settings.ShowFOV
            end)
        end
    end,
})

AimTab:Slider({
    Label = "FOV Radius",
    Value = Settings.FOV,
    MinValue = 35,
    MaxValue = 300,
    Format = "%.0f",
    ReadOnly = false,
    Callback = function(_, value)
        local number = tonumber(value)
        if number then
            Settings.FOV = math.clamp(math.floor(number + 0.5), 35, 300)
            if FOVRing then
                pcall(function()
                    FOVRing.Radius = Settings.FOV
                end)
            end
        end
    end,
})

local FOVColors = {
    Purple = Color3.fromRGB(163, 143, 255),
    White = Color3.fromRGB(255, 255, 255),
    Cyan = Color3.fromRGB(80, 220, 255),
    Red = Color3.fromRGB(255, 80, 80),
    Green = Color3.fromRGB(80, 255, 120),
    Yellow = Color3.fromRGB(255, 220, 80),
}

AimTab:Combo({
    Label = "FOV Color",
    Selected = "White",
    Items = FOVColors,
    Callback = function(_, color)
        if typeof(color) == "Color3" then
            Colors.FOV = color
            if FOVRing then
                pcall(function()
                    FOVRing.Color = color
                end)
            end
        end
    end,
})

ESPTab:Checkbox({
    Label = "Enable ESP",
    Value = ESPSettings.Enabled,
    Callback = function(_, value)
        ESPSettings.Enabled = value == true
    end,
})

ESPTab:Slider({
    Label = "Distance",
    Value = ESPSettings.MaxDistance,
    MinValue = 100,
    MaxValue = 5000,
    Format = "%.0f",
    ReadOnly = false,
    Callback = function(_, value)
        local number = tonumber(value)
        if number then
            ESPSettings.MaxDistance = math.clamp(math.floor(number + 0.5), 100, 5000)
        end
    end,
})

ESPTab:Checkbox({
    Label = "Team Check",
    Value = ESPSettings.TeamCheck,
    Callback = function(_, value)
        ESPSettings.TeamCheck = value == true
    end,
})

ESPTab:Checkbox({
    Label = "Team Colors",
    Value = ESPSettings.TeamColor,
    Callback = function(_, value)
        ESPSettings.TeamColor = value == true
    end,
})

ESPTab:Checkbox({
    Label = "Names",
    Value = ESPSettings.ShowName,
    Callback = function(_, value)
        ESPSettings.ShowName = value == true
    end,
})

ESPTab:Checkbox({
    Label = "Distance",
    Value = ESPSettings.ShowDistance,
    Callback = function(_, value)
        ESPSettings.ShowDistance = value == true
    end,
})

ESPTab:Checkbox({
    Label = "Health Bar",
    Value = ESPSettings.ShowHealth,
    Callback = function(_, value)
        ESPSettings.ShowHealth = value == true
    end,
})

ESPTab:Checkbox({
    Label = "Health Colors",
    Value = ESPSettings.HealthColor,
    Callback = function(_, value)
        ESPSettings.HealthColor = value == true
    end,
})

ESPTab:Checkbox({
    Label = "Line ESP",
    Value = ESPSettings.LineESP,
    Callback = function(_, value)
        ESPSettings.LineESP = value == true
    end,
})

ESPTab:Combo({
    Label = "Line Origin",
    Selected = ESPSettings.LineOrigin,
    Items = {"Top", "Bottom", "Middle"},
    Callback = function(_, value)
        if value == "Top" or value == "Bottom" or value == "Middle" then
            ESPSettings.LineOrigin = value
        end
    end,
})


ESPTab:Slider({
    Label = "Corner Length (%)",
    Value = math.floor(ESPSettings.CornerLength * 100 + 0.5),
    MinValue = 10,
    MaxValue = 50,
    Format = "%.0f",
    ReadOnly = false,
    Callback = function(_, value)
        local number = tonumber(value)
        if number then
            ESPSettings.CornerLength = math.clamp(math.floor(number + 0.5), 10, 50) / 100
        end
    end,
})

local BoxColors = {
    White = Color3.fromRGB(255, 255, 255),
    Purple = Color3.fromRGB(163, 143, 255),
    Cyan = Color3.fromRGB(80, 220, 255),
    Red = Color3.fromRGB(255, 80, 80),
    Green = Color3.fromRGB(80, 255, 120),
    Yellow = Color3.fromRGB(255, 220, 80),
}

ESPTab:Combo({
    Label = "Box Color",
    Selected = "White",
    Items = BoxColors,
    Callback = function(_, selection)
        local color = selection
        if typeof(selection) ~= "Color3" then
            color = BoxColors[tostring(selection)]
        end
        if typeof(color) == "Color3" then
            ESPSettings.DefaultColor = color
        end
    end,
})


end

-- Native target-ball line length + physics-verified pocket highlight.
-- Prediction uses the game's own ShotFinder and Simulation modules. It never changes aim or fires.
-- Detection fix: validate the simulator's actual first-contact target and remove the geometric-angle hard cutoff.
local PoolSettings = {
    Enabled = false,
    HighlightEnabled = true,
    GuidelineScale = 3.0,
}

local NativeGuidelineCandidates = {}
local ActiveNativeGuideline = nil
local NativeGuidelineLastScan = 0
local NativeGuidelineLastSelection = 0
local NativeGuidelineState = setmetatable({}, { __mode = "k" })
local NativeGuidelineScanInterval = 1.0
local PocketPrediction = {
    Busy = false,
    LastCheck = 0,
    LastSignature = nil,
    Verified = false,
    TargetBall = nil,
    Pocket = nil,
    Power = nil,
    LastError = nil,
    LastNotifiedTarget = nil,
    LastNotifiedPocket = nil,
    LastNotifiedPower = nil,
    LastNotificationTime = 0,
    Interval = 0.08, -- quick response; expensive work still runs in a worker
}

local VERIFIED_LINE_COLOR = Color3.fromRGB(55, 255, 110)

local function scanNativeGuidelines()
    local found = {}
    local visuals = workspace:FindFirstChild("ClientVisuals")
    local root = visuals or workspace
    for _, instance in ipairs(root:GetDescendants()) do
        if instance:IsA("BasePart") and instance.Name == "ObjectStub" then
            table.insert(found, instance)
        end
    end
    NativeGuidelineCandidates = found
    NativeGuidelineLastScan = os.clock()
end

local function chooseNativeGuideline()
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    if os.clock() - NativeGuidelineLastScan >= NativeGuidelineScanInterval then
        scanNativeGuidelines()
    end
    local best, bestDistance
    for _, part in ipairs(NativeGuidelineCandidates) do
        if part and part.Parent then
            local distance = (part.Position - camera.CFrame.Position).Magnitude
            if not bestDistance or distance < bestDistance then
                best, bestDistance = part, distance
            end
        end
    end
    return best
end

local function getNativePartBaseline(part)
    local state = NativeGuidelineState[part]
    if not state then
        state = {
            baseSize = part.Size,
            baseCFrame = part.CFrame,
            baseColor = part.Color,
            appliedSize = nil,
            appliedCFrame = nil,
            appliedColor = nil,
        }
        NativeGuidelineState[part] = state
    else
        -- The game rewrites the guideline during its own render update. Treat
        -- values different from ours as the game's newest baseline.
        if state.appliedSize and (part.Size ~= state.appliedSize or part.CFrame ~= state.appliedCFrame) then
            state.baseSize = part.Size
            state.baseCFrame = part.CFrame
            state.appliedSize = nil
            state.appliedCFrame = nil
        end
        if state.appliedColor and part.Color ~= state.appliedColor then
            state.baseColor = part.Color
            state.appliedColor = nil
        end
    end
    return state
end

local function restoreNativeGuideline(part)
    if not part then return end
    local state = NativeGuidelineState[part]
    if state then
        if part.Parent then
            pcall(function()
                if state.appliedSize and part.Size == state.appliedSize
                    and part.CFrame == state.appliedCFrame then
                    part.Size = state.baseSize
                    part.CFrame = state.baseCFrame
                end
                if state.appliedColor and part.Color == state.appliedColor then
                    part.Color = state.baseColor
                end
            end)
        end
        NativeGuidelineState[part] = nil
    end
end

local function extendNativeGuideline(part)
    if not part or not part.Parent or not part:IsA("BasePart") or part.Name ~= "ObjectStub" then return end
    local state = getNativePartBaseline(part)
    local originalLength = state.baseSize.Z
    if not originalLength or originalLength <= 0.001 then return end
    local scale = math.clamp(tonumber(PoolSettings.GuidelineScale) or 3.0, 1.0, 20.0)
    local targetSize = Vector3.new(state.baseSize.X, state.baseSize.Y, originalLength * scale)
    local targetCFrame = state.baseCFrame + state.baseCFrame.ZVector * (originalLength * (scale - 1.0) * 0.5)
    pcall(function()
        part.Size = targetSize
        part.CFrame = targetCFrame
    end)
    state.appliedSize = targetSize
    state.appliedCFrame = targetCFrame
end

local function setNativeGuidelineVerified(part, verified)
    if not part or not part.Parent or not part:IsA("BasePart") then return end
    local state = getNativePartBaseline(part)
    if verified then
        pcall(function() part.Color = VERIFIED_LINE_COLOR end)
        state.appliedColor = VERIFIED_LINE_COLOR
    else
        if state.appliedColor then
            pcall(function()
                if part.Color == state.appliedColor then part.Color = state.baseColor end
            end)
            state.appliedColor = nil
        end
    end
end

_G.CelvynNativeGuidelineCleanup = function()
    PoolSettings.Enabled = false
    PoolSettings.HighlightEnabled = false
    restoreNativeGuideline(ActiveNativeGuideline)
    ActiveNativeGuideline = nil
    _G.CelvynNativeGuidelineCleanup = nil
end

local updatePocketPrediction

if IsPoolGame then
    PoolTab:Checkbox({
        Label = "Extend Target Ball Line",
        Value = PoolSettings.Enabled,
        Callback = function(_, value)
            PoolSettings.Enabled = value == true
            if PoolSettings.Enabled then
                NativeGuidelineLastScan = 0
                scanNativeGuidelines()
            else
                -- Reset the stretched part to the game's current size. If the
                -- highlight remains enabled, the renderer will select it again.
                restoreNativeGuideline(ActiveNativeGuideline)
                ActiveNativeGuideline = nil
                NativeGuidelineLastScan = 0
                if PoolSettings.HighlightEnabled then scanNativeGuidelines() end
            end
        end,
    })

    PoolTab:Slider({
        Label = "Target Ball Line Length (%)",
        Value = 300,
        MinValue = 100,
        MaxValue = 2000,
        Format = "%.0f%%",
        ReadOnly = false,
        Callback = function(_, value)
            local number = tonumber(value)
            if number then
                PoolSettings.GuidelineScale = math.clamp(number / 100, 1.0, 20.0)
            end
        end,
    })

    PoolTab:Checkbox({
        Label = "Auto Highlight Simulated Pocket",
        Value = PoolSettings.HighlightEnabled,
        Callback = function(_, value)
            PoolSettings.HighlightEnabled = value == true
            PocketPrediction.LastSignature = nil
            PocketPrediction.Verified = false
            setNativeGuidelineVerified(ActiveNativeGuideline, false)
            if PoolSettings.HighlightEnabled then
                NativeGuidelineLastScan = 0
                scanNativeGuidelines()
            elseif not PoolSettings.Enabled then
                restoreNativeGuideline(ActiveNativeGuideline)
                ActiveNativeGuideline = nil
            end
        end,
    })

    local function getRuntimeMethod(object, methodName)
        if type(object) ~= "table" then return nil end
        local direct = rawget(object, methodName)
        if type(direct) == "function" then return direct end
        local mt
        if type(getrawmetatable) == "function" then
            pcall(function() mt = getrawmetatable(object) end)
        end
        if not mt then pcall(function() mt = getmetatable(object) end) end
        if type(mt) == "table" then
            local index = mt.__index
            if type(index) == "table" and type(index[methodName]) == "function" then
                return index[methodName]
            elseif type(index) == "function" then
                local ok, result = pcall(index, object, methodName)
                if ok and type(result) == "function" then return result end
            end
        end
        return nil
    end

    local CachedPoolHub, CachedPoolInput
    local LastRuntimeScan = 0
    local RuntimeRescanInterval = 3.0

    local function scanPoolRuntime()
        -- Reuse discovered objects instead of walking every GC object on each prediction.
        local now = os.clock()
        if CachedPoolHub and CachedPoolInput and now - LastRuntimeScan < RuntimeRescanInterval then
            local tableId = CachedPoolHub.mySeat
            local snapshot = tableId and CachedPoolHub.snapshots and CachedPoolHub.snapshots[tableId]
            local match = tableId and CachedPoolHub.matches and CachedPoolHub.matches[tableId]
            if snapshot and match and type(match.state) == "table"
                and snapshot.shooter == LocalPlayer.UserId
                and (snapshot.phase == "Aiming" or snapshot.phase == "Intro")
                and type(match.state.balls) == "table" and type(match.state.geometry) == "table" then
                return CachedPoolHub, CachedPoolInput, {
                    tableId = tableId, snapshot = snapshot, match = match, state = match.state,
                }
            end
        end
        LastRuntimeScan = now
        if type(getgc) ~= "function" then return nil, nil, nil end
        local ok, objects = pcall(getgc, true)
        if not ok or type(objects) ~= "table" then return nil, nil, nil end
        local hub, input
        for _, object in pairs(objects) do
            if type(object) ~= "table" then continue end
            if not hub and type(rawget(object, "matches")) == "table"
                and type(rawget(object, "snapshots")) == "table"
                and type(rawget(object, "boundTo")) == "table"
                and type(rawget(object, "cueOf")) == "table" then
                hub = object
            end
            if not input and type(rawget(object, "angle")) == "number"
                and type(rawget(object, "aimListeners")) == "table"
                and type(rawget(object, "spinListeners")) == "table"
                and type(rawget(object, "elevationListeners")) == "table"
                and type(rawget(object, "enabled")) == "boolean"
                and getRuntimeMethod(object, "setAngle")
                and getRuntimeMethod(object, "setSpin")
                and getRuntimeMethod(object, "setElevation") then
                input = object
            end
            if hub and input then break end
        end
        if not hub or not input then return hub, input, nil end
        CachedPoolHub, CachedPoolInput = hub, input
        local tableId = hub.mySeat
        local snapshot = tableId and hub.snapshots[tableId]
        local match = tableId and hub.matches[tableId]
        if not snapshot or not match or type(match.state) ~= "table" then return hub, input, nil end
        if snapshot.shooter ~= LocalPlayer.UserId then return hub, input, nil end
        if snapshot.phase ~= "Aiming" and snapshot.phase ~= "Intro" then return hub, input, nil end
        if type(match.state.balls) ~= "table" or type(match.state.geometry) ~= "table" then return hub, input, nil end
        return hub, input, {
            tableId = tableId,
            snapshot = snapshot,
            match = match,
            state = match.state,
        }
    end

    local function getPoolModules()
        local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
        if not shared then return nil end
        local bots = shared:FindFirstChild("Bots")
        local physics = shared:FindFirstChild("Physics")
        local finderModule = bots and bots:FindFirstChild("ShotFinder")
        local simulationModule = physics and physics:FindFirstChild("Simulation")
        local configModule = shared:FindFirstChild("Config")
        if not finderModule or not simulationModule or not configModule then return nil end
        local okFinder, finder = pcall(require, finderModule)
        local okSimulation, simulation = pcall(require, simulationModule)
        local okConfig, config = pcall(require, configModule)
        if not okFinder or type(finder) ~= "table" or type(finder.candidates) ~= "function"
            or type(finder.calibrate) ~= "function" then return nil end
        if not okSimulation or type(simulation) ~= "table" or type(simulation.runHeadless) ~= "function" then return nil end
        if not okConfig or type(config) ~= "table" then return nil end
        return finder, simulation, config
    end

    local function findBallById(balls, id)
        for _, ball in ipairs(balls) do
            if ball.id == id then return ball end
        end
        return nil
    end

    local function angleDifference(a, b)
        return math.atan2(math.sin(a - b), math.cos(a - b))
    end

    local function readShotSpin(input)
        local spin = input.spin or input.spinOffset or input.Spin
        if type(spin) == "table" then
            return {
                x = tonumber(spin.x or spin.X) or 0,
                y = tonumber(spin.y or spin.Y) or 0,
            }
        elseif typeof(spin) == "Vector2" then
            return { x = spin.X, y = spin.Y }
        end
        return {
            x = tonumber(input.spinX or input.SpinX) or 0,
            y = tonumber(input.spinY or input.SpinY) or 0,
        }
    end

    local function getTargetIds(finder, planningState, state)
        if type(finder.ownIds) == "function" then
            local ok, ids = pcall(finder.ownIds, planningState)
            if ok and type(ids) == "table" and #ids > 0 then return ids end
        end
        local ids = {}
        for _, ball in ipairs(state.balls) do
            if not ball.pocketed and ball.id ~= 0 and ball.id ~= 8 then
                table.insert(ids, ball.id)
            end
        end
        if #ids == 0 then
            for _, ball in ipairs(state.balls) do
                if not ball.pocketed and ball.id ~= 0 then table.insert(ids, ball.id) end
            end
        end
        return ids
    end

    local function predictionSignature(runtime, input)
        local state = runtime.state
        local parts = {
            tostring(math.floor((tonumber(input.angle) or 0) * 1000 + 0.5)),
            tostring(math.floor((tonumber(input.power) or -1) * 100 + 0.5)),
            tostring(math.floor((tonumber(input.elevation) or 0) * 10 + 0.5)),
            tostring(runtime.tableId or "table"),
            tostring(state.geometry),
        }
        local spin = readShotSpin(input)
        table.insert(parts, tostring(math.floor(spin.x * 100 + 0.5)))
        table.insert(parts, tostring(math.floor(spin.y * 100 + 0.5)))
        for _, ball in ipairs(state.balls) do
            table.insert(parts, tostring(ball.id))
            table.insert(parts, ball.pocketed and "p" or "-" )
            table.insert(parts, tostring(math.floor((tonumber(ball.x) or 0) * 100 + 0.5)))
            table.insert(parts, tostring(math.floor((tonumber(ball.y) or 0) * 100 + 0.5)))
            table.insert(parts, tostring(math.floor((tonumber(ball.vx) or 0) * 100 + 0.5)))
            table.insert(parts, tostring(math.floor((tonumber(ball.vy) or 0) * 100 + 0.5)))
        end
        return table.concat(parts, ":")
    end

    local function simulateCurrentAngle(simulation, state, input, config, candidate, validTargetIds, power, spin, elevation)
        local minPower = tonumber(config.Input and config.Input.MinPowerToShoot) or 0.04
        power = math.clamp(tonumber(power) or minPower, minPower, 1)
        local ok, result = pcall(simulation.runHeadless, {
            geometry = state.geometry,
            balls = state.balls,
            time = 0,
            overrides = state.overrides,
            fx = state.fx,
        }, {
            angle = input.angle,
            power = power,
            spin = spin,
            elevation = elevation,
        })
        if not ok or type(result) ~= "table" or type(result.finalBalls) ~= "table" then
            return false
        end
        -- A capped run has not fully settled, so do not mark it as verified.
        if result.capped == true or result.halted == true then return false end
        local cueBall = findBallById(result.finalBalls, 0)
        -- Use the simulator's actual first contact. ShotFinder candidates are
        -- geometric hints, so insisting on the nearest candidate can suppress
        -- valid bank shots, cut shots, or contacts near candidate-angle boundaries.
        local firstContactId = result.firstContact
        if firstContactId == nil or firstContactId == 0 then return false end
        if not validTargetIds[firstContactId] and not validTargetIds[tostring(firstContactId)] then return false end
        local actualTarget = findBallById(result.finalBalls, firstContactId)
        if not actualTarget or actualTarget.pocketed ~= true then return false end
        if cueBall and cueBall.pocketed == true then return false end
        if actualTarget.pocket == nil then return false end
        return true, actualTarget.pocket, firstContactId, power
    end

    local function calculateCurrentPocketPrediction(hub, input, runtime)
        local finder, simulation, config = getPoolModules()
        if not finder then return false end
        local state = runtime.state
        local cueBall = findBallById(state.balls, 0)
        if not cueBall or cueBall.pocketed or type(input.angle) ~= "number" then return false end
        local planningState = {
            geometry = state.geometry,
            balls = state.balls,
            groups = runtime.snapshot.groups or {},
            team = runtime.snapshot.activeTeam or 1,
            phase = nil,
        }
        local targetIds = getTargetIds(finder, planningState, state)
        if #targetIds == 0 then return false end
        local validTargetIds = {}
        for _, id in ipairs(targetIds) do
            validTargetIds[id] = true
            validTargetIds[tostring(id)] = true
        end
        local okCandidates, candidates = pcall(finder.candidates, planningState, cueBall.x, cueBall.y, targetIds)
        if not okCandidates or type(candidates) ~= "table" or #candidates == 0 then return false end

        -- Only evaluate the candidate nearest the player's existing aim angle.
        -- The user's angle is passed unchanged to Simulation.runHeadless.
        local nearest, nearestDelta
        for _, candidate in ipairs(candidates) do
            if type(candidate.angle) == "number" then
                local delta = math.abs(angleDifference(input.angle, candidate.angle))
                if not nearestDelta or delta < nearestDelta then
                    nearest, nearestDelta = candidate, delta
                end
            end
        end
        if not nearest then return false end
        -- Do not hard-reject based on candidate-angle difference. The actual
        -- current angle is tested by runHeadless; the candidate is used only
        -- to seed the power search. This avoids missed detections for cut/bank shots.

        local spin = readShotSpin(input)
        local elevation = tonumber(input.elevation) or tonumber(config.Cue and config.Cue.CueElevationDegrees) or 0
        local minPower = tonumber(config.Input and config.Input.MinPowerToShoot) or 0.04
        local activePower = tonumber(input.power)
        local powers = {}
        local maxPower = tonumber(config.Bots and config.Bots.Finder and config.Bots.Finder.MaxPower) or 0.85
        if activePower and activePower > (minPower + 0.005) then
            -- Only treat power as actively selected when it is above the idle/minimum
            -- value. Lua treats 0 as truthy, so a plain `if activePower` can accidentally
            -- reduce every idle prediction to a single minimum-power simulation.
            powers[1] = math.clamp(activePower, minPower, 1)
        else
            local basePower
            if nearest and type(finder.calibrate) == "function" then
                local calibratedOk, calibrated = pcall(finder.calibrate, planningState, nearest)
                if calibratedOk and calibrated == true and type(nearest.power) == "number" then
                    basePower = nearest.power
                end
            end
            -- If ShotFinder cannot calibrate this angle, still evaluate the current
            -- physical shot at a reasonable fallback power instead of silently failing.
            basePower = math.clamp(tonumber(basePower) or (maxPower * 0.65), minPower, maxPower)
            -- Search a wider range around the calibrated power. The simulator
            -- checks the actual current aim angle for every power value.
            -- Yield between complete simulations so this batch does not monopolize
            -- the executor thread. A single runHeadless call itself is synchronous.
            local offsets = { 0, -0.025, 0.025, -0.05, 0.05, -0.085, 0.085, -0.13, 0.13 }
            for _, offset in ipairs(offsets) do
                table.insert(powers, math.clamp(basePower + offset, minPower, maxPower))
            end
        end

        local tested = {}
        local simulationCount = 0

        -- Keep the shared game physics module untouched. Mutating Simulation.step
        -- globally can interfere with live gameplay and may fail if runHeadless
        -- captured a local reference to step. Yield between independent trials.

        local predictionFound = nil
        for _, power in ipairs(powers) do
            local duplicate = false
            for _, oldPower in ipairs(tested) do
                if math.abs(oldPower - power) < 0.005 then duplicate = true break end
            end
            if not duplicate then
                table.insert(tested, power)
                simulationCount += 1
                local success, pocket, targetId, testedPower = simulateCurrentAngle(
                    simulation, state, input, config, nearest, validTargetIds, power, spin, elevation
                )
                if success then
                    predictionFound = { targetId, pocket, testedPower }
                    break
                end
                -- Yield between independent trials so the game can process input/render work.
                if simulationCount < #powers then task.wait(0.005) end
            end
        end

        if predictionFound then
            return true, predictionFound[1], predictionFound[2], predictionFound[3]
        end
        return false
    end

    updatePocketPrediction = function()
        if PocketPrediction.Busy or not PoolSettings.HighlightEnabled then return end
        local now = os.clock()
        if now - PocketPrediction.LastCheck < PocketPrediction.Interval then return end
        PocketPrediction.LastCheck = now

        local hub, input, runtime = scanPoolRuntime()
        if not runtime or not input or input.spinEditing then
            PocketPrediction.LastSignature = nil
            PocketPrediction.Verified = false
            PocketPrediction.TargetBall = nil
            PocketPrediction.Pocket = nil
            PocketPrediction.Power = nil
            setNativeGuidelineVerified(ActiveNativeGuideline, false)
            return
        end
        local signature = predictionSignature(runtime, input)
        if signature == PocketPrediction.LastSignature then
            setNativeGuidelineVerified(ActiveNativeGuideline, PocketPrediction.Verified)
            return
        end
        PocketPrediction.LastSignature = signature
        PocketPrediction.Busy = true
        task.spawn(function()
            local ok, verified, targetId, pocket, power = pcall(calculateCurrentPocketPrediction, hub, input, runtime)
            if ok then
                PocketPrediction.Verified = verified == true
                PocketPrediction.TargetBall = targetId
                PocketPrediction.Pocket = pocket
                PocketPrediction.Power = power
                PocketPrediction.LastError = nil
            else
                PocketPrediction.Verified = false
                PocketPrediction.TargetBall = nil
                PocketPrediction.Pocket = nil
                PocketPrediction.Power = nil
                PocketPrediction.LastError = tostring(verified)
                warn("[Pool Pocket Highlight] Prediction failed: " .. tostring(verified))
            end
            PocketPrediction.Busy = false
            setNativeGuidelineVerified(ActiveNativeGuideline, PocketPrediction.Verified)

            -- Notify only when a useful recommendation appears or materially
            -- changes; the aim angle updates frequently, so avoid toast spam.
            if PocketPrediction.Verified and type(PocketPrediction.Power) == "number" then
                local powerChanged = not PocketPrediction.LastNotifiedPower
                    or math.abs(PocketPrediction.Power - PocketPrediction.LastNotifiedPower) >= 0.03
                local targetChanged = PocketPrediction.TargetBall ~= PocketPrediction.LastNotifiedTarget
                local pocketChanged = PocketPrediction.Pocket ~= PocketPrediction.LastNotifiedPocket
                local nowNotify = os.clock()
                if (powerChanged or targetChanged or pocketChanged)
                    and nowNotify - (PocketPrediction.LastNotificationTime or 0) >= 2.0 then
                    local powerPercent = math.floor(PocketPrediction.Power * 100 + 0.5)
                    local targetText = PocketPrediction.TargetBall ~= nil and ("Ball " .. tostring(PocketPrediction.TargetBall)) or "Target ball"
                    local pocketText = PocketPrediction.Pocket ~= nil and ("Pocket " .. tostring(PocketPrediction.Pocket)) or "pocket"
                    pcall(function()
                        StarterGui:SetCore("SendNotification", {
                            Title = "Pool Shot Power",
                            Text = string.format("%s -> %s | Suggested power: %d%%. Physics estimate, not a guarantee.", targetText, pocketText, powerPercent),
                            Duration = 4,
                        })
                    end)
                    PocketPrediction.LastNotifiedTarget = PocketPrediction.TargetBall
                    PocketPrediction.LastNotifiedPocket = PocketPrediction.Pocket
                    PocketPrediction.LastNotifiedPower = PocketPrediction.Power
                    PocketPrediction.LastNotificationTime = nowNotify
                end
            end
        end)
    end
end

local HumanoidCache = setmetatable({}, { __mode = "k" })
local RootPartCache = setmetatable({}, { __mode = "k" })
local AimPartCache = setmetatable({}, { __mode = "k" })
local HeadCache = setmetatable({}, { __mode = "k" })

local RootPartNames = {"HumanoidRootPart", "RootPart", "LowerTorso", "Torso", "UpperTorso"}
local AimPartFallbacks = {"Head", "HumanoidRootPart", "RootPart", "UpperTorso", "Torso", "LowerTorso"}

local function getHumanoid(character)
    if not character then
        return nil
    end

    local cached = HumanoidCache[character]
    if cached and cached.Parent then
        return cached
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        humanoid = character:FindFirstChildWhichIsA("Humanoid", true)
    end
    if humanoid then
        HumanoidCache[character] = humanoid
    end
    return humanoid
end

local function isPlayerTarget(target)
    return typeof(target) == "Instance" and target:IsA("Player")
end

local function getTargetCharacter(target)
    if isPlayerTarget(target) then
        return target.Character
    end
    if typeof(target) == "Instance" and target:IsA("Model") then
        return target
    end
    return nil
end

local function getTargetName(target)
    if isPlayerTarget(target) then
        return target.DisplayName .. "  @" .. target.Name
    end
    return target and target.Name or "NPC"
end

local function getRootPart(character)
    if not character then
        return nil
    end

    local cached = RootPartCache[character]
    if cached and cached:IsA("BasePart") and cached:IsDescendantOf(character) then
        return cached
    end

    for i = 1, #RootPartNames do
        local name = RootPartNames[i]
        local part = character:FindFirstChild(name) or character:FindFirstChild(name, true)
        if part and part:IsA("BasePart") then
            RootPartCache[character] = part
            return part
        end
    end

    if character:IsA("Model") then
        local primary = character.PrimaryPart
        if primary and primary:IsA("BasePart") and primary:IsDescendantOf(character) then
            RootPartCache[character] = primary
            return primary
        end
    end
    return nil
end

local function getHeadPart(character)
    if not character then
        return nil
    end
    local cached = HeadCache[character]
    if cached and cached:IsA("BasePart") and cached:IsDescendantOf(character) then
        return cached
    end
    local head = character:FindFirstChild("Head") or character:FindFirstChild("Head", true)
    if head and head:IsA("BasePart") then
        HeadCache[character] = head
        return head
    end
    return nil
end

local function getAimPart(character)
    if not character then
        return nil
    end

    local cached = AimPartCache[character]
    if cached and cached.Name == Settings.AimPart and cached.Part
        and cached.Part:IsA("BasePart") and cached.Part:IsDescendantOf(character) then
        return cached.Part
    end

    local preferred = character:FindFirstChild(Settings.AimPart) or character:FindFirstChild(Settings.AimPart, true)
    if not (preferred and preferred:IsA("BasePart")) then
        preferred = nil
        for i = 1, #AimPartFallbacks do
            local part = character:FindFirstChild(AimPartFallbacks[i]) or character:FindFirstChild(AimPartFallbacks[i], true)
            if part and part:IsA("BasePart") then
                preferred = part
                break
            end
        end
    end
    preferred = preferred or getRootPart(character)
    AimPartCache[character] = {Name = Settings.AimPart, Part = preferred}
    return preferred
end

local function BuildAimContext()
    Camera = workspace.CurrentCamera or Camera
    if not Camera then
        return nil
    end

    local character = LocalPlayer.Character
    local humanoid = getHumanoid(character)
    local root = getRootPart(character)
    if not humanoid or humanoid.Health <= 0 or not root then
        return nil
    end

    local viewport = Camera.ViewportSize
    return {
        Camera = Camera,
        LocalRoot = root,
        LocalTeam = LocalPlayer.Team,
        CenterX = viewport.X * 0.5,
        CenterY = viewport.Y * 0.5,
        FOVSquared = Settings.FOV * Settings.FOV,
    }
end

local NPCCache = setmetatable({}, {__mode = "k"})

local function RefreshNPCCache()
    if IsPoolGame then return end
    local found = {}
    for _, instance in ipairs(workspace:GetDescendants()) do
        if instance:IsA("Model") and not Players:GetPlayerFromCharacter(instance) then
            local humanoid = getHumanoid(instance)
            if humanoid and humanoid.Health > 0 and getRootPart(instance) then
                found[instance] = true
            end
        end
    end
    for model in pairs(NPCCache) do
        if not found[model] or not model.Parent then
            NPCCache[model] = nil
        end
    end
    for model in pairs(found) do
        NPCCache[model] = true
    end
end

task.spawn(function()
    while not Controller.Cleaned do
        pcall(RefreshNPCCache)
        task.wait(2)
    end
end)

local function isValidTarget(target, context)
    if not target or not context then
        return false
    end
    if isPlayerTarget(target) and target == LocalPlayer then
        return false
    end

    local character = getTargetCharacter(target)
    if not character or not character.Parent then
        return false
    end

    if isPlayerTarget(target) then
        if target.Character ~= character then
            return false
        end
        if Settings.TeamCheck and context.LocalTeam ~= nil and target.Team == context.LocalTeam then
            return false
        end
    elseif not target:IsA("Model") or Players:GetPlayerFromCharacter(character) then
        return false
    end

    local humanoid = getHumanoid(character)
    if not humanoid or humanoid.Health <= 0 then
        return false
    end
    local aimPart = getAimPart(character)
    if not aimPart then
        return false
    end

    local screenPoint, onScreen = context.Camera:WorldToViewportPoint(aimPart.Position)
    if not onScreen or screenPoint.Z <= 0 then
        return false
    end

    local dx = screenPoint.X - context.CenterX
    local dy = screenPoint.Y - context.CenterY
    local distanceSquared = dx * dx + dy * dy
    if distanceSquared > context.FOVSquared then
        return false
    end
    return true, distanceSquared, aimPart
end

local function getClosestTarget(context)
    local bestTarget, bestAimPart
    local bestDistanceSquared = math.huge

    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= LocalPlayer then
            local valid, distanceSquared, aimPart = isValidTarget(target, context)
            if valid and distanceSquared < bestDistanceSquared then
                bestDistanceSquared = distanceSquared
                bestTarget = target
                bestAimPart = aimPart
            end
        end
    end

    for target in pairs(NPCCache) do
        local valid, distanceSquared, aimPart = isValidTarget(target, context)
        if valid and distanceSquared < bestDistanceSquared then
            bestDistanceSquared = distanceSquared
            bestTarget = target
            bestAimPart = aimPart
        end
    end
    return bestTarget, bestAimPart
end

local LastFOVViewportX, LastFOVViewportY = -1, -1
local function updateFOVRing()
    if not FOVRing or not Settings.ShowFOV then
        return
    end
    Camera = workspace.CurrentCamera or Camera
    if not Camera then
        return
    end
    local viewport = Camera.ViewportSize
    if viewport.X == LastFOVViewportX and viewport.Y == LastFOVViewportY then
        return
    end
    LastFOVViewportX, LastFOVViewportY = viewport.X, viewport.Y
    pcall(function()
        FOVRing.Position = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    end)
end

local AimErrorLastWarn = 0
local function updateAimAndFOV(deltaTime)
    local ok, err = pcall(function()
        Camera = workspace.CurrentCamera or Camera
        if not Camera then
            CurrentTarget = nil
            return
        end

        updateFOVRing()

        if not Settings.Enabled then
            CurrentTarget = nil
            SelectionTimer = 0
            return
        end

        local context = BuildAimContext()
        if not context then
            CurrentTarget = nil
            return
        end

        local frameTime = math.clamp(tonumber(deltaTime) or 0, 0, 0.1)
        SelectionTimer += frameTime

        -- Validate the lock every frame. Reacquire immediately if an NPC is
        -- removed, respawned, or moves outside the configured FOV.
        local valid, _, aimPart = false, nil, nil
        if CurrentTarget ~= nil then
            valid, _, aimPart = isValidTarget(CurrentTarget, context)
        end

        if not valid then
            CurrentTarget, aimPart = getClosestTarget(context)
            valid = CurrentTarget ~= nil and aimPart ~= nil
            SelectionTimer = 0
        elseif SelectionTimer >= 0.25 then
            -- Periodically refresh the best target instead of keeping an old
            -- target indefinitely when NPCs are replaced or new ones appear.
            SelectionTimer = 0
            local bestTarget, bestAimPart = getClosestTarget(context)
            if bestTarget and bestAimPart then
                CurrentTarget, aimPart = bestTarget, bestAimPart
                valid = true
            end
        end

        if valid and CurrentTarget and aimPart and aimPart.Parent then
            local goal = CFrame.lookAt(context.Camera.CFrame.Position, aimPart.Position)
            context.Camera.CFrame = goal
        else
            CurrentTarget = nil
        end
    end)

    if not ok then
        CurrentTarget = nil
        -- Do not silently hide a recurring error; throttle warnings to avoid
        -- flooding the executor console if the game changes character models.
        local now = os.clock()
        if now - AimErrorLastWarn >= 3 then
            AimErrorLastWarn = now
            warn("[Aimbot] Recovered from update error: " .. tostring(err))
        end
    end
end

local boundAimStep = pcall(function()
    RunService:BindToRenderStep("CelvynAimLock", Enum.RenderPriority.Last.Value + 1, updateAimAndFOV)
end)

if not boundAimStep then
    local renderConnection = RunService.RenderStepped:Connect(updateAimAndFOV)
    table.insert(Controller.Connections, renderConnection)
end

table.insert(Controller.Connections, Players.PlayerRemoving:Connect(function(player)
    if player == CurrentTarget then
        CurrentTarget = nil
        SelectionTimer = 0
    end
end))

local function GetPlayerColor(Target)
    if isPlayerTarget(Target) and ESPSettings.TeamColor and Target.Team ~= nil and Target.TeamColor then
        return Target.TeamColor.Color
    end
    return ESPSettings.DefaultColor
end
local function IsFiniteNumber(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end

local function GetBoundingBox(Character, Humanoid, Root, ActiveCamera, Viewport)
    if not Character or not Humanoid or not Root or not ActiveCamera or not Viewport then
        return nil
    end

    local Head = getHeadPart(Character)
    if not Humanoid or not Root or not Head then
        return nil
    end

    if Viewport.X <= 0 or Viewport.Y <= 0 then
        return nil
    end

    local TopWorld = Head.Position + Vector3.new(0, Head.Size.Y * 0.5, 0)
    local FootDrop = math.max(Humanoid.HipHeight + Root.Size.Y * 0.5, Root.Size.Y * 1.5)
    local BottomWorld = Root.Position - Vector3.new(0, FootDrop, 0)
    local TopScreen = ActiveCamera:WorldToViewportPoint(TopWorld)
    local BottomScreen = ActiveCamera:WorldToViewportPoint(BottomWorld)

    if TopScreen.Z <= 0 or BottomScreen.Z <= 0 then
        return nil
    end
    if not IsFiniteNumber(TopScreen.X) or not IsFiniteNumber(TopScreen.Y)
        or not IsFiniteNumber(TopScreen.Z) or not IsFiniteNumber(BottomScreen.X)
        or not IsFiniteNumber(BottomScreen.Y) or not IsFiniteNumber(BottomScreen.Z) then
        return nil
    end

    local Height = math.abs(BottomScreen.Y - TopScreen.Y)
    if Height < 2 or Height > Viewport.Y * 0.95 then
        return nil
    end
    local Width = math.clamp(Height * 0.45, 2, Viewport.X * 0.95)
    local CenterX = (TopScreen.X + BottomScreen.X) * 0.5
    local MinX = CenterX - Width * 0.5
    local MaxX = CenterX + Width * 0.5
    local MinY = math.min(TopScreen.Y, BottomScreen.Y)
    local MaxY = math.max(TopScreen.Y, BottomScreen.Y)
    if MaxX < 0 or MinX > Viewport.X or MaxY < 0 or MinY > Viewport.Y then
        return nil
    end

    MinX = math.clamp(MinX, 0, Viewport.X)
    MaxX = math.clamp(MaxX, 0, Viewport.X)
    MinY = math.clamp(MinY, 0, Viewport.Y)
    MaxY = math.clamp(MaxY, 0, Viewport.Y)
    if MaxX <= MinX or MaxY <= MinY then
        return nil
    end
    return MinX, MinY, MaxX, MaxY
end

local function UpdateCornerBox(Data, X, Y, Width, Height, Color)
    local CX = X + Width
    local CY = Y + Height
    local Horizontal = math.clamp(Width * ESPSettings.CornerLength, 2, math.max(Width / 2, 2))
    local Vertical = math.clamp(Height * ESPSettings.CornerLength, 2, math.max(Height / 2, 2))
    local Lines = Data.Lines

    Lines[1].From = Vector2.new(X, Y)
    Lines[1].To = Vector2.new(X + Horizontal, Y)
    Lines[2].From = Vector2.new(X, Y)
    Lines[2].To = Vector2.new(X, Y + Vertical)
    Lines[3].From = Vector2.new(CX, Y)
    Lines[3].To = Vector2.new(CX - Horizontal, Y)
    Lines[4].From = Vector2.new(CX, Y)
    Lines[4].To = Vector2.new(CX, Y + Vertical)
    Lines[5].From = Vector2.new(X, CY)
    Lines[5].To = Vector2.new(X + Horizontal, CY)
    Lines[6].From = Vector2.new(X, CY)
    Lines[6].To = Vector2.new(X, CY - Vertical)
    Lines[7].From = Vector2.new(CX, CY)
    Lines[7].To = Vector2.new(CX - Horizontal, CY)
    Lines[8].From = Vector2.new(CX, CY)
    Lines[8].To = Vector2.new(CX, CY - Vertical)

    local thickness = ESPSettings.BoxThickness
    if Data.LastBoxColor ~= Color or Data.LastBoxThickness ~= thickness then
        for i = 1, #Lines do
            local Line = Lines[i]
            if Data.LastBoxColor ~= Color then Line.Color = Color end
            if Data.LastBoxThickness ~= thickness then Line.Thickness = thickness end
        end
        Data.LastBoxColor = Color
        Data.LastBoxThickness = thickness
    end
    for i = 1, #Lines do
        if not Lines[i].Visible then
            Lines[i].Visible = true
        end
    end
end

local function UpdateEntityESP(Player, Data, LocalRoot, ActiveCamera, Viewport)
    if isPlayerTarget(Player) and Player == LocalPlayer then
        HideESP(Data)
        return
    end

    if isPlayerTarget(Player) then
        if Player.Parent ~= Players or not Player.Character then
            HideESP(Data)
            return
        end
        if ESPSettings.TeamCheck and LocalPlayer.Team ~= nil and Player.Team == LocalPlayer.Team then
            HideESP(Data)
            return
        end
    elseif not Player:IsA("Model") or Players:GetPlayerFromCharacter(Player) then
        HideESP(Data)
        return
    end

    local Character = getTargetCharacter(Player)
    if not Character then
        HideESP(Data)
        return
    end

    local Humanoid = getHumanoid(Character)
    local Root = getRootPart(Character)
    if not Humanoid or not Root or Humanoid.Health <= 0 then
        HideESP(Data)
        return
    end

    if not LocalRoot or not ActiveCamera or not Viewport then
        HideESP(Data)
        return
    end

    local Offset = Root.Position - LocalRoot.Position
    local DistanceSquared = Offset:Dot(Offset)
    local MaxDistance = ESPSettings.MaxDistance
    if DistanceSquared > MaxDistance * MaxDistance then
        HideESP(Data)
        return
    end

    local X1, Y1, X2, Y2 = GetBoundingBox(Character, Humanoid, Root, ActiveCamera, Viewport)
    if not X1 then
        HideESP(Data)
        return
    end

    local Width = X2 - X1
    local Height = Y2 - Y1
    if Width <= 1 or Height <= 1 then
        HideESP(Data)
        return
    end

    local Color = GetPlayerColor(Player)
    Data.Hidden = false
    UpdateCornerBox(Data, X1, Y1, Width, Height, Color)

    if ESPSettings.LineESP and Data.Tracer then
        local OriginY = Viewport.Y * 0.5
        if ESPSettings.LineOrigin == "Top" then
            OriginY = 0
        elseif ESPSettings.LineOrigin == "Bottom" then
            OriginY = Viewport.Y
        end
        Data.Tracer.From = Vector2.new(Viewport.X * 0.5, OriginY)
        Data.Tracer.To = Vector2.new(X1 + Width * 0.5, Y2)
        if Data.LastTracerColor ~= Color then
            Data.Tracer.Color = Color
            Data.LastTracerColor = Color
        end
        if Data.LastTracerThickness ~= ESPSettings.BoxThickness then
            Data.Tracer.Thickness = ESPSettings.BoxThickness
            Data.LastTracerThickness = ESPSettings.BoxThickness
        end
        if not Data.Tracer.Visible then
            Data.Tracer.Visible = true
        end
    elseif Data.Tracer and Data.Tracer.Visible then
        Data.Tracer.Visible = false
    end

    if ESPSettings.ShowHealth then
        local HealthPercent = math.clamp(Humanoid.Health / math.max(Humanoid.MaxHealth, 1), 0, 1)
        local HealthHeight = Height * HealthPercent
        Data.HealthBackground.From = Vector2.new(X1 - 6, Y1)
        Data.HealthBackground.To = Vector2.new(X1 - 6, Y2)
        if not Data.HealthBackground.Visible then
            Data.HealthBackground.Visible = true
        end
        Data.HealthBar.From = Vector2.new(X1 - 6, Y2)
        Data.HealthBar.To = Vector2.new(X1 - 6, Y2 - HealthHeight)

        local HealthText = math.floor(HealthPercent * 100)
        if Data.LastHealthColorPercent ~= HealthText or Data.LastHealthColorMode ~= ESPSettings.HealthColor then
            if ESPSettings.HealthColor then
                local ColorPercent = HealthText / 100
                Data.HealthBar.Color = Color3.new(1 - ColorPercent, ColorPercent, 60 / 255)
            else
                Data.HealthBar.Color = Color3.fromRGB(100, 255, 150)
            end
            Data.LastHealthColorPercent = HealthText
            Data.LastHealthColorMode = ESPSettings.HealthColor
        end
        if not Data.HealthBar.Visible then
            Data.HealthBar.Visible = true
        end

        if Data.LastHealthText ~= HealthText then
            Data.HealthText.Text = string.format("%d%%", HealthText)
            Data.LastHealthText = HealthText
        end
        Data.HealthText.Position = Vector2.new(X1 - 28, Y1 + Height * 0.5)
        if not Data.HealthText.Visible then
            Data.HealthText.Visible = true
        end
    else
        Data.HealthBackground.Visible = false
        Data.HealthBar.Visible = false
        Data.HealthText.Visible = false
    end

    if ESPSettings.ShowName then
        local NameText = getTargetName(Player)
        if Data.LastNameText ~= NameText then
            Data.Username.Text = NameText
            Data.LastNameText = NameText
        end
        Data.Username.Position = Vector2.new(X1 + Width * 0.5, Y1 - 18)
        if not Data.Username.Visible then
            Data.Username.Visible = true
        end
    else
        Data.Username.Visible = false
    end

    if ESPSettings.ShowDistance then
        local Distance = math.sqrt(DistanceSquared)
        local DistanceText = string.format("%dm", math.floor(Distance))
        if Data.LastDistanceText ~= DistanceText then
            Data.Distance.Text = DistanceText
            Data.LastDistanceText = DistanceText
        end
        Data.Distance.Position = Vector2.new(X1 + Width * 0.5, Y2 + 5)
        if not Data.Distance.Visible then
            Data.Distance.Visible = true
        end
    else
        Data.Distance.Visible = false
    end
end

if DrawingSupported then
    if not IsPoolGame then
        for _, Player in ipairs(Players:GetPlayers()) do
            if Player ~= LocalPlayer then
                CreateESP(Player)
            end
        end
        pcall(RefreshNPCCache)
        for NPC in pairs(NPCCache) do
            CreateESP(NPC)
        end

        table.insert(Controller.Connections, Players.PlayerAdded:Connect(function(Player)
            if Player ~= LocalPlayer then
                CreateESP(Player)
            end
        end))

        task.spawn(function()
            while not Controller.Cleaned and not IsPoolGame do
                for NPC in pairs(NPCCache) do
                    if NPC.Parent and not ESPObjects[NPC] then
                        CreateESP(NPC)
                    end
                end
                task.wait(2)
            end
        end)

        table.insert(Controller.Connections, Players.PlayerRemoving:Connect(function(Player)
            RemoveESP(Player)
        end))
    else
        ESPSettings.Enabled = false
        RemoveAllESP()
    end


    table.insert(Controller.Connections, RunService.RenderStepped:Connect(function()
        if not IsPoolGame or (not PoolSettings.Enabled and not PoolSettings.HighlightEnabled) then
            if ActiveNativeGuideline then
                restoreNativeGuideline(ActiveNativeGuideline)
                ActiveNativeGuideline = nil
            end
            PocketPrediction.LastSignature = nil
            PocketPrediction.Verified = false
            return
        end

        local now = os.clock()
        if now - NativeGuidelineLastSelection >= 0.25 or not ActiveNativeGuideline
            or not ActiveNativeGuideline.Parent then
            NativeGuidelineLastSelection = now
            local selected = chooseNativeGuideline()
            if selected ~= ActiveNativeGuideline then
                restoreNativeGuideline(ActiveNativeGuideline)
                ActiveNativeGuideline = selected
            end
        end

        if ActiveNativeGuideline then
            -- The game rewrites ObjectStub during its frame update. Defer visual edits
            -- until after that update, and only edit the native target-ball line.
            local target = ActiveNativeGuideline
            task.defer(function()
                if not IsPoolGame or target ~= ActiveNativeGuideline or not target or not target.Parent then return end
                if PoolSettings.Enabled then extendNativeGuideline(target) end
                if PoolSettings.HighlightEnabled then
                    updatePocketPrediction()
                    setNativeGuidelineVerified(target, PocketPrediction.Verified)
                else
                    setNativeGuidelineVerified(target, false)
                end
            end)
        end
    end))

    local ESPAccumulator = 0
    local ESPUpdateInterval = 1 / 30
    local ESPMaxAccumulator = ESPUpdateInterval * 2
    table.insert(Controller.Connections, RunService.RenderStepped:Connect(function(DeltaTime)
        Camera = workspace.CurrentCamera or Camera
        if not Camera then
            return
        end

        if IsPoolGame or not ESPSettings.Enabled then
            if ESPWasActive then
                for _, Data in pairs(ESPObjects) do
                    HideESP(Data)
                end
                ESPWasActive = false
            end
            ESPAccumulator = 0
            return
        end

        ESPAccumulator = math.min(ESPAccumulator + (DeltaTime or 0), ESPMaxAccumulator)
        if ESPAccumulator < ESPUpdateInterval then
            return
        end
        ESPAccumulator %= ESPUpdateInterval
        ESPWasActive = true

        local ActiveCamera = Camera
        local Viewport = ActiveCamera.ViewportSize
        local LocalRoot = getRootPart(LocalPlayer.Character)
        for Target, Data in pairs(ESPObjects) do
            local IsPlayer = isPlayerTarget(Target)
            local IsAlive = IsPlayer
                and Target.Parent == Players
                or (not IsPlayer and Target.Parent ~= nil and Target:IsA("Model"))
            if not IsAlive then
                RemoveESP(Target)
            else
                local ok, err = pcall(UpdateEntityESP, Target, Data, LocalRoot, ActiveCamera, Viewport)
                if not ok then
                    pcall(HideESP, Data)
                    if not Data.ErrorReported then
                        Data.ErrorReported = true
                        warn("ESP update failed for " .. getTargetName(Target) .. ": " .. tostring(err))
                    end
                elseif Data.ErrorReported then
                    Data.ErrorReported = nil
                end
            end
        end
    end))
end