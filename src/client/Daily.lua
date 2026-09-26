-- Daily challenges, login streak, Wolverine odds and Become Wolverine.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local Shop = require(script.Parent:WaitForChild("Shop"))

local player = Players.LocalPlayer
local Daily = {}

local new, corner, stroke, gradient = UIKit.new, UIKit.Corner, UIKit.Stroke, UIKit.Gradient
local K = UIKit.Colors

local gui = new("ScreenGui", { Name = "DailyUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

local dailyButton = Shop.DockButton("DAILY", "🎁", K.Green, 2)
local buyButton, buyLabel = Shop.DockButton("BECOME WOLVERINE", "👑", K.Red, 3)
-- no price on the button: Roblox's purchase prompt shows the real one
local BUY_TEXT = "BECOME WOLVERINE"
buyLabel.Text = BUY_TEXT

-- Wolverine odds pill
local odds = new("Frame", { Size = UDim2.fromOffset(170, 46), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 4 }, Shop.Dock)
corner(odds, 12)
gradient(odds, Color3.fromRGB(50, 16, 18), Color3.fromRGB(18, 8, 10))
local oddsStroke = stroke(odds, Color3.fromRGB(140, 30, 30), 2)
new("TextLabel", {
	Position = UDim2.fromOffset(10, 4),
	Size = UDim2.new(1, -20, 0, 14),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(220, 170, 170),
	Text = "WOLVERINE CHANCE",
}, odds)
local oddsBar = new("Frame", { Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -20, 0, 14), BackgroundColor3 = K.Ink }, odds)
corner(oddsBar, 7)
local oddsFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, oddsBar)
corner(oddsFill, 7)
gradient(oddsFill, Color3.fromRGB(255, 90, 60), Color3.fromRGB(180, 20, 20), 0)
local oddsText = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = K.White,
	Text = "",
	ZIndex = 2,
}, oddsBar)
new("UIStroke", { Thickness = 1.5 }, oddsText)

---------------------------------------------------------------------------
-- Challenges window
---------------------------------------------------------------------------

local window = UIKit.Window(gui, "DAILY CHALLENGES", UDim2.fromOffset(520, 436), K.Green)
local w = window.Frame

-- everyone's dailies reset together at 00:00 UTC (server clock)
local resetText = new("TextLabel", {
	Position = UDim2.fromOffset(20, 66),
	Size = UDim2.new(1, -40, 0, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(170, 235, 190),
	Text = "",
	ZIndex = 31,
}, w)

local list = new("Frame", { Position = UDim2.fromOffset(20, 100), Size = UDim2.new(1, -40, 0, 260), BackgroundTransparency = 1, ZIndex = 31 }, w)
new("UIListLayout", { Padding = UDim.new(0, 10) }, list)

local streak = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.new(1, -40, 0, 40),
	BackgroundColor3 = Color3.new(1, 1, 1),
	ZIndex = 31,
}, w)
corner(streak, 10)
gradient(streak, Color3.fromRGB(70, 54, 10), Color3.fromRGB(28, 22, 6), 0)
stroke(streak, K.Yellow, 1.5, 0.3)
local streakText = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = K.Yellow,
	Text = "",
	ZIndex = 32,
}, streak)
new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, streakText)

local ICONS = { BecomeWolverine = "🐺", WolverineKills = "🩸", SurviveTime = "⏱️", PlayMatches = "🎮" }
local rows = {}
for i, c in Config.DailyChallenges do
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, ZIndex = 32 }, list)
	corner(row, 12)
	gradient(row, Color3.fromRGB(42, 42, 50), Color3.fromRGB(22, 22, 28), 0)
	local rowStroke = stroke(row, Color3.fromRGB(70, 70, 80), 1.5)
	local tile = new("TextLabel", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Color3.fromRGB(20, 40, 26),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		Text = ICONS[c.Id] or "★",
		ZIndex = 33,
	}, row)
	corner(tile, 10)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, tile)
	new("TextLabel", {
		Position = UDim2.fromOffset(58, 6),
		Size = UDim2.new(1, -170, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = K.White,
		Text = c.Text,
		ZIndex = 33,
	}, row)
	local reward = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(100, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = K.Yellow,
		Text = "",
		ZIndex = 33,
	}, row)
	UIKit.CoinText(reward, tostring(c.Reward))
	local bar = new("Frame", { Position = UDim2.fromOffset(58, 32), Size = UDim2.new(1, -68, 0, 14), BackgroundColor3 = K.Ink, ZIndex = 33 }, row)
	corner(bar, 7)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 34 }, bar)
	corner(fill, 7)
	gradient(fill, Color3.fromRGB(120, 255, 150), Color3.fromRGB(30, 160, 70), 0)
	local count = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = K.White,
		Text = "",
		ZIndex = 35,
	}, bar)
	new("UIStroke", { Thickness = 1.5 }, count)
	rows[c.Id] = { Fill = fill, Count = count, Goal = c.Goal, Stroke = rowStroke, Reward = reward, Tile = tile }
end

local DAY = 24 * 60 * 60
-- coins for a login on streak day n (same formula as PlayerData.LoginReward)
local function loginReward(n)
	local r = Config.DailyReward
	return r.Base + r.PerStreakDay * (math.clamp(n, 1, r.MaxStreak) - 1)
end

