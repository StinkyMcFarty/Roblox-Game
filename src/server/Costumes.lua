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

-- 3D boots on both feet: a shell over the foot, a toe cap, a thick sole and a
-- cuff round the bottom of the shin. `flare` makes the cuff a wide comic-book
-- boot top.
local function boots(char, color, sole, flare)
	for _, side in { "Right", "Left" } do
		local foot = char:FindFirstChild(side .. "Foot")
		if foot then
			local s = foot.Size
			gear(char, foot, "Boot", Vector3.new(s.X * 1.14, s.Y * 1.25, s.Z * 1.14), color, M.Leather, CFrame.new(0, s.Y * 0.1, 0))
			gear(char, foot, "BootToe", Vector3.new(s.X * 1.1, s.Y * 0.9, s.Z * 0.4), color:Lerp(Color3.new(0, 0, 0), 0.15), M.Leather, CFrame.new(0, -s.Y * 0.05, -s.Z * 0.46))
			gear(char, foot, "BootSole", Vector3.new(s.X * 1.2, s.Y * 0.32, s.Z * 1.24), sole, M.Rubber, CFrame.new(0, -s.Y * 0.55, -s.Z * 0.02))
		end
		local shin = char:FindFirstChild(side .. "LowerLeg")
		if shin then
			local s = shin.Size
			if flare then
				gear(char, shin, "BootFlare", Vector3.new(s.X * 1.45, s.Y * 0.2, s.Z * 1.45), color, M.SmoothPlastic, CFrame.new(0, s.Y * 0.38, 0), { Mesh = Enum.MeshType.Sphere })
			else
				gear(char, shin, "BootCuff", Vector3.new(s.X * 1.12, s.Y * 0.36, s.Z * 1.12), color, M.Leather, CFrame.new(0, -s.Y * 0.32, 0))
			end
		end
	end
end

-- Gloves over the fists: a shell, a knuckle ridge (where the claws come out)
-- and a cuff at the wrist; `flare` = a wide comic-book gauntlet top.
local function gloves(char, color, cuff, flare)
	for _, side in { "Right", "Left" } do
		local hand = char:FindFirstChild(side .. "Hand")
		if hand then
			local s = hand.Size
			gear(char, hand, "Glove", Vector3.new(s.X * 1.12, s.Y * 1.08, s.Z * 1.12), color, M.Leather, CFrame.new())
			gear(char, hand, "Knuckles", Vector3.new(s.X * 1.14, s.Y * 0.3, s.Z * 0.5), color:Lerp(Color3.new(0, 0, 0), 0.2), M.Leather, CFrame.new(0, -s.Y * 0.3, -s.Z * 0.2))
		end
		local arm = char:FindFirstChild(side .. "LowerArm")
		if arm then
			local s = arm.Size
			if flare then
				gear(char, arm, "GloveFlare", Vector3.new(s.X * 1.5, s.Y * 0.22, s.Z * 1.5), cuff, M.SmoothPlastic, CFrame.new(0, s.Y * 0.36, 0), { Mesh = Enum.MeshType.Sphere })
			else
				gear(char, arm, "GloveCuff", Vector3.new(s.X * 1.1, s.Y * 0.2, s.Z * 1.1), cuff, M.Leather, CFrame.new(0, -s.Y * 0.42, 0))
			end
		end
	end
end

-- Rounded shoulders: a roll along the top outer edge of the torso (so it
-- stops reading as a box) and a cap over the top of each upper arm.
local function shoulders(char, color, material, bulk, noCaps)
	bulk = bulk or 1
	local torso = char:FindFirstChild("UpperTorso")
	if torso then
		local s = torso.Size
		local d = s.Y * 0.5 * bulk
		for _, side in { -1, 1 } do
			gear(char, torso, "ShoulderRoll", Vector3.new(s.Z * 1.04, d, d), color, material,
				CFrame.new(side * (s.X / 2 - d * 0.36), s.Y / 2 - d * 0.36, 0) * CFrame.Angles(0, rad(90), 0), { Shape = Enum.PartType.Cylinder })
		end
	end
	for _, n in { "RightUpperArm", "LeftUpperArm" } do
		local arm = not noCaps and char:FindFirstChild(n)
		if arm then
			local s = arm.Size
			gear(char, arm, "Deltoid", Vector3.new(s.X * 1.12 * bulk, s.Y * 0.62, s.Z * 1.1 * bulk), color, material,
				CFrame.new(0, s.Y * 0.26, 0), { Mesh = Enum.MeshType.Sphere })
		end
	end
end

-- A sculpted build over the torso and arms: pecs with a shadow line under
-- them, a six-pack, traps sloping up to the neck, biceps and calves.
-- c = { Chest, Shade, Abs, Traps, Arms, Calves, Material }
local function physique(char, c)
	local mat = c.Material or M.SmoothPlastic
	local torso = char:FindFirstChild("UpperTorso")
	if torso then
		local s = torso.Size
		local fz = -s.Z / 2
		for _, side in { -1, 1 } do
			gear(char, torso, "Pec", Vector3.new(s.X * 0.29, s.Y * 0.28, 0.12), c.Chest, mat,
				CFrame.new(side * s.X * 0.15, s.Y * 0.2, fz - 0.04) * CFrame.Angles(rad(-5), 0, 0))
			gear(char, torso, "PecShade", Vector3.new(s.X * 0.27, 0.05, 0.1), c.Shade, mat, CFrame.new(side * s.X * 0.15, s.Y * 0.055, fz - 0.05))
			gear(char, torso, "Trap", Vector3.new(s.Z * 0.62, s.Y * 0.14, s.X * 0.24), c.Traps or c.Chest, mat,
				CFrame.new(side * s.X * 0.28, s.Y * 0.57, s.Z * 0.06) * CFrame.Angles(0, rad(-side * 90), 0), { Class = "WedgePart" })
		end
		for row = 0, 2 do
			for _, side in { -1, 1 } do
				gear(char, torso, "Ab", Vector3.new(s.X * 0.13, s.Y * 0.12, 0.06), c.Abs or c.Chest, mat,
					CFrame.new(side * s.X * 0.075, -s.Y * (0.08 + row * 0.15), fz - 0.02))
			end
		end
		gear(char, torso, "AbLine", Vector3.new(0.04, s.Y * 0.46, 0.05), c.Shade, mat, CFrame.new(0, -s.Y * 0.23, fz - 0.015))
	end
	for _, n in { "RightUpperArm", "LeftUpperArm" } do
		local arm = char:FindFirstChild(n)
		if arm and c.Arms then
			local s = arm.Size
			gear(char, arm, "Bicep", Vector3.new(s.X * 0.7, s.Y * 0.5, s.Z * 0.5), c.Arms, mat,
				CFrame.new(0, -s.Y * 0.08, -s.Z * 0.32), { Mesh = Enum.MeshType.Sphere })
		end
	end
	for _, n in { "RightLowerLeg", "LeftLowerLeg" } do
		local leg = char:FindFirstChild(n)
		if leg and c.Calves then
			local s = leg.Size
			gear(char, leg, "Calf", Vector3.new(s.X * 0.8, s.Y * 0.5, s.Z * 0.5), c.Calves, mat,
				CFrame.new(0, s.Y * 0.12, s.Z * 0.34), { Mesh = Enum.MeshType.Sphere })
		end
	end
end

-- A pointed flap (an isosceles triangle standing up) on a surface: two
-- wedges back to back. `base` is the flap's centre in anchor space; its local
-- X is the surface normal, Y up, Z across.
local function pointFlap(char, anchor, name, base, width, height, thick, color, material)
	for _, k in { 0, math.pi } do
		gear(char, anchor, name, Vector3.new(thick, height, width / 2), color, material or M.SmoothPlastic,
			base * CFrame.Angles(0, k, 0) * CFrame.new(0, 0, -width / 4), { Class = "WedgePart" })
	end
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

local SHIRT_SLOTS = { UpperTorso = true, UpperArm = true, LowerArm = true, Hand = true }
local PANTS_SLOTS = { LowerTorso = true, UpperLeg = true, LowerLeg = true, Foot = true }

local function asset(id)
	if not id or id == 0 or id == "" then
		return nil
	end
	return "rbxassetid://" .. (type(id) == "number" and string.format("%.0f", id) or tostring(id))
end

-- Wolverine's hair, built from parts so it works on any avatar (blocky
-- players usually have no hair): a close cap with the two signature tufts
-- sweeping up and back from the temples, a lower crest between them and
-- sideburns. opts: Tuft (height multiplier), Chops (sideburn length).
local function wolverineHair(char, head, color, opts)
	if not head then
		return
	end
	opts = opts or {}
	local hs = head.Size
	local tuft = opts.Tuft or 1
	local mat = M.SmoothPlastic
	local function piece(name, size, cf, class)
		return gear(char, head, name, size, color, mat, cf, class and { Class = class } or nil, "Hair")
	end
	-- cap, back and sides hugging the skull
	piece("HairCap", Vector3.new(hs.X * 1.06, hs.Y * 0.2, hs.Z * 1.08), CFrame.new(0, hs.Y * 0.52, hs.Z * 0.02))
	piece("HairBack", Vector3.new(hs.X * 1.04, hs.Y * 0.64, hs.Z * 0.12), CFrame.new(0, hs.Y * 0.2, hs.Z * 0.54))
	for _, side in { -1, 1 } do
		piece("HairSide", Vector3.new(hs.X * 0.1, hs.Y * 0.36, hs.Z * 0.62), CFrame.new(side * hs.X * 0.53, hs.Y * 0.3, hs.Z * 0.2))
		-- the tufts: tall wedges rising from the temples, leaning out and swept back
		piece("HairTuft", Vector3.new(hs.X * 0.3, hs.Y * 0.58 * tuft, hs.Z * 0.72),
			CFrame.new(side * hs.X * 0.42, hs.Y * (0.6 + 0.2 * tuft), hs.Z * 0.12) * CFrame.Angles(rad(-30), 0, rad(-side * 36)), "WedgePart")
		-- a second, shorter spike behind each tuft for a ragged edge
		piece("HairSpike", Vector3.new(hs.X * 0.2, hs.Y * 0.36 * tuft, hs.Z * 0.46),
			CFrame.new(side * hs.X * 0.5, hs.Y * (0.54 + 0.12 * tuft), hs.Z * 0.4) * CFrame.Angles(rad(-42), 0, rad(-side * 52)), "WedgePart")
		-- sideburns running down toward the jaw
		piece("Sideburn", Vector3.new(hs.X * 0.06, hs.Y * 0.5 * (opts.Chops or 1), hs.Z * 0.3),
			CFrame.new(side * hs.X * 0.52, hs.Y * (0.12 - 0.25 * ((opts.Chops or 1) - 1)), -hs.Z * 0.1))
	end
	-- lower crest in the middle, swept back
	piece("HairCrest", Vector3.new(hs.X * 0.42, hs.Y * 0.3 * tuft, hs.Z * 0.78),
		CFrame.new(0, hs.Y * (0.6 + 0.1 * tuft), hs.Z * 0.12) * CFrame.Angles(rad(-16), 0, 0), "WedgePart")
	-- a ragged layer of short spikes flicking out round the back and crown
	for k = -2, 2 do
		piece("HairFlick", Vector3.new(hs.X * 0.16, hs.Y * 0.26 * tuft, hs.Z * 0.34),
			CFrame.new(k * hs.X * 0.2, hs.Y * (0.5 - math.abs(k) * 0.04), hs.Z * 0.5) * CFrame.Angles(rad(-58), 0, rad(-k * 14)), "WedgePart")
	end
	for _, side in { -1, 1 } do
		piece("HairFlick", Vector3.new(hs.X * 0.14, hs.Y * 0.3 * tuft, hs.Z * 0.4),
			CFrame.new(side * hs.X * 0.26, hs.Y * (0.66 + 0.1 * tuft), -hs.Z * 0.06) * CFrame.Angles(rad(-24), 0, rad(-side * 24)), "WedgePart")
	end
