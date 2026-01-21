-- Gay Draco Hub 🐉 (Seats/Dojo/Dragon/Fruit) + Random Fruit Dealer (Cousin Buy) + Pink Glass UI
-- Executor / LocalScript

-- ===== Services =====
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer

-- ===== CONFIG =====
local UI_NAME = "GayDracoHub_UI_V3"
local TWEEN_SPEED = 350 -- studs/sec

local TP_SEAT_GATE = Vector3.new(-12464.33, 374.95, -7553.44)
local TP_DOJO_GATE = Vector3.new(5659.49, 1014.12, -343.54)

-- FRUIT POS
local POS_FRUIT_DROP    = Vector3.new(5849.85, 1208.32, 876.21)
local POS_FRUIT_RECEIVE = Vector3.new(5845.76, 1208.32, 879.39)

local DESTINATIONS = {
	-- Seats
	{ label = "Seat 1", pos = Vector3.new(-12602.31, 337.59, -7544.76), type = "SEAT" },
	{ label = "Seat 2", pos = Vector3.new(-12591.06, 337.59, -7544.76), type = "SEAT" },
	{ label = "Seat 3", pos = Vector3.new(-12591.06, 337.59, -7556.76), type = "SEAT" },
	{ label = "Seat 4", pos = Vector3.new(-12602.31, 337.59, -7556.76), type = "SEAT" },
	{ label = "Seat 5", pos = Vector3.new(-12602.31, 337.59, -7568.76), type = "SEAT" },
	{ label = "Seat 6", pos = Vector3.new(-12591.06, 337.59, -7568.76), type = "SEAT" },

	-- Special
	{ label = "Get quest Dojo",     pos = Vector3.new(5866.27, 1208.32, 870.26), type = "DOJO" },
	{ label = "Buy Dragon Talon",   pos = Vector3.new(5659.94, 1211.32, 865.08), type = "DRAGON" },
}

-- ===== Runtime state =====
local alive = true
local conns = {}
local gui, currentTween
local character, humanoid, hrp

local function addConn(c)
	table.insert(conns, c)
	return c
end

local function disconnectAll()
	for _, c in ipairs(conns) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(conns)
end

local function bindChar(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:WaitForChild("HumanoidRootPart")
end
bindChar(plr.Character or plr.CharacterAdded:Wait())
addConn(plr.CharacterAdded:Connect(bindChar))

-- ===== Logger =====
local statusLabel
local debugBox
local function nowTag()
	local t = os.date("*t")
	return string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)
end

local function setStatus(kind, msg)
	local line = string.format("[%s] %s: %s", nowTag(), kind, msg)
	print("[GayDracoHub] " .. line)
	if statusLabel then statusLabel.Text = line end
	if debugBox then
		debugBox.Text = line .. "\n" .. (debugBox.Text or "")
	end
end

-- ===== Movement =====
local function stopTween()
	if currentTween then
		pcall(function() currentTween:Cancel() end)
		currentTween = nil
	end
end

local function hardTeleport(pos)
	if not hrp then return end
	stopTween()
	hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	task.wait(0.12)
end

local function tweenTo(pos, labelText)
	if not (alive and humanoid and hrp) then return end
	stopTween()

	pos = pos + Vector3.new(0, 2.5, 0)

	local oldWalkSpeed = humanoid.WalkSpeed
	local oldJumpPower = humanoid.JumpPower

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	local dist = (pos - hrp.Position).Magnitude
	local t = math.max(dist / TWEEN_SPEED, 0.05)

	setStatus("MOVE", "Going → " .. labelText)

	currentTween = TweenService:Create(
		hrp,
		TweenInfo.new(t, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(pos) }
	)

	currentTween:Play()
	currentTween.Completed:Wait()

	humanoid.WalkSpeed = oldWalkSpeed or 16
	humanoid.JumpPower = oldJumpPower or 50
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

	setStatus("OK", "Arrived → " .. labelText)
end

local function tpGateThenTween(gatePos, destPos, labelText)
	if not (alive and hrp) then return end

	hardTeleport(gatePos)
	task.wait(0.4)

	local gateOff = (hrp.Position - gatePos).Magnitude
	if gateOff > 10 then
		setStatus("NET", "Lag-back detected, retry gate")
		task.wait(1.2)
		hardTeleport(gatePos)
		task.wait(0.4)
	end

	tweenTo(destPos, labelText)
end

