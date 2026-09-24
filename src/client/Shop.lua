-- Wolverine shop: suits + claws, and the left-side menu dock.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Skins = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skins"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local ShopRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop")

local player = Players.LocalPlayer
local Shop = {}

local new, corner, stroke, gradient = UIKit.new, UIKit.Corner, UIKit.Stroke, UIKit.Gradient
local K = UIKit.Colors

local gui = new("ScreenGui", { Name = "SkinShop", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

---------------------------------------------------------------------------
-- Left dock (shared with the Daily module)
---------------------------------------------------------------------------

local dock = new("Frame", {
	Name = "Dock",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 0),
	Size = UDim2.fromOffset(170, 10),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, gui)
local dockScale = new("UIScale", {}, dock)
new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, dock)
Shop.Dock = dock

local function fitDock()
	local v = workspace.CurrentCamera.ViewportSize
	dockScale.Scale = (v.X < 900 or v.Y < 520) and 0.7 or 1
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitDock)
fitDock()

function Shop.DockButton(text, icon, color, order)
	local b, label = UIKit.Button(dock, { Text = text, Icon = icon, Color = color, Size = UDim2.fromOffset(170, 54), LayoutOrder = order })
	return b, label
end

-- Coin counter at the top of the dock
local coinPlate = new("Frame", { Size = UDim2.fromOffset(170, 40), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 0 }, dock)
corner(coinPlate, 20)
gradient(coinPlate, Color3.fromRGB(60, 46, 10), Color3.fromRGB(24, 18, 6))
stroke(coinPlate, K.Yellow, 2)
UIKit.Coin(coinPlate, 28, { Position = UDim2.fromOffset(7, 6) })
local coinText = new("TextLabel", {
	Position = UDim2.fromOffset(42, 0),
	Size = UDim2.new(1, -52, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = K.Yellow,
	Text = "0",
}, coinPlate)
new("UIPadding", { PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9) }, coinText)
local coinScale = new("UIScale", {}, coinPlate)

---------------------------------------------------------------------------
-- Shop window
---------------------------------------------------------------------------

local window = UIKit.Window(gui, "WOLVERINE ARMORY", UDim2.fromOffset(700, 430), K.Yellow)
local w = window.Frame

local tabs = new("Frame", { Position = UDim2.fromOffset(20, 66), Size = UDim2.new(1, -40, 0, 40), BackgroundTransparency = 1, ZIndex = 31 }, w)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }, tabs)

local scroller = new("ScrollingFrame", {
	Position = UDim2.fromOffset(20, 116),
	Size = UDim2.new(1, -40, 1, -160),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = K.Yellow,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X,
	ZIndex = 31,
}, w)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, scroller)
new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 4) }, scroller)

local message = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(1, -40, 0, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(190, 190, 200),
	Text = "Earn coins by surviving, rebooting terminals, kills and daily challenges.",
	ZIndex = 31,
}, w)

local category = "Suits"
local cards = {}

local function ownedList(attr)
	local set = {}
	for s in string.gmatch(player:GetAttribute(attr) or "", "[^,]+") do
		set[s] = true
	end
	return set
end

local function coins()
	local ls = player:FindFirstChild("leaderstats")
	return (ls and ls:FindFirstChild("Coins")) and ls.Coins.Value or 0
end

local function refresh()
	coinText.Text = tostring(coins())
	local owned = ownedList(category == "Suits" and "OwnedSkins" or "OwnedClaws")
	local equipped = player:GetAttribute(category == "Suits" and "Skin" or "Claw")
	local list = category == "Suits" and Skins.List or Skins.Claws
	for id, card in cards do
		local item = list[id]
		if equipped == id then
			UIKit.CoinText(card.Label, "EQUIPPED", false)
			UIKit.Recolor(card.Button, K.Green)
			card.Stroke.Color = K.Green
			card.Stroke.Thickness = 3
		elseif owned[id] then
			UIKit.CoinText(card.Label, "EQUIP", false)
			UIKit.Recolor(card.Button, K.Blue)
			card.Stroke.Color = Color3.fromRGB(70, 70, 80)
			card.Stroke.Thickness = 2
		else
			UIKit.CoinText(card.Label, tostring(item.Price))
			UIKit.Recolor(card.Button, coins() >= item.Price and K.Yellow or Color3.fromRGB(90, 90, 96))
			card.Stroke.Color = Color3.fromRGB(70, 70, 80)
			card.Stroke.Thickness = 2
		end
	end
end

-- Draws a little claw preview (3 blades) inside a frame
local function clawPreview(parent, item)
	for i = -1, 1 do
		local blade = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, i * 22, 0.92, 0),
			Size = UDim2.fromOffset(item.Thick and 12 or 8, 86),
			Rotation = i * 6,
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 34,
		}, parent)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, blade)
		gradient(blade, item.Color:Lerp(Color3.new(1, 1, 1), 0.35), item.Color, 0)
		new("UIStroke", { Color = item.Glow, Thickness = 2, Transparency = 0.3 }, blade)
	end
end

-- Draws a little suit preview (colour blocks shaped like a body)
local function suitPreview(parent, item)
	local c = item.Colors
	local skin = Color3.fromRGB(230, 180, 140)
	local function col(x)
		return x == "Skin" and skin or x
	end
	local function box(x, y, wd, h, color)
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, x, 0, y),
			Size = UDim2.fromOffset(wd, h),
			BackgroundColor3 = color,
			ZIndex = 34,
		}, parent)
		corner(f, 4)
		return f
	end
	box(0, 8, 26, 24, skin)
	box(0, 34, 40, 34, col(c.UpperTorso))
	box(0, 68, 40, 10, col(c.LowerTorso))
	box(-28, 34, 14, 22, col(c.UpperArm))
	box(28, 34, 14, 22, col(c.UpperArm))
	box(-28, 56, 14, 14, col(c.LowerArm))
	box(28, 56, 14, 14, col(c.LowerArm))
	box(-10, 78, 18, 18, col(c.UpperLeg))
	box(10, 78, 18, 18, col(c.UpperLeg))
	box(-10, 96, 18, 8, col(c.Foot))
	box(10, 96, 18, 8, col(c.Foot))
