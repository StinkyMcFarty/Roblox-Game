-- A small north-up map of the facility (top left) with a dot for you that
-- moves and turns as you do, room names, and the Sentinel docks (two Sentinel
-- heads). It shows ONLY you: no other players, no Wolverine. M turns it on
-- and off; tapping/clicking it toggles a bigger view.
-- The layout comes from the server (Facility publishMinimap).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

local WIDTH = 210 -- px, small view
-- short names that fit the small map (the four ring sections share one)
local SHORT = {
	Atrium = "SUBJECT X", RingN = "RING", RingS = "", RingW = "", RingE = "",
	Foundry = "FOUNDRY", Hangar = "HANGAR", Genetics = "GENETICS", Cryo = "CRYO",
	Command = "COMMAND", Servers = "SERVERS", Reactor = "REACTOR", Archive = "ARCHIVE",
	Canteen = "CANTEEN", Quarters = "QUARTERS", Reception = "MEDICAL", Surgery = "SURGERY",
}
local BIG = 2.3 -- scale of the big view
local rgb = Color3.fromRGB

local gui = Instance.new("ScreenGui")
gui.Name = "Minimap"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame, dot, arrow, bounds, scale, labels
local big = false
local shown = true -- M toggles
local uiScale

local function build(data)
	if frame then
		frame:Destroy()
	end
	bounds = data.Bounds
	local w, h = bounds[3] - bounds[1], bounds[4] - bounds[2]
	scale = WIDTH / w
	local H = math.floor(h * scale + 0.5)
	local function px(x, z)
		return UDim2.fromOffset((x - bounds[1]) * scale, (z - bounds[2]) * scale)
	end

	frame = Instance.new("TextButton")
	frame.Name = "Map"
	frame.Text = ""
	frame.AutoButtonColor = false
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.fromOffset(16, 64)
	frame.Size = UDim2.fromOffset(WIDTH + 8, H + 8)
	frame.BackgroundColor3 = rgb(10, 12, 16)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
	local st = Instance.new("UIStroke", frame)
	st.Color = rgb(120, 130, 145)
	st.Transparency = 0.5
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiScale = Instance.new("UIScale", frame)
	uiScale.Scale = big and BIG or 1

	local canvas = Instance.new("Frame")
	canvas.Position = UDim2.fromOffset(4, 4)
	canvas.Size = UDim2.fromOffset(WIDTH, H)
	canvas.BackgroundTransparency = 1
	canvas.Parent = frame

	labels = {}
	for _, r in data.Rooms do
		local room = Instance.new("Frame")
		room.Position = px(r[2], r[3])
		room.Size = UDim2.fromOffset((r[4] - r[2]) * scale, (r[5] - r[3]) * scale)
		room.BackgroundColor3 = rgb(34, 39, 47)
		room.BackgroundTransparency = 0.15
		room.BorderSizePixel = 0
		room.Parent = canvas
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5, 0.5)
		t.Size = UDim2.new(1, -2, 1, -2)
		t.Text = (r[6] and SHORT[r[6]]) or r[1]
		t.TextWrapped = true
		t.TextScaled = true
		t.Font = Enum.Font.GothamBold
		t.TextColor3 = rgb(170, 180, 195)
		t.TextStrokeTransparency = 0.6
		t.ZIndex = 3
		t.Parent = room
		local limit = Instance.new("UITextSizeConstraint", t)
		limit.MaxTextSize = 8
		table.insert(labels, t)
	end
	for _, wl in data.Walls do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = px(wl[1], wl[2])
		line.Size = UDim2.fromOffset(math.max(1, wl[3] * scale), 1.5)
		line.Rotation = wl[4]
		line.BackgroundColor3 = rgb(185, 195, 208)
		line.BorderSizePixel = 0
		line.Parent = canvas
	end

	-- the Sentinel docks: two little Sentinel heads (purple helmet, grey
	-- faceplate, red eye slit) over a "SENTINELS" tag
	if data.Pod then
		local pod = Instance.new("Frame")
		pod.AnchorPoint = Vector2.new(0.5, 0.5)
		pod.Position = px(data.Pod[1], data.Pod[2])
		pod.Size = UDim2.fromOffset(34, 24)
		pod.BackgroundTransparency = 1
		pod.ZIndex = 4
		pod.Parent = canvas
		for k = 0, 1 do
			local head = Instance.new("Frame")
			head.Position = UDim2.fromOffset(5 + k * 13, 0)
			head.Size = UDim2.fromOffset(11, 12)
			head.BackgroundColor3 = rgb(125, 60, 175)
			head.BorderSizePixel = 0
			head.ZIndex = 4
			head.Parent = pod
			Instance.new("UICorner", head).CornerRadius = UDim.new(0, 4)
			local hs = Instance.new("UIStroke", head)
			hs.Color = rgb(20, 12, 30)
			local face = Instance.new("Frame")
			face.Position = UDim2.fromOffset(2, 4)
			face.Size = UDim2.fromOffset(7, 7)
			face.BackgroundColor3 = rgb(150, 156, 170)
			face.BorderSizePixel = 0
			face.ZIndex = 5
			face.Parent = head
			Instance.new("UICorner", face).CornerRadius = UDim.new(0, 2)
			local eyes = Instance.new("Frame")
			eyes.Position = UDim2.fromOffset(1, 2)
			eyes.Size = UDim2.fromOffset(5, 1.5)
			eyes.BackgroundColor3 = rgb(255, 50, 40)
			eyes.BorderSizePixel = 0
			eyes.ZIndex = 6
			eyes.Parent = face
		end
		local tag = Instance.new("TextLabel")
		tag.Position = UDim2.fromOffset(-8, 13)
		tag.Size = UDim2.fromOffset(50, 10)
		tag.BackgroundTransparency = 1
		tag.Text = "SENTINELS"
		tag.Font = Enum.Font.GothamBlack
		tag.TextSize = 7
		tag.TextColor3 = rgb(205, 150, 255)
		tag.TextStrokeTransparency = 0.3
		tag.ZIndex = 5
		tag.Parent = pod
	end

	dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(7, 7)
	dot.BackgroundColor3 = rgb(80, 255, 140)
	dot.BorderSizePixel = 0
	dot.ZIndex = 5
	dot.Parent = canvas
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	local ds = Instance.new("UIStroke", dot)
	ds.Color = Color3.new(0, 0, 0)
	ds.Thickness = 1
	arrow = Instance.new("TextLabel")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(18, 18)
	arrow.BackgroundTransparency = 1
	arrow.Text = "▲"
	arrow.TextSize = 9
	arrow.Font = Enum.Font.GothamBold
	arrow.TextColor3 = rgb(80, 255, 140)
	arrow.ZIndex = 4
	arrow.Parent = canvas

	frame.Activated:Connect(function()
		big = not big
		uiScale.Scale = big and BIG or 1
	end)