local function showReset()
	local left = math.max(0, DAY - math.floor(workspace:GetServerTimeNow()) % DAY)
	resetText.Text = ("⏱ NEW CHALLENGES + LOGIN REWARD IN %dh %02dm %02ds"):format(left // 3600, left % 3600 // 60, left % 60)
end
task.spawn(function()
	while true do
		if w.Visible then
			showReset()
		end
		task.wait(0.5)
	end
end)

local function refresh()
	local ok, data = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Challenges") or "{}")
	end)
	local progress = (ok and type(data) == "table" and type(data.Progress) == "table") and data.Progress or {}
	local done = (ok and type(data) == "table" and type(data.Done) == "table") and data.Done or {}
	for id, r in rows do
		local v = tonumber(progress[id]) or 0
		local complete = done[id] == true
		TweenService:Create(r.Fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
			Size = UDim2.fromScale(complete and 1 or math.clamp(v / r.Goal, 0, 1), 1),
		}):Play()
		r.Stroke.Color = complete and K.Green or Color3.fromRGB(70, 70, 80)
		r.Tile.BackgroundColor3 = complete and Color3.fromRGB(30, 110, 50) or Color3.fromRGB(20, 40, 26)
		r.Reward.Text = complete and "✔ CLAIMED" or r.Reward.Text:gsub("✔ CLAIMED", "")
		if complete then
			r.Count.Text = "COMPLETE"
		elseif id == "SurviveTime" then
			r.Count.Text = ("%d:%02d / %d:%02d"):format(v // 60, v % 60, r.Goal // 60, r.Goal % 60)
		else
			r.Count.Text = ("%d / %d"):format(v, r.Goal)
		end
	end
	local s = player:GetAttribute("LoginStreak") or 0
	streakText.Text = ("🔥 LOGIN STREAK: DAY %d — TOMORROW +%d COINS"):format(math.max(s, 1), loginReward(s + 1))

	local tokens = player:GetAttribute("GuaranteedTokens") or 0
	local chance = player:GetAttribute("WolverineChance") or 0
	local place = player:GetAttribute("WolverineQueue") or 1
	if tokens > 0 and place > 1 then
		oddsText.Text = ("IN QUEUE #%d"):format(place) -- someone else goes first
		oddsFill.Size = UDim2.fromScale(1, 1)
		oddsStroke.Color = K.Yellow
	elseif tokens > 0 then
		oddsText.Text = "GUARANTEED"
		oddsFill.Size = UDim2.fromScale(1, 1)
		oddsStroke.Color = K.Yellow
	else
		oddsText.Text = chance .. "%"
		TweenService:Create(oddsFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(chance / 100, 0.04, 1), 1) }):Play()
		oddsStroke.Color = Color3.fromRGB(140, 30, 30)
	end
end

dailyButton.Activated:Connect(function()
	refresh()
	showReset()
	window.Toggle()
end)
buyButton.Activated:Connect(function()
	local id = Config.ProductId("Wolverine", Config.GuaranteedWolverineProductId)
	if id == 0 then
		buyLabel.Text = "NOT SET UP"
		task.delay(2, function()
			buyLabel.Text = BUY_TEXT
		end)
		return
	end
	MarketplaceService:PromptProductPurchase(player, id)
end)


for _, attr in { "Challenges", "LoginStreak", "WolverineChance", "GuaranteedTokens", "WolverineQueue" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
refresh()

function Daily.ShowReward(amount, days)
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 230),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 40,
	}, gui)
	corner(holder, 18)
	gradient(holder, Color3.fromRGB(60, 46, 12), Color3.fromRGB(18, 14, 6))
	stroke(holder, K.Yellow, 3)
	local scale = new("UIScale", { Scale = 0.5 }, holder)
	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	-- rotating rays behind the coin
	local rays = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(160, 160),
		BackgroundTransparency = 1,
		ZIndex = 41,
	}, holder)
	for i = 0, 5 do
		local ray = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(18, 160),
			Rotation = i * 30,
			BackgroundColor3 = K.Yellow,
			BackgroundTransparency = 0.75,
			ZIndex = 41,
		}, rays)
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, ray)
	end
	TweenService:Create(rays, TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()

	local title = new("TextLabel", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 40),
		BackgroundTransparency = 1,
		Font = Enum.Font.LuckiestGuy,
		TextScaled = true,
		TextColor3 = K.Yellow,
		Text = "DAILY REWARD",
		ZIndex = 43,
	}, holder)
	new("UIStroke", { Thickness = 2.5 }, title)
	local amountLabel = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(300, 56),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = K.White,
		Text = "",
		ZIndex = 43,
	}, holder)
	UIKit.CoinText(amountLabel, "+" .. amount)
	new("UIStroke", { Thickness = 2.5 }, amountLabel)
	new("TextLabel", {
		Position = UDim2.new(0, 10, 1, -86),
		Size = UDim2.new(1, -20, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = K.Green,
		Text = days >= Config.DailyReward.MaxStreak and ("🔥 Day %d streak — max reward! Log in daily to keep it"):format(days)
			or ("🔥 Day %d streak — tomorrow +%d coins"):format(days, loginReward(days + 1)),
		ZIndex = 43,
	}, holder)
	local ok = UIKit.Button(holder, {
		Text = "COLLECT",
		Color = K.Green,
		Size = UDim2.fromOffset(170, 44),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		ZIndex = 44,
	})
	local function close()
		local tw = TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 0.6 })
		tw:Play()
		tw.Completed:Wait()
		holder:Destroy()
	end
	ok.Activated:Connect(close)
	task.delay(10, function()
		if holder.Parent then
			close()
		end
	end)
end

return Daily
