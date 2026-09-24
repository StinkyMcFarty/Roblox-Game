-- Wolverine: transformation, intro (SNIKT + roar), abilities, healing factor
-- and tearing through walls while he runs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

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
local Skins = require(ReplicatedStorage.Shared.Skins)

local Fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx")

local Wolverine = {}

local YELLOW = Color3.fromRGB(245, 195, 20)
local BLACK = Color3.fromRGB(20, 20, 24)
local STEEL = Color3.fromRGB(210, 214, 222)
local CLAW_LEN = 2.3

local cooldowns = {}
local lastDamaged = 0
local lastShredFx = 0
local combo = 0
local claws = {}
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

local SLOT_PARTS = {
	UpperTorso = { "UpperTorso", "Torso" },
	LowerTorso = { "LowerTorso" },
	UpperArm = { "RightUpperArm", "LeftUpperArm", "Right Arm", "Left Arm" },
	LowerArm = { "RightLowerArm", "LeftLowerArm" },
	Hand = { "RightHand", "LeftHand" },
	UpperLeg = { "RightUpperLeg", "LeftUpperLeg", "Right Leg", "Left Leg" },
	LowerLeg = { "RightLowerLeg", "LeftLowerLeg" },
	Foot = { "RightFoot", "LeftFoot" },
}

local function comicCowl(char, head, hs)
	gearPart(char, head, "Cowl", Vector3.new(hs.X * 1.06, hs.Y * 0.55, hs.Z * 1.06), YELLOW, nil, CFrame.new(0, hs.Y * 0.25, 0))
	gearPart(char, head, "MaskBand", Vector3.new(hs.X * 1.08, hs.Y * 0.24, hs.Z * 1.08), BLACK, nil, CFrame.new(0, hs.Y * 0.07, 0))
	for s = -1, 1, 2 do
		gearPart(char, head, "Fin", Vector3.new(0.12, hs.Y * 0.8, hs.Z * 0.55), BLACK, nil,
			CFrame.new(s * hs.X * 0.5, hs.Y * 0.55, hs.Z * 0.05) * CFrame.Angles(0, 0, math.rad(-s * 18)))
		gearPart(char, head, "Eye", Vector3.new(hs.X * 0.24, hs.Y * 0.08, 0.05), Color3.new(1, 1, 1), Enum.Material.Neon,
			CFrame.new(s * hs.X * 0.2, hs.Y * 0.08, -hs.Z * 0.55) * CFrame.Angles(0, 0, math.rad(s * 12)))
	end
	-- black tiger stripes on the torso
	local torso = Util.Torso(char)
	if torso then
		local ts = torso.Size
		for s = -1, 1, 2 do
			for i = 0, 1 do
				gearPart(char, torso, "Stripe", Vector3.new(0.05, ts.Y * 0.12, ts.Z * 0.6), BLACK, nil,
					CFrame.new(s * ts.X * 0.51, ts.Y * (0.15 - i * 0.3), 0) * CFrame.Angles(0, 0, math.rad(s * 25)))
			end
		end
	end
end

local function sideburns(char, head, hs, color)
	for s = -1, 1, 2 do
		gearPart(char, head, "Sideburn", Vector3.new(0.1, hs.Y * 0.45, hs.Z * 0.35), color, Enum.Material.Fabric,
			CFrame.new(s * hs.X * 0.5, -hs.Y * 0.05, hs.Z * 0.05))
		-- the famous hair "horns"
		gearPart(char, head, "HairPoint", Vector3.new(hs.X * 0.18, hs.Y * 0.45, hs.Z * 0.3), color, Enum.Material.Fabric,
			CFrame.new(s * hs.X * 0.32, hs.Y * 0.58, 0) * CFrame.Angles(0, 0, math.rad(-s * 28)))
	end
end

