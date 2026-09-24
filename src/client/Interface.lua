-- HUD built entirely from code.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local Interface = {}

local new, corner, stroke, gradient = UIKit.new, UIKit.Corner, UIKit.Stroke, UIKit.Gradient
local K = UIKit.Colors
local TITLE = Enum.Font.GothamBlack
local BODY = Enum.Font.GothamBold

local function darker(c, f)
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local gui = new("ScreenGui", {
	Name = "WolverineHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

local smallScreen = false
local function checkScreen()
	local v = workspace.CurrentCamera.ViewportSize
	smallScreen = v.X < 900 or v.Y < 520
end
checkScreen()

---------------------------------------------------------------------------
-- Screen effects
---------------------------------------------------------------------------

local vignette = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1 }, gui)
for _, e in {
	{ UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0), 90 },
	{ UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.65), 270 },
	{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0, 0), 0 },
	{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0), 180 },
} do
	local f = new("Frame", { Size = e[1], Position = e[2], BackgroundColor3 = Color3.fromRGB(120, 0, 0), BorderSizePixel = 0 }, vignette)
	new("UIGradient", { Rotation = e[3], Transparency = NumberSequence.new(0, 1) }, f)
end

local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = K.Red, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50 }, gui)

---------------------------------------------------------------------------
-- Top: timer plate + Wolverine health + terminals
---------------------------------------------------------------------------

local top = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 44),
	Size = UDim2.fromOffset(300, 70),
	BackgroundColor3 = Color3.new(1, 1, 1),
}, gui)
corner(top, 14)
gradient(top, Color3.fromRGB(38, 30, 34), Color3.fromRGB(12, 10, 14))
local topStroke = stroke(top, Color3.fromRGB(120, 30, 30), 2)
for i = 0, 2 do -- claw scratch detail
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 20 + i * 9, 0.5, 0),
		Size = UDim2.fromOffset(3, 46),
		Rotation = 22,
		BackgroundColor3 = Color3.fromRGB(150, 25, 25),
		BackgroundTransparency = 0.2,
	}, top)
end
local statusLabel = new("TextLabel", {
	Size = UDim2.new(1, -70, 0, 20),
	Position = UDim2.fromOffset(52, 6),
	BackgroundTransparency = 1,
	Font = BODY,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(200, 190, 195),
	Text = "",
}, top)
local timerLabel = new("TextLabel", {
	Size = UDim2.new(1, -70, 0, 40),
	Position = UDim2.fromOffset(52, 26),
	BackgroundTransparency = 1,
	Font = TITLE,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = K.White,
	Text = "",
}, top)
new("UIStroke", { Thickness = 2, Transparency = 0.2 }, timerLabel)

local wHealth = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 122),
	Size = UDim2.fromOffset(300, 20),
	BackgroundColor3 = K.Ink,
	Visible = false,
}, gui)
corner(wHealth, 10)
stroke(wHealth, Color3.fromRGB(80, 60, 10), 2)
local wHealthLag = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.3, BorderSizePixel = 0 }, wHealth)
corner(wHealthLag, 10)
local wHealthFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, wHealth)
corner(wHealthFill, 10)
gradient(wHealthFill, Color3.fromRGB(255, 220, 60), Color3.fromRGB(220, 140, 10))
new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = TITLE,
	TextScaled = true,
	Text = "WOLVERINE",
	TextColor3 = K.White,
	ZIndex = 2,
}, wHealth)
new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }, wHealth)

local terminalsLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 148),
	Size = UDim2.fromOffset(320, 20),
	BackgroundTransparency = 1,
	Font = BODY,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(200, 160, 255),
	Text = "",
}, gui)
new("UIStroke", { Thickness = 1.5, Transparency = 0.3 }, terminalsLabel)

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
	TextColor3 = K.White,
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
	TextColor3 = K.Yellow,
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
	TextColor3 = K.White,
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
	Size = UDim2.fromOffset(330, 220),
	BackgroundTransparency = 1,
}, gui)
new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Right }, feed)

---------------------------------------------------------------------------
-- Stamina bar
---------------------------------------------------------------------------

local stamina = new("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(340, 34),
	BackgroundTransparency = 1,
	GroupTransparency = 0,
}, gui)
local stamScale = new("UIScale", {}, stamina)
local stamIcon = new("TextLabel", {
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = K.Ink,
	Font = TITLE,
	TextScaled = true,
	Text = "⚡",
	TextColor3 = K.Blue,
}, stamina)
corner(stamIcon, 17)
local stamIconStroke = stroke(stamIcon, K.Blue, 2)
new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, stamIcon)

