local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local StarterGui        = game:GetService("StarterGui")
local TweenService      = game:GetService("TweenService")
local Stats             = game:GetService("Stats")

local LP            = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui     = LP:WaitForChild("PlayerGui")

local CARPET_NAMES = {"Flying Bee", "Waverider", "Cupid's Wings", "Santa's Sleigh", "Witch's Broom", "Flying Carpet"}

local Steal = {
    AutoStealEnabled = false,
    StealRadius      = 55,
    StealDuration    = 0.2,
    Mode             = "half",
    HalfFireRange    = 10,
    HalfHoldMin      = 1.3,
    HalfHoldMax      = 2.6,
    HalfEntryDelay   = 0.3,
    Data             = {}
}

local isStealing     = false
local stealStartTime = nil
local autoConn       = nil

local function isMyPlotByName(plotName)
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return false end
    local plot = plots:FindFirstChild(plotName)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yb = sign:FindFirstChild("YourBase")
        if yb and yb:IsA("BillboardGui") then
            return yb.Enabled == true
        end
    end
    return false
end

local function findNearestPrompt()
    local char = LP.Character
    if not char then return nil end

    local root = char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
    if not root then return nil end

    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end

    local nearest, dist = nil, math.huge

    for _, plot in ipairs(plots:GetChildren()) do
        if plot:IsA("Model") and not isMyPlotByName(plot.Name) then
            local pods = plot:FindFirstChild("AnimalPodiums")
            if pods then
                for _, pod in ipairs(pods:GetChildren()) do
                    local base = pod:FindFirstChild("Base")
                    local sp   = base and base:FindFirstChild("Spawn")
                    if sp then
                        local d = (sp.Position - root.Position).Magnitude
                        if d <= Steal.StealRadius and d < dist then
                            local found = nil
                            local att = sp:FindFirstChild("PromptAttachment")
                            if att then
                                for _, pr in ipairs(att:GetChildren()) do
                                    if pr:IsA("ProximityPrompt")
                                        and pr.ActionText
                                        and pr.ActionText:find("Steal") then
                                        found = pr
                                    end
                                end
                            end
                            if not found then
                                for _, pr in ipairs(sp:GetDescendants()) do
                                    if pr:IsA("ProximityPrompt")
                                        and pr.ActionText
                                        and pr.ActionText:find("Steal") then
                                        found = pr
                                    end
                                end
                            end
                            if found then
                                nearest, dist = found, d
                            end
                        end
                    end
                end
            end
        end
    end

    return nearest
end

local function _promptDist(prompt)
    local char = LP.Character
    if not char then return math.huge end

    local root = char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
    if not root then return math.huge end

    local part = prompt.Parent
    if part and part:IsA("Attachment") then part = part.Parent end
    if part and part:IsA("BasePart") then
        return (part.Position - root.Position).Magnitude
    end

    local ok, cf = pcall(function()
        return prompt.Parent and prompt.Parent.WorldPosition
    end)
    if ok and cf then
        return (cf - root.Position).Magnitude
    end

    return math.huge
end

local function executeSteal(prompt)
    if isStealing then return end

    if not Steal.Data[prompt] then
        Steal.Data[prompt] = { hold = {}, trigger = {}, ready = true }

        if getconnections then
            for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
                if c.Function then
                    table.insert(Steal.Data[prompt].hold, c.Function)
                end
            end
            for _, c in ipairs(getconnections(prompt.Triggered)) do
                if c.Function then
                    table.insert(Steal.Data[prompt].trigger, c.Function)
                end
            end
        end
    end

    local data = Steal.Data[prompt]
    if not data.ready then return end

    data.ready    = false
    isStealing    = true
    stealStartTime = tick()

    if Steal.Mode == "half" then
        task.spawn(function()
            for _, fn in ipairs(data.hold) do task.spawn(fn) end
            task.wait(Steal.HalfHoldMin)

            local inRange = _promptDist(prompt) <= Steal.HalfFireRange
            while true do
                local el = tick() - stealStartTime
                if el > Steal.HalfHoldMax or not prompt.Parent then break end

                if _promptDist(prompt) <= Steal.HalfFireRange then
                    if not inRange then task.wait(Steal.HalfEntryDelay) end
                    for _, fn in ipairs(data.trigger) do task.spawn(fn) end
                    break
                end
                task.wait()
            end

            task.wait(0.05)
            data.ready = true
            isStealing = false
        end)
    else
        task.spawn(function()
            for _, fn in ipairs(data.hold) do task.spawn(fn) end
            local el = 0
            while el < Steal.StealDuration do
                el = el + task.wait()
            end
            for _, fn in ipairs(data.trigger) do task.spawn(fn) end
            task.wait(0.05)
            data.ready = true
            isStealing = false
        end)
    end
end

local function startAutoSteal()
    if autoConn then return end
    autoConn = RunService.Heartbeat:Connect(function()
        if not Steal.AutoStealEnabled or isStealing then return end
        local p = findNearestPrompt()
        if p then executeSteal(p) end
    end)
end

local function stopAutoSteal()
    if autoConn then
        autoConn:Disconnect()
        autoConn = nil
    end
    isStealing = false
end

_G.AutoSteal       = Steal
_G.AutoSteal_Start = startAutoSteal
_G.AutoSteal_Stop  = stopAutoSteal

local function enableAutoSteal()
    local S = _G.AutoSteal
    if not S then return end
    if not S.AutoStealEnabled then
        S.AutoStealEnabled = true
        if _G.AutoSteal_Start then
            pcall(_G.AutoSteal_Start)
        end
    end
end

local function disableAutoSteal()
    local S = _G.AutoSteal
    if not S then return end
    S.AutoStealEnabled = false
    if _G.AutoSteal_Stop then
        pcall(_G.AutoSteal_Stop)
    end
end

local function findCarpetTool()
    local char = LP.Character
    local bp   = LP:FindFirstChild("Backpack")

    for _, name in ipairs(CARPET_NAMES) do
        local t = (char and char:FindFirstChild(name))
              or (bp and bp:FindFirstChild(name))

        if t and t:IsA("Tool") then
            return t, name
        end
    end

    return nil, nil
end

local function equipCarpet()
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end

    local tool, name = findCarpetTool()
    if not tool then return nil end

    if tool.Parent ~= char then
        pcall(function()
            hum:EquipTool(tool)
        end)
    end

    return name
end

local function fireGrappleAt(pos)
    if typeof(pos) ~= "Vector3" then return false end

    local char = LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")

    if not hrp or not hum then return false end

    if not char:FindFirstChild("Grapple Hook") then
        local bp = LP:FindFirstChild("Backpack")
        local tool = bp and bp:FindFirstChild("Grapple Hook")

        if tool then
            pcall(function()
                hum:EquipTool(tool)
            end)
        end
    end

    if not char:FindFirstChild("Grapple Hook") then
        return false
    end

    local look = Vector3.new(pos.X, hrp.Position.Y, pos.Z)

    if (look - hrp.Position).Magnitude > 0.05 then
        hrp.CFrame = CFrame.new(hrp.Position, look)
    end

    local netFolder = ReplicatedStorage:FindFirstChild("Packages")
        and ReplicatedStorage.Packages:FindFirstChild("Net")

    if not netFolder then return false end

    local r = netFolder:GetChildren()[6]

    if not (r and r:IsA("RemoteEvent")) then
        return false
    end

    local p = _G.__dosocbUseItemPayload

    if p and p.n then
        return pcall(function()
            r:FireServer(table.unpack(p, 1, p.n))
        end)
    end

    return pcall(function()
        r:FireServer(tonumber(_G.dosocbGrappleValue) or 0.33)
    end)
end

local Synchronizer
local AnimalsData
local SharedAnimals

local function loadModules()
    if Synchronizer and AnimalsData and SharedAnimals then
        return true
    end

    local ok = pcall(function()
        local Packages = ReplicatedStorage:WaitForChild("Packages", 10)
        local Datas    = ReplicatedStorage:WaitForChild("Datas", 10)
        local Shared   = ReplicatedStorage:WaitForChild("Shared", 10)

        Synchronizer  = require(Packages:WaitForChild("Synchronizer", 10))
        AnimalsData   = require(Datas:WaitForChild("Animals", 10))
        SharedAnimals = require(Shared:WaitForChild("Animals", 10))
    end)

    return ok
end

local _xchan
local _lastSweep = 0
local _dirty = true
local SWEEP_GAP = 0.5

local function _classTable()
    local ok, c = pcall(function()
        return require(
            ReplicatedStorage
                :WaitForChild("Packages", 10)
                :WaitForChild("Synchronizer", 10)
                :WaitForChild("Channel", 10)
        )
    end)

    if ok and type(c) == "table" then
        return c
    end

    return nil
end

local function _sweep()
    local cls = _classTable()
    if not cls then return end
    if type(getgc) ~= "function" then return end

    _lastSweep = os.clock()
    _dirty = false

    local reg = {}

    local ok, gc = pcall(getgc, true)
    if not ok or type(gc) ~= "table" then
        return
    end

    for i = 1, #gc do
        local v = gc[i]

        if type(v) == "table" then
            local mt = getmetatable(v)

            if mt == cls then
                local idx = rawget(v, "Index")

                if idx ~= nil then
                    reg[idx] = v
                end
            end
        end
    end

    _xchan = reg
end

local function _needsSweep()
    if not _xchan then return true end
    if _dirty then return true end

    local plots = Workspace:FindFirstChild("Plots")

    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            if _xchan[plot.Name] == nil then
                return true
            end
        end
    end

    return false
end

local function dosocbSyncAll()
    if _needsSweep() then
        if os.clock() - _lastSweep > SWEEP_GAP then
            _sweep()
        end
    end

    return _xchan
end

local function dosocbSyncGet(idx)
    local t = dosocbSyncAll()

    if not t or idx == nil then
        return nil
    end

    local ok, cd = pcall(rawget, t, idx)

    if ok and type(cd) == "table" then
        return cd
    end

    return nil
end

_G.dosocbSyncAll = dosocbSyncAll
_G.dosocbSyncGet = dosocbSyncGet

local myPlot