local function loganJacket(char)
	local torso = Util.Torso(char)
	if not torso then
		return
	end
	local ts = torso.Size
	local leather = Color3.fromRGB(92, 60, 38)
	for s = -1, 1, 2 do
		gearPart(char, torso, "Jacket", Vector3.new(ts.X * 0.3, ts.Y * 1.02, ts.Z * 1.1), leather, Enum.Material.Leather,
			CFrame.new(s * ts.X * 0.37, 0, 0))
	end
	gearPart(char, torso, "Collar", Vector3.new(ts.X * 1.05, ts.Y * 0.18, ts.Z * 1.15), leather, Enum.Material.Leather,
		CFrame.new(0, ts.Y * 0.46, 0))
end

local function weaponXRig(char, head, hs)
	local metal = Color3.fromRGB(110, 115, 125)
	gearPart(char, head, "Helmet", Vector3.new(hs.X * 1.1, hs.Y * 0.45, hs.Z * 1.1), metal, Enum.Material.DiamondPlate,
		CFrame.new(0, hs.Y * 0.33, 0))
	local visor = gearPart(char, head, "Eye", Vector3.new(hs.X * 0.8, hs.Y * 0.07, 0.05), Color3.fromRGB(120, 255, 200), Enum.Material.Neon,
		CFrame.new(0, hs.Y * 0.12, -hs.Z * 0.56))
	visor.Name = "Eye"
	-- cables trailing from the helmet down the back
	for i = -1, 1 do
		gearPart(char, head, "Cable", Vector3.new(0.08, hs.Y * 1.3, 0.08), BLACK, Enum.Material.Rubber,
			CFrame.new(i * hs.X * 0.22, -hs.Y * 0.1, hs.Z * 0.58) * CFrame.Angles(math.rad(-15), 0, 0))
	end
	-- surgical scars / wires on the arms and chest
	for _, n in { "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm", "Right Arm", "Left Arm" } do
		local limb = char:FindFirstChild(n)
		if limb then
			for j = -1, 1, 2 do
				gearPart(char, limb, "Band", limb.Size * Vector3.new(1.08, 0.08, 1.08), BLACK, Enum.Material.Rubber,
					CFrame.new(0, j * limb.Size.Y * 0.25, 0))
			end
		end
	end
	local torso = Util.Torso(char)
	if torso then
		local ts = torso.Size
		for i = -1, 1 do
			gearPart(char, torso, "Scar", Vector3.new(0.08, ts.Y * 0.7, 0.05), Color3.fromRGB(150, 40, 40), nil,
				CFrame.new(i * ts.X * 0.18, 0, -ts.Z * 0.51) * CFrame.Angles(0, 0, math.rad(20)))
		end
	end
end

local function oldManGear(char, head, hs)
	local grey = Color3.fromRGB(175, 175, 172)
	gearPart(char, head, "Hair", Vector3.new(hs.X * 1.04, hs.Y * 0.35, hs.Z * 1.04), grey, Enum.Material.Fabric,
		CFrame.new(0, hs.Y * 0.36, hs.Z * 0.02))
	gearPart(char, head, "Beard", Vector3.new(hs.X * 0.95, hs.Y * 0.42, hs.Z * 0.5), grey, Enum.Material.Fabric,
		CFrame.new(0, -hs.Y * 0.3, -hs.Z * 0.3))
	gearPart(char, head, "Moustache", Vector3.new(hs.X * 0.55, hs.Y * 0.08, 0.12), grey, Enum.Material.Fabric,
		CFrame.new(0, -hs.Y * 0.08, -hs.Z * 0.52))
	sideburns(char, head, hs, grey)
	-- long coat tails
	local lower = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")
	if lower then
		local ls = lower.Size
		gearPart(char, lower, "CoatTail", Vector3.new(ls.X * 1.12, ls.Y * 3.2, ls.Z * 1.15), Color3.fromRGB(60, 44, 34), Enum.Material.Leather,
			CFrame.new(0, -ls.Y * 1.4, ls.Z * 0.05))
	end
end

