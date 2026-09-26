-- The lobby's rules screen (north wall): one display, three tabs.
-- MapBuilder builds the hardware ("RulesScreen" in the Lobby model); this
-- draws the pages on its glass from a SurfaceGui in PlayerGui (adorned to
-- the part), so every player clicks through the tabs on their own. The
-- numbers come from Config, so the copy stays true when the tuning changes.
-- Until someone picks a tab the pages turn by themselves.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local player = Players.LocalPlayer

local rgb = Color3.fromRGB
local BOLD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local REG = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Regular)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json")

local INK = rgb(9, 11, 16)
local CREAM = rgb(232, 228, 218)
local DIM = rgb(128, 136, 152)
local AMBER = rgb(255, 176, 70)
local LINE = rgb(40, 46, 58)

local S = Config.Sentinel
local B = Config.Block.Guard

-- The pages. Steps are the goal in order; Keys are the controls.
local PAGES = {
	{
		Tab = "HOW TO PLAY",
		Accent = AMBER,
		Heading = "SURVIVE THE BERSERKER",
		Steps = {
			{ "RUN AND HIDE", "Subject X is loose and hunting you. Break his line of sight, and hide in anything that glows white." },
			{ "REPAIR THE TERMINALS", "Reboot the 3 Sentinel terminals around the facility." },
			{ "SUIT UP", ("Then %d of you can climb into the Sentinel suits in the Hangar."):format(S.Suits) },
			{ "TAKE HIM DOWN", "Beat him in the suits, or stay alive until the clock runs out." },
		},
		Note = ("%d hits and you are torn in half."):format(Config.HitsToKill),
		Keys = {
			{ "SHIFT", "Sprint", "Outrun him round a corner" },
			{ "E", "Use", "Repair, hide, and hold to suit up" },
			{ "G", "Your power", "Fart, Turbo Fart, Dodge or Invisibility" },
			{ "SPACE", "Jump", "Also climbs out of a hiding spot" },
			{ "M", "Map", "Only you are on it" },
		},
	},
	{
		Tab = "THE BERSERKER",
		Accent = rgb(232, 70, 58),
		Heading = "IF YOU ARE HIM",
		Steps = {
			{ "HUNT THEM", ("Catch the scientists before the clock runs out. Every kill adds %d seconds."):format(Config.KillTimeBonus) },
			{ "RAGE", ("Below %d%% health you snap: faster slashes, harder hits."):format(Config.Rage.Threshold * 100) },
			{ "RIDE THE SUITS", "Pounce a Sentinel to land on its back, then stab its power pack." },
		},
		Keys = {
			{ "M1", "Claw Slash", "Through people and through walls" },
			{ "C", "All fours", "The fastest way to move (Ctrl too)" },
			{ "Q", "Pounce", "From all fours. Lands you on a suit's back" },
			{ "E", "Impale", "Both claws in. Lift them up" },
			{ "R", "Sniff", ("Smell every scent for %ds"):format(Config.Abilities.Sniff.Duration) },
			{ "F", "Block", ("Hold. Takes %d punches"):format(B.Wolverine) },
			{ "SPACE", "Leap off", "Jump off a suit's back" },
			{ "F F F", "Resist", "Mash to walk through a death ray" },
		},
	},
	{
		Tab = "SENTINELS",
		Accent = rgb(110, 176, 255),
		Heading = "SUIT UP",
		Steps = {
			{ "HUNT HIM", ("Each suit runs for %d seconds. Bring him down before it powers off."):format(S.Duration) },
			{ "STAY LINKED", ("Within %d studs of the other suit you hit %gx; apart, only %gx."):format(S.LinkRange, S.LinkedMultiplier, S.SoloMultiplier) },
			{ "SHAKE HIM OFF", "If he rides your back, buck him off, or back him into a wall to crush him." },
		},
		Keys = {
			{ "M1", "Hydraulic Smash", "Stuns and launches him" },
			{ "M2", "Ground Slam", ("Hits him within %d studs"):format(S.Slam.Radius) },
			{ "Q", "Death Ray", "Melts through walls. Aim with the mouse" },
			{ "E", "Inhibitor Blast", ("Stuns him %gs. Press E again to cancel"):format(S.Pulse.Stun) },
			{ "R", "Grab & Throw", "Catch him by the throat and hurl him" },
			{ "F", "Block", ("Hold. Takes %d slashes"):format(B.Sentinel) },
			{ "SPACE", "Buck", "Throw him off your back" },
		},
	},
}