end

---------------------------------------------------------------------------
-- Wolverine faces. The avatar's round head is hidden and the suit gets a
-- block head of the same size; the face is drawn on its flat front with a
-- SurfaceGui (frames), so it always sits flat, stays sharp and needs no
-- uploaded images. Styles: "Logan", "Comic", "WeaponX", "OldMan".
---------------------------------------------------------------------------

local INK = rgb(18, 14, 12)

local function box(parent, x, y, w, h, color, rot, z, round, stroke)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.Rotation = rot or 0
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z or 1
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, round)
		c.Parent = f
	end
	if stroke then
		local st = Instance.new("UIStroke")
		st.Color = INK
		st.Thickness = stroke
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = f
	end
	f.Parent = parent
	return f
end

local function faceChops(g, color, z)
	for _, s in { -1, 1 } do
		local cx = 256 + s * 216
		box(g, cx, 300, 64, 230, color, 0, z, 10, 5)
		box(g, 256 + s * 150, 394, 128, 44, color, s * 14, z, 14, 5)
	end
end

local function faceEyes(g, iris, z)
	for _, s in { -1, 1 } do
		local cx = 256 + s * 80
		box(g, cx, 224, 92, 38, rgb(250, 248, 242), 0, z, 16, 4)
		box(g, cx - s * 10, 228, 28, 28, iris, 0, z + 1, 14)
		box(g, cx - s * 10, 228, 12, 12, INK, 0, z + 2, 6)
		box(g, cx, 206, 108, 14, INK, -s * 12, z + 3, 4) -- heavy angry lid
	end
end

local function faceBrows(g, color, z)
	for _, s in { -1, 1 } do
		box(g, 256 + s * 84, 166, 134, 30, color, -s * 16, z, 6, 4)
		box(g, 256 + s * 11, 192, 4, 26, rgb(120, 70, 50), -s * 10, z) -- scowl creases
	end
end

local function faceNose(g, z)
	box(g, 252, 296, 8, 46, rgb(150, 92, 66), 0, z, 4)
	box(g, 262, 318, 28, 8, rgb(150, 92, 66), 0, z, 4)
end

local function faceSnarl(g, z, y)
	y = y or 372
	box(g, 256, y, 196, 64, rgb(96, 22, 24), 0, z, 18, 5)
	box(g, 256, y, 164, 32, rgb(246, 242, 228), 0, z + 1, 6)
	box(g, 256, y, 164, 3, rgb(150, 140, 120), 0, z + 2)
	for k = -3, 3 do
		box(g, 256 + k * 22, y, 3, 32, rgb(150, 140, 120), 0, z + 2)
	end
end

local FACE_STYLES = {
	Logan = function(g, hair)
		faceChops(g, rgb(58, 40, 28), 2)
		faceBrows(g, hair or rgb(40, 28, 20), 3)
		faceEyes(g, rgb(92, 70, 44), 3)
		faceNose(g, 2)
		faceSnarl(g, 3)
	end,
	Comic = function(g, _, skinTone)
		-- bare jaw under the yellow mask
		box(g, 256, 404, 520, 240, skinTone, 0, 1, nil, 5)
		faceChops(g, rgb(20, 20, 26), 2)
		for _, s in { -1, 1 } do
			local cx = 256 + s * 86
			box(g, cx, 214, 176, 86, rgb(16, 16, 22), -s * 16, 2, 12, 4) -- black mask round the eyes
			box(g, cx - s * 6, 222, 100, 26, rgb(255, 255, 255), -s * 14, 3, 4) -- blank white comic eyes
		end
		faceSnarl(g, 3, 380)
	end,
	WeaponX = function(g)
		faceChops(g, rgb(58, 40, 28), 2)
		faceNose(g, 2)
		faceSnarl(g, 3)
		for _, sc in { { 170, 300, 28 }, { 350, 316, -24 } } do -- stitched scars
			box(g, sc[1], sc[2], 8, 96, rgb(150, 30, 30), sc[3], 4, 4)
			for k = -1, 1 do
				box(g, sc[1] + k * math.sin(math.rad(sc[3])) * -28, sc[2] + k * 28, 22, 4, INK, sc[3], 5)
			end
		end
	end,
	OldMan = function(g, hair)
		local grey = hair or rgb(184, 182, 176)
		faceEyes(g, rgb(90, 110, 120), 3)
		faceBrows(g, grey, 4)
		faceNose(g, 2)
		-- full beard: jaw to jaw
		box(g, 256, 440, 520, 190, grey, 0, 2, nil, 5)
		for _, s in { -1, 1 } do
			box(g, 256 + s * 222, 300, 76, 260, grey, 0, 2, 10, 5)
		end
		box(g, 256, 376, 96, 18, rgb(70, 30, 30), 0, 3, 6, 4) -- grim mouth
		box(g, 256, 350, 220, 32, rgb(206, 204, 198), 0, 4, 14, 4) -- moustache
		for k = -3, 3 do
			box(g, 256 + k * 36, 450, 4, 44, rgb(140, 138, 132), 0, 3)
		end
	end,
}

-- Hide the avatar's head and weld a block head of the same size in its place
-- with the drawn face on its front. Returns the new head part.
local function faceBlock(char, head, style, hair, skinTone)
	for _, d in head:GetChildren() do
		if d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") or d.ClassName == "FaceControls" then
			d:Destroy()
		end
	end
	head.Transparency = 1
	if not head:GetAttribute("FaceGuard") then
		head:SetAttribute("FaceGuard", true)
		pcall(function()
			-- the avatar finishes loading after we dress and re-adds its face
			head.ChildAdded:Connect(function(d)
				task.defer(function()
					if d.Parent == head and (d:IsA("Decal") or d:IsA("Texture")) then
						d:Destroy()
					end
				end)
			end)
		end)
	end
	local blk = gear(char, head, "HeadBlock", head.Size, head.Color, M.SmoothPlastic, CFrame.new())
	local g = Instance.new("SurfaceGui")
	g.Name = "Face"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(512, 512)
	g.LightInfluence = 1
	g.ClipsDescendants = true
	g.Parent = blk
	FACE_STYLES[style](g, hair, skinTone)
	return blk
end

