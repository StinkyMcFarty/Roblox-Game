-- Wolverine: transformation, intro (SNIKT + roar), abilities, healing factor
-- and tearing through walls while he runs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Round = require(script.Parent.Round)
local Status = require(script.Parent.Status)
local Posture = require(script.Parent.Posture)
local Movement = require(script.Parent.Movement)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local Fart = require(script.Parent.Fart)
local VFX = require(script.Parent.VFX)
local Costumes = require(script.Parent.Costumes)
local Skins = require(ReplicatedStorage.Shared.Skins)

local Fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx")

local Wolverine = {}

local YELLOW = Color3.fromRGB(245, 195, 20)
local STEEL = Color3.fromRGB(210, 214, 222)

local cooldowns = {}
local lastDamaged = 0
local combo = 0
local rage = { Count = 0, Armed = true, Until = 0 } -- this round's rage (Config.Rage)
local updateRage
local crackGlass

-- How much faster his cooldowns run right now: slashes by AttackSpeed, the
-- rest by Cooldown, while enraged.
local function rageScale(player, ability)
	if not player:GetAttribute("Rage") then
		return 1
	end
	return ability == "Slash" and 1 / Config.Rage.AttackSpeed or Config.Rage.Cooldown
end
local clawGlow = Color3.fromRGB(210, 230, 255)
local clawSkin = nil

---------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------

local function gearPart(char, anchor, name, size, color, material, offset)
	local folder = char:FindFirstChild("Gear")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Gear"
		folder.Parent = char
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = anchor.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = anchor
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	p.Parent = folder
	return p, w
end

local function dressUp(char, skinId)
	Costumes.Dress(char, skinId)
	local hl = Instance.new("Highlight")
	hl.Name = "Menace"
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.fromRGB(170, 0, 0)
	hl.OutlineTransparency = 0.35
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = char
end

local clawSet = nil
local clawTrails = {}
local trailToken = 0

-- Claw trails only streak during attacks, never while walking around.
local function swingTrails(duration)
	trailToken += 1
	local my = trailToken
	for _, t in clawTrails do
		if t.Parent then
			t.Enabled = true
		end
	end
	task.delay(duration, function()
		if trailToken == my then
			for _, t in clawTrails do
				if t.Parent then
					t.Enabled = false
				end
			end
		end
	end)
end

local function makeClaws(char, clawId)
	clawSkin = Skins.Claws[clawId] or Skins.Claws[Skins.DefaultClaw]
	clawGlow = clawSkin.Glow
	char:SetAttribute("ClawGlow", clawGlow)
	clawSet = Costumes.BuildClaws(char, clawSkin, false)
end