local function findMyPlot()
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if not plotsFolder then return nil end

    for _, plot in ipairs(plotsFolder:GetChildren()) do
        local plotSign = plot:FindFirstChild("PlotSign")

        if plotSign then
            for _, desc in ipairs(plotSign:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Text then
                    local text = tostring(desc.Text)

                    if string.find(text, LP.Name, 1, true)
                        or string.find(text, LP.DisplayName, 1, true) then
                        return plot
                    end
                end
            end
        end
    end

    return nil
end

local function _getChannelOwner(channel)
    local owner

    pcall(function()
        local cache = rawget(channel, "CacheTable")

        if type(cache) == "table" then
            owner = cache.Owner
        end
    end)

    if not owner then
        pcall(function()
            if type(channel.Get) == "function" then
                owner = channel:Get("Owner")
            end
        end)
    end

    return owner
end

local function _isMyChannel(channel)
    local owner = _getChannelOwner(channel)

    if not owner then
        return false
    end

    if typeof(owner) == "Instance" and owner:IsA("Player") then
        return owner == LP

    elseif type(owner) == "string" then
        return owner:lower() == LP.Name:lower()

    elseif type(owner) == "number" then
        local p = Players:GetPlayerByUserId(owner)
        return p == LP
    end

    return false
end

local function _getChannelAnimalList(channel)
    local animalList

    pcall(function()
        local cache = rawget(channel, "CacheTable")

        if type(cache) == "table" then
            animalList = cache.AnimalList
        end
    end)

    if not animalList then
        pcall(function()
            if type(channel.Get) == "function" then
                animalList = channel:Get("AnimalList")
            end
        end)
    end

    return animalList
end

local function findSlotByAnimalOccurrence(animalName, occurrence)
    occurrence = tonumber(occurrence) or 1

    local matches = {}

    for _, channel in pairs(dosocbSyncAll()) do
        if _isMyChannel(channel) then
            local animalList = _getChannelAnimalList(channel)

            if type(animalList) == "table" then
                for slot, animalData in pairs(animalList) do
                    if type(animalData) == "table"
                        and tostring(animalData.Index) == tostring(animalName) then

                        table.insert(matches, {
                            slot = tonumber(slot) or 0,
                            data = animalData
                        })
                    end
                end
            end
        end
    end

    table.sort(matches, function(a, b)
        return a.slot < b.slot
    end)

    local match = matches[occurrence]

    if match then
        return match.slot, match.data
    end

    return nil, nil
end

local function findSlotByAnimalName(animalName)
    return findSlotByAnimalOccurrence(animalName, 1)
end

local function animalExistsInAnyBase(animalName)
    if not loadModules() then
        return false, false
    end

    dosocbSyncAll()

    local channels = dosocbSyncAll()
    if not channels then
        return false, false
    end

    local inMyBase = false
    local inOtherBase = false

    for _, channel in pairs(channels) do
        if type(channel) ~= "table" then
            continue
        end

        local animalList = _getChannelAnimalList(channel)

        if type(animalList) ~= "table" then
            continue
        end

        local mine = _isMyChannel(channel)

        for _, animalData in pairs(animalList) do
            if type(animalData) == "table" then
                local idx = animalData.Index

                if idx and tostring(idx) == tostring(animalName) then
                    if mine then
                        inMyBase = true
                    else
                        inOtherBase = true
                    end
                end
            end
        end
    end

    return inMyBase, inOtherBase
end

local function getOtherBaseTarget(animalName, occurrence)
    if not loadModules() then
        return nil
    end

    local channels = dosocbSyncAll()
    if not channels then
        return nil
    end

    occurrence = tonumber(occurrence) or 1

    local allOtherMatches = {}

    for _, channel in pairs(channels) do
        if type(channel) ~= "table" then
            continue
        end

        if _isMyChannel(channel) then
            continue
        end

        local animalList = _getChannelAnimalList(channel)

        if type(animalList) ~= "table" then
            continue
        end

        local owner = _getChannelOwner(channel)

        for slot, animalData in pairs(animalList) do
            if type(animalData) == "table"
                and tostring(animalData.Index) == tostring(animalName) then

                table.insert(allOtherMatches, {
                    channel = channel,
                    owner = owner,
                    slot = tonumber(slot) or slot,
                    data = animalData
                })
            end
        end
    end

    table.sort(allOtherMatches, function(a, b)
        local aOwner = tostring(a.owner or "")
        local bOwner = tostring(b.owner or "")

        if aOwner ~= bOwner then
            return aOwner < bOwner
        end

        local na = tonumber(a.slot) or math.huge
        local nb = tonumber(b.slot) or math.huge

        return na < nb
    end)

    local ownCount = 0

    for _, channel in pairs(channels) do
        if type(channel) == "table" and _isMyChannel(channel) then
            local animalList = _getChannelAnimalList(channel)

            if type(animalList) == "table" then
                for _, animalData in pairs(animalList) do
                    if type(animalData) == "table"
                        and tostring(animalData.Index) == tostring(animalName) then
                        ownCount += 1
                    end
                end
            end
        end
    end

    local otherIndex = occurrence - ownCount

    if otherIndex < 1 then
        return nil
    end

    local entry = allOtherMatches[otherIndex]

    if not entry then
        return nil
    end

    local owner = entry.owner
    local plotName = nil

    if type(owner) == "Instance" and owner:IsA("Player") then
        plotName = owner.Name

    elseif type(owner) == "string" then
        plotName = owner

    elseif type(owner) == "number" then
        local p = Players:GetPlayerByUserId(owner)

        if p then
            plotName = p.Name
        end
    end

    if not plotName then
        local idx = rawget(entry.channel, "Index")

        if idx then
            plotName = tostring(idx)
        end
    end

    local plots = Workspace:FindFirstChild("Plots")

    if not plots then
        return nil
    end

    local plot = plotName and plots:FindFirstChild(plotName)

    if not plot then
        for _, candidate in ipairs(plots:GetChildren()) do
            if tostring(candidate.Name):lower() == tostring(plotName):lower() then
                plot = candidate
                break
            end
        end
    end

    if not plot then
        return nil
    end

    local podiums = plot:FindFirstChild("AnimalPodiums")

    if not podiums then
        return nil
    end

    local podium = podiums:FindFirstChild(tostring(entry.slot))

    if not podium then
        return nil
    end

    local pos
    local petModel

    for _, desc in ipairs(podium:GetDescendants()) do
        if desc:IsA("Model") then
            if desc.Name ~= "Claim"
                and desc.Name ~= "Base"
                and desc.Name ~= "Decorations" then

                local hasMesh = false

                for _, c in ipairs(desc:GetDescendants()) do
                    if c:IsA("MeshPart") then
                        hasMesh = true
                        break
                    end
                end

                if hasMesh then
                    petModel = desc
                    break
                end
            end
        end
    end

    if petModel then
        local ok, cf = pcall(function()
            return petModel:GetBoundingBox()
        end)

        if ok and cf then
            pos = cf.Position
        end
    end

    if not pos then
        local ok, cf = pcall(function()
            return podium:GetPivot()
        end)

        if ok and cf then
            pos = cf.Position
        end
    end

    if not pos then
        return nil
    end

    return {
        animalName = animalName,
        occurrence = occurrence,
        plot = plot,
        plotName = plot.Name,
        slot = entry.slot,
        position = pos,
        owner = owner,
        animalData = entry.data
    }
end


local netFolder = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net")
local _cachedGrabRemote = nil

local function fireGrab(slot)
    slot = tonumber(slot)

    if not slot then
        return false
    end

    if not _cachedGrabRemote or not _cachedGrabRemote.Parent then
        _cachedGrabRemote = netFolder:GetChildren()[167]
    end

    if not (_cachedGrabRemote and _cachedGrabRemote:IsA("RemoteEvent")) then
        return false
    end

    return pcall(function()
        _cachedGrabRemote:FireServer("Grab", slot)
    end)
end

local grabButtonGui = nil
local grabButton = nil
local grabButtonSlot = nil
local grabSpamThread = nil

local function stopGrabSpam()
    if grabSpamThread then
        local t = grabSpamThread
        grabSpamThread = nil

        pcall(function()
            task.cancel(t)
        end)
    end
end

local function destroyGrabButton()
    stopGrabSpam()

    if grabButtonGui then
        grabButtonGui:Destroy()
        grabButtonGui = nil
    end

    grabButton = nil
    grabButtonSlot = nil
end

local function startGrabSpam(slot)
    stopGrabSpam()

    grabSpamThread = task.spawn(function()
        while grabButtonSlot == slot do
            if LP:GetAttribute("Stealing") == true then
                break
            end

            fireGrab(slot)
            task.wait(0.1)
        end
    end)
end

local function createGrabButton(slot)
    slot = tonumber(slot)

    if not slot then
        return
    end

    destroyGrabButton()

    grabButtonSlot = slot

    local gui = Instance.new("ScreenGui")
    gui.Name = "KurdHubGrabButton"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = PlayerGui

    grabButtonGui = gui

    local button = Instance.new("TextButton")
    button.Name = "GrabButton"
    button.Size = UDim2.new(0, 120, 0, 46)
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -16, 0.5, 0)
    button.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    button.BorderSizePixel = 1
    button.BorderColor3 = Color3.fromRGB(255, 255, 255)
    button.Text = "GRAB " .. tostring(slot)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 18
    button.Font = Enum.Font.GothamBold
    button.AutoButtonColor = true
    button.ZIndex = 100
    button.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 9)
    corner.Parent = button

    grabButton = button

    button.Activated:Connect(function()
        if grabButtonSlot ~= slot then
            return
        end

        if LP:GetAttribute("Stealing") == true then
            destroyGrabButton()
            return
        end

        fireGrab(slot)
    end)

    startGrabSpam(slot)
end

local function flingUpOnce()
    local c = LP.Character

    if not c then
        c = LP.CharacterAdded:Wait()
    end

    local h = c and c:FindFirstChild("HumanoidRootPart")

    if h then
        h.AssemblyLinearVelocity = Vector3.new(
            h.AssemblyLinearVelocity.X,
            10000000,
            h.AssemblyLinearVelocity.Z
        )
    end
end

local SPD = 180
local isRunning = false
local rc = nil
local activeFloor = nil

local Y_CAP_FLOOR1      = 6.39
local FLOOR2_PART_Y     = 1.49
local FLOOR3_PART_Y     = 19.49
local SUPPORT_PART_NAME = "jaa"
local FLOOR3_PART_NAME  = "hehdhd"

local supportPart = nil

local LAYOUT_A_WAYPOINTS = {
    Floor1 = {
        Vector3.new(-338.88, -5.01, 112.94)
    },

    Floor2 = {
        Vector3.new(-338.88, -5.01, 112.94)
    },

    Floor3 = {
        Vector3.new(-357.13, 13.83, 146.90),
        Vector3.new(-298.92, 12.99, 145.69),
        Vector3.new(-303.55, 12.99, 114.20)
    }
}

local LAYOUT_A_SAFE = {
    Floor1 = {
        pos = Vector3.new(-318.02, -7.9, 111.03),
        minSlot = 1,
        maxSlot = 18
    },

    Floor2 = {
        pos = Vector3.new(-318.02, 10.1, 111.03),
        minSlot = 19,
        maxSlot = 27
    },
}

local LAYOUT_B_WAYPOINTS = {
    Floor1 = {
        Vector3.new(-339.42, -5.01, 6.66)
    },

    Floor2 = {
        Vector3.new(-339.42, -5.01, 6.66)
    },

    Floor3 = {
        Vector3.new(-389.48, 15.85, 37.25),
        Vector3.new(-297.48, 16.05, 39.26),
        Vector3.new(-300.31, 12.99, 23.35)
    }
}

local LAYOUT_B_SAFE = {
    Floor1 = {
        pos = Vector3.new(-314.89, -8.01, 6.7),
        minSlot = 1,
        maxSlot = 18
    },

    Floor2 = {
        pos = Vector3.new(-314.89, 10.1, 6.7),
        minSlot = 19,
        maxSlot = 27
    },
}

local LAYOUT_A_ANCHOR = Vector3.new(-348.58, -6.51, 113.79)
local LAYOUT_B_ANCHOR = Vector3.new(-349.36, -6.44, 6.38)

local FLOOR_WAYPOINTS = LAYOUT_B_WAYPOINTS
local SAFE_ZONES = LAYOUT_B_SAFE

local function detectLayout()
    if not myPlot then
        myPlot = findMyPlot()
    end

    if not myPlot then
        return
    end

    local base = myPlot:FindFirstChild("Base")
        or myPlot:FindFirstChild("Spawn")
        or myPlot

    local origin

    if base and base:IsA("BasePart") then
        origin = base.Position

    elseif base and base:IsA("Model") then
        local ok, cf = pcall(function()
            return base:GetPivot()
        end)

        if ok and cf then
            origin = cf.Position
        end
    end

    if not origin then
        origin = myPlot:GetPivot().Position
    end

    local dA = (origin - LAYOUT_A_ANCHOR).Magnitude
    local dB = (origin - LAYOUT_B_ANCHOR).Magnitude

    if dA < dB then
        FLOOR_WAYPOINTS = LAYOUT_A_WAYPOINTS
        SAFE_ZONES = LAYOUT_A_SAFE
    else
        FLOOR_WAYPOINTS = LAYOUT_B_WAYPOINTS
        SAFE_ZONES = LAYOUT_B_SAFE
    end
end

local SAFE_ZONE_RADIUS = 28

local function getSafeZoneFloor()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if not hrp then
        return nil
    end

    local p = hrp.Position

    for floor, zone in pairs(SAFE_ZONES) do
        local dz = p.Z - zone.pos.Z
        local dx = p.X - zone.pos.X
        local dy = p.Y - zone.pos.Y

        if math.abs(dy) <= 8
            and (dx * dx + dz * dz) <= (SAFE_ZONE_RADIUS * SAFE_ZONE_RADIUS) then
            return floor
        end
    end

    return nil
end

local function floorForSlot(slot)
    if slot >= 1 and slot <= 10 then
        return "Floor1"
    elseif slot >= 11 and slot <= 18 then
        return "Floor2"
    elseif slot >= 19 and slot <= 27 then
        return "Floor3"
    end

    return nil