local function moveDojoStyle(destPos, labelText, gatePos)
	if not (alive and hrp) then return end
	gatePos = gatePos or TP_DOJO_GATE

	local dist = (destPos - hrp.Position).Magnitude
	local t = dist / TWEEN_SPEED

	if t < 1 then
		setStatus("MOVE", "Quick TP → " .. labelText)
		hardTeleport(destPos)
		setStatus("OK", "Arrived → " .. labelText)
	else
		setStatus("MOVE", "Gate + Tween → " .. labelText)
		tpGateThenTween(gatePos, destPos, labelText)
	end
end

-- ===== Click / UI automation =====
local function clickScreen()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	local x, y = vp.X/2, vp.Y/2
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
	task.wait()
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local function findClickableForText(targetLower)
	for _, obj in ipairs(plr.PlayerGui:GetDescendants()) do
		if obj:IsA("TextButton") and obj.Visible then
			if string.lower(obj.Text or "") == targetLower then
				return obj
			end
		end
	end
	for _, obj in ipairs(plr.PlayerGui:GetDescendants()) do
		if obj:IsA("TextLabel") and obj.Visible then
			if string.lower(obj.Text or "") == targetLower then
				local p = obj.Parent
				while p and not (p:IsA("TextButton") or p:IsA("ImageButton")) do
					p = p.Parent
				end
				if p and p.Visible then
					return p
				end
			end
		end
	end
	return nil
end

local function fireButton(btn)
	if not (btn and btn.Visible) then return false end
	pcall(function() btn:Activate() end)
	pcall(function()
		if getconnections then
			for _, c in ipairs(getconnections(btn.Activated)) do pcall(function() c:Fire() end) end
			if btn:IsA("TextButton") then
				for _, c in ipairs(getconnections(btn.MouseButton1Click)) do pcall(function() c:Fire() end) end
			end
		end
	end)
	return true
end

local function spamUntilGone(text, maxWaitAppear, maxSpamTime)
	local targetLower = string.lower(text)
	maxWaitAppear = maxWaitAppear or 2.0
	maxSpamTime = maxSpamTime or 4.0

	local t0 = os.clock()
	local btn
	while alive and (os.clock() - t0) < maxWaitAppear do
		btn = findClickableForText(targetLower)
		if btn then break end
		task.wait(0.05)
	end
	if not btn then return false end

	local spamStart = os.clock()
	local lastSeen = os.clock()

	while alive and (os.clock() - spamStart) < maxSpamTime do
		btn = findClickableForText(targetLower)
		if btn then
			lastSeen = os.clock()
			fireButton(btn)
		else
			if (os.clock() - lastSeen) > 0.2 then break end
		end
		task.wait(0.03)
	end
	return true
end

-- ===== MAIN actions =====
local function goTo(dest)
	if not (alive and hrp) then return end

	if dest.type == "SEAT" then
    local dist = (dest.pos - hrp.Position).Magnitude
    local t = dist / TWEEN_SPEED

    if t > 1 then
        setStatus("MOVE", "Seat: Gate → TP (" .. string.format("%.2fs", t) .. ")")

        -- 1️⃣ TP về gate SEAT
        hardTeleport(TP_SEAT_GATE)

        -- 2️⃣ chờ server ổn định
        task.wait(1)

        -- 3️⃣ TP thẳng đến seat
        hardTeleport(dest.pos)

        setStatus("OK", "Arrived → " .. dest.label)
    else
        -- gần thì tween cho mượt
        tweenTo(dest.pos, dest.label)
    end

    return
	end


	if dest.type == "DOJO" then
    moveDojoStyle(dest.pos, dest.label, TP_DOJO_GATE)
    task.wait(0.6)

    local CommF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

    -- Thứ tự đai chuẩn
    local dojoQuests = {
        "Admittance",    -- White
        "Water Warrior", -- Yellow
        "Diplomacy",     -- Orange
        "Precision",     -- Green
        "Endurance",     -- Blue
        "Agility",       -- Purple
        "Strength",     -- Red
        "Mastery"        -- Black
    }

    for _, questName in ipairs(dojoQuests) do
        setStatus("DOJO", "Try quest → " .. questName)

        local ok, status = pcall(function()
            return CommF:InvokeServer("DojoTrainer", questName, 1)
        end)

        if ok and status == 1 then
            setStatus("DOJO", "Doing → " .. questName)

            -- Chờ cho đến khi claim được
            while alive do
                task.wait(5)

                local ok2, claim = pcall(function()
                    return CommF:InvokeServer("DojoTrainer", questName, 2)
                end)

                if ok2 and claim == 3 then
                    setStatus("DOJO", "Completed → " .. questName)
                    break
                end
            end

        elseif status == 3 then
            setStatus("DOJO", "Already owned → " .. questName)
        else
            setStatus("DOJO", "Cannot start → " .. questName)
        end
    end

    setStatus("OK", "All Dojo belts processed")
    return