local function popClaws(char, noAnim)
	if not noAnim then
		VFX.Anim(char, "Snikt")
	end
	if not clawSet then
		return
	end
	Costumes.PopClaws(clawSet)
	-- Streaking trails off every blade: every swing leaves a crisp arc
	task.delay(0.18, function()
		table.clear(clawTrails)
		for i, tip in clawSet.Tips do
			local base = clawSet.Bases[i]
			if tip.Parent and base and base.Parent then
				local a0 = Instance.new("Attachment")
				a0.Parent = base
				a0.Position = Vector3.new(0, base.Size.Y * 0.3, 0)
				local a1 = Instance.new("Attachment")
				a1.Parent = tip
				local trail = Instance.new("Trail")
				trail.Attachment0 = a0
				trail.Attachment1 = a1
				trail.Lifetime = 0.14
				trail.MinLength = 0.05
				trail.LightEmission = 1
				trail.Color = ColorSequence.new(Color3.new(1, 1, 1), clawGlow)
				trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
				trail.Enabled = false
				trail.Parent = tip
				table.insert(clawTrails, trail)
				if clawSkin.Drip or clawSkin.Sparkle then
					local pe = Instance.new("ParticleEmitter")
					if clawSkin.Drip then
						for k, v in Util.BloodProps do
							pe[k] = v
						end
						pe.Rate = 3
						pe.Speed = NumberRange.new(0, 1)
						pe.Size = NumberSequence.new(0.12)
					else
						for k, v in Util.SparkProps do
							pe[k] = v
						end
						pe.Color = ColorSequence.new(clawSkin.Glow, clawSkin.Color)
						pe.Rate = 6
						pe.Speed = NumberRange.new(0.5, 2)
						pe.Acceleration = Vector3.zero
					end
					pe.Parent = a1
				end
				if clawSkin.Material == Enum.Material.Neon then
					local l = Instance.new("PointLight")
					l.Color = clawGlow
					l.Range = 6
					l.Brightness = 1
					l.Parent = base
				end
			end
		end
	end)
	for _, side in { "Right", "Left" } do
		local hand = Util.Hand(char, side)
		if hand then
			Util.Burst(hand, Util.SparkProps, 25, 1.5)
			Util.Burst(hand, Util.BloodProps, 10, 1.5)
			Util.Sound(Config.Sounds.Snikt, hand, { Volume = 2, Range = 250, Pitch = 0.9 })
		end
	end

	-- Comic-book SNIKT! above his head
	local head = char:FindFirstChild("Head")
	if head then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromScale(7, 2.5)
		bb.StudsOffset = Vector3.new(0, 3.5, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 200
		bb.Adornee = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "SNIKT!"
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.TextColor3 = YELLOW
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.Rotation = -8
		label.Parent = bb
		bb.Parent = head
		task.delay(0.9, function()
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end)
		Debris:AddItem(bb, 1.5)
	end
	Fx:FireAllClients("Shake", { Position = head and head.Position or Vector3.zero, Intensity = 0.4, Radius = 60 })
end

local tankIntro -- defined below (needs popClaws/roar)

local function roar(char)
	local head = char:FindFirstChild("Head")
	local root = Util.Root(char)
	if not (head and root) then
		return
	end
	VFX.Anim(char, "Roar")
	VFX.Shockwave(root.Position - Vector3.new(0, 2.8, 0), 22, Color3.fromRGB(255, 80, 60))
	if Config.Sounds.Roar ~= "" then
		Util.Sound(Config.Sounds.Roar, head, { Volume = 3, Range = 900, MinRange = 40 })
	else
		Util.Sound(Config.Sounds.Lunge, head, { Volume = 3, Range = 900, MinRange = 40, Pitch = 0.3 })
		Util.Sound(Config.Sounds.Break, head, { Volume = 3, Range = 900, MinRange = 40, Pitch = 0.4 })
	end
	for _, eye in (char:FindFirstChild("Gear") or char):GetChildren() do
		if eye.Name == "Eye" then
			eye.Color = Color3.fromRGB(255, 40, 40)
		end
	end
	Fx:FireAllClients("Roar", { Position = root.Position })
end

local function clawStreaks(root, side)
	VFX.ClawArc(root, side, clawGlow)
end

---------------------------------------------------------------------------
-- Adamantium skeleton (flashed when the Sentinel's laser hits him)
---------------------------------------------------------------------------

local skeleton = {} -- parts, hidden until revealed
local flesh = {} -- [BasePart] = normal transparency
local revealToken = 0

local function bone(char, anchor, size, offset, shape)
	local p = gearPart(char, anchor, "Bone", size, STEEL, Enum.Material.Metal, offset)
	p.Reflectance = 0.45
	p.Transparency = 1
	if shape then
		p.Shape = shape
	end
	table.insert(skeleton, p)
	return p
end

-- A long bone along the part's Y axis with knobbly joint ends.
local function longBone(char, limb)
	if not limb then
		return
	end
	local s = limb.Size
	local len = s.Y * 0.95
	local r = math.min(s.X, s.Z) * 0.32
	bone(char, limb, Vector3.new(len, r, r), CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	for _, y in { -len / 2, len / 2 } do
		bone(char, limb, Vector3.one * r * 1.7, CFrame.new(0, y, 0), Enum.PartType.Ball)
	end
end

local function makeSkeleton(char)
	skeleton = {}
	flesh = {}
	local head = char:FindFirstChild("Head")
	if head then
		local hs = head.Size
		bone(char, head, Vector3.new(hs.X * 0.72, hs.Y * 0.7, hs.Z * 0.75), CFrame.new(0, hs.Y * 0.06, 0))
		bone(char, head, Vector3.new(hs.X * 0.55, hs.Y * 0.2, hs.Z * 0.6), CFrame.new(0, -hs.Y * 0.3, -hs.Z * 0.05)) -- jaw
		for s = -1, 1, 2 do
			local socket = bone(char, head, Vector3.new(hs.X * 0.18, hs.Y * 0.16, 0.05), CFrame.new(s * hs.X * 0.17, hs.Y * 0.1, -hs.Z * 0.39))
			socket.Color = Color3.fromRGB(255, 40, 40)
			socket.Material = Enum.Material.Neon
			socket.Reflectance = 0
		end
	end
	local upper = char:FindFirstChild("UpperTorso")
	if upper then
		local s = upper.Size
		bone(char, upper, Vector3.new(s.X * 0.14, s.Y * 1.05, s.X * 0.14), CFrame.new(0, 0, s.Z * 0.2)) -- spine
		bone(char, upper, Vector3.new(s.X * 0.95, s.Y * 0.08, s.Z * 0.2), CFrame.new(0, s.Y * 0.4, 0)) -- collarbone
		for i = 0, 3 do
			local w = s.X * (0.85 - i * 0.08)
			bone(char, upper, Vector3.new(w, s.Y * 0.07, s.Z * 0.75), CFrame.new(0, s.Y * (0.22 - i * 0.16), 0))
		end
	end
	local lower = char:FindFirstChild("LowerTorso")
	if lower then
		local s = lower.Size
		bone(char, lower, Vector3.new(s.X * 0.8, s.Y * 0.45, s.Z * 0.5), CFrame.new(0, -s.Y * 0.05, 0)) -- pelvis
		bone(char, lower, Vector3.new(s.X * 0.14, s.Y * 0.9, s.X * 0.14), CFrame.new(0, s.Y * 0.2, s.Z * 0.2))
	end
	for _, n in { "RightUpperArm", "RightLowerArm", "LeftUpperArm", "LeftLowerArm", "RightUpperLeg", "RightLowerLeg", "LeftUpperLeg", "LeftLowerLeg", "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
		longBone(char, char:FindFirstChild(n))
	end
	for _, n in { "RightHand", "LeftHand", "RightFoot", "LeftFoot" } do
		local p = char:FindFirstChild(n)
		if p then
			bone(char, p, p.Size * 0.6, CFrame.identity)
		end
	end
	local torsoR6 = char:FindFirstChild("Torso")
	if torsoR6 then
		local s = torsoR6.Size
		bone(char, torsoR6, Vector3.new(s.X * 0.12, s.Y, s.X * 0.12), CFrame.new(0, 0, s.Z * 0.2))
		for i = 0, 3 do
			bone(char, torsoR6, Vector3.new(s.X * 0.85, s.Y * 0.07, s.Z * 0.7), CFrame.new(0, s.Y * (0.3 - i * 0.15), 0))
		end
	end

	-- Everything that should go see-through: body, suit gear, hair
	local gear = char:FindFirstChild("Gear")
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Name ~= "Claw" and d.Name ~= "Bone" then
			if d.Parent == char or d.Parent == gear or d.Parent:IsA("Accessory") then
				flesh[d] = d.Transparency
			end
		end
	end
	for _, p in skeleton do
		flesh[p] = nil
	end
	-- group the bones so they can glow through the see-through flesh
	local model = Instance.new("Model")
	model.Name = "Skeleton"
	model.Parent = char
	for _, p in skeleton do
		p.Parent = model
	end
	local glow = Instance.new("Highlight")
	glow.Name = "BoneGlow"
	glow.Adornee = model
	glow.FillColor = Color3.fromRGB(215, 228, 245)
	glow.FillTransparency = 0.35
	glow.OutlineColor = Color3.new(1, 1, 1)
	glow.OutlineTransparency = 0.15
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Enabled = false
	glow.Parent = model
end

function Wolverine.RevealSkeleton()
	local player = Round.Wolverine
	local char = player and player.Character
	if not char or #skeleton == 0 then
		return
	end
	revealToken += 1
	local token = revealToken
	for p in flesh do
		if p.Parent then
			p.Transparency = 0.92
		end
	end
	local glow = char:FindFirstChild("BoneGlow", true)
	if glow then
		glow.Enabled = true
	end
	for _, p in skeleton do
		if p.Parent then
			p.Transparency = 0
		end
	end
	local torso = Util.Torso(char)
	if torso then
		local burn = Instance.new("PointLight")
		burn.Name = "Burn"
		burn.Color = Color3.fromRGB(255, 90, 40)
		burn.Range = 12
		burn.Brightness = 3
		burn.Parent = torso
		Debris:AddItem(burn, 0.8)
	end
	-- Healing factor: the flesh knits back over the metal
	task.delay(0.7, function()
		if token ~= revealToken then
			return
		end
		local info = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		local glow2 = char:FindFirstChild("BoneGlow", true)
		if glow2 then
			task.delay(0.9, function()
				if token == revealToken then
					glow2.Enabled = false
				end
			end)
		end
		for p, t in flesh do
			if p.Parent then
				TweenService:Create(p, info, { Transparency = t }):Play()
			end
		end
		for _, p in skeleton do
			if p.Parent then
				TweenService:Create(p, info, { Transparency = 1 }):Play()
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Transform / intro
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Intro: the Weapon X tank breakout. He floats in the adamantium fluid, wakes,
-- smashes out through the glass, lands, crosses his arms and the claws shoot
-- out in an X, then the roar. Timings live in Config.Intro.
---------------------------------------------------------------------------

local GLASS = Color3.fromRGB(190, 230, 235)
local FLUID = Color3.fromRGB(70, 220, 205)

-- A kick lands on the tank glass: cracks star out from where his boot hit
-- (more of them, further, on the second kick), and on the second kick the
-- fluid starts spurting through. Everything goes into `list` to clear later.
crackGlass = function(glass, dir, strength, list)
	local c = glass.CFrame.Position
	local radius, height = glass.Size.Y / 2, glass.Size.X
	local up = Vector3.new(0, 1, 0)
	local side = dir:Cross(up).Unit
	local hit = c + dir * (radius + 0.04) + up * (-height * 0.2 + strength * 0.5) + side * (strength - 1.5) * 0.8 -- where his boot lands
	local folder = (Round.Map and Round.Map:FindFirstChild("Debris")) or workspace
	local function line(a, b, w)
		local mid = (a + b) / 2
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Glass
		p.Color = Color3.fromRGB(235, 250, 255)
		p.Transparency = 0.15
		p.Size = Vector3.new(w, w, (b - a).Magnitude + 0.05)
		p.CFrame = CFrame.lookAt(mid, b)
		p.Parent = folder
		table.insert(list, p)
	end
	for k = 1, 5 + strength * 4 do
		local a = math.random() * math.pi * 2
		local p0 = hit
		local reach = (1.4 + math.random() * 1.6) * (0.8 + strength * 0.6)
		local len = 0
		while len < reach do
			a += (math.random() - 0.5) * 0.8
			local seg = 0.5 + math.random() * 0.7
			local p1 = p0 + (side * math.cos(a) + up * math.sin(a)) * seg
			line(p0, p1, 0.06 * (1 - len / reach) + 0.02)
			p0 = p1
			len += seg
		end
	end
	-- the ring of shattered glass round the impact
	for k = 1, 8 do
		local a1, a2 = k / 8 * math.pi * 2, (k + 1) / 8 * math.pi * 2
		local r = 0.35 * strength
		line(hit + (side * math.cos(a1) + up * math.sin(a1)) * r, hit + (side * math.cos(a2) + up * math.sin(a2)) * r, 0.05)
	end
	if strength >= 2 then
		-- the fluid starts spurting through the cracks
		local spout = Instance.new("Part")
		spout.Anchored, spout.CanCollide, spout.CanQuery, spout.Transparency = true, false, false, 1
		spout.Size = Vector3.one * 0.5
		spout.CFrame = CFrame.lookAt(hit, hit + dir)
		spout.Parent = folder
		table.insert(list, spout)
		local jet = Instance.new("ParticleEmitter")
		jet.Texture = "rbxasset://textures/particles/smoke_main.dds"
		jet.Color = ColorSequence.new(Color3.fromRGB(190, 255, 245), FLUID)
		jet.LightEmission = 0.3
		jet.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.9) })
		jet.Transparency = NumberSequence.new(0.35, 1)
		jet.Lifetime = NumberRange.new(0.5, 0.8)
		jet.Rate = 90
		jet.Speed = NumberRange.new(10, 16)
		jet.SpreadAngle = Vector2.new(9, 9)
		jet.Acceleration = Vector3.new(0, -55, 0)
		jet.EmissionDirection = Enum.NormalId.Front
		jet.Parent = spout
	end
end

local function shatterTank(glass, liquid, dir)
	local c = glass.CFrame.Position
	local radius, height = glass.Size.Y / 2, glass.Size.X
	glass.Transparency = 1
	glass.CanCollide = false
	glass.CanQuery = false
	local folder = (Round.Map and Round.Map:FindFirstChild("Debris")) or workspace
	for k = 1, 90 do
		local a = math.random() * math.pi * 2
		local y = (math.random() - 0.5) * height * 0.9
		local p = c + Vector3.new(math.cos(a) * radius, y, math.sin(a) * radius)
		local shard = Instance.new("WedgePart")
		local big = k <= 10 -- a few big panes among the splinters
		shard.Size = big and Vector3.new(0.1, 2 + math.random() * 2, 1.5 + math.random() * 1.5) or Vector3.new(0.08, 0.3 + math.random() * 1.4, 0.3 + math.random() * 1)
		shard.CFrame = CFrame.new(p) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		shard.Material = Enum.Material.Glass
		shard.Color = GLASS
		shard.Transparency = 0.35
		shard.Reflectance = 0.3
		shard.CanCollide = true
		shard.CanQuery = false
		shard.CastShadow = false
		shard.Parent = folder
		-- blown out, mostly the way he's facing
		local out = (p - c) * Vector3.new(1, 0, 1)
		out = out.Magnitude > 0.01 and out.Unit or dir
		shard.AssemblyLinearVelocity = (out * 0.5 + dir * (0.6 + math.random() * 0.6)).Unit * (30 + math.random() * 35) + Vector3.new(0, 8 + math.random() * 14, 0)
		shard.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 30
		Debris:AddItem(shard, 5 + math.random() * 2)
	end
	-- the fluid gushes out in a torrent, arcing down to the floor
	local floorY0 = c.Y - height / 2
	local gush = Instance.new("Part")
	gush.Anchored, gush.CanCollide, gush.CanQuery, gush.Transparency = true, false, false, 1
	gush.Size = Vector3.new(radius * 1.6, height * 0.5, 0.5)
	gush.CFrame = CFrame.lookAt(c + dir * radius - Vector3.new(0, height * 0.15, 0), c + dir * (radius + 1) - Vector3.new(0, height * 0.15, 0))
	gush.Parent = folder
	local torrent = Instance.new("ParticleEmitter")
	torrent.Texture = "rbxasset://textures/particles/smoke_main.dds"
	torrent.Color = ColorSequence.new(Color3.fromRGB(200, 255, 248), FLUID)
	torrent.LightEmission = 0.35
	torrent.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 3.4) })
	torrent.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.7, 0.5), NumberSequenceKeypoint.new(1, 1) })
	torrent.Lifetime = NumberRange.new(0.6, 1)
	torrent.Rate = 260
	torrent.Speed = NumberRange.new(14, 24)
	torrent.SpreadAngle = Vector2.new(25, 10)
	torrent.Acceleration = Vector3.new(0, -70, 0)
	torrent.EmissionDirection = Enum.NormalId.Front
	torrent.Shape = Enum.ParticleEmitterShape.Box
	torrent.Parent = gush
	local droplets = torrent:Clone()
	droplets.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	droplets.Size = NumberSequence.new(0.35, 0.1)
	droplets.Rate = 160
	droplets.Speed = NumberRange.new(18, 34)
	droplets.SpreadAngle = Vector2.new(45, 30)
	droplets.LightEmission = 0.8
	droplets.Parent = gush
	task.delay(1.1, function()
		torrent.Rate = 70 -- the gush eases to a pour
		droplets.Rate = 30
	end)
	task.delay(2.2, function()
		torrent.Enabled = false
		droplets.Enabled = false
	end)
	Debris:AddItem(gush, 4)
	-- and spreads across the floor in a sheet, then slowly drains away
	local puddle = Instance.new("Part")
	puddle.Shape = Enum.PartType.Cylinder
	puddle.Anchored, puddle.CanCollide, puddle.CanQuery, puddle.CanTouch, puddle.CastShadow = true, false, false, false, false
	puddle.Material = Enum.Material.Glass
	puddle.Color = FLUID
	puddle.Transparency = 0.45
	puddle.Reflectance = 0.35
	puddle.Size = Vector3.new(0.06, radius * 2, radius * 2)
	puddle.CFrame = CFrame.new(c.X, floorY0 + 0.05, c.Z) * CFrame.Angles(0, 0, math.rad(90))
	puddle.Parent = folder
	local spread = CFrame.new(c.X + dir.X * 7, floorY0 + 0.05, c.Z + dir.Z * 7) * CFrame.Angles(0, 0, math.rad(90))
	TweenService:Create(puddle, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.06, 30, 30), CFrame = spread }):Play()
	task.delay(4, function()
		if puddle.Parent then
			TweenService:Create(puddle, TweenInfo.new(8), { Transparency = 1, Size = Vector3.new(0.06, 34, 34) }):Play()
		end
	end)
	Debris:AddItem(puddle, 12.5)
	-- the fluid bursts out and drains
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.Transparency = true, false, false, 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.lookAt(c, c + dir)
	anchor.Parent = folder
	Util.Burst(anchor, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(150, 255, 240), FLUID),
		LightEmission = 0.4,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 4.5) }),
		Transparency = NumberSequence.new(0.25, 1),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(18, 40),
		SpreadAngle = Vector2.new(55, 30),
		Acceleration = Vector3.new(0, -60, 0),
		EmissionDirection = Enum.NormalId.Front,
	}, 90, 2)
	Util.Burst(anchor, Util.SparkProps, 40, 1.5)
	Debris:AddItem(anchor, 3)
	if liquid then
		local bottom = liquid.CFrame.Position.Y - liquid.Size.X / 2
		TweenService:Create(liquid, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = Vector3.new(0.2, liquid.Size.Y, liquid.Size.Z),
			CFrame = CFrame.new(liquid.CFrame.Position.X, bottom + 0.1, liquid.CFrame.Position.Z) * CFrame.Angles(0, 0, math.rad(90)),
		}):Play()
		local light = liquid:FindFirstChildWhichIsA("Light")
		if light then
			TweenService:Create(light, TweenInfo.new(1.2), { Brightness = 0.4 }):Play()
		end
	end
	VFX.Shockwave(Vector3.new(c.X, c.Y - height / 2 + 0.3, c.Z), 26, FLUID)
	Util.SoundAt(Config.Sounds.Break, c, { Volume = 3, Pitch = 1.35, Range = 500 })
	Util.SoundAt(Config.Sounds.Break, c, { Volume = 2.4, Pitch = 0.6, Range = 500 })
	Util.SoundAt(Config.Sounds.Impact, c, { Volume = 2.5, Pitch = 0.7, Range = 400 })
	Fx:FireAllClients("Shake", { Position = c, Intensity = 1.4, Radius = 140 })