local function dressUp(char, skinId)
	local skin = Skins.List[skinId] or Skins.List[Skins.Default]
	local head = char:FindFirstChild("Head")
	local skinTone = head and head.Color or Color3.fromRGB(230, 180, 140)
	for _, d in char:GetChildren() do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("BodyColors") then
			d:Destroy()
		elseif d:IsA("Accessory") and not (skin.KeepHair and d.AccessoryType == Enum.AccessoryType.Hair) then
			d:Destroy()
		end
	end
	for slot, names in SLOT_PARTS do
		local color = skin.Colors[slot]
		if color == "Skin" then
			color = skinTone
		end
		for _, name in names do
			local p = char:FindFirstChild(name)
			if p and p:IsA("BasePart") and color then
				p.Color = color
				local sa = p:FindFirstChildOfClass("SurfaceAppearance")
				if sa then
					sa:Destroy()
				end
				if p:IsA("MeshPart") then
					pcall(function()
						p.TextureID = ""
					end)
				end
			end
		end
	end

	if head then
		local hs = head.Size
		if skinId == "Comic" then
			comicCowl(char, head, hs)
		elseif skinId == "WeaponX" then
			weaponXRig(char, head, hs)
		elseif skinId == "OldManLogan" then
			oldManGear(char, head, hs)
		else
			sideburns(char, head, hs, Color3.fromRGB(35, 25, 20))
			loganJacket(char)
		end
		-- Every skin gets faint glowing eyes so he reads as a monster in the dark
		if skinId ~= "Comic" and skinId ~= "WeaponX" then
			for s = -1, 1, 2 do
				gearPart(char, head, "Eye", Vector3.new(hs.X * 0.12, hs.Y * 0.05, 0.04), Color3.fromRGB(255, 235, 200), Enum.Material.Neon,
					CFrame.new(s * hs.X * 0.18, hs.Y * 0.1, -hs.Z * 0.5))
			end
		end
	end

	local hl = Instance.new("Highlight")
	hl.Name = "Menace"
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.fromRGB(170, 0, 0)
	hl.OutlineTransparency = 0.25
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = char
end

local function makeClaws(char, clawId)
	claws = {}
	clawSkin = Skins.Claws[clawId] or Skins.Claws[Skins.DefaultClaw]
	clawGlow = clawSkin.Glow
	local thick = clawSkin.Thick or 1
	for _, side in { "Right", "Left" } do
		local hand = Util.Hand(char, side)
		if hand then
			for i = -1, 1 do
				local z = i * math.max(0.1, hand.Size.Z * 0.3)
				local c, w = gearPart(char, hand, "Claw", Vector3.new(0.07 * thick, 0.1, 0.16 * thick), clawSkin.Color, clawSkin.Material, CFrame.new(0, 0, z))
				c.Reflectance = clawSkin.Reflectance
				c.Transparency = 1
				table.insert(claws, { Part = c, Weld = w, Z = z, Hand = hand })
			end
		end
	end
end

local function popClaws(char)
	local info = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	for _, c in claws do
		if c.Part.Parent then
			c.Part.Transparency = 0
			local thick = clawSkin and clawSkin.Thick or 1
			TweenService:Create(c.Part, info, { Size = Vector3.new(0.07 * thick, CLAW_LEN, 0.16 * thick) }):Play()
			TweenService:Create(c.Weld, info, { C0 = CFrame.new(0, -(c.Hand.Size.Y * 0.3 + CLAW_LEN / 2), c.Z) }):Play()
			-- Streaking trail off every blade: every swing leaves a crisp arc
			task.delay(0.2, function()
				if not c.Part.Parent then
					return
				end
				local a0 = Instance.new("Attachment")
				a0.Position = Vector3.new(0, CLAW_LEN * 0.1, 0)
				a0.Parent = c.Part
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(0, -CLAW_LEN / 2, 0)
				a1.Parent = c.Part
				local trail = Instance.new("Trail")
				trail.Attachment0 = a0
				trail.Attachment1 = a1
				trail.Lifetime = 0.14
				trail.MinLength = 0.05
				trail.LightEmission = 1
				trail.Color = ColorSequence.new(Color3.new(1, 1, 1), clawGlow)
				trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
				trail.Parent = c.Part
				if clawSkin and (clawSkin.Drip or clawSkin.Sparkle) then
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
				if clawSkin and clawSkin.Material == Enum.Material.Neon then
					local l = Instance.new("PointLight")
					l.Color = clawGlow
					l.Range = 6
					l.Brightness = 1
					l.Parent = c.Part
				end
			end)
		end
	end
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

