-- Map brightness setting: a sun button (top left, above the minimap; in the
-- lobby and in rounds)
-- opens a five-step picker. The level applies at once on this client
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
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = K.Yellow,
	Text = "☀",
	AutoButtonColor = false,
}, gui)
corner(button, 22)
gradient(button, Color3.fromRGB(46, 46, 58), Color3.fromRGB(18, 18, 24))
stroke(button, K.Yellow, 2)
new("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7) }, button)
UIKit.Animate(button, K.Yellow)

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