end


	if dest.type == "DRAGON" then
	-- (có thể bỏ 2 dòng này nếu muốn instant 100%)
	moveDojoStyle(dest.pos, dest.label, TP_DOJO_GATE)
	task.wait(0.25)

	setStatus("DRAGON", "Invoke Dragon Talon via CommF_")

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local comm = remotes and remotes:FindFirstChild("CommF_")
	if not comm then
		setStatus("ERR", "CommF_ not found")
		return
	end

	-- gọi trực tiếp như Random Fruit
	local ok, result = pcall(function()
		return comm:InvokeServer("BuyDragonTalon")
	end)

	if not ok then
		setStatus("ERR", "Invoke error")
		return
	end

	setStatus("OK", "Dragon Talon result: " .. tostring(result))
	return
end

end

-- ===== FRUIT actions =====
local function faceOnce(targetPos)
	if not hrp then return end
	hrp.CFrame = CFrame.new(hrp.Position, targetPos)
end

local function findFruitTool()
	local char = plr.Character
	local backpack = plr:FindFirstChildOfClass("Backpack")

	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and string.find(tool.Name, "Fruit") then
				return tool
			end
		end
	end
	if char then
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") and string.find(tool.Name, "Fruit") then
				return tool
			end
		end
	end
	return nil
end

local function dropFruitFlow()
	local tool = findFruitTool()
	if not tool then
		setStatus("FRUIT", "No 'Fruit' found in inventory")
		return
	end
	if not plr.Character then
		setStatus("FRUIT", "Character not ready")
		return
	end

	tool.Parent = plr.Character
	task.wait(0.22)

	clickScreen()
	task.wait(0.22)

	local ok = spamUntilGone("Drop", 1.3, 3.0)
	if ok then
		setStatus("FRUIT", "Dropped via UI")
	else
		tool.Parent = workspace
		setStatus("FRUIT", "Dropped via fallback")
	end
end

local function doFruitDrop()
	if not alive then return end
	setStatus("FRUIT", "Going to drop spot")
	moveDojoStyle(POS_FRUIT_DROP, "FRUIT DROP", TP_DOJO_GATE)
	task.wait(0.45)
	faceOnce(POS_FRUIT_RECEIVE)
	task.wait(0.35)
	dropFruitFlow()
end

local function doFruitReceive()
	if not alive then return end
	setStatus("FRUIT", "Going to receive spot")
	moveDojoStyle(POS_FRUIT_RECEIVE, "FRUIT RECEIVE", TP_DOJO_GATE)
	task.wait(0.4)
	faceOnce(POS_FRUIT_DROP)
	setStatus("FRUIT", "Ready")
end

local function tpToDojo()
	if not alive then return end
	moveDojoStyle(DESTINATIONS[#DESTINATIONS-1].pos, "DOJO", TP_DOJO_GATE)
end

local function tpToDragon()
	if not alive then return end
	moveDojoStyle(DESTINATIONS[#DESTINATIONS].pos, "DRAGON TALON", TP_DOJO_GATE)
end

-- ===== Random Fruit Dealer (Cousin Buy) =====
local function safeWaitFor(parent, childName, timeout)
	timeout = timeout or 8
	local t0 = os.clock()
	while alive and (os.clock() - t0) < timeout do
		local c = parent:FindFirstChild(childName)
		if c then return c end
		task.wait(0.1)
	end
	return nil
end

local function buyRandomFruitDealer()
	if not alive then return end
	setStatus("RF", "Looking for ReplicatedStorage.Remotes...")
	local remotesFolder = safeWaitFor(ReplicatedStorage, "Remotes", 10)
	if not alive then return end
	if not remotesFolder then
		setStatus("ERR", "Cannot find ReplicatedStorage.Remotes")
		return
	end

	setStatus("RF", "Looking for Remotes.CommF_ ...")
	local comm = safeWaitFor(remotesFolder, "CommF_", 10)
	if not alive then return end
	if not comm then
		setStatus("ERR", "Cannot find CommF_ (game changed?)")
		return
	end

	setStatus("RF", "Invoke: CommF_:InvokeServer('Cousin','Buy') ...")
	local ok, result = pcall(function()
		return comm:InvokeServer("Cousin", "Buy")
	end)
	if not alive then return end
	if not ok then
		setStatus("ERR", "InvokeServer error: " .. tostring(result))
		setStatus("HINT", "Có thể remote bị chặn / executor lỗi invoke / anti-cheat.")
		return
	end

	setStatus("RF", "Returned: " .. tostring(result) .. " (type=" .. typeof(result) .. ")")
	if typeof(result) == "string" then
		setStatus("FRUIT", "✅ Random Fruit: " .. result)
	else
		setStatus("WARN", "Không nhận tên fruit dạng string (cooldown/thiếu Beli/điều kiện).")
	end
end

-- ===== UI Helpers (Pink Glass) =====
local function createCorner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = parent
	return c
end

local function createStroke(parent, thickness, transparency, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.6
	if color then s.Color = color end
	s.Parent = parent
	return s
end

local function mkGradient(parent)
	local g = Instance.new("UIGradient")
	g.Rotation = 35
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 190, 220)), -- light pink
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(205, 170, 255)), -- soft purple
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(175, 220, 255)), -- baby blue
	})
	g.Parent = parent
	return g
