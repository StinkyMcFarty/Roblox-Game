-- HUD built entirely from code.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local Interface = {}

local YELLOW = Color3.fromRGB(255, 205, 30)
local RED = Color3.fromRGB(230, 40, 40)
local DARK = Color3.fromRGB(14, 14, 18)
local TITLE = Enum.Font.GothamBlack
local BODY = Enum.Font.GothamBold

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(p, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p)
end

local function stroke(p, color, thickness)
	new("UIStroke", { Color = color or Color3.new(0, 0, 0), Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end

local gui = new("ScreenGui", {
	Name = "WolverineHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

---------------------------------------------------------------------------
-- Screen effects
---------------------------------------------------------------------------

local vignette = new("CanvasGroup", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	GroupTransparency = 1,
	ZIndex = 1,
}, gui)
for _, e in {
	{ UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0), 90 },
	{ UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.65), 270 },
	{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0, 0), 0 },
	{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0), 180 },
} do
	local f = new("Frame", { Size = e[1], Position = e[2], BackgroundColor3 = Color3.fromRGB(120, 0, 0), BorderSizePixel = 0 }, vignette)
	new("UIGradient", {
		Rotation = e[3],
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
	}, f)
end

local flash = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = RED,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 50,
}, gui)

---------------------------------------------------------------------------
-- Top: status + timer + Wolverine health
---------------------------------------------------------------------------

local top = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 44),
	Size = UDim2.fromOffset(320, 64),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.25,
}, gui)
corner(top, 10)
stroke(top, Color3.fromRGB(80, 20, 20), 2)
local statusLabel = new("TextLabel", {
	Size = UDim2.new(1, -16, 0, 22),
	Position = UDim2.fromOffset(8, 4),
	BackgroundTransparency = 1,
	Font = BODY,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(220, 220, 225),
	Text = "",
}, top)
local timerLabel = new("TextLabel", {
	Size = UDim2.new(1, -16, 0, 34),
	Position = UDim2.fromOffset(8, 26),
	BackgroundTransparency = 1,
	Font = TITLE,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "",
}, top)

local wHealth = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 114),
	Size = UDim2.fromOffset(300, 18),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.2,
	Visible = false,
}, gui)
corner(wHealth, 6)
local wHealthFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = YELLOW, BorderSizePixel = 0 }, wHealth)
corner(wHealthFill, 6)
new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = TITLE,
	TextScaled = true,
	Text = "WOLVERINE",
	TextColor3 = Color3.new(0, 0, 0),
	ZIndex = 2,
}, wHealth)

local terminalsLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 136),
	Size = UDim2.fromOffset(300, 20),
	BackgroundTransparency = 1,
	Font = BODY,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(200, 160, 255),
	TextStrokeTransparency = 0.5,
	Text = "",
}, gui)

---------------------------------------------------------------------------
-- Centre: announcements & role banner
---------------------------------------------------------------------------

local announceLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.new(0.9, 0, 0, 56),
	BackgroundTransparency = 1,
	Font = TITLE,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0,
	TextTransparency = 1,
	ZIndex = 20,
}, gui)
new("UITextSizeConstraint", { MaxTextSize = 44 }, announceLabel)

local roleLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.new(0.9, 0, 0, 90),
	BackgroundTransparency = 1,
	Font = Enum.Font.LuckiestGuy,
	TextScaled = true,
	TextColor3 = YELLOW,
	TextStrokeTransparency = 0,
	TextTransparency = 1,
	ZIndex = 21,
}, gui)
local roleSub = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.new(0.8, 0, 0, 30),
	BackgroundTransparency = 1,
	Font = BODY,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.3,
	TextTransparency = 1,
	ZIndex = 21,
}, gui)

---------------------------------------------------------------------------
-- Kill feed
---------------------------------------------------------------------------

local feed = new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 60),
	Size = UDim2.fromOffset(330, 200),
	BackgroundTransparency = 1,
}, gui)
new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Right }, feed)

---------------------------------------------------------------------------
-- Bottom: abilities, stamina, wounds
---------------------------------------------------------------------------

