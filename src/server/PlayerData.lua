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

local DAY = 24 * 60 * 60 -- dailies and the login reward run on a rolling 24 hours

local function freshDaily()
	return { Started = os.time(), Progress = {}, Done = {} }
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
	local suits = {}
	for id in d.OwnedSentinels do
		table.insert(suits, id)
	end
	player:SetAttribute("OwnedSentinels", table.concat(suits, ","))
	player:SetAttribute("SentinelSkin", d.SentinelSkin)
	local ups = {}
	for id in d.Upgrades do
		table.insert(ups, id)
	end
	player:SetAttribute("Upgrades", table.concat(ups, ","))
	player:SetAttribute("Power", d.Power)
	player:SetAttribute("GuaranteedTokens", d.Tokens)
	player:SetAttribute("LoginStreak", d.Streak)
	player:SetAttribute("Challenges", HttpService:JSONEncode(d.Daily))
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild(Config.CoinName)
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
	local ok = pcall(function()
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
			OwnedSentinels = (function()
				local list = {}
				for id in d.OwnedSentinels do
					table.insert(list, id)
				end
				return list
			end)(),
			SentinelSkin = d.SentinelSkin,
			Upgrades = (function()
				local list = {}
				for id in d.Upgrades do
					table.insert(list, id)
				end
				return list
			end)(),
			Power = d.Power,
			Tokens = d.Tokens,
			LastLogin = d.LastLogin,
			LastClaim = d.LastClaim,
			Streak = d.Streak,
			Daily = d.Daily,
			Receipts = d.Receipts,
		})
	end)
	return ok
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
	if os.time() - (d.Daily.Started or 0) >= DAY then
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
		OwnedSentinels = { [Skins.DefaultSentinel] = true },
		SentinelSkin = Skins.DefaultSentinel,
		Upgrades = {}, -- [id] = true, survivor upgrades (Config.Upgrades)
		Power = "", -- the one upgrade equipped on G ("" = the plain fart)
		Tokens = 0,
		LastLogin = "",
		LastClaim = 0, -- os.time() of the last daily login reward
		Streak = 0,
		Daily = freshDaily(),
		Pity = 0, -- rounds played in a row without being Wolverine (this session)
		Receipts = {}, -- recent Robux PurchaseIds already granted (never grant twice)
	}
	if store then
		local ok, saved = pcall(function()
			return store:GetAsync("p_" .. player.UserId)
		end)
		if not ok and tostring(saved):find("StudioAccessToApisNotAllowed") then
			-- Studio without API access: play without saving instead of erroring
			store = nil
			print("[PlayerData] Saving is off in Studio. To test saving: Game Settings > Security > Enable Studio Access to API Services. The live game saves normally.")
		end
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
			for _, id in saved.OwnedSentinels or {} do
				if Skins.Sentinels[id] then
					data.OwnedSentinels[id] = true
				end
			end
			if saved.SentinelSkin and data.OwnedSentinels[saved.SentinelSkin] then
				data.SentinelSkin = saved.SentinelSkin
			end
			for _, id in saved.Upgrades or {} do
				if Config.Upgrades[id] then
					data.Upgrades[id] = true
				end
			end
			if type(saved.Power) == "string" then
				if data.Upgrades[saved.Power] then
					data.Power = saved.Power
				end
			elseif data.Upgrades.TurboFart then
				data.Power = "TurboFart" -- bought before powers had to be picked
			end
			data.Tokens = tonumber(saved.Tokens) or 0
			if type(saved.Receipts) == "table" then
				for _, id in saved.Receipts do
					if type(id) == "string" then
						table.insert(data.Receipts, id)
					end
				end
			end
			data.LastLogin = saved.LastLogin or ""
			data.LastClaim = tonumber(saved.LastClaim) or 0
			data.Streak = tonumber(saved.Streak) or 0
			if type(saved.Daily) == "table" and os.time() - (tonumber(saved.Daily.Started) or 0) < DAY then
				data.Daily = {
					Started = tonumber(saved.Daily.Started),
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
	task.spawn(PlayerData.CheckPasses, player)

	-- Daily login reward
	local since = os.time() - data.LastClaim
	if since >= DAY then
		-- claimed again within 48 hours keeps the streak going
		data.Streak = (since < DAY * 2) and data.Streak + 1 or 1
		data.LastClaim = os.time()
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
		return false, "Not enough " .. Config.CoinName
	end
	d.Coins -= claw.Price
	d.OwnedClaws[id] = true
	d.Claw = id
	publish(player)
	task.spawn(PlayerData.Save, player)
	return true, "Unlocked " .. claw.Name .. "!"
end

function PlayerData.GetSentinelSkin(player)
	local d = cache[player]
	return d and d.SentinelSkin or Skins.DefaultSentinel
end

function PlayerData.BuySentinel(player, id)
	local d, suit = cache[player], Skins.Sentinels[id]
	if not (d and suit) then
		return false, "Unknown suit"
	end
	if d.OwnedSentinels[id] then
		return false, "Already owned"
	end
	if d.Coins < suit.Price then
		return false, "Not enough " .. Config.CoinName
	end
	d.Coins -= suit.Price
	d.OwnedSentinels[id] = true
	d.SentinelSkin = id
	publish(player)
	task.spawn(PlayerData.Save, player)
	return true, "Unlocked " .. suit.Name .. "!"
end

function PlayerData.EquipSentinel(player, id)
	local d = cache[player]
	local suit = Skins.Sentinels[id]
	if d and suit and suit.Price == 0 then
		d.OwnedSentinels[id] = true -- free suits are always yours
	end
	if d and d.OwnedSentinels[id] then
		d.SentinelSkin = id
		publish(player)
		return true, "Equipped " .. Skins.Sentinels[id].Name
	end
	return false, "You don't own that suit"
end

function PlayerData.HasUpgrade(player, id)
	local d = cache[player]
	return d ~= nil and d.Upgrades[id] == true
end

-- The upgrade this survivor has equipped on G ("" = none, the plain fart).
function PlayerData.Power(player)
	local d = cache[player]
	return d and d.Power or ""
end

-- Equip an owned upgrade as the G power (only one at a time); equipping the
-- one already on unequips it.
function PlayerData.EquipUpgrade(player, id)
	local d = cache[player]
	if not (d and d.Upgrades[id]) then
		return false, "You don't own that"
	end
	if d.Power == id then
		d.Power = ""
		publish(player)
		return true, Config.Upgrades[id].Name .. " off: G is a plain fart"
	end
	d.Power = id
	publish(player)
	return true, Config.Upgrades[id].Name .. " equipped on G"
end

function PlayerData.BuyUpgrade(player, id)
	local d, up = cache[player], Config.Upgrades[id]
	if not (d and up) then
		return false, "Unknown upgrade"
	end
	if d.Upgrades[id] then
		return false, "Already owned"
	end
	if d.Coins < up.Price then
		return false, "Not enough " .. Config.CoinName
	end
	d.Coins -= up.Price
	d.Upgrades[id] = true
	d.Power = id -- a new power goes straight on G
	publish(player)
	task.spawn(PlayerData.Save, player)
	return true, "Unlocked " .. up.Name .. "! Equipped on G"
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
		return false, "Not enough " .. Config.CoinName
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
	local w = 1 + (d and d.Pity or 0) * Config.WolverinePityWeight
	if player:GetAttribute("DoubleChance") then
		w *= 2 -- 2x Wolverine chance game pass
	end
	return w
end

-- 2x chance game pass: checked on join, granted instantly when bought in-game
function PlayerData.CheckPasses(player)
	local id = Config.DoubleChanceGamepassId
	if id == 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	if ok and owns and player.Parent then
		player:SetAttribute("DoubleChance", true)
		PlayerData.PublishChances()
	end
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == Config.DoubleChanceGamepassId and Config.DoubleChanceGamepassId ~= 0 then
		player:SetAttribute("DoubleChance", true)
		PlayerData.PublishChances()
		fx(player, "Announce", { Text = "2X WOLVERINE CHANCE unlocked!", Color = Color3.fromRGB(255, 205, 30), Duration = 4 })
	end
end)

