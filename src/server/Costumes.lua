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
	local YEL, BLU, BLK = rgb(238, 184, 20), rgb(28, 56, 140), rgb(18, 18, 22)
	if head then
		local hs = head.Size
		head.Color = YEL
		-- sculpted cowl over the top of the head
		-- fitted cowl over the top of the (block) head, above the brow line
		gear(char, head, "Cowl", Vector3.new(hs.X * 1.06, hs.Y * 0.3, hs.Z * 1.06), YEL, M.SmoothPlastic,
			CFrame.new(0, hs.Y * 0.4, hs.Z * 0.01))
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
			-- folded-back collar
			gear(char, torso, "Lapel", Vector3.new(s.X * 0.15, s.Y * 0.34, t), DARK, M.Leather,
				CFrame.new(side * s.X * 0.19, s.Y * 0.3, fz - t) * CFrame.Angles(0, 0, rad(side * 24)))
			-- hem band
			gear(char, torso, "JacketHem", Vector3.new(s.X * 0.36, s.Y * 0.09, t * 1.4), DARK, M.Leather, CFrame.new(side * s.X * 0.33, -s.Y * 0.466, fz))
		end
		-- maroon shirt and the grey tee at the neck
		gear(char, torso, "ShirtFront", Vector3.new(s.X * 0.34, s.Y * 0.98, t * 0.5), MAROON, M.Fabric, CFrame.new(0, 0, -(s.Z / 2 + t * 0.25)))
		gear(char, torso, "TeeNeck", Vector3.new(s.X * 0.22, s.Y * 0.14, t * 0.8), TEE, M.Fabric, CFrame.new(0, s.Y * 0.405, -(s.Z / 2 + t * 0.4)))
		gear(char, torso, "Zip", Vector3.new(0.05, s.Y * 0.5, t * 0.6), rgb(30, 22, 16), M.Metal, CFrame.new(-s.X * 0.4, -s.Y * 0.08, fz - t * 0.5))
	end
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
		gear(char, lower, "Belt", Vector3.new(s.X * 1.05, s.Y * 0.3, s.Z * 1.06), rgb(34, 26, 20), M.Leather, CFrame.new(0, s.Y * 0.3, 0))
		local buckle = gear(char, lower, "Buckle", Vector3.new(s.X * 0.16, s.Y * 0.34, 0.06), rgb(170, 170, 176), M.Metal, CFrame.new(0, s.Y * 0.3, -s.Z * 0.56))
		buckle.Reflectance = 0.25
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
	local edgeColor = lighten(claw.Color, 0.65)
	local spineColor = claw.Color:Lerp(Color3.new(0, 0, 0), 0.35)
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
			-- bevel line on both flats
			for sx = -1, 1, 2 do
				local bevel = Costumes.Gear(owner, root, "Claw", Vector3.new(0.012, sg.Len, w * 0.06), spineColor, M.SmoothPlastic,
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
		local tip = Costumes.Gear(owner, root, "Claw", Vector3.new(0.058 * thick, tipLen, 0.17 * thick), claw.Color, claw.Material,
			f * CFrame.new(0, -tipLen / 2, 0) * CFrame.Angles(0, 0, math.pi), { Class = "WedgePart", Reflectance = claw.Reflectance, Transparency = extended and 0 or 1 }, "Claws")
		table.insert(set.Parts, tip)
		table.insert(set.Tips, tip)
	end
end

-- Builds 3 claws per hand. Returns { Roots = { {Weld, Extended} }, Parts, Tips, Bases }.
function Costumes.BuildClaws(char, claw, extended)
	local set = { Roots = {}, Parts = {}, Tips = {}, Bases = {} }
	for _, side in { "Right", "Left" } do
		local hand = Util.Hand(char, side)
		if hand then
			bladesOn(char, hand, claw, extended, set)
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
		p(Vector3.new(0.82, 0.18, 0.28), fistCf * CFrame.new(0, -0.4, k * 0.32), rgb(40, 38, 44), M.Leather)
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

function Costumes.DressSentinel(char)
	-- palette from the comics: periwinkle armour, magenta limbs, violet helmet,
	-- gold skull face, dark mechanical joints
	local ARMOR, ARMOR2 = rgb(112, 116, 196), rgb(84, 86, 160)
	local MAG, HELM, FACE, MECH = rgb(182, 88, 184), rgb(124, 78, 164), rgb(212, 176, 112), rgb(24, 24, 30)
	local F = "SentinelGear"
	local function g(anchor, name, size, color, mat, offset, props)
		-- left-side armour is a hair larger so mirrored pieces never share a face
		if anchor.Name:sub(1, 4) == "Left" then
			size += Vector3.new(0.04, 0.04, 0.04)
		end
		return Costumes.Gear(char, anchor, name, size, color, mat or M.SmoothPlastic, offset, props, F)
	end
	local function round(anchor, name, size, color, offset)
		return g(anchor, name, size, color, M.SmoothPlastic, offset, { Mesh = Enum.MeshType.Sphere })
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

	local head = char:FindFirstChild("Head")
	if head then
		local hs = head.Size
		round(head, "Helmet", Vector3.new(hs.X * 1.2, hs.Y * 1.1, hs.Z * 1.25), HELM, CFrame.new(0, hs.Y * 0.14, hs.Z * 0.08))
		g(head, "HelmetBand", Vector3.new(hs.X * 1.18, hs.Y * 0.14, hs.Z * 1.2), HELM:Lerp(Color3.new(0, 0, 0), 0.25), M.SmoothPlastic, CFrame.new(0, hs.Y * 0.18, hs.Z * 0.06))
		for i = -1, 1 do -- ridges over the dome
			g(head, "Ridge", Vector3.new(hs.X * 0.1, hs.Y * 0.16, hs.Z * 1.1), HELM:Lerp(Color3.new(1, 1, 1), 0.1), M.SmoothPlastic, CFrame.new(i * hs.X * 0.26, hs.Y * 0.58, hs.Z * 0.06))
		end
		-- the skull face: brow, cheekbones, grille mouth
		g(head, "FacePlate", Vector3.new(hs.X * 0.78, hs.Y * 0.62, 0.16), FACE, M.Metal, CFrame.new(0, -hs.Y * 0.08, -hs.Z * 0.56), { Reflectance = 0.12 })
		g(head, "Brow", Vector3.new(hs.X * 0.84, hs.Y * 0.14, 0.24), FACE:Lerp(Color3.new(0, 0, 0), 0.25), M.Metal, CFrame.new(0, hs.Y * 0.2, -hs.Z * 0.6))
		for s = -1, 1, 2 do
			g(head, "Cheek", Vector3.new(hs.X * 0.2, hs.Y * 0.2, 0.2), FACE:Lerp(Color3.new(0, 0, 0), 0.15), M.Metal, CFrame.new(s * hs.X * 0.28, -hs.Y * 0.08, -hs.Z * 0.6) * CFrame.Angles(0, rad(s * 18), 0))
			g(head, "Socket", Vector3.new(hs.X * 0.24, hs.Y * 0.14, 0.05), rgb(30, 12, 12), M.SmoothPlastic, CFrame.new(s * hs.X * 0.18, hs.Y * 0.06, -hs.Z * 0.64))
			local eye = g(head, "Eye", Vector3.new(hs.X * 0.16, hs.Y * 0.07, 0.05), rgb(255, 40, 40), M.Neon, CFrame.new(s * hs.X * 0.18, hs.Y * 0.06, -hs.Z * 0.67))
			local l = Instance.new("PointLight")
			l.Color = rgb(255, 40, 40)
			l.Range = 5
			l.Brightness = 1.5
			l.Parent = eye
			g(head, "EarDisc", Vector3.new(0.14, hs.Y * 0.44, hs.Y * 0.44), HELM:Lerp(Color3.new(0, 0, 0), 0.2), M.SmoothPlastic, CFrame.new(s * hs.X * 0.6, 0, 0), { Shape = Enum.PartType.Cylinder })
		end
		g(head, "Jaw", Vector3.new(hs.X * 0.56, hs.Y * 0.24, 0.2), FACE:Lerp(Color3.new(0, 0, 0), 0.12), M.Metal, CFrame.new(0, -hs.Y * 0.36, -hs.Z * 0.52))
		for i = 0, 3 do
			g(head, "Teeth", Vector3.new(0.04, hs.Y * 0.14, 0.03), rgb(60, 44, 28), M.Metal, CFrame.new((i - 1.5) * hs.X * 0.1, -hs.Y * 0.33, -hs.Z * 0.63))
		end
	end

	local torso = char:FindFirstChild("UpperTorso")
	if torso then
		local s = torso.Size
		-- broad armoured chest over a dark mechanical core
		g(torso, "ChestPlate", Vector3.new(s.X * 1.34, s.Y * 0.56, s.Z * 1.34), ARMOR, M.SmoothPlastic, CFrame.new(0, s.Y * 0.25, 0))
		for sx = -1, 1, 2 do
			g(torso, "Pec", Vector3.new(s.X * 0.62, s.Y * 0.4, 0.3), ARMOR, M.SmoothPlastic, CFrame.new(sx * s.X * 0.32, s.Y * 0.2, -s.Z * 0.7) * CFrame.Angles(rad(-6), rad(sx * 14), 0))
			g(torso, "PecEdge", Vector3.new(s.X * 0.6, 0.08, 0.34), ARMOR2, M.SmoothPlastic, CFrame.new(sx * s.X * 0.32, s.Y * 0.0, -s.Z * 0.72) * CFrame.Angles(0, rad(sx * 14), 0))
			g(torso, "Lat", Vector3.new(0.3, s.Y * 0.5, s.Z * 1.1), ARMOR2, M.SmoothPlastic, CFrame.new(sx * s.X * 0.66, s.Y * 0.12, 0))
			-- exposed pistons down the sides
			g(torso, "Piston", Vector3.new(0.14, s.Y * 0.6, 0.14), rgb(150, 150, 160), M.Metal, CFrame.new(sx * s.X * 0.42, -s.Y * 0.3, -s.Z * 0.3), { Reflectance = 0.3 })
		end
		local core = g(torso, "Core", Vector3.new(0.14, s.X * 0.24, s.X * 0.24), rgb(255, 236, 190), M.Neon, CFrame.new(0, s.Y * 0.26, -s.Z * 0.9) * CFrame.Angles(0, rad(90), 0), { Shape = Enum.PartType.Cylinder })
		g(torso, "CoreRing", Vector3.new(0.14, s.X * 0.36, s.X * 0.36), rgb(40, 40, 48), M.Metal, CFrame.new(0, s.Y * 0.26, -s.Z * 0.86) * CFrame.Angles(0, rad(90), 0), { Shape = Enum.PartType.Cylinder })
		local l = Instance.new("PointLight")
		l.Color = rgb(255, 200, 130)
		l.Range = 14
		l.Brightness = 3
		l.Parent = core
		-- segmented abdomen: dark frame with violet plates
		g(torso, "Abdomen", Vector3.new(s.X * 0.7, s.Y * 0.5, s.Z * 1.05), MECH, M.Metal, CFrame.new(0, -s.Y * 0.28, 0))
		for i = 0, 2 do
			for sx = -1, 1, 2 do
				g(torso, "AbPlate", Vector3.new(s.X * 0.24, s.Y * 0.12, 0.14), ARMOR2, M.SmoothPlastic, CFrame.new(sx * s.X * 0.14, -s.Y * (0.1 + i * 0.15), -s.Z * 0.56) * CFrame.Angles(0, rad(sx * 6), 0))
			end
		end
		g(torso, "Collar", Vector3.new(s.X * 0.8, s.Y * 0.16, s.Z * 1.26), ARMOR2, M.SmoothPlastic, CFrame.new(0, s.Y * 0.57, 0))
		g(torso, "Neck", Vector3.new(s.X * 0.34, s.Y * 0.22, s.Z * 0.5), MECH, M.Metal, CFrame.new(0, s.Y * 0.62, 0))
		g(torso, "BackPack", Vector3.new(s.X * 0.9, s.Y * 0.6, s.Z * 0.5), ARMOR2, M.SmoothPlastic, CFrame.new(0, s.Y * 0.16, s.Z * 0.72))
	end

	local lower = char:FindFirstChild("LowerTorso")
	if lower then
		local s = lower.Size
		g(lower, "Belt", Vector3.new(s.X * 1.06, s.Y * 0.5, s.Z * 1.1), MECH, M.Metal, CFrame.new(0, s.Y * 0.3, 0))
		g(lower, "Codpiece", Vector3.new(s.X * 0.42, s.Y * 1.2, 0.2), ARMOR2, M.SmoothPlastic, CFrame.new(0, -s.Y * 0.2, -s.Z * 0.58))
		for sx = -1, 1, 2 do
			g(lower, "HipPlate", Vector3.new(s.X * 0.42, s.Y * 1.3, s.Z * 1.18), MAG, M.SmoothPlastic, CFrame.new(sx * s.X * 0.4, -s.Y * 0.25, 0) * CFrame.Angles(0, 0, rad(sx * 6)))
		end
	end

	for _, n in { "RightUpperArm", "LeftUpperArm" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			local side = n:sub(1, 5) == "Right" and 1 or -1
			round(p, "Pauldron", Vector3.new(s.X * 2.4, s.Y * 0.95, s.Z * 2.2), ARMOR, CFrame.new(side * s.X * 0.2, s.Y * 0.3, 0))
			round(p, "PauldronRim", Vector3.new(s.X * 2.2, s.Y * 0.3, s.Z * 2.05), ARMOR2, CFrame.new(side * s.X * 0.2, s.Y * 0.02, 0))
			g(p, "Bicep", Vector3.new(s.X * 1.35, s.Y * 0.62, s.Z * 1.35), MAG, M.SmoothPlastic, CFrame.new(0, -s.Y * 0.14, 0))
		end
	end
	for _, n in { "RightLowerArm", "LeftLowerArm" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			round(p, "Elbow", Vector3.new(s.X * 1.3, s.Y * 0.4, s.Z * 1.3), MECH, CFrame.new(0, s.Y * 0.42, 0))
			g(p, "Gauntlet", Vector3.new(s.X * 1.6, s.Y * 0.95, s.Z * 1.6), ARMOR, M.SmoothPlastic, CFrame.new(0, -s.Y * 0.06, 0))
			g(p, "GauntletPlate", Vector3.new(s.X * 1.2, s.Y * 0.7, 0.14), ARMOR2, M.SmoothPlastic, CFrame.new(0, -s.Y * 0.04, -s.Z * 0.82))
			g(p, "Cuff", Vector3.new(s.X * 1.7, s.Y * 0.14, s.Z * 1.7), ARMOR2, M.SmoothPlastic, CFrame.new(0, -s.Y * 0.5, 0))
		end
	end
	for _, n in { "RightHand", "LeftHand" } do
		local p = char:FindFirstChild(n)
		if p then
			g(p, "Fist", p.Size * Vector3.new(1.4, 1.4, 1.4), rgb(40, 40, 50), M.Metal, CFrame.new(0, -p.Size.Y * 0.1, 0))
		end
	end
	for _, n in { "RightUpperLeg", "LeftUpperLeg" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			g(p, "Thigh", Vector3.new(s.X * 1.5, s.Y * 0.95, s.Z * 1.5), MAG, M.SmoothPlastic, CFrame.new(0, 0.02, 0))
			g(p, "ThighPlate", Vector3.new(s.X * 1.1, s.Y * 0.6, 0.14), MAG:Lerp(Color3.new(1, 1, 1), 0.08), M.SmoothPlastic, CFrame.new(0, 0.05, -s.Z * 0.78))
		end
	end
	for _, n in { "RightLowerLeg", "LeftLowerLeg" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			round(p, "Knee", Vector3.new(s.X * 1.75, s.Y * 0.55, s.Z * 1.8), ARMOR, CFrame.new(0, s.Y * 0.44, -s.Z * 0.12))
			g(p, "Shin", Vector3.new(s.X * 1.8, s.Y * 1.05, s.Z * 1.8), ARMOR, M.SmoothPlastic, CFrame.new(0, -s.Y * 0.1, 0))
			g(p, "ShinPlate", Vector3.new(s.X * 1.3, s.Y * 0.8, 0.14), ARMOR2, M.SmoothPlastic, CFrame.new(0, -s.Y * 0.06, -s.Z * 0.92))
		end
	end
	for _, n in { "RightFoot", "LeftFoot" } do
		local p = char:FindFirstChild(n)
		if p then
			local s = p.Size
			g(p, "Boot", Vector3.new(s.X * 2, s.Y * 1.8, s.Z * 1.6), ARMOR, M.SmoothPlastic, CFrame.new(0, s.Y * 0.25, -s.Z * 0.12))
			g(p, "Toe", Vector3.new(s.X * 1.9, s.Y * 1, s.Z * 0.5), ARMOR2, M.SmoothPlastic, CFrame.new(0, -s.Y * 0.03, -s.Z * 0.9))
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
function Costumes.SentinelStatue(parent, base, scale)
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
	Costumes.DressSentinel(model)
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