local hotbar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.fromOffset(460, 76),
	BackgroundTransparency = 1,
}, gui)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 8),
}, hotbar)

local staminaBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -100),
	Size = UDim2.fromOffset(260, 8),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.3,
}, gui)
corner(staminaBar, 4)
local staminaFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 200, 255), BorderSizePixel = 0 }, staminaBar)
corner(staminaFill, 4)

local wounds = new("TextLabel", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -120),
	Size = UDim2.fromOffset(240, 30),
	BackgroundTransparency = 1,
	Font = TITLE,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.3,
	Text = "",
}, gui)

local hint = new("TextLabel", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -16),
	Size = UDim2.fromOffset(300, 90),
	BackgroundTransparency = 1,
	Font = BODY,
	TextSize = 14,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Bottom,
	TextColor3 = Color3.fromRGB(200, 200, 210),
	TextStrokeTransparency = 0.5,
	Text = "",
}, gui)

local slots = {}

function Interface.SetAbilities(list)
	for _, s in slots do
		s.Frame:Destroy()
	end
	slots = {}
	for _, a in list do
		local f = new("Frame", {
			Size = UDim2.fromOffset(88, 72),
			BackgroundColor3 = DARK,
			BackgroundTransparency = 0.2,
		}, hotbar)
		corner(f, 10)
		stroke(f, a.Color or Color3.fromRGB(120, 30, 30), 2)
		new("TextLabel", {
			Size = UDim2.new(1, -8, 0, 22),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
			Font = TITLE,
			TextScaled = true,
			TextColor3 = a.Color or YELLOW,
			Text = a.KeyText,
		}, f)
		new("TextLabel", {
			Size = UDim2.new(1, -8, 0, 36),
			Position = UDim2.fromOffset(4, 30),
			BackgroundTransparency = 1,
			Font = BODY,
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = a.Label,
		}, f)
		local cd = new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			ZIndex = 5,
		}, f)
		corner(cd, 10)
		slots[a.Name] = { Frame = f, Cooldown = cd, ReadyAt = 0, Duration = 1 }
	end
end

function Interface.StartCooldown(name, duration)
	local s = slots[name]
	if s then
		s.ReadyAt = os.clock() + duration
		s.Duration = duration
	end
end

function Interface.SetHint(text)
	hint.Text = text
end