local function comicGear(char, head)
	local YEL, YEL2, BLU, BLU2, BLK = rgb(238, 184, 20), rgb(206, 150, 12), rgb(28, 56, 140), rgb(20, 40, 104), rgb(18, 18, 22)
	if head then
		local hs = head.Size
		head.Color = YEL
		-- fitted cowl over the top and back of the (block) head
		gear(char, head, "Cowl", Vector3.new(hs.X * 1.06, hs.Y * 0.3, hs.Z * 1.06), YEL, M.SmoothPlastic, CFrame.new(0, hs.Y * 0.4, hs.Z * 0.01))
		gear(char, head, "CowlBack", Vector3.new(hs.X * 1.06, hs.Y * 0.8, hs.Z * 0.1), YEL, M.SmoothPlastic, CFrame.new(0, hs.Y * 0.1, hs.Z * 0.52))
		-- the iconic fins: tall black blades swept up and back from the
		-- temples, a yellow inner layer and a black ear patch under each
		for s = -1, 1, 2 do
			gear(char, head, "Fin", Vector3.new(0.14, hs.Y * 1.3, hs.Z * 0.78), BLK, M.SmoothPlastic,
				CFrame.new(s * hs.X * 0.47, hs.Y * 0.74, hs.Z * 0.16) * CFrame.Angles(rad(-18), 0, rad(-s * 16)), { Class = "WedgePart" })
			gear(char, head, "FinInner", Vector3.new(0.12, hs.Y * 0.86, hs.Z * 0.5), YEL, M.SmoothPlastic,
				CFrame.new(s * hs.X * 0.43, hs.Y * 0.62, hs.Z * 0.13) * CFrame.Angles(rad(-18), 0, rad(-s * 16)), { Class = "WedgePart" })
		end
	end

	local torso = char:FindFirstChild("UpperTorso")
	if torso then
		local s = torso.Size
		local fz = s.Z * 0.525 + 0.02
		-- muscle under the spandex
		physique(char, { Chest = YEL, Shade = YEL2, Abs = YEL, Traps = BLU, Material = M.SmoothPlastic })
		for side = -1, 1, 2 do
			-- blue flanks from the armpits to the belt
			gear(char, torso, "Flank", Vector3.new(s.X * 0.2, s.Y * 0.96, s.Z * 1.05), BLU, M.SmoothPlastic, CFrame.new(side * s.X * 0.41, -s.Y * 0.02, 0))
			-- the blue sweeps over the shoulders and in to the collar
			gear(char, torso, "Yoke", Vector3.new(s.X * 0.4, s.Y * 0.2, s.Z * 1.06), BLU, M.SmoothPlastic, CFrame.new(side * s.X * 0.31, s.Y * 0.41, 0))
			gear(char, torso, "YokePoint", Vector3.new(0.05, s.Y * 0.3, s.X * 0.2), BLU, M.SmoothPlastic,
				CFrame.new(side * s.X * 0.2, s.Y * 0.2, -fz) * CFrame.Angles(0, 0, rad(180)) * CFrame.Angles(0, rad(-side * 90), 0), { Class = "WedgePart" })
			-- black tiger stripes knifing in from the flanks, front and back
			for k = 0, 2 do
				for _, face in { -1, 1 } do
					local y = -s.Y * (0.02 + k * 0.16)
					gear(char, torso, "Stripe", Vector3.new(0.04, s.Y * 0.08, s.X * (0.26 - k * 0.03)), BLK, M.SmoothPlastic,
						CFrame.new(side * s.X * (0.38 - k * 0.01), y, face * fz) * CFrame.Angles(0, 0, rad(side * -12)) * CFrame.Angles(0, rad(side * 90), 0), { Class = "WedgePart" })
				end
			end
		end
	end
	shoulders(char, BLU, M.SmoothPlastic, 1.08, true)
	-- rounded blue shoulder pads with a black rim
	for _, n in { "RightUpperArm", "LeftUpperArm" } do
		local arm = char:FindFirstChild(n)
		if arm then
			local s = arm.Size
			local side = n:sub(1, 5) == "Right" and 1 or -1
			gear(char, arm, "ShoulderPad", Vector3.new(s.X * 1.36, s.Y * 0.7, s.Z * 1.28), BLU, M.SmoothPlastic,
				CFrame.new(side * s.X * 0.06, s.Y * 0.4, 0), { Mesh = Enum.MeshType.Sphere })
			gear(char, arm, "PadRim", Vector3.new(s.X * 1.32, s.Y * 0.08, s.Z * 1.24), BLK, M.SmoothPlastic,
				CFrame.new(side * s.X * 0.06, s.Y * 0.2, 0), { Mesh = Enum.MeshType.Sphere })
			for k = 0, 1 do -- stripes round the yellow sleeve
				gear(char, arm, "Stripe", Vector3.new(0.04, s.Y * 0.08, s.Z * 0.62), BLK, M.SmoothPlastic,
					CFrame.new(side * (s.X * 0.5 + 0.02), -s.Y * (0.12 + k * 0.2), 0) * CFrame.Angles(rad(side * 20), 0, 0))
			end
		end
	end
	-- gauntlets: blue to the elbow, a black-trimmed cuff with a big point on
	-- the outside of the forearm
	for _, side in { "Right", "Left" } do
		local sx = side == "Right" and 1 or -1
		local hand = char:FindFirstChild(side .. "Hand")
		if hand then
			local hsz = hand.Size
			gear(char, hand, "Glove", Vector3.new(hsz.X * 1.12, hsz.Y * 1.08, hsz.Z * 1.12), BLU, M.SmoothPlastic, CFrame.new())
			gear(char, hand, "Knuckles", Vector3.new(hsz.X * 1.14, hsz.Y * 0.3, hsz.Z * 0.5), BLU2, M.SmoothPlastic, CFrame.new(0, -hsz.Y * 0.3, -hsz.Z * 0.2))
		end
		local arm = char:FindFirstChild(side .. "LowerArm")
		if arm then
			local as = arm.Size
			gear(char, arm, "GloveCuff", Vector3.new(as.X * 1.16, as.Y * 0.16, as.Z * 1.16), BLU, M.SmoothPlastic, CFrame.new(0, as.Y * 0.36, 0))
			gear(char, arm, "CuffRim", Vector3.new(as.X * 1.18, as.Y * 0.04, as.Z * 1.18), BLK, M.SmoothPlastic, CFrame.new(0, as.Y * 0.45, 0))
			pointFlap(char, arm, "GloveFin", CFrame.new(sx * (as.X * 0.58 + 0.04), as.Y * 0.62, 0), as.Z * 1.0, as.Y * 0.62, 0.08, BLU)
			pointFlap(char, arm, "GloveFinRim", CFrame.new(sx * (as.X * 0.58 + 0.01), as.Y * 0.64, 0), as.Z * 1.08, as.Y * 0.68, 0.06, BLK)
		end
	end
	-- boots: blue, a black sole, the top cut into a point at the front
	boots(char, BLU, BLK)
	for _, n in { "RightLowerLeg", "LeftLowerLeg" } do
		local leg = char:FindFirstChild(n)
		if leg then
			local ls = leg.Size
			gear(char, leg, "BootTop", Vector3.new(ls.X * 1.14, ls.Y * 0.1, ls.Z * 1.14), BLU, M.SmoothPlastic, CFrame.new(0, ls.Y * 0.32, 0))
			pointFlap(char, leg, "BootPoint", CFrame.new(0, ls.Y * 0.5, -(ls.Z * 0.57 + 0.04)) * CFrame.Angles(0, rad(90), 0), ls.X * 0.9, ls.Y * 0.4, 0.08, BLU)
			pointFlap(char, leg, "BootPointRim", CFrame.new(0, ls.Y * 0.52, -(ls.Z * 0.57 + 0.01)) * CFrame.Angles(0, rad(90), 0), ls.X * 0.98, ls.Y * 0.46, 0.06, BLK)
		end
	end
	for _, n in { "RightUpperLeg", "LeftUpperLeg" } do
		local leg = char:FindFirstChild(n)
		if leg then
			local ls = leg.Size
			local side = n:sub(1, 5) == "Right" and 1 or -1
			for k = 0, 2 do -- tiger stripes down the outer thigh
				gear(char, leg, "Stripe", Vector3.new(0.04, ls.Y * 0.07, ls.Z * (0.66 - k * 0.08)), BLK, M.SmoothPlastic,
					CFrame.new(side * (ls.X * 0.5 + 0.02), ls.Y * (0.28 - k * 0.22), 0) * CFrame.Angles(rad(side * 24), 0, 0))
			end
			gear(char, leg, "Briefs", Vector3.new(ls.X * 1.06, ls.Y * 0.2, ls.Z * 1.06), BLU, M.SmoothPlastic, CFrame.new(0, ls.Y * 0.42, 0))
		end
	end
	-- red belt, black buckle with the X
	local lower = char:FindFirstChild("LowerTorso")
	if lower then
		local s = lower.Size
		gear(char, lower, "Briefs", Vector3.new(s.X * 1.03, s.Y * 0.9, s.Z * 1.04), BLU, M.SmoothPlastic, CFrame.new(0, -s.Y * 0.05, 0))
		gear(char, lower, "Belt", Vector3.new(s.X * 1.08, s.Y * 0.3, s.Z * 1.1), rgb(186, 24, 30), M.Leather, CFrame.new(0, s.Y * 0.34, 0))
		local buckle = gear(char, lower, "Buckle", Vector3.new(0.12, s.Y * 0.62, s.Y * 0.62), BLK, M.Metal,
			CFrame.new(0, s.Y * 0.34, -s.Z * 0.57) * CFrame.Angles(0, rad(90), 0), { Shape = Enum.PartType.Cylinder })
		buckle.Reflectance = 0.2
		gear(char, lower, "BuckleRim", Vector3.new(0.1, s.Y * 0.7, s.Y * 0.7), rgb(200, 200, 206), M.Metal,
			CFrame.new(0, s.Y * 0.34, -s.Z * 0.555) * CFrame.Angles(0, rad(90), 0), { Shape = Enum.PartType.Cylinder, Reflectance = 0.3 })
		for k = -1, 1, 2 do -- the X on the buckle
			gear(char, lower, "BuckleX", Vector3.new(s.Y * 0.52, 0.06, 0.05), YEL, M.Metal,
				CFrame.new(0, s.Y * 0.34, -s.Z * 0.57 - 0.07) * CFrame.Angles(0, 0, rad(k * 45)), { Reflectance = 0.25 })
		end
	end
end

local function weaponXGear(char, head)
	local GUN, DARK = rgb(58, 58, 62), rgb(34, 34, 38)
	-- the body they built: bare, scarred and cut like a statue
	local tone = head and head.Color or rgb(226, 176, 140)
	local shade = tone:Lerp(Color3.new(0, 0, 0), 0.22)
	physique(char, { Chest = tone, Shade = shade, Abs = tone, Traps = tone, Material = M.SmoothPlastic })
	shoulders(char, tone, M.SmoothPlastic, 1, true)
	if head then
		local hs = head.Size
		-- helmet shell and visor band, boxed to fit the block head
		gear(char, head, "Helmet", Vector3.new(hs.X * 1.1, hs.Y * 0.56, hs.Z * 1.1), GUN, M.Metal,
			CFrame.new(0, hs.Y * 0.25, hs.Z * 0.01), { Reflectance = 0.08 })
		gear(char, head, "Band", Vector3.new(hs.X * 1.14, hs.Y * 0.2, hs.Z * 1.14), DARK, M.Metal, CFrame.new(0, hs.Y * 0.07, 0))
		-- glowing red visor wrapping the eyes
		local visor = gear(char, head, "Visor", Vector3.new(hs.X * 0.9, hs.Y * 0.09, 0.05), rgb(255, 40, 40), M.Neon, CFrame.new(0, hs.Y * 0.07, -(hs.Z * 0.57 + 0.025)))
		for s = -1, 1, 2 do
			gear(char, head, "Visor", Vector3.new(0.05, hs.Y * 0.09, hs.Z * 0.5), rgb(255, 40, 40), M.Neon,
				CFrame.new(s * (hs.X * 0.57 + 0.025), hs.Y * 0.07, -hs.Z * 0.25))
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
		gear(char, head, "Ridge", Vector3.new(hs.X * 0.16, hs.Y * 0.14, hs.Z * 0.95), DARK, M.Metal, CFrame.new(0, hs.Y * 0.57, hs.Z * 0.02))
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

	-- electrode pads on the chest trailing wires, clamp rings on the
	-- forearms, braces on the knees
	if torso then
		local s = torso.Size
		for _, e in { { -0.3, 0.3 }, { 0.3, 0.3 }, { -0.2, -0.2 }, { 0.26, -0.24 } } do
			local pad = gear(char, torso, "Electrode", Vector3.new(0.05, 0.3, 0.3), rgb(210, 210, 215), M.SmoothPlastic,
				CFrame.new(s.X * e[1], s.Y * e[2], -s.Z * 0.53) * CFrame.Angles(0, rad(90), 0), { Shape = Enum.PartType.Cylinder })
			pad.Name = "Electrode"
			cable(char, torso, { Vector3.new(s.X * e[1], s.Y * e[2], -s.Z * 0.56), Vector3.new(s.X * e[1] * 1.4, s.Y * (e[2] - 0.2), -s.Z * 0.62), Vector3.new(s.X * 0.5, -s.Y * 0.5, -s.Z * 0.3) }, 0.05, rgb(160, 30, 30))
		end
	end
	for _, n in { "RightLowerArm", "LeftLowerArm" } do
		local arm = char:FindFirstChild(n)
		if arm then
			local s = arm.Size
			for _, y in { 0.25, -0.2 } do
				gear(char, arm, "Clamp", Vector3.new(s.X * 1.18, s.Y * 0.1, s.Z * 1.18), rgb(120, 122, 128), M.Metal, CFrame.new(0, s.Y * y, 0), { Reflectance = 0.2 })
			end
		end
	end
	for _, n in { "RightLowerLeg", "LeftLowerLeg" } do
		local leg = char:FindFirstChild(n)
		if leg then
			local s = leg.Size
			gear(char, leg, "KneeBrace", Vector3.new(s.X * 1.2, s.Y * 0.26, s.Z * 1.2), rgb(70, 72, 78), M.Metal, CFrame.new(0, s.Y * 0.36, 0))
			gear(char, leg, "BraceBolt", Vector3.new(0.12, 0.2, 0.2), rgb(150, 150, 155), M.Metal, CFrame.new(s.X * 0.62, s.Y * 0.36, 0), { Shape = Enum.PartType.Cylinder })
		end
	end

	-- a restraint collar round the neck and a spine plate the helmet cables
	-- plug into; broken shackles on the wrists and ankles, a snapped link
	-- hanging off each
	if torso then
		local s = torso.Size
		gear(char, torso, "Collar", Vector3.new(s.Y * 0.2, s.X * 0.66, s.X * 0.66), GUN, M.Metal,
			CFrame.new(0, s.Y * 0.5, 0) * CFrame.Angles(0, 0, rad(90)), { Shape = Enum.PartType.Cylinder, Reflectance = 0.1 })
		gear(char, torso, "CollarRing", Vector3.new(s.Y * 0.05, s.X * 0.68, s.X * 0.68), DARK, M.Metal,
			CFrame.new(0, s.Y * 0.44, 0) * CFrame.Angles(0, 0, rad(90)), { Shape = Enum.PartType.Cylinder })
		gear(char, torso, "CollarLED", Vector3.new(0.12, 0.08, 0.04), rgb(255, 40, 40), M.Neon, CFrame.new(0, s.Y * 0.5, -s.X * 0.33 - 0.01))
		gear(char, torso, "SpinePlate", Vector3.new(s.X * 0.22, s.Y * 0.84, 0.14), DARK, M.Metal, CFrame.new(0, s.Y * 0.02, s.Z * 0.56))
		for k = -1, 1 do
			gear(char, torso, "SpinePort", Vector3.new(0.1, 0.18, 0.18), rgb(150, 150, 155), M.Metal,
				CFrame.new(0, s.Y * (0.08 + k * 0.24), s.Z * 0.64) * CFrame.Angles(0, rad(90), 0), { Shape = Enum.PartType.Cylinder, Reflectance = 0.2 })
		end
	end
	for _, n in { "RightLowerArm", "LeftLowerArm", "RightLowerLeg", "LeftLowerLeg" } do
		local limb = char:FindFirstChild(n)
		if limb then
			local s = limb.Size
			local side = n:sub(1, 5) == "Right" and 1 or -1
			local y = -s.Y * 0.36
			gear(char, limb, "Shackle", Vector3.new(s.X * 1.24, s.Y * 0.2, s.Z * 1.24), GUN, M.Metal, CFrame.new(0, y, 0), { Reflectance = 0.15 })
			gear(char, limb, "ShackleRidge", Vector3.new(s.X * 1.28, s.Y * 0.04, s.Z * 1.28), DARK, M.Metal, CFrame.new(0, y, 0))
			gear(char, limb, "ShackleBolt", Vector3.new(0.1, 0.16, 0.16), rgb(150, 150, 155), M.Metal, CFrame.new(side * s.X * 0.66, y, 0), { Shape = Enum.PartType.Cylinder })
			gear(char, limb, "Link", Vector3.new(0.07, 0.3, 0.18), rgb(120, 122, 128), M.Metal, CFrame.new(side * s.X * 0.68, y - 0.2, 0), { Reflectance = 0.2 })
			gear(char, limb, "Link", Vector3.new(0.18, 0.28, 0.07), rgb(120, 122, 128), M.Metal,
				CFrame.new(side * s.X * 0.7, y - 0.44, 0) * CFrame.Angles(0, 0, rad(side * 18)), { Reflectance = 0.2 })
		end
	end

	-- cables wrapped around the arms and legs
	wrap(char, char:FindFirstChild("RightUpperArm"), 1.6, 0.08, 0.35, -0.4)
	wrap(char, char:FindFirstChild("LeftLowerArm"), 1.8, 0.08, 0.4, -0.35)
	wrap(char, char:FindFirstChild("RightLowerArm"), 1.2, 0.07, 0.3, -0.3)
	wrap(char, char:FindFirstChild("LeftUpperLeg"), 1.8, 0.09, 0.4, -0.4)
	wrap(char, char:FindFirstChild("RightUpperLeg"), 1.2, 0.08, 0.3, -0.35)
	wrap(char, char:FindFirstChild("RightLowerLeg"), 1.4, 0.08, 0.4, -0.2)
