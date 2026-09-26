-- Map brightness setting: a light-bulb button (top left, above the minimap;
-- in the lobby and in rounds) opens a five-step picker: the bulb flashes on
-- as it opens and goes dark again when it shuts. The level applies at once on this client
-- (Effects.SetBrightness) and is saved with the player's data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local ShopRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop")

local player = Players.LocalPlayer
local new, corner, stroke, gradient = UIKit.new, UIKit.Corner, UIKit.Stroke, UIKit.Gradient
local K = UIKit.Colors
local LEVELS = Config.Brightness.Levels

local gui = new("ScreenGui", { Name = "BrightnessUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 6 }, player:WaitForChild("PlayerGui"))

local button = new("TextButton", {
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Text = "",
	AutoButtonColor = false,
}, gui)
corner(button, 22)
gradient(button, Color3.fromRGB(46, 46, 58), Color3.fromRGB(18, 18, 24))
stroke(button, K.Yellow, 2)
UIKit.Animate(button, K.Yellow)

-- the bulb: a glow halo and rays (only while lit), the glass with its
-- filament, the neck and a screw base
local GLASS_OFF, GLASS_ON, FLASH = Color3.fromRGB(74, 74, 88), Color3.fromRGB(255, 232, 140), Color3.fromRGB(255, 255, 236)
local FIL_OFF, FIL_ON = Color3.fromRGB(40, 40, 48), Color3.fromRGB(255, 140, 40)
local CY = 0.4 -- the glass's centre, down the button
local halo = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, CY), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = Color3.fromRGB(255, 214, 90), BackgroundTransparency = 1 }, button)
corner(halo, 100)
local rays = {}
for k = 0, 7 do
	local a = k / 8 * math.pi * 2
	local ray = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.cos(a) * 14, CY, math.sin(a) * 14),
		Size = UDim2.fromOffset(2, 4), Rotation = math.deg(a) + 90, BackgroundColor3 = K.Yellow, BackgroundTransparency = 1, BorderSizePixel = 0,
	}, button)
	rays[k + 1] = { Frame = ray, A = a }
end
local glass = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, CY), Size = UDim2.fromOffset(19, 19), BackgroundColor3 = GLASS_OFF, BorderSizePixel = 0 }, button)
corner(glass, 100)
local glassStroke = stroke(glass, Color3.fromRGB(120, 120, 134), 1)
local neck = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, CY, 6), Size = UDim2.fromOffset(9, 6), BackgroundColor3 = GLASS_OFF, BorderSizePixel = 0 }, button)
local filament = {}
for _, sx in { -1, 1 } do
	filament[#filament + 1] = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, sx * 2.5, CY, 2), Size = UDim2.fromOffset(2, 7),
		Rotation = sx * 22, BackgroundColor3 = FIL_OFF, BorderSizePixel = 0,
	}, button)
end
for k = 0, 2 do -- the screw base
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, CY, 12 + k * 3), Size = UDim2.fromOffset(k == 2 and 7 or 10, 2), BackgroundColor3 = Color3.fromRGB(160, 160, 172), BorderSizePixel = 0 }, button)
end
new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, CY, 21), Size = UDim2.fromOffset(4, 2), BackgroundColor3 = Color3.fromRGB(90, 90, 100), BorderSizePixel = 0 }, button)

local function tween(obj, t, props, style)
	TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