local function roar(char)
	local head = char:FindFirstChild("Head")
	local root = Util.Root(char)
	if not (head and root) then
		return
	end
	Posture.Roar(char)
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
	task.delay(1.8, function()
		Posture.RestoreAll(char, 0.3)
	end)
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
			p.Transparency = 0.85
		end
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

function Wolverine.Transform(player, spawnCFrame)
	local char = player.Character
	if not char then
		return
	end
	player:SetAttribute("Role", "Wolverine")
	cooldowns[player] = {}
	combo = 0
	lastDamaged = 0
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

	task.delay(Config.ClawPopTime, function()
		if valid() then
			popClaws(char)
		end
	end)
	task.delay(Config.RoarTime, function()
		if valid() then
			roar(char)
		end
	end)
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

local function slash(player, char, root)
	combo = combo % 2 + 1
	local side = combo == 1 and "R" or "L"
	Posture.Swipe(char, side)
	clawStreaks(root, side)
	Util.Sound(Config.Sounds.Slash, root, { Pitch = 0.9 + math.random() * 0.25, Volume = 1.2 })
	local cfg = Config.Abilities.Slash
	local cf = root.CFrame * CFrame.new(0, 0, -cfg.Range / 2)
	Combat.BreakInBox(cf, Vector3.new(cfg.Width, 9, cfg.Range), root.Position, 35)
	local target = Combat.FindTargets(cf, Vector3.new(cfg.Width, 8, cfg.Range + 1))[1]
	if target then
		Combat.Resolve(player, target.Player)
	end
end

local function groundY(position, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -30, 0), params)
	return hit and hit.Position.Y or position.Y - 3
end

-- Pinned to the ground and clawed at.
local function pin(player, victim)
	local kChar, vChar = player.Character, victim.Character
	local kRoot, vRoot = Util.Root(kChar), Util.Root(vChar)
	if not (kRoot and vRoot) then
		return
	end
	Combat.PullOut(victim)
	for _, p in { player, victim } do
		Status.Apply(p, "Busy", 4)
		Status.Apply(p, "Frozen", 4)
	end
	local look = Util.Flat(vRoot.Position - kRoot.Position)
	local y = groundY(vRoot.Position, { kChar, vChar })
	local base = CFrame.lookAt(Vector3.new(vRoot.Position.X, y, vRoot.Position.Z), Vector3.new(vRoot.Position.X, y, vRoot.Position.Z) + look)
	kRoot.Anchored = true
	vRoot.Anchored = true
	vRoot.CFrame = base * CFrame.new(0, 1, 0) * CFrame.Angles(math.rad(90), 0, 0)
	kRoot.CFrame = base * CFrame.new(0, 2.6, 1.6)
	Posture.Set(kChar, "Root", CFrame.Angles(math.rad(-45), 0, 0), 0.12)
	Util.Sound(Config.Sounds.Land, kRoot, { Volume = 2, Pitch = 0.7 })
	VFX.Shockwave(Vector3.new(vRoot.Position.X, y + 0.2, vRoot.Position.Z), 12)
	Fx:FireAllClients("Shake", { Position = kRoot.Position, Intensity = 0.8, Radius = 60 })
	Util.FireClient(Fx, victim, "Grabbed", {})

	for i = 1, 3 do
		task.wait(0.28)
		if not (vChar.Parent and kChar.Parent) then
			break
		end
		local side = i % 2 == 1 and "R" or "L"
		Posture.Swipe(kChar, side)
		Util.Sound(Config.Sounds.Slash, vRoot, { Pitch = 0.8 + i * 0.1, Volume = 1.3 })
		Combat.Blood(Util.Torso(vChar), 18)
		local vt = Util.Torso(vChar)
		if vt then
			VFX.Impact(vt.Position, clawGlow, 0.7)
		end
		Util.FireClient(Fx, victim, "Shake", { Position = vRoot.Position, Intensity = 0.5, Radius = 10 })
	end
	task.wait(0.2)

	Posture.Restore(kChar, "Root", 0.15)
	local result = Combat.Hit(victim, true)
	if result == "kill" then
		kRoot.CFrame = base * CFrame.new(0, 2.6, 3)
		Combat.Execute(player, victim)
	else
		if vRoot.Parent then
			vRoot.Anchored = false
			vRoot.CFrame = base * CFrame.new(0, 3, 0)
		end
		if kRoot.Parent then
			kRoot.Anchored = false
		end
		for _, p in { player, victim } do
			Status.Clear(p, "Busy")
			Status.Clear(p, "Frozen")
		end
		if result == "hit" then
			Combat.Wound(player, victim)
		end
	end