end

tankIntro = function(player, char, spawnCFrame, valid)
	local cfg = Config.Intro
	local root = Util.Root(char)
	local map = Round.Map
	local glass = map and map:FindFirstChild("TankGlass", true)
	local liquid = map and map:FindFirstChild("TankLiquid", true)
	if not (root and glass) then
		-- no tank on this map: the classic intro
		task.wait(Config.ClawPopTime)
		if valid() then popClaws(char) end
		task.wait(Config.RoarTime - Config.ClawPopTime)
		if valid() then roar(char) end
		return
	end
	local dir = Util.Flat(spawnCFrame.LookVector)
	local tc = glass.CFrame.Position
	local floorY = tc.Y - glass.Size.X / 2
	local hum = Util.Humanoid(char)
	local hip = (hum and hum.HipHeight or 2) + root.Size.Y / 2
	local inside = CFrame.lookAt(Vector3.new(tc.X, floorY + hip + 1.2, tc.Z), Vector3.new(tc.X, floorY + hip + 1.2, tc.Z) + dir)
	root.Anchored = true
	char:PivotTo(inside)
	VFX.Anim(char, "TankFloat")
	Util.FireClient(Fx, player, "IntroCam", { Tank = tc, Land = spawnCFrame.Position, Dir = dir, Burst = cfg.Burst, Release = Config.IntroLength })

	-- drifting in the fluid
	local t0 = os.clock()
	while os.clock() - t0 < cfg.Wake and valid() do
		local t = os.clock() - t0
		char:PivotTo(inside * CFrame.new(0, math.sin(t * 1.6) * 0.25, 0) * CFrame.Angles(0, math.sin(t * 0.7) * 0.08, 0))
		task.wait()
	end
	if not valid() then
		root.Anchored = false
		return
	end
	-- eyes snap open, he fights the restraints: the glass takes two hits
	VFX.Anim(char, "TankWake")
	for _, eye in (char:FindFirstChild("Gear") or char):GetChildren() do
		if eye.Name == "Eye" then
			eye.Color = Color3.fromRGB(255, 40, 40)
		end
	end
	Util.SoundAt(Config.Sounds.Snarl ~= "" and Config.Sounds.Snarl or Config.Sounds.Impact, tc, { Volume = 2, Pitch = 0.8, Range = 200 })
	-- two kicks at the glass: it cracks, then starts spurting
	local cracks = {}
	for k, at in cfg.Kicks do
		task.wait(math.max(0, at - 0.18 - (os.clock() - t0)))
		if not valid() then break end
		VFX.Anim(char, "TankKick")
		task.wait(0.18) -- the boot connects
		if not valid() then break end
		crackGlass(glass, dir, k, cracks)
		Util.SoundAt(Config.Sounds.Impact, tc, { Volume = 2.6, Pitch = 0.5 + k * 0.1, Range = 300 })
		Util.SoundAt(Config.Sounds.Break, tc, { Volume = 1.2 + k * 0.4, Pitch = 1.6, Range = 260 }) -- the glass cracking
		Fx:FireAllClients("Shake", { Position = tc, Intensity = 0.6 + k * 0.25, Radius = 80 })
		glass.Transparency = math.max(0.45, glass.Transparency - 0.1) -- stress fogs the glass
	end
	task.wait(math.max(0, cfg.Burst - (os.clock() - t0)))
	if not valid() then
		for _, c in cracks do
			c:Destroy()
		end
		root.Anchored = false
		return
	end

	-- BREAKOUT: a flying kick through the glass
	for _, c in cracks do
		c:Destroy()
	end
	shatterTank(glass, liquid, dir)
	VFX.Anim(char, "KickOut")
	local from = char:GetPivot()
	local to = spawnCFrame
	local flight = 0.42
	local f0 = os.clock()
	while os.clock() - f0 < flight and valid() do
		local u = (os.clock() - f0) / flight
		local p = from.Position:Lerp(to.Position, u) + Vector3.new(0, math.sin(u * math.pi) * 2.2, 0)
		char:PivotTo(CFrame.lookAt(p, p + dir))
		task.wait()
	end
	char:PivotTo(to)
	VFX.Dust(to.Position - Vector3.new(0, hip, 0), Color3.fromRGB(150, 210, 205), 18)
	VFX.Shockwave(to.Position - Vector3.new(0, hip - 0.2, 0), 14, FLUID)
	Util.Sound(Config.Sounds.Land ~= "" and Config.Sounds.Land or Config.Sounds.Impact, root, { Volume = 2.4, Pitch = 0.75, Range = 300 })
	Fx:FireAllClients("Shake", { Position = to.Position, Intensity = 1, Radius = 90 })

	-- rise, cross the forearms... SNIKT: the blades shoot out in an X
	task.wait(cfg.Cross - cfg.Burst - flight)
	if not valid() then
		root.Anchored = false
		return
	end
	VFX.Anim(char, "CrossSnikt")
	task.wait(0.62)
	if not valid() then
		root.Anchored = false
		return
	end
	popClaws(char, true)
	for _, hand in { char:FindFirstChild("RightHand"), char:FindFirstChild("LeftHand") } do
		if hand then
			VFX.Impact(hand.Position + Vector3.new(0, 0.8, 0), clawGlow, 1.4)
		end
	end
	Util.Sound(Config.Sounds.Snikt, root, { Volume = 3, Range = 400 })
	Fx:FireAllClients("Shake", { Position = to.Position, Intensity = 0.8, Radius = 80 })
	Fx:FireAllClients("HitStop", { Attacker = char, Duration = 0.12 })

	-- hold the X... then throw the arms wide and ROAR
	task.wait(cfg.Roar - cfg.Cross - 0.62)
	if valid() then
		roar(char)
	end
	task.wait(math.max(0.3, Config.IntroLength - cfg.Roar)) -- free him right as he's released
	if root.Parent then
		root.Anchored = false
	end
