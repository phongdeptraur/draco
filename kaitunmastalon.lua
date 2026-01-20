-- Blox Fruits: SetTeam MARINES -> Wait char -> Run Script A ALWAYS
-- Then: if no Dragon Talon -> TP + Tween (lagback retry) -> BuyDragonTalon
-- After: Check Mastery Dragon Talon (equip + read UI). If mastery <= 500 -> run Script B.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local lp = Players.LocalPlayer
repeat task.wait() until lp

local function setStatus(tag, msg)
    print(string.format("[%s] %s", tostring(tag), tostring(msg)))
end

-- ===== Remotes =====
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local comm = remotes:WaitForChild("CommF_")

-- ===== Character helpers =====
local function waitChar()
    local ch = lp.Character
    if not ch then ch = lp.CharacterAdded:Wait() end
    local hum = ch:FindFirstChildOfClass("Humanoid") or ch:WaitForChild("Humanoid")
    local hrp = ch:FindFirstChild("HumanoidRootPart") or ch:WaitForChild("HumanoidRootPart")
    return ch, hum, hrp
end

local function isMarines()
    local t = lp.Team
    return (t and t.Name and string.lower(t.Name) == "marines") or false
end

local function ensureMarines()
    local tries = 0
    while not isMarines() and tries < 12 do
        tries += 1
        pcall(function()
            comm:InvokeServer("SetTeam", "Marines")
        end)
        task.wait(0.35)
    end
    setStatus("TEAM", "Marines=" .. tostring(isMarines()) .. " (tries=" .. tries .. ")")
end

-- ===== Inventory check =====
local function hasDragonTalon()
    local ch = lp.Character
    local bp = lp:FindFirstChildOfClass("Backpack")
    if not bp then return false end
    if bp:FindFirstChild("Dragon Talon") then return true end
    if ch and ch:FindFirstChild("Dragon Talon") then return true end
    return false
end

-- ===== Move =====
local function tpTo(vec)
    local ch, hum, hrp = waitChar()
    if hum.SeatPart then hum.Sit = false end
    hrp.CFrame = CFrame.new(vec)
end

local function tweenToWithLagback(startVec, targetVec, speed, lagBackThreshold)
    speed = speed or 350
    lagBackThreshold = lagBackThreshold or 70

    local retries = 0

    while true do
        local ch, hum, hrp = waitChar()
        if hum.SeatPart then hum.Sit = false end

        hrp.CFrame = CFrame.new(startVec)
        task.wait(0.05)

        local dist0 = (hrp.Position - targetVec).Magnitude
        local t = dist0 / math.max(1, speed)

        local tween = TweenService:Create(
            hrp,
            TweenInfo.new(t, Enum.EasingStyle.Linear),
            { CFrame = CFrame.new(targetVec) }
        )

        local bestDist = math.huge
        local lagged = false

        tween:Play()

        while tween.PlaybackState == Enum.PlaybackState.Playing do
            local dist = (hrp.Position - targetVec).Magnitude
            if dist < bestDist then bestDist = dist end

            if dist > bestDist + lagBackThreshold then
                lagged = true
                break
            end

            task.wait(0.12)
        end

        if lagged then
            retries += 1
            pcall(function() tween:Cancel() end)
            setStatus("LAGBACK", "Detected -> retry #" .. retries)
            task.wait(0.2)
        else
            local finalDist = (hrp.Position - targetVec).Magnitude
            if finalDist <= 8 then
                setStatus("MOVE", "Arrived (retries=" .. retries .. ", finalDist=" .. math.floor(finalDist) .. ")")
                return retries
            end
            retries += 1
            setStatus("ROLLBACK", "Not arrived -> retry #" .. retries .. " (finalDist=" .. math.floor(finalDist) .. ")")
            task.wait(0.2)
        end
    end
end