end

local SKIP_NAMES = {
    ["Claim"] = true,
    ["Base"] = true,
    ["Decorations"] = true,
}

local function findPetModelInPodium(podium)
    for _, desc in ipairs(podium:GetDescendants()) do
        if desc:IsA("Model") and not SKIP_NAMES[desc.Name] then
            local hasMesh = false

            for _, c in ipairs(desc:GetDescendants()) do
                if c:IsA("MeshPart") then
                    hasMesh = true
                    break
                end
            end

            if hasMesh then
                return desc
            end
        end
    end

    return nil
end

local function getSlotPosition(podium)
    local petModel = findPetModelInPodium(podium)

    if petModel then
        local ok, cf = pcall(function()
            return petModel:GetBoundingBox()
        end)

        if ok and cf then
            return cf.Position, petModel.Name
        end
    end

    local ok, cf = pcall(function()
        return podium:GetPivot()
    end)

    if ok and cf then
        return cf.Position, nil
    end

    return podium.Position, nil
end

local function getSlotPositionByNumber(slotNum)
    if not myPlot then
        myPlot = findMyPlot()
    end

    if not myPlot then
        return nil
    end

    local podiums = myPlot:FindFirstChild("AnimalPodiums")

    if not podiums then
        return nil
    end

    local podium = podiums:FindFirstChild(tostring(slotNum))

    if not podium then
        return nil
    end

    return getSlotPosition(podium)
end

local function clearSupportPart()
    if supportPart and supportPart.Parent then
        supportPart:Destroy()
    end

    supportPart = nil

    local existing = Workspace:FindFirstChild(SUPPORT_PART_NAME)

    while existing do
        existing:Destroy()
        existing = Workspace:FindFirstChild(SUPPORT_PART_NAME)
    end
end

local function spawnSupportPartUnderSlot(slot)
    clearSupportPart()

    local slotPos = getSlotPositionByNumber(slot)

    if not slotPos then
        return nil
    end

    local p = Instance.new("Part")

    p.Name = SUPPORT_PART_NAME
    p.Anchored = true
    p.CanCollide = true
    p.Size = Vector3.new(5, 0.5, 5)

    p.CFrame =
        CFrame.new(
            Vector3.new(
                slotPos.X,
                FLOOR2_PART_Y,
                slotPos.Z
            )
        )
        * CFrame.Angles(0, math.rad(-90), 0)

    p.Parent = Workspace

    supportPart = p

    return p
end

local function clearFloor3Part()
    local existing = Workspace:FindFirstChild(FLOOR3_PART_NAME)

    while existing do
        existing:Destroy()
        existing = Workspace:FindFirstChild(FLOOR3_PART_NAME)
    end
end

local function spawnFloor3PartUnderSlot(slot)
    clearFloor3Part()

    local slotPos = getSlotPositionByNumber(slot)

    if not slotPos then
        return nil
    end

    local Part = Instance.new("Part")

    Part.Name = FLOOR3_PART_NAME
    Part.Anchored = true
    Part.CanCollide = true
    Part.Color = Color3.fromRGB(163, 162, 165)
    Part.Material = Enum.Material.Plastic
    Part.Transparency = 0
    Part.Reflectance = 0
    Part.Size = Vector3.new(4, 0.5, 4)

    Part.CFrame = CFrame.new(
        Vector3.new(
            slotPos.X,
            FLOOR3_PART_Y,
            slotPos.Z
        )
    )

    Part.Parent = Workspace

    return Part
end

local function moveToPosition(hrp, targetPos, yCap)
    local startTick = tick()

    while isRunning
        and hrp
        and (hrp.Position - targetPos).Magnitude > 5
        and (tick() - startTick) < 6 do

        local dir = (targetPos - hrp.Position).Unit

        hrp.Velocity = dir * SPD

        if yCap and hrp.Position.Y > yCap then
            local newPos = Vector3.new(
                hrp.Position.X,
                yCap,
                hrp.Position.Z
            )

            hrp.CFrame = CFrame.new(
                newPos,
                newPos + dir * Vector3.new(1, 0, 1)
            )

            hrp.Velocity = Vector3.new(
                hrp.Velocity.X,
                0,
                hrp.Velocity.Z
            )
        end

        task.wait(0.05)
    end

    if hrp then
        local finalY = hrp.Position.Y

        if yCap and finalY > yCap then
            finalY = yCap
        end

        hrp.CFrame = CFrame.new(
            Vector3.new(
                targetPos.X,
                finalY,
                targetPos.Z
            )
        )

        hrp.Velocity = Vector3.zero
    end
end

local OTHER_BASES_LOW = {
    [1] = Vector3.new(-460, -6, 219),
    [2] = Vector3.new(-460, -6, 111),
    [3] = Vector3.new(-460, -6, 5),
    [4] = Vector3.new(-460, -6, -100),

    [5] = Vector3.new(-355, -6, 217),
    [6] = Vector3.new(-355, -6, 113),
    [7] = Vector3.new(-355, -6, 5),
    [8] = Vector3.new(-355, -6, -100),
}

local OTHER_BASES_HIGH = {
    [1] = {
        Vector3.new(-462.7, 32, 220.3),
        Vector3.new(-476.9, 17, 221.1)
    },

    [2] = {
        Vector3.new(-463.0, 32, 113.3),
        Vector3.new(-476.6, 17, 113.5)
    },

    [3] = {
        Vector3.new(-462.8, 32, 6.3),
        Vector3.new(-476.5, 17, 6.8)
    },

    [4] = {
        Vector3.new(-462.8, 32, -100.7),
        Vector3.new(-476.4, 17, -100.8)
    },

    [5] = {
        Vector3.new(-356.6, 32, 220.5),
        Vector3.new(-342.3, 17, 221.4)
    },

    [6] = {
        Vector3.new(-357.0, 32, 114.0),
        Vector3.new(-342.9, 17, 113.2)
    },

    [7] = {
        Vector3.new(-356.6, 32, 6.4),
        Vector3.new(-342.6, 17, 6.0)
    },

    [8] = {
        Vector3.new(-355.8, 32, -100.0),
        Vector3.new(-342.7, 17, -100.3)
    },
}

local OTHER_HIGH_WALK_DIRECTIONS = {
    [1] = Vector3.new(-1.00, 0, 0.05),
    [2] = Vector3.new(-1.00, 0, 0.05),
    [3] = Vector3.new(-1.00, 0, 0.03),
    [4] = Vector3.new(-1.00, 0, 0.03),

    [5] = Vector3.new(1.00, 0, 0.00),
    [6] = Vector3.new(1.00, 0, -0.03),
    [7] = Vector3.new(1.00, 0, 0.04),
    [8] = Vector3.new(1.00, 0, 0.03),
}

local OTHER_PLATFORM_POSITIONS = {
    [1] = Vector3.new(-472, 13.3, 221.1),
    [2] = Vector3.new(-472, 13.3, 113.5),
    [3] = Vector3.new(-472, 13.3, 6.8),
    [4] = Vector3.new(-472, 13.3, -100.8),

    [5] = Vector3.new(-347, 13.3, 221.4),
    [6] = Vector3.new(-347, 13.3, 113.2),
    [7] = Vector3.new(-347, 13.3, 6.0),
    [8] = Vector3.new(-347, 13.3, -100.3),
}

local OTHER_CLONE_POSITIONS = {
    Vector3.new(-476, -4, 221),
    Vector3.new(-476, -4, 114),
    Vector3.new(-476, -4, 7),
    Vector3.new(-476, -4, -100),

    Vector3.new(-342, -4, -100),
    Vector3.new(-342, -4, 6),
    Vector3.new(-342, -4, 114),
    Vector3.new(-342, -4, 220)
}

local OTHER_FACE_TARGETS = {
    Vector3.new(-519, -3, 221),
    Vector3.new(-519, -3, 114),
    Vector3.new(-518, -3, 7),
    Vector3.new(-519, -3, -100),

    Vector3.new(-301, -3, -100),
    Vector3.new(-301, -3, 7),
    Vector3.new(-302, -3, 114),
    Vector3.new(-300, -3, 220)
}

local otherTpMoving = false
local otherTpCancel = false
local otherPlatform = nil

local function getClosestOtherBaseIdx(position)
    local closest = 1
    local dist = math.huge

    for i, basePos in pairs(OTHER_BASES_LOW) do
        local d =
            (
                Vector2.new(position.X, position.Z)
                -
                Vector2.new(basePos.X, basePos.Z)
            ).Magnitude
        if d < dist then
            dist = d
            closest = i
        end
    end

    return closest
end

local function cleanupOtherPlatform()
    if otherPlatform and otherPlatform.Parent then
        otherPlatform:Destroy()
    end

    otherPlatform = nil

    local existing = Workspace:FindFirstChild("KurdHubOtherPlatform")

    while existing do
        existing:Destroy()
        existing = Workspace:FindFirstChild("KurdHubOtherPlatform")
    end
end

local function createOtherPlatform(plotIndex)
    cleanupOtherPlatform()

    local pos = OTHER_PLATFORM_POSITIONS[plotIndex]

    if not pos then
        return nil
    end

    local platform = Instance.new("Part")

    platform.Name = "KurdHubOtherPlatform"
    platform.Size = Vector3.new(8, 1, 8)
    platform.Position = pos
    platform.Anchored = true
    platform.CanCollide = true
    platform.Material = Enum.Material.Plastic
    platform.Transparency = 0

    platform.Parent = Workspace

    otherPlatform = platform

    return platform
end

local function otherMoveStep(targetPos)
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")

    if not hrp or not hum then
        return false
    end

    local STEP_DISTANCE = 12
    local WAIT_TIME = 0.09
    local MAX_TRIES = 1000
    local VELOCITY_MULTIPLIER = 1.5

    local tries = 0

    while
        (hrp.Position - targetPos).Magnitude > 6
        and tries < MAX_TRIES
    do
        if otherTpCancel or LP:GetAttribute("Stealing") == true then
            hrp.Velocity = Vector3.zero
            return false
        end

        tries += 1

        local currentPos = hrp.Position
        local direction = targetPos - currentPos
        local distance = direction.Magnitude

        if distance <= 6 then
            break
        end

        direction = direction.Unit

        local moveDistance = math.min(
            STEP_DISTANCE,
            distance
        )

        local nextPos =
            currentPos
            +
            (direction * moveDistance)

        local moveDirection =
            (nextPos - currentPos).Unit

        local velocity =
            moveDirection
            *
            (moveDistance / WAIT_TIME)
            *
            VELOCITY_MULTIPLIER

        hrp.Velocity = velocity

        task.wait(WAIT_TIME)

        if (hrp.Position - targetPos).Magnitude < 15 then
            hrp.Velocity = hrp.Velocity * 0.7
        end
    end

    hrp.Velocity = Vector3.zero

    return true
end

local function otherMoveStepSlow(targetPos)
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")

    if not hrp or not hum then
        return false
    end

    local STEP_DISTANCE = 7
    local WAIT_TIME = 0.09
    local MAX_TRIES = 1500

    local tries = 0

    while
        (hrp.Position - targetPos).Magnitude > 4
        and tries < MAX_TRIES
    do
        if otherTpCancel or LP:GetAttribute("Stealing") == true then
            hrp.Velocity = Vector3.zero
            return false
        end

        tries += 1

        local currentPos = hrp.Position
        local direction = targetPos - currentPos
        local distance = direction.Magnitude

        if distance <= 4 then
            break
        end

        direction = direction.Unit

        local moveDistance = math.min(
            STEP_DISTANCE,
            distance
        )

        local nextPos =
            currentPos
            +
            (direction * moveDistance)

        local moveDirection =
            (nextPos - currentPos).Unit

        local velocity =
            moveDirection
            *
            (moveDistance / WAIT_TIME)

        hrp.Velocity = velocity

        task.wait(WAIT_TIME)

        if (hrp.Position - targetPos).Magnitude < 10 then
            hrp.Velocity = hrp.Velocity * 0.8
        end
    end

    hrp.Velocity = Vector3.zero

    return true
end