end

function Wolverine.Transform(player, spawnCFrame)
	local char = player.Character
	if not char then
		return
	end
	player:SetAttribute("Role", "Wolverine")
	player:SetAttribute("Rage", false)
	cooldowns[player] = {}
	combo = 0
	lastDamaged = 0
	rage = { Count = 0, Armed = true, Until = 0 }
	char:PivotTo(spawnCFrame)

	local function valid()
		return Round.Active and Round.Wolverine == player and player.Character == char and Util.IsAlive(char)
	end

	-- Wait for the avatar to finish loading so we can strip it properly
	if not player:HasAppearanceLoaded() then
		local t0 = os.clock()
		while not player:HasAppearanceLoaded() and os.clock() - t0 < 4 do
			task.wait(0.1)
		end
	end
	if not valid() then
		return
	end

	local hum = Util.Humanoid(char)
	hum.MaxHealth = Config.Wolverine.MaxHealth
	hum.Health = Config.Wolverine.MaxHealth
	hum.Died:Connect(function()
		if Round.Wolverine == player then
			Round.WolverineDead = true
		end
	end)

	dressUp(char, PlayerData.GetSkin(player))
	Posture.Forget(char)
	pcall(function()
		char:ScaleTo(Config.Wolverine.Scale)
	end)
	makeClaws(char, PlayerData.GetClaw(player))
	makeSkeleton(char)
	char:PivotTo(spawnCFrame * CFrame.new(0, 1, 0))

	task.spawn(tankIntro, player, char, spawnCFrame, valid)
	task.delay(Config.IntroLength, function()
		if valid() then
			Round.Released = true
			ReplicatedStorage:SetAttribute("Released", true)
			Fx:FireAllClients("Announce", { Text = "WOLVERINE HAS BEEN RELEASED", Color = Color3.fromRGB(255, 60, 60), Duration = 3 })
		end
	end)
