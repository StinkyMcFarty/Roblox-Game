-- Daily challenges panel, login streak, Wolverine odds and the Robux
-- "guaranteed Wolverine" button.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local Daily = {}

local DARK = Color3.fromRGB(16, 16, 20)
local YELLOW = Color3.fromRGB(255, 205, 30)
local GREEN = Color3.fromRGB(90, 220, 120)

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

local gui = new("ScreenGui", { Name = "DailyUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

local function sideButton(text, y, color)
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, y),
		Size = UDim2.fromOffset(110, 44),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.15,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = color,
		Text = text,
	}, gui)
	corner(b, 10)
	new("UIStroke", { Color = color, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, b)
	return b
end

local dailyButton = sideButton("DAILY", 52, GREEN)
local buyButton = sideButton("BE WOLVERINE\n80 R$", 104, YELLOW)
buyButton.Size = UDim2.fromOffset(110, 52)
buyButton.Position = UDim2.new(0, 12, 0.5, 108)

local chanceLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 150),
	Size = UDim2.fromOffset(160, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(255, 120, 120),
	TextStrokeTransparency = 0.4,
	Text = "",
}, gui)

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(460, 340),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 30,
}, gui)
corner(panel, 14)
new("UIStroke", { Color = GREEN, Thickness = 2 }, panel)
local scale = new("UIScale", {}, panel)

new("TextLabel", {
	Position = UDim2.fromOffset(20, 12),
	Size = UDim2.new(1, -80, 0, 34),
	BackgroundTransparency = 1,
	Font = Enum.Font.LuckiestGuy,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = GREEN,
	Text = "DAILY CHALLENGES",
	ZIndex = 31,
}, panel)
local close = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = Color3.fromRGB(150, 30, 30),
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "X",
	ZIndex = 31,
}, panel)
corner(close, 8)

local list = new("Frame", {
	Position = UDim2.fromOffset(16, 56),
	Size = UDim2.new(1, -32, 0, 230),
	BackgroundTransparency = 1,
	ZIndex = 31,
}, panel)
new("UIListLayout", { Padding = UDim.new(0, 8) }, list)

local streakLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(1, -32, 0, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = YELLOW,
	Text = "",
	ZIndex = 31,
}, panel)

local rows = {}
for i, c in Config.DailyChallenges do
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = Color3.fromRGB(30, 30, 36), LayoutOrder = i, ZIndex = 32 }, list)
	corner(row, 8)
	new("TextLabel", {
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -120, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = c.Text,
		ZIndex = 33,
	}, row)
	new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 4),
		Size = UDim2.fromOffset(100, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = YELLOW,
		Text = "+" .. c.Reward .. " coins",
		ZIndex = 33,
	}, row)
	local bar = new("Frame", { Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 10), BackgroundColor3 = Color3.fromRGB(55, 55, 62), ZIndex = 33 }, row)
	corner(bar, 5)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0, ZIndex = 34 }, bar)
	corner(fill, 5)
	local count = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		ZIndex = 35,
	}, bar)
	rows[c.Id] = { Fill = fill, Count = count, Goal = c.Goal, Id = c.Id }
end

local function refresh()
	local ok, data = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Challenges") or "{}")
	end)
	local progress = (ok and type(data) == "table" and type(data.Progress) == "table") and data.Progress or {}
	local done = (ok and type(data) == "table" and type(data.Done) == "table") and data.Done or {}
	for id, r in rows do
		local v = tonumber(progress[id]) or 0
		local complete = done[id] == true
		r.Fill.Size = UDim2.fromScale(complete and 1 or math.clamp(v / r.Goal, 0, 1), 1)
		if complete then
			r.Count.Text = "DONE"
		elseif id == "SurviveTime" then
			r.Count.Text = ("%d:%02d / %d:%02d"):format(v // 60, v % 60, r.Goal // 60, r.Goal % 60)
		else
			r.Count.Text = ("%d / %d"):format(v, r.Goal)
		end
	end
	streakLabel.Text = ("Login streak: %d day%s — come back tomorrow for more coins"):format(
		player:GetAttribute("LoginStreak") or 0,
		(player:GetAttribute("LoginStreak") or 0) == 1 and "" or "s"
	)
	local tokens = player:GetAttribute("GuaranteedTokens") or 0
	local chance = player:GetAttribute("WolverineChance")
	if tokens > 0 then
		chanceLabel.Text = "Wolverine next round: GUARANTEED"
		chanceLabel.TextColor3 = YELLOW
	elseif chance then
		chanceLabel.Text = ("Wolverine chance: %d%%"):format(chance)
		chanceLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
	end
end

local function fit()
	local cam = workspace.CurrentCamera
	scale.Scale = math.max(0.4, math.min(1, (cam.ViewportSize.X - 24) / 460, (cam.ViewportSize.Y - 24) / 340))
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
fit()

dailyButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
	refresh()
end)
close.Activated:Connect(function()
	panel.Visible = false
end)
buyButton.Activated:Connect(function()
	if Config.GuaranteedWolverineProductId == 0 then
		chanceLabel.Text = "Purchase not set up yet (see Config)"
		return
	end
	MarketplaceService:PromptProductPurchase(player, Config.GuaranteedWolverineProductId)
end)

for _, attr in { "Challenges", "LoginStreak", "WolverineChance", "GuaranteedTokens" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
refresh()

function Daily.ShowReward(amount, streak)
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 170),
		BackgroundColor3 = DARK,
		ZIndex = 40,
	}, gui)
	corner(card, 14)
	new("UIStroke", { Color = YELLOW, Thickness = 3 }, card)
	new("TextLabel", {
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.new(1, -20, 0, 40),
		BackgroundTransparency = 1,
		Font = Enum.Font.LuckiestGuy,
		TextScaled = true,
		TextColor3 = YELLOW,
		Text = "DAILY REWARD",
		ZIndex = 41,
	}, card)
	new("TextLabel", {
		Position = UDim2.fromOffset(10, 58),
		Size = UDim2.new(1, -20, 0, 44),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = ("+%d coins"):format(amount),
		ZIndex = 41,
	}, card)
	new("TextLabel", {
		Position = UDim2.fromOffset(10, 108),
		Size = UDim2.new(1, -20, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = GREEN,
		Text = ("Day %d streak — bigger rewards every day you come back"):format(streak),
		ZIndex = 41,
	}, card)
	local ok = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(120, 28),
		BackgroundColor3 = Color3.fromRGB(40, 120, 60),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "NICE",
		ZIndex = 41,
	}, card)
	corner(ok, 8)
	ok.Activated:Connect(function()
		card:Destroy()
	end)
	task.delay(8, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

return Daily
