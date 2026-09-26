-- Lobby dock: STORE (buy coin packs with Robux) and AFK (sit out matches).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local AfkRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Afk")

local player = Players.LocalPlayer
local new, corner, stroke, gradient = UIKit.new, UIKit.Corner, UIKit.Stroke, UIKit.Gradient
local K = UIKit.Colors

local gui = new("ScreenGui", { Name = "Store", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5 }, player:WaitForChild("PlayerGui"))

local function commas(n)
	local s = tostring(n)
	while true do
		local k
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			return s
		end
	end
end

---------------------------------------------------------------------------
-- Store window: four coin packs
---------------------------------------------------------------------------

local window = UIKit.Window(gui, Config.CoinName:gsub("s$", ""):upper() .. " STORE", UDim2.fromOffset(720, 400), K.Yellow)
local w = window.Frame

local row = new("Frame", { Position = UDim2.fromOffset(20, 72), Size = UDim2.new(1, -40, 0, 270), BackgroundTransparency = 1, ZIndex = 31 }, w)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center }, row)

local message = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.new(1, -40, 0, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(190, 190, 200),
	Text = Config.CoinName .. " buy suits and claws in the Armory. Bigger packs give a bonus.",
	ZIndex = 31,
}, w)

-- a little pile of drawn coins, bigger for bigger packs
local function coinPile(parent, tier)
	local pile = new("Frame", { Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromOffset(0, 14), BackgroundTransparency = 1, ZIndex = 33 }, parent)
	local layout = {
		{ { 0, 0, 44 } },
		{ { -16, 6, 38 }, { 16, -2, 42 } },
		{ { -26, 10, 34 }, { 26, 8, 34 }, { 0, -6, 44 } },
		{ { -30, 14, 32 }, { 30, 12, 32 }, { -12, -4, 38 }, { 14, -10, 42 }, { 0, 16, 30 } },
	}
	for i, c in layout[tier] do
		UIKit.Coin(pile, c[3], {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, c[1], 0.5, c[2]),
			ZIndex = 34 + i,
			Rotation = (i % 2 == 0) and 12 or -8,
		})
	end
	return pile
end

local priceLabels = {}
for i, pack in Config.CoinPacks do
	local card = new("Frame", { Size = UDim2.fromOffset(152, 262), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, ZIndex = 32 }, row)
	corner(card, 14)
	gradient(card, Color3.fromRGB(48, 40, 22), Color3.fromRGB(20, 18, 14))
	stroke(card, i == #Config.CoinPacks and K.Yellow or Color3.fromRGB(110, 90, 40), i == #Config.CoinPacks and 2.5 or 1.5)
	coinPile(card, i)
	if pack.Bonus ~= "" then
		local ribbon = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, -10),
			Size = UDim2.fromOffset(112, 22),
			BackgroundColor3 = K.Red,
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = pack.Bonus,
			ZIndex = 40,
		}, card)
		corner(ribbon, 11)
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, ribbon)
	end
	local amount = new("TextLabel", {
		Position = UDim2.fromOffset(8, 116),
		Size = UDim2.new(1, -16, 0, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.LuckiestGuy,
		TextScaled = true,
		TextColor3 = K.Yellow,
		Text = commas(pack.Coins),
		ZIndex = 33,
	}, card)
	new("UIStroke", { Thickness = 2 }, amount)
	new("TextLabel", {
		Position = UDim2.fromOffset(8, 152),
		Size = UDim2.new(1, -16, 0, 32),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(210, 205, 190),
		Text = pack.Name,
		ZIndex = 33,
	}, card)
	local buy, buyLabel = UIKit.Button(card, {
		Text = "R$ " .. pack.Robux,
		Color = K.Green,
		Size = UDim2.new(1, -20, 0, 46),
		Position = UDim2.new(0, 10, 1, -58),
		ZIndex = 34,
	})
	priceLabels[i] = buyLabel
	buy.Activated:Connect(function()
		if pack.ProductId == 0 then
			message.Text = "This pack isn't set up yet (add its Developer Product ID in Config.CoinPacks)."
			message.TextColor3 = K.Red
			return
		end
		MarketplaceService:PromptProductPurchase(player, pack.ProductId)
	end)
end

-- show the real Robux price from the Creator Dashboard once the product exists
task.spawn(function()
	for i, pack in Config.CoinPacks do
		if pack.ProductId ~= 0 then
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(pack.ProductId, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				priceLabels[i].Text = "R$ " .. info.PriceInRobux
			end
		end
	end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
	if userId ~= player.UserId or not purchased then
		return
	end
	for _, pack in Config.CoinPacks do
		if pack.ProductId == productId then
			message.Text = ("+%s %s! Spend them in the Armory."):format(commas(pack.Coins), Config.CoinName)
			message.TextColor3 = K.Green
		end
	end
end)

local storeButton = Shop.DockButton("STORE", "💰", K.Green, 5)
storeButton.Activated:Connect(function()
	message.TextColor3 = Color3.fromRGB(190, 190, 200)
	window.Toggle()
end)

---------------------------------------------------------------------------
-- AFK toggle
---------------------------------------------------------------------------

local afkButton, afkLabel = Shop.DockButton("AFK: OFF", "💤", Color3.fromRGB(120, 124, 140), 6)

local banner = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 58),
	Size = UDim2.fromOffset(460, 34),
	BackgroundColor3 = Color3.fromRGB(20, 22, 30),
	BackgroundTransparency = 0.15,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(170, 200, 255),
	Text = "YOU'RE AFK — sitting out matches. Press AFK to play again.",
	Visible = false,
}, gui)
corner(banner, 10)
stroke(banner, Color3.fromRGB(90, 120, 200), 1.5)
new("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, banner)

-- true while the AFK was set by the idle timer (not the button): any input
-- clears it again
local autoAfk = false

local function showAfk()
	local on = player:GetAttribute("AFK") == true
	banner.Text = autoAfk and "YOU'RE AFK — move or press any key to play again." or "YOU'RE AFK — sitting out matches. Press AFK to play again."
	afkLabel.Text = on and "AFK: ON" or "AFK: OFF"
	UIKit.Recolor(afkButton, on and K.Blue or Color3.fromRGB(120, 124, 140))
	banner.Visible = on
	if on then
		banner.TextTransparency = 1
		TweenService:Create(banner, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	end
end
player:GetAttributeChangedSignal("AFK"):Connect(showAfk)
showAfk()

afkButton.Activated:Connect(function()
	autoAfk = false
	AfkRemote:FireServer(not (player:GetAttribute("AFK") == true))
end)

-- Roblox fires Idled after ~2 minutes with no input: sit them out
-- automatically, but only while they're waiting in the lobby (hiding in a
-- locker or spectating a match isn't being away), and the moment they touch a
-- control again they're back in. An AFK turned on with the button stays on.
if Config.AutoAfk then
	player.Idled:Connect(function()
		local role = player:GetAttribute("Role")
		if (role == nil or role == "Lobby") and not player:GetAttribute("AFK") then
			autoAfk = true
			AfkRemote:FireServer(true)
		end
	end)
	local function back()
		if autoAfk then
			autoAfk = false
			if player:GetAttribute("AFK") then
				AfkRemote:FireServer(false)
			else
				showAfk()
			end
		end
	end
	UserInputService.InputBegan:Connect(back)
	UserInputService.InputChanged:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch or t == Enum.UserInputType.Gamepad1 then
			back()
		end
	end)
end

return {}