function Interface.Announce(text, color, duration)
	announceLabel.Text = text
	announceLabel.TextColor3 = color or Color3.new(1, 1, 1)
	announceLabel.TextTransparency = 0
	announceLabel.TextStrokeTransparency = 0
	announceLabel.Size = UDim2.new(0.9, 0, 0, 70)
	TweenService:Create(announceLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(0.9, 0, 0, 56) }):Play()
	local token = {}
	Interface._announceToken = token
	task.delay(duration or 3, function()
		if Interface._announceToken == token then
			TweenService:Create(announceLabel, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

function Interface.RoleBanner(title, subtitle, color)
	roleLabel.Text = title
	roleLabel.TextColor3 = color or YELLOW
	roleSub.Text = subtitle or ""
	for _, l in { roleLabel, roleSub } do
		l.TextTransparency = 0
		l.TextStrokeTransparency = l == roleLabel and 0 or 0.3
	end
	task.delay(3.5, function()
		for _, l in { roleLabel, roleSub } do
			TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

function Interface.Flash(color, strength, duration)
	flash.BackgroundColor3 = color or RED
	flash.BackgroundTransparency = 1 - (strength or 0.4)
	TweenService:Create(flash, TweenInfo.new(duration or 0.5), { BackgroundTransparency = 1 }):Play()
end

local danger = 0
function Interface.SetDanger(level)
	danger = level
end

function Interface.KillFeed(text)
	local l = new("TextLabel", {
		Size = UDim2.fromOffset(330, 26),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.3,
		Font = BODY,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 120, 120),
		Text = text,
	}, feed)
	corner(l, 6)
	task.delay(6, function()
		TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.wait(0.5)
		l:Destroy()
	end)
end

function Interface.TimeBonus(seconds)
	local l = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 180, 0, 60),
		Size = UDim2.fromOffset(120, 34),
		BackgroundTransparency = 1,
		Font = TITLE,
		TextScaled = true,
		TextColor3 = RED,
		TextStrokeTransparency = 0,
		Text = "+" .. seconds .. "s",
	}, gui)
	TweenService:Create(l, TweenInfo.new(1.6), { Position = UDim2.new(0.5, 180, 0, 30), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.7, function()
		l:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Per-frame refresh
---------------------------------------------------------------------------

local pulseClock = 0
RunService.RenderStepped:Connect(function(dt)
	local role = player:GetAttribute("Role")
	local status = ReplicatedStorage:GetAttribute("Status") or ""
	local ends = ReplicatedStorage:GetAttribute("TimerEnds") or 0
	statusLabel.Text = status
	local left = math.max(0, ends - workspace:GetServerTimeNow())
	if ends > 0 then
		timerLabel.Text = ("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
		timerLabel.TextColor3 = (left < 20 and ReplicatedStorage:GetAttribute("InRound")) and RED or Color3.new(1, 1, 1)
	else
		timerLabel.Text = ""
	end

	-- Wolverine health bar
	local wName = ReplicatedStorage:GetAttribute("Wolverine")
	local wPlayer = wName and Players:FindFirstChild(wName)
	local wHum = wPlayer and wPlayer.Character and wPlayer.Character:FindFirstChildOfClass("Humanoid")
	if wHum and ReplicatedStorage:GetAttribute("InRound") then
		wHealth.Visible = true
		wHealthFill.Size = UDim2.fromScale(math.clamp(wHum.Health / math.max(1, wHum.MaxHealth), 0, 1), 1)
	else
		wHealth.Visible = false
	end

	-- Terminals
	local total = ReplicatedStorage:GetAttribute("TerminalsTotal") or 0
	if ReplicatedStorage:GetAttribute("InRound") and total > 0 then
		if ReplicatedStorage:GetAttribute("SuitOnline") then
			terminalsLabel.Text = "SENTINEL SUIT ONLINE — container yard"
		else
			terminalsLabel.Text = ("Sentinel terminals: %d/%d"):format(ReplicatedStorage:GetAttribute("Terminals") or 0, total)
		end
	else
		terminalsLabel.Text = ""
	end

	-- Stamina
	local stamina = player:GetAttribute("Stamina") or 1
	staminaFill.Size = UDim2.fromScale(math.clamp(stamina, 0, 1), 1)
	staminaBar.Visible = role ~= "Sentinel"
	staminaFill.BackgroundColor3 = role == "Wolverine" and Color3.fromRGB(255, 150, 40) or Color3.fromRGB(120, 200, 255)

	-- Wounds / armor
	if role == "Survivor" then
		local hits = player:GetAttribute("Hits") or 0
		local marks = ""
		for i = 1, Config.HitsToKill do
			marks ..= i <= hits and "/// " or "— "
		end
		wounds.Text = "WOUNDS  " .. marks
		wounds.TextColor3 = hits >= Config.HitsToKill - 1 and RED or Color3.new(1, 1, 1)
	elseif role == "Sentinel" then
		local armor = player:GetAttribute("Armor") or 0
		local suitEnds = player:GetAttribute("SuitEnds") or 0
		wounds.Text = ("ARMOR %d  |  POWER %ds"):format(armor, math.max(0, math.floor(suitEnds - workspace:GetServerTimeNow())))
		wounds.TextColor3 = Color3.fromRGB(200, 160, 255)
	else
		wounds.Text = ""
	end

	-- Cooldowns
	local t = os.clock()
	for _, s in slots do
		local frac = math.clamp((s.ReadyAt - t) / s.Duration, 0, 1)
		s.Cooldown.Size = UDim2.fromScale(1, frac)
	end

	-- Danger vignette pulses like a heartbeat
	if danger > 0.05 then
		pulseClock += dt * (1 + danger * 2.5)
		local beat = math.max(0, math.sin(pulseClock * math.pi * 2)) ^ 6
		vignette.GroupTransparency = 1 - math.clamp(danger * 0.7 + beat * danger * 0.3, 0, 1)
	else
		vignette.GroupTransparency = 1
	end
end)

return Interface
