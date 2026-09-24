-- Survivor counter to Wolverine's Sniff: a green gas cloud out the back.
-- For a while afterwards the Sniff tracker points at the cloud, not you.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Round = require(script.Parent.Round)
local Hiding = require(script.Parent.Hiding)

local Fart = {}

local lastUsed = {} -- [Player] = os.clock()
local clouds = {} -- [Player] = { Position, Time }

function Fart.Use(player)
	local cfg = Config.Fart
	if not Round.Survivors[player] or player:GetAttribute("Role") ~= "Survivor" then
		return
	end
	if os.clock() - (lastUsed[player] or -math.huge) < cfg.Cooldown - 0.5 then
		return
	end
	local char = player.Character
	local root = Util.Root(char)
	if not (root and Util.IsAlive(char)) then
		return
	end
	lastUsed[player] = os.clock()

	local butt = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso") or root
	local pos = butt.Position - root.CFrame.LookVector * 1.2 - Vector3.new(0, 0.4, 0)
	clouds[player] = { Position = pos, Time = os.clock() }

	local cloud = Instance.new("Part")
	cloud.Name = "GasCloud"
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.CanTouch = false
	cloud.Transparency = 1
	cloud.Size = Vector3.one
	cloud.Position = pos
	cloud.Parent = (Round.Map and Round.Map:FindFirstChild("Debris")) or workspace

	local gas = Instance.new("ParticleEmitter")
	gas.Texture = "rbxasset://textures/particles/smoke_main.dds"
	gas.Color = ColorSequence.new(Color3.fromRGB(140, 200, 40), Color3.fromRGB(90, 140, 30))
	gas.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 7) })
	gas.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.7, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	gas.Lifetime = NumberRange.new(3, 5)
	gas.Speed = NumberRange.new(0.5, 2)
	gas.SpreadAngle = Vector2.new(180, 180)
	gas.RotSpeed = NumberRange.new(-20, 20)
	gas.Acceleration = Vector3.new(0, 0.6, 0)
	gas.Rate = 30
	gas.Parent = cloud
	task.delay(cfg.CloudTime - 4, function()
		gas.Enabled = false
	end)
	Debris:AddItem(cloud, cfg.CloudTime + 1)

	-- the initial blast out the back
	Util.Burst(butt, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(150, 210, 50)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 4) }),
		Transparency = NumberSequence.new(0.3, 1),
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Back,
	}, 25, 2)
	Util.Sound(Config.Sounds.Fart, butt, { Volume = 2, Pitch = 0.9 + math.random() * 0.3, Range = 120 })
	if Config.Sounds.Fart == "" then
		Util.Sound(Config.Sounds.Gore, butt, { Volume = 2, Pitch = 0.35, Range = 120 })
	end
end

-- Returns { Name = player.Name } for trackable survivors, or
-- { Position = Vector3 } decoys for anyone hiding behind their gas.
function Fart.SniffTargets()
	local targets = {}
	for player in Round.Survivors do
		local c = clouds[player]
		local spot = Hiding.SpotOf(player)
		if c and os.clock() - c.Time < Config.Fart.MaskTime then
			table.insert(targets, { Position = c.Position })
		elseif spot and spot:FindFirstChild("Inside") then
			table.insert(targets, { Position = spot.Inside.Position - Vector3.new(0, 2, 0), Hiding = true })
		elseif player.IsBot then
			table.insert(targets, { Char = player.Character })
		else
			table.insert(targets, { Name = player.Name })
		end
	end
	return targets
end

function Fart.Reset(player)
	lastUsed[player] = nil
	clouds[player] = nil
end

return Fart
