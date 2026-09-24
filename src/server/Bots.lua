-- Bot survivors so a round is playable with only 1-2 real players.
-- A bot is a small table that looks enough like a Player for the rest of
-- the game (Character, Name, DisplayName, Get/SetAttribute).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Round = require(script.Parent.Round)
local Status = require(script.Parent.Status)
local Costumes = require(script.Parent.Costumes)

local Bots = {}

local Bot = {}
Bot.__index = Bot
Bot.IsBot = true
Bot.UserId = 0

function Bot:GetAttribute(key)
	return self.Character and self.Character:GetAttribute(key)
end

function Bot:SetAttribute(key, value)
	if self.Character then
		self.Character:SetAttribute(key, value)
	end
end

function Bot:FindFirstChild()
	return nil
end

local NAMES = { "Scott", "Jean", "Rogue", "Jubilee", "Kitty", "Bobby", "Remy", "Ororo", "Hank", "Kurt", "Piotr", "Warren" }
local SHIRTS = {
	Color3.fromRGB(160, 40, 40), Color3.fromRGB(40, 80, 160), Color3.fromRGB(60, 120, 60),
	Color3.fromRGB(200, 160, 40), Color3.fromRGB(110, 60, 150), Color3.fromRGB(80, 80, 85),
}
local SKIN = { Color3.fromRGB(234, 184, 146), Color3.fromRGB(204, 142, 105), Color3.fromRGB(124, 84, 60), Color3.fromRGB(255, 204, 170) }

local active = {} -- list of bots this round

local function makeModel(index)
	local desc = Instance.new("HumanoidDescription")
	local skin = SKIN[math.random(#SKIN)]
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	local shirt = SHIRTS[math.random(#SHIRTS)]
	desc.TorsoColor = shirt
	desc.LeftLegColor = Color3.fromRGB(45, 50, 70)
	desc.RightLegColor = Color3.fromRGB(45, 50, 70)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("Could not create bot:", model)
		return nil
	end
	model.Name = NAMES[(index - 1) % #NAMES + 1] .. " (bot)"
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	hum.NameDisplayDistance = 40
	hum.MaxHealth = 100
	hum.Health = 100
	return model
end

-- wander between the facility's rooms (spawn points sit in every wing)
local function randomPoint()
	local spawns = Round.Map and Round.Map:FindFirstChild("Spawns")
	local list = spawns and spawns:GetChildren() or {}
	if #list > 0 then
		return list[math.random(#list)].Position + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
	end
	return Vector3.new(math.random(-100, 100), 3, math.random(-100, 100))
end

local function think(bot)
	local char = bot.Character
	local hum, root = Util.Humanoid(char), Util.Root(char)
	if not (hum and root) or hum.Health <= 0 or not Round.Survivors[bot] then
		return
	end
	if root.Anchored or Status.Has(bot, "Frozen") or Status.Has(bot, "Busy") then
		hum.WalkSpeed = 0
		return
	end

	local w = Round.Wolverine
	local wRoot = w and Util.Root(w.Character)
	local dist = wRoot and (wRoot.Position - root.Position).Magnitude or math.huge
	local boost = Status.Has(bot, "Boost") and Config.AdrenalineBonus or 0

	if Round.Released and dist < 70 then
		-- Flee: away from him, with some sideways panic so they aren't a straight line
		local away = Util.Flat(root.Position - wRoot.Position)
		local side = away:Cross(Vector3.yAxis) * (bot.Dodge or 1)
		local target = root.Position + away * 30 + side * math.random(5, 15)
		target = Vector3.new(math.clamp(target.X, -170, 170), root.Position.Y, math.clamp(target.Z, -170, 170))
		hum.WalkSpeed = (dist < 40 and Config.Survivor.SprintSpeed - 2 or Config.Survivor.WalkSpeed) + boost
		hum:MoveTo(target)
		char:SetAttribute("Sprinting", dist < 40)
		if math.random() < 0.08 then
			bot.Dodge = -(bot.Dodge or 1)
		end
	else
		char:SetAttribute("Sprinting", false)
		hum.WalkSpeed = Config.Survivor.WalkSpeed - 2 + boost
		local toGoal = bot.Goal and Vector3.new(bot.Goal.X - root.Position.X, 0, bot.Goal.Z - root.Position.Z).Magnitude or 0
		if not bot.Goal or toGoal < 4 or os.clock() > (bot.GoalUntil or 0) then
			bot.Goal = randomPoint()
			bot.GoalUntil = os.clock() + math.random(6, 12)
		end
		hum:MoveTo(bot.Goal)
	end

	-- Unstick: hop if we are trying to move but not going anywhere
	local v = root.AssemblyLinearVelocity
	if Vector3.new(v.X, 0, v.Z).Magnitude < 2 then
		bot.Stuck = (bot.Stuck or 0) + 1
		if bot.Stuck > 3 then
			hum.Jump = true
			bot.Goal = randomPoint()
			bot.Stuck = 0
		end
	else
		bot.Stuck = 0
	end
end

-- Adds bots as survivors until there are at least `count` survivors.
function Bots.Fill(count, spawns)
	local have = 0
	for _ in Round.Survivors do
		have += 1
	end
	for i = 1, count - have do
		local model = makeModel(i)
		if model then
			local bot = setmetatable({ Character = model, Name = model.Name, DisplayName = model.Name, Dodge = 1 }, Bot)
			bot:SetAttribute("Role", "Survivor")
			bot:SetAttribute("Hits", 0)
			bot:SetAttribute("Sprinting", false)
			model.Parent = (Round.Map and Round.Map:FindFirstChild("Debris")) or workspace
			local spot = spawns[math.random(#spawns)]
			model:PivotTo(spot.CFrame + Vector3.new(math.random(-10, 10) / 10, 3, math.random(-10, 10) / 10))
			pcall(Costumes.DressScientist, model)
			local root = Util.Root(model)
			if root then
				pcall(function()
					root:SetNetworkOwner(nil)
				end)
			end
			local hum = Util.Humanoid(model)
			hum.Died:Connect(function()
				if Round.Survivors[bot] then
					Round.Survivors[bot] = nil
				end
			end)
			Round.Survivors[bot] = true
			table.insert(active, bot)
		end
	end
end

function Bots.Clear()
	for _, bot in active do
		Round.Survivors[bot] = nil
		Status.Reset(bot)
		if bot.Character then
			bot.Character:Destroy()
		end
	end
	active = {}
end

local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	if clock < 0.25 then
		return
	end
	clock = 0
	for _, bot in active do
		think(bot)
	end
end)

return Bots