end

---------------------------------------------------------------------------
-- Abilities
---------------------------------------------------------------------------

-- A slash that lands locks his claws for a moment: slash, pounce and impale
-- all go on cooldown (never shortening one that's already longer).
local CLAW_ATTACKS = { "Slash", "Pounce", "Stab" }
local function lockClaws(player, seconds)
	local cd = cooldowns[player]
	if not cd then
		return
	end
	seconds *= rageScale(player, "Lock")
	local ready = os.clock() + seconds - 0.1 -- same latency allowance as Handle
	for _, name in CLAW_ATTACKS do
		cd[name] = math.max(cd[name] or 0, ready)
	end
	Util.FireClient(Fx, player, "ClawLock", { Seconds = seconds, Abilities = CLAW_ATTACKS })
end

local function slash(player, char, root)
	swingTrails(0.38)
	combo = combo % 2 + 1
	local side = combo == 1 and "R" or "L"
	VFX.Anim(char, side == "R" and "SlashR" or "SlashL")
	-- land the hit on the strike frame of the animation (wind-up first)
	task.delay(0.12 * rageScale(player, "Slash"), function()
		if not (char.Parent and Util.IsAlive(char)) then
			return
		end
		clawStreaks(root, side)
		Util.Sound(Config.Sounds.Slash, root, { Pitch = 0.96 + math.random() * 0.1, Volume = 1.3 })
		local cfg = Config.Abilities.Slash
		local cf = root.CFrame * CFrame.new(0, 0, -cfg.Range / 2)
		if Combat.BreakInBox(cf, Vector3.new(cfg.Width, 9, cfg.Range), root.Position, 35) == 0 then
			Combat.ClawWall(root, cfg.Range)
		end
		local target = Combat.FindTargets(cf, Vector3.new(cfg.Width, 8, cfg.Range + 1))[1]
		if target then
			local sentinel = target.Player:GetAttribute("Role") == "Sentinel"
			if Combat.Resolve(player, target.Player) then
				lockClaws(player, sentinel and cfg.SentinelHitLock or cfg.HitLock)
			end
		end
	end)
end

local function groundY(position, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -30, 0), params)
	return hit and hit.Position.Y or position.Y - 3
end

-- Mid-dive contact: both claws slam into them and drive them back.
local function pounceStrike(player, char, root, target)
	local victim = target.Player
	Combat.PullOut(victim)
	VFX.Anim(char, "PounceStrike")
	local dir = Util.Flat(target.Root.Position - root.Position)
	local torso = Util.Torso(target.Char) or target.Root
	Util.Sound(Config.Sounds.PounceHit, torso, { Volume = 2, Range = 200, Pitch = Config.UploadedSounds.PounceHit ~= 0 and 1 or 0.85 })
	VFX.Pierce(root, clawGlow)
	VFX.Impact(torso.Position, clawGlow, 1.3, target.Char)
	Fx:FireAllClients("PounceStrike", { Position = torso.Position, Dir = dir, Color = clawGlow })
	VFX.ExitSpray(target.Char, dir)
	VFX.Shockwave(Vector3.new(target.Root.Position.X, groundY(target.Root.Position, { char, target.Char }) + 0.2, target.Root.Position.Z), 14)
	Combat.Blood(torso, 40)
	Fx:FireAllClients("Shake", { Position = root.Position, Intensity = 1, Radius = 70 })
	-- he lands on his feet where they were standing
	Util.FireClient(Fx, player, "Knock", { Velocity = dir * 10 + Vector3.new(0, -20, 0) })
	local result = Combat.Hit(victim, true)
	if result == "kill" then
		Combat.Execute(player, victim)
	elseif result == "hit" then
		Combat.Wound(player, victim, { Force = 95, Up = 24, Dir = dir })
	end