end

local function mkAccentGradient(parent)
	local g = Instance.new("UIGradient")
	g.Rotation = 0
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 120, 180)), -- pink
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(180, 130, 255)), -- purple
	})
	g.Parent = parent
	return g
end

local function setBtnActive(btn, active)
	if not btn then return end
	btn.BackgroundTransparency = active and 0.15 or 0.32
	local st = btn:FindFirstChild("UIStroke")
	if st then st.Transparency = active and 0.25 or 0.60 end
end

-- ===== Build UI =====
do
	-- remove old
	local old = plr.PlayerGui:FindFirstChild(UI_NAME)
	if old then old:Destroy() end

	gui = Instance.new("ScreenGui")
	gui.Name = UI_NAME
	gui.ResetOnSpawn = false
	gui.Parent = plr.PlayerGui

	local main = Instance.new("Frame")
	main.Name = "Main"
	main.Size = UDim2.new(0, 380, 0, 545)
	main.Position = UDim2.new(0, 16, 0, 16)
	main.BackgroundColor3 = Color3.fromRGB(255, 210, 230)
	main.BackgroundTransparency = 0.55 -- glass
	main.Parent = gui
	createCorner(main, 18)
	createStroke(main, 1, 0.55, Color3.fromRGB(255, 150, 200))
	mkGradient(main)

	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxassetid://1316045217"
	shadow.ImageTransparency = 0.75
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(10, 10, 118, 118)
	shadow.Size = UDim2.new(1, 54, 1, 54)
	shadow.Position = UDim2.new(0, -27, 0, -27)
	shadow.Parent = main
	shadow.ZIndex = 0

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = main

	-- Topbar (draggable)
	local topbar = Instance.new("Frame")
	topbar.Name = "Topbar"
	topbar.Size = UDim2.new(1, 0, 0, 52)
	topbar.BackgroundTransparency = 0.55
	topbar.BackgroundColor3 = Color3.fromRGB(255, 200, 225)
	topbar.Parent = main
	createCorner(topbar, 16)
	createStroke(topbar, 1, 0.70, Color3.fromRGB(255, 150, 200))

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(1, 0, 0, 3)
	accent.Position = UDim2.new(0, 0, 1, -3)
	accent.BackgroundTransparency = 0.05
	accent.BackgroundColor3 = Color3.fromRGB(255, 130, 190)
	accent.Parent = topbar
	mkAccentGradient(accent)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -130, 1, 0)
	title.Position = UDim2.new(0, 12, 0, 0)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(70, 35, 55)
	title.Text = "Gay Draco Hub 🐉"
	title.Parent = topbar

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.new(1, -130, 1, 0)
	sub.Position = UDim2.new(0, 12, 0, 18)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 11
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = Color3.fromRGB(95, 55, 75)
	sub.Text = "Seat / Dojo / Dragon / Fruit / Random Fruit"
	sub.Parent = topbar

	local btnUnload = Instance.new("TextButton")
	btnUnload.Name = "Unload"
	btnUnload.Size = UDim2.new(0, 110, 0, 32)
	btnUnload.Position = UDim2.new(1, -12, 0.5, 0)
	btnUnload.AnchorPoint = Vector2.new(1, 0.5)
	btnUnload.BackgroundColor3 = Color3.fromRGB(255, 150, 190)
	btnUnload.BackgroundTransparency = 0.25
	btnUnload.Font = Enum.Font.GothamBold
	btnUnload.TextSize = 12
	btnUnload.TextColor3 = Color3.fromRGB(60, 20, 40)
	btnUnload.Text = "UNLOAD"
	btnUnload.Parent = topbar
	createCorner(btnUnload, 14)
	createStroke(btnUnload, 1, 0.45, Color3.fromRGB(255, 120, 180))

	-- Tabs
	local tabbar = Instance.new("Frame")
	tabbar.Name = "Tabbar"
	tabbar.BackgroundTransparency = 1
	tabbar.Size = UDim2.new(1, 0, 0, 42)
	tabbar.Position = UDim2.new(0, 0, 0, 62)
	tabbar.Parent = main

	local function mkTab(text, x)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 118, 0, 32)
		b.Position = UDim2.new(0, x, 0, 6)
		b.BackgroundColor3 = Color3.fromRGB(255, 190, 220)
		b.BackgroundTransparency = 0.35
		b.Font = Enum.Font.GothamSemibold
		b.TextSize = 12
		b.TextColor3 = Color3.fromRGB(65, 25, 45)
		b.Text = text
		b.Parent = tabbar
		createCorner(b, 14)
		createStroke(b, 1, 0.60, Color3.fromRGB(255, 140, 195))
		return b
	end

	local tabMainBtn = mkTab("MAIN", 0)
	local tabFruitBtn = mkTab("FRUIT", 126)

	-- Status
	local statusBar = Instance.new("Frame")
	statusBar.Name = "StatusBar"
	statusBar.Size = UDim2.new(1, 0, 0, 56)
	statusBar.Position = UDim2.new(0, 0, 0, 106)
	statusBar.BackgroundColor3 = Color3.fromRGB(255, 205, 230)
	statusBar.BackgroundTransparency = 0.55
	statusBar.Parent = main
	createCorner(statusBar, 16)
	createStroke(statusBar, 1, 0.70, Color3.fromRGB(255, 150, 200))

	statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.Size = UDim2.new(1, -16, 1, -10)
	statusLabel.Position = UDim2.new(0, 8, 0, 5)
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 12
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusLabel.TextWrapped = true
	statusLabel.TextColor3 = Color3.fromRGB(70, 35, 55)
	statusLabel.Text = "Initializing..."
	statusLabel.Parent = statusBar

	-- Pages container
	local pages = Instance.new("Frame")
	pages.Name = "Pages"
	pages.BackgroundTransparency = 1
	pages.Size = UDim2.new(1, 0, 1, -176)
	pages.Position = UDim2.new(0, 0, 0, 170)
	pages.Parent = main

	local function newScrollPage(parent)
		local page = Instance.new("Frame")
		page.BackgroundTransparency = 1
		page.Size = UDim2.new(1, 0, 1, 0)
		page.Parent = parent

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "Scroll"
		scroll.Size = UDim2.new(1, 0, 1, 0)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 6
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.Parent = page

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = scroll

		local function header(text, order)
			local h = Instance.new("TextLabel")
			h.LayoutOrder = order
			h.BackgroundTransparency = 1
			h.Size = UDim2.new(1, 0, 0, 18)
			h.Font = Enum.Font.GothamBold
			h.TextSize = 12
			h.TextXAlignment = Enum.TextXAlignment.Left
			h.TextColor3 = Color3.fromRGB(90, 40, 65)
			h.Text = text
			h.Parent = scroll
			return h
		end

		local function button(text, order)
			local b = Instance.new("TextButton")
			b.LayoutOrder = order
			b.Size = UDim2.new(1, 0, 0, 38)
			b.BackgroundColor3 = Color3.fromRGB(255, 190, 220)
			b.BackgroundTransparency = 0.42
			b.Font = Enum.Font.GothamSemibold
			b.TextSize = 13
			b.TextColor3 = Color3.fromRGB(55, 18, 38)
			b.Text = text
			b.Parent = scroll
			createCorner(b, 16)
			createStroke(b, 1, 0.60, Color3.fromRGB(255, 140, 195))

			local glow = Instance.new("Frame")
			glow.BackgroundColor3 = Color3.fromRGB(255, 130, 190)
			glow.BackgroundTransparency = 0.82
			glow.Size = UDim2.new(1, 0, 1, 0)
			glow.Parent = b
			createCorner(glow, 16)
			mkAccentGradient(glow)

			addConn(b.MouseEnter:Connect(function()
				TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = 0.35}):Play()
			end))
			addConn(b.MouseLeave:Connect(function()
				TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = 0.42}):Play()
			end))

			return b
		end

		return page, header, button, scroll
	end

	local pageMain, headerMain, btnMain = newScrollPage(pages)
	local pageFruit, headerFruit, btnFruit, fruitScroll = newScrollPage(pages)
	pageMain.Visible = true
	pageFruit.Visible = false

	local function setTab(which)
		if which == "MAIN" then
			pageMain.Visible = true
			pageFruit.Visible = false
			setBtnActive(tabMainBtn, true)
			setBtnActive(tabFruitBtn, false)
			setStatus("UI", "Tab → MAIN")
		else
			pageMain.Visible = false
			pageFruit.Visible = true
			setBtnActive(tabMainBtn, false)
			setBtnActive(tabFruitBtn, true)
			setStatus("UI", "Tab → FRUIT")
		end
	end

	addConn(tabMainBtn.MouseButton1Click:Connect(function() setTab("MAIN") end))
	addConn(tabFruitBtn.MouseButton1Click:Connect(function() setTab("FRUIT") end))
	setTab("MAIN")

	-- MAIN content
	headerMain("SEATS", 1)
	local order = 2
	for _, d in ipairs(DESTINATIONS) do
		if d.type == "SEAT" then
			local b = btnMain(d.label, order); order += 1
			addConn(b.MouseButton1Click:Connect(function()
				task.spawn(function() goTo(d) end)
			end))
		end
	end

	headerMain("SPECIAL", order); order += 1
	for _, d in ipairs(DESTINATIONS) do
		if d.type ~= "SEAT" then
			local b = btnMain(d.label, order); order += 1
			addConn(b.MouseButton1Click:Connect(function()
				task.spawn(function() goTo(d) end)
			end))
		end
	end

	-- FRUIT content
	headerFruit("FRUIT", 1)
	local bDrop = btnFruit("Drop Fruit", 2)
	local bRecv = btnFruit("Recieve Fruit", 3)

	headerFruit("RANDOM FRUIT DEALER", 4)
	local bRand = btnFruit("Buy Random Fruit (Cousin)", 5)

	headerFruit("TP", 6)
	local bTPDojo   = btnFruit("TP Dojo", 7)
	local bTPDragon = btnFruit("TP Dragon Talon", 8)

	headerFruit("DEBUG LOG", 9)
	do
		local box = Instance.new("TextBox")
		box.LayoutOrder = 10
		box.Size = UDim2.new(1, 0, 0, 160)
		box.BackgroundColor3 = Color3.fromRGB(255, 210, 230)
		box.BackgroundTransparency = 0.62
		box.BorderSizePixel = 0
		box.ClearTextOnFocus = false
		box.MultiLine = true
		box.TextEditable = false
		box.TextWrapped = false
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.TextYAlignment = Enum.TextYAlignment.Top
		box.Font = Enum.Font.Code
		box.TextSize = 13
		box.TextColor3 = Color3.fromRGB(65, 25, 45)
		box.Text = ""
		box.Parent = fruitScroll

		createCorner(box, 14)
		createStroke(box, 1, 0.65, Color3.fromRGB(255, 150, 200))

		debugBox = box
	end

	addConn(bDrop.MouseButton1Click:Connect(function() task.spawn(doFruitDrop) end))
	addConn(bRecv.MouseButton1Click:Connect(function() task.spawn(doFruitReceive) end))
	addConn(bTPDojo.MouseButton1Click:Connect(function() task.spawn(tpToDojo) end))
	addConn(bTPDragon.MouseButton1Click:Connect(function() task.spawn(tpToDragon) end))
	addConn(bRand.MouseButton1Click:Connect(function() task.spawn(buyRandomFruitDealer) end))

	-- Draggable main frame
	do
		local dragging = false
		local dragStart, startPos

		addConn(topbar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				dragStart = input.Position
				startPos = main.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end))

		addConn(UserInputService.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = input.Position - dragStart
				main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end))
	end

	-- Unload
	local function Unload()
		alive = false
		stopTween()
		disconnectAll()
		if gui then pcall(function() gui:Destroy() end) end
		print("[GayDracoHub] UNLOADED")
	end
	getgenv().SeatTween_Unload = Unload
	addConn(btnUnload.MouseButton1Click:Connect(Unload))

	-- Friendly init status
	setStatus("READY", "Hub loaded (MAIN/FRUIT) — Pink Glass")
	setStatus("TIP", "FRUIT tab: Buy Random Fruit (Cousin) + Debug log")
end