local clickSound = Instance.new("Sound")
clickSound.SoundId = Config.Sounds.UIClick
clickSound.Volume = 0.3
clickSound.Parent = SoundService

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function label(parent, props)
	local t = new("TextLabel", { BackgroundTransparency = 1, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true }, parent)
	for k, v in props do
		t[k] = v
	end
	return t
end

local function keycap(parent, text, accent, pos)
	local cap = new("Frame", { Position = pos, Size = UDim2.fromOffset(104, 34), BackgroundColor3 = rgb(26, 30, 40), BorderSizePixel = 0 }, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, cap)
	new("UIStroke", { Color = accent, Thickness = 2, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, cap)
	label(cap, { Size = UDim2.fromScale(1, 1), Text = text, FontFace = BOLD, TextSize = 22, TextColor3 = CREAM, TextXAlignment = Enum.TextXAlignment.Center })
	return cap
end

-- one page: the heading and goal steps on the left, the controls on the right
local function buildPage(parent, page)
	local f = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, parent)
	label(f, { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(620, 50), Text = page.Heading, FontFace = BOLD, TextSize = 44, TextColor3 = CREAM })
	new("Frame", { Position = UDim2.fromOffset(0, 54), Size = UDim2.fromOffset(120, 4), BackgroundColor3 = page.Accent, BorderSizePixel = 0 }, f)
	local y = 70
	for i, step in page.Steps do
		label(f, { Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(40, 28), Text = ("%02d"):format(i), FontFace = MONO, TextSize = 19, TextColor3 = page.Accent })
		label(f, { Position = UDim2.fromOffset(44, y), Size = UDim2.fromOffset(580, 28), Text = step[1], FontFace = BOLD, TextSize = 25, TextColor3 = CREAM })
		label(f, { Position = UDim2.fromOffset(44, y + 26), Size = UDim2.fromOffset(580, 40), Text = step[2], FontFace = REG, TextSize = 18, TextColor3 = DIM, TextYAlignment = Enum.TextYAlignment.Top })
		y += 68
	end
	if page.Note then
		label(f, { Position = UDim2.fromOffset(44, y - 2), Size = UDim2.fromOffset(580, 26), Text = page.Note, FontFace = BOLD, TextSize = 21, TextColor3 = page.Accent })
	end
	-- the controls
	local cx = 690
	new("Frame", { Position = UDim2.fromOffset(cx - 36, 4), Size = UDim2.new(0, 2, 1, -8), BackgroundColor3 = LINE, BorderSizePixel = 0 }, f)
	label(f, { Position = UDim2.fromOffset(cx, 0), Size = UDim2.fromOffset(400, 30), Text = "CONTROLS", FontFace = MONO, TextSize = 20, TextColor3 = DIM })
	local rowH = #page.Keys > 7 and 40 or 46
	for i, k in page.Keys do
		local ry = 38 + (i - 1) * rowH
		keycap(f, k[1], page.Accent, UDim2.fromOffset(cx, ry))
		label(f, { Position = UDim2.fromOffset(cx + 122, ry), Size = UDim2.fromOffset(220, 34), Text = k[2], FontFace = BOLD, TextSize = 24, TextColor3 = CREAM })
		label(f, { Position = UDim2.fromOffset(cx + 346, ry), Size = UDim2.fromOffset(470, 34), Text = k[3], FontFace = REG, TextSize = 20, TextColor3 = DIM })
	end
	return f
end

