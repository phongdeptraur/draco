-- Blox Fruits: SetTeam MARINES -> Wait char -> Run Script A ALWAYS
-- Then: if no Dragon Talon -> TP + Tween (lagback retry) -> BuyDragonTalon

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

-- ===== Script A (ALWAYS RUN) =====
local function runScriptA()
    -- TODO: DÁN SCRIPT A CỦA BẠN VÀO ĐÂY
    -- Ví dụ: loadstring(game:HttpGet("..."))()
    setStatus("A", "Running Script A...")
end

-- ===== MAIN =====

-- SetTeam sớm
ensureMarines()

-- Đợi nhân vật load rồi set lại nếu chưa ăn
waitChar()
if not isMarines() then
    setStatus("TEAM", "Still not Marines after character load -> set again")
    ensureMarines()
end

-- Chạy Script A luôn sau khi chọn team
runScriptA()

-- Sau Script A: nếu chưa có Dragon Talon thì mới mua
if hasDragonTalon() then
    setStatus("CHECK", "Dragon Talon already owned -> skip buy")
    return
end

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

setStatus("OK", "Dragon Talon result: " .. tostring(result))
