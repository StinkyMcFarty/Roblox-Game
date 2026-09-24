-- Wolverine skin shop (button on the left of the screen).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skins = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skins"))
local ShopRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop")

local player = Players.LocalPlayer
local Shop = {}

local DARK = Color3.fromRGB(16, 16, 20)
local YELLOW = Color3.fromRGB(255, 205, 30)

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local gui = new("ScreenGui", { Name = "SkinShop", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

local openButton = new("TextButton", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.fromOffset(110, 44),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.15,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = YELLOW,
	Text = "SKINS",
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 10) }, openButton)
new("UIStroke", { Color = YELLOW, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, openButton)
new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, openButton)

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(620, 360),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 30,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, panel)
new("UIStroke", { Color = YELLOW, Thickness = 2 }, panel)
new("UISizeConstraint", { MaxSize = Vector2.new(620, 360) }, panel)
new("UIScale", {}, panel)

new("TextLabel", {
	Position = UDim2.fromOffset(20, 12),
	Size = UDim2.new(1, -140, 0, 36),
	BackgroundTransparency = 1,
	Font = Enum.Font.LuckiestGuy,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = YELLOW,
	Text = "WOLVERINE SKINS",
	ZIndex = 31,
}, panel)
local coinsLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -60, 0, 16),
	Size = UDim2.fromOffset(160, 28),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = Color3.fromRGB(255, 225, 120),
	Text = "",
	ZIndex = 31,
}, panel)
local close = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = Color3.fromRGB(150, 30, 30),
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "X",
	ZIndex = 31,
}, panel)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, close)

local grid = new("Frame", {
	Position = UDim2.fromOffset(16, 60),
	Size = UDim2.new(1, -32, 1, -104),
	BackgroundTransparency = 1,
	ZIndex = 31,
}, panel)
new("UIGridLayout", { CellSize = UDim2.fromOffset(140, 250), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)

local message = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.new(1, -40, 0, 24),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Earn coins by surviving, rebooting terminals and getting kills.",
	ZIndex = 31,
}, panel)

local cards = {}

local function owned(id)
	for s in string.gmatch(player:GetAttribute("OwnedSkins") or "", "[^,]+") do
		if s == id then
			return true
		end
	end
	return false
end

local function refresh()
	local coins = 0
	local ls = player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Coins") then
		coins = ls.Coins.Value
	end
	coinsLabel.Text = coins .. " coins"
	local equipped = player:GetAttribute("Skin")
	for id, card in cards do
		local skin = Skins.List[id]
		if equipped == id then
			card.Button.Text = "EQUIPPED"
			card.Button.BackgroundColor3 = Color3.fromRGB(40, 120, 60)
		elseif owned(id) then
			card.Button.Text = "EQUIP"
			card.Button.BackgroundColor3 = Color3.fromRGB(50, 80, 140)
		else
			card.Button.Text = "BUY " .. skin.Price
			card.Button.BackgroundColor3 = coins >= skin.Price and Color3.fromRGB(190, 140, 20) or Color3.fromRGB(70, 70, 75)
		end
	end
end

for i, id in Skins.Order do
	local skin = Skins.List[id]
	local card = new("Frame", { BackgroundColor3 = Color3.fromRGB(30, 30, 36), LayoutOrder = i, ZIndex = 32 }, grid)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, card)
	local swatch = new("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 70),
		BackgroundColor3 = skin.Swatch,
		ZIndex = 33,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, swatch)
	for c = -1, 1 do -- claw marks on the swatch
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, c * 14, 0.5, 0),
			Size = UDim2.fromOffset(4, 56),
			Rotation = 20,
			BackgroundColor3 = Color3.fromRGB(220, 225, 235),
			ZIndex = 34,
		}, swatch)
	end
	new("TextLabel", {
		Position = UDim2.fromOffset(8, 86),
		Size = UDim2.new(1, -16, 0, 40),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = skin.Name,
		ZIndex = 33,
	}, card)
	new("TextLabel", {
		Position = UDim2.fromOffset(8, 128),
		Size = UDim2.new(1, -16, 0, 70),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(190, 190, 200),
		Text = skin.Description,
		ZIndex = 33,
	}, card)
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 36),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		ZIndex = 33,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, button)
	button.Activated:Connect(function()
		local action = owned(id) and "Equip" or "Buy"
		local ok, msg = ShopRemote:InvokeServer(action, id)
		message.Text = msg or ""
		message.TextColor3 = ok and Color3.fromRGB(120, 255, 150) or Color3.fromRGB(255, 110, 110)
		refresh()
	end)
	cards[id] = { Button = button }
end

-- Fit small (phone) screens
local function fit()
	local cam = workspace.CurrentCamera
	local s = math.min(1, (cam.ViewportSize.X - 24) / 620, (cam.ViewportSize.Y - 24) / 360)
	panel:FindFirstChildOfClass("UIScale").Scale = math.max(0.4, s)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
fit()

openButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
	refresh()
end)
close.Activated:Connect(function()
	panel.Visible = false
end)
player:GetAttributeChangedSignal("OwnedSkins"):Connect(refresh)
player:GetAttributeChangedSignal("Skin"):Connect(refresh)
task.spawn(function()
	local ls = player:WaitForChild("leaderstats", 30)
	local coins = ls and ls:WaitForChild("Coins", 30)
	if coins then
		coins.Changed:Connect(refresh)
	end
	refresh()
end)

return Shop
