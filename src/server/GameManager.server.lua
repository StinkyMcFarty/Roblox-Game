-- Round loop: intermission -> pick Wolverine -> survive -> results.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent
local Config = require(ReplicatedStorage.Shared.Config)
local Round = require(Server.Round)
local Status = require(Server.Status)
local Movement = require(Server.Movement)
local MapBuilder = require(Server.MapBuilder)
local Facility = require(Server.Facility)
local Costumes = require(Server.Costumes)
local Wolverine = require(Server.Wolverine)
local Sentinel = require(Server.Sentinel)
local PlayerData = require(Server.PlayerData)
local Fart = require(Server.Fart)
local Hiding = require(Server.Hiding)
local Bots = require(Server.Bots)
local Skins = require(ReplicatedStorage.Shared.Skins)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Fx = Remotes:WaitForChild("Fx")
local Ability = Remotes:WaitForChild("Ability")
local ShopRemote = Remotes:WaitForChild("Shop")
local R = Skins.Rewards

local RED = Color3.fromRGB(255, 60, 60)
local GOLD = Color3.fromRGB(255, 210, 60)
local GREEN = Color3.fromRGB(90, 255, 140)

Players.RespawnTime = 4
MapBuilder.SetupLighting()
MapBuilder.SetupTerrain()
local lobby = MapBuilder.BuildLobby()
task.defer(Facility.Build) -- pre-build the facility template during the first intermission