end

local function pounce(player, char, root)
	swingTrails(1.3)
	local cfg = Config.Abilities.Pounce
	VFX.Anim(char, "Pounce")
	if Config.UploadedSounds.PounceLeap ~= 0 then
		Util.Sound(Config.Sounds.PounceLeap, root, { Volume = 1.8, Range = 160 })
	else
		Util.Sound(Config.Sounds.Slash, root, { Pitch = 0.72, Volume = 1.2 })
	end
	Fx:FireAllClients("PounceTrail", { Char = char, Color = clawGlow, Duration = cfg.AirTime })
	-- The client applies the leap; the server watches for contact.
	local launched = os.clock()
	local untilTime = launched + cfg.Window
	local blocked = false
	local stand = Util.Humanoid(char).HipHeight + root.Size.Y / 2
	task.wait(0.12)
	while os.clock() < untilTime and char.Parent and Util.IsAlive(char) do
		Combat.BreakInBox(root.CFrame * CFrame.new(0, 0, -2.5), Vector3.new(6, 8, 5), root.Position, 55)
		local target = not blocked and Combat.FindNear(root.Position, cfg.GrabRadius)[1]
		if target and Combat.BreakShield(target.Player) then
			-- pounced into their i-frames: they shatter and the pounce is spent
			-- (it still flies on through walls and lands, but grabs nobody)
			blocked = true
		elseif target then
			pounceStrike(player, char, root, target)
			return
		end
		task.wait()
		if os.clock() - launched > 0.3 and root.AssemblyLinearVelocity.Y < 1
			and root.Position.Y - groundY(root.Position, { char }) <= stand + 0.8 then
			break -- touched down without catching anyone
		end
	end
	-- whiffed: land hard
	VFX.Anim(char, "PounceLand")
	Util.Sound(Config.Sounds.Land, root, { Volume = 1.6, Pitch = 0.8 })
	local landAt = Vector3.new(root.Position.X, groundY(root.Position, { char }) + 0.2, root.Position.Z)
	VFX.Shockwave(landAt, 9)
	Fx:FireAllClients("PounceLand", { Position = landAt })
	Fx:FireAllClients("Shake", { Position = landAt, Intensity = 0.6, Radius = 50 })
end

-- Let a character go after a hold: unanchor, clear the freeze, and give
-- their client control of their own body again (bots stay server-run).
local impaling = {} -- [Wolverine] = { Player, Root } while an impale holds someone
local function release(p, r)
	if r and r.Parent and r.Anchored then
		r.Anchored = false
	end
	if p then
		Status.Clear(p, "Busy")
		Status.Clear(p, "Frozen")
		if r and r.Parent and not r.Anchored and p:IsA("Player") and not p:GetAttribute("IsBot") then
			pcall(function()
				r:SetNetworkOwner(p)
			end)
		end
	end
end

-- Uppercut impale: drive the claws up through them and hoist them overhead.
local function stab(player, char, root)
	swingTrails(1.1)
	local cfg = Config.Abilities.Stab
	VFX.Anim(char, "Impale")

	-- sweep the hitbox through the whole lunge instead of one frame
	task.wait(0.06)
	local target
	local t0 = os.clock()
	local broke = false
	repeat
		if not (char.Parent and Util.IsAlive(char)) then
			return
		end
		local cf = root.CFrame * CFrame.new(0, 0, -cfg.Range / 2 + 1)
		if not broke and os.clock() - t0 > 0.08 then
			broke = true
			Combat.BreakInBox(cf, Vector3.new(6, 9, cfg.Range), root.Position, 65)
		end
		local nearest = Combat.FindTargets(cf, Vector3.new(cfg.Width, 10, cfg.Range + 2))[1]
		if nearest and Combat.BreakShield(nearest.Player) then
			break -- impaled into their i-frames: they shatter and the impale misses
		end
		target = nearest
		if not target then
			task.wait()
		end
	until target or os.clock() - t0 > 0.3
	if not target then
		task.wait(0.3)
		VFX.StopAnim(char, "Impale")
		return
	end

	local victim = target.Player
	Combat.PullOut(victim)
	local vChar, vRoot = target.Char, target.Root
	-- a Sentinel is too heavy for one arm: both claws go in and he heaves it
	-- overhead, and the suit fights back, shocking him through his claws
	local sentinel = victim:GetAttribute("Role") == "Sentinel"
	for _, p in { player, victim } do
		Status.Apply(p, "Busy", 3.2)
		Status.Apply(p, "Frozen", 3.2)
	end
	root.Anchored = true
	vRoot.Anchored = true
	impaling[player] = { Player = victim, Root = vRoot }
	local base = CFrame.lookAt(root.Position, root.Position + Util.Flat(vRoot.Position - root.Position))
	local scale = Config.Wolverine.Scale
	root.CFrame = base
	vRoot.CFrame = base * CFrame.new(sentinel and 0 or 0.8, 0.4, sentinel and -3.2 or -2.2) * CFrame.Angles(0, math.pi, 0)
	VFX.Anim(vChar, "Impaled")
	local held
	if sentinel then
		VFX.StopAnim(char, "Impale")
		VFX.Anim(char, "ImpaleHeavy")
		held = base * CFrame.new(0, 4.4 * scale + 1.6, -1.2) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.rad(-18), 0, 0)
	else
		-- hoisted up onto the right claws as the uppercut lands
		held = base * CFrame.new(1.05 * scale, 4.8 * scale, -0.35) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.rad(-22), 0, 0)
	end
	TweenService:Create(vRoot, TweenInfo.new(sentinel and 0.3 or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = held }):Play()
	local torso = Util.Torso(vChar) or vRoot
	Util.Sound(Config.Sounds.Impale, torso, { Volume = 2.2, Range = 220, Pitch = Config.UploadedSounds.Impale ~= 0 and 1 or 0.7 })
	if sentinel then
		Util.Sound(Config.Sounds.Punch, torso, { Volume = 2, Pitch = 0.5, Range = 220 }) -- adamantium through armour plate
	else
		Util.Sound(Config.Sounds.Gore, torso, { Pitch = 0.8, Volume = 0.5 })
	end
	task.delay(0.12, function()
		Fx:FireAllClients("HitStop", { Attacker = char, Victim = vChar, Duration = 0.1 })
		VFX.Impact(torso.Position, clawGlow, 1.3)
		-- the claws punch out through their back
		Fx:FireAllClients("ImpaleBurst", { Position = torso.Position, Dir = (base.LookVector * 0.35 + Vector3.new(0, 1, 0)).Unit, Color = clawGlow, Heavy = sentinel })
		if sentinel then
			Fx:FireAllClients("Electric", { Char = vChar, Duration = 1.4 })
			Util.Burst(torso, Util.SparkProps, 60, 2)
		else
			VFX.ExitSpray(vChar, Vector3.new(0, 1, 0))
			Combat.Blood(torso, 60)
		end
	end)
	Fx:FireAllClients("Shake", { Position = root.Position, Intensity = sentinel and 1.3 or 0.9, Radius = 70 })
	Util.FireClient(Fx, victim, "Grabbed", {})

	-- held up there, bleeding (or, a Sentinel, shocking him through his claws:
	-- Config.Wolverine.ImpaleShock of his health over three zaps)
	for k = 1, 4 do
		task.wait(0.25)
		if not vChar.Parent then
			continue
		end
		if sentinel then
			if k <= 3 then
				local hum = Util.Humanoid(char)
				if hum then
					Wolverine.Damage(hum.MaxHealth * Config.Wolverine.ImpaleShock / 3, victim)
				end
				Fx:FireAllClients("Electrocute", { From = vChar, To = char, Duration = 0.3 })
				Wolverine.RevealSkeleton()
				Util.Sound(Config.Sounds.Laser, root, { Volume = 1.8, Pitch = 0.45 + math.random() * 0.15, Range = 160 })
				Util.Burst(root, Util.SparkProps, 25, 1)
			end
		else
			Combat.Blood(torso, 8)
		end
	end

	local result = Combat.Hit(victim, true)
	if result == "kill" then
		VFX.StopAnim(char, "Impale")
		VFX.StopAnim(vChar, "Impaled")
		Combat.Execute(player, victim)
	else
		-- boot them off the claws: the claws rip down out of them, the knee
		-- comes up and the kick sends them flying
		VFX.StopAnim(char, sentinel and "ImpaleHeavy" or "Impale")
		VFX.Anim(char, "ImpaleKick")
		VFX.StopAnim(vChar, "Impaled")
		if vRoot.Parent then
			-- a Sentinel is huge: set it down well clear so it can't land on him
			TweenService:Create(vRoot, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = base * CFrame.new(0, sentinel and 3 or 1.2, sentinel and -6.5 or -2.6) * CFrame.Angles(0, math.pi, 0),
			}):Play()
		end
		task.wait(0.2)
		release(victim, vRoot)
		release(player, root)
		local kickAt = (base * CFrame.new(0, 0.8, -2.2)).Position
		Fx:FireAllClients("KickImpact", { Position = kickAt, Dir = base.LookVector })
		Util.Sound(Config.Sounds.Punch, root, { Volume = 2.2, Pitch = 0.75, Range = 220 })
		Util.Sound(Config.Sounds.Impact, root, { Volume = 1.8, Pitch = 0.8, Range = 220 })
		Fx:FireAllClients("Shake", { Position = kickAt, Intensity = 1, Radius = 70 })
		Fx:FireAllClients("HitStop", { Attacker = char, Victim = vChar, Duration = 0.08 })
		for _, p in { player, victim } do
			Status.Clear(p, "Busy")
			Status.Clear(p, "Frozen")
		end
		if result == "hit" then
			Combat.Wound(player, victim, { Force = 140, Up = 38, Dir = base.LookVector })
		end
	end