local function instantOtherClone()
    pcall(function()
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if not hum then
            return
        end

        local cloner =
            LP.Backpack:FindFirstChild("Quantum Cloner")
            or
            char:FindFirstChild("Quantum Cloner")

        if not cloner then
            return
        end

        hum:EquipTool(cloner)

        task.wait()

        cloner:Activate()

        local cloneName =
            tostring(LP.UserId)
            ..
            "_Clone"

        for _ = 1, 20 do
            if Workspace:FindFirstChild(cloneName) then
                break
            end

            task.wait()
        end

        task.wait(0.6)

        local tpButton =
            PlayerGui:FindFirstChild("ToolsFrames", true)

        if tpButton then
            tpButton =
                tpButton:FindFirstChild("TeleportToClone", true)

            if tpButton
                and tpButton.Visible
                and firesignal then

                firesignal(tpButton.MouseButton1Up)
            end
        end
    end)
end

local function getTargetPlotUnlocked(plotName)
    local ok, result = pcall(function()
        local plots = Workspace:FindFirstChild("Plots")

        if not plots then
            return false
        end

        local targetPlot = plots:FindFirstChild(plotName)

        if not targetPlot then
            return false
        end

        local unlockFolder = targetPlot:FindFirstChild("Unlock")

        if not unlockFolder then
            return true
        end

        local unlockItems = {}

        for _, item in pairs(unlockFolder:GetChildren()) do
            local pos = nil

            if item:IsA("Model") then
                pcall(function()
                    pos = item:GetPivot().Position
                end)

            elseif item:IsA("BasePart") then
                pos = item.Position
            end

            if pos then
                table.insert(unlockItems, {
                    Object = item,
                    Height = pos.Y
                })
            end
        end

        table.sort(unlockItems, function(a, b)
            return a.Height < b.Height
        end)

        if #unlockItems == 0 then
            return true
        end

        local floor1Door = unlockItems[1].Object

        for _, desc in ipairs(floor1Door:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Enabled then
                return false
            end
        end

        return true
    end)

    return ok and result or false
end

local function walkOtherForward(seconds, direction)
    local char = LP.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if not hum or not hrp then
        return
    end

    hrp.Velocity = Vector3.zero

    task.wait(0.05)

    local camera = Workspace.CurrentCamera
    local startTime = os.clock()

    local conn

    conn = RunService.RenderStepped:Connect(function()
        if otherTpCancel
            or LP:GetAttribute("Stealing") == true
            or os.clock() - startTime >= seconds then

            conn:Disconnect()
            hum:Move(Vector3.zero, false)

            return
        end

        if camera then
            camera.CFrame = CFrame.lookAt(
                camera.CFrame.Position,
                hrp.Position + hrp.CFrame.LookVector * 10
            )
        end

        if direction then
            hum:Move(direction, false)
        else
            hum:Move(hrp.CFrame.LookVector, false)
        end
    end)
end

local _stealScriptLoaded = false

local function loadStealScript()
    if _stealScriptLoaded then return end
    _stealScriptLoaded = true

    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Ninja10908/START/refs/heads/main/Fnrt"))()
    end)

    task.wait(0.2)
end

local function travelToOtherBase(targetData)
    if otherTpMoving then
        otherTpCancel = true
        return
    end

    if not targetData then
        return
    end

    if not targetData.position then
        return
    end

    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if not hrp or not hum or hum.Health <= 0 then
        return
    end

    otherTpCancel = false
    otherTpMoving = true

    loadStealScript()

    local targetPos = targetData.position

    local plotIndex =
        getClosestOtherBaseIdx(targetPos)

    createOtherPlatform(plotIndex)

    local carpetName = equipCarpet()

    if not carpetName then
        StarterGui:SetCore("SendNotification", {
            Title = targetData.animalName or "Not Found",
            Text = "کەسێ نینە",
            Duration = 4
        })

        cleanupOtherPlatform()
        otherTpMoving = false

        return
    end

    task.wait(0.1)

    task.spawn(function()
        while otherTpMoving and not otherTpCancel do
            local c = LP.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            local eq = c and c:FindFirstChild(carpetName)

            if h and not eq then
                pcall(function()
                    equipCarpet()
                end)
            end

            task.wait(0.1)
        end
    end)

    local isHighFloor = targetPos.Y > 10

    local baseLow =
        OTHER_BASES_LOW[plotIndex]

    local baseHigh =
        OTHER_BASES_HIGH[plotIndex]

    if not isHighFloor and baseLow then
        if not otherMoveStep(baseLow) then
            cleanupOtherPlatform()
            otherTpMoving = false
            return
        end
    elseif isHighFloor and baseHigh then
        if not otherMoveStep(baseHigh[1]) then
            cleanupOtherPlatform()
            otherTpMoving = false
            return
        end

        if otherTpCancel then
            cleanupOtherPlatform()
            otherTpMoving = false
            return
        end

        if not otherMoveStep(baseHigh[2]) then
            cleanupOtherPlatform()
            otherTpMoving = false
            return
        end
    end

    if otherTpCancel then
        cleanupOtherPlatform()
        otherTpMoving = false
        hrp.Velocity = Vector3.zero
        return
    end

    if not isHighFloor then
        local bestSpot =
            OTHER_CLONE_POSITIONS[1]

        local minDst = math.huge

        for _, pos in ipairs(OTHER_CLONE_POSITIONS) do
            local d =
                (targetPos - pos).Magnitude

            if d < minDst then
                minDst = d
                bestSpot = pos
            end
        end

        if not otherMoveStep(bestSpot) then
            cleanupOtherPlatform()
            otherTpMoving = false
            return
        end
    end

    if otherTpCancel then
        cleanupOtherPlatform()
        otherTpMoving = false
        hrp.Velocity = Vector3.zero
        return
    end

    local bestFace =
        OTHER_FACE_TARGETS[1]

    local minFaceDist = math.huge

    for _, pos in ipairs(OTHER_FACE_TARGETS) do
        local d =
            (hrp.Position - pos).Magnitude

        if d < minFaceDist then
            minFaceDist = d
            bestFace = pos
        end
    end

    local targetLookAt =
        CFrame.lookAt(
            hrp.Position,
            Vector3.new(
                bestFace.X,
                hrp.Position.Y,
                bestFace.Z
            )
        )

    for _ = 1, 5 do
        if otherTpCancel then
            cleanupOtherPlatform()
            otherTpMoving = false
            hrp.Velocity = Vector3.zero
            return
        end

        hrp.CFrame =
            hrp.CFrame:Lerp(
                targetLookAt,
                0.2
            )

        task.wait(0.02)
    end

    if isHighFloor
        or not getTargetPlotUnlocked(targetData.plotName) then

        local walkDir =
            OTHER_HIGH_WALK_DIRECTIONS[plotIndex]

        walkOtherForward(
            0.4,
            walkDir
        )

        task.wait(0.4)

        if otherTpCancel then
            cleanupOtherPlatform()
            otherTpMoving = false
            hrp.Velocity = Vector3.zero
            return
        end

        pcall(function()
            local hum2 = LP.Character
                and LP.Character:FindFirstChildOfClass("Humanoid")
            if hum2 then
                hum2:UnequipTools()
            end
        end)

        otherTpMoving = false

        task.wait(0.15)

        instantOtherClone()

        task.wait(0.3)

        cleanupOtherPlatform()

        otherTpMoving = true

        pcall(function()
            equipCarpet()
        end)

    else
        cleanupOtherPlatform()
    end

    if otherTpCancel then
        otherTpMoving = false
        hrp.Velocity = Vector3.zero
        return
    end

    pcall(function()
        equipCarpet()
    end)

    local verticalDiff =
        targetPos.Y - hrp.Position.Y

    if verticalDiff > 2 then
        local downOffset =
            targetPos.Y > 20
            and 15
            or 8

        local airPos = Vector3.new(
            targetPos.X,
            targetPos.Y - downOffset,
            targetPos.Z
        )

        local platform =
            Instance.new("Part")

        platform.Name = "KurdHubYellowTarget"
        platform.Size = Vector3.new(4, 0.4, 4)
        platform.Position =
            airPos - Vector3.new(0, 5, 0)
        platform.Material = Enum.Material.Neon
        platform.Anchored = true
        platform.CanCollide = true
        platform.Transparency = 0
        platform.Parent = Workspace

        RunService.Heartbeat:Wait()

        if otherTpCancel then
            platform:Destroy()
            otherTpMoving = false
            hrp.Velocity = Vector3.zero
            return
        end

        if not otherMoveStepSlow(
            airPos + Vector3.new(0, 1, 0)
        ) then
            platform:Destroy()
            otherTpMoving = false
            hrp.Velocity = Vector3.zero
            return
        end

        task.spawn(function()
            local start = tick()

            while tick() - start < 20 do
                if otherTpCancel
                    or LP:GetAttribute("Stealing") then

                    if platform.Parent then
                        platform:Destroy()
                    end

                    break
                end

                task.wait(0.1)
            end

            if platform.Parent then
                platform:Destroy()
            end
        end)
    else
        otherMoveStep(targetPos)
    end

    task.wait(0.1)

    hrp.Velocity = Vector3.zero

    otherTpMoving = false

    enableAutoSteal()
end

local ACTIVE_SLOT = nil

local function setActiveSlot(slotNum)
    ACTIVE_SLOT = slotNum
end

local function clearActiveSlot()
    ACTIVE_SLOT = nil
end

local function haltMovement()
    isRunning = false

    if rc then
        rc:Disconnect()
        rc = nil
    end
end

local function fullCancel()
    haltMovement()

    activeFloor = nil

    clearActiveSlot()
    clearSupportPart()
    clearFloor3Part()
    destroyGrabButton()

    otherTpCancel = true
    cleanupOtherPlatform()

    disableAutoSteal()
end

LP:GetAttributeChangedSignal("Stealing"):Connect(function()
    if LP:GetAttribute("Stealing") == true then
        fullCancel()
    end
end)

LP:GetAttributeChangedSignal("Stealing"):Connect(function()
    if LP:GetAttribute("Stealing") == false then
        disableAutoSteal()
    end
end)

LP.CharacterAdded:Connect(function()
    fullCancel()
end)

local function flatDist(a, b)
    local dx = a.X - b.X
    local dz = a.Z - b.Z

    return math.sqrt(
        dx * dx + dz * dz
    )
end