end

local function load()
	local raw = ReplicatedStorage:GetAttribute("Minimap")
	if type(raw) == "string" then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and data and data.Bounds then
			build(data)
		end
	end
end
ReplicatedStorage:GetAttributeChangedSignal("Minimap"):Connect(load)
load()

UserInputService.InputBegan:Connect(function(input, gp)
	if not gp and input.KeyCode == Enum.KeyCode.M then
		shown = not shown
	end
end)

RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local p = root and root.Position
	-- only in the facility (not the lobby) and only during a round
	local inside = shown and frame ~= nil and p ~= nil and workspace:FindFirstChild("Map") ~= nil
		and p.X > bounds[1] and p.X < bounds[3] and p.Z > bounds[2] and p.Z < bounds[4] and p.Y < 60
		and player:GetAttribute("Role") ~= "Lobby"
	gui.Enabled = inside
	if not inside then
		return
	end
	local x, z = (p.X - bounds[1]) * scale, (p.Z - bounds[2]) * scale
	dot.Position = UDim2.fromOffset(x, z)
	local look = root.CFrame.LookVector
	local ang = math.atan2(look.X, -look.Z)
	arrow.Position = UDim2.fromOffset(x + math.sin(ang) * 7, z - math.cos(ang) * 7)
	arrow.Rotation = math.deg(ang)
end)

return {}