end

-- Logan: brown leather jacket (open over a maroon shirt and grey tee) with
-- the orange-striped sleeves, jeans and a heavy belt.
local function loganGear(char)
	local LEATHER, DARK, STRIPE = rgb(92, 58, 36), rgb(58, 36, 22), rgb(206, 118, 44)
	local MAROON, TEE = rgb(104, 34, 40), rgb(128, 128, 132)
	local torso = char:FindFirstChild("UpperTorso")
	if torso then
		local s = torso.Size
		local t = 0.08
		local fz = -(s.Z / 2 + t / 2)
		gear(char, torso, "JacketBack", Vector3.new(s.X + 2 * t, s.Y, t), LEATHER, M.Leather, CFrame.new(0, 0, s.Z / 2 + t / 2))
		for _, side in { -1, 1 } do
			gear(char, torso, "JacketSide", Vector3.new(t, s.Y * 0.97, s.Z), LEATHER, M.Leather, CFrame.new(side * (s.X / 2 + t / 2), -s.Y * 0.015, 0))
			-- open front panels, the shirt shows down the middle
			gear(char, torso, "JacketFront", Vector3.new(s.X * 0.34, s.Y, t), LEATHER, M.Leather, CFrame.new(side * s.X * 0.33, 0, fz))
			gear(char, torso, "JacketShoulder", Vector3.new(s.X * 0.36, t, s.Z + 2 * t), LEATHER, M.Leather, CFrame.new(side * s.X * 0.33, s.Y / 2 + t / 2, 0))
			-- folded-back sheepskin collar
			gear(char, torso, "Lapel", Vector3.new(s.X * 0.15, s.Y * 0.34, t), rgb(196, 170, 130), M.Fabric,
				CFrame.new(side * s.X * 0.19, s.Y * 0.3, fz - t) * CFrame.Angles(0, 0, rad(side * 24)))
			-- hem band
			gear(char, torso, "JacketHem", Vector3.new(s.X * 0.36, s.Y * 0.09, t * 1.4), DARK, M.Leather, CFrame.new(side * s.X * 0.33, -s.Y * 0.466, fz))
		end
		-- maroon shirt and the grey tee at the neck
		gear(char, torso, "ShirtFront", Vector3.new(s.X * 0.34, s.Y * 0.98, t * 0.5), MAROON, M.Fabric, CFrame.new(0, 0, -(s.Z / 2 + t * 0.25)))
		gear(char, torso, "TeeNeck", Vector3.new(s.X * 0.22, s.Y * 0.14, t * 0.8), TEE, M.Fabric, CFrame.new(0, s.Y * 0.405, -(s.Z / 2 + t * 0.4)))
		gear(char, torso, "Zip", Vector3.new(0.05, s.Y * 0.5, t * 0.6), rgb(30, 22, 16), M.Metal, CFrame.new(-s.X * 0.4, -s.Y * 0.08, fz - t * 0.5))
		-- sheepskin collar turned up round the back of the neck
		gear(char, torso, "Sheepskin", Vector3.new(s.X * 0.8, s.Y * 0.16, s.Z * 0.5), rgb(196, 170, 130), M.Fabric, CFrame.new(0, s.Y * 0.52, s.Z * 0.34))
		-- dog tags on a chain over the tee
		for side = -1, 1, 2 do
			gear(char, torso, "Chain", Vector3.new(0.03, s.Y * 0.36, 0.03), rgb(170, 170, 176), M.Metal,
				CFrame.new(side * s.X * 0.07, s.Y * 0.3, -(s.Z / 2 + t * 0.7)) * CFrame.Angles(0, 0, rad(side * 22)), { Reflectance = 0.3 })
		end
		for k = 0, 1 do
			gear(char, torso, "DogTag", Vector3.new(0.16, 0.24, 0.03), rgb(185, 186, 192), M.Metal,
				CFrame.new(k * 0.06 - 0.03, s.Y * 0.1 - k * 0.04, -(s.Z / 2 + t * 0.8)) * CFrame.Angles(0, 0, rad(k * 12 - 6)), { Reflectance = 0.35 })
		end
	end
	for _, n in { "RightLowerLeg", "LeftLowerLeg" } do -- rolled jeans cuffs
		local leg = char:FindFirstChild(n)
		if leg then
			local s = leg.Size
			gear(char, leg, "JeansCuff", Vector3.new(s.X * 1.1, s.Y * 0.14, s.Z * 1.1), rgb(40, 56, 92), M.Fabric, CFrame.new(0, -s.Y * 0.075, 0)) -- turned up over the boot top
		end
	end
	boots(char, rgb(70, 46, 28), rgb(26, 20, 16))
	for _, n in { "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm" } do
		local arm = char:FindFirstChild(n)
		if arm then
			local s = arm.Size
			gear(char, arm, "Sleeve", Vector3.new(s.X * 1.06, s.Y * 1.03, s.Z * 1.06), LEATHER, M.Leather, CFrame.new())
			if n:find("Upper") then
				-- the three orange racing stripes round each sleeve
				for k = 0, 2 do
					gear(char, arm, "SleeveStripe", Vector3.new(s.X * 1.1, s.Y * 0.06, s.Z * 1.1), STRIPE, M.Fabric, CFrame.new(0, -s.Y * (0.02 + k * 0.12), 0))
				end
			else
				gear(char, arm, "Cuff", Vector3.new(s.X * 1.1, s.Y * 0.14, s.Z * 1.1), DARK, M.Leather, CFrame.new(0, -s.Y * 0.43, 0))
			end
		end
	end
	local lower = char:FindFirstChild("LowerTorso")
	if lower then
		local s = lower.Size
		gear(char, lower, "Belt", Vector3.new(s.X * 1.05, s.Y * 0.3, s.Z * 1.1), rgb(34, 26, 20), M.Leather, CFrame.new(0, s.Y * 0.3, 0))
		local buckle = gear(char, lower, "Buckle", Vector3.new(s.X * 0.16, s.Y * 0.34, 0.06), rgb(170, 170, 176), M.Metal, CFrame.new(0, s.Y * 0.3, -s.Z * 0.56))
		buckle.Reflectance = 0.25
	end
	-- the jacket's cut: rounded shoulders, chest pockets with snaps, zips down
	-- the open front, a ribbed waistband and seams across the back
	shoulders(char, LEATHER, M.Leather, 1, true)
	if torso then
		local s = torso.Size
		local t = 0.08
		local front, back = -(s.Z / 2 + t + 0.02), s.Z / 2 + t + 0.01
		for k = 0, 2 do
			gear(char, torso, "Rib", Vector3.new(s.X + 2 * t + 0.02, 0.05, 0.03), DARK, M.Leather, CFrame.new(0, -s.Y * (0.39 + k * 0.035), back))
		end
		gear(char, torso, "Yoke", Vector3.new(s.X + 2 * t, 0.04, 0.02), DARK, M.Leather, CFrame.new(0, s.Y * 0.22, back))
		for _, side in { -1, 1 } do
			gear(char, torso, "PocketFlap", Vector3.new(s.X * 0.2, s.Y * 0.08, 0.05), DARK, M.Leather, CFrame.new(side * s.X * 0.34, s.Y * 0.14, front))
			gear(char, torso, "Snap", Vector3.new(0.04, 0.09, 0.09), rgb(170, 170, 176), M.Metal,
				CFrame.new(side * s.X * 0.34, s.Y * 0.12, front - 0.03) * CFrame.Angles(0, rad(90), 0), { Shape = Enum.PartType.Cylinder, Reflectance = 0.3 })
			gear(char, torso, "ZipEdge", Vector3.new(0.04, s.Y * 0.84, 0.03), rgb(150, 140, 120), M.Metal, CFrame.new(side * s.X * 0.165, -s.Y * 0.06, front + 0.01), { Reflectance = 0.2 })
			gear(char, torso, "Seam", Vector3.new(0.03, s.Y * 0.6, 0.02), DARK, M.Leather, CFrame.new(side * s.X * 0.25, -s.Y * 0.1, back))
		end
	end
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
	local COAT, COAT2 = rgb(60, 44, 34), rgb(46, 34, 26)
	if torso then
		local s = torso.Size
		local t = 0.09
		-- the duster's body: back, sides and open fronts over the shirt
		gear(char, torso, "CoatBack", Vector3.new(s.X + 2 * t, s.Y, t), COAT, M.Leather, CFrame.new(0, 0, s.Z / 2 + t / 2))
		for side = -1, 1, 2 do
			gear(char, torso, "CoatSide", Vector3.new(t, s.Y * 0.98, s.Z), COAT, M.Leather, CFrame.new(side * (s.X / 2 + t / 2), 0, 0))
			gear(char, torso, "CoatFront", Vector3.new(s.X * 0.3, s.Y, t), COAT, M.Leather, CFrame.new(side * s.X * 0.35, 0, -(s.Z / 2 + t / 2)))
			gear(char, torso, "CoatShoulder", Vector3.new(s.X * 0.4, t, s.Z + 2 * t), COAT2, M.Leather, CFrame.new(side * s.X * 0.3, s.Y / 2 + t / 2, 0))
			gear(char, torso, "Lapel", Vector3.new(s.X * 0.16, s.Y * 0.36, t), COAT2, M.Leather,
				CFrame.new(side * s.X * 0.22, s.Y * 0.28, -(s.Z / 2 + t * 1.5)) * CFrame.Angles(0, 0, rad(side * 22)))
		end
		-- turned-up collar
		gear(char, torso, "Collar", Vector3.new(s.X * 1.12, s.Y * 0.26, s.Z * 1.22), COAT2, M.Leather, CFrame.new(0, s.Y * 0.52, 0.05))
	end
	for _, n in { "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm" } do
		local arm = char:FindFirstChild(n)
		if arm then
			local s = arm.Size
			gear(char, arm, "CoatSleeve", Vector3.new(s.X * 1.08, s.Y * 1.02, s.Z * 1.08), COAT, M.Leather, CFrame.new())
			if n:find("Lower") then
				gear(char, arm, "SleeveCuff", Vector3.new(s.X * 1.16, s.Y * 0.2, s.Z * 1.16), COAT2, M.Leather, CFrame.new(0, -s.Y * 0.4, 0))
			end
		end
	end
	-- a ragged hem on the coat tails
	if lower then
		local s = lower.Size
		for k = -2, 2 do
			gear(char, lower, "Tatter", Vector3.new(s.X * 0.18, s.Y * 0.5, 0.1), COAT2, M.Leather,
				CFrame.new(k * s.X * 0.2, -s.Y * 3.2, s.Z * 0.62) * CFrame.Angles(rad(8), 0, rad(k * 7)), { Class = "WedgePart" })
		end
	end
	-- a thick grey beard jutting out under the chin. Its front stands well
	-- clear of the face (a hair's breadth off it flickered against the drawn
	-- beard), and the tip is set back behind it.
	local head = char:FindFirstChild("Head")
	if head then
		local hs = head.Size
		gear(char, head, "Beard", Vector3.new(hs.X * 0.86, hs.Y * 0.34, hs.Z * 0.4), rgb(184, 182, 176), M.Fabric, CFrame.new(0, -hs.Y * 0.5, -hs.Z * 0.38))
		gear(char, head, "BeardTip", Vector3.new(hs.X * 0.5, hs.Y * 0.24, hs.Z * 0.26), rgb(170, 168, 162), M.Fabric,
			CFrame.new(0, -hs.Y * 0.68, -hs.Z * 0.34) * CFrame.Angles(rad(180), 0, 0), { Class = "WedgePart" })
	end
	boots(char, rgb(48, 36, 28), rgb(24, 20, 16))
	-- heavy, rounded shoulders on the duster
	shoulders(char, COAT, M.Leather, 1.12, true)
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
	-- always his own natural skin tone, whatever colour the player's avatar is
	local skinTone = Skins.SkinTone
	if head then
		head.Color = skinTone
		local sa = head:FindFirstChildOfClass("SurfaceAppearance")
		if sa then
			sa:Destroy()
		end
		if head:IsA("MeshPart") then
			pcall(function()
				head.TextureID = ""
			end)
		end
	end
	local hasShirt, hasPants = asset(tex.Shirt), asset(tex.Pants)

	for _, d in char:GetChildren() do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("BodyColors") then
			d:Destroy()
		elseif d:IsA("Accessory") and not (skin.KeepHair and d.AccessoryType == Enum.AccessoryType.Hair) then
			d:Destroy()
		end
	end

	-- Base body colours: skin tone under a clothing texture (its see-through
	-- bits are bare skin), the suit's flat colours where there's no texture
	for slot, names in SLOT_PARTS do
		local color = skin.Colors[slot]
		if color == "Skin" or (hasShirt and SHIRT_SLOTS[slot]) or (hasPants and PANTS_SLOTS[slot]) then
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
		-- Wolverine's face as a decal (decals wrap the round head properly).
		-- The avatar finishes loading after we dress and re-adds its own face,
		-- so any other face decal that shows up is removed.
		for _, d in head:GetChildren() do
			if d:IsA("Decal") and d.Name ~= "WolverineFace" then
				d:Destroy()
			end
		end
		-- newer default heads can carry the face in the mesh texture itself
		for _, d in head:GetChildren() do
			if d:IsA("SurfaceAppearance") or d.ClassName == "FaceControls" then
				d:Destroy()
			end
		end
		pcall(function()
			if head:IsA("MeshPart") then
				head.TextureID = ""
			end
		end)
		local face = head:FindFirstChild("WolverineFace") or Instance.new("Decal")
		face.Name = "WolverineFace"
		face.Face = Enum.NormalId.Front
		face.Texture = asset(tex.Face)
		face.Parent = head
		if not head:GetAttribute("FaceGuard") then
			head:SetAttribute("FaceGuard", true)
			pcall(function()
				head.ChildAdded:Connect(function(d)
					task.defer(function()
						if d.Parent == head and d:IsA("Decal") and d.Name ~= "WolverineFace" then
							d:Destroy()
						end
					end)
				end)
			end)
		end
	end

	if skinId == "Logan" then
		loganGear(char)
	elseif skinId == "Comic" then
		comicGear(char, head)
	elseif skinId == "WeaponX" then
		weaponXGear(char, head)
	elseif skinId == "OldManLogan" then
		oldManGear(char)
	end
	if head and skin.FaceStyle and FACE_STYLES[skin.FaceStyle] and not asset(tex.Face) then
		faceBlock(char, head, skin.FaceStyle, skin.FaceHair, skinTone)
	end
	if skin.Hair and (skin.HairAccessoryId or 0) == 0 then
		wolverineHair(char, head, skin.Hair.Color, skin.Hair)
	end
	loadHair(char, skin.HairAccessoryId)