function PlayerData.PublishChances()
	local list = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("AFK") then
			p:SetAttribute("WolverineChance", 0) -- sitting out
		else
			table.insert(list, p)
		end
	end
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

-- Every grant is recorded in the player's save (Receipts) before we tell
-- Roblox it's done, so a purchase can never be given twice or lost.
local function alreadyGranted(d, purchaseId)
	for _, id in d.Receipts do
		if id == purchaseId then
			return true
		end
	end
	return false
end

local function packFor(productId)
	for _, pack in Config.CoinPacks do
		if pack.ProductId ~= 0 and pack.ProductId == productId then
			return pack
		end
	end
	return nil
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local d = player and cache[player]
	if not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if alreadyGranted(d, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local pack = packFor(receipt.ProductId)
	local isToken = receipt.ProductId == Config.GuaranteedWolverineProductId and Config.GuaranteedWolverineProductId ~= 0
	if not (pack or isToken) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- apply, record, save; undo if the save fails so Roblox retries later
	local before = { Coins = d.Coins, Tokens = d.Tokens }
	if pack then
		d.Coins += pack.Coins
	else
		d.Tokens += 1
	end
	table.insert(d.Receipts, purchaseId)
	while #d.Receipts > 60 do
		table.remove(d.Receipts, 1)
	end
	if store and not PlayerData.Save(player) then
		d.Coins, d.Tokens = before.Coins, before.Tokens
		table.remove(d.Receipts)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	publish(player)
	if pack then
		fx(player, "Coins", { Amount = pack.Coins, Reason = pack.Name })
		fx(player, "Announce", { Text = ("+%d %s — thanks for the support!"):format(pack.Coins, Config.CoinName:upper()), Color = Color3.fromRGB(255, 205, 30), Duration = 3 })
	else
		PlayerData.PublishChances()
		fx(player, "Announce", { Text = "You WILL be Wolverine next round.", Color = Color3.fromRGB(255, 205, 30), Duration = 4 })
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
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