-- ===== Small popup (3s) =====
local function popup3s(text)
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return end

    local sg = Instance.new("ScreenGui")
    sg.ResetOnSpawn = false
    sg.Name = "DT_MASTERY_POPUP"
    sg.Parent = pg

    local lbl = Instance.new("TextLabel")
    lbl.Parent = sg
    lbl.Size = UDim2.fromScale(0.65, 0.09)
    lbl.Position = UDim2.fromScale(0.175, 0.45)
    lbl.BackgroundColor3 = Color3.fromRGB(0,0,0)
    lbl.BackgroundTransparency = 0.25
    lbl.TextColor3 = Color3.fromRGB(0,255,0)
    lbl.TextScaled = true
    lbl.Font = Enum.Font.SourceSansBold
    lbl.BorderSizePixel = 0
    lbl.Text = tostring(text)

    task.delay(3, function()
        pcall(function() sg:Destroy() end)
    end)
end

-- ===== Mastery check (equip + read UI) =====
local function equipDragonTalon()
    local ch, hum = waitChar()
    local bp = lp:FindFirstChildOfClass("Backpack")
    if not bp then return false end

    local tool = bp:FindFirstChild("Dragon Talon") or ch:FindFirstChild("Dragon Talon")
    if not tool then return false end

    hum:EquipTool(tool)
    return true
end

local function parseMasteryFromText(txt)
    -- expect like: "Mastery 600 (MAX)" or "Mastery 432"
    if type(txt) ~= "string" then return nil end
    local n = string.match(txt, "Mastery%s+(%d+)")
    return n and tonumber(n) or nil
end

local function findMasteryLine(timeoutSec)
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return nil end

    local deadline = os.clock() + (timeoutSec or 2.0)
    while os.clock() < deadline do
        for _, gui in ipairs(pg:GetDescendants()) do
            if gui:IsA("TextLabel") or gui:IsA("TextButton") then
                local t = gui.Text
                if t and string.find(t, "Mastery") then
                    return t
                end
            end
        end
        task.wait(0.08)
    end
    return nil
end

local function checkDragonTalonMastery()
    if not equipDragonTalon() then
        setStatus("MASTERY", "Dragon Talon tool not found to equip")
        popup3s("❌ Dragon Talon NOT found (equip fail)")
        return nil
    end

    task.wait(0.25) -- chờ UI render
    local line = findMasteryLine(2.5)

    if not line then
        setStatus("MASTERY", "Mastery UI not found")
        popup3s("⚠️ Mastery UI not found")
        return nil
    end

    local m = parseMasteryFromText(line)
    setStatus("MASTERY", tostring(line) .. " | parsed=" .. tostring(m))
    popup3s("✅ " .. line)

    return m
end

-- ===== Script A / B =====
local function runScriptA()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/phongdeptraur/draco/refs/heads/main/source-draco.lua"))()
    setStatus("A", "Running Script A...")
end

local function runScriptB()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/phongdeptraur/draco/refs/heads/main/banana-masfarm.lua"))()
    setStatus("B", "Running Script B...")
end

-- ===== MAIN =====
ensureMarines()

waitChar()
if not isMarines() then
    setStatus("TEAM", "Still not Marines after character load -> set again")
    ensureMarines()
end

runScriptA()

-- Ensure Dragon Talon exists (buy if needed)
local boughtOrAlready = false

if hasDragonTalon() then
    setStatus("CHECK", "Dragon Talon already owned")
    boughtOrAlready = true
else
    setStatus("CHECK", "No Dragon Talon -> TP + Tween + BuyDragonTalon")
    local START = Vector3.new(5659.49, 1014.12, -343.54)
    local GOAL  = Vector3.new(5659.94, 1211.32,  865.08)

    tpTo(START)
    task.wait(0.25)

    tweenToWithLagback(START, GOAL, 350, 70)

    local ok, result = pcall(function()
        return comm:InvokeServer("BuyDragonTalon")
    end)

    if not ok then
        setStatus("ERR", "Invoke error (BuyDragonTalon)")
        return
    end

    setStatus("OK", "BuyDragonTalon result: " .. tostring(result))
    boughtOrAlready = true
end

-- After buy success OR already owned -> check mastery -> maybe run B
if boughtOrAlready then
    task.wait(0.25) -- cho tool/UI ổn định
    local mastery = checkDragonTalonMastery()

    if mastery and mastery <= 500 then
        setStatus("COND", "Mastery <= 500 -> run Script B")
        runScriptB()
    else
        setStatus("COND", "Mastery > 500 or unknown -> skip Script B")
    end
end