end

---------------------------------------------------------------------------
-- Claws: curved, tapered chrome blades with a bright cutting edge
---------------------------------------------------------------------------

local function lighten(c, f)
	return c:Lerp(Color3.new(1, 1, 1), f)
end

-- Three claw blades on one hand/fist part. `owner` is the model that holds the gear folder.
local function bladesOn(owner, hand, claw, extended, set)
	local L = Costumes.CLAW_LEN
	local thick = claw.Thick or 1
	local edgeColor = claw.EdgeColor or lighten(claw.Color, 0.65)
	local spineColor = claw.SpineColor or claw.Color:Lerp(Color3.new(0, 0, 0), 0.35)
	local out = CFrame.new(0, -hand.Size.Y * 0.3, -hand.Size.Z * 0.1)
	local tucked = CFrame.new(0, L * 0.5, -hand.Size.Z * 0.1)
	local root, rootWeld = Costumes.Gear(owner, hand, "ClawRoot", Vector3.one * 0.05, Color3.new(), M.SmoothPlastic, extended and out or tucked, { Transparency = 1 }, "Claws")
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
			local body = Costumes.Gear(owner, root, "Claw", Vector3.new(t, sg.Len + 0.02, w), claw.Color, claw.Material, center, { Reflectance = claw.Reflectance, Transparency = extended and 0 or 1 }, "Claws")
			-- bright honed edge along the inside curve
			local edge = Costumes.Gear(owner, root, "Claw", Vector3.new(t * 0.7, sg.Len + 0.02, 0.035), edgeColor, M.SmoothPlastic,
				center * CFrame.new(0, 0, -w / 2 - 0.012), { Reflectance = math.min(1, claw.Reflectance + 0.35), Transparency = extended and 0 or 1 }, "Claws")
			-- bevel line on both flats (the Verity faces cover the flats instead)
			for sx = -1, 1, 2 do
				if claw.Verity then
					break
				end
				local bevel = Costumes.Gear(owner, root, "Claw", Vector3.new(0.012, sg.Len, w * 0.06), spineColor, M.SmoothPlastic,
					center * CFrame.new(sx * t / 2, 0, w * 0.12), { Transparency = extended and 0 or 1 }, "Claws")
				table.insert(set.Parts, bevel)
			end
			if claw.Verity then
				Costumes.SmileyStrip(body, Enum.NormalId.Right, extended)
				Costumes.SmileyStrip(body, Enum.NormalId.Left, extended)
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
		local tip = Costumes.Gear(owner, root, "Claw", Vector3.new(0.058 * thick, tipLen, 0.17 * thick), claw.Color, claw.Material,
			f * CFrame.new(0, -tipLen / 2, 0) * CFrame.Angles(0, 0, math.pi), { Class = "WedgePart", Reflectance = claw.Reflectance, Transparency = extended and 0 or 1 }, "Claws")
		table.insert(set.Parts, tip)
		table.insert(set.Tips, tip)
	end
end

-- Builds 3 claws per hand. Returns { Roots = { {Weld, Extended} }, Parts, Tips, Bases }.
-- `display`: a statue carrying every claw skin at once (no Verity badges:
-- a SurfaceGui still shows on a hidden part)
function Costumes.BuildClaws(char, claw, extended, display)
	local set = { Roots = {}, Parts = {}, Tips = {}, Bases = {} }
	for _, side in { "Right", "Left" } do
		local hand = Util.Hand(char, side)
		if hand then
			bladesOn(char, hand, claw, extended, set)
		end
		-- Verity: the grin on a badge on the outside of each forearm
		local arm = claw.Verity and not display and char:FindFirstChild(side .. "LowerArm")
		if arm then
			local s = arm.Size
			local sx = side == "Right" and 1 or -1
			local badge = Costumes.Gear(char, arm, "VerityBadge", Vector3.new(0.06, s.X * 0.8, s.X * 0.8), rgb(18, 16, 16), M.SmoothPlastic, CFrame.new(sx * (s.X / 2 + 0.03), -s.Y * 0.1, 0), nil, "Claws")
			Costumes.Smiley(badge, sx == 1 and Enum.NormalId.Right or Enum.NormalId.Left)
		end
	end
	return set
end

-- Display piece: a gloved fist with its claws out (used in the lobby).
function Costumes.ClawDisplay(parent, cframe, claw)
	local model = Instance.new("Model")
	model.Name = "ClawDisplay"
	local function p(size, cf, color, mat, props)
		local part = Instance.new(props and props.Class or "Part")
		part.Anchored = true
		part.CanCollide = false
		part.Size = size
		part.CFrame = cf
		part.Color = color
		part.Material = mat
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if props then
			for k, v in props do
				if k ~= "Class" then
					part[k] = v
				end
			end
		end
		part.Parent = model
		return part
	end
	-- the fist points its knuckles up: hand -Y = up
	local fistCf = cframe * CFrame.Angles(math.pi, 0, 0)
	local glove = rgb(26, 24, 28)
	local fist = p(Vector3.new(0.8, 0.9, 1.05), fistCf, glove, M.Leather)
	for k = -1, 1 do -- knuckle ridge
		p(Vector3.new(0.84, 0.18, 0.28), fistCf * CFrame.new(0, -0.4, k * 0.32), rgb(40, 38, 44), M.Leather)
	end
	p(Vector3.new(0.3, 0.5, 0.9), fistCf * CFrame.new(0.5, 0.05, 0), glove, M.Leather) -- thumb
	p(Vector3.new(1.4, 0.7, 0.7), fistCf * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, rad(90)), rgb(34, 32, 36), M.Leather, { Shape = Enum.PartType.Cylinder })
	p(Vector3.new(0.18, 0.76, 0.76), fistCf * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, rad(90)), rgb(120, 122, 128), M.Metal, { Shape = Enum.PartType.Cylinder })
	bladesOn(model, fist, claw, true, { Roots = {}, Parts = {}, Tips = {}, Bases = {} })
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model.Parent = parent
	return model