end

local function pounce(player, char, root)
	local cfg = Config.Abilities.Pounce
	Util.Sound(Config.Sounds.Lunge, root, { Pitch = 0.65, Volume = 1.6 })
	Posture.ArmsForward(char, 0.1)
	-- The client applies the leap; the server watches for contact.
	local untilTime = os.clock() + cfg.Window
	while os.clock() < untilTime and char.Parent and Util.IsAlive(char) do
		Combat.BreakInBox(root.CFrame * CFrame.new(0, 0, -2.5), Vector3.new(6, 8, 5), root.Position, 55)
		local target = Combat.FindNear(root.Position, cfg.GrabRadius)[1]
		if target and not Status.Has(target.Player, "Immune") then
			pin(player, target.Player)
			return
		end
		task.wait()
	end
	Posture.RestoreAll(char, 0.2)
end

local function stab(player, char, root)
	local cfg = Config.Abilities.Stab
	Util.Sound(Config.Sounds.Lunge, root, { Pitch = 0.9, Volume = 1.4 })
	Posture.ArmsForward(char, 0.08)
	task.wait(0.14)
	if not (char.Parent and Util.IsAlive(char)) then
		return
	end
	local cf = root.CFrame * CFrame.new(0, 0, -cfg.Range / 2)
	Combat.BreakInBox(cf, Vector3.new(6, 9, cfg.Range), root.Position, 65)
	local target = Combat.FindTargets(cf, Vector3.new(6, 8, cfg.Range + 1))[1]
	if not target or Status.Has(target.Player, "Immune") then
		task.wait(0.25)
		Posture.RestoreAll(char, 0.2)
		return
	end

	-- Impaled on both sets of claws and lifted
	local victim = target.Player
	Combat.PullOut(victim)
	local vRoot = target.Root
	for _, p in { player, victim } do
		Status.Apply(p, "Busy", 3)
		Status.Apply(p, "Frozen", 3)
	end
	root.Anchored = true
	vRoot.Anchored = true
	local base = CFrame.lookAt(root.Position, root.Position + Util.Flat(vRoot.Position - root.Position))
	root.CFrame = base
	vRoot.CFrame = base * CFrame.new(0, 0.8, -2.8) * CFrame.Angles(0, math.pi, 0)
	TweenService:Create(vRoot, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		CFrame = base * CFrame.new(0, 2.6, -2.6) * CFrame.Angles(math.rad(-15), math.pi, 0),
	}):Play()
	Posture.Set(char, "RShoulder", CFrame.Angles(math.rad(115), 0, 0), 0.3)
	Posture.Set(char, "LShoulder", CFrame.Angles(math.rad(115), 0, 0), 0.3)
	Util.Sound(Config.Sounds.Slash, vRoot, { Pitch = 0.6, Volume = 1.6 })
	Util.Sound(Config.Sounds.Gore, vRoot, { Pitch = 0.6, Volume = 1.2 })
	Combat.Blood(Util.Torso(target.Char), 45)
	VFX.Pierce(root, clawGlow)
	VFX.ExitSpray(target.Char, base.LookVector)
	VFX.Impact(vRoot.Position + Vector3.new(0, 1, 0), clawGlow, 1.1)
	Fx:FireAllClients("Shake", { Position = root.Position, Intensity = 0.7, Radius = 60 })
	Util.FireClient(Fx, victim, "Grabbed", {})
	task.wait(0.65)

	local result = Combat.Hit(victim, true)
	if result == "kill" then
		Combat.Execute(player, victim)
	else
		if vRoot.Parent then
			vRoot.Anchored = false
		end
		if root.Parent then
			root.Anchored = false
		end
		for _, p in { player, victim } do
			Status.Clear(p, "Busy")
			Status.Clear(p, "Frozen")
		end
		Posture.RestoreAll(char, 0.2)
		if result == "hit" then
			Combat.Wound(player, victim)
		end
	end