end

local function build()
	for _, c in cards do
		c.Card:Destroy()
	end
	cards = {}
	local order = category == "Suits" and Skins.Order or Skins.ClawOrder
	local list = category == "Suits" and Skins.List or Skins.Claws
	for i, id in order do
		local item = list[id]
		local card = new("Frame", { Size = UDim2.fromOffset(190, 250), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, ZIndex = 32 }, scroller)
		corner(card, 14)
		gradient(card, Color3.fromRGB(44, 42, 52), Color3.fromRGB(20, 19, 25))
		local cardStroke = stroke(card, Color3.fromRGB(70, 70, 80), 2)
		local scale = new("UIScale", {}, card)

		local preview = new("Frame", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, 112),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			ZIndex = 33,
		}, card)
		corner(preview, 10)
		local accent = category == "Suits" and item.Swatch or item.Glow
		gradient(preview, accent:Lerp(Color3.new(0, 0, 0), 0.35), Color3.fromRGB(12, 12, 16))
		if category == "Suits" then
			suitPreview(preview, item)
		else
			clawPreview(preview, item)
		end
		new("TextLabel", {
			Position = UDim2.fromOffset(12, 128),
			Size = UDim2.new(1, -24, 0, 24),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = K.White,
			Text = item.Name,
			ZIndex = 33,
		}, card)
		new("TextLabel", {
			Position = UDim2.fromOffset(12, 154),
			Size = UDim2.new(1, -24, 0, 40),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(180, 178, 190),
			Text = item.Description,
			ZIndex = 33,
		}, card)
		local button, label = UIKit.Button(card, {
			Text = "",
			Color = K.Yellow,
			Size = UDim2.new(1, -20, 0, 40),
			Position = UDim2.new(0, 10, 1, -50),
			ZIndex = 34,
		})
		card.MouseEnter:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1.04 }):Play()
		end)
		card.MouseLeave:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 1 }):Play()
		end)
		button.Activated:Connect(function()
			local isSuit = category == "Suits"
			local owned = ownedList(isSuit and "OwnedSkins" or "OwnedClaws")[id]
			local action = (owned and "Equip" or "Buy") .. (isSuit and "" or "Claw")
			local ok, msg = ShopRemote:InvokeServer(action, id)
			message.Text = msg or ""
			message.TextColor3 = ok and K.Green or Color3.fromRGB(255, 110, 110)
			if ok then
				scale.Scale = 1.12
				TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
			refresh()
		end)
		cards[id] = { Card = card, Button = button, Label = label, Stroke = cardStroke }
	end
	scroller.CanvasPosition = Vector2.zero
	refresh()
end

local tabButtons = {}
local function selectTab(name)
	category = name
	for n, b in tabButtons do
		UIKit.Recolor(b, n == name and K.Yellow or Color3.fromRGB(80, 80, 90))
	end
	build()
end
for i, name in { "Suits", "Claws" } do
	local b = UIKit.Button(tabs, {
		Text = name == "Suits" and "SUITS" or "CLAWS",
		Icon = name == "Suits" and "🦸" or "🗡️",
		Color = K.Yellow,
		Size = UDim2.fromOffset(150, 40),
		LayoutOrder = i,
		ZIndex = 32,
	})
	tabButtons[name] = b
	b.Activated:Connect(function()
		selectTab(name)
	end)
end
selectTab("Suits")

local openButton = Shop.DockButton("ARMORY", "🛡️", K.Yellow, 1)
openButton.Activated:Connect(function()
	refresh()
	window.Toggle()
end)

player:GetAttributeChangedSignal("OwnedSkins"):Connect(refresh)
player:GetAttributeChangedSignal("Skin"):Connect(refresh)
player:GetAttributeChangedSignal("OwnedClaws"):Connect(refresh)
player:GetAttributeChangedSignal("Claw"):Connect(refresh)
task.spawn(function()
	local ls = player:WaitForChild("leaderstats", 30)
	local c = ls and ls:WaitForChild("Coins", 30)
	if c then
		local last = c.Value
		c.Changed:Connect(function(v)
			if v > last then
				coinScale.Scale = 1.15
				TweenService:Create(coinScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
			last = v
			refresh()
		end)
	end
	refresh()
end)

-- Lobby statues show the claws YOU have equipped (all skins are built onto
-- them server-side; we just reveal the matching set locally).
local CollectionService = game:GetService("CollectionService")
local function statueClaws(model)
	local mine = player:GetAttribute("Claw") or Skins.DefaultClaw
	local folder = model:FindFirstChild("Claws")
	if not folder then
		return
	end
	for _, p in folder:GetChildren() do
		local id = p:GetAttribute("ClawSkin")
		if id and p:IsA("BasePart") then
			p.Transparency = (id == mine) and (p:GetAttribute("BaseT") or 0) or 1
		end
	end
end
local function allStatues()
	for _, m in CollectionService:GetTagged("SkinStatue") do
		statueClaws(m)
	end
end
CollectionService:GetInstanceAddedSignal("SkinStatue"):Connect(function(m)
	task.wait(0.5) -- let its claw parts replicate
	statueClaws(m)
end)
player:GetAttributeChangedSignal("Claw"):Connect(allStatues)
task.spawn(function()
	for _ = 1, 10 do -- statues and claws may still be replicating on join
		allStatues()
		task.wait(1)
	end
end)

return Shop