local track = new("Frame", {
	Position = UDim2.fromOffset(42, 7),
	Size = UDim2.new(1, -42, 0, 20),
	BackgroundColor3 = K.Ink,
	BackgroundTransparency = 0.1,
	ClipsDescendants = true,
}, stamina)
corner(track, 10)
local trackStroke = stroke(track, Color3.fromRGB(40, 70, 100), 2)
local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, track)
corner(fill, 10)
local fillGrad = gradient(fill, Color3.fromRGB(90, 220, 255), Color3.fromRGB(30, 110, 230), 0)
new("Frame", { -- gloss
	Size = UDim2.new(1, 0, 0.45, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.8,
	BorderSizePixel = 0,
}, fill)
local sheen = new("Frame", {
	Size = UDim2.new(0, 40, 1, 0),
	Position = UDim2.new(-0.2, 0, 0, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.6,
	BorderSizePixel = 0,
	Rotation = 12,
}, fill)
new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 1) }) }, sheen)
for i = 1, 3 do -- segment ticks
	new("Frame", {
		Position = UDim2.new(i / 4, -1, 0, 3),
		Size = UDim2.new(0, 2, 1, -6),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, track)
end
local stamText = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = TITLE,
	TextSize = 13,
	TextColor3 = K.White,
	Text = "STAMINA",
	ZIndex = 4,
}, track)
new("UIStroke", { Thickness = 1.5, Transparency = 0.2 }, stamText)

---------------------------------------------------------------------------
-- Ability panel (bottom right)
---------------------------------------------------------------------------

local panel = new("Frame", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -16),
	Size = UDim2.fromOffset(290, 10),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, gui)
local panelScale = new("UIScale", {}, panel)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom }, panel)

local header = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 0 }, panel)
local headerText = new("TextLabel", {
	Size = UDim2.new(1, -50, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.LuckiestGuy,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = K.Yellow,
	Text = "",
}, header)
new("UIStroke", { Thickness = 2 }, headerText)
local headerLine = new("Frame", { Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0, BackgroundColor3 = K.Yellow }, header)
new("UIGradient", { Transparency = NumberSequence.new(0, 1) }, headerLine)

local slots = {}

local function makeCard(a, order, isHold)
	local accent = a.Color or K.Yellow
	local card = new("Frame", {
		Name = a.Name,
		Size = UDim2.new(1, 0, 0, isHold and 44 or 62),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
		ClipsDescendants = true,
	}, panel)
	corner(card, 12)
	gradient(card, Color3.fromRGB(36, 34, 42), Color3.fromRGB(16, 15, 20), 0)
	local cardStroke = stroke(card, accent, 1.5, 0.55)
	local scale = new("UIScale", {}, card)

	-- accent edge
	local edge = new("Frame", { Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = accent, BorderSizePixel = 0 }, card)
	gradient(edge, accent, darker(accent, 0.5))

	-- icon tile
	local tileSize = isHold and 32 or 46
	local tile = new("Frame", {
		Position = UDim2.new(0, 14, 0.5, -tileSize / 2),
		Size = UDim2.fromOffset(tileSize, tileSize),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
	}, card)
	corner(tile, 10)
	gradient(tile, darker(accent, 0.8), darker(accent, 0.3))
	local tileStroke = stroke(tile, accent, 2)
	local icon = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = TITLE,
		TextScaled = true,
		Text = a.Icon or "•",
		TextColor3 = K.White,
		ZIndex = 2,
	}, tile)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, icon)
	-- sweep overlay that drains top->bottom as the cooldown finishes
	local sweep = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, tile)
	local countdown = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = TITLE,
		TextScaled = true,
		Text = "",
		TextColor3 = K.White,
		ZIndex = 4,
	}, tile)
	new("UIStroke", { Thickness = 2 }, countdown)
	new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, countdown)

	-- text
	local x = 14 + tileSize + 10
	local name = new("TextLabel", {
		Position = UDim2.fromOffset(x, isHold and 6 or 9),
		Size = UDim2.new(1, -x - 60, 0, isHold and 18 or 20),
		BackgroundTransparency = 1,
		Font = TITLE,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = K.White,
		Text = string.upper(a.Label),
	}, card)
	new("TextLabel", {
		Position = UDim2.fromOffset(x, isHold and 24 or 31),
		Size = UDim2.new(1, -x - 60, 0, isHold and 14 or 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = isHold and 11 or 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(175, 170, 180),
		Text = a.Desc or "",
	}, card)

	-- keycap
	local cap = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(a.KeyText and #a.KeyText > 2 and 52 or 38, 36),
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
	}, card)
	corner(cap, 8)
	local capTop = new("Frame", {
		Size = UDim2.new(1, 0, 1, -4),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, cap)
	corner(capTop, 8)
	gradient(capTop, Color3.fromRGB(245, 245, 250), Color3.fromRGB(185, 185, 195))
	new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = TITLE,
		TextScaled = true,
		Text = a.KeyText or "",
		TextColor3 = Color3.fromRGB(25, 25, 30),
	}, capTop)
	new("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, capTop)

	-- ready flash
	local flashFrame = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = accent, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5 }, card)

	slots[a.Name] = {
		Card = card, Scale = scale, Stroke = cardStroke, TileStroke = tileStroke, Sweep = sweep, Countdown = countdown,
		Flash = flashFrame, Name = name, Icon = icon, Accent = accent, ReadyAt = 0, Duration = 1, WasCooling = false,
		Hold = isHold, Attr = a.Attr,
	}
