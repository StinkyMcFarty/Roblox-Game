-- Survivor counter to Wolverine's Sniff: a green gas cloud out the back.
-- For a while afterwards the Sniff tracker points at the cloud, not you.
-- The G key is the survivor's power: the fart (plain or Turbo Fart), or, with
-- the Dodge upgrade equipped instead, a split-second dodge (Fart.Dodge).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Round = require(script.Parent.Round)
local Hiding = require(script.Parent.Hiding)
local VFX = require(script.Parent.VFX)
local Status = require(script.Parent.Status)
local Movement = require(script.Parent.Movement)
local PlayerData = require(script.Parent.PlayerData)

local Fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx")

local Fart = {}

local lastUsed = {} -- [Player] = os.clock()
local lastDodge = {} -- [Player] = os.clock()
local clouds = {} -- [Player] = { Position, Time }

function Fart.Use(player)
	local cfg = Config.Fart
	if not Round.Survivors[player] or player:GetAttribute("Role") ~= "Survivor" then
		return
	end
	if PlayerData.Power(player) == "Dodge" then
		return -- G is their dodge instead
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
	VFX.Anim(char, "Fart")
	-- fart mid-sprint: instantly at full speed. With Turbo Fart, every fart
	-- (sprinting or not, even out of stamina) also gives a speed burst and a
	-- trail of gas streaming out behind
	Movement.MaxOut(player)
	if PlayerData.Power(player) == "TurboFart" then
		local up = Config.Upgrades.TurboFart
		Status.Apply(player, "FartBoost", up.Duration)
		Fart.Trail(char, up.Duration, up.TrailTime)
		Util.FireClient(Fx, player, "Announce", { Text = "TURBO FART!", Color = Color3.fromRGB(170, 230, 60), Duration = 1.2 })
	end

	local butt = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso") or root
	local pos = butt.Position - root.CFrame.LookVector * 1.2 - Vector3.new(0, 0.4, 0)
	local look = root.CFrame.LookVector
	clouds[player] = { Position = Vector3.new(pos.X, root.Position.Y, pos.Z), Yaw = math.atan2(-look.X, -look.Z), Time = os.clock() }

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

	-- Wolverine caught right in the fresh cloud gags on it
	task.spawn(function()
		local stop = os.clock() + cfg.GasWindow
		while os.clock() < stop and Round.Active do
			local w = Round.Wolverine
			local wchar = w and w.Character
			local wroot = Util.Root(wchar)
			if wroot and Util.IsAlive(wchar) and (wroot.Position - pos).Magnitude <= cfg.GasRadius and not Status.Has(w, "Gassed") then
				Status.Apply(w, "Gassed", cfg.GasTime)
				VFX.Anim(wchar, "Gassed")
				Util.FireClient(Fx, w, "Gassed", { Duration = cfg.GasTime })
				Util.FireClient(Fx, player, "KillFeed", { Text = "You gassed Wolverine!" })
				Util.Sound(Config.Sounds.Sniff, wroot, { Volume = 1.6, Pitch = 0.7, Range = 80 })
				break
			end
			task.wait(0.1)
		end
	end)

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

-- Scent marks for Wolverine's Sniff, streamed to his client while it lasts.
-- Every mark is the same shape so a gas decoy looks exactly like a person:
-- { Id, Position, Yaw, Hiding? }. Survivors behind their gas give the cloud's
-- position instead of their own.
function Fart.SniffTargets()
	local targets = {}
	for player in Round.Survivors do
		local c = clouds[player]
		local spot = Hiding.SpotOf(player)
		local id = tostring(player.UserId or player.Name)
		local root = Util.Root(player.Character)
		if c and os.clock() - c.Time < Config.Fart.MaskTime then
			table.insert(targets, { Id = id, Position = c.Position, Yaw = c.Yaw or 0 })
		elseif spot and spot:FindFirstChild("Inside") then
			table.insert(targets, { Id = id, Position = spot.Inside.Position, Yaw = 0, Hiding = true })
		elseif root and Util.IsAlive(player.Character) then
			local look = root.CFrame.LookVector
			table.insert(targets, { Id = id, Position = root.Position, Yaw = math.atan2(-look.X, -look.Z), Big = player:GetAttribute("Role") == "Sentinel" })
		end
	end
	return targets
end

-- A green trail of gas streaming from their backside for `duration` seconds;
-- each bit of it fades `fade` seconds after it's laid down.
function Fart.Trail(char, duration, fade)
	local butt = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")
	if not butt then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "FartTrail"
	a0.Position = Vector3.new(0, 0.7, 0.6)
	a0.Parent = butt
	local a1 = Instance.new("Attachment")
	a1.Name = "FartTrail"
	a1.Position = Vector3.new(0, -0.7, 0.6)
	a1.Parent = butt
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = fade
	trail.Color = ColorSequence.new(Color3.fromRGB(170, 230, 60), Color3.fromRGB(90, 140, 30))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.2) })
	trail.LightEmission = 0.2
	trail.FaceCamera = true
	trail.Parent = butt
	local puffs = Instance.new("ParticleEmitter")
	puffs.Name = "FartTrail"
	puffs.Texture = "rbxasset://textures/particles/smoke_main.dds"
	puffs.Color = ColorSequence.new(Color3.fromRGB(160, 220, 60), Color3.fromRGB(100, 150, 40))
	puffs.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.6) })
	puffs.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	puffs.Lifetime = NumberRange.new(fade * 0.6, fade)
	puffs.Rate = 30
	puffs.Speed = NumberRange.new(0.5, 1.5)
	puffs.SpreadAngle = Vector2.new(40, 40)
	puffs.EmissionDirection = Enum.NormalId.Back
	puffs.Parent = butt
	task.delay(duration, function()
		trail.Enabled = false
		puffs.Enabled = false
	end)
	for _, inst in { a0, a1, trail, puffs } do
		Debris:AddItem(inst, duration + fade + 0.2)
	end
end

-- Dodge upgrade: pressed just as he strikes, a split second of i-frames. His
-- attack lands on nothing (Combat.BreakShield sees "Dodging"), and it's on
-- cooldown whether it dodged anything or not.
function Fart.Dodge(player)
	local up = Config.Upgrades.Dodge
	if not Round.Survivors[player] or player:GetAttribute("Role") ~= "Survivor" then
		return
	end
	if PlayerData.Power(player) ~= "Dodge" or Hiding.IsHidden(player) then
		return
	end
	if os.clock() - (lastDodge[player] or -math.huge) < up.Cooldown - 0.5 then
		return
	end
	local char = player.Character
	local root = Util.Root(char)
	if not (root and Util.IsAlive(char)) then
		return
	end
	lastDodge[player] = os.clock()
	Status.Apply(player, "Immune", up.Window)
	Status.Apply(player, "Dodging", up.Window)
	VFX.Anim(char, "Dodge")
	Util.Sound(Config.Sounds.Whoosh, root, { Volume = 1.2, Pitch = 1.3, Range = 60 })
	Fx:FireAllClients("Dodge", { Char = char, Duration = up.Window })
end

function Fart.Reset(player)
	lastUsed[player] = nil
	lastDodge[player] = nil
	clouds[player] = nil
end

return Fart