end

-- SNIKT: blades slide out of the knuckles.
function Costumes.PopClaws(set)
	for _, p in set.Parts do
		p.Transparency = 0
		for _, sg in p:GetChildren() do
			if sg:IsA("SurfaceGui") and sg.Name == "VerityFaces" then
				sg.Enabled = true
			end
		end
	end
	local info = TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	for _, r in set.Roots do
		TweenService:Create(r.Weld, info, { C0 = r.Extended }):Play()
	end
end

---------------------------------------------------------------------------
-- Sentinel armour (purple-blue plates, magenta limbs, gold face, glowing core)
---------------------------------------------------------------------------

-- Survivors are Weapon X scientists: lab coat over their own avatar, ID badge,
-- pens and safety glasses. Sized from each body part, so it fits any R15 avatar.
function Costumes.DressScientist(char)
	local old = char:FindFirstChild("LabCoat")
	if old then
		old:Destroy()
	end
	local coat = rgb(236, 238, 240)
	local shade = rgb(214, 218, 222)
	local function g(anchor, name, size, color, mat, offset, props)
		return gear(char, anchor, name, size, color, mat or M.Fabric, offset, props, "LabCoat")
	end
	local torso = char:FindFirstChild("UpperTorso")
	if torso then
		local s = torso.Size
		-- back + sides + shoulders, open at the front
		g(torso, "CoatBack", Vector3.new(s.X * 1.08, s.Y * 1.02, 0.12), coat, nil, CFrame.new(0, 0, s.Z * 0.56))
		for sx = -1, 1, 2 do
			g(torso, "CoatSide", Vector3.new(0.12, s.Y * 1.02, s.Z * 1.12), coat, nil, CFrame.new(sx * s.X * 0.54, 0, 0))
			g(torso, "CoatFront", Vector3.new(s.X * 0.36, s.Y * 1.02, 0.12), coat, nil, CFrame.new(sx * s.X * 0.36, 0, -s.Z * 0.56))
			g(torso, "Shoulder", Vector3.new(s.X * 0.36, 0.12, s.Z * 1.12), coat, nil, CFrame.new(sx * s.X * 0.36, s.Y * 0.51, 0))
			-- lapels
			g(torso, "Lapel", Vector3.new(s.X * 0.14, s.Y * 0.42, 0.1), shade, nil, CFrame.new(sx * s.X * 0.22, s.Y * 0.28, -s.Z * 0.63) * CFrame.Angles(0, 0, math.rad(sx * 18)))
			g(torso, "Seam", Vector3.new(0.05, s.Y * 0.9, 0.14), shade, nil, CFrame.new(sx * s.X * 0.2, -0.05, -s.Z * 0.57))
		end
		-- breast pocket with pens, ID badge on a lanyard
		g(torso, "Pocket", Vector3.new(s.X * 0.22, s.Y * 0.2, 0.06), shade, nil, CFrame.new(-s.X * 0.34, s.Y * 0.12, -s.Z * 0.64))
		local penColors = { rgb(30, 60, 200), rgb(200, 30, 30), rgb(20, 20, 20) }
		for i = 1, 3 do
			g(torso, "Pen", Vector3.new(0.05, s.Y * 0.18, 0.05), penColors[i], M.SmoothPlastic, CFrame.new(-s.X * 0.4 + i * s.X * 0.045, s.Y * 0.24, -s.Z * 0.66))
		end
		g(torso, "Lanyard", Vector3.new(0.04, s.Y * 0.4, 0.04), rgb(170, 30, 26), M.SmoothPlastic, CFrame.new(s.X * 0.18, s.Y * 0.2, -s.Z * 0.62) * CFrame.Angles(0, 0, math.rad(12)))
		local badge = g(torso, "Badge", Vector3.new(s.X * 0.18, s.Y * 0.22, 0.04), rgb(245, 245, 245), M.SmoothPlastic, CFrame.new(s.X * 0.24, -s.Y * 0.04, -s.Z * 0.64))
		g(torso, "BadgeStripe", Vector3.new(s.X * 0.18, s.Y * 0.05, 0.05), rgb(40, 90, 200), M.SmoothPlastic, CFrame.new(s.X * 0.24, s.Y * 0.05, -s.Z * 0.645))
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 1
		gui.CanvasSize = Vector2.new(60, 70)
		gui.Parent = badge
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 0.6)
		t.Position = UDim2.fromScale(0, 0.4)
		t.TextScaled = true
		t.Font = Enum.Font.Code
		t.TextColor3 = rgb(20, 20, 20)
		t.Text = "WX\nSTAFF"
		t.Parent = gui
	end
	local lower = char:FindFirstChild("LowerTorso")
	if lower then
		local s = lower.Size
		g(lower, "CoatWaist", Vector3.new(s.X * 1.1, s.Y * 1.1, s.Z * 1.14), coat, nil, CFrame.new(0, 0, 0.02))
		for sx = -1, 1, 2 do
			g(lower, "CoatTail", Vector3.new(s.X * 0.54, s.Y * 5.4, 0.12), coat, nil, CFrame.new(sx * s.X * 0.27, -s.Y * 2.6, s.Z * 0.62) * CFrame.Angles(math.rad(6), 0, math.rad(sx * 3)))
			g(lower, "CoatFlap", Vector3.new(s.X * 0.34, s.Y * 5, 0.1), coat, nil, CFrame.new(sx * s.X * 0.4, -s.Y * 2.4, -s.Z * 0.62) * CFrame.Angles(math.rad(-5), 0, math.rad(sx * 5)))
			g(lower, "CoatHem", Vector3.new(0.12, s.Y * 5.2, s.Z * 1.1), coat, nil, CFrame.new(sx * s.X * 0.56, -s.Y * 2.5, 0) * CFrame.Angles(0, 0, math.rad(sx * 4)))
		end
	end
	for _, side in { "Left", "Right" } do
		local ua = char:FindFirstChild(side .. "UpperArm")
		if ua then
			local s = ua.Size
			g(ua, "Sleeve", Vector3.new(s.X * 1.12, s.Y * 1.02, s.Z * 1.12), coat, nil, CFrame.new())
		end
		local la = char:FindFirstChild(side .. "LowerArm")
		if la then
			local s = la.Size
			g(la, "Cuff", Vector3.new(s.X * 1.14, s.Y * 0.7, s.Z * 1.14), coat, nil, CFrame.new(0, s.Y * 0.15, 0))
		end
	end
	local head = char:FindFirstChild("Head")
	if head then
		local s = head.Size
		g(head, "Glasses", Vector3.new(s.X * 0.86, s.Y * 0.18, 0.05), rgb(180, 220, 240), M.Glass, CFrame.new(0, s.Y * 0.1, -s.Z * 0.53), { Transparency = 0.55 })
		g(head, "GlassesFrame", Vector3.new(s.X * 0.9, 0.05, 0.07), rgb(30, 30, 32), M.SmoothPlastic, CFrame.new(0, s.Y * 0.2, -s.Z * 0.54))
		for sx = -1, 1, 2 do
			g(head, "GlassesArm", Vector3.new(0.05, 0.05, s.Z * 0.6), rgb(30, 30, 32), M.SmoothPlastic, CFrame.new(sx * s.X * 0.46, s.Y * 0.18, -s.Z * 0.2))
		end
	end
end

-- The Verity grin, drawn with frames (no image uploads) into a square
-- `cell`: two black eyes and a big open smile, a D shape (flat along the
-- top, round along the bottom) with a dark outline. `teeth` adds the tooth
-- lines (only readable on the bigger faces).
local INK_DARK = rgb(20, 10, 10)
local function drawGrin(cell, outline, teeth)
	local function f(props, parent)
		local fr = Instance.new("Frame")
		fr.BorderSizePixel = 0
		for k, v in props do
			fr[k] = v
		end
		fr.Parent = parent
		return fr
	end
	local function round(fr)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = fr
	end
	for _, x in { 0.34, 0.66 } do
		round(f({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.36), Size = UDim2.fromScale(0.12, 0.22), BackgroundColor3 = INK_DARK }, cell))
	end
	-- the smile: an ellipse centred on the top edge of a clipping box, so only
	-- its bottom half shows
	local clip = f({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.fromScale(0.66, 0.3), BackgroundTransparency = 1, ClipsDescendants = true }, cell)
	local lip = f({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(1, 2), BackgroundColor3 = INK_DARK }, clip)
	round(lip)
	local inner = f({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -outline * 2, 1, -outline * 2), BackgroundColor3 = rgb(250, 248, 240) }, lip)
	round(inner)
	f({ Position = UDim2.fromScale(0, 0), Size = UDim2.new(1, 0, 0, outline), BackgroundColor3 = INK_DARK, ZIndex = 3 }, clip) -- top lip
	if teeth then
		for i = 1, 5 do
			f({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(i / 6, 0), Size = UDim2.new(0, math.max(1, outline * 0.6), 0.62, 0), BackgroundColor3 = INK_DARK, ZIndex = 3 }, clip)
		end
		f({ Position = UDim2.fromScale(0.08, 0.34), Size = UDim2.new(0.84, 0, 0, math.max(1, outline * 0.6)), BackgroundColor3 = INK_DARK, ZIndex = 3 }, clip)
	end
end

-- The Verity grin as a badge: a yellow smiley filling one face of `part`.
function Costumes.Smiley(part, face)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Verity"
	sg.Face = face or Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 120
	sg.LightInfluence = 0.4
	sg.Parent = part
	local ball = Instance.new("Frame")
	ball.BorderSizePixel = 0
	ball.AnchorPoint = Vector2.new(0.5, 0.5)
	ball.Position = UDim2.fromScale(0.5, 0.5)
	ball.Size = UDim2.fromScale(0.94, 0.94)
	ball.BackgroundColor3 = rgb(255, 205, 40)
	ball.Parent = sg
	local sq = Instance.new("UIAspectRatioConstraint")
	sq.AspectRatio = 1
	sq.Parent = ball
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = ball
	local rim = Instance.new("UIStroke")
	rim.Color = rgb(150, 100, 10)
	rim.Thickness = 3
	rim.Parent = ball
	drawGrin(ball, 4, true)
	return sg
end

-- A column of little grins running down one face of a long part (the
-- Verity claws: yellow blades covered in faces). Drawn on a SurfaceGui, which
-- still shows on a see-through part, so it starts disabled until the claws
-- are out (PopClaws / the lobby statue turn it on).
function Costumes.SmileyStrip(part, face, enabled)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "VerityFaces"
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 240
	sg.LightInfluence = 0.5
	sg.Enabled = enabled == true
	sg.Parent = part
	local n = math.max(1, math.floor(part.Size.Y / (part.Size.Z * 1.1)))
	for i = 1, n do
		local cell = Instance.new("Frame")
		cell.BorderSizePixel = 0
		cell.BackgroundColor3 = rgb(255, 214, 60)
		cell.AnchorPoint = Vector2.new(0.5, 0.5)
		cell.Position = UDim2.fromScale(0.5, (i - 0.5) / n)
		cell.Size = UDim2.fromScale(0.86, 0.86 / n)
		cell.Parent = sg
		local sq = Instance.new("UIAspectRatioConstraint")
		sq.AspectRatio = 1
		sq.Parent = cell
		local ring = Instance.new("UIStroke")
		ring.Color = INK_DARK
		ring.Thickness = 2
		ring.Parent = cell
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0.5, 0)
		rc.Parent = cell
		drawGrin(cell, 2, false)
	end
	return sg