end

-- The impale anchors both of them for the lift. Whatever happens in it
-- (even an error), both are always let go afterwards: unanchored, unfrozen
-- and handed back to their own client to move.
local function safeStab(player, char, root)
	local ok, err = xpcall(stab, debug.traceback, player, char, root)
	if not ok then
		warn("[Impale] " .. tostring(err))
	end
	local v = impaling[player]
	impaling[player] = nil
	if v then
		release(v.Player, v.Root)
	end
	release(player, root)
	VFX.StopAnim(char, nil)
end

local function sniff(player, root)
	local cfg = Config.Abilities.Sniff
	Util.Sound(Config.Sounds.Sniff, root, { Volume = 1.5 })
	VFX.Anim(player.Character, "Sniff")
	Util.FireClient(Fx, player, "Sniff", { Duration = cfg.Duration, Targets = Fart.SniffTargets() })
	-- keep the scents live: positions stream to his client for the whole sniff
	task.spawn(function()
		local stop = os.clock() + cfg.Duration
		while os.clock() < stop and Round.Wolverine == player and player.Parent do
			task.wait(0.12)
			Util.FireClient(Fx, player, "SniffUpdate", { Targets = Fart.SniffTargets() })
		end
	end)
	for survivor in Round.Survivors do
		Util.FireClient(Fx, survivor, "Sniffed", {})
	end
end

