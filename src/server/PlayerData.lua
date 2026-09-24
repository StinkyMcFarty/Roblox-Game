-- Saved player data: coins, skins, daily challenges, login streak and
-- purchased "guaranteed Wolverine" tokens. Also handles the Robux purchase.
--
-- In Studio, turn on Game Settings > Security > "Enable Studio Access to
-- API Services" for saving to work there (the game still runs without it).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Skins = require(ReplicatedStorage.Shared.Skins)

local PlayerData = {}

local store
pcall(function()
	store = DataStoreService:GetDataStore("SurviveTheWolverine_v1")
end)

local cache = {}

local function today()
	return os.date("!%Y%m%d")
end

local function yesterday()
	return os.date("!%Y%m%d", os.time() - 86400)
end

local function fx(player, kind, data)
	ReplicatedStorage.Remotes.Fx:FireClient(player, kind, data)
end

local function freshDaily()
	return { Day = today(), Progress = {}, Done = {} }
end

local function publish(player)
	local d = cache[player]
	if not d then
		return
	end
	local owned = {}
	for id in d.Owned do
		table.insert(owned, id)
	end
	player:SetAttribute("OwnedSkins", table.concat(owned, ","))
	player:SetAttribute("Skin", d.Skin)
	local claws = {}
	for id in d.OwnedClaws do
		table.insert(claws, id)
	end
	player:SetAttribute("OwnedClaws", table.concat(claws, ","))
	player:SetAttribute("Claw", d.Claw)
	player:SetAttribute("GuaranteedTokens", d.Tokens)
	player:SetAttribute("LoginStreak", d.Streak)
	player:SetAttribute("Challenges", HttpService:JSONEncode(d.Daily))
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	if coins then
		coins.Value = d.Coins
	end
end

function PlayerData.Save(player)
	local d = cache[player]
	if not (d and store) then
		return
	end
	local owned = {}
	for id in d.Owned do
		table.insert(owned, id)
	end
	pcall(function()
		store:SetAsync("p_" .. player.UserId, {
			Coins = d.Coins,
			Owned = owned,
			Skin = d.Skin,
			OwnedClaws = (function()
				local list = {}
				for id in d.OwnedClaws do
					table.insert(list, id)
				end
				return list
			end)(),
			Claw = d.Claw,
			Tokens = d.Tokens,
			LastLogin = d.LastLogin,
			Streak = d.Streak,
			Daily = d.Daily,
		})
	end)
end

function PlayerData.AddCoins(player, amount, reason)
	local d = cache[player]
	if not d or amount <= 0 then
		return
	end
	d.Coins += amount
	publish(player)
	fx(player, "Coins", { Amount = amount, Reason = reason or "" })
end

local function checkDay(d)
	if d.Daily.Day ~= today() then
		d.Daily = freshDaily()
	end
end

function PlayerData.Load(player)
	local data = {
		Coins = 0,
		Owned = { [Skins.Default] = true },
		Skin = Skins.Default,
		OwnedClaws = { [Skins.DefaultClaw] = true },
		Claw = Skins.DefaultClaw,
		Tokens = 0,
		LastLogin = "",
		Streak = 0,
		Daily = freshDaily(),
		Pity = 0, -- rounds played in a row without being Wolverine (this session)
	}
	if store then
		local ok, saved = pcall(function()
			return store:GetAsync("p_" .. player.UserId)
		end)
		if ok and type(saved) == "table" then
			data.Coins = tonumber(saved.Coins) or 0
			for _, id in saved.Owned or {} do
				if Skins.List[id] then
					data.Owned[id] = true
				end
			end
			if saved.Skin and data.Owned[saved.Skin] then
				data.Skin = saved.Skin
			end
			for _, id in saved.OwnedClaws or {} do
				if Skins.Claws[id] then
					data.OwnedClaws[id] = true
				end
			end
			if saved.Claw and data.OwnedClaws[saved.Claw] then
				data.Claw = saved.Claw
			end
			data.Tokens = tonumber(saved.Tokens) or 0
			data.LastLogin = saved.LastLogin or ""
			data.Streak = tonumber(saved.Streak) or 0
			if type(saved.Daily) == "table" and saved.Daily.Day == today() then
				data.Daily = {
					Day = saved.Daily.Day,
					Progress = saved.Daily.Progress or {},
					Done = saved.Daily.Done or {},
				}
			end
		end
	end
	if not player.Parent then
		return
	end
	cache[player] = data
	publish(player)

	-- Daily login reward
	if data.LastLogin ~= today() then
		data.Streak = (data.LastLogin == yesterday()) and data.Streak + 1 or 1
		data.LastLogin = today()
		local r = Config.DailyReward
		local reward = r.Base + r.PerStreakDay * (math.min(data.Streak, r.MaxStreak) - 1)
		PlayerData.AddCoins(player, reward, ("Daily reward — day %d streak"):format(data.Streak))
		-- give the client a moment to load its UI before showing the popup
		task.delay(4, function()
			if player.Parent then
				fx(player, "DailyReward", { Amount = reward, Streak = data.Streak })
			end
		end)
		task.spawn(PlayerData.Save, player)
	end
end

---------------------------------------------------------------------------
-- Daily challenges
---------------------------------------------------------------------------