-- Lobby: statues, live status screen and leaderboard
task.spawn(function()
	for _, spot in lobby:WaitForChild("Pedestals"):GetChildren() do
		local id = spot:GetAttribute("Skin")
		Wolverine.MakeStatue(id, spot.CFrame, lobby)
		local skin = Skins.List[id]
		for _, d in lobby:GetDescendants() do
			if d.Name == "PlaqueText" and d.Text == id and skin then
				d.Text = skin.Name .. (skin.Price > 0 and ("\n" .. skin.Price .. " " .. Config.CoinName:upper()) or "   FREE")
			end
		end
	end
end)
task.spawn(function()
	local screen = lobby:WaitForChild("StatusScreen")
	local board = lobby:FindFirstChild("Leaderboard", true)
	local rows = board and board:FindFirstChild("Rows", true)
	while true do
		local status = ReplicatedStorage:GetAttribute("Status") or ""
		local ends = ReplicatedStorage:GetAttribute("TimerEnds") or 0
		local left = math.max(0, ends - workspace:GetServerTimeNow())
		local timer = ends > 0 and ("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60)) or "--:--"
		for _, d in screen:GetDescendants() do
			if d.Name == "StatusText" then
				d.Text = string.upper(status)
			elseif d.Name == "TimerText" then
				d.Text = timer
			end
		end
		if rows then
			local list = {}
			for _, p in Players:GetPlayers() do
				local ls = p:FindFirstChild("leaderstats")
				local kills = ls and ls:FindFirstChild("Kills") and ls.Kills.Value or 0
				local wins = ls and ls:FindFirstChild("Wins") and ls.Wins.Value or 0
				table.insert(list, { Name = p.DisplayName, Kills = kills, Wins = wins })
			end
			table.sort(list, function(a, b)
				return a.Kills * 2 + a.Wins > b.Kills * 2 + b.Wins
			end)
			for i = 1, 6 do
				local row = rows:FindFirstChild("Row" .. i)
				local e = list[i]
				if row then
					row.Text = e and ("%d.  %s   🩸%d  🏆%d"):format(i, e.Name, e.Kills, e.Wins) or ""
				end
			end
		end
		task.wait(0.5)
	end
end)

local function now()
	return workspace:GetServerTimeNow()
end

local function announce(text, color, duration)
	Fx:FireAllClients("Announce", { Text = text, Color = color or Color3.new(1, 1, 1), Duration = duration or 3 })
end

local function setStatus(text, endsAt)
	ReplicatedStorage:SetAttribute("Status", text)
	ReplicatedStorage:SetAttribute("TimerEnds", endsAt or 0)
end

local function stat(player, name, delta)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(name)
	if v then
		v.Value += delta
	end
end

-- Studio = testing (1 player + bots). Live game = real players only.
local TESTING = RunService:IsStudio()

local function minPlayers()
	return TESTING and 1 or Config.MinPlayers
end

-- Players who'll take part in the next match (AFK players sit it out)
local function activePlayers()
	local list = {}
	for _, p in Players:GetPlayers() do
		if not p:GetAttribute("AFK") then
			table.insert(list, p)
		end
	end
	return list
end

Remotes:WaitForChild("Afk").OnServerEvent:Connect(function(player, on)
	if type(on) ~= "boolean" then
		return
	end
	player:SetAttribute("AFK", on or nil)
	PlayerData.PublishChances()
end)

---------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------

local blockyDescription -- defined below; used by the lobby respawn handler

local function onPlayerAdded(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, name in { Config.CoinName, "Wins", "Kills" } do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = ls
	end
	ls.Parent = player
	player:SetAttribute("Role", "Lobby")
	player:SetAttribute("Stamina", 1)
	task.spawn(function()
		PlayerData.Load(player)
		PlayerData.PublishChances()
	end)

	-- lobby auto-spawns: turn them blocky once their avatar has loaded
	player.CharacterAppearanceLoaded:Connect(function(char)
		if player:GetAttribute("BlockyLoad") then
			player:SetAttribute("BlockyLoad", nil)
			return
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and not Round.Survivors[player] and Round.Wolverine ~= player then
			pcall(function()
				hum:ApplyDescription(blockyDescription(player))
			end)
		end
	end)
	player.CharacterAdded:Connect(function(char)
		if not Round.Survivors[player] and Round.Wolverine ~= player then
			player:SetAttribute("Role", "Lobby")
			player:SetAttribute("Hits", 0)
		end
		local hum = char:WaitForChild("Humanoid")
		hum.Died:Connect(function()
			Hiding.Clear(player)
			if Round.Survivors[player] then -- died some other way (fell, reset...)
				Round.Survivors[player] = nil
				player:SetAttribute("Role", "Dead")
				if Round.Active then
					Fx:FireAllClients("KillFeed", { Text = player.DisplayName .. " died" })
				end
			end
		end)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	Hiding.Clear(player)
	Round.Survivors[player] = nil
	Status.Reset(player)
	if player == Round.Wolverine then
		Round.WolverineLeft = true
	end
end)

Ability.OnServerEvent:Connect(function(player, name, arg)
	if typeof(name) ~= "string" then
		return
	end
	local role = player:GetAttribute("Role")
	if name == "Sprint" then
		Movement.SetInput(player, "Sprint", arg == true)
	elseif name == "Fart" then
		Fart.Use(player)
	elseif name == "Dodge" then
		Fart.Dodge(player)
	elseif name == "Vanish" then
		Fart.Vanish(player)
	elseif name == "Unhide" then
		Hiding.Leave(player)
	elseif name == "TerminalResult" then
		Sentinel.TerminalResult(player, arg)
	elseif name == "Spectate" then
		-- stream the map in around whoever they're watching (nil = themselves)
		local root = typeof(arg) == "Instance" and arg:IsA("Model") and arg:IsDescendantOf(workspace) and arg:FindFirstChild("HumanoidRootPart")
		player.ReplicationFocus = root or nil
	elseif role == "Wolverine" then
		Wolverine.Handle(player, name, arg)
	elseif role == "Sentinel" then
		Sentinel.Handle(player, name, arg)
	end
end)

ShopRemote.OnServerInvoke = function(player, action, id)
	if typeof(action) ~= "string" or typeof(id) ~= "string" then
		return false, "Bad request"
	end
	if action == "Buy" then
		return PlayerData.Buy(player, id)
	elseif action == "Equip" then
		return PlayerData.Equip(player, id)
	elseif action == "BuyClaw" then
		return PlayerData.BuyClaw(player, id)
	elseif action == "EquipClaw" then
		return PlayerData.EquipClaw(player, id)
	elseif action == "BuySentinel" then
		return PlayerData.BuySentinel(player, id)
	elseif action == "EquipSentinel" then
		return PlayerData.EquipSentinel(player, id)
	elseif action == "BuyUpgrade" then
		return PlayerData.BuyUpgrade(player, id)
	elseif action == "EquipUpgrade" then
		return PlayerData.EquipUpgrade(player, id)
	elseif action == "Brightness" then
		return PlayerData.SetBrightness(player, tonumber(id))
	end
	return false, "Bad request"
end

---------------------------------------------------------------------------
-- Round
---------------------------------------------------------------------------

local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

-- Everyone plays on the classic blocky body (their own clothes, colours, face
-- and accessories stay; bundle body parts and scaling are removed).
local descCache = {}
blockyDescription = function(p)
	local d = descCache[p]
	if not d then
		local ok, base = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(math.max(1, p.UserId))
		end)
		d = ok and base or Instance.new("HumanoidDescription")
		for _, k in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
			d[k] = 0
		end
		d.HeightScale, d.WidthScale, d.DepthScale, d.HeadScale = 1, 1, 1, 1
		d.BodyTypeScale, d.ProportionScale = 0, 0
		descCache[p] = d
	end
	return d:Clone()
end
Players.PlayerRemoving:Connect(function(p)
	descCache[p] = nil
end)
local function loadBlocky(p)
	p:SetAttribute("BlockyLoad", true)
	local ok = pcall(function()
		p:LoadCharacterWithHumanoidDescription(blockyDescription(p))
	end)
	if not ok then
		p:SetAttribute("BlockyLoad", nil)
		p:LoadCharacter()
	end
end

local function runRound()
	local list = activePlayers()
	if #list < minPlayers() then
		return
	end

	setStatus("Building the facility...")
	local map = Facility.Build()
	Round.Map = map
	Round.Active = true
	Round.Released = false
	Round.WolverineDead = false
	Round.WolverineKiller = nil
	Round.WolverineLeft = false
	Round.Survivors = {}
	ReplicatedStorage:SetAttribute("Released", false)
	ReplicatedStorage:SetAttribute("InRound", true)

	local wolverine, bought = PlayerData.PickWolverine(list)
	Round.Wolverine = wolverine
	ReplicatedStorage:SetAttribute("Wolverine", wolverine.Name)

	for _, p in list do
		Status.Reset(p)
		Movement.Reset(p)
		Fart.Reset(p)
		p:SetAttribute("Hits", 0)
		p:SetAttribute("Armor", nil)
		p:SetAttribute("SuitEnds", nil)
		if p ~= wolverine then
			Round.Survivors[p] = true
		end
	end

	local spawns = shuffle(map:WaitForChild("Spawns"):GetChildren())
	local wolverineSpawn = map:WaitForChild("WolverineSpawn").CFrame
	for i, p in list do
		loadBlocky(p)
		local char = p.Character
		if char then
			if p == wolverine then
				task.spawn(Wolverine.Transform, p, wolverineSpawn)
			else
				p:SetAttribute("Role", "Survivor")
				local spot = spawns[(i - 1) % #spawns + 1]
				char:PivotTo(spot.CFrame + Vector3.new(0, 3, 0))
				task.spawn(function()
					char:WaitForChild("UpperTorso", 5)
					pcall(Costumes.DressScientist, char)
				end)
			end
		end
	end

	Sentinel.SetupRound(map)
	Hiding.SetupRound(map)
	if TESTING then
		Bots.Fill(Config.BotFill, spawns)
	end
	-- for Wolverine's objective (client/Objectives): kills out of the
	-- survivors who started the round
	local survivorCount = 0
	for _ in Round.Survivors do
		survivorCount += 1
	end
	ReplicatedStorage:SetAttribute("SurvivorsTotal", survivorCount)
	ReplicatedStorage:SetAttribute("Kills", 0)
	announce(wolverine.DisplayName .. " is WOLVERINE!" .. (bought and "  (guaranteed pass)" or ""), RED, 4)
	PlayerData.Progress(wolverine, "BecomeWolverine", 1)
	Round.EndTime = os.clock() + Config.IntroLength + Config.RoundTime

	local killConn = Round.Killed:Connect(function(victim, killer)
		ReplicatedStorage:SetAttribute("Kills", (ReplicatedStorage:GetAttribute("Kills") or 0) + 1)
		Round.EndTime += Config.KillTimeBonus
		stat(killer, "Kills", 1)
		PlayerData.AddCoins(killer, R.Kill, "Kill")
		PlayerData.Progress(killer, "WolverineKills", 1)
		Fx:FireAllClients("KillFeed", {
			Text = ("%s ripped %s in half  +%ds"):format(killer.DisplayName, victim.DisplayName, Config.KillTimeBonus),
		})
		Fx:FireAllClients("TimeBonus", { Seconds = Config.KillTimeBonus })
	end)

	local result
	local surviveClock = os.clock()
	while true do
		if Round.Released and os.clock() - surviveClock >= 1 then
			surviveClock = os.clock()
			for p in Round.Survivors do
				PlayerData.Progress(p, "SurviveTime", 1)
			end
		elseif not Round.Released then
			surviveClock = os.clock()
		end
		local remaining = Round.EndTime - os.clock()
		setStatus(Round.Released and "SURVIVE" or "Wolverine is waking up...", now() + remaining)
		if Round.WolverineLeft then
			result = "left"
			break
		elseif Round.WolverineDead then
			result = "slain"
			break
		elseif next(Round.Survivors) == nil then
			task.wait(2.5) -- let the last kill play out
			result = "wolverine"
			break
		elseif remaining <= 0 then
			result = "survivors"
			break
		end
		task.wait(0.2)
	end
	killConn:Disconnect()

	Round.Active = false
	Round.Released = false
	ReplicatedStorage:SetAttribute("Released", false)

	local sentinelPlayer
	for p in Round.Survivors do
		if p:GetAttribute("Role") == "Sentinel" then
			sentinelPlayer = p
		end
	end

	if result == "wolverine" then
		announce("WOLVERINE WINS — nobody survived", RED, 5)
		if wolverine.Parent then
			stat(wolverine, "Wins", 1)
			PlayerData.AddCoins(wolverine, R.WolverineWin, "Wolverine victory")
		end
	else
		if result == "survivors" then
			announce("SURVIVORS WIN — you outlasted Wolverine", GREEN, 5)
		elseif result == "slain" then
			announce("THE SENTINEL BROUGHT WOLVERINE DOWN!", GOLD, 5)
		else
			announce("Wolverine left — survivors win", GREEN, 5)
		end
		for p in Round.Survivors do
			stat(p, "Wins", 1)
			PlayerData.AddCoins(p, R.Survive, "Survived")
		end
		local slayer = Round.WolverineKiller
		if not (slayer and slayer.Parent) then
			slayer = sentinelPlayer
		end
		if result == "slain" and slayer then
			PlayerData.AddCoins(slayer, R.SentinelTakedown, "Took down Wolverine")
		end
	end
	for _, p in list do
		if p.Parent then
			if p ~= wolverine and not Round.Survivors[p] then
				PlayerData.AddCoins(p, R.Died, "Played a match")
			end
			PlayerData.Progress(p, "PlayMatches", 1)
		end
	end
	PlayerData.RoundPlayed(list, wolverine)
	setStatus("Round over", now() + Config.EndScreenTime)
	task.wait(Config.EndScreenTime)

	Bots.Clear()
	Round.Wolverine = nil
	Round.Survivors = {}
	ReplicatedStorage:SetAttribute("Wolverine", nil)
	ReplicatedStorage:SetAttribute("InRound", false)
	ReplicatedStorage:SetAttribute("SurvivorsTotal", nil)
	ReplicatedStorage:SetAttribute("Kills", nil)
	for _, p in Players:GetPlayers() do
		Hiding.Clear(p)
		p.ReplicationFocus = nil -- stop following whoever they spectated
		p:SetAttribute("Role", "Lobby")
		p:SetAttribute("Hits", 0)
		p:SetAttribute("Armor", nil)
		p:SetAttribute("SuitEnds", nil)
		Status.Reset(p)
		Movement.Reset(p)
		task.spawn(function()
			loadBlocky(p)
		end)
	end
end

while true do
	ReplicatedStorage:SetAttribute("InRound", false)
	while #activePlayers() < minPlayers() do
		local afk = #Players:GetPlayers() - #activePlayers()
		setStatus(("Waiting for players (%d/%d)%s"):format(#activePlayers(), minPlayers(), afk > 0 and ("  •  %d AFK"):format(afk) or ""))
		task.wait(1)
	end
	local ends = now() + Config.IntermissionTime
	setStatus("Intermission", ends)
	local ok = true
	while now() < ends do
		task.wait(0.25)
		if #activePlayers() < minPlayers() then
			ok = false
			break
		end
	end
	if ok then
		local success, err = pcall(runRound)
		if not success then
			warn("Round crashed:", err)
			pcall(Bots.Clear)
			Round.Active = false
			Round.Wolverine = nil
			Round.Survivors = {}
			for _, p in Players:GetPlayers() do
				p:SetAttribute("Role", "Lobby")
				task.spawn(function()
					loadBlocky(p)
				end)
			end
			task.wait(3)
		end
	end
end