end

-- Sentinel suit palettes. Default follows the comics: steel-blue armour
-- plates, deep purple limbs and hips, a tall ribbed purple helmet with a
-- silver face and amber eyes, a glowing gold chest disc, dark mechanics.
Costumes.SentinelSkins = {
	Default = {
		Armor = rgb(92, 100, 130), Armor2 = rgb(64, 70, 96), Edge = rgb(128, 136, 166),
		Limb = rgb(112, 54, 124), Helm = rgb(100, 56, 132), Face = rgb(172, 178, 194),
		Mech = rgb(32, 32, 40), Cable = rgb(48, 48, 58),
		Core = rgb(255, 196, 80), Eye = rgb(255, 160, 40), Thruster = rgb(120, 190, 255),
	},
	-- Verity: black armour, yellow limbs, red hoses, core and thrusters, and
	-- the grin painted over the face (Verity = true)
	Verity = {
		Armor = rgb(26, 24, 26), Armor2 = rgb(14, 14, 16), Edge = rgb(255, 205, 40),
		Limb = rgb(240, 190, 30), Helm = rgb(20, 18, 20), Face = rgb(255, 210, 40),
		Mech = rgb(30, 28, 30), Cable = rgb(150, 20, 20),
		Core = rgb(255, 40, 40), Eye = rgb(255, 40, 40), Thruster = rgb(255, 60, 40),
		Verity = true,
	},
}