local function build(glass)
	local old = player.PlayerGui:FindFirstChild("RulesScreen")
	if old then
		old:Destroy()
	end
	local gui = new("SurfaceGui", {
		Name = "RulesScreen", Adornee = glass, Face = Enum.NormalId.Front, ResetOnSpawn = false,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 32, LightInfluence = 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ClipsDescendants = true,
	}, player.PlayerGui)
	local bg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, gui)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(16, 20, 28), INK) }, bg)
	-- faint scanlines for a bit of screen texture
	for y = 0, 1, 1 / 90 do
		new("Frame", { Position = UDim2.fromScale(0, y), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.965, BorderSizePixel = 0 }, bg)
	end
	local pad = new("Frame", { Position = UDim2.fromOffset(40, 26), Size = UDim2.new(1, -80, 1, -52), BackgroundTransparency = 1 }, bg)

	-- header: the name on the left, the tabs on the right
	label(pad, { Size = UDim2.fromOffset(560, 56), Text = "SURVIVE THE WOLVERINE", FontFace = BOLD, TextSize = 40, TextColor3 = AMBER })
	new("Frame", { Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = LINE, BorderSizePixel = 0 }, pad)
	-- footer: the facility line, the incident counter nobody gets to reset, a hint
	local foot = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 }, pad)
	new("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = LINE, BorderSizePixel = 0 }, foot)
	label(foot, { Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(600, 24), Text = "WEAPON X  ·  FACILITY 7  ·  CONTAINMENT PROTOCOL", FontFace = MONO, TextSize = 16, TextColor3 = DIM })
	local counter = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 40, 0, 5), Size = UDim2.fromOffset(300, 26), BackgroundTransparency = 1 }, foot)
	label(counter, { Size = UDim2.new(1, -40, 1, 0), Text = "DAYS WITHOUT AN INCIDENT", FontFace = REG, TextSize = 18, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right })
	local digit = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(30, 26), BackgroundColor3 = rgb(40, 12, 12), BorderSizePixel = 0 }, counter)
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, digit)
	label(digit, { Size = UDim2.fromScale(1, 1), Text = "0", FontFace = BOLD, TextSize = 22, TextColor3 = rgb(255, 60, 44), TextXAlignment = Enum.TextXAlignment.Center })
	label(foot, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6), Size = UDim2.fromOffset(400, 24), Text = "CLICK A TAB TO READ ON", FontFace = MONO, TextSize = 16, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right })

	-- the tabs
	local tabs, pages = {}, {}
	local body = new("Frame", { Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 1, -114), BackgroundTransparency = 1 }, pad)
	local current = 0
	local function show(i)
		if i == current then
			return
		end
		current = i
		for k, t in tabs do
			local on = k == i
			local accent = PAGES[k].Accent
			TweenService:Create(t.Bar, TweenInfo.new(0.2), { Size = on and UDim2.new(1, 0, 0, 4) or UDim2.new(0, 0, 0, 4) }):Play()
			t.Button.BackgroundTransparency = on and 0.86 or 1
			t.Button.BackgroundColor3 = accent
			t.Name.TextColor3 = on and CREAM or DIM
			t.Num.TextColor3 = on and accent or DIM
			pages[k].Visible = on
		end
		local p = pages[i]
		p.Position = UDim2.fromOffset(24, 0)
		TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(0, 0) }):Play()
	end
	local lastClick = -math.huge
	for i, page in PAGES do
		local b = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -(#PAGES - i) * 262, 0, 2), Size = UDim2.fromOffset(254, 56),
			BackgroundColor3 = page.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
		}, pad)
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
		local num = label(b, { Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(36, 52), Text = ("%02d"):format(i), FontFace = MONO, TextSize = 18, TextColor3 = DIM })
		local name = label(b, { Position = UDim2.fromOffset(50, 0), Size = UDim2.new(1, -54, 0, 52), Text = page.Tab, FontFace = BOLD, TextSize = 26, TextColor3 = DIM })
		local bar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0, 0, 0, 4), BackgroundColor3 = page.Accent, BorderSizePixel = 0 }, b)
		b.MouseEnter:Connect(function()
			if current ~= i then
				name.TextColor3 = CREAM
			end
		end)
		b.MouseLeave:Connect(function()
			if current ~= i then
				name.TextColor3 = DIM
			end
		end)
		b.Activated:Connect(function()
			lastClick = os.clock()
			clickSound:Play()
			show(i)
		end)
		tabs[i] = { Button = b, Name = name, Num = num, Bar = bar }
		pages[i] = buildPage(body, page)
	end
	show(1)

	-- the pages turn by themselves until someone picks a tab
	task.spawn(function()
		while gui.Parent do
			task.wait(14)
			if os.clock() - lastClick > 45 then
				show(current % #PAGES + 1)
			end
		end
	end)
	return gui
end

task.spawn(function()
	while true do
		local lobby = workspace:WaitForChild("Lobby")
		local glass = lobby:WaitForChild("RulesScreen")
		local gui = build(glass)
		-- rebuilt if the lobby (or the screen) is ever replaced
		while glass.Parent and glass:IsDescendantOf(workspace) do
			glass.AncestryChanged:Wait()
		end
		gui:Destroy()
		task.wait(1)
	end
end)

return {}
