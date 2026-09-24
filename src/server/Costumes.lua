-- Everything that makes characters look good: Wolverine suits (textures +
-- sculpted 3D gear), the claws, and the Sentinel armour.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Skins = require(ReplicatedStorage.Shared.Skins)
local Util = require(ReplicatedStorage.Shared.Util)

local Costumes = {}

local rgb = Color3.fromRGB
local rad = math.rad
local M = Enum.Material

Costumes.CLAW_LEN = 2.6

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function folderFor(char, name)
	local f = char:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = char
	end
	return f
end

-- Welded cosmetic part. `props` can set Shape/Mesh/etc.
function Costumes.Gear(char, anchor, name, size, color, material, offset, props, folderName)
	local p = Instance.new(props and props.Class or "Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	if props then
		for k, v in props do
			if k ~= "Class" and k ~= "Mesh" then
				p[k] = v
			end
		end
		if props.Mesh then
			local m = Instance.new("SpecialMesh")
			m.MeshType = props.Mesh
			m.Parent = p
		end
	end
	p.CFrame = anchor.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = anchor
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	p.Parent = folderFor(char, folderName or "Gear")
	return p, w
end
local gear = Costumes.Gear

-- A cable made of short segments through `points` (in anchor space).
local function cable(char, anchor, points, thickness, color)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		if len > 0.01 then
			gear(char, anchor, "Cable", Vector3.new(thickness, thickness, len + thickness * 0.5), color or rgb(18, 18, 20), M.Rubber,
				CFrame.lookAt((a + b) / 2, b))
		end
	end
end

-- Cable spiralling around a limb.
local function wrap(char, limb, turns, thickness, yTop, yBottom)
	if not limb then
		return
	end
	local s = limb.Size
	local r = math.max(s.X, s.Z) * 0.56
	local pts = {}
	local steps = math.floor(turns * 10)
	for k = 0, steps do
		local t = k / steps
		local a = t * turns * math.pi * 2
		local y = s.Y * (yTop + (yBottom - yTop) * t)
		table.insert(pts, Vector3.new(math.cos(a) * r, y, math.sin(a) * r))
	end
	cable(char, limb, pts, thickness)
end

local function strap(char, anchor, a, b, width, color)
	local len = (b - a).Magnitude
	return gear(char, anchor, "Strap", Vector3.new(width, 0.08, len), color or rgb(30, 26, 22), M.Leather, CFrame.lookAt((a + b) / 2, b))
end

---------------------------------------------------------------------------
-- Wolverine suits
---------------------------------------------------------------------------

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

local function asset(id)
	return (id and id ~= 0 and id ~= "") and ("rbxassetid://" .. tostring(id)) or nil
end

local function comicGear(char, head)
	local YEL, BLU, BLK = rgb(238, 184, 20), rgb(28, 56, 140), rgb(18, 18, 22)
	if head then
		local hs = head.Size
		head.Color = YEL
		-- sculpted cowl over the top of the head
		gear(char, head, "Cowl", Vector3.new(hs.X * 1.1, hs.Y * 0.55, hs.Z * 1.1), YEL, M.SmoothPlastic,
			CFrame.new(0, hs.Y * 0.38, hs.Z * 0.02), { Mesh = Enum.MeshType.Sphere })
		-- the iconic swept-back fins
		for s = -1, 1, 2 do
			gear(char, head, "Fin", Vector3.new(0.1, hs.Y * 0.95, hs.Z * 0.62), BLK, M.SmoothPlastic,
				CFrame.new(s * hs.X * 0.47, hs.Y * 0.62, hs.Z * 0.12) * CFrame.Angles(rad(-12), 0, rad(-s * 16)),
				{ Class = "WedgePart" })
		end
	end
	-- rounded blue shoulder pads
	for _, n in { "RightUpperArm", "LeftUpperArm" } do
		local arm = char:FindFirstChild(n)
		if arm then
			local s = arm.Size
			local side = n:sub(1, 5) == "Right" and 1 or -1
			gear(char, arm, "ShoulderPad", Vector3.new(s.X * 1.9, s.Y * 0.62, s.Z * 1.9), BLU, M.SmoothPlastic,
				CFrame.new(side * s.X * 0.12, s.Y * 0.3, 0), { Mesh = Enum.MeshType.Sphere })
			gear(char, arm, "PadTrim", Vector3.new(s.X * 1.95, 0.06, s.Z * 1.95), BLK, M.SmoothPlastic,
				CFrame.new(side * s.X * 0.12, s.Y * 0.05, 0), { Mesh = Enum.MeshType.Sphere })
		end
	end
	-- 3D belt + buckle
	local lower = char:FindFirstChild("LowerTorso")
	if lower then
		local s = lower.Size
		gear(char, lower, "Belt", Vector3.new(s.X * 1.06, s.Y * 0.28, s.Z * 1.08), rgb(170, 26, 30), M.Leather, CFrame.new(0, s.Y * 0.32, 0))
		local buckle = gear(char, lower, "Buckle", Vector3.new(0.12, s.Y * 0.42, s.Y * 0.42), BLK, M.Metal,
			CFrame.new(0, s.Y * 0.32, -s.Z * 0.56) * CFrame.Angles(0, rad(90), 0), { Shape = Enum.PartType.Cylinder })
		buckle.Reflectance = 0.2
	end
end

local function weaponXGear(char, head)
	local GUN, DARK = rgb(58, 58, 62), rgb(34, 34, 38)
	if head then
		local hs = head.Size
		gear(char, head, "Helmet", Vector3.new(hs.X * 1.16, hs.Y * 0.8, hs.Z * 1.18), GUN, M.Metal,
			CFrame.new(0, hs.Y * 0.3, hs.Z * 0.03), { Mesh = Enum.MeshType.Sphere, Reflectance = 0.08 })
		gear(char, head, "Band", Vector3.new(hs.Y * 0.3, hs.X * 1.2, hs.Z * 1.2), DARK, M.Metal,
			CFrame.new(0, hs.Y * 0.1, 0) * CFrame.Angles(0, 0, rad(90)), { Shape = Enum.PartType.Cylinder })
		-- glowing red visor band wrapping the eyes
		local visor = gear(char, head, "Visor", Vector3.new(hs.X * 0.8, hs.Y * 0.09, 0.06), rgb(255, 40, 40), M.Neon, CFrame.new(0, hs.Y * 0.1, -hs.Z * 0.61))
		for s = -1, 1, 2 do
			gear(char, head, "Visor", Vector3.new(hs.Z * 0.38, hs.Y * 0.09, 0.06), rgb(255, 40, 40), M.Neon,
				CFrame.new(s * hs.X * 0.5, hs.Y * 0.1, -hs.Z * 0.45) * CFrame.Angles(0, rad(s * -50), 0))
			-- ear cans + bolts
			gear(char, head, "EarCan", Vector3.new(0.28, hs.Y * 0.5, hs.Y * 0.5), DARK, M.Metal,
				CFrame.new(s * hs.X * 0.62, hs.Y * 0.05, 0), { Shape = Enum.PartType.Cylinder })
			gear(char, head, "Bolt", Vector3.new(0.1, hs.Y * 0.14, hs.Y * 0.14), rgb(150, 150, 155), M.Metal,
				CFrame.new(s * hs.X * 0.78, hs.Y * 0.05, 0), { Shape = Enum.PartType.Cylinder })
		end
		local l = Instance.new("PointLight")
		l.Color = rgb(255, 40, 40)
		l.Range = 8
		l.Brightness = 2
		l.Parent = visor
		gear(char, head, "Ridge", Vector3.new(hs.X * 0.16, hs.Y * 0.14, hs.Z * 0.95), DARK, M.Metal, CFrame.new(0, hs.Y * 0.68, hs.Z * 0.02))
		for i = -1, 1 do -- cable ports on the dome
			gear(char, head, "Port", Vector3.new(0.18, 0.22, 0.22), rgb(120, 120, 125), M.Metal,
				CFrame.new(i * hs.X * 0.22, hs.Y * 0.55, hs.Z * 0.4) * CFrame.Angles(0, 0, rad(90)), { Shape = Enum.PartType.Cylinder })
		end
	end

	local torso = char:FindFirstChild("UpperTorso")
	if torso then
		local s = torso.Size
		-- cables from the helmet down the back
		for i = -1, 1 do
			local x = i * s.X * 0.18
			cable(char, torso, {
				Vector3.new(x, s.Y * 0.5 + 1.1, s.Z * 0.45),
				Vector3.new(x * 1.4, s.Y * 0.55, s.Z * 0.7),
				Vector3.new(x * 1.8, s.Y * 0.1, s.Z * 0.62),
				Vector3.new(x * 2.1, -s.Y * 0.45, s.Z * 0.6),
			}, 0.09)
		end
		-- chest harness: V straps into a centre box, and over the shoulders
		for sx = -1, 1, 2 do
			strap(char, torso, Vector3.new(sx * s.X * 0.32, s.Y * 0.5, -s.Z * 0.52), Vector3.new(sx * s.X * 0.06, -s.Y * 0.05, -s.Z * 0.54), 0.2)
			strap(char, torso, Vector3.new(sx * s.X * 0.32, s.Y * 0.52, -s.Z * 0.5), Vector3.new(sx * s.X * 0.32, s.Y * 0.52, s.Z * 0.5), 0.2)
			strap(char, torso, Vector3.new(sx * s.X * 0.32, s.Y * 0.5, s.Z * 0.52), Vector3.new(-sx * s.X * 0.2, -s.Y * 0.3, s.Z * 0.54), 0.2)
		end
		gear(char, torso, "HarnessBox", Vector3.new(s.X * 0.26, s.Y * 0.22, 0.2), rgb(80, 80, 86), M.Metal, CFrame.new(0, -s.Y * 0.05, -s.Z * 0.6))
		local led = gear(char, torso, "LED", Vector3.new(0.08, 0.08, 0.04), rgb(80, 255, 120), M.Neon, CFrame.new(s.X * 0.07, -s.Y * 0.02, -s.Z * 0.71))
		led.Name = "LED"
	end

	local lower = char:FindFirstChild("LowerTorso")
	if lower then
		local s = lower.Size
		gear(char, lower, "Belt", Vector3.new(s.X * 1.08, s.Y * 0.3, s.Z * 1.1), rgb(40, 34, 28), M.Leather, CFrame.new(0, s.Y * 0.3, 0))
		for i, x in { -0.32, 0.05, 0.36 } do -- equipment boxes on the belt
			local box = gear(char, lower, "BeltBox", Vector3.new(s.X * 0.28, s.Y * 0.5, 0.3), i == 2 and rgb(70, 72, 78) or rgb(90, 88, 84), M.Metal,
				CFrame.new(s.X * x, s.Y * 0.1, -s.Z * 0.62))
			box.Reflectance = 0.05
			gear(char, lower, "Grille", Vector3.new(s.X * 0.2, 0.04, 0.02), rgb(20, 20, 20), M.Metal, CFrame.new(s.X * x, s.Y * 0.15, -s.Z * 0.78))
			gear(char, lower, "Grille", Vector3.new(s.X * 0.2, 0.04, 0.02), rgb(20, 20, 20), M.Metal, CFrame.new(s.X * x, s.Y * 0.05, -s.Z * 0.78))
		end
		gear(char, lower, "BeltLED", Vector3.new(0.06, 0.06, 0.03), rgb(255, 60, 40), M.Neon, CFrame.new(s.X * 0.05, s.Y * 0.28, -s.Z * 0.78))
	end

	-- cables wrapped around the arms and legs
	wrap(char, char:FindFirstChild("RightUpperArm"), 1.6, 0.08, 0.35, -0.4)
	wrap(char, char:FindFirstChild("LeftLowerArm"), 1.8, 0.08, 0.4, -0.35)
	wrap(char, char:FindFirstChild("RightLowerArm"), 1.2, 0.07, 0.3, -0.3)
	wrap(char, char:FindFirstChild("LeftUpperLeg"), 1.8, 0.09, 0.4, -0.4)
	wrap(char, char:FindFirstChild("RightUpperLeg"), 1.2, 0.08, 0.3, -0.35)
	wrap(char, char:FindFirstChild("RightLowerLeg"), 1.4, 0.08, 0.4, -0.2)
end

local function oldManGear(char)
	local lower = char:FindFirstChild("LowerTorso")
	if lower then
		local s = lower.Size
		for sx = -1, 1, 2 do -- long duster coat tails
			gear(char, lower, "CoatTail", Vector3.new(s.X * 0.52, s.Y * 3.4, 0.12), rgb(60, 44, 34), M.Leather,
				CFrame.new(sx * s.X * 0.27, -s.Y * 1.5, s.Z * 0.56) * CFrame.Angles(rad(6), 0, rad(sx * 3)))
		end
		for sx = -1, 1, 2 do
			gear(char, lower, "CoatFront", Vector3.new(s.X * 0.3, s.Y * 3.2, 0.1), rgb(60, 44, 34), M.Leather,
				CFrame.new(sx * s.X * 0.42, -s.Y * 1.4, -s.Z * 0.55) * CFrame.Angles(rad(-4), 0, rad(sx * 4)))
		end
	end
	local torso = char:FindFirstChild("UpperTorso")
	if torso then
		local s = torso.Size
		gear(char, torso, "Collar", Vector3.new(s.X * 1.1, s.Y * 0.2, s.Z * 1.15), rgb(52, 36, 26), M.Leather, CFrame.new(0, s.Y * 0.46, 0.05))
	end
end

local function loadHair(char, id)
	if not id or id == 0 then
		return
	end
	local ok, model = pcall(function()
		return game:GetService("InsertService"):LoadAsset(id)
	end)
	if ok and model then
		local acc = model:FindFirstChildWhichIsA("Accessory", true)
		local hum = Util.Humanoid(char)
		if acc and hum then
			hum:AddAccessory(acc)
		end
		model:Destroy()
	end
end

function Costumes.Dress(char, skinId)
	local skin = Skins.List[skinId] or Skins.List[Skins.Default]
	local tex = skin.Textures or {}
	local head = char:FindFirstChild("Head")
	local skinTone = head and head.Color or rgb(226, 176, 140)
	local hasShirt, hasPants = asset(tex.Shirt), asset(tex.Pants)

	for _, d in char:GetChildren() do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("BodyColors") then
			d:Destroy()
		elseif d:IsA("Accessory") and not (skin.KeepHair and d.AccessoryType == Enum.AccessoryType.Hair) then
			d:Destroy()
		end
	end

	-- Base body colours: skin tone under textures, flat colours as a fallback
	for slot, names in SLOT_PARTS do
		local color = skin.Colors[slot]
		if hasShirt or hasPants or color == "Skin" then
			color = skinTone
		end
		for _, name in names do
			local p = char:FindFirstChild(name)
			if p and p:IsA("BasePart") then
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
	if hasShirt then
		local s = Instance.new("Shirt")
		s.ShirtTemplate = hasShirt
		s.Parent = char
	end
	if hasPants then
		local p = Instance.new("Pants")
		p.PantsTemplate = hasPants
		p.Parent = char
	end
	if head and asset(tex.Face) then
		local face = head:FindFirstChildOfClass("Decal")
		if not face then
			face = Instance.new("Decal")
			face.Name = "face"
			face.Face = Enum.NormalId.Front
			face.Parent = head
		end
		face.Texture = asset(tex.Face)
	end

	if skinId == "Comic" then
		comicGear(char, head)
	elseif skinId == "WeaponX" then
		weaponXGear(char, head)
	elseif skinId == "OldManLogan" then
		oldManGear(char)
	end
	loadHair(char, skin.HairAccessoryId)
end

---------------------------------------------------------------------------
-- Claws: curved, tapered chrome blades with a bright cutting edge
---------------------------------------------------------------------------

local function lighten(c, f)
	return c:Lerp(Color3.new(1, 1, 1), f)
end

-- Builds 3 claws per hand. Returns { Roots = { {Weld, Extended, Retracted} }, Parts, Tips, Bases }.
function Costumes.BuildClaws(char, claw, extended)
	local L = Costumes.CLAW_LEN
	local thick = claw.Thick or 1
	local set = { Roots = {}, Parts = {}, Tips = {}, Bases = {} }
	local edgeColor = lighten(claw.Color, 0.65)
	local spineColor = claw.Color:Lerp(Color3.new(0, 0, 0), 0.35)

	for _, side in { "Right", "Left" } do
		local hand = Util.Hand(char, side)
		if hand then
			local out = CFrame.new(0, -hand.Size.Y * 0.3, -hand.Size.Z * 0.1)
			local tucked = CFrame.new(0, L * 0.5, -hand.Size.Z * 0.1)
			local root, rootWeld = Costumes.Gear(char, hand, "ClawRoot", Vector3.one * 0.05, Color3.new(), M.SmoothPlastic, extended and out or tucked, { Transparency = 1 }, "Claws")
			table.insert(set.Roots, { Weld = rootWeld, Extended = out })
			local spread = math.max(0.11, hand.Size.Z * 0.32)
			for i = -1, 1 do
				local f = CFrame.new(0, 0, i * spread) * CFrame.Angles(0, 0, rad(i * 2))
				local segs = {
					{ Len = L * 0.44, W = 0.2, T = 0.07, Ang = 0 },
					{ Len = L * 0.26, W = 0.19, T = 0.066, Ang = 5 },
					{ Len = L * 0.16, W = 0.17, T = 0.06, Ang = 7 },
				}
				for k, sg in segs do
					f = f * CFrame.Angles(rad(sg.Ang), 0, 0)
					local center = f * CFrame.new(0, -sg.Len / 2, 0)
					local w, t = sg.W * thick, sg.T * thick
					local body = Costumes.Gear(char, root, "Claw", Vector3.new(t, sg.Len + 0.02, w), claw.Color, claw.Material, center, { Reflectance = claw.Reflectance, Transparency = extended and 0 or 1 }, "Claws")
					-- bright honed edge along the inside curve
					local edge = Costumes.Gear(char, root, "Claw", Vector3.new(t * 0.7, sg.Len + 0.02, 0.035), edgeColor, M.SmoothPlastic,
						center * CFrame.new(0, 0, -w / 2 - 0.012), { Reflectance = math.min(1, claw.Reflectance + 0.35), Transparency = extended and 0 or 1 }, "Claws")
					-- bevel line on both flats
					for sx = -1, 1, 2 do
						local bevel = Costumes.Gear(char, root, "Claw", Vector3.new(0.012, sg.Len, w * 0.06), spineColor, M.SmoothPlastic,
							center * CFrame.new(sx * t / 2, 0, w * 0.12), { Transparency = extended and 0 or 1 }, "Claws")
						table.insert(set.Parts, bevel)
					end
					table.insert(set.Parts, body)
					table.insert(set.Parts, edge)
					if k == 1 then
						table.insert(set.Bases, body)
					end
					f = f * CFrame.new(0, -sg.Len, 0)
				end
				-- sharp tapered tip
				local tipLen = L * 0.2
				f = f * CFrame.Angles(rad(9), 0, 0)
				local tip = Costumes.Gear(char, root, "Claw", Vector3.new(0.058 * thick, tipLen, 0.17 * thick), claw.Color, claw.Material,
					f * CFrame.new(0, -tipLen / 2, 0) * CFrame.Angles(0, 0, math.pi), { Class = "WedgePart", Reflectance = claw.Reflectance, Transparency = extended and 0 or 1 }, "Claws")
				table.insert(set.Parts, tip)
				table.insert(set.Tips, tip)
			end
		end
	end
	return set
end

-- SNIKT: blades slide out of the knuckles.
function Costumes.PopClaws(set)
	for _, p in set.Parts do
		p.Transparency = 0
	end
	local info = TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	for _, r in set.Roots do
		TweenService:Create(r.Weld, info, { C0 = r.Extended }):Play()
	end
end

---------------------------------------------------------------------------
-- Sentinel armour (purple-blue plates, magenta limbs, gold face, glowing core)
---------------------------------------------------------------------------

function Costumes.DressSentinel(char)
	local ARMOR, ARMOR2 = rgb(98, 102, 178), rgb(76, 78, 150)
	local MAG, FACE, MECH = rgb(176, 84, 178), rgb(208, 172, 112), rgb(26, 26, 32)
	local F = "SentinelGear"
	local function g(anchor, name, size, color, mat, offset, props)
		return Costumes.Gear(char, anchor, name, size, color, mat or M.SmoothPlastic, offset, props, F)
	end

	for _, d in char:GetChildren() do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("Accessory") then
			d:Destroy()
		elseif d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Color = MECH
			d.Material = M.Metal
			local face = d:FindFirstChildOfClass("Decal")
			if face then
				face.Transparency = 1
			end
		end
	end

	local head = char:FindFirstChild("Head")
	if head then
		local hs = head.Size
		g(head, "Helmet", Vector3.new(hs.X * 1.22, hs.Y * 1.12, hs.Z * 1.22), ARMOR, M.SmoothPlastic, CFrame.new(0, hs.Y * 0.1, hs.Z * 0.06), { Mesh = Enum.MeshType.Sphere })
		g(head, "Crest", Vector3.new(hs.X * 0.3, hs.Y * 0.2, hs.Z * 1.1), ARMOR2, M.SmoothPlastic, CFrame.new(0, hs.Y * 0.62, hs.Z * 0.05))
		g(head, "FacePlate", Vector3.new(hs.X * 0.8, hs.Y * 0.78, 0.14), FACE, M.Metal, CFrame.new(0, -hs.Y * 0.05, -hs.Z * 0.56), { Reflectance = 0.1 })
		g(head, "Jaw", Vector3.new(hs.X * 0.62, hs.Y * 0.28, 0.2), FACE:Lerp(Color3.new(0, 0, 0), 0.15), M.Metal, CFrame.new(0, -hs.Y * 0.36, -hs.Z * 0.52))
		for s = -1, 1, 2 do
			local eye = g(head, "Eye", Vector3.new(hs.X * 0.2, hs.Y * 0.08, 0.05), rgb(255, 40, 40), M.Neon,
				CFrame.new(s * hs.X * 0.19, hs.Y * 0.1, -hs.Z * 0.64) * CFrame.Angles(0, 0, rad(s * 10)))
			local l = Instance.new("PointLight")
			l.Color = rgb(255, 40, 40)
			l.Range = 5
			l.Brightness = 1.5
			l.Parent = eye
		end
		for i = 0, 2 do -- mouth grille
			g(head, "Grille", Vector3.new(hs.X * 0.36, 0.035, 0.03), rgb(60, 45, 30), M.Metal, CFrame.new(0, -hs.Y * (0.26 + i * 0.07), -hs.Z * 0.64))
		end
	end

	local torso = char:FindFirstChild("UpperTorso")
	if torso then
		local s = torso.Size
		g(torso, "ChestPlate", Vector3.new(s.X * 1.3, s.Y * 0.58, s.Z * 1.3), ARMOR, M.SmoothPlastic, CFrame.new(0, s.Y * 0.2, 0))
		for sx = -1, 1, 2 do -- pec plates
			g(torso, "Pec", Vector3.new(s.X * 0.58, s.Y * 0.36, 0.25), ARMOR2, M.SmoothPlastic,
				CFrame.new(sx * s.X * 0.3, s.Y * 0.2, -s.Z * 0.68) * CFrame.Angles(0, rad(sx * 12), 0))
		end
		local core = g(torso, "Core", Vector3.one * s.X * 0.26, rgb(255, 220, 150), M.Neon, CFrame.new(0, s.Y * 0.28, -s.Z * 0.76), { Shape = Enum.PartType.Ball })
		g(torso, "CoreRing", Vector3.new(0.12, s.X * 0.36, s.X * 0.36), ARMOR2, M.Metal, CFrame.new(0, s.Y * 0.28, -s.Z * 0.7) * CFrame.Angles(0, rad(90), 0), { Shape = Enum.PartType.Cylinder })
		local l = Instance.new("PointLight")
		l.Color = rgb(255, 190, 110)
		l.Range = 12
		l.Brightness = 3
		l.Parent = core
		-- exposed mechanical abdomen ribs
		for i = 0, 3 do
			g(torso, "Rib", Vector3.new(s.X * (0.78 - i * 0.05), 0.1, s.Z * 1.05), rgb(14, 14, 18), M.Metal, CFrame.new(0, -s.Y * (0.12 + i * 0.1), 0))
			for sx = -1, 1, 2 do
				g(torso, "AbPlate", Vector3.new(s.X * 0.22, s.Y * 0.07, 0.1), ARMOR2, M.SmoothPlastic, CFrame.new(sx * s.X * 0.13, -s.Y * (0.12 + i * 0.1), -s.Z * 0.55))
			end
		end
		g(torso, "Collar", Vector3.new(s.X * 0.9, s.Y * 0.14, s.Z * 1.2), ARMOR2, M.SmoothPlastic, CFrame.new(0, s.Y * 0.52, 0))
	end

	local lower = char:FindFirstChild("LowerTorso")
	if lower then
		local s = lower.Size
		g(lower, "Pelvis", Vector3.new(s.X * 1.15, s.Y * 0.8, s.Z * 1.2), MAG, M.SmoothPlastic, CFrame.new(0, -s.Y * 0.05, 0))
		g(lower, "Waist", Vector3.new(s.X * 1.02, s.Y * 0.2, s.Z * 1.05), rgb(14, 14, 18), M.Metal, CFrame.new(0, s.Y * 0.42, 0))
	end

	for _, n in { "RightUpperArm", "LeftUpperArm" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			local side = n:sub(1, 5) == "Right" and 1 or -1
			g(p, "Pauldron", Vector3.new(s.X * 2.3, s.Y * 0.8, s.Z * 2.1), ARMOR, M.SmoothPlastic, CFrame.new(side * s.X * 0.18, s.Y * 0.28, 0), { Mesh = Enum.MeshType.Sphere })
			g(p, "PauldronRim", Vector3.new(s.X * 2.1, s.Y * 0.12, s.Z * 1.95), ARMOR2, M.SmoothPlastic, CFrame.new(side * s.X * 0.18, -s.Y * 0.02, 0), { Mesh = Enum.MeshType.Sphere })
		end
	end
	for _, n in { "RightLowerArm", "LeftLowerArm" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			g(p, "Forearm", Vector3.new(s.X * 1.55, s.Y * 0.95, s.Z * 1.5), MAG, M.SmoothPlastic, CFrame.new(0, -s.Y * 0.02, 0))
			g(p, "ForearmPlate", Vector3.new(s.X * 1.1, s.Y * 0.7, 0.1), ARMOR2, M.SmoothPlastic, CFrame.new(0, 0, -s.Z * 0.78))
		end
	end
	for _, n in { "RightHand", "LeftHand" } do
		local p = char:FindFirstChild(n)
		if p then
			g(p, "Gauntlet", p.Size * Vector3.new(1.4, 1.1, 1.4), rgb(40, 40, 46), M.Metal, CFrame.identity)
		end
	end
	for _, n in { "RightUpperLeg", "LeftUpperLeg" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			g(p, "Thigh", Vector3.new(s.X * 1.45, s.Y * 0.9, s.Z * 1.45), MAG, M.SmoothPlastic, CFrame.new(0, 0.02, 0))
		end
	end
	for _, n in { "RightLowerLeg", "LeftLowerLeg" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			g(p, "Knee", Vector3.new(s.X * 1.7, s.Y * 0.5, s.Z * 1.8), ARMOR, M.SmoothPlastic, CFrame.new(0, s.Y * 0.42, -s.Z * 0.1), { Mesh = Enum.MeshType.Sphere })
			g(p, "Shin", Vector3.new(s.X * 1.7, s.Y * 1.05, s.Z * 1.75), ARMOR, M.SmoothPlastic, CFrame.new(0, -s.Y * 0.08, 0))
			g(p, "ShinPlate", Vector3.new(s.X * 1.2, s.Y * 0.8, 0.12), ARMOR2, M.SmoothPlastic, CFrame.new(0, -s.Y * 0.05, -s.Z * 0.9))
		end
	end
	for _, n in { "RightFoot", "LeftFoot" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			g(p, "Boot", Vector3.new(s.X * 1.9, s.Y * 1.6, s.Z * 1.5), ARMOR, M.SmoothPlastic, CFrame.new(0, s.Y * 0.2, -s.Z * 0.1))
		end
	end
end

return Costumes