function Costumes.DressSentinel(char, skinId)
	local P = Costumes.SentinelSkins[skinId or "Default"] or Costumes.SentinelSkins.Default
	local ARMOR, ARMOR2, EDGE = P.Armor, P.Armor2, P.Edge
	local LIMB, HELM, FACE, MECH, CABLE = P.Limb, P.Helm, P.Face, P.Mech, P.Cable
	local F = "SentinelGear"
	local function g(anchor, name, size, color, mat, offset, props)
		-- left-side armour is a hair larger so mirrored pieces never share a face
		if anchor.Name:sub(1, 4) == "Left" then
			size += Vector3.new(0.04, 0.04, 0.04)
		end
		props = props or {}
		if props.Reflectance == nil and (mat == M.Metal) then
			props.Reflectance = 0.06
		end
		return Costumes.Gear(char, anchor, name, size, color, mat or M.Metal, offset, props, F)
	end
	local function round(anchor, name, size, color, offset, mat)
		return g(anchor, name, size, color, mat or M.Metal, offset, { Mesh = Enum.MeshType.Sphere })
	end
	local function tube(anchor, name, a, b, thick, color)
		-- a cable/hose between two points in the anchor's space
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
		return g(anchor, name, Vector3.new((b - a).Magnitude, thick, thick), color, M.SmoothPlastic, cf, { Shape = Enum.PartType.Cylinder })
	end
	local function glow(part, color, range, brightness)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness
		l.Parent = part
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
	local old = char:FindFirstChild(F)
	if old then
		old:Destroy()
	end
	local coat = char:FindFirstChild("LabCoat")
	if coat then
		coat:Destroy()
	end

	-- HEAD: a tall ribbed purple helm over a silver skull face
	local head = char:FindFirstChild("Head")
	if head then
		local hs = head.Size
		round(head, "Helmet", Vector3.new(hs.X * 1.22, hs.Y * 1.3, hs.Z * 1.28), HELM, CFrame.new(0, hs.Y * 0.2, hs.Z * 0.1))
		g(head, "HelmetBand", Vector3.new(hs.X * 1.2, hs.Y * 0.16, hs.Z * 1.22), HELM:Lerp(Color3.new(0, 0, 0), 0.3), M.Metal, CFrame.new(0, hs.Y * 0.16, hs.Z * 0.08))
		for i = -2, 2 do -- ribs running back over the dome
			g(head, "Rib", Vector3.new(hs.X * 0.07, hs.Y * 0.2, hs.Z * 1.16), HELM:Lerp(Color3.new(1, 1, 1), 0.12), M.Metal, CFrame.new(i * hs.X * 0.16, hs.Y * (0.72 - math.abs(i) * 0.07), hs.Z * 0.1))
		end
		g(head, "Crest", Vector3.new(hs.X * 0.14, hs.Y * 0.22, hs.Z * 1.2), EDGE, M.Metal, CFrame.new(0, hs.Y * 0.84, hs.Z * 0.1))
		local faceplate = g(head, "FacePlate", Vector3.new(hs.X * 0.8, hs.Y * 0.7, 0.18), FACE, M.Metal, CFrame.new(0, -hs.Y * 0.06, -hs.Z * 0.56), { Reflectance = 0.18 })
		if P.Verity then
			Costumes.Smiley(faceplate, Enum.NormalId.Front)
		end
		g(head, "Brow", Vector3.new(hs.X * 0.88, hs.Y * 0.14, 0.26), FACE:Lerp(Color3.new(0, 0, 0), 0.3), M.Metal, CFrame.new(0, hs.Y * 0.235, -hs.Z * 0.6))
		if not P.Verity then
			g(head, "Visor", Vector3.new(hs.X * 0.66, hs.Y * 0.12, 0.05), rgb(20, 14, 12), M.SmoothPlastic, CFrame.new(0, hs.Y * 0.08, -hs.Z * 0.65))
		end
		for s = -1, 1, 2 do
			if not P.Verity then
				local eye = g(head, "Eye", Vector3.new(hs.X * 0.2, hs.Y * 0.07, 0.05), P.Eye, M.Neon, CFrame.new(s * hs.X * 0.17, hs.Y * 0.08, -hs.Z * 0.68))
				glow(eye, P.Eye, 6, 1.6)
			end
			g(head, "Cheek", Vector3.new(hs.X * 0.2, hs.Y * 0.24, 0.22), FACE:Lerp(Color3.new(0, 0, 0), 0.18), M.Metal, CFrame.new(s * hs.X * 0.3, -hs.Y * 0.1, -hs.Z * 0.6) * CFrame.Angles(0, rad(s * 20), 0))
			g(head, "EarDisc", Vector3.new(0.16, hs.Y * 0.5, hs.Y * 0.5), HELM:Lerp(Color3.new(0, 0, 0), 0.25), M.Metal, CFrame.new(s * hs.X * 0.62, 0, 0), { Shape = Enum.PartType.Cylinder })
			g(head, "EarBolt", Vector3.new(0.2, hs.Y * 0.2, hs.Y * 0.2), EDGE, M.Metal, CFrame.new(s * hs.X * 0.68, 0, 0), { Shape = Enum.PartType.Cylinder })
		end
		g(head, "Jaw", Vector3.new(hs.X * 0.6, hs.Y * 0.26, 0.22), FACE:Lerp(Color3.new(0, 0, 0), 0.15), M.Metal, CFrame.new(0, -hs.Y * 0.38, -hs.Z * 0.52))
		if not P.Verity then
			for i = 0, 4 do
				g(head, "Grille", Vector3.new(0.04, hs.Y * 0.16, 0.03), rgb(40, 40, 48), M.Metal, CFrame.new((i - 2) * hs.X * 0.09, -hs.Y * 0.36, -hs.Z * 0.64))
			end
		end
	end

	-- TORSO: a massive sculpted chest with the glowing disc, segmented abs,
	-- hoses down the flanks, thrusters on the back
	local torso = char:FindFirstChild("UpperTorso")
	if torso then
		local s = torso.Size
		g(torso, "ChestPlate", Vector3.new(s.X * 1.42, s.Y * 0.6, s.Z * 1.4), ARMOR, M.Metal, CFrame.new(0, s.Y * 0.24, 0))
		for sx = -1, 1, 2 do
			g(torso, "Pec", Vector3.new(s.X * 0.66, s.Y * 0.44, 0.34), ARMOR, M.Metal, CFrame.new(sx * s.X * 0.34, s.Y * 0.2, -s.Z * 0.72) * CFrame.Angles(rad(-6), rad(sx * 14), 0))
			g(torso, "PecEdge", Vector3.new(s.X * 0.64, 0.08, 0.38), EDGE, M.Metal, CFrame.new(sx * s.X * 0.34, -s.Y * 0.02, -s.Z * 0.74) * CFrame.Angles(0, rad(sx * 14), 0))
			g(torso, "Lat", Vector3.new(0.34, s.Y * 0.56, s.Z * 1.14), ARMOR2, M.Metal, CFrame.new(sx * s.X * 0.7, s.Y * 0.1, 0))
			g(torso, "Piston", Vector3.new(0.16, s.Y * 0.62, 0.16), rgb(160, 162, 172), M.Metal, CFrame.new(sx * s.X * 0.44, -s.Y * 0.3, -s.Z * 0.3), { Reflectance = 0.35 })
			tube(torso, "Hose", Vector3.new(sx * s.X * 0.56, s.Y * 0.1, -s.Z * 0.4), Vector3.new(sx * s.X * 0.4, -s.Y * 0.55, -s.Z * 0.5), 0.16, CABLE)
			-- back thrusters: a nozzle with a pale blue glow
			g(torso, "Thruster", Vector3.new(s.Y * 0.4, 0.46, 0.46), MECH, M.Metal, CFrame.new(sx * s.X * 0.26, -s.Y * 0.05, s.Z * 1.08) * CFrame.Angles(0, 0, rad(90)), { Shape = Enum.PartType.Cylinder })
			local jet = g(torso, "ThrusterGlow", Vector3.new(0.06, 0.34, 0.34), P.Thruster, M.Neon, CFrame.new(sx * s.X * 0.26, -s.Y * 0.26, s.Z * 1.08) * CFrame.Angles(0, 0, rad(90)), { Shape = Enum.PartType.Cylinder })
			glow(jet, P.Thruster, 6, 1)
		end
		-- the chest disc: a gold core in a dark bezel with a soft halo
		local core = g(torso, "Core", Vector3.new(0.14, s.X * 0.3, s.X * 0.3), P.Core, M.Neon, CFrame.new(0, s.Y * 0.26, -s.Z * 0.92) * CFrame.Angles(0, rad(90), 0), { Shape = Enum.PartType.Cylinder })
		g(torso, "CoreRing", Vector3.new(0.14, s.X * 0.42, s.X * 0.42), MECH, M.Metal, CFrame.new(0, s.Y * 0.26, -s.Z * 0.88) * CFrame.Angles(0, rad(90), 0), { Shape = Enum.PartType.Cylinder })
		g(torso, "CoreHalo", Vector3.new(0.1, s.X * 0.5, s.X * 0.5), P.Core, M.Neon, CFrame.new(0, s.Y * 0.26, -s.Z * 0.855) * CFrame.Angles(0, rad(90), 0), { Shape = Enum.PartType.Cylinder, Transparency = 0.7 })
		glow(core, P.Core, 16, 3)
		g(torso, "Abdomen", Vector3.new(s.X * 0.72, s.Y * 0.52, s.Z * 1.06), MECH, M.Metal, CFrame.new(0, -s.Y * 0.28, 0))
		for i = 0, 2 do
			for sx = -1, 1, 2 do
				g(torso, "AbPlate", Vector3.new(s.X * 0.25, s.Y * 0.12, 0.16), ARMOR2, M.Metal, CFrame.new(sx * s.X * 0.14, -s.Y * (0.1 + i * 0.15), -s.Z * 0.57) * CFrame.Angles(0, rad(sx * 6), 0))
			end
		end
		g(torso, "Collar", Vector3.new(s.X * 0.84, s.Y * 0.18, s.Z * 1.3), ARMOR2, M.Metal, CFrame.new(0, s.Y * 0.58, 0))
		g(torso, "Neck", Vector3.new(s.X * 0.36, s.Y * 0.24, s.Z * 0.52), MECH, M.Metal, CFrame.new(0, s.Y * 0.63, 0))
		local pack = g(torso, "BackPack", Vector3.new(s.X * 0.95, s.Y * 0.64, s.Z * 0.56), ARMOR2, M.Metal, CFrame.new(0, s.Y * 0.16, s.Z * 0.74))
		if P.Verity then
			local sg = Instance.new("SurfaceGui")
			sg.Face = Enum.NormalId.Back
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = 80
			sg.Parent = pack
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Text = "VERITY"
			t.Font = Enum.Font.Creepster
			t.TextScaled = true
			t.TextColor3 = rgb(230, 30, 30)
			t.Parent = sg
		end
		g(torso, "Spine", Vector3.new(s.X * 0.2, s.Y * 0.9, 0.2), MECH, M.Metal, CFrame.new(0, -s.Y * 0.05, s.Z * 1.02))
	end

	-- HIPS: dark belt and buckle, purple hip armour
	local lower = char:FindFirstChild("LowerTorso")
	if lower then
		local s = lower.Size
		g(lower, "Belt", Vector3.new(s.X * 1.08, s.Y * 0.52, s.Z * 1.12), MECH, M.Metal, CFrame.new(0, s.Y * 0.3, 0))
		g(lower, "Buckle", Vector3.new(s.X * 0.3, s.Y * 0.44, 0.14), EDGE, M.Metal, CFrame.new(0, s.Y * 0.3, -s.Z * 0.6))
		g(lower, "Codpiece", Vector3.new(s.X * 0.42, s.Y * 1.2, 0.22), ARMOR2, M.Metal, CFrame.new(0, -s.Y * 0.25, -s.Z * 0.58))
		for sx = -1, 1, 2 do
			g(lower, "HipPlate", Vector3.new(s.X * 0.44, s.Y * 1.35, s.Z * 1.2), LIMB, M.Metal, CFrame.new(sx * s.X * 0.4, -s.Y * 0.25, 0) * CFrame.Angles(0, 0, rad(sx * 7)))
		end
	end

	-- ARMS: huge round pauldrons, purple biceps, ribbed gauntlets, big fists
	for _, n in { "RightUpperArm", "LeftUpperArm" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			local side = n:sub(1, 5) == "Right" and 1 or -1
			round(p, "Pauldron", Vector3.new(s.X * 2.6, s.Y * 1.02, s.Z * 2.35), ARMOR, CFrame.new(side * s.X * 0.22, s.Y * 0.3, 0))
			round(p, "PauldronCap", Vector3.new(s.X * 1.9, s.Y * 0.5, s.Z * 1.7), EDGE, CFrame.new(side * s.X * 0.28, s.Y * 0.58, 0))
			round(p, "PauldronRim", Vector3.new(s.X * 2.4, s.Y * 0.3, s.Z * 2.2), ARMOR2, CFrame.new(side * s.X * 0.22, s.Y * 0.0, 0))
			g(p, "Bicep", Vector3.new(s.X * 1.4, s.Y * 0.64, s.Z * 1.4), LIMB, M.Metal, CFrame.new(0, -s.Y * 0.16, 0))
		end
	end
	for _, n in { "RightLowerArm", "LeftLowerArm" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			round(p, "Elbow", Vector3.new(s.X * 1.35, s.Y * 0.42, s.Z * 1.35), MECH, CFrame.new(0, s.Y * 0.42, 0))
			g(p, "Gauntlet", Vector3.new(s.X * 1.7, s.Y * 0.95, s.Z * 1.7), ARMOR, M.Metal, CFrame.new(0, -s.Y * 0.06, 0))
			for i = 0, 2 do
				g(p, "GauntletRib", Vector3.new(s.X * 1.76, s.Y * 0.06, s.Z * 1.76), ARMOR2, M.Metal, CFrame.new(0, s.Y * (0.22 - i * 0.2), 0))
			end
			g(p, "GauntletPlate", Vector3.new(s.X * 1.24, s.Y * 0.72, 0.16), EDGE, M.Metal, CFrame.new(0, -s.Y * 0.04, -s.Z * 0.86))
			g(p, "Cuff", Vector3.new(s.X * 1.8, s.Y * 0.16, s.Z * 1.8), ARMOR2, M.Metal, CFrame.new(0, -s.Y * 0.5, 0))
			tube(p, "ArmHose", Vector3.new(s.X * 0.62, s.Y * 0.36, s.Z * 0.5), Vector3.new(s.X * 0.7, -s.Y * 0.42, s.Z * 0.3), 0.12, CABLE)
		end
	end
	for _, n in { "RightHand", "LeftHand" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			g(p, "Fist", s * Vector3.new(1.5, 1.5, 1.46), MECH, M.Metal, CFrame.new(0, -s.Y * 0.1, 0))
			g(p, "Knuckles", Vector3.new(s.X * 1.54, s.Y * 0.5, 0.18), EDGE, M.Metal, CFrame.new(0, -s.Y * 0.2, -s.Z * 0.78))
		end
	end

	-- LEGS: purple thighs, round knee guards, armoured shins, heavy boots.
	-- The legs touch in the middle, so each piece keeps its inner edge just
	-- short of the centre line and carries its bulk outward (armour wider
	-- than the leg used to cut into the other leg, standing or walking).
	-- size X and x offset for a piece `width` legs wide whose inner side sits
	-- `inner` legs from the leg's centre (0.42 for the shells; plates tuck in
	-- a little and bands stand out a little, so no two inner sides share a
	-- plane and flicker)
	local function leg(p, width, inner)
		local side = p.Name:find("Right") and 1 or -1
		return p.Size.X * width, side * p.Size.X * math.max(0, width / 2 - (inner or 0.42))
	end
	for _, n in { "RightUpperLeg", "LeftUpperLeg" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			local w, x = leg(p, 1.36)
			g(p, "Thigh", Vector3.new(w, s.Y * 0.95, s.Z * 1.5), LIMB, M.Metal, CFrame.new(x, 0.02, 0))
			w, x = leg(p, 1, 0.38)
			g(p, "ThighPlate", Vector3.new(w, s.Y * 0.62, 0.16), LIMB:Lerp(Color3.new(1, 1, 1), 0.1), M.Metal, CFrame.new(x, 0.05, -s.Z * 0.78))
		end
	end
	for _, n in { "RightLowerLeg", "LeftLowerLeg" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			local w, x = leg(p, 1.5, 0.445)
			round(p, "Knee", Vector3.new(w, s.Y * 0.58, s.Z * 1.8), ARMOR, CFrame.new(x, s.Y * 0.44, -s.Z * 0.12))
			w, x = leg(p, 1.52)
			g(p, "Shin", Vector3.new(w, s.Y * 1.05, s.Z * 1.8), ARMOR, M.Metal, CFrame.new(x, -s.Y * 0.1, 0))
			w, x = leg(p, 1.1, 0.38)
			g(p, "ShinPlate", Vector3.new(w, s.Y * 0.82, 0.16), EDGE, M.Metal, CFrame.new(x, -s.Y * 0.06, -s.Z * 0.93))
			w, x = leg(p, 1.58, 0.47)
			g(p, "ShinRib", Vector3.new(w, s.Y * 0.06, s.Z * 1.85), ARMOR2, M.Metal, CFrame.new(x, s.Y * 0.18, 0))
		end
	end
	for _, n in { "RightFoot", "LeftFoot" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			local w, x = leg(p, 1.64, 0.445)
			g(p, "Boot", Vector3.new(w, s.Y * 1.9, s.Z * 1.7), ARMOR2, M.Metal, CFrame.new(x, s.Y * 0.25, -s.Z * 0.12))
			w, x = leg(p, 1.56, 0.39)
			g(p, "Toe", Vector3.new(w, s.Y * 1.05, s.Z * 0.55), ARMOR, M.Metal, CFrame.new(x, -s.Y * 0.03, -s.Z * 0.95))
			w, x = leg(p, 1.3, 0.395)
			g(p, "Heel", Vector3.new(w, s.Y * 1.1, s.Z * 0.4), MECH, M.Metal, CFrame.new(x, -s.Y * 0.03, s.Z * 0.8))
		end
	end
end

-- A life-size Sentinel on display (anchored R15 frame wearing the suit).
local STATUE = {
	HumanoidRootPart = { Vector3.new(2, 2, 1), Vector3.new(0, 0, 0) },
	UpperTorso = { Vector3.new(2, 1.6, 1), Vector3.new(0, 0.55, 0) },
	LowerTorso = { Vector3.new(2, 0.4, 1), Vector3.new(0, -0.45, 0) },
	Head = { Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.95, 0) },
	RightUpperArm = { Vector3.new(1, 1.2, 1), Vector3.new(1.5, 0.75, 0) },
	RightLowerArm = { Vector3.new(1, 1.1, 1), Vector3.new(1.5, -0.4, 0) },
	RightHand = { Vector3.new(1, 0.3, 1), Vector3.new(1.5, -1.1, 0) },
	LeftUpperArm = { Vector3.new(1, 1.2, 1), Vector3.new(-1.5, 0.75, 0) },
	LeftLowerArm = { Vector3.new(1, 1.1, 1), Vector3.new(-1.5, -0.4, 0) },
	LeftHand = { Vector3.new(1, 0.3, 1), Vector3.new(-1.5, -1.1, 0) },
	RightUpperLeg = { Vector3.new(1, 1.2, 1), Vector3.new(0.5, -1.25, 0) },
	RightLowerLeg = { Vector3.new(1, 1.1, 1), Vector3.new(0.5, -2.4, 0) },
	RightFoot = { Vector3.new(1, 0.3, 1), Vector3.new(0.5, -3.1, 0) },
	LeftUpperLeg = { Vector3.new(1, 1.2, 1), Vector3.new(-0.5, -1.25, 0) },
	LeftLowerLeg = { Vector3.new(1, 1.1, 1), Vector3.new(-0.5, -2.4, 0) },
	LeftFoot = { Vector3.new(1, 0.3, 1), Vector3.new(-0.5, -3.1, 0) },
}
-- `base` = where the feet stand, facing -Z
function Costumes.SentinelStatue(parent, base, scale, skinId)
	local model = Instance.new("Model")
	model.Name = "SentinelStatue"
	local root = base * CFrame.new(0, 3.25 * scale, 0)
	for name, info in STATUE do
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = name ~= "HumanoidRootPart"
		p.Size = info[1] * scale
		local cf = root * CFrame.new(info[2] * scale)
		-- arms hang slightly away from the body, fists by the thighs
		local side = name:find("Right") and 1 or name:find("Left") and -1 or 0
		if name:find("Arm") or name:find("Hand") then
			local pivot = root * CFrame.new(side * 1.5 * scale, 1.2 * scale, 0)
			cf = pivot * CFrame.Angles(rad(-4), 0, rad(side * 9)) * pivot:Inverse() * cf
		end
		p.CFrame = cf
		p.Transparency = name == "HumanoidRootPart" and 1 or 0
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
	end
	Costumes.DressSentinel(model, skinId)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PodPrompt"
	prompt.ActionText = "Enter Sentinel Suit"
	prompt.ObjectText = "Sentinel"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = model:FindFirstChild("UpperTorso")
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model.Parent = parent
	return model
end

return Costumes
