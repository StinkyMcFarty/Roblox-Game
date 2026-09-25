-- Survivor upgrades window (lobby dock "UPGRADES"): one card per upgrade in
-- Config.Upgrades with what it does, its price and a buy button. Bought
-- upgrades are kept forever (PlayerData, attribute "Upgrades").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local ShopRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop")

local player = Players.LocalPlayer
local new, corner, stroke, gradient = UIKit.new, UIKit.Corner, UIKit.Stroke, UIKit.Gradient
local K = UIKit.Colors
local GREEN = Color3.fromRGB(150, 210, 50)

local gui = new("ScreenGui", { Name = "Upgrades", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
local window = UIKit.Window(gui, "SURVIVOR UPGRADES", UDim2.fromOffset(560, 340), GREEN)
local w = window.Frame

local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(20, 72),
	Size = UDim2.new(1, -40, 1, -118),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = GREEN,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ZIndex = 31,
}, w)
new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local message = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(1, -40, 0, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(190, 190, 200),
	Text = "Upgrades are yours for good once bought.",
	ZIndex = 31,
}, w)

local function owned(id)
	for _, v in string.split(player:GetAttribute("Upgrades") or "", ",") do
		if v == id then
			return true
		end
	end
	return false
end

local cards = {} -- [id] = { Button, Label }
for id, up in Config.Upgrades do
	local card = new("Frame", { Size = UDim2.new(1, -8, 0, 96), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = up.Order or 0, ZIndex = 31 }, list)
	corner(card, 12)
	gradient(card, Color3.fromRGB(40, 48, 30), Color3.fromRGB(20, 24, 16))
	stroke(card, GREEN, 1.5, 0.3)
	new("TextLabel", {
		Position = UDim2.fromOffset(12, 14),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		Text = up.Icon or "⬆",
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		ZIndex = 32,
	}, card)
	new("TextLabel", {
		Position = UDim2.fromOffset(88, 10),
		Size = UDim2.new(1, -250, 0, 26),
		BackgroundTransparency = 1,
		Text = up.Name,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 32,
	}, card)
	new("TextLabel", {
		Position = UDim2.fromOffset(88, 38),
		Size = UDim2.new(1, -250, 0, 48),
		BackgroundTransparency = 1,
		Text = up.Desc,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(200, 205, 190),
		ZIndex = 32,
	}, card)
	local button, label = UIKit.Button(card, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(140, 50),
		Color = K.Yellow,
		Text = "",
		ZIndex = 32,
	})
	button.Activated:Connect(function()
		if owned(id) then
			return
		end
		local ok, msg = ShopRemote:InvokeServer("BuyUpgrade", id)
		message.Text = msg or (ok and "Unlocked!" or "Couldn't buy that")
		message.TextColor3 = ok and GREEN or Color3.fromRGB(255, 110, 100)
	end)
	cards[id] = { Button = button, Label = label, Price = up.Price }
end

local function refresh()
	for id, c in cards do
		if owned(id) then
			c.Label.Text = "OWNED"
			UIKit.Recolor(c.Button, GREEN)
		else
			c.Label.Text = ("BUY  %d"):format(c.Price)
			UIKit.Recolor(c.Button, K.Yellow)
		end
	end
end
player:GetAttributeChangedSignal("Upgrades"):Connect(refresh)
refresh()

local openButton = Shop.DockButton("UPGRADES", "⬆️", GREEN, 7)
openButton.Activated:Connect(function()
	refresh()
	message.Text = "Upgrades are yours for good once bought."
	message.TextColor3 = Color3.fromRGB(190, 190, 200)
	window.Toggle()
end)

return {}