end

function Interface.SetAbilities(list, holds, title, color)
	for _, s in slots do
		s.Card:Destroy()
	end
	slots = {}
	headerText.Text = title or ""
	headerText.TextColor3 = color or K.Yellow
	headerLine.BackgroundColor3 = color or K.Yellow
	header.Visible = (#list + #(holds or {})) > 0
	local order = 1
	for _, a in list do
		makeCard(a, order, false)
		order += 1
	end
	for _, h in holds or {} do
		makeCard(h, order, true)
		order += 1
	end
	-- slide in
	for i, s in slots do
		s.Scale.Scale = 0.6
		TweenService:Create(s.Scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

function Interface.StartCooldown(name, duration)
	local s = slots[name]
	if not s then
		return
	end
	s.ReadyAt = os.clock() + duration
	s.Duration = duration
	s.WasCooling = true
	-- press feedback
	s.Scale.Scale = 0.92
	TweenService:Create(s.Scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	s.Flash.BackgroundTransparency = 0.5
	TweenService:Create(s.Flash, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
end

function Interface.SetHint(_) end

function Interface.Announce(text, color, duration)
	announceLabel.Text = text
	announceLabel.TextColor3 = color or K.White
	announceLabel.TextTransparency = 0
	announceLabel.TextStrokeTransparency = 0
	announceLabel.Size = UDim2.new(0.9, 0, 0, 72)
	TweenService:Create(announceLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.new(0.9, 0, 0, 56) }):Play()
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
	roleLabel.TextColor3 = color or K.Yellow
	roleSub.Text = subtitle or ""
	roleLabel.Size = UDim2.new(0.9, 0, 0, 140)
	TweenService:Create(roleLabel, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Size = UDim2.new(0.9, 0, 0, 90) }):Play()
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
	flash.BackgroundColor3 = color or K.Red
	flash.BackgroundTransparency = 1 - (strength or 0.4)
	TweenService:Create(flash, TweenInfo.new(duration or 0.5), { BackgroundTransparency = 1 }):Play()
end

local danger = 0
function Interface.SetDanger(level)
	danger = level
end

function Interface.KillFeed(text)
	local l = new("TextLabel", {
		Size = UDim2.fromOffset(330, 28),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = BODY,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 130, 130),
		Text = text,
		Position = UDim2.fromOffset(60, 0),
	}, feed)
	corner(l, 8)
	gradient(l, Color3.fromRGB(40, 18, 20), Color3.fromRGB(14, 10, 12), 0)
	stroke(l, Color3.fromRGB(120, 30, 30), 1.5, 0.3)
	task.delay(6, function()
		TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.wait(0.5)
		l:Destroy()
	end)
end

function Interface.TimeBonus(seconds)
	local l = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 190, 0, 60),
		Size = UDim2.fromOffset(120, 36),
		BackgroundTransparency = 1,
		Font = TITLE,
		TextScaled = true,
		TextColor3 = K.Red,
		TextStrokeTransparency = 0,
		Text = "+" .. seconds .. "s",
	}, gui)
	TweenService:Create(l, TweenInfo.new(1.6), { Position = UDim2.new(0.5, 190, 0, 28), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.7, function()
		l:Destroy()
	end)
	topStroke.Color = K.Red
	TweenService:Create(topStroke, TweenInfo.new(1), { Color = Color3.fromRGB(120, 30, 30) }):Play()
end

---------------------------------------------------------------------------
-- Per-frame refresh
---------------------------------------------------------------------------

local pulseClock, shownStamina, lagHealth, sheenClock = 0, 1, 1, 0
local stamVisibleFor = 0

RunService.RenderStepped:Connect(function(dt)
	checkScreen()
	panelScale.Scale = smallScreen and 0.7 or 1
	stamScale.Scale = smallScreen and 0.75 or 1
	panel.Position = smallScreen and UDim2.new(1, -8, 0.62, 0) or UDim2.new(1, -16, 1, -16)
	local role = player:GetAttribute("Role")
	local inRound = ReplicatedStorage:GetAttribute("InRound")
	local now = workspace:GetServerTimeNow()

	statusLabel.Text = string.upper(ReplicatedStorage:GetAttribute("Status") or "")
	local ends = ReplicatedStorage:GetAttribute("TimerEnds") or 0
	local left = math.max(0, ends - now)
	if ends > 0 then
		timerLabel.Text = ("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
		local urgent = left < 20 and inRound
		timerLabel.TextColor3 = urgent and K.Red or K.White
	else
		timerLabel.Text = "--:--"
	end

	-- Wolverine health (white lag bar trails the real one)
	local wName = ReplicatedStorage:GetAttribute("Wolverine")
	local wPlayer = wName and Players:FindFirstChild(wName)
	local wHum = wPlayer and wPlayer.Character and wPlayer.Character:FindFirstChildOfClass("Humanoid")
	if wHum and inRound then
		wHealth.Visible = true
		local frac = math.clamp(wHum.Health / math.max(1, wHum.MaxHealth), 0, 1)
		lagHealth = math.max(frac, lagHealth - dt * 0.35)
		wHealthFill.Size = UDim2.fromScale(frac, 1)
		wHealthLag.Size = UDim2.fromScale(lagHealth, 1)
	else
		wHealth.Visible = false
		lagHealth = 1
	end

	local total = ReplicatedStorage:GetAttribute("TerminalsTotal") or 0
	if inRound and total > 0 then
		terminalsLabel.Text = ReplicatedStorage:GetAttribute("SuitOnline") and "⚠ SENTINEL SUIT ONLINE — CONTAINER YARD"
			or ("SENTINEL TERMINALS  %d / %d"):format(ReplicatedStorage:GetAttribute("Terminals") or 0, total)
	else
		terminalsLabel.Text = ""
	end

	-- Stamina
	local target = math.clamp(player:GetAttribute("Stamina") or 1, 0, 1)
	shownStamina += (target - shownStamina) * math.min(1, dt * 12)
	fill.Size = UDim2.fromScale(shownStamina, 1)
	local wolverine = role == "Wolverine"
	local draining = target < shownStamina - 0.001 or target < 0.999
	local exhausted = target < 0.05
	if wolverine then
		fillGrad.Color = ColorSequence.new(Color3.fromRGB(255, 190, 60), Color3.fromRGB(230, 60, 20))
		stamIcon.Text = "🐺"
		stamText.Text = exhausted and "EXHAUSTED" or "FERAL"
		stamIconStroke.Color = Color3.fromRGB(255, 150, 40)
	else
		fillGrad.Color = ColorSequence.new(Color3.fromRGB(90, 220, 255), Color3.fromRGB(30, 110, 230))
		stamIcon.Text = "⚡"
		stamText.Text = exhausted and "EXHAUSTED" or "STAMINA"
		stamIconStroke.Color = K.Blue
	end
	if exhausted then
		local blink = (math.sin(os.clock() * 12) + 1) / 2
		trackStroke.Color = Color3.fromRGB(255, 40, 40):Lerp(Color3.fromRGB(80, 10, 10), blink)
	else
		trackStroke.Color = wolverine and Color3.fromRGB(110, 60, 20) or Color3.fromRGB(40, 70, 100)
	end
	sheenClock += dt
	sheen.Position = UDim2.new((sheenClock % 1.6) / 1.6 * 1.4 - 0.2, 0, 0, 0)
	-- fade out when full and idle
	if draining then
		stamVisibleFor = 2
	else
		stamVisibleFor -= dt
	end
	local wantHidden = role == "Sentinel" or role == "Dead" or (stamVisibleFor <= 0 and role ~= "Wolverine")
	stamina.GroupTransparency += ((wantHidden and 0.75 or 0) - stamina.GroupTransparency) * math.min(1, dt * 6)

	-- Ability cards
	local t = os.clock()
	for _, s in slots do
		if s.Hold then
			local on = s.Attr and player:GetAttribute(s.Attr)
			s.Stroke.Transparency = on and 0 or 0.55
			s.Stroke.Thickness = on and 2.5 or 1.5
			s.Name.TextColor3 = on and s.Accent or K.White
		else
			local remaining = s.ReadyAt - t
			if remaining > 0 then
				s.Sweep.Size = UDim2.fromScale(1, math.clamp(remaining / s.Duration, 0, 1))
				s.Countdown.Text = remaining >= 10 and tostring(math.ceil(remaining)) or ("%.1f"):format(remaining)
				s.Icon.TextTransparency = 0.5
				s.Stroke.Transparency = 0.8
			else
				s.Sweep.Size = UDim2.fromScale(1, 0)
				s.Countdown.Text = ""
				s.Icon.TextTransparency = 0
				-- ready glow pulse
				local pulse = (math.sin(t * 3) + 1) / 2
				s.Stroke.Transparency = 0.2 + pulse * 0.4
				s.TileStroke.Thickness = 2 + pulse
				if s.WasCooling then
					s.WasCooling = false
					s.Scale.Scale = 1.1
					TweenService:Create(s.Scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
					s.Flash.BackgroundTransparency = 0.3
					TweenService:Create(s.Flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
				end
			end
		end
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

-- Wounds / armor indicator (bottom-left)
local wounds = new("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -20),
	Size = UDim2.fromOffset(210, 54),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false,
}, gui)
corner(wounds, 12)
gradient(wounds, Color3.fromRGB(40, 18, 22), Color3.fromRGB(14, 10, 12))
stroke(wounds, Color3.fromRGB(120, 30, 30), 1.5, 0.3)
local woundsTitle = new("TextLabel", {
	Position = UDim2.fromOffset(12, 5),
	Size = UDim2.new(1, -24, 0, 16),
	BackgroundTransparency = 1,
	Font = TITLE,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(230, 200, 200),
	Text = "WOUNDS",
}, wounds)
local pips = {}
for i = 1, math.max(Config.HitsToKill, Config.Sentinel.Armor) do
	local pip = new("Frame", {
		Position = UDim2.fromOffset(12 + (i - 1) * 46, 26),
		Size = UDim2.fromOffset(40, 20),
		BackgroundColor3 = Color3.fromRGB(60, 60, 66),
	}, wounds)
	corner(pip, 6)
	for c = -1, 1 do -- claw slash inside the pip
		new("Frame", {
			Name = "Slash",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, c * 7, 0.5, 0),
			Size = UDim2.fromOffset(3, 22),
			Rotation = 25,
			BackgroundColor3 = Color3.fromRGB(20, 0, 0),
			Visible = false,
		}, pip)
	end
	pips[i] = pip
end
RunService.RenderStepped:Connect(function()
	local role = player:GetAttribute("Role")
	if role == "Survivor" then
		wounds.Visible = true
		woundsTitle.Text = player:GetAttribute("Hidden") and "WOUNDS — HIDING" or "WOUNDS"
		local hits = player:GetAttribute("Hits") or 0
		for i, pip in pips do
			pip.Visible = i <= Config.HitsToKill
			local hurt = i <= hits
			pip.BackgroundColor3 = hurt and K.Red or Color3.fromRGB(60, 60, 66)
			for _, s in pip:GetChildren() do
				if s.Name == "Slash" then
					s.Visible = hurt
				end
			end
		end
	elseif role == "Sentinel" then
		wounds.Visible = true
		local armor = player:GetAttribute("Armor") or 0
		local suitEnds = player:GetAttribute("SuitEnds") or 0
		woundsTitle.Text = ("ARMOR — POWER %ds"):format(math.max(0, math.floor(suitEnds - workspace:GetServerTimeNow())))
		for i, pip in pips do
			pip.Visible = i <= Config.Sentinel.Armor
			pip.BackgroundColor3 = i <= armor and K.Purple or Color3.fromRGB(50, 50, 56)
			for _, s in pip:GetChildren() do
				if s.Name == "Slash" then
					s.Visible = false
				end
			end
		end
	else
		wounds.Visible = false
	end
end)

return Interface