-- How hard he's fighting the beam right now: presses in the last second
-- against Config.Sentinel.Laser.Resist.Presses, 0..1.
local resistPresses = {}
function Wolverine.ResistLevel()
	local now = os.clock()
	while resistPresses[1] and now - resistPresses[1] > 1 do
		table.remove(resistPresses, 1)
	end
	return math.clamp(#resistPresses / Config.Sentinel.Laser.Resist.Presses, 0, 1)
end

function Wolverine.Handle(player, ability, arg)
	if player ~= Round.Wolverine or not Round.Released then
		return
	end
	if ability == "Feral" then
		Movement.SetInput(player, "Feral", arg == true)
		return
	end
	if ability == "Resist" then
		-- mashing R under a death ray (see Wolverine.ResistLevel)
		local now = os.clock()
		if now - (resistPresses[#resistPresses] or 0) >= 0.045 then
			table.insert(resistPresses, now)
		end
		return
	end
	local char = player.Character
	local root = Util.Root(char)
	if not (root and Util.IsAlive(char)) then
		return
	end
	if Status.Has(player, "Busy") or Status.Has(player, "Stunned") or Status.Has(player, "Frozen") or Status.Has(player, "Gassed") then
		return
	end
	local cfg = Config.Abilities[ability]
	if not cfg then
		return
	end
	local cd = cooldowns[player]
	if not cd then
		cd = {}
		cooldowns[player] = cd
	end
	if (cd[ability] or 0) > os.clock() then
		return
	end
	if ability == "Pounce" and not Movement.IsFeral(player) then
		return -- he can only pounce out of an all-fours sprint
	end
	cd[ability] = os.clock() + cfg.Cooldown * rageScale(player, ability) - 0.1 -- small latency allowance

	if ability == "Slash" then
		slash(player, char, root)
	elseif ability == "Pounce" then
		task.spawn(pounce, player, char, root)
	elseif ability == "Stab" then
		task.spawn(safeStab, player, char, root)
	elseif ability == "Sniff" then
		sniff(player, root)
	end
end

-- Posed display statue for the lobby's suit gallery.
function Wolverine.MakeStatue(skinId, cframe, parent)
	local desc = Instance.new("HumanoidDescription")
	local tone = Color3.fromRGB(226, 176, 140)
	desc.HeadColor = tone
	desc.LeftArmColor = tone
	desc.RightArmColor = tone
	desc.TorsoColor = tone
	desc.LeftLegColor = tone
	desc.RightLegColor = tone
	local ok, model = pcall(function()
		return game:GetService("Players"):CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return nil
	end
	model.Name = "Statue_" .. skinId
	local hum = Util.Humanoid(model)
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	model.Parent = parent
	dressUp(model, skinId)
	local menace = model:FindFirstChild("Menace")
	if menace then
		menace:Destroy()
	end
	pcall(function()
		model:ScaleTo(1.25)
	end)
	-- every claw skin is built onto the statue; each player's client shows only
	-- the claws they have equipped (Shop.lua). Others see the default claws.
	for _, clawId in Skins.ClawOrder do
		Costumes.BuildClaws(model, Skins.Claws[clawId], true, true)
		local folder = model:FindFirstChild("Claws")
		for _, p in folder and folder:GetChildren() or {} do
			if p:IsA("BasePart") and p:GetAttribute("ClawSkin") == nil then
				p:SetAttribute("ClawSkin", clawId)
				p:SetAttribute("BaseT", p.Transparency)
				if clawId ~= Skins.DefaultClaw then
					p.Transparency = 1
				end
			end
		end
	end
	CollectionService:AddTag(model, "SkinStatue")
	-- Crouched, arms flared, claws out
	Posture.Set(model, "Root", CFrame.new(0, -0.3, 0) * CFrame.Angles(math.rad(-14), 0, 0))
	Posture.Set(model, "Neck", CFrame.Angles(math.rad(12), 0, 0))
	Posture.Set(model, "RShoulder", CFrame.Angles(math.rad(45), 0, math.rad(50)))
	Posture.Set(model, "LShoulder", CFrame.Angles(math.rad(45), 0, math.rad(-50)))
	Posture.Set(model, "RHip", CFrame.Angles(math.rad(28), 0, math.rad(8)))
	Posture.Set(model, "LHip", CFrame.Angles(math.rad(-12), 0, math.rad(-8)))
	local root = Util.Root(model)
	model:PivotTo(cframe * CFrame.new(0, 3.9, 0))
	if root then
		root.Anchored = true
	end
	return model
end

-- Called by the Sentinel.
function Wolverine.Damage(amount, by)
	local player = Round.Wolverine
	local char = player and player.Character
	local hum, root = Util.Humanoid(char), Util.Root(char)
	if not (hum and root) or hum.Health <= 0 then
		return
	end
	lastDamaged = os.clock()
	hum:TakeDamage(amount)
	if hum.Health <= 0 and by and not Round.WolverineKiller then
		Round.WolverineKiller = by -- credited with the takedown
	end
	Fx:FireAllClients("HitStop", { Victim = char, Duration = 0 })
	Util.Burst(root, Util.SparkProps, 25, 1.5) -- adamantium skeleton sparks
end

---------------------------------------------------------------------------
-- Healing factor. (Running no longer tears through walls: he claws, pounces
-- or impales his way through them.)
---------------------------------------------------------------------------

-- Rage (Config.Rage): a red aura everyone can see, fire licking off him, a
-- red glow and his outline flaring red, for Duration seconds.
local RAGE_RED = Color3.fromRGB(255, 30, 20)
local function rageAura(char, on)
	local torso = Util.Torso(char)
	local menace = char:FindFirstChild("Menace")
	if menace then
		menace.FillColor = on and RAGE_RED or Color3.fromRGB(170, 0, 0)
		menace.FillTransparency = on and 0.7 or 1
		menace.OutlineColor = on and RAGE_RED or Color3.fromRGB(170, 0, 0)
		menace.OutlineTransparency = on and 0 or 0.35
	end
	for _, d in char:GetDescendants() do
		if d.Name == "RageAura" then
			d:Destroy()
		end
	end
	if not (on and torso) then
		return
	end
	local fire = Instance.new("ParticleEmitter")
	fire.Name = "RageAura"
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 70, 30), Color3.fromRGB(120, 0, 0))
	fire.LightEmission = 1
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6), NumberSequenceKeypoint.new(1, 0.4) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime = NumberRange.new(0.45, 0.8)
	fire.Rate = 70
	fire.Speed = NumberRange.new(2, 5)
	fire.SpreadAngle = Vector2.new(35, 35)
	fire.Acceleration = Vector3.new(0, 9, 0)
	fire.RotSpeed = NumberRange.new(-90, 90)
	fire.Rotation = NumberRange.new(0, 360)
	fire.EmissionDirection = Enum.NormalId.Top
	fire.Shape = Enum.ParticleEmitterShape.Box
	fire.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	fire.Parent = torso
	local embers = fire:Clone()
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 120, 60))
	embers.Size = NumberSequence.new(0.35, 0)
	embers.Lifetime = NumberRange.new(0.6, 1.1)
	embers.Rate = 25
	embers.Speed = NumberRange.new(4, 9)
	embers.Parent = torso
	local light = Instance.new("PointLight")
	light.Name = "RageAura"
	light.Color = RAGE_RED
	light.Brightness = 3
	light.Range = 16
	light.Parent = torso
end

-- He snaps when he drops below the threshold: at most MaxPerGame times a
-- round, and only once per dip (he has to get back above the line first).
updateRage = function(player, char, hum)
	local cfg = Config.Rage
	local now = os.clock()
	if player:GetAttribute("Rage") and now >= rage.Until then
		player:SetAttribute("Rage", false)
		rageAura(char, false)
		Util.FireClient(Fx, player, "Announce", { Text = "THE RAGE FADES", Color = Color3.fromRGB(200, 120, 120), Duration = 2 })
	end
	if hum.Health / hum.MaxHealth >= cfg.Threshold then
		rage.Armed = true
	elseif rage.Armed and rage.Count < cfg.MaxPerGame and not player:GetAttribute("Rage") then
		rage.Armed = false
		rage.Count += 1
		rage.Until = now + cfg.Duration
		player:SetAttribute("Rage", true)
		player:SetAttribute("RageEnds", workspace:GetServerTimeNow() + cfg.Duration)
		rageAura(char, true)
		local root = Util.Root(char)
		if root then
			Util.Sound(Config.Sounds.Roar, root, { Volume = 2.6, Pitch = 0.85, Range = 400 })
			VFX.Shockwave(root.Position - Vector3.new(0, 2.8, 0), 22, RAGE_RED)
			Fx:FireAllClients("Shake", { Position = root.Position, Intensity = 1, Radius = 90 })
		end
		Fx:FireAllClients("Announce", { Text = "WOLVERINE IS ENRAGED!", Color = RAGE_RED, Duration = 3 })
	end
end

RunService.Heartbeat:Connect(function(dt)
	local player = Round.Wolverine
	if not (player and Round.Active) then
		return
	end
	local char = player.Character
	local hum, root = Util.Humanoid(char), Util.Root(char)
	if not (hum and root) or hum.Health <= 0 then
		return
	end

	updateRage(player, char, hum)
	if os.clock() - lastDamaged > Config.Wolverine.HealDelay and hum.Health < hum.MaxHealth then
		hum.Health = math.min(hum.MaxHealth, hum.Health + Config.Wolverine.HealPerSecond * dt)
	end
end)

return Wolverine