local function travelToSlot(slot, onArrive)
    slot = tonumber(slot)

    if not slot then
        return
    end

    detectLayout()

    if ACTIVE_SLOT == slot then
        fullCancel()

        StarterGui:SetCore("SendNotification", {
            Title = "Cancelled",
            Text = "Travel to slot " .. slot .. " cancelled",
            Duration = 2
        })

        return
    end

    local floorName =
        floorForSlot(slot)

    if not floorName then
        return
    end

    local currentZone =
        getSafeZoneFloor()

    if currentZone then
        local z =
            SAFE_ZONES[currentZone]

        if not (
            slot >= z.minSlot
            and slot <= z.maxSlot
        ) then
            return
        end
    end

    fullCancel()

    isRunning = true
    activeFloor = floorName

    setActiveSlot(slot)
    createGrabButton(slot)

    local char = LP.Character
    local hrp =
        char and char:FindFirstChild("HumanoidRootPart")
    local hum =
        char and char:FindFirstChildOfClass("Humanoid")

    if not hrp or not hum then
        fullCancel()
        return
    end

    local petPos =
        getSlotPositionByNumber(slot)

    if not petPos then
        local wps =
            FLOOR_WAYPOINTS[floorName] or {}

        petPos = wps[#wps]
    end

    if not petPos then
        fullCancel()
        return
    end

    local inSafeZone = false

    if currentZone then
        local z =
            SAFE_ZONES[currentZone]

        inSafeZone =
            slot >= z.minSlot
            and slot <= z.maxSlot
    end

    local isFloor2 =
        floorName == "Floor2"

    local isFloor3 =
        floorName == "Floor3"

    if isFloor2 then
        spawnSupportPartUnderSlot(slot)
    end

    if isFloor3 then
        spawnFloor3PartUnderSlot(slot)
    end

    local grapplePos =
        petPos

    if isFloor2
        and supportPart
        and supportPart.Parent then

        grapplePos =
            supportPart.Position
    end

    if isFloor3 then
        local f3 =
            Workspace:FindFirstChild(
                FLOOR3_PART_NAME
            )

        if f3 then
            grapplePos =
                f3.Position
        end
    end

    local _gh =
        (
            LP:FindFirstChild("Backpack")
            and LP.Backpack:FindFirstChild(
                "Grapple Hook"
            )
        )
        or
        (
            char
            and char:FindFirstChild(
                "Grapple Hook"
            )
        )

    if not _gh then
        StarterGui:SetCore("SendNotification", {
            Title = "No Grapple Hook",
            Text = "Target tool not found",
            Duration = 5
        })

        fullCancel()
        flingUpOnce()

        return
    end

    if _gh.Parent ~= char then
        pcall(function()
            hum:EquipTool(_gh)
        end)
    end

    local _t0 =
        os.clock()

    while
        not char:FindFirstChild(
            "Grapple Hook"
        )
        and os.clock() - _t0 < 1
    do
        RunService.Heartbeat:Wait()
    end

    pcall(function()
        fireGrappleAt(grapplePos)
    end)

    task.wait(0.1)

    pcall(function()
        hum:UnequipTools()
    end)

    task.wait(0.1)

    local carpetName =
        equipCarpet()

    if not carpetName then
        StarterGui:SetCore("SendNotification", {
            Title = "No Carpet Tool",
            Text = "Target tool not found",
            Duration = 5
        })

        fullCancel()
        flingUpOnce()

        return
    end

    task.wait(0.1)

    task.spawn(function()
        while isRunning do
            local c = LP.Character
            local h =
                c and c:FindFirstChildOfClass(
                    "Humanoid"
                )

            local eq =
                c and c:FindFirstChild(
                    carpetName
                )

            if h and not eq then
                pcall(function()
                    equipCarpet()
                end)
            end

            task.wait(0.1)
        end
    end)

    task.spawn(function()
        if not inSafeZone then
            local waypoints =
                FLOOR_WAYPOINTS[floorName]
                or {}

            for _, pos in ipairs(waypoints) do
                if not isRunning then
                    break
                end

                local cap =
                    isFloor2
                    and Y_CAP_FLOOR1
                    or nil

                moveToPosition(
                    hrp,
                    pos,
                    cap
                )

                task.wait(0.1)
            end
        end

        local finalPos =
            petPos

        if isFloor2
            and supportPart
            and supportPart.Parent then

            finalPos =
                supportPart.Position
        end

        if isFloor3 then
            local f3 =
                Workspace:FindFirstChild(
                    FLOOR3_PART_NAME
                )

            if f3 then
                finalPos =
                    f3.Position
            end
        end

        while
            isRunning
            and ACTIVE_SLOT == slot
        do
            if isFloor2 then
                if supportPart
                    and supportPart.Parent then

                    finalPos =
                        supportPart.Position
                else
                    local slotPos =
                        getSlotPositionByNumber(slot)

                    if slotPos then
                        finalPos =
                            Vector3.new(
                                slotPos.X,
                                FLOOR2_PART_Y,
                                slotPos.Z
                            )

                        spawnSupportPartUnderSlot(slot)
                    end
                end

            elseif isFloor3 then
                local f3 =
                    Workspace:FindFirstChild(
                        FLOOR3_PART_NAME
                    )

                if f3 then
                    finalPos =
                        f3.Position
                else
                    local slotPos =
                        getSlotPositionByNumber(slot)

                    if slotPos then
                        finalPos =
                            Vector3.new(
                                slotPos.X,
                                FLOOR3_PART_Y,
                                slotPos.Z
                            )

                        spawnFloor3PartUnderSlot(slot)
                    end
                end

            else
                local slotPos =
                    getSlotPositionByNumber(slot)

                if slotPos then
                    finalPos =
                        slotPos
                end
            end

            local curHrp =
                LP.Character
                and LP.Character:FindFirstChild(
                    "HumanoidRootPart"
                )

            if curHrp then
                local flat =
                    flatDist(
                        finalPos,
                        curHrp.Position
                    )

                if flat > 2.5 then
                    local dir =
                        (finalPos - curHrp.Position).Unit

                    curHrp.Velocity =
                        dir * SPD

                    if isFloor2
                        and curHrp.Position.Y > Y_CAP_FLOOR1 then

                        local np =
                            Vector3.new(
                                curHrp.Position.X,
                                Y_CAP_FLOOR1,
                                curHrp.Position.Z
                            )

                        curHrp.CFrame =
                            CFrame.new(
                                np,
                                np + Vector3.new(
                                    dir.X,
                                    0,
                                    dir.Z
                                )
                            )

                        curHrp.Velocity =
                            Vector3.new(
                                curHrp.Velocity.X,
                                0,
                                curHrp.Velocity.Z
                            )
                    end

                else
                    if isFloor2
                        and supportPart
                        and supportPart.Parent then

                        local lockY =
                            supportPart.Position.Y
                            + 0.25
                            + 3

                        if lockY > Y_CAP_FLOOR1 then
                            lockY = Y_CAP_FLOOR1
                        end

                        curHrp.CFrame =
                            CFrame.new(
                                Vector3.new(
                                    supportPart.Position.X,
                                    lockY,
                                    supportPart.Position.Z
                                )
                            )

                        curHrp.AssemblyLinearVelocity =
                            Vector3.zero

                        curHrp.AssemblyAngularVelocity =
                            Vector3.zero

                    elseif isFloor3 then
                        local f3 =
                            Workspace:FindFirstChild(
                                FLOOR3_PART_NAME
                            )

                        if f3 then
                            local lockY =
                                f3.Position.Y
                                + 0.25
                                + 3

                            curHrp.CFrame =
                                CFrame.new(
                                    Vector3.new(
                                        f3.Position.X,
                                        lockY,
                                        f3.Position.Z
                                    )
                                )

                            curHrp.AssemblyLinearVelocity =
                                Vector3.zero

                            curHrp.AssemblyAngularVelocity =
                                Vector3.zero
                        end

                    else
                        local keepY =
                            curHrp.Position.Y

                        curHrp.CFrame =
                            CFrame.new(
                                Vector3.new(
                                    finalPos.X,
                                    keepY,
                                    finalPos.Z
                                )
                            )

                        curHrp.AssemblyLinearVelocity =
                            Vector3.new(
                                0,
                                curHrp.AssemblyLinearVelocity.Y,
                                0
                            )

                        curHrp.AssemblyAngularVelocity =
                            Vector3.zero
                    end

                    break
                end
            end

            task.wait(0.02)
        end

        if onArrive then
            onArrive(slot)
        end
    end)
end

local function attachPetViewport(viewport, petName, mutation)
    if not SharedAnimals then
        return false
    end

    if type(
        SharedAnimals.AttachOnViewportWithOptimizations
    ) ~= "function" then
        return false
    end

    local mut = mutation

    if mut == ""
        or mut == "None"
        or tostring(mut) == "nil" then

        mut = nil
    end

    local ok = pcall(function()
        SharedAnimals:AttachOnViewportWithOptimizations(
            petName,
            viewport,
            nil,
            mut
        )
    end)

    return ok
end

local CraftingMachine

for _, v in ipairs(PlayerGui:GetDescendants()) do
    if v.Name == "CraftingMachine" then
        CraftingMachine = v
        break
    end
end

if not CraftingMachine then
    return
end

local List =
    CraftingMachine:FindFirstChild(
        "List",
        true
    )

local Content =
    CraftingMachine:FindFirstChild(
        "Content",
        true
    )

if not List or not Content then
    return
end

local Brainrots =
    Content:FindFirstChild(
        "Brainrots",
        true
    )

if not Brainrots then
    return
end

if not loadModules() then
    return
end

if type(
    SharedAnimals.AttachOnViewportWithOptimizations
) ~= "function" then
    return
end

local MENU_W = 300
local CELL   = 52
local GAP    = 5
local COLS   = 5
local PAD    = 6

local HEADER_H         = 36
local REQUIRED_TITLE_H = 22
local REQUIRED_CELL_H  = 52
local REQUIRED_H =
    REQUIRED_TITLE_H
    + REQUIRED_CELL_H
    + 5

local GRID_H =
    CELL
    + (PAD * 2)

local MENU_H =
    HEADER_H
    + GRID_H
    + REQUIRED_H

local BLOCK_STRIP_H = 18

local BLACKLIST_W = 150

local BLACKLIST_FILE =
    "blacklistFuse.json"

local blacklist = {}

local function loadBlacklist()
    blacklist = {}

    if type(isfile) ~= "function"
        or type(readfile) ~= "function" then
        return
    end

    if not isfile(BLACKLIST_FILE) then
        return
    end

    local ok, data =
        pcall(readfile, BLACKLIST_FILE)

    if not ok
        or type(data) ~= "string"
        or data == "" then
        return
    end

    local ok2, decoded =
        pcall(function()
            return game:GetService(
                "HttpService"
            ):JSONDecode(data)
        end)

    if not ok2 or type(decoded) ~= "table" then
        return
    end

    for _, name in ipairs(decoded) do
        if type(name) == "string"
            and name ~= "" then

            blacklist[name] = true
        end
    end
end

local function saveBlacklist()
    if type(writefile) ~= "function" then
        return
    end

    local list = {}

    for name in pairs(blacklist) do
        table.insert(list, name)
    end

    table.sort(list)

    local ok, encoded =
        pcall(function()
            return game:GetService(
                "HttpService"
            ):JSONEncode(list)
        end)

    if not ok then
        return
    end

    pcall(writefile, BLACKLIST_FILE, encoded)
end

local function isBlacklisted(name)
    if not name then
        return false
    end

    return blacklist[name] == true
end

local function blacklistAdd(name)
    if not name or name == "" then
        return
    end

    blacklist[name] = true
    saveBlacklist()
end

local function blacklistRemove(name)
    if not name then
        return
    end

    blacklist[name] = nil
    saveBlacklist()
end

loadBlacklist()

local blockMode = false

local THEME = {
    Base      = Color3.fromRGB(9, 7, 16),
    Panel     = Color3.fromRGB(19, 15, 32),
    PanelAlt  = Color3.fromRGB(27, 19, 44),
    Accent1   = Color3.fromRGB(150, 90, 255),
    Accent2   = Color3.fromRGB(70, 205, 255),
    Good1     = Color3.fromRGB(70, 220, 140),
    Good2     = Color3.fromRGB(30, 170, 120),
    Bad1      = Color3.fromRGB(235, 90, 100),
    Bad2      = Color3.fromRGB(180, 40, 60),
    Text      = Color3.fromRGB(242, 242, 252),
    SubText   = Color3.fromRGB(170, 165, 190),
}

local function tween(obj, props, t, style, dir)
    local info = TweenInfo.new(
        t or 0.18,
        style or Enum.EasingStyle.Quad,
        dir or Enum.EasingDirection.Out
    )
    local tw = TweenService:Create(obj, info, props)
    tw:Play()
    return tw
end

local function addCorner(inst, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = inst
    return c
end

local function addStroke(inst, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.Accent1
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.35
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = inst
    return s
end

local function addGradient(inst, rotation, colorSeq)
    local g = Instance.new("UIGradient")
    g.Rotation = rotation or 0
    g.Color = colorSeq or ColorSequence.new(THEME.Panel, THEME.PanelAlt)
    g.Parent = inst
    return g
end

local function hoverGlow(button, base, hover)
    button.MouseEnter:Connect(function()
        tween(button, {BackgroundColor3 = hover}, 0.15)
    end)
    button.MouseLeave:Connect(function()
        tween(button, {BackgroundColor3 = base}, 0.15)
    end)
end

local ScreenGui =
    PlayerGui:FindFirstChild(
        "KurdHubPetViewer"
    )

if not ScreenGui then
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "KurdHubPetViewer"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = PlayerGui
end

local oldCraft =
    PlayerGui:FindFirstChild(
        "KurdCraftingViewer"
    )

if oldCraft then
    oldCraft:Destroy()
end

local Menu = Instance.new("Frame")
Menu.Name = "CraftMenu"
Menu.Size = UDim2.new(0, MENU_W, 0, MENU_H)
Menu.Position = UDim2.new(0, 10, 0.5, -MENU_H / 2)
Menu.BackgroundColor3 = THEME.Panel
Menu.BackgroundTransparency = 0.04
Menu.BorderSizePixel = 0
Menu.ClipsDescendants = true
Menu.Active = true
Menu.ZIndex = 10
Menu.Parent = ScreenGui

addCorner(Menu, 14)
addGradient(Menu, 60, ColorSequence.new{
    ColorSequenceKeypoint.new(0, THEME.Panel),
    ColorSequenceKeypoint.new(1, THEME.PanelAlt),
})
addStroke(Menu, THEME.Accent1, 1.5, 0.25)

local RequiredBackBtn = Instance.new("TextButton")
RequiredBackBtn.Name = "RequiredBackButton"
RequiredBackBtn.Parent = ScreenGui
RequiredBackBtn.Size = UDim2.new(0, 52, 0, 40)
RequiredBackBtn.BackgroundColor3 = THEME.PanelAlt
RequiredBackBtn.BorderSizePixel = 0
RequiredBackBtn.Text = "↩️"
RequiredBackBtn.TextSize = 26
RequiredBackBtn.TextColor3 = THEME.Text
RequiredBackBtn.AutoButtonColor = false
RequiredBackBtn.ZIndex = 50
addCorner(RequiredBackBtn, 12)
addStroke(RequiredBackBtn, THEME.Accent2, 1, 0.4)
hoverGlow(RequiredBackBtn, THEME.PanelAlt, Color3.fromRGB(40, 30, 62))

local BACK_BTN_OFFSET_Y = 60

local function updateRequiredBackPosition()
    local p = Menu.AbsolutePosition
    local s = Menu.AbsoluteSize
    RequiredBackBtn.Position = UDim2.fromOffset(
        p.X + 16,
        p.Y + s.Y + BACK_BTN_OFFSET_Y
    )
end

task.defer(updateRequiredBackPosition)

RunService.RenderStepped:Connect(function()
    if Menu and Menu.Parent then
        updateRequiredBackPosition()
    end
end)

local Header = Instance.new("TextLabel")
Header.Name = "Header"
Header.Size = UDim2.new(1, -110, 0, HEADER_H)
Header.Position = UDim2.new(0, 100, 0, 0)
Header.BackgroundTransparency = 1
Header.Text = "Mziry - Craft Machine"
Header.TextColor3 = THEME.Text
Header.Font = Enum.Font.GothamBlack
Header.TextSize = 16
Header.TextXAlignment = Enum.TextXAlignment.Center
Header.ZIndex = 11
Header.Parent = Menu

addGradient(Header, 0, ColorSequence.new{
    ColorSequenceKeypoint.new(0, THEME.Accent2),
    ColorSequenceKeypoint.new(1, THEME.Accent1),
})


local SettingsBtn = Instance.new("TextButton")
SettingsBtn.Name = "SettingsBtn"
SettingsBtn.Size = UDim2.new(0, HEADER_H - 8, 0, HEADER_H - 8)
SettingsBtn.AnchorPoint = Vector2.new(1, 0)
SettingsBtn.Position = UDim2.new(1, -6, 0, 4)
SettingsBtn.BackgroundColor3 = THEME.PanelAlt
SettingsBtn.BorderSizePixel = 0
SettingsBtn.Text = "⚙"
SettingsBtn.TextColor3 = THEME.Text
SettingsBtn.TextSize = 18
SettingsBtn.Font = Enum.Font.GothamBold
SettingsBtn.AutoButtonColor = false
SettingsBtn.ZIndex = 12
SettingsBtn.Parent = Menu
addCorner(SettingsBtn, 8)
addStroke(SettingsBtn, THEME.Accent2, 1, 0.5)
hoverGlow(SettingsBtn, THEME.PanelAlt, Color3.fromRGB(40, 30, 62))

local BlockToggleBtn = Instance.new("TextButton")
BlockToggleBtn.Name = "BlockToggleBtn"
BlockToggleBtn.Size = UDim2.new(0, 80, 0, HEADER_H - 8)
BlockToggleBtn.Position = UDim2.new(0, 16, 0, 4)
BlockToggleBtn.BackgroundColor3 = blockMode and THEME.Good2 or THEME.Bad2
BlockToggleBtn.BorderSizePixel = 0
BlockToggleBtn.Text = "BLOCK"
BlockToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
BlockToggleBtn.TextSize = 14
BlockToggleBtn.Font = Enum.Font.GothamBold
BlockToggleBtn.AutoButtonColor = false
BlockToggleBtn.ZIndex = 12
BlockToggleBtn.Parent = Menu

addCorner(BlockToggleBtn, 8)
addStroke(BlockToggleBtn, Color3.fromRGB(255, 255, 255), 1, 0.35)

local CraftGrid = Instance.new("Frame")
CraftGrid.Name = "CraftGrid"
CraftGrid.Size = UDim2.new(1, 0, 0, GRID_H)
CraftGrid.Position = UDim2.new(0, 0, 0, HEADER_H)
CraftGrid.BackgroundTransparency = 1
CraftGrid.Parent = Menu

local GridPadding = Instance.new("UIPadding")
GridPadding.PaddingLeft = UDim.new(0, PAD)
GridPadding.PaddingRight = UDim.new(0, PAD)
GridPadding.PaddingTop = UDim.new(0, PAD)
GridPadding.PaddingBottom = UDim.new(0, PAD)
GridPadding.Parent = CraftGrid

local GridLayout = Instance.new("UIGridLayout")
GridLayout.CellSize = UDim2.new(0, CELL, 0, CELL)
GridLayout.CellPadding = UDim2.new(0, GAP, 0, 0)
GridLayout.FillDirectionMaxCells = COLS
GridLayout.SortOrder = Enum.SortOrder.LayoutOrder
GridLayout.Parent = CraftGrid

local RequiredFrame = Instance.new("Frame")
RequiredFrame.Name = "Required"
RequiredFrame.Size = UDim2.new(1, -12, 0, REQUIRED_H)
RequiredFrame.Position = UDim2.new(0, 6, 0, HEADER_H + GRID_H)
RequiredFrame.BackgroundColor3 = THEME.Base
RequiredFrame.BackgroundTransparency = 0.1
RequiredFrame.BorderSizePixel = 0
RequiredFrame.ClipsDescendants = true
RequiredFrame.ZIndex = 11
RequiredFrame.Parent = Menu

addCorner(RequiredFrame, 10)
addStroke(RequiredFrame, THEME.Accent1, 1, 0.6)

local RequiredContainer = Instance.new("Frame")
RequiredContainer.Name = "RequiredContainer"
RequiredContainer.Size = UDim2.new(1, -10, 0, REQUIRED_TITLE_H)
RequiredContainer.Position = UDim2.new(0, 6, 0, 0)
RequiredContainer.BackgroundTransparency = 1
RequiredContainer.ZIndex = 12
RequiredContainer.Parent = RequiredFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.FillDirection = Enum.FillDirection.Horizontal
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 2)
ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
ListLayout.Parent = RequiredContainer

local RedLabel = Instance.new("TextLabel")
RedLabel.AutomaticSize = Enum.AutomaticSize.X
RedLabel.Size = UDim2.new(0, 0, 1, 0)
RedLabel.BackgroundTransparency = 1
RedLabel.TextColor3 = Color3.fromRGB(255, 68, 68)
RedLabel.Text = "🔴 کەسێ نینە"
RedLabel.Font = Enum.Font.GothamBold
RedLabel.TextSize = 16
RedLabel.TextXAlignment = Enum.TextXAlignment.Left
RedLabel.LayoutOrder = 1
RedLabel.Parent = RequiredContainer

local YellowLabel = Instance.new("TextLabel")
YellowLabel.AutomaticSize = Enum.AutomaticSize.X
YellowLabel.Size = UDim2.new(0, 0, 1, 0)
YellowLabel.BackgroundTransparency = 1
YellowLabel.TextColor3 = Color3.fromRGB(255, 204, 0)
YellowLabel.Text = "🟡 تە نینە هەڤاڵێ تەیێ هەی"
YellowLabel.Font = Enum.Font.GothamBold
YellowLabel.TextSize = 16
YellowLabel.TextXAlignment = Enum.TextXAlignment.Left
YellowLabel.LayoutOrder = 2
YellowLabel.Parent = RequiredContainer

local GreenLabel = Instance.new("TextLabel")
GreenLabel.AutomaticSize = Enum.AutomaticSize.X
GreenLabel.Size = UDim2.new(0, 0, 1, 0)
GreenLabel.BackgroundTransparency = 1
GreenLabel.TextColor3 = Color3.fromRGB(68, 255, 68)
GreenLabel.Text = "🟢 تەیێ هەی"
GreenLabel.Font = Enum.Font.GothamBold
GreenLabel.TextSize = 16
GreenLabel.TextXAlignment = Enum.TextXAlignment.Left
GreenLabel.LayoutOrder = 3
GreenLabel.Parent = RequiredContainer

local RequiredGrid = Instance.new("Frame")
RequiredGrid.Name = "RequiredGrid"
RequiredGrid.Size = UDim2.new(1, -10, 0, REQUIRED_CELL_H)
RequiredGrid.Position = UDim2.new(0, 5, 0, REQUIRED_TITLE_H)
RequiredGrid.BackgroundTransparency = 1
RequiredGrid.ZIndex = 12
RequiredGrid.Parent = RequiredFrame

local RequiredLayout = Instance.new("UIGridLayout")
RequiredLayout.CellSize = UDim2.new(0, CELL, 0, CELL)
RequiredLayout.CellPadding = UDim2.new(0, GAP, 0, 0)
RequiredLayout.FillDirectionMaxCells = COLS
RequiredLayout.SortOrder = Enum.SortOrder.LayoutOrder
RequiredLayout.Parent = RequiredGrid

local SettingsPanel = Instance.new("Frame")
SettingsPanel.Name = "BlacklistPanel"
SettingsPanel.Size = UDim2.new(0, BLACKLIST_W, 0, MENU_H)
SettingsPanel.BackgroundColor3 = THEME.Base
SettingsPanel.BackgroundTransparency = 0.05
SettingsPanel.BorderSizePixel = 0
SettingsPanel.ClipsDescendants = true
SettingsPanel.Visible = false
SettingsPanel.ZIndex = 100
SettingsPanel.Parent = ScreenGui

addCorner(SettingsPanel, 14)
addGradient(SettingsPanel, 60, ColorSequence.new{
    ColorSequenceKeypoint.new(0, THEME.Base),
    ColorSequenceKeypoint.new(1, THEME.Panel),
})
addStroke(SettingsPanel, THEME.Accent2, 1.5, 0.3)

local SettingsPanelTitle = Instance.new("TextLabel")
SettingsPanelTitle.Name = "Title"
SettingsPanelTitle.Size = UDim2.new(1, -40, 0, 32)
SettingsPanelTitle.Position = UDim2.new(0, 12, 0, 4)
SettingsPanelTitle.BackgroundTransparency = 1
SettingsPanelTitle.Text = "⛔ BLACKLIST"
SettingsPanelTitle.TextColor3 = THEME.Text
SettingsPanelTitle.Font = Enum.Font.GothamBold
SettingsPanelTitle.TextSize = 15
SettingsPanelTitle.TextXAlignment = Enum.TextXAlignment.Left
SettingsPanelTitle.ZIndex = 101
SettingsPanelTitle.Parent = SettingsPanel

local SettingsClose = Instance.new("TextButton")
SettingsClose.Name = "Close"
SettingsClose.Size = UDim2.new(0, 26, 0, 26)
SettingsClose.AnchorPoint = Vector2.new(1, 0)
SettingsClose.Position = UDim2.new(1, -6, 0, 5)
SettingsClose.BackgroundColor3 = THEME.Bad1
SettingsClose.BorderSizePixel = 0
SettingsClose.Text = "×"
SettingsClose.TextColor3 = THEME.Text
SettingsClose.TextSize = 18
SettingsClose.Font = Enum.Font.GothamBold
SettingsClose.AutoButtonColor = false
SettingsClose.ZIndex = 102
SettingsClose.Parent = SettingsPanel
addCorner(SettingsClose, 8)
addGradient(SettingsClose, 90, ColorSequence.new{
    ColorSequenceKeypoint.new(0, THEME.Bad1),
    ColorSequenceKeypoint.new(1, THEME.Bad2),
})
hoverGlow(SettingsClose, THEME.Bad1, Color3.fromRGB(250, 110, 120))

local SettingsScroll = Instance.new("ScrollingFrame")
SettingsScroll.Name = "Scroll"
SettingsScroll.Size = UDim2.new(1, -14, 1, -42)
SettingsScroll.Position = UDim2.new(0, 7, 0, 36)
SettingsScroll.BackgroundTransparency = 1
SettingsScroll.BorderSizePixel = 0
SettingsScroll.ScrollBarThickness = 4
SettingsScroll.ScrollBarImageColor3 = THEME.Accent1
SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
SettingsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
SettingsScroll.ZIndex = 101
SettingsScroll.Parent = SettingsPanel

local SettingsLayout = Instance.new("UIListLayout")
SettingsLayout.Padding = UDim.new(0, 6)
SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
SettingsLayout.Parent = SettingsScroll

local settingsTweening = false

RunService.RenderStepped:Connect(function()
    if not (Menu and Menu.Parent) then return end
    local p = Menu.AbsolutePosition
    local s = Menu.AbsoluteSize
    local ph = SettingsPanel.AbsoluteSize.Y

    SettingsPanel.Position = UDim2.fromOffset(
        p.X + s.X + 20,
        p.Y + (s.Y - ph) / 2 + 60
    )
end)

local function refreshSettingsList()
    for _, child in ipairs(
        SettingsScroll:GetChildren()
    ) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end

    local names = {}

    for name in pairs(blacklist) do
        table.insert(names, name)
    end

    table.sort(names)

    if #names == 0 then
        local empty =
            Instance.new("TextLabel")

        empty.Size =
            UDim2.new(
                1,
                -10,
                0,
                34
            )

        empty.BackgroundTransparency =
            1

        empty.Text =
            "empty"

        empty.TextColor3 =
            Color3.fromRGB(
                140,
                140,
                150
            )

        empty.Font =
            Enum.Font.Gotham

        empty.TextSize =
            14

        empty.TextXAlignment =
            Enum.TextXAlignment.Center

        empty.ZIndex =
            102

        empty.Parent =
            SettingsScroll

        return
    end

    for i, name in ipairs(names) do
        local row =
            Instance.new("Frame")

        row.Name =
            "Row_" .. tostring(i)

        row.Size =
            UDim2.new(
                1,
                -10,
                0,
                44
            )

        row.BackgroundColor3 =
            Color3.fromRGB(
                30,
                30,
                36
            )

        row.BorderSizePixel =
            0

        row.LayoutOrder =
            i

        row.ZIndex =
            102

        row.Parent =
            SettingsScroll

        local rowCorner =
            Instance.new("UICorner")

        rowCorner.CornerRadius =
            UDim.new(0, 7)

        rowCorner.Parent =
            row

        local petCell =
            Instance.new("Frame")

        petCell.Name =
            "PetCell"

        petCell.Size =
            UDim2.new(
                0,
                36,
                0,
                36
            )

        petCell.Position =
            UDim2.new(
                0,
                6,
                0.5,
                0
            )

        petCell.AnchorPoint =
            Vector2.new(
                0,
                0.5
            )

        petCell.BackgroundColor3 =
            Color3.fromRGB(
                20,
                20,
                24
            )

        petCell.BorderSizePixel =
            0

        petCell.ClipsDescendants =
            true

        petCell.ZIndex =
            103

        petCell.Parent =
            row

        local petCellCorner =
            Instance.new("UICorner")

        petCellCorner.CornerRadius =
            UDim.new(0, 6)

        petCellCorner.Parent =
            petCell

        local viewport =
            Instance.new("ViewportFrame")

        viewport.Name =
            "View"

        viewport.Size =
            UDim2.new(
                1,
                0,
                1,
                0
            )

        viewport.BackgroundTransparency =
            1

        viewport.BorderSizePixel =
            0

        viewport.Ambient =
            Color3.fromRGB(
                200,
                200,
                200
            )

        viewport.LightColor =
            Color3.fromRGB(
                255,
                255,
                255
            )

        viewport.LightDirection =
            Vector3.new(
                -1,
                -1,
                -1
            )

        viewport.ZIndex =
            104

        viewport.Parent =
            petCell

        attachPetViewport(
            viewport,
            name,
            nil
        )

        local unblockBtn =
            Instance.new("TextButton")

        unblockBtn.Name =
            "Whitelist"

        unblockBtn.Size =
            UDim2.new(
                0,
                32,
                0,
                32
            )

        unblockBtn.AnchorPoint =
            Vector2.new(
                1,
                0.5
            )

        unblockBtn.Position =
            UDim2.new(
                1,
                -6,
                0.5,
                0
            )

        unblockBtn.BackgroundColor3 =
            Color3.fromRGB(
                70,
                140,
                220
            )

        unblockBtn.BorderSizePixel =
            0

        unblockBtn.Text =
            "X"

        unblockBtn.TextColor3 =
            Color3.fromRGB(
                255,
                255,
                255
            )

        unblockBtn.TextSize =
            15

        unblockBtn.Font =
            Enum.Font.GothamBold

        unblockBtn.AutoButtonColor =
            true

        unblockBtn.ZIndex =
            105

        unblockBtn.Parent =
            row

        local unblockCorner =
            Instance.new("UICorner")

        unblockCorner.CornerRadius =
            UDim.new(0, 7)

        unblockCorner.Parent =
            unblockBtn

        unblockBtn.Activated:Connect(function()
            blacklistRemove(name)

            refreshSettingsList()
            rebuild()
            showRequired()
        end)
    end
end

local function toggleSettings(force)
    if settingsTweening then return end

    local show
    if force ~= nil then
        show = force
    else
        show = not SettingsPanel.Visible
    end

    if show == SettingsPanel.Visible then return end

    settingsTweening = true
    tween(SettingsBtn, {Rotation = show and 90 or 0}, 0.25, Enum.EasingStyle.Back)

    if show then
        SettingsPanel.Visible = true
        SettingsPanel.Size = UDim2.new(0, BLACKLIST_W, 0, 0)
        refreshSettingsList()
        tween(SettingsPanel, {
            Size = UDim2.new(0, BLACKLIST_W, 0, MENU_H),
        }, 0.22, Enum.EasingStyle.Back).Completed:Connect(function()
            settingsTweening = false
        end)
    else
        tween(SettingsPanel, {
            Size = UDim2.new(0, BLACKLIST_W, 0, 0),
        }, 0.18, Enum.EasingStyle.Quad).Completed:Connect(function()
            SettingsPanel.Visible = false
            settingsTweening = false
        end)
    end
end

SettingsBtn.Activated:Connect(function()
    toggleSettings()
end)

SettingsClose.Activated:Connect(function()
    toggleSettings(false)
end)

local function applyBlockToggleVisual()
    if blockMode then
        BlockToggleBtn.BackgroundColor3 = THEME.Good2
        BlockToggleBtn.Text = "BLOCK"
    else
        BlockToggleBtn.BackgroundColor3 = THEME.Bad2
        BlockToggleBtn.Text = "BLOCK"
    end
end


applyBlockToggleVisual()

local dragging = false
local dragStart
local startPos

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then

        dragging = true
        dragStart = input.Position
        startPos = Menu.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end

    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement then

        local delta = input.Position - dragStart

        local newX = startPos.X.Offset + delta.X
        local newY = startPos.Y.Offset + delta.Y

        Menu.Position = UDim2.new(
            startPos.X.Scale, newX,
            startPos.Y.Scale, newY
        )
    end
end)

local function createPreview(
    parent,
    animalName,
    mutation,
    size,
    clickable,
    withBlock
)
    local Cell =
        Instance.new("Frame")

    Cell.Size =
        UDim2.new(
            0,
            size,
            0,
            size
        )

    Cell.BackgroundColor3 =
        Color3.fromRGB(
            30,
            30,
            34
        )

    Cell.BorderSizePixel =
        0

    Cell.ClipsDescendants =
        true

    Cell.Parent =
        parent

    local Corner =
        Instance.new("UICorner")

    Corner.CornerRadius =
        UDim.new(0, 7)

    Corner.Parent =
        Cell

    local Stroke =
        Instance.new("UIStroke")

    Stroke.Color =
        Color3.fromRGB(
            255,
            255,
            255
        )

    Stroke.Transparency =
        0.78

    Stroke.Thickness =
        1

    Stroke.Parent =
        Cell

    local Viewport =
        Instance.new("ViewportFrame")

    Viewport.Name =
        "View"

    Viewport.Size =
        UDim2.new(
            1,
            0,
            1,
            0
        )

    Viewport.BackgroundTransparency =
        1

    Viewport.BorderSizePixel =
        0

    Viewport.Ambient =
        Color3.fromRGB(
            200,
            200,
            200
        )

    Viewport.LightColor =
        Color3.fromRGB(
            255,
            255,
            255
        )

    Viewport.LightDirection =
        Vector3.new(
            -1,
            -1,
            -1
        )

    Viewport.ZIndex =
        1

    Viewport.Parent =
        Cell

    attachPetViewport(
        Viewport,
        animalName,
        mutation
    )

    local Click

    if clickable then
        Click =
            Instance.new("TextButton")

        Click.Name =
            "Click"

        Click.Size =
            UDim2.new(
                1,
                0,
                1,
                withBlock
                and -BLOCK_STRIP_H
                or 0
            )

        Click.Position =
            UDim2.new(
                0,
                0,
                0,
                withBlock
                and BLOCK_STRIP_H
                or 0
            )

        Click.BackgroundTransparency =
            1

        Click.Text =
            ""

        Click.AutoButtonColor =
            false

        Click.ZIndex =
            20

        Click.Parent =
            Cell
    end

    local BlockBtn

    if withBlock then
        BlockBtn =
            Instance.new("TextButton")

        BlockBtn.Name =
            "BlockBtn"

        BlockBtn.Size =
            UDim2.new(
                1,
                0,
                0,
                BLOCK_STRIP_H
            )

        BlockBtn.Position =
            UDim2.new(
                0,
                0,
                0,
                0
            )

        BlockBtn.BackgroundColor3 =
            Color3.fromRGB(
                180,
                45,
                45
            )

        BlockBtn.BackgroundTransparency =
            0.05

        BlockBtn.BorderSizePixel =
            0

        BlockBtn.Text =
            "BLOCK"

        BlockBtn.TextColor3 =
            Color3.fromRGB(
                255,
                255,
                255
            )

        BlockBtn.TextSize =
            12

        BlockBtn.Font =
            Enum.Font.GothamBold

        BlockBtn.AutoButtonColor =
            true

        BlockBtn.ZIndex =
            30

        BlockBtn.Parent =
            Cell

        local BlockCorner =
            Instance.new("UICorner")

        BlockCorner.CornerRadius =
            UDim.new(0, 6)

        BlockCorner.Parent =
            BlockBtn
    end

    return Cell,
        Stroke,
        Click,
        BlockBtn
end

local function refreshBlockButtons()
    for _, cell in ipairs(
        CraftGrid:GetChildren()
    ) do
        if cell:IsA("Frame") then
            local existing =
                cell:FindFirstChild(
                    "BlockBtn"
                )

            local click =
                cell:FindFirstChild(
                    "Click"
                )

            if blockMode
                and not existing then

                local name =
                    cell:GetAttribute(
                        "AnimalName"
                    )

                if name then
                    local BlockBtn =
                        Instance.new(
                            "TextButton"
                        )

                    BlockBtn.Name =
                        "BlockBtn"

                    BlockBtn.Size =
                        UDim2.new(
                            1,
                            0,
                            0,
                            BLOCK_STRIP_H
                        )

                    BlockBtn.Position =
                        UDim2.new(
                            0,
                            0,
                            0,
                            0
                        )

                    BlockBtn.BackgroundColor3 =
                        Color3.fromRGB(
                            180,
                            45,
                            45
                        )

                    BlockBtn.BackgroundTransparency =
                        0.05

                    BlockBtn.BorderSizePixel =
                        0

                    BlockBtn.Text =
                        "BLOCK"

                    BlockBtn.TextColor3 =
                        Color3.fromRGB(
                            255,
                            255,
                            255
                        )

                    BlockBtn.TextSize =
                        12

                    BlockBtn.Font =
                        Enum.Font.GothamBold

                    BlockBtn.AutoButtonColor =
                        true

                    BlockBtn.ZIndex =
                        30

                    BlockBtn.Parent =
                        cell

                    local bc =
                        Instance.new(
                            "UICorner"
                        )

                    bc.CornerRadius =
                        UDim.new(
                            0,
                            6
                        )

                    bc.Parent =
                        BlockBtn

                    if click then
                        click.Size =
                            UDim2.new(
                                1,
                                0,
                                1,
                                -BLOCK_STRIP_H
                            )

                        click.Position =
                            UDim2.new(
                                0,
                                0,
                                0,
                                BLOCK_STRIP_H
                            )
                    end

                    BlockBtn.Activated:Connect(function()
                        blacklistAdd(name)

                        refreshSettingsList()
                        rebuild()
                        showRequired()
                    end)
                end

            elseif not blockMode
                and existing then

                existing:Destroy()

                if click then
                    click.Size =
                        UDim2.new(
                            1,
                            0,
                            1,
                            0
                        )

                    click.Position =
                        UDim2.new(
                            0,
                            0,
                            0,
                            0
                        )
                end
            end
        end
    end
end

local function getRequired()
    local result = {}

    for _, child in ipairs(
        Brainrots:GetChildren()
    ) do
        if child.Name == "Template"
            and child:IsA("Frame")
            and child.Visible then

            local title =
                child:FindFirstChild(
                    "Title"
                )

            if title
                and title:IsA("TextLabel") then

                local name =
                    title.Text

                if name
                    and name ~= ""
                    and not isBlacklisted(name) then

                    table.insert(
                        result,
                        name
                    )
                end
            end
        end
    end

    return result
end

local function clearRequired()
    for _, child in ipairs(
        RequiredGrid:GetChildren()
    ) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local selectedRequired = nil
local hiddenRequired = {}

function showRequired()
    hiddenRequired = {}
    selectedRequired = nil

    clearRequired()

    local required =
        getRequired()

    local occurrenceCounts = {}

    for _, animalName in ipairs(required) do
        occurrenceCounts[animalName] =
            (
                occurrenceCounts[animalName]
                or 0
            ) + 1

        local occurrence =
            occurrenceCounts[animalName]

        local cell, Stroke, Click =
            createPreview(
                RequiredGrid,
                animalName,
                nil,
                CELL,
                true,
                false
            )

        cell:SetAttribute(
            "AnimalName",
            animalName
        )

        cell:SetAttribute(
            "Occurrence",
            occurrence
        )

        local mySlot = findSlotByAnimalOccurrence(
            animalName,
            occurrence
        )

        local otherTarget = getOtherBaseTarget(
            animalName,
            occurrence
        )

        local inMine = mySlot ~= nil
        local inOther = otherTarget ~= nil

        local strokeColor
        local fillColor
        local targetType

        if inMine then
            strokeColor = Color3.fromRGB(60, 255, 100)
            fillColor   = Color3.fromRGB(40, 90, 55)
            targetType  = "Mine"

        elseif inOther then
            strokeColor = Color3.fromRGB(255, 220, 40)
            fillColor   = Color3.fromRGB(90, 80, 25)
            targetType  = "Other"

        else
            strokeColor = Color3.fromRGB(255, 60, 60)
            fillColor   = Color3.fromRGB(90, 30, 30)
            targetType  = "None"
        end

        Stroke.Color = strokeColor
        Stroke.Transparency = 0
        Stroke.Thickness = 2

        cell.BackgroundColor3 = fillColor

        local glow = Instance.new("UIStroke")
        glow.Name = "Glow"
        glow.Color = strokeColor
        glow.Thickness = 5
        glow.Transparency = 0.65
        glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        glow.Parent = cell

        cell:SetAttribute("TargetType", targetType)

        local baseColor = Stroke.Color
        local baseFill  = cell.BackgroundColor3
        local baseGlow  = glow.Color

        Click.Activated:Connect(function()
            selectedRequired =
                cell

            local targetType =
                cell:GetAttribute(
                    "TargetType"
                )

            if targetType == "Mine" then
                local slot =
                    findSlotByAnimalOccurrence(
                        animalName,
                        occurrence
                    )

                if not slot then
                    StarterGui:SetCore(
                        "SendNotification",
                        {
                            Title = animalName,
                            Text = "کەسێ نینە",
                            Duration = 3
                        }
                    )

                    return
                end

                travelToSlot(slot)

                return
            end

            if targetType == "Other" then
                local target =
                    getOtherBaseTarget(
                        animalName,
                        occurrence
                    )

                if not target then
                    StarterGui:SetCore(
                        "SendNotification",
                        {
                            Title = animalName,
                            Text = "تە نینە، بەس ئێکێ دیێ هەی",
                            Duration = 3
                        }
                    )

                    return
                end

                travelToOtherBase(target)

                return
            end

            StarterGui:SetCore(
                "SendNotification",
                {
                    Title = animalName,
                    Text = "کەسێ نینە",
                    Duration = 3
                }
            )
        end)

        Click.MouseEnter:Connect(function()
            Stroke.Color =
                Color3.fromRGB(
                    70,
                    180,
                    255
                )

            Stroke.Thickness = 3
            glow.Color = Color3.fromRGB(70, 180, 255)
            glow.Transparency = 0.4
        end)

        Click.MouseLeave:Connect(function()
            Stroke.Color =
                baseColor

            Stroke.Thickness = 2
            cell.BackgroundColor3 = baseFill
            glow.Color = baseGlow
            glow.Transparency = 0.65
        end)
    end
end

local lastAnimalState = ""

local function getAnimalState()
    local channels = _xchan

    if type(channels) ~= "table" then
        channels = dosocbSyncAll()

        if type(channels) ~= "table" then
            return ""
        end
    end

    local parts = {}

    for _, channel in pairs(channels) do
        if type(channel) == "table" then
            local animalList = _getChannelAnimalList(channel)

            if type(animalList) == "table" then
                local owner = _getChannelOwner(channel)
                local ownerKey

                if typeof(owner) == "Instance" then
                    ownerKey = owner.Name
                else
                    ownerKey = tostring(owner)
                end

                for slot, animalData in pairs(animalList) do
                    if type(animalData) == "table" then
                        parts[#parts + 1] =
                            ownerKey
                            .. ":"
                            .. tostring(slot)
                            .. ":"
                            .. tostring(animalData.Index)
                    end
                end
            end
        end
    end

    table.sort(parts)

    return table.concat(parts, "|")
end

local requiredRefreshQueued = false

local function queueRequiredRefresh()
    if requiredRefreshQueued then
        return
    end

    requiredRefreshQueued = true

    task.delay(0.15, function()
        requiredRefreshQueued = false

        if Menu and Menu.Parent then
            pcall(showRequired)
        end
    end)
end

_G.dosocbGetAnimalState = getAnimalState
_G.dosocbQueueRequiredRefresh = queueRequiredRefresh

task.defer(function()
    if Menu and Menu.Parent then
        pcall(function()
            lastAnimalState = getAnimalState()
        end)
    end
end)

task.spawn(function()
    while task.wait(0.25) do
        if not (Menu and Menu.Parent) then
            break
        end

        local ok, state = pcall(getAnimalState)

        if not ok then
            task.wait(0.5)
            continue
        end

        if state ~= lastAnimalState then
            lastAnimalState = state

            task.delay(0.1, function()
                if Menu and Menu.Parent then
                    pcall(showRequired)
                end
            end)
        end
    end
end)

LP:GetAttributeChangedSignal(
    "Stealing"
):Connect(function()
    if LP:GetAttribute("Stealing") == true then

        if selectedRequired
            and selectedRequired.Parent
            and selectedRequired.Visible then

            table.insert(
                hiddenRequired,
                selectedRequired
            )

            selectedRequired.Visible =
                false
        end
    end
end)

RequiredBackBtn.Activated:Connect(function()
    local cell =
        table.remove(
            hiddenRequired
        )

    if cell and cell.Parent then
        cell.Visible = true
    end

    selectedRequired = nil
end)

local function activateCraft(button)
    if type(getconnections) ~= "function" then
        return false
    end

    local connections =
        getconnections(
            button.Activated
        )

    for _, connection in ipairs(connections) do
        if connection.Function then
            local ok =
                pcall(function()
                    connection.Function()
                end)

            if ok then
                return true
            end
        end
    end

    return false
end

local bound = {}
local order = 0

local function addCraft(craft)
    if bound[craft] then
        return
    end

    local Button =
        craft:FindFirstChild(
            "Button",
            true
        )

    if not Button
        or not Button:IsA("GuiButton") then
        return
    end

    local Title =
        Button:FindFirstChild(
            "Title",
            true
        )

    if not Title
        or not Title:IsA("TextLabel") then
        return
    end

    local name =
        Title.Text

    if not name
        or name == ""
        or name == "Brainrot Name" then
        return
    end

    if isBlacklisted(name) then
        return
    end

    bound[craft] =
        true

    order += 1

    local Cell,
        Stroke,
        Click,
        BlockBtn =
        createPreview(
            CraftGrid,
            name,
            nil,
            CELL,
            true,
            blockMode
        )

    Cell.LayoutOrder =
        order

    Cell:SetAttribute(
        "AnimalName",
        name
    )

    Click.Activated:Connect(function()
        for _, child in ipairs(
            CraftGrid:GetChildren()
        ) do
            if child:IsA("Frame") then
                local s =
                    child:FindFirstChildOfClass(
                        "UIStroke"
                    )

                if s then
                    s.Color =
                        Color3.fromRGB(
                            255,
                            255,
                            255
                        )

                    s.Transparency =
                        0.78
                end
            end
        end

        Stroke.Color =
            Color3.fromRGB(
                70,
                180,
                255
            )

        Stroke.Transparency =
            0

        activateCraft(Button)

        task.wait(0.05)

        showRequired()
    end)

    if BlockBtn then
        BlockBtn.Activated:Connect(function()
            blacklistAdd(name)

            refreshSettingsList()
            rebuild()
            showRequired()
        end)
    end
end

function rebuild()
    for _, child in ipairs(
        CraftGrid:GetChildren()
    ) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    bound = {}
    order = 0

    for _, craft in ipairs(
        List:GetChildren()
    ) do
        addCraft(craft)
    end
end

rebuild()

BlockToggleBtn.Activated:Connect(function()
    blockMode = not blockMode

    applyBlockToggleVisual()
    refreshBlockButtons()
end)

List.ChildAdded:Connect(function(child)
    task.wait()
    addCraft(child)
end)

List.ChildRemoved:Connect(function()
    task.wait()
    rebuild()
end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local r0js = 0

local function sobz()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return end
    pcall(function()
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        root.Velocity = Vector3.zero
        root.RotVelocity = Vector3.zero
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("Motor6D") then obj.Enabled = true end
            if obj:IsA("Constraint") then obj.Enabled = true end
        end
        workspace.CurrentCamera.CameraSubject = hum
        local PM = player.PlayerScripts:FindFirstChild("PlayerModule")
        if PM then
            local CM = require(PM:FindFirstChild("ControlModule"))
            if CM then CM:Enable() end
        end
        hum.AutoRotate = true
        hum.PlatformStand = false
        hum.Sit = false
    end)
end

if not _G.dj91 then
    _G.do9bs = true
    _G.dj91 = RunService.Heartbeat:Connect(function()
        if not _G.do9bs then return end
        local char = player.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        local state = hum:GetState()
        local isRagdolled = (state == Enum.HumanoidStateType.Physics or
            state == Enum.HumanoidStateType.Ragdoll or
            state == Enum.HumanoidStateType.FallingDown)
        if isRagdolled then
            local now = tick()
            if now - r0js > 0.15 then
                r0js = now
                sobz()
            end
        end
    end)
else
    _G.do9bs = false
    if _G.dj91 then
        _G.dj91:Disconnect()
        _G.dj91 = nil
    end
end