local function bulb(on)
	if on then
		-- flash: white-hot, a big bright halo and the rays thrown wide, then settle
		glass.BackgroundColor3, neck.BackgroundColor3 = FLASH, FLASH
		halo.Size, halo.BackgroundTransparency = UDim2.fromOffset(44, 44), 0.3
		tween(glass, 0.35, { BackgroundColor3 = GLASS_ON })
		tween(neck, 0.35, { BackgroundColor3 = GLASS_ON })
		tween(halo, 0.4, { Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 0.72 })
		glassStroke.Color = K.Yellow
		for _, f in filament do
			tween(f, 0.15, { BackgroundColor3 = FIL_ON })
		end
		for _, r in rays do
			r.Frame.BackgroundTransparency = 0
			r.Frame.Position = UDim2.new(0.5, math.cos(r.A) * 19, CY, math.sin(r.A) * 19)
			tween(r.Frame, 0.35, { Position = UDim2.new(0.5, math.cos(r.A) * 14.5, CY, math.sin(r.A) * 14.5), BackgroundTransparency = 0.15 }, Enum.EasingStyle.Back)
		end
	else
		tween(glass, 0.2, { BackgroundColor3 = GLASS_OFF })
		tween(neck, 0.2, { BackgroundColor3 = GLASS_OFF })
		tween(halo, 0.2, { BackgroundTransparency = 1 })
		glassStroke.Color = Color3.fromRGB(120, 120, 134)
		for _, f in filament do
			tween(f, 0.2, { BackgroundColor3 = FIL_OFF })
		end
		for _, r in rays do
			tween(r.Frame, 0.15, { BackgroundTransparency = 1 })
		end
	end
end

local panel = new("Frame", {
	Position = UDim2.fromOffset(68, 8),
	Size = UDim2.fromOffset(264, 112),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false,
}, gui)
corner(panel, 12)
gradient(panel, Color3.fromRGB(34, 34, 44), Color3.fromRGB(16, 16, 22))
stroke(panel, K.Yellow, 2)
new("TextLabel", {
	Position = UDim2.fromOffset(14, 8),
	Size = UDim2.new(1, -28, 0, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = K.Yellow,
	Text = "MAP BRIGHTNESS",
}, panel)
local levelName = new("TextLabel", {
	Position = UDim2.fromOffset(14, 82),
	Size = UDim2.new(1, -28, 0, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(215, 215, 225),
	Text = "",
}, panel)

-- one step per level: a little sun that grows with the level
local steps = {}
local row = new("Frame", { Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -28, 0, 40), BackgroundTransparency = 1 }, panel)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }, row)
for i = 1, #LEVELS do
	local b = new("TextButton", {
		Size = UDim2.fromOffset(42, 40),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		AutoButtonColor = false,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(150, 150, 160),
		Text = "☀",
		LayoutOrder = i,
	}, row)
	corner(b, 8)
	local pad = (#LEVELS - i) * 3 + 5 -- the brighter the level, the bigger the sun
	new("UIPadding", { PaddingTop = UDim.new(0, pad), PaddingBottom = UDim.new(0, pad) }, b)
	steps[i] = { Button = b, Stroke = stroke(b, Color3.fromRGB(70, 70, 84), 1.5) }
end

local current = nil
local function show(level)
	current = level
	for i, s in steps do
		local on = i == level
		s.Button.BackgroundColor3 = on and Color3.fromRGB(96, 76, 16) or Color3.fromRGB(40, 40, 50)
		s.Button.TextColor3 = on and K.Yellow or (i < level and Color3.fromRGB(200, 170, 70) or Color3.fromRGB(150, 150, 160))
		s.Stroke.Color = on and K.Yellow or Color3.fromRGB(70, 70, 84)
	end
	levelName.Text = LEVELS[level].Name
end

local function pick(level)
	if level == current then
		return
	end
	show(level)
	Effects.SetBrightness(level)
	task.spawn(function()
		pcall(function()
			ShopRemote:InvokeServer("Brightness", tostring(level))
		end)
	end)
end
for i, s in steps do
	s.Button.Activated:Connect(function()
		pick(i)
	end)
end

button.Activated:Connect(function()
	panel.Visible = not panel.Visible
	bulb(panel.Visible)
	if panel.Visible then
		panel.Size = UDim2.fromOffset(264, 90)
		TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(264, 112) }):Play()
	end
end)

local function fromAttribute()
	local level = tonumber(player:GetAttribute("Brightness"))
	show(LEVELS[level] and level or Config.Brightness.Default)
end
player:GetAttributeChangedSignal("Brightness"):Connect(fromAttribute)
fromAttribute()

return {}