end

local function sniff(player, root)
	local cfg = Config.Abilities.Sniff
	Util.Sound(Config.Sounds.Sniff, root, { Volume = 1.5 })
	Util.FireClient(Fx, player, "Sniff", { Duration = cfg.Duration, Targets = Fart.SniffTargets() })
	for survivor in Round.Survivors do
		Util.FireClient(Fx, survivor, "Sniffed", {})
	end
end

function Wolverine.Handle(player, ability, arg)
	if player ~= Round.Wolverine or not Round.Released then
		return
	end
	if ability == "Feral" then
		Movement.SetInput(player, "Feral", arg == true)
		return
	end
	local char = player.Character
	local root = Util.Root(char)
	if not (root and Util.IsAlive(char)) then
		return
	end
	if Status.Has(player, "Busy") or Status.Has(player, "Stunned") or Status.Has(player, "Frozen") then
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
	cd[ability] = os.clock() + cfg.Cooldown - 0.1 -- small latency allowance

	if ability == "Slash" then
		slash(player, char, root)
	elseif ability == "Pounce" then
		task.spawn(pounce, player, char, root)
	elseif ability == "Stab" then
		task.spawn(stab, player, char, root)
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
	local claw = Skins.Claws[Skins.DefaultClaw]
	for _, side in { "Right", "Left" } do
		local hand = Util.Hand(model, side)
		if hand then
			for i = -1, 1 do
				local z = i * math.max(0.1, hand.Size.Z * 0.3)
				local c = gearPart(model, hand, "Claw", Vector3.new(0.08, CLAW_LEN * 1.25, 0.18), claw.Color, claw.Material,
					CFrame.new(0, -(hand.Size.Y * 0.3 + CLAW_LEN * 0.62), z))
				c.Reflectance = claw.Reflectance
			end
		end
	end
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
function Wolverine.Damage(amount)
	local player = Round.Wolverine
	local char = player and player.Character
	local hum, root = Util.Humanoid(char), Util.Root(char)
	if not (hum and root) or hum.Health <= 0 then
		return
	end
	lastDamaged = os.clock()
	hum:TakeDamage(amount)
	Util.Burst(root, Util.SparkProps, 25, 1.5) -- adamantium skeleton sparks
end

---------------------------------------------------------------------------
-- Healing factor + running through walls
---------------------------------------------------------------------------

local shredClock = 0
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

	if os.clock() - lastDamaged > Config.Wolverine.HealDelay and hum.Health < hum.MaxHealth then
		hum.Health = math.min(hum.MaxHealth, hum.Health + Config.Wolverine.HealPerSecond * dt)
	end

	shredClock += dt
	if shredClock < 0.1 or not Round.Released or Status.Has(player, "Busy") or Status.Has(player, "Stunned") then
		return
	end
	shredClock = 0

	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local dir
	if flat.Magnitude > Config.Wolverine.ShredSpeed then
		dir = flat.Unit
	elseif Movement.IsCharging(player) and hum.MoveDirection.Magnitude > 0.5 then
		dir = Util.Flat(hum.MoveDirection)
	end
	if dir then
		local cf = CFrame.lookAt(root.Position, root.Position + dir) * CFrame.new(0, 0.5, -3)
		local broke = Combat.BreakInBox(cf, Vector3.new(5.5, 9, 4), root.Position, 45)
		if broke > 0 and os.clock() - lastShredFx > 0.3 then
			lastShredFx = os.clock()
			combo = combo % 2 + 1
			local side = combo == 1 and "R" or "L"
			if not player:GetAttribute("Feral") then
				Posture.Swipe(char, side)
			end
			clawStreaks(root, side)
			Fx:FireAllClients("Shake", { Position = root.Position, Intensity = 0.5, Radius = 50 })
		end
	end
end)

return Wolverine