function PlayerData.Progress(player, id, amount)
	local d = cache[player]
	if not d then
		return
	end
	checkDay(d)
	local challenge
	for _, c in Config.DailyChallenges do
		if c.Id == id then
			challenge = c
		end
	end
	if not challenge or d.Daily.Done[id] then
		return
	end
	d.Daily.Progress[id] = math.min(challenge.Goal, (d.Daily.Progress[id] or 0) + amount)
	if d.Daily.Progress[id] >= challenge.Goal then
		d.Daily.Done[id] = true
		PlayerData.AddCoins(player, challenge.Reward, "Challenge: " .. challenge.Text)
		fx(player, "Announce", { Text = "CHALLENGE COMPLETE: " .. challenge.Text, Color = Color3.fromRGB(120, 255, 150), Duration = 3 })
	end
	publish(player)
end

---------------------------------------------------------------------------
-- Skins
---------------------------------------------------------------------------

function PlayerData.GetSkin(player)
	local d = cache[player]
	return d and d.Skin or Skins.Default
end

function PlayerData.GetClaw(player)
	local d = cache[player]
	return d and d.Claw or Skins.DefaultClaw
end

function PlayerData.BuyClaw(player, id)
	local d, claw = cache[player], Skins.Claws[id]
	if not (d and claw) then
		return false, "Unknown claws"
	end
	if d.OwnedClaws[id] then
		return false, "Already owned"
	end
	if d.Coins < claw.Price then
		return false, "Not enough coins"
	end
	d.Coins -= claw.Price
	d.OwnedClaws[id] = true
	d.Claw = id
	publish(player)
	task.spawn(PlayerData.Save, player)
	return true, "Unlocked " .. claw.Name .. "!"
end

function PlayerData.EquipClaw(player, id)
	local d = cache[player]
	if d and d.OwnedClaws[id] then
		d.Claw = id
		publish(player)
		return true, "Equipped " .. Skins.Claws[id].Name
	end
	return false, "You don't own those"
end

function PlayerData.Buy(player, id)
	local d, skin = cache[player], Skins.List[id]
	if not (d and skin) then
		return false, "Unknown skin"
	end
	if d.Owned[id] then
		return false, "Already owned"
	end
	if d.Coins < skin.Price then
		return false, "Not enough coins"
	end
	d.Coins -= skin.Price
	d.Owned[id] = true
	d.Skin = id
	publish(player)
	task.spawn(PlayerData.Save, player)
	return true, "Unlocked " .. skin.Name .. "!"
end

function PlayerData.Equip(player, id)
	local d = cache[player]
	if d and d.Owned[id] then
		d.Skin = id
		publish(player)
		return true, "Equipped " .. Skins.List[id].Name
	end
	return false, "You don't own that"
end

---------------------------------------------------------------------------
-- Choosing Wolverine: purchased tokens first, then weighted by play streak
---------------------------------------------------------------------------

local function weight(player)
	local d = cache[player]
	return 1 + (d and d.Pity or 0) * Config.WolverinePityWeight
end

function PlayerData.PublishChances()
	local list = Players:GetPlayers()
	local total = 0
	for _, p in list do
		total += weight(p)
	end
	for _, p in list do
		local d = cache[p]
		if d and d.Tokens > 0 then
			p:SetAttribute("WolverineChance", 100)
		else
			p:SetAttribute("WolverineChance", total > 0 and math.floor(weight(p) / total * 100 + 0.5) or 0)
		end
	end
end

function PlayerData.PickWolverine(list)
	-- A purchased token guarantees it (first buyer in the server goes first)
	for _, p in list do
		local d = cache[p]
		if d and d.Tokens > 0 then
			d.Tokens -= 1
			publish(p)
			task.spawn(PlayerData.Save, p)
			return p, true
		end
	end
	local total = 0
	for _, p in list do
		total += weight(p)
	end
	local roll = math.random() * total
	for _, p in list do
		roll -= weight(p)
		if roll <= 0 then
			return p, false
		end
	end
	return list[#list], false
end

-- Called once per round with everyone who played in it.
function PlayerData.RoundPlayed(list, wolverine)
	for _, p in list do
		local d = cache[p]
		if d then
			d.Pity = (p == wolverine) and 0 or d.Pity + 1
		end
	end
	PlayerData.PublishChances()
end

---------------------------------------------------------------------------
-- Robux: guaranteed Wolverine next round
---------------------------------------------------------------------------

local granted = {}
MarketplaceService.ProcessReceipt = function(receipt)
	if granted[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local d = player and cache[player]
	if not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if receipt.ProductId == Config.GuaranteedWolverineProductId then
		d.Tokens += 1
		granted[receipt.PurchaseId] = true
		publish(player)
		PlayerData.Save(player)
		PlayerData.PublishChances()
		fx(player, "Announce", { Text = "You WILL be Wolverine next round.", Color = Color3.fromRGB(255, 205, 30), Duration = 4 })
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

Players.PlayerRemoving:Connect(function(player)
	PlayerData.Save(player)
	cache[player] = nil
	task.defer(PlayerData.PublishChances)
end)

game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		PlayerData.Save(p)
	end
end)

return PlayerData
