-- Builds the whole map from code: a snowed-in Weapon X compound at night.
-- Rebuilt every round so shredded walls come back.
--
-- Every wall is made of 4-stud panels tagged with the "Breakable" attribute,
-- which is what lets Wolverine tear through buildings.
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local rgb = Color3.fromRGB
local M = Enum.Material
local PANEL = 4
local HALF = 180 -- playable area is 360 x 360

local C = {
	Snow = rgb(228, 234, 242),
	SnowShade = rgb(205, 214, 228),
	Asphalt = rgb(44, 46, 52),
	Line = rgb(200, 170, 60),
	Concrete = rgb(160, 163, 168),
	LabInner = rgb(196, 200, 206),
	LabFloor = rgb(88, 92, 98),
	Metal = rgb(96, 101, 110),
	DarkMetal = rgb(52, 55, 62),
	Rust = rgb(125, 74, 48),
	Wood = rgb(110, 74, 46),
	DarkWood = rgb(70, 46, 30),
	Pine = rgb(34, 66, 44),
	PineDark = rgb(24, 48, 33),
	Rock = rgb(92, 96, 104),
	Glass = rgb(160, 200, 220),
	Hazard = rgb(230, 180, 20),
	Blood = rgb(80, 0, 0),
	Brick = rgb(135, 58, 48),
	Lamp = rgb(255, 205, 150),
	Cold = rgb(190, 215, 255),
	Emergency = rgb(255, 40, 30),
}

local rng = Random.new(1)
local zones = {} -- rectangles trees/rocks must avoid

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function make(class, parent, props)
	local inst = Instance.new(class)
	if inst:IsA("BasePart") then
		inst.Anchored = true
		inst.TopSurface = Enum.SurfaceType.Smooth
		inst.BottomSurface = Enum.SurfaceType.Smooth
	end
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function part(parent, props)
	return make("Part", parent, props)
end

local function block(parent, size, cf, material, color, extra)
	local p = part(parent, { Size = size, CFrame = cf, Material = material, Color = color })
	if extra then
		for k, v in extra do
			p[k] = v
		end
	end
	return p
end

local function breakable(p)
	p:SetAttribute("Breakable", true)
	return p
end

local function vary(color, amount)
	local s = 1 + (rng:NextNumber() - 0.5) * (amount or 0.06)
	return Color3.new(math.clamp(color.R * s, 0, 1), math.clamp(color.G * s, 0, 1), math.clamp(color.B * s, 0, 1))
end

local function light(parent, props)
	return make("PointLight", parent, props)
end

local function zone(cx, cz, sx, sz)
	table.insert(zones, { cx - sx / 2, cz - sz / 2, cx + sx / 2, cz + sz / 2 })
end

local function inZone(x, z, pad)
	for _, r in zones do
		if x > r[1] - pad and x < r[3] + pad and z > r[2] - pad and z < r[4] + pad then
			return true
		end
	end
	return false
end

local function sign(parent, cf, size, text, textColor, bg, font)
	local p = block(parent, size, cf, M.SmoothPlastic, bg or C.DarkMetal)
	local gui = make("SurfaceGui", p, {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 30,
		LightInfluence = 0,
	})
	make("TextLabel", gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		Font = font or Enum.Font.GothamBlack,
		TextColor3 = textColor or Color3.new(1, 1, 1),
	})
	return p
end

---------------------------------------------------------------------------
-- Walls & buildings
---------------------------------------------------------------------------

-- Wall from a to b (world XZ), base at y0. Openings (doors/windows):
-- { At = distance from start, Width, Bottom, Top, Glass = bool }
local function wall(parent, a, b, y0, height, thick, style, openings)
	local fa, fb = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
	local len = (fb - fa).Magnitude
	if len < 0.1 then
		return
	end
	local frame = CFrame.lookAt(fa, fb)
	openings = openings or {}
	local cuts = { 0, len }
	for _, o in openings do
		table.insert(cuts, math.clamp(o.At - o.Width / 2, 0, len))
		table.insert(cuts, math.clamp(o.At + o.Width / 2, 0, len))
	end
	table.sort(cuts)
	local function openingAt(t)
		for _, o in openings do
			if t > o.At - o.Width / 2 and t < o.At + o.Width / 2 then
				return o
			end
		end
		return nil
	end
	for i = 1, #cuts - 1 do
		local t0, t1 = cuts[i], cuts[i + 1]
		if t1 - t0 > 0.05 then
			local o = openingAt((t0 + t1) / 2)
			local spans = o and { { 0, o.Bottom }, { o.Top, height } } or { { 0, height } }
			local segs = math.max(1, math.ceil((t1 - t0) / PANEL))
			local w = (t1 - t0) / segs
			for s = 0, segs - 1 do
				local mid = t0 + w * (s + 0.5)
				for _, sp in spans do
					local h = math.min(sp[2], height) - sp[1]
					if h > 0.05 then
						local p = part(parent, {
							Size = Vector3.new(thick, h, w),
							CFrame = frame * CFrame.new(0, y0 + sp[1] + h / 2, -mid),
							Material = style.Material,
							Color = vary(style.Color, style.Vary),
							Transparency = style.Transparency or 0,
							Reflectance = style.Reflectance or 0,
						})
						if style.Breakable ~= false then
							breakable(p)
						end
					end
				end
				if o and o.Glass then
					local gh = o.Top - o.Bottom
					breakable(part(parent, {
						Size = Vector3.new(thick * 0.3, gh, w),
						CFrame = frame * CFrame.new(0, y0 + o.Bottom + gh / 2, -mid),
						Material = M.Glass,
						Color = C.Glass,
						Transparency = style.GlassTransparency or 0.6,
						Reflectance = style.GlassReflectance or 0.1,
					}))
				end
			end
		end
	end
end

local function conv(list, len)
	local out = {}
	for _, op in list or {} do
		table.insert(out, { At = op.At + len / 2, Width = op.Width, Bottom = op.Bottom, Top = op.Top, Glass = op.Glass })
	end
	return out
end

-- Axis-aligned building. Openings use At = offset from the wall's centre.
-- N/S walls run west->east, E/W walls run north->south.
local function building(parent, center, sx, sz, h, o)
	local model = Instance.new("Model")
	model.Name = o.Name or "Building"
	local t = o.Thick or 1
	local y0 = center.Y + 0.4
	local hx, hz = sx / 2, sz / 2
	local ops = o.Openings or {}
	zone(center.X, center.Z, sx, sz)

	block(model, Vector3.new(sx, 0.4, sz), CFrame.new(center + Vector3.new(0, 0.2, 0)), o.Floor.Material, o.Floor.Color)

	local ws = o.Wall
	wall(model, center + Vector3.new(-hx, 0, -hz + t / 2), center + Vector3.new(hx, 0, -hz + t / 2), y0, h, t, ws, conv(ops.N, sx))
	wall(model, center + Vector3.new(-hx, 0, hz - t / 2), center + Vector3.new(hx, 0, hz - t / 2), y0, h, t, ws, conv(ops.S, sx))
	wall(model, center + Vector3.new(-hx + t / 2, 0, -hz + t), center + Vector3.new(-hx + t / 2, 0, hz - t), y0, h, t, ws, conv(ops.W, sz - 2 * t))
	wall(model, center + Vector3.new(hx - t / 2, 0, -hz + t), center + Vector3.new(hx - t / 2, 0, hz - t), y0, h, t, ws, conv(ops.E, sz - 2 * t))

	for _, iw in o.Interior or {} do
		local a, b = center + iw.A, center + iw.B
		local len = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
		wall(model, a, b, y0, iw.Height or h, iw.Thick or 0.8, iw.Style or o.InteriorWall or ws, conv(iw.Openings, len))
	end

	local rs = o.RoofStyle
	if o.Roof == "flat" then
		block(model, Vector3.new(sx + 1.5, 1, sz + 1.5), CFrame.new(center + Vector3.new(0, y0 + h + 0.5, 0)), rs.Material, rs.Color)
		block(model, Vector3.new(sx + 1.2, 0.3, sz + 1.2), CFrame.new(center + Vector3.new(0, y0 + h + 1.15, 0)), M.Snow, C.Snow)
	elseif o.Roof == "gable" then
		local rh = o.RoofHeight or sz * 0.4
		local ang = math.atan2(rh, sz / 2)
		local L = (sz / 2 + 1.4) / math.cos(ang)
		local ridge = CFrame.new(center.X, y0 + h + rh, center.Z)
		for _, s in { -1, 1 } do
			local tilt = ridge * CFrame.Angles(s * ang, 0, 0)
			block(model, Vector3.new(sx + 2, 0.6, L), tilt * CFrame.new(0, 0.3, s * L / 2), rs.Material, rs.Color)
			block(model, Vector3.new(sx + 2.1, 0.3, L * 0.97), tilt * CFrame.new(0, 0.72, s * L / 2), M.Snow, C.Snow)
		end
		-- Stepped gables (log-cabin style) fill the triangle ends
		local steps = 6
		for _, gx in { -hx + t / 2, hx - t / 2 } do
			for i = 1, steps do
				local w = sz * (1 - (i - 0.5) / steps)
				local sh = rh / steps
				block(model, Vector3.new(t, sh, w), CFrame.new(center.X + gx, y0 + h + (i - 0.5) * sh, center.Z), ws.Material, ws.Color)
			end
		end
	end

	if o.Lights then
		local spacing = o.LightSpacing or 14
		local nx = math.max(1, math.floor(sx / spacing))
		local nz = math.max(1, math.floor(sz / spacing))
		for ix = 1, nx do
			for iz = 1, nz do
				local x = center.X - hx + (ix - 0.5) * sx / nx
				local z = center.Z - hz + (iz - 0.5) * sz / nz
				local lamp = block(model, Vector3.new(3, 0.2, 0.7), CFrame.new(x, y0 + h - 0.15, z), M.Neon, o.LightColor or C.Cold)
				light(lamp, { Range = 20, Brightness = 1.1, Color = o.LightColor or C.Cold, Shadows = true })
				if rng:NextNumber() < (o.FlickerChance or 0) then
					CollectionService:AddTag(lamp, "Flicker")
				end
			end
		end
	end

	model.Parent = parent
	return model, y0
end

---------------------------------------------------------------------------
-- Props
---------------------------------------------------------------------------


-- Detailed wooden crate: planks, frame beams, braces, metal corners, stencils.
local STENCILS = { "WEAPON X", "PROPERTY OF DEPT. H", "FRAGILE", "LOT 47-X", "BIOHAZARD", "DO NOT OPEN", "ALKALI LAKE" }
local function woodCrate(parent, cf, s, isBreakable)
	local model = Instance.new("Model")
	model.Name = "Crate"
	local wood = vary(rgb(150, 112, 70), 0.12)
	local dark = wood:Lerp(Color3.new(0, 0, 0), 0.35)
	local metal = rgb(60, 62, 66)
	local function bp(size, off, color, mat, extra)
		local p = block(model, size, cf * off, mat, color, extra)
		if isBreakable then
			breakable(p)
		end
		return p
	end
	bp(s * 0.96, CFrame.new(0, s.Y / 2, 0), wood, M.WoodPlanks)
	-- frame beams on all 12 edges
	local e = math.min(s.X, s.Y, s.Z) * 0.09
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			bp(Vector3.new(e, s.Y, e), CFrame.new(x * (s.X / 2 - e / 2), s.Y / 2, z * (s.Z / 2 - e / 2)), dark, M.Wood)
		end
		for _, y in { 0, 1 } do
			bp(Vector3.new(e, e, s.Z), CFrame.new(x * (s.X / 2 - e / 2), e / 2 + y * (s.Y - e), 0), dark, M.Wood)
			bp(Vector3.new(s.X, e, e), CFrame.new(0, e / 2 + y * (s.Y - e), x * (s.Z / 2 - e / 2)), dark, M.Wood)
		end
	end
	-- plank seams + diagonal braces on the faces
	for _, z in { -1, 1 } do
		for k = 1, 3 do
			bp(Vector3.new(s.X * 0.9, 0.04, 0.03), CFrame.new(0, s.Y * k / 4, z * (s.Z / 2 + 0.005)), dark, M.Wood)
		end
		local diag = math.sqrt(s.X ^ 2 + s.Y ^ 2) * 0.82
		bp(Vector3.new(diag, e * 0.8, e * 0.5), CFrame.new(0, s.Y / 2, z * (s.Z / 2 + e * 0.1)) * CFrame.Angles(0, 0, math.atan2(s.Y, s.X) * z), dark, M.Wood)
	end
	for _, x in { -1, 1 } do
		for k = 1, 3 do
			bp(Vector3.new(0.03, 0.04, s.Z * 0.9), CFrame.new(x * (s.X / 2 + 0.005), s.Y * k / 4, 0), dark, M.Wood)
		end
	end
	-- metal corner brackets
	for _, x in { -1, 1 } do
		for _, y in { 0, 1 } do
			for _, z in { -1, 1 } do
				bp(Vector3.one * e * 1.5, CFrame.new(x * (s.X / 2 - e * 0.6), e * 0.7 + y * (s.Y - e * 1.4), z * (s.Z / 2 - e * 0.6)), metal, M.Metal)
			end
		end
	end
	-- stencilled labels
	local label = block(model, Vector3.new(s.X * 0.6, s.Y * 0.28, 0.02), cf * CFrame.new(0, s.Y * 0.62, -(s.Z / 2 + e * 0.35)), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false })
	local gui = make("SurfaceGui", label, { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 60 })
	make("TextLabel", gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.Arcade,
		TextScaled = true,
		TextColor3 = rgb(30, 22, 16),
		TextTransparency = 0.15,
		Text = STENCILS[rng:NextInteger(1, #STENCILS)],
	})
	model.Parent = parent
	return model
end

local function steelBarrel(parent, cf, color, isBreakable)
	local model = Instance.new("Model")
	model.Name = "Barrel"
	local function bp(size, off, col, mat, extra)
		local p = block(model, size, cf * off * CFrame.Angles(0, 0, math.rad(90)), mat, col, extra)
		if isBreakable then
			breakable(p)
		end
		return p
	end
	bp(Vector3.new(3, 2.2, 2.2), CFrame.new(0, 1.5, 0), color, M.Metal, { Shape = Enum.PartType.Cylinder })
	for _, y in { 0.2, 1.05, 1.95, 2.8 } do
		bp(Vector3.new(0.14, 2.32, 2.32), CFrame.new(0, y, 0), color:Lerp(Color3.new(0, 0, 0), 0.35), M.Metal, { Shape = Enum.PartType.Cylinder })
	end
	bp(Vector3.new(0.06, 1.9, 1.9), CFrame.new(0, 3.02, 0), color:Lerp(Color3.new(0, 0, 0), 0.2), M.DiamondPlate, { Shape = Enum.PartType.Cylinder })
	local tag = block(model, Vector3.new(0.9, 0.9, 0.02), cf * CFrame.new(0, 1.5, -1.11), M.SmoothPlastic, rgb(230, 200, 40))
	local g = make("SurfaceGui", tag, { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 80 })
	make("TextLabel", g, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextScaled = true, Font = Enum.Font.GothamBlack, Text = "☢", TextColor3 = rgb(20, 20, 20) })
	model.Parent = parent
	return model
end

local function crate(parent, pos, s)
	s = s or 4
	return woodCrate(parent, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber() * 0.4, 0), Vector3.one * s, true)
end

local function barrel(parent, pos, color)
	return steelBarrel(parent, CFrame.new(pos), color or C.Rust, true)
end

local function fireBarrel(parent, pos)
	barrel(parent, pos, C.DarkMetal)
	local top = block(parent, Vector3.new(1.6, 0.2, 1.6), CFrame.new(pos + Vector3.new(0, 3.1, 0)), M.Slate, rgb(30, 25, 20))
	make("Fire", top, { Size = 4, Heat = 8, Color = rgb(255, 140, 40), SecondaryColor = rgb(255, 60, 20) })
	light(top, { Range = 20, Brightness = 2, Color = rgb(255, 150, 70), Shadows = true })
	CollectionService:AddTag(top, "FireLight")
	zone(pos.X, pos.Z, 4, 4)
end

local function lamp(parent, pos, facing, flicker)
	local base = CFrame.lookAt(pos, pos + facing)
	local metal = rgb(58, 62, 68)
	block(parent, Vector3.new(1.4, 0.6, 1.4), base * CFrame.new(0, 0.3, 0), M.Concrete, rgb(120, 120, 124))
	block(parent, Vector3.new(1, 0.9, 0.9), base * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, metal, { Shape = Enum.PartType.Cylinder })
	block(parent, Vector3.new(8, 0.55, 0.55), base * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, metal, { Shape = Enum.PartType.Cylinder })
	block(parent, Vector3.new(6, 0.4, 0.4), base * CFrame.new(0, 12, 0) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, metal, { Shape = Enum.PartType.Cylinder })
	block(parent, Vector3.new(0.32, 0.32, 3.4), base * CFrame.new(0, 14.75, -1.6) * CFrame.Angles(math.rad(6), 0, 0), M.Metal, metal)
	local housing = block(parent, Vector3.new(1.3, 0.35, 2.6), base * CFrame.new(0, 14.4, -3.3), M.Metal, metal)
	local head = block(parent, Vector3.new(1.05, 0.08, 2.2), base * CFrame.new(0, 14.2, -3.3), M.Neon, C.Lamp)
	make("SpotLight", head, { Face = Enum.NormalId.Bottom, Range = 38, Angle = 110, Brightness = 3, Color = C.Lamp, Shadows = true })
	light(housing, { Range = 12, Brightness = 0.5, Color = C.Lamp })
	if flicker then
		CollectionService:AddTag(head, "Flicker")
	end
end

-- A round terraced cone: shrinking discs = one tier of a pine.
local function coneTier(parent, base, w, h, color, discs, collide)
	for i = 0, discs - 1 do
		local r = w / 2 * (1 - i / discs * 0.82)
		local dh = h / discs
		make("Part", parent, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(dh * 1.05, r * 2, r * 2),
			CFrame = CFrame.new(base + Vector3.new(0, dh * (i + 0.5), 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Material = M.Grass,
			Color = vary(color, 0.08),
			CanCollide = collide and i == 0,
		})
	end
end

local function tree(parent, pos, scale, simple)
	local model = Instance.new("Model")
	model.Name = "Pine"
	local s = scale
	local trunk = block(model, Vector3.new(6 * s, 1.1 * s, 1.1 * s), CFrame.new(pos + Vector3.new(0, 3 * s, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Wood, C.DarkWood, { Shape = Enum.PartType.Cylinder })
	breakable(trunk)
	trunk:SetAttribute("Topple", true)
	local tiers = simple and { { 10, 7, 2.2 }, { 6.5, 6, 7.2 } }
		or { { 10.5, 5.4, 2.2 }, { 8.4, 4.8, 5.4 }, { 6.2, 4.2, 8.4 }, { 3.8, 3.8, 11.2 } }
	for i, t in tiers do
		local w, h, y = t[1] * s, t[2] * s, t[3] * s
		local base = pos + Vector3.new(0, y, 0)
		coneTier(model, base, w, h, i % 2 == 0 and C.Pine or C.PineDark, simple and 3 or 4, i == 1)
		if not simple then -- snow settled on the branches
			for k, f in { 0.25, 0.75 } do
				local rr = w / 2 * (1 - (f - 0.25) * 0.82) * 0.94
				make("Part", model, {
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.25 * s, rr * 2, rr * 2),
					CFrame = CFrame.new(base + Vector3.new(0, h * f + 0.05 * s + 0.01 * k, 0)) * CFrame.Angles(0, 0, math.rad(90)),
					Material = M.Snow,
					Color = C.Snow,
					CanCollide = false,
				})
			end
		end
	end
	model.Parent = parent
end

local function terrain()
	return workspace:FindFirstChildOfClass("Terrain")
end

local function rock(parent, pos, size)
	local t = terrain()
	if t then
		local r = math.max(size.X, size.Z) * 0.6
		t:FillBall(pos + Vector3.new(0, -r * 0.35, 0), r, Enum.Material.Rock)
		t:FillBall(pos + Vector3.new(r * 0.3, -r * 0.5, -r * 0.2), r * 0.8, Enum.Material.Slate)
		t:FillBall(pos + Vector3.new(0, r * 0.25, 0), r * 0.55, Enum.Material.Snow)
		return
	end
	local cf = CFrame.new(pos + Vector3.new(0, size.Y * 0.35, 0)) * CFrame.Angles(rng:NextNumber() * 0.4, rng:NextNumber() * 6, rng:NextNumber() * 0.4)
	block(parent, size, cf, M.Slate, vary(C.Rock, 0.2))
	block(parent, Vector3.new(size.X * 0.85, 0.4, size.Z * 0.85), cf * CFrame.new(0, size.Y / 2, 0), M.Snow, C.Snow, { CanCollide = false })
end

local function car(parent, cf, color, lightsOn)
	local body = breakable(block(parent, Vector3.new(6, 2, 12), cf * CFrame.new(0, 1.7, 0), M.SmoothPlastic, color))
	breakable(block(parent, Vector3.new(5.6, 1.9, 6), cf * CFrame.new(0, 3.65, 0.6), M.Glass, rgb(40, 50, 60), { Transparency = 0.2 }))
	block(parent, Vector3.new(5.2, 0.3, 5.4), cf * CFrame.new(0, 4.75, 0.6), M.Snow, C.Snow, { CanCollide = false })
	for _, x in { -2.9, 2.9 } do
		for _, z in { -3.8, 3.8 } do
			block(parent, Vector3.new(0.9, 2.4, 2.4), cf * CFrame.new(x, 1.2, z), M.SmoothPlastic, rgb(20, 20, 22), { Shape = Enum.PartType.Cylinder })
		end
		local hl = block(parent, Vector3.new(1, 0.6, 0.2), cf * CFrame.new(x * 0.75, 2, -6.05), M.Neon, lightsOn and rgb(255, 245, 210) or rgb(90, 90, 80))
		if lightsOn then
			make("SpotLight", hl, { Face = Enum.NormalId.Front, Range = 40, Angle = 45, Brightness = 2, Color = rgb(255, 240, 210) })
		end
	end
	local p = cf.Position
	zone(p.X, p.Z, 10, 14)
	return body
end

local function container(parent, cf, color, openBack)
	local L, W, H = 20, 8, 8.5
	local style = { Material = M.CorrodedMetal, Color = color, Vary = 0.05 }
	block(parent, Vector3.new(W, 0.4, L), cf * CFrame.new(0, 0.2, 0), M.Metal, C.DarkMetal)
	block(parent, Vector3.new(W, 0.4, L), cf * CFrame.new(0, H - 0.2, 0), M.CorrodedMetal, color)
	block(parent, Vector3.new(W - 0.4, 0.3, L - 0.4), cf * CFrame.new(0, H + 0.15, 0), M.Snow, C.Snow, { CanCollide = false })
	local y0 = cf.Position.Y + 0.4
	local function w(ax, az, bx, bz)
		wall(parent, cf:PointToWorldSpace(Vector3.new(ax, 0, az)), cf:PointToWorldSpace(Vector3.new(bx, 0, bz)), y0, H - 0.8, 0.35, style)
	end
	w(-W / 2 + 0.2, -L / 2, -W / 2 + 0.2, L / 2)
	w(W / 2 - 0.2, -L / 2, W / 2 - 0.2, L / 2)
	w(-W / 2, -L / 2 + 0.2, W / 2, -L / 2 + 0.2)
	if not openBack then
		w(-W / 2, L / 2 - 0.2, W / 2, L / 2 - 0.2)
	end
end

local function watchtower(parent, pos)
	local model = Instance.new("Model")
	model.Name = "Watchtower"
	local H = 24
	for _, x in { -4, 4 } do
		for _, z in { -4, 4 } do
			block(model, Vector3.new(1.2, H, 1.2), CFrame.new(pos + Vector3.new(x, H / 2, z)), M.Wood, C.DarkWood)
		end
	end
	for _, y in { 7, 15 } do
		block(model, Vector3.new(9, 0.6, 0.6), CFrame.new(pos + Vector3.new(0, y, -4)), M.Wood, C.DarkWood)
		block(model, Vector3.new(9, 0.6, 0.6), CFrame.new(pos + Vector3.new(0, y, 4)), M.Wood, C.DarkWood)
	end
	block(model, Vector3.new(11, 0.8, 11), CFrame.new(pos + Vector3.new(0, H, 0)), M.WoodPlanks, C.Wood)
	for _, d in { Vector3.new(0, 0, -5.3), Vector3.new(0, 0, 5.3), Vector3.new(-5.3, 0, 0), Vector3.new(5.3, 0, 0) } do
		local size = d.X == 0 and Vector3.new(11, 1.2, 0.4) or Vector3.new(0.4, 1.2, 11)
		block(model, size, CFrame.new(pos + d + Vector3.new(0, H + 1, 0)), M.Wood, C.Wood)
	end
	for _, x in { -5, 5 } do
		for _, z in { -5, 5 } do
			block(model, Vector3.new(0.5, 6, 0.5), CFrame.new(pos + Vector3.new(x, H + 3.4, z)), M.Wood, C.DarkWood)
		end
	end
	block(model, Vector3.new(12.5, 0.6, 12.5), CFrame.new(pos + Vector3.new(0, H + 6.6, 0)), M.CorrodedMetal, C.Metal)
	block(model, Vector3.new(12, 0.3, 12), CFrame.new(pos + Vector3.new(0, H + 7, 0)), M.Snow, C.Snow)
	make("TrussPart", model, {
		Size = Vector3.new(2, H, 2),
		CFrame = CFrame.new(pos + Vector3.new(0, H / 2, 5.4)),
		Material = M.Metal,
		Color = C.DarkMetal,
	})
	local search = block(model, Vector3.new(1.6, 1.6, 2.6), CFrame.new(pos + Vector3.new(0, H + 2.2, 0)), M.Metal, C.DarkMetal)
	make("SpotLight", search, { Face = Enum.NormalId.Front, Range = 60, Angle = 22, Brightness = 5, Color = rgb(235, 240, 255), Shadows = true })
	CollectionService:AddTag(search, "Searchlight")
	model.Parent = parent
	zone(pos.X, pos.Z, 12, 14)
end

local function terminal(parent, pos, facing, name)
	local model = Instance.new("Model")
	model.Name = name
	local cf = CFrame.lookAt(pos, pos + facing)
	local body = block(model, Vector3.new(4, 5, 2), cf * CFrame.new(0, 2.5, 0), M.Metal, C.DarkMetal)
	body.Name = "Body"
	block(model, Vector3.new(4, 0.4, 1.6), cf * CFrame.new(0, 3, -1.5) * CFrame.Angles(math.rad(20), 0, 0), M.Metal, C.Metal)
	local screen = block(model, Vector3.new(3.2, 2, 0.1), cf * CFrame.new(0, 3.9, -1.02), M.Neon, rgb(255, 50, 50))
	screen.Name = "Screen"
	light(screen, { Range = 12, Brightness = 1.5, Color = rgb(255, 50, 50) })
	local gui = make("SurfaceGui", screen, { Face = Enum.NormalId.Front, LightInfluence = 0 })
	local label = make("TextLabel", gui, {
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "SENTINEL\nOFFLINE",
		TextScaled = true,
		Font = Enum.Font.Code,
		TextColor3 = Color3.new(1, 1, 1),
	})
	label.Name = "Label"
	make("ProximityPrompt", body, {
		Name = "TerminalPrompt",
		ActionText = "Reboot",
		ObjectText = "Sentinel Terminal",
		HoldDuration = Config.Sentinel.HoldTime,
		MaxActivationDistance = 9,
		RequiresLineOfSight = false,
	})
	model.Parent = parent
	return model
end

-- A box you can climb into. Every panel is breakable; smashing it throws
-- the occupant out. `cf` sits on the floor with -Z facing out (the door).
local SPOT_KINDS = {
	Locker = { Size = Vector3.new(3, 7.5, 2.6), Material = M.Metal, Color = rgb(70, 85, 110) },
	Wardrobe = { Size = Vector3.new(4.5, 8, 3), Material = M.WoodPlanks, Color = rgb(90, 58, 36) },
	Dumpster = { Size = Vector3.new(7, 4.5, 4.5), Material = M.Metal, Color = rgb(40, 90, 55) },
	Freezer = { Size = Vector3.new(6, 8, 6), Material = M.SmoothPlastic, Color = rgb(215, 220, 225) },
	Cabinet = { Size = Vector3.new(3.5, 7, 3), Material = M.Metal, Color = rgb(110, 110, 100) },
}

local function hidingSpot(folder, cf, kind)
	local k = SPOT_KINDS[kind]
	local s = k.Size
	local t = 0.3
	local model = Instance.new("Model")
	model.Name = kind
	local function panel(size, offset, color)
		return breakable(block(model, size, cf * CFrame.new(offset), k.Material, color or k.Color))
	end
	panel(Vector3.new(s.X, s.Y, t), Vector3.new(0, s.Y / 2, s.Z / 2 - t / 2))
	panel(Vector3.new(t, s.Y, s.Z), Vector3.new(-s.X / 2 + t / 2, s.Y / 2, 0))
	panel(Vector3.new(t, s.Y, s.Z), Vector3.new(s.X / 2 - t / 2, s.Y / 2, 0))
	panel(Vector3.new(s.X, t, s.Z), Vector3.new(0, s.Y - t / 2, 0), kind == "Dumpster" and rgb(30, 30, 32) or nil)
	local door = panel(Vector3.new(s.X - 0.1, s.Y - 0.1, t), Vector3.new(0, s.Y / 2, -s.Z / 2 + t / 2), vary(k.Color, 0.1))
	block(model, Vector3.new(0.2, 0.9, 0.2), cf * CFrame.new(s.X * 0.3, s.Y * 0.5, -s.Z / 2 - 0.1), M.Metal, C.DarkMetal)
	if kind == "Locker" or kind == "Cabinet" then
		for i = 0, 2 do
			block(model, Vector3.new(s.X * 0.6, 0.08, 0.05), cf * CFrame.new(0, s.Y * 0.75 + i * 0.25, -s.Z / 2 - 0.02), M.Metal, C.DarkMetal)
		end
	end
	if kind == "Dumpster" then
		block(model, Vector3.new(s.X + 0.4, 0.3, s.Z + 0.2), cf * CFrame.new(0, s.Y + 0.15, 0), M.Snow, C.Snow, { CanCollide = false })
	end
	local inside = block(model, Vector3.one, cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, math.pi, 0), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false })
	inside.Name = "Inside"
	local exit = block(model, Vector3.one, cf * CFrame.new(0, 0, -s.Z / 2 - 2.5) * CFrame.Angles(0, math.pi, 0), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false })
	exit.Name = "Exit"
	make("ProximityPrompt", door, {
		Name = "HidePrompt",
		ActionText = "Hide",
		ObjectText = kind,
		HoldDuration = 0.4,
		MaxActivationDistance = 7,
		RequiresLineOfSight = false,
	})
	model.Parent = folder
	return model
end

local function sentinelPod(parent, pos)
	local model = Instance.new("Model")
	model.Name = "SentinelPod"
	local purple = rgb(130, 40, 190)
	local base = block(model, Vector3.new(1.4, 14, 14), CFrame.new(pos + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.DiamondPlate, C.DarkMetal, { Shape = Enum.PartType.Cylinder })
	block(model, Vector3.new(0.3, 14.4, 14.4), CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Neon, purple, { Shape = Enum.PartType.Cylinder })
	block(model, Vector3.new(11, 8, 8), CFrame.new(pos + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Glass, rgb(200, 170, 255), { Shape = Enum.PartType.Cylinder, Transparency = 0.75, CanCollide = false })
	block(model, Vector3.new(1, 9, 9), CFrame.new(pos + Vector3.new(0, 13, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, C.DarkMetal, { Shape = Enum.PartType.Cylinder })

	local dummy = Instance.new("Model")
	dummy.Name = "Dummy"
	block(dummy, Vector3.new(3.4, 3.6, 2), CFrame.new(pos + Vector3.new(0, 6.6, 0)), M.Metal, purple)
	block(dummy, Vector3.new(2, 2, 2), CFrame.new(pos + Vector3.new(0, 9.5, 0)), M.Metal, purple)
	block(dummy, Vector3.new(1.6, 0.3, 0.1), CFrame.new(pos + Vector3.new(0, 9.6, -1.02)), M.Neon, rgb(255, 210, 60))
	block(dummy, Vector3.new(1.2, 3.2, 1.2), CFrame.new(pos + Vector3.new(-2.4, 6.6, 0)), M.Metal, purple)
	block(dummy, Vector3.new(1.2, 3.2, 1.2), CFrame.new(pos + Vector3.new(2.4, 6.6, 0)), M.Metal, purple)
	block(dummy, Vector3.new(1.3, 3.4, 1.3), CFrame.new(pos + Vector3.new(-0.8, 3.1, 0)), M.Metal, C.Metal)
	block(dummy, Vector3.new(1.3, 3.4, 1.3), CFrame.new(pos + Vector3.new(0.8, 3.1, 0)), M.Metal, C.Metal)
	dummy.Parent = model

	local beacon = block(model, Vector3.new(1.5, 300, 1.5), CFrame.new(pos + Vector3.new(0, 150, 0)), M.Neon, purple, { Transparency = 1, CanCollide = false, CanQuery = false })
	beacon.Name = "Beacon"
	light(base, { Name = "PodLight", Range = 16, Brightness = 1, Color = purple })
	make("ProximityPrompt", base, {
		Name = "PodPrompt",
		ActionText = "Enter Sentinel Suit",
		ObjectText = "Sentinel Pod",
		HoldDuration = Config.Sentinel.PodHoldTime,
		MaxActivationDistance = 12,
		RequiresLineOfSight = false,
		Enabled = false,
	})
	model.Parent = parent
	zone(pos.X, pos.Z, 16, 16)
	return model
end

---------------------------------------------------------------------------
-- Areas
---------------------------------------------------------------------------

local function buildLab(bld, props, map)
	local lab, y0 = building(bld, Vector3.zero, 90, 70, 15, {
		Name = "WeaponX_Lab",
		Wall = { Material = M.Concrete, Color = C.Concrete, Vary = 0.04 },
		InteriorWall = { Material = M.SmoothPlastic, Color = C.LabInner, Vary = 0.03 },
		Floor = { Material = M.DiamondPlate, Color = C.LabFloor },
		Roof = "flat",
		RoofStyle = { Material = M.Concrete, Color = rgb(110, 112, 118) },
		Lights = true,
		LightSpacing = 15,
		LightColor = C.Cold,
		FlickerChance = 0.35,
		Openings = {
			S = { { At = 0, Width = 10, Bottom = 0, Top = 10 }, { At = -28, Width = 8, Bottom = 4, Top = 8, Glass = true }, { At = 28, Width = 8, Bottom = 4, Top = 8, Glass = true } },
			N = { { At = -25, Width = 6, Bottom = 0, Top = 9 }, { At = 25, Width = 6, Bottom = 0, Top = 9 } },
			E = { { At = 0, Width = 7, Bottom = 0, Top = 9 } },
			W = { { At = 0, Width = 7, Bottom = 0, Top = 9 } },
		},
		Interior = {
			{ A = Vector3.new(-45, 0, -18), B = Vector3.new(-20, 0, -18), Openings = { { At = 0, Width = 5, Bottom = 0, Top = 8 } } },
			{ A = Vector3.new(-20, 0, -35), B = Vector3.new(-20, 0, -18), Openings = { { At = 0, Width = 5, Bottom = 0, Top = 8 } } },
			{ A = Vector3.new(-45, 0, 18), B = Vector3.new(-20, 0, 18), Openings = { { At = 0, Width = 5, Bottom = 0, Top = 8 } } },
			{ A = Vector3.new(-20, 0, 18), B = Vector3.new(-20, 0, 35), Openings = { { At = 0, Width = 5, Bottom = 0, Top = 8 } } },
			{ A = Vector3.new(20, 0, -18), B = Vector3.new(45, 0, -18), Openings = { { At = 0, Width = 5, Bottom = 0, Top = 8 } } },
			{ A = Vector3.new(20, 0, -35), B = Vector3.new(20, 0, -18), Openings = { { At = 0, Width = 5, Bottom = 0, Top = 8 } } },
			{ A = Vector3.new(20, 0, 18), B = Vector3.new(45, 0, 18), Openings = { { At = 0, Width = 5, Bottom = 0, Top = 8 } } },
			{ A = Vector3.new(20, 0, 18), B = Vector3.new(20, 0, 35), Openings = { { At = 0, Width = 5, Bottom = 0, Top = 8 } } },
		},
	})

	-- Tank chamber: breakable glass box Wolverine smashes out of
	local glass = { Material = M.Glass, Color = rgb(150, 195, 215), Transparency = 0.55, Reflectance = 0.1, Vary = 0 }
	local cx, cz = 12, 10
	wall(lab, Vector3.new(-cx, 0, -cz), Vector3.new(cx, 0, -cz), y0, 15, 0.6, glass)
	wall(lab, Vector3.new(-cx, 0, cz), Vector3.new(cx, 0, cz), y0, 15, 0.6, glass)
	wall(lab, Vector3.new(-cx, 0, -cz), Vector3.new(-cx, 0, cz), y0, 15, 0.6, glass)
	wall(lab, Vector3.new(cx, 0, -cz), Vector3.new(cx, 0, cz), y0, 15, 0.6, glass)
	for _, x in { -cx, cx } do
		for _, z in { -cz, cz } do
			block(lab, Vector3.new(1.2, 15, 1.2), CFrame.new(x, y0 + 7.5, z), M.Metal, C.DarkMetal)
		end
	end
	-- hazard border
	for _, d in { { 0, -cz - 1.2, 2 * cx + 3, 1 }, { 0, cz + 1.2, 2 * cx + 3, 1 }, { -cx - 1.2, 0, 1, 2 * cz + 3 }, { cx + 1.2, 0, 1, 2 * cz + 3 } } do
		block(lab, Vector3.new(d[3], 0.05, d[4]), CFrame.new(d[1], y0 + 0.03, d[2]), M.SmoothPlastic, C.Hazard)
	end
	sign(lab, CFrame.new(0, y0 + 12.5, cz + 0.45) * CFrame.Angles(0, math.pi, 0), Vector3.new(14, 2.2, 0.2), "SUBJECT X — DO NOT OPEN", rgb(255, 60, 60), rgb(25, 25, 28))

	-- The adamantium tank
	local tp = Vector3.new(0, y0, -4)
	block(lab, Vector3.new(1, 9, 9), CFrame.new(tp + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, C.DarkMetal, { Shape = Enum.PartType.Cylinder })
	block(lab, Vector3.new(9, 7.5, 7.5), CFrame.new(tp + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Glass, C.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.7, CanCollide = true })
	local liquid = block(lab, Vector3.new(6, 7, 7), CFrame.new(tp + Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Neon, rgb(80, 220, 200), { Shape = Enum.PartType.Cylinder, Transparency = 0.55, CanCollide = false })
	light(liquid, { Range = 22, Brightness = 2, Color = rgb(80, 230, 210) })
	block(lab, Vector3.new(1, 9, 9), CFrame.new(tp + Vector3.new(0, 10.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, C.DarkMetal, { Shape = Enum.PartType.Cylinder })
	for _, x in { -2.5, 2.5 } do
		block(lab, Vector3.new(4.5, 0.8, 0.8), CFrame.new(tp + Vector3.new(x, 13, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, C.Metal, { Shape = Enum.PartType.Cylinder })
	end
	-- restraint frame where he wakes up
	block(lab, Vector3.new(8, 0.6, 0.6), CFrame.new(0, y0 + 9, 7.5), M.Metal, C.DarkMetal)
	for _, x in { -3.7, 3.7 } do
		block(lab, Vector3.new(0.6, 9, 0.6), CFrame.new(x, y0 + 4.5, 7.5), M.Metal, C.DarkMetal)
	end

	local spawn = block(map, Vector3.new(2, 1, 2), CFrame.lookAt(Vector3.new(0, y0 + 3.5, 4), Vector3.new(0, y0 + 3.5, 20)), M.SmoothPlastic, C.Blood, { Transparency = 1, CanCollide = false, CanQuery = false })
	spawn.Name = "WolverineSpawn"

	-- Server room (NW)
	for i = 0, 3 do
		for _, z in { -30, -23 } do
			local rack = block(props, Vector3.new(2.2, 8, 5), CFrame.new(-40 + i * 5.5, y0 + 4, z), M.Metal, rgb(30, 32, 38))
			breakable(rack)
			for j = 1, 4 do
				block(props, Vector3.new(0.1, 0.2, 0.3), CFrame.new(-40 + i * 5.5 + 1.15, y0 + 1.5 + j * 1.4, z - 1.5 + rng:NextNumber() * 3), M.Neon, j % 2 == 0 and rgb(60, 255, 120) or rgb(255, 80, 40))
			end
		end
	end
	-- Hiding lockers (NE locker room, server room, med bay)
	local hide = map:FindFirstChild("HidingSpots")
	for _, z in { -29, -25, -21 } do
		hidingSpot(hide, CFrame.lookAt(Vector3.new(43.2, y0, z), Vector3.new(0, y0, z)), "Locker")
	end
	hidingSpot(hide, CFrame.lookAt(Vector3.new(-43.2, y0, -21), Vector3.new(0, y0, -21)), "Cabinet")
	hidingSpot(hide, CFrame.lookAt(Vector3.new(-43, y0, 24), Vector3.new(0, y0, 24)), "Locker")

	-- Med bay (SW)
	for i = 0, 2 do
		local x = -40 + i * 7
		block(props, Vector3.new(3.5, 1.4, 7), CFrame.new(x, y0 + 1.3, 30), M.Metal, C.Metal)
		block(props, Vector3.new(3.2, 0.5, 6.6), CFrame.new(x, y0 + 2.2, 30), M.Fabric, rgb(220, 225, 230))
		block(props, Vector3.new(3.3, 0.1, 6.7), CFrame.new(x, y0 + 2.5, 30.2), M.Fabric, rgb(120, 20, 20), { Transparency = i == 1 and 0 or 1 })
	end
	-- Lockers (NE)
	for i = 0, 7 do
		breakable(block(props, Vector3.new(2.4, 7.5, 2), CFrame.new(23 + i * 2.6, y0 + 3.75, -33.5), M.Metal, rgb(70, 85, 110)))
	end
	-- Cafeteria (SE)
	for i = 0, 1 do
		for j = 0, 1 do
			local p = Vector3.new(28 + i * 9, y0, 23 + j * 7)
			breakable(block(props, Vector3.new(6, 0.4, 3), CFrame.new(p + Vector3.new(0, 3, 0)), M.WoodPlanks, C.Wood))
			block(props, Vector3.new(6, 0.4, 1), CFrame.new(p + Vector3.new(0, 1.7, -2.2)), M.Metal, C.Metal)
			block(props, Vector3.new(6, 0.4, 1), CFrame.new(p + Vector3.new(0, 1.7, 2.2)), M.Metal, C.Metal)
		end
	end
	-- Corridor clutter, pipes, emergency lights, blood
	for _, p in { Vector3.new(-16, y0, 14), Vector3.new(16, y0, -14), Vector3.new(-30, y0, 3), Vector3.new(35, y0, -4) } do
		crate(props, p, 4)
		barrel(props, p + Vector3.new(3.5, 0, 1))
	end
	for _, z in { -26, 26 } do
		block(props, Vector3.new(88, 0.9, 0.9), CFrame.new(0, y0 + 13.8, z) * CFrame.Angles(0, 0, 0), M.Metal, C.Metal, { Shape = Enum.PartType.Cylinder })
	end
	for _, pos in { Vector3.new(-44, y0 + 11, 0), Vector3.new(44, y0 + 11, 0), Vector3.new(0, y0 + 11, -34), Vector3.new(0, y0 + 11, 34) } do
		local e = block(lab, Vector3.new(0.8, 0.8, 0.8), CFrame.new(pos), M.Neon, C.Emergency)
		light(e, { Range = 18, Brightness = 1.5, Color = C.Emergency })
		CollectionService:AddTag(e, "Flicker")
	end
	for _ = 1, 7 do
		local p = Vector3.new(rng:NextNumber(-40, 40), y0 + 0.03, rng:NextNumber(-30, 30))
		block(props, Vector3.new(rng:NextNumber(1.5, 4), 0.05, rng:NextNumber(1, 3)), CFrame.new(p) * CFrame.Angles(0, rng:NextNumber() * 6, 0), M.SmoothPlastic, C.Blood, { CanCollide = false, CanQuery = false })
	end

	-- Front sign and door lights
	sign(lab, CFrame.new(0, y0 + 12.5, 35.6) * CFrame.Angles(0, math.pi, 0), Vector3.new(24, 3.5, 0.3), "WEAPON X", rgb(255, 60, 60), rgb(20, 20, 22))
	for _, x in { -6.5, 6.5 } do
		local l = block(lab, Vector3.new(0.8, 0.8, 0.4), CFrame.new(x, y0 + 10.5, 35.8), M.Neon, C.Emergency)
		light(l, { Range = 16, Brightness = 2, Color = C.Emergency })
	end
	zone(0, 0, 100, 80)
end

local function buildCabin(bld, props, center, withFire)
	local model, y0 = building(bld, center, 22, 16, 9, {
		Name = "Cabin",
		Wall = { Material = M.WoodPlanks, Color = C.Wood, Vary = 0.1 },
		Floor = { Material = M.WoodPlanks, Color = C.DarkWood },
		Roof = "gable",
		RoofHeight = 5,
		RoofStyle = { Material = M.Slate, Color = rgb(58, 52, 52) },
		Openings = {
			S = { { At = -4, Width = 5, Bottom = 0, Top = 7 }, { At = 5, Width = 4, Bottom = 3, Top = 6, Glass = true } },
			N = { { At = 0, Width = 4, Bottom = 3, Top = 6, Glass = true } },
			E = { { At = 0, Width = 4, Bottom = 3, Top = 6, Glass = true } },
			W = { { At = 2, Width = 4, Bottom = 0, Top = 7 } },
		},
		Interior = {
			{ A = Vector3.new(3, 0, -8), B = Vector3.new(3, 0, 8), Openings = { { At = 2, Width = 4, Bottom = 0, Top = 7 } } },
		},
	})
	local c = center
	-- wardrobe to hide in
	local hide = bld.Parent:FindFirstChild("HidingSpots")
	hidingSpot(hide, CFrame.lookAt(c + Vector3.new(9.2, y0, 4.5), c + Vector3.new(0, y0, 4.5)), "Wardrobe")
	-- bed & table
	breakable(block(props, Vector3.new(4, 1.4, 7), CFrame.new(c + Vector3.new(7.5, y0 + 0.7, -3)), M.Fabric, rgb(120, 40, 40)))
	breakable(block(props, Vector3.new(4, 0.4, 3), CFrame.new(c + Vector3.new(-4, y0 + 3, -2)), M.WoodPlanks, C.Wood))
	-- fireplace + chimney
	local fp = block(model, Vector3.new(2, 5, 5), CFrame.new(c + Vector3.new(-9.5, y0 + 2.5, -4)), M.Cobblestone, rgb(90, 90, 95))
	local chimney = block(model, Vector3.new(2, 10, 2.5), CFrame.new(c + Vector3.new(-10, y0 + 12, -4)), M.Cobblestone, rgb(90, 90, 95))
	chimney.Name = "Chimney"
	if withFire then
		make("Fire", fp, { Size = 3, Heat = 5, Color = rgb(255, 140, 40), SecondaryColor = rgb(255, 60, 20) })
		light(fp, { Range = 18, Brightness = 1.8, Color = rgb(255, 150, 70), Shadows = true })
		CollectionService:AddTag(fp, "FireLight")
	end
	-- porch + lantern
	block(model, Vector3.new(22, 0.5, 5), CFrame.new(c + Vector3.new(0, 0.25, 10.5)), M.WoodPlanks, C.DarkWood)
	local lantern = block(model, Vector3.new(0.6, 0.9, 0.6), CFrame.new(c + Vector3.new(-7.2, y0 + 7.5, 8.6)), M.Neon, C.Lamp)
	light(lantern, { Range = 16, Brightness = 1.3, Color = C.Lamp })
	if rng:NextNumber() < 0.5 then
		CollectionService:AddTag(lantern, "Flicker")
	end
	zone(c.X, c.Z + 3, 24, 22)
	return model, y0
end

local function buildWarehouse(bld, props, terminals, center)
	local model, y0 = building(bld, center, 56, 40, 16, {
		Name = "Warehouse",
		Wall = { Material = M.CorrodedMetal, Color = rgb(112, 86, 70), Vary = 0.08 },
		Floor = { Material = M.Concrete, Color = rgb(88, 88, 94) },
		Roof = "flat",
		RoofStyle = { Material = M.CorrodedMetal, Color = rgb(80, 82, 88) },
		Lights = true,
		LightSpacing = 18,
		LightColor = rgb(255, 210, 150),
		FlickerChance = 0.4,
		Openings = {
			W = { { At = 0, Width = 12, Bottom = 0, Top = 12 } },
			E = { { At = 6, Width = 10, Bottom = 0, Top = 11 } },
			S = { { At = -15, Width = 5, Bottom = 0, Top = 8 }, { At = 12, Width = 6, Bottom = 6, Top = 9, Glass = true } },
			N = { { At = -10, Width = 6, Bottom = 8, Top = 11, Glass = true }, { At = 10, Width = 6, Bottom = 8, Top = 11, Glass = true } },
		},
		Interior = {
			{ A = Vector3.new(14, 0, -20), B = Vector3.new(14, 0, -4), Height = 10, Openings = { { At = 0, Width = 5, Bottom = 0, Top = 8 } } },
			{ A = Vector3.new(14, 0, -4), B = Vector3.new(28, 0, -4), Height = 10, Openings = { { At = 0, Width = 5, Bottom = 4, Top = 7, Glass = true } } },
		},
	})
	local c = center
	block(model, Vector3.new(14, 0.5, 16), CFrame.new(c + Vector3.new(21, y0 + 10.25, -12)), M.Concrete, rgb(90, 90, 95))
	container(props, CFrame.new(c + Vector3.new(-16, 0, 6)) * CFrame.Angles(0, math.rad(90), 0), rgb(40, 90, 140), true)
	container(props, CFrame.new(c + Vector3.new(-2, 0, 12)), rgb(150, 50, 40), false)
	for i = 0, 5 do
		crate(props, c + Vector3.new(-22 + (i % 3) * 4.4, 0, -14 + math.floor(i / 3) * 4.4), 4)
	end
	crate(props, c + Vector3.new(-22, 4, -14), 4)
	-- catwalk + ladder
	block(model, Vector3.new(34, 0.5, 4), CFrame.new(c + Vector3.new(-9, y0 + 9, -17.5)), M.DiamondPlate, C.Metal)
	block(model, Vector3.new(34, 1.2, 0.3), CFrame.new(c + Vector3.new(-9, y0 + 9.9, -15.5)), M.Metal, C.Hazard)
	make("TrussPart", model, { Size = Vector3.new(2, 10, 2), CFrame = CFrame.new(c + Vector3.new(-25, y0 + 5, -14.5)), Material = M.Metal, Color = C.DarkMetal })
	terminal(terminals, c + Vector3.new(21, y0, -17.5), Vector3.new(0, 0, 1), "Terminal_Warehouse")
	local hide = bld.Parent:FindFirstChild("HidingSpots")
	hidingSpot(hide, CFrame.lookAt(c + Vector3.new(26, y0, -9), c + Vector3.new(0, y0, -9)), "Cabinet")
	hidingSpot(hide, CFrame.lookAt(c + Vector3.new(10, 0, 24), c + Vector3.new(10, 0, 40)), "Dumpster")
	return model
end

local function buildDiner(bld, props, terminals, center)
	local model, y0 = building(bld, center, 36, 22, 11, {
		Name = "Diner",
		Wall = { Material = M.Brick, Color = C.Brick, Vary = 0.08 },
		InteriorWall = { Material = M.SmoothPlastic, Color = rgb(220, 210, 190) },
		Floor = { Material = M.Marble, Color = rgb(210, 210, 215) },
		Roof = "flat",
		RoofStyle = { Material = M.Concrete, Color = rgb(70, 70, 76) },
		Lights = true,
		LightSpacing = 12,
		LightColor = rgb(255, 225, 180),
		FlickerChance = 0.5,
		Openings = {
			S = { { At = 0, Width = 5, Bottom = 0, Top = 8 }, { At = -10, Width = 10, Bottom = 2.5, Top = 8, Glass = true }, { At = 10, Width = 10, Bottom = 2.5, Top = 8, Glass = true } },
			W = { { At = 0, Width = 4, Bottom = 0, Top = 8 } },
			N = { { At = 12, Width = 4, Bottom = 0, Top = 8 } },
			E = { { At = 4, Width = 6, Bottom = 3, Top = 7, Glass = true } },
		},
		Interior = {
			{ A = Vector3.new(-18, 0, -3), B = Vector3.new(18, 0, -3), Openings = { { At = 12, Width = 4, Bottom = 0, Top = 8 }, { At = -4, Width = 10, Bottom = 3.5, Top = 7 } } },
		},
	})
	local c = center
	breakable(block(props, Vector3.new(18, 3.5, 2), CFrame.new(c + Vector3.new(-4, y0 + 1.75, -1)), M.Wood, rgb(150, 40, 40)))
	for i = 0, 5 do
		block(props, Vector3.new(1.8, 2.4, 1.8), CFrame.new(c + Vector3.new(-12 + i * 3.2, y0 + 1.2, 1.5)) * CFrame.Angles(0, 0, math.rad(90)), M.Fabric, rgb(170, 30, 30), { Shape = Enum.PartType.Cylinder })
	end
	for _, x in { -14, -8, 8, 14 } do
		breakable(block(props, Vector3.new(4, 0.4, 3), CFrame.new(c + Vector3.new(x, y0 + 3, 7.5)), M.SmoothPlastic, rgb(230, 230, 235)))
		block(props, Vector3.new(4, 3, 1), CFrame.new(c + Vector3.new(x, y0 + 1.5, 5.3)), M.Fabric, rgb(170, 30, 30))
	end
	local juke = block(props, Vector3.new(3, 5, 2), CFrame.new(c + Vector3.new(16, y0 + 2.5, 8)), M.Neon, rgb(255, 120, 200))
	light(juke, { Range = 12, Brightness = 1, Color = rgb(255, 120, 200) })
	terminal(terminals, c + Vector3.new(8, y0, -9), Vector3.new(0, 0, 1), "Terminal_Diner")
	local hide = bld.Parent:FindFirstChild("HidingSpots")
	hidingSpot(hide, CFrame.lookAt(c + Vector3.new(-14, y0, -7), c + Vector3.new(0, y0, -7)), "Freezer")
	hidingSpot(hide, CFrame.lookAt(c + Vector3.new(-6, 0, -15), c + Vector3.new(-6, 0, -30)), "Dumpster")
	-- Neon roof sign
	local signPart = sign(model, CFrame.new(c + Vector3.new(0, y0 + 14, 11.5)) * CFrame.Angles(0, math.pi, 0), Vector3.new(18, 4, 0.4), "JOE'S DINER", rgb(255, 80, 120), rgb(15, 15, 20), Enum.Font.LuckiestGuy)
	light(signPart, { Range = 24, Brightness = 2, Color = rgb(255, 80, 120) })
	CollectionService:AddTag(signPart, "Flicker")
	for _, x in { -7, 7 } do
		block(model, Vector3.new(0.5, 3, 0.5), CFrame.new(c + Vector3.new(x, y0 + 11.6, 11.5)), M.Metal, C.DarkMetal)
	end
	-- Parking lot + gas pumps
	block(props, Vector3.new(50, 0.2, 30), CFrame.new(c + Vector3.new(0, 0.1, 27)), M.Asphalt, C.Asphalt)
	car(props, CFrame.new(c + Vector3.new(-14, 0.2, 26)) * CFrame.Angles(0, math.rad(8), 0), rgb(40, 70, 120), false)
	car(props, CFrame.new(c + Vector3.new(4, 0.2, 30)) * CFrame.Angles(0, math.rad(-80), 0), rgb(130, 30, 30), true)
	for _, x in { 16, 22 } do
		breakable(block(props, Vector3.new(2, 5, 1.5), CFrame.new(c + Vector3.new(x, 2.7, 34)), M.SmoothPlastic, rgb(200, 40, 40)))
	end
	block(props, Vector3.new(14, 0.8, 8), CFrame.new(c + Vector3.new(19, 11, 34)), M.Metal, rgb(220, 220, 225))
	for _, x in { 13, 25 } do
		block(props, Vector3.new(0.8, 10.6, 0.8), CFrame.new(c + Vector3.new(x, 5.3, 34)), M.Metal, C.Metal)
	end
	local canopy = block(props, Vector3.new(12, 0.2, 6), CFrame.new(c + Vector3.new(19, 10.5, 34)), M.Neon, rgb(240, 245, 255))
	light(canopy, { Range = 22, Brightness = 1.5, Color = rgb(230, 240, 255) })
	CollectionService:AddTag(canopy, "Flicker")
	zone(c.X, c.Z + 14, 52, 54)
	return model
end

local function buildContainerYard(props, map, center)
	local colors = { rgb(40, 90, 140), rgb(150, 50, 40), rgb(60, 110, 60), rgb(190, 130, 40), rgb(90, 90, 100) }
	local spots = {
		{ -26, -22, 0, false }, { -26, 22, 0, true }, { 26, -22, 0, true }, { 26, 22, 0, false },
		{ 0, -32, 90, false }, { 0, 32, 90, true }, { -38, 0, 90, false }, { 38, 0, 90, true },
	}
	for i, s in spots do
		local cf = CFrame.new(center + Vector3.new(s[1], 0, s[2])) * CFrame.Angles(0, math.rad(s[3]), 0)
		container(props, cf, colors[(i - 1) % #colors + 1], s[4])
		if i % 3 == 1 then
			container(props, cf + Vector3.new(0, 8.5, 0), colors[i % #colors + 1], false)
		end
	end
	for _, d in { Vector3.new(-14, 0, 14), Vector3.new(14, 0, -14) } do
		local p = center + d
		block(props, Vector3.new(0.8, 20, 0.8), CFrame.new(p + Vector3.new(0, 10, 0)), M.Metal, C.DarkMetal)
		local head = block(props, Vector3.new(3, 1, 1.2), CFrame.lookAt(p + Vector3.new(0, 20, 0), center), M.Neon, C.Cold)
		make("SpotLight", head, { Face = Enum.NormalId.Front, Range = 45, Angle = 60, Brightness = 2.5, Color = C.Cold, Shadows = true })
	end
	sentinelPod(map, center)
	hidingSpot(map:FindFirstChild("HidingSpots"), CFrame.lookAt(center + Vector3.new(12, 0, 8), center + Vector3.new(0, 0, 8)), "Dumpster")
	zone(center.X, center.Z, 90, 90)
end

local function buildGate(props, bld)
	local z = HALF - 6
	for _, x in { -9, 9 } do
		block(props, Vector3.new(2, 12, 2), CFrame.new(x, 6, z), M.Concrete, C.Concrete)
		local l = block(props, Vector3.new(1, 1, 1), CFrame.new(x, 12.6, z), M.Neon, C.Emergency)
		light(l, { Range = 16, Brightness = 2, Color = C.Emergency })
		CollectionService:AddTag(l, "Flicker")
	end
	block(props, Vector3.new(16, 0.6, 0.6), CFrame.new(0, 4, z - 1.5) * CFrame.Angles(0, 0, math.rad(12)), M.SmoothPlastic, rgb(220, 60, 60))
	building(bld, Vector3.new(16, 0, z - 16), 8, 8, 8, {
		Name = "GuardBooth",
		Wall = { Material = M.Concrete, Color = rgb(150, 150, 140) },
		Floor = { Material = M.Concrete, Color = rgb(100, 100, 100) },
		Roof = "flat",
		RoofStyle = { Material = M.Metal, Color = C.DarkMetal },
		Lights = true,
		LightColor = C.Cold,
		FlickerChance = 1,
		Openings = {
			W = { { At = 0, Width = 3.5, Bottom = 0, Top = 7 } },
			S = { { At = 0, Width = 5, Bottom = 3, Top = 6, Glass = true } },
			N = { { At = 0, Width = 5, Bottom = 3, Top = 6, Glass = true } },
		},
	})
	sign(props, CFrame.new(0, 14, z), Vector3.new(20, 2.5, 0.3), "ALKALI LAKE — RESTRICTED", rgb(255, 220, 90), rgb(25, 25, 28))
	zone(0, z - 8, 30, 20)
end

local function buildRoads(env, props)
	local function road(cx, cz, sx, sz)
		block(env, Vector3.new(sx, 0.2, sz), CFrame.new(cx, 0.1, cz), M.Asphalt, C.Asphalt)
		zone(cx, cz, sx, sz)
		local alongX = sx > sz
		local len = alongX and sx or sz
		-- solid white edge lines
		for _, off in { -1, 1 } do
			local w = (alongX and sz or sx) / 2 - 0.7
			local p = alongX and Vector3.new(cx, 0.215, cz + off * w) or Vector3.new(cx + off * w, 0.215, cz)
			block(env, alongX and Vector3.new(len - 2, 0.03, 0.25) or Vector3.new(0.25, 0.03, len - 2), CFrame.new(p), M.SmoothPlastic, rgb(215, 215, 210), { CanCollide = false })
		end
		for t = -len / 2 + 4, len / 2 - 4, 10 do
			local p = alongX and Vector3.new(cx + t, 0.22, cz) or Vector3.new(cx, 0.22, cz + t)
			block(env, alongX and Vector3.new(4, 0.05, 0.4) or Vector3.new(0.4, 0.05, 4), CFrame.new(p), M.SmoothPlastic, C.Line)
		end
	end
	road(0, -56, 136, 12) -- ring north
	road(0, 56, 136, 12) -- ring south
	road(-62, 0, 12, 100) -- ring west
	road(62, 0, 12, 100) -- ring east
	road(0, 121, 12, 118) -- main road to gate
	road(0, -121, 12, 118) -- north road
	road(124, 0, 112, 12) -- east
	road(-124, 0, 112, 12) -- west

	-- Crosswalks where the main roads meet the ring road
	for _, c in { { 0, 68, false }, { 0, -68, false }, { 74, 0, true }, { -74, 0, true } } do
		for k = -2, 2 do
			local p = c[3] and Vector3.new(c[1], 0.22, c[2] + k * 2.1) or Vector3.new(c[1] + k * 2.1, 0.22, c[2])
			block(env, c[3] and Vector3.new(4.5, 0.04, 1.1) or Vector3.new(1.1, 0.04, 4.5), CFrame.new(p), M.SmoothPlastic, rgb(225, 225, 220), { CanCollide = false })
		end
	end
	-- Manhole covers
	for _, p in { Vector3.new(0, 0.21, 95), Vector3.new(0, 0.21, -100), Vector3.new(110, 0.21, 0), Vector3.new(-120, 0.21, 0), Vector3.new(-30, 0.21, -56), Vector3.new(40, 0.21, 56) } do
		block(env, Vector3.new(0.05, 2.4, 2.4), CFrame.new(p) * CFrame.Angles(0, 0, math.rad(90)), M.DiamondPlate, rgb(40, 40, 42), { Shape = Enum.PartType.Cylinder, CanCollide = false })
	end
	-- Curbed sidewalk around the lab + entrance plazas
	local pave, curb = rgb(138, 138, 144), rgb(170, 170, 172)
	for _, sw in { { 0, -48, 112, 4 }, { 0, 48, 112, 4 }, { -54, 0, 4, 92 }, { 54, 0, 4, 92 } } do
		block(env, Vector3.new(sw[3], 0.5, sw[4]), CFrame.new(sw[1], 0.25, sw[2]), M.Pavement, pave)
		local outer = sw[3] > sw[4]
		local ex = outer and 0 or (sw[1] > 0 and 1 or -1) * (sw[3] / 2 - 0.2)
		local ez = outer and (sw[2] > 0 and 1 or -1) * (sw[4] / 2 - 0.2) or 0
		block(env, outer and Vector3.new(sw[3], 0.6, 0.4) or Vector3.new(0.4, 0.6, sw[4]), CFrame.new(sw[1] + ex, 0.3, sw[2] + ez), M.Concrete, curb)
	end
	for _, pz in { { 0, 41, 16, 11 }, { 48.5, 0, 7, 10 }, { -48.5, 0, 7, 10 }, { 25, -41, 8, 11 }, { -25, -41, 8, 11 } } do
		block(env, Vector3.new(pz[3], 0.5, pz[4]), CFrame.new(pz[1], 0.25, pz[2]), M.Pavement, pave)
	end

	-- snow drifts on the roads
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-HALF, HALF), rng:NextNumber(-HALF, HALF)
		if inZone(x, z, 0) and not inZone(x, z, -8) then
			block(env, Vector3.new(rng:NextNumber(3, 8), 0.25, rng:NextNumber(3, 8)), CFrame.new(x, 0.2, z) * CFrame.Angles(0, rng:NextNumber() * 6, 0), M.Snow, C.SnowShade, { CanCollide = false })
		end
	end

	-- street lamps
	local lampSpots = {}
	for x = -60, 60, 30 do
		table.insert(lampSpots, { Vector3.new(x, 0, -63.5), Vector3.new(0, 0, 1) })
		table.insert(lampSpots, { Vector3.new(x, 0, 63.5), Vector3.new(0, 0, -1) })
	end
	for z = 75, 165, 30 do
		table.insert(lampSpots, { Vector3.new(7.5, 0, z), Vector3.new(-1, 0, 0) })
		table.insert(lampSpots, { Vector3.new(-7.5, 0, -z), Vector3.new(1, 0, 0) })
	end
	for x = 80, 170, 30 do
		table.insert(lampSpots, { Vector3.new(x, 0, 7.5), Vector3.new(0, 0, -1) })
		table.insert(lampSpots, { Vector3.new(-x, 0, -7.5), Vector3.new(0, 0, 1) })
	end
	for _, s in lampSpots do
		lamp(props, s[1], s[2], rng:NextNumber() < 0.3)
	end

	-- abandoned cars
	car(props, CFrame.new(-30, 0.2, 56) * CFrame.Angles(0, math.rad(95), 0), rgb(70, 70, 75), false)
	car(props, CFrame.new(62, 0.2, -30) * CFrame.Angles(0, math.rad(12), 0), rgb(30, 60, 40), true)
	car(props, CFrame.new(2, 0.2, 100) * CFrame.Angles(0, math.rad(-20), 0), rgb(150, 150, 155), false)
	car(props, CFrame.new(-110, 0.2, 2) * CFrame.Angles(0, math.rad(80), 0), rgb(100, 30, 30), false)
end

local function buildBoundary(env)
	local function side(cx, cz, sx, sz)
		block(env, Vector3.new(sx, 120, sz), CFrame.new(cx, 60, cz), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
	end
	local e = HALF + 3
	side(0, -e, 2 * e + 2, 2)
	side(0, e, 2 * e + 2, 2)
	side(-e, 0, 2, 2 * e + 2)
	side(e, 0, 2, 2 * e + 2)

	-- fence
	for _, s in { { "x", -HALF }, { "x", HALF }, { "z", -HALF }, { "z", HALF } } do
		local along = s[1]
		for t = -HALF, HALF, 12 do
			local p = along == "x" and Vector3.new(t, 5, s[2]) or Vector3.new(s[2], 5, t)
			block(env, Vector3.new(0.6, 10, 0.6), CFrame.new(p), M.Metal, C.DarkMetal)
		end
		local size = along == "x" and Vector3.new(2 * HALF, 9, 0.2) or Vector3.new(0.2, 9, 2 * HALF)
		local c = along == "x" and Vector3.new(0, 4.5, s[2]) or Vector3.new(s[2], 4.5, 0)
		block(env, size, CFrame.new(c), M.DiamondPlate, rgb(120, 125, 130), { Transparency = 0.8 })
		for _, y in { 9.6, 10.2 } do
			local wsize = along == "x" and Vector3.new(2 * HALF, 0.1, 0.1) or Vector3.new(0.1, 0.1, 2 * HALF)
			block(env, wsize, CFrame.new(c.X, y, c.Z), M.Metal, rgb(150, 150, 150))
		end
	end

	-- dark forest & mountains beyond the fence
	for _ = 1, 140 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(HALF + 12, HALF + 80)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if math.abs(x) > HALF + 8 or math.abs(z) > HALF + 8 then
			tree(env, Vector3.new(x, 0, z), rng:NextNumber(1.2, 2), true)
		end
	end
	for i = 1, (terrain() and 0 or 18) do
		local a = (i / 18) * math.pi * 2 + rng:NextNumber() * 0.2
		local r = rng:NextNumber(330, 400)
		local h = rng:NextNumber(90, 190)
		local w = rng:NextNumber(120, 200)
		local cf = CFrame.new(math.cos(a) * r, h / 2 - 20, math.sin(a) * r) * CFrame.Angles(0, -a, math.rad(rng:NextNumber(-12, 12)))
		block(env, Vector3.new(w, h, w * 0.7), cf * CFrame.Angles(0, math.rad(45), 0), M.Slate, vary(rgb(70, 74, 84), 0.2), { CanCollide = false })
		block(env, Vector3.new(w * 0.55, h * 0.25, w * 0.4), cf * CFrame.new(0, h * 0.42, 0) * CFrame.Angles(0, math.rad(45), 0), M.Snow, C.Snow, { CanCollide = false })
	end
end

local function buildWilderness(env, props)
	for _ = 1, 260 do
		local x, z = rng:NextNumber(-HALF + 6, HALF - 6), rng:NextNumber(-HALF + 6, HALF - 6)
		if not inZone(x, z, 6) then
			local roll = rng:NextNumber()
			if roll < 0.62 then
				tree(env, Vector3.new(x, 0, z), rng:NextNumber(0.9, 1.5))
				zone(x, z, 4, 4)
			elseif roll < 0.8 then
				rock(props, Vector3.new(x, 0, z), Vector3.new(rng:NextNumber(4, 9), rng:NextNumber(3, 6), rng:NextNumber(4, 9)))
				zone(x, z, 8, 8)
			else
				local t = terrain()
				local r = rng:NextNumber(6, 11)
				if t then
					t:FillBall(Vector3.new(x, -r * 0.55, z), r, Enum.Material.Snow)
				else
					block(env, Vector3.one * r * 2, CFrame.new(x, -r * 0.55, z), M.Snow, C.SnowShade, { Shape = Enum.PartType.Ball })
				end
			end
		end
	end
	for _, p in { Vector3.new(-80, 0, -80), Vector3.new(85, 0, 70), Vector3.new(-40, 0, 160), Vector3.new(160, 0, -60), Vector3.new(-160, 0, 60), Vector3.new(45, 0, -100) } do
		if not inZone(p.X, p.Z, 2) then
			fireBarrel(props, p)
		end
	end
end


---------------------------------------------------------------------------
-- Extra detail pass: the stuff that makes it feel lived-in (and abandoned)
---------------------------------------------------------------------------

local function powerLine(parent, a, b, spacing)
	local dir = (b - a).Unit
	local len = (b - a).Magnitude
	local side = dir:Cross(Vector3.yAxis)
	local poles = {}
	for t = 0, len, spacing do
		local p = a + dir * t
		block(parent, Vector3.new(0.9, 20, 0.9), CFrame.new(p + Vector3.new(0, 10, 0)), M.Wood, rgb(70, 52, 36))
		block(parent, Vector3.new(0.5, 0.5, 7), CFrame.lookAt(p + Vector3.new(0, 18.5, 0), p + Vector3.new(0, 18.5, 0) + side), M.Wood, rgb(70, 52, 36))
		for _, o in { -3, 0, 3 } do
			block(parent, Vector3.new(0.3, 0.5, 0.3), CFrame.new(p + side * o + Vector3.new(0, 19, 0)), M.SmoothPlastic, rgb(120, 140, 120))
		end
		table.insert(poles, p)
	end
	for i = 1, #poles - 1 do
		for _, o in { -3, 0, 3 } do
			local p0 = poles[i] + side * o + Vector3.new(0, 19.2, 0)
			local p1 = poles[i + 1] + side * o + Vector3.new(0, 19.2, 0)
			local mid = (p0 + p1) / 2 - Vector3.new(0, 1.2, 0)
			for _, seg in { { p0, mid }, { mid, p1 } } do
				local l = (seg[2] - seg[1]).Magnitude
				block(parent, Vector3.new(0.08, 0.08, l), CFrame.lookAt((seg[1] + seg[2]) / 2, seg[2]), M.SmoothPlastic, rgb(20, 20, 20), { CanCollide = false, CanQuery = false })
			end
		end
	end
end

local function acUnit(parent, pos)
	block(parent, Vector3.new(4, 2.6, 3), CFrame.new(pos + Vector3.new(0, 1.3, 0)), M.Metal, rgb(150, 152, 156))
	block(parent, Vector3.new(2.4, 0.2, 2.4), CFrame.new(pos + Vector3.new(0, 2.7, 0)), M.DiamondPlate, rgb(60, 62, 66))
	block(parent, Vector3.new(3.8, 0.25, 2.8), CFrame.new(pos + Vector3.new(0, 2.8, 0)), M.Snow, C.Snow, { CanCollide = false })
end

local function vent(parent, pos)
	block(parent, Vector3.new(1.4, 3, 1.4), CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, rgb(120, 122, 128), { Shape = Enum.PartType.Cylinder })
	block(parent, Vector3.new(2.2, 0.4, 2.2), CFrame.new(pos + Vector3.new(0, 3.2, 0)), M.Metal, rgb(90, 92, 98))
end

local function woodpile(parent, pos, facing)
	local cf = CFrame.lookAt(pos, pos + facing)
	for row = 0, 2 do
		for i = 0, 4 - row do
			block(parent, Vector3.new(4, 0.9, 0.9), cf * CFrame.new(0, 0.5 + row * 0.8, -1.8 + i * 0.95 + row * 0.45) * CFrame.Angles(0, math.rad(90), 0), M.Wood, vary(rgb(110, 76, 46), 0.15), { Shape = Enum.PartType.Cylinder })
		end
	end
	block(parent, Vector3.new(1.4, 2.4, 2.4), cf * CFrame.new(2.8, 0.7, 1) * CFrame.Angles(0, 0, math.rad(90)), M.Wood, rgb(90, 62, 40), { Shape = Enum.PartType.Cylinder })
	block(parent, Vector3.new(0.2, 1.6, 0.2), cf * CFrame.new(2.8, 2.2, 1) * CFrame.Angles(0, 0, math.rad(20)), M.Wood, rgb(80, 56, 36))
	block(parent, Vector3.new(0.1, 0.5, 0.7), cf * CFrame.new(2.55, 2.9, 1) * CFrame.Angles(0, 0, math.rad(20)), M.Metal, rgb(140, 140, 145))
end

local function pallet(parent, cf)
	for i = -1, 1 do
		block(parent, Vector3.new(4, 0.25, 0.8), cf * CFrame.new(0, 0.55, i * 1.5), M.WoodPlanks, rgb(150, 115, 70))
		block(parent, Vector3.new(0.6, 0.45, 4), cf * CFrame.new(i * 1.7, 0.22, 0), M.WoodPlanks, rgb(130, 98, 60))
	end
end

local function cone(parent, pos)
	block(parent, Vector3.new(1.2, 0.2, 1.2), CFrame.new(pos + Vector3.new(0, 0.1, 0)), M.SmoothPlastic, rgb(40, 40, 40))
	for i = 0, 2 do
		local w = 0.9 - i * 0.25
		block(parent, Vector3.new(w, 0.5, w), CFrame.new(pos + Vector3.new(0, 0.45 + i * 0.5, 0)), M.SmoothPlastic, i == 1 and rgb(240, 240, 240) or rgb(240, 110, 20))
	end
end

local function barrier(parent, cf)
	block(parent, Vector3.new(6, 1, 2), cf * CFrame.new(0, 0.5, 0), M.Concrete, rgb(170, 170, 165))
	block(parent, Vector3.new(6, 2, 1), cf * CFrame.new(0, 2, 0), M.Concrete, rgb(170, 170, 165))
	block(parent, Vector3.new(6.05, 0.4, 1.05), cf * CFrame.new(0, 2.4, 0), M.SmoothPlastic, rgb(230, 60, 40))
end

local function truck(parent, cf)
	breakable(block(parent, Vector3.new(7, 5, 6), cf * CFrame.new(0, 3.3, -7), M.SmoothPlastic, rgb(30, 60, 110)))
	breakable(block(parent, Vector3.new(6.6, 2, 0.2), cf * CFrame.new(0, 4.6, -10.05), M.Glass, rgb(40, 50, 60), { Transparency = 0.2 }))
	breakable(block(parent, Vector3.new(7.4, 7.5, 16), cf * CFrame.new(0, 4.6, 4), M.CorrodedMetal, rgb(200, 200, 205)))
	block(parent, Vector3.new(7, 0.3, 15.6), cf * CFrame.new(0, 8.5, 4), M.Snow, C.Snow, { CanCollide = false })
	for _, z in { -7, 1, 8 } do
		for _, x in { -3.3, 3.3 } do
			block(parent, Vector3.new(1.2, 3, 3), cf * CFrame.new(x, 1.5, z), M.SmoothPlastic, rgb(20, 20, 22), { Shape = Enum.PartType.Cylinder })
		end
	end
	local p = cf.Position
	zone(p.X, p.Z, 10, 24)
end

local function bench(parent, cf)
	block(parent, Vector3.new(6, 0.4, 1.8), cf * CFrame.new(0, 1.6, 0), M.WoodPlanks, rgb(110, 76, 46))
	block(parent, Vector3.new(6, 1.6, 0.3), cf * CFrame.new(0, 2.6, 0.8), M.WoodPlanks, rgb(110, 76, 46))
	for _, x in { -2.6, 2.6 } do
		block(parent, Vector3.new(0.3, 1.6, 1.6), cf * CFrame.new(x, 0.8, 0), M.Metal, C.DarkMetal)
	end
	block(parent, Vector3.new(5.6, 0.2, 1.6), cf * CFrame.new(0, 1.9, 0), M.Snow, C.Snow, { CanCollide = false })
end

local function phoneBooth(parent, cf)
	breakable(block(parent, Vector3.new(3.5, 8, 3.5), cf * CFrame.new(0, 4, 0), M.Glass, rgb(160, 30, 30), { Transparency = 0.3 }))
	block(parent, Vector3.new(3.7, 0.6, 3.7), cf * CFrame.new(0, 8.3, 0), M.SmoothPlastic, rgb(150, 20, 20))
	local lamp = block(parent, Vector3.new(2.4, 0.5, 0.2), cf * CFrame.new(0, 7.7, -1.8), M.Neon, rgb(255, 245, 220))
	light(lamp, { Range = 10, Brightness = 1, Color = rgb(255, 240, 210) })
	CollectionService:AddTag(lamp, "Flicker")
end

local function generator(parent, cf)
	block(parent, Vector3.new(6, 4, 3.5), cf * CFrame.new(0, 2, 0), M.Metal, rgb(200, 160, 30))
	block(parent, Vector3.new(6.2, 0.5, 3.7), cf * CFrame.new(0, 4.2, 0), M.Metal, C.DarkMetal)
	block(parent, Vector3.new(0.6, 3, 0.6), cf * CFrame.new(2.3, 5.5, 1), M.Metal, rgb(60, 60, 60), { Shape = Enum.PartType.Cylinder })
	local led = block(parent, Vector3.new(0.3, 0.3, 0.1), cf * CFrame.new(-2, 3, -1.8), M.Neon, rgb(60, 255, 90))
	light(led, { Range = 4, Brightness = 1, Color = rgb(60, 255, 90) })
	sign(parent, cf * CFrame.new(0.6, 2.4, -1.8), Vector3.new(2.6, 1.4, 0.05), "⚡ DANGER", rgb(20, 20, 20), rgb(240, 200, 30))
	block(parent, Vector3.new(6, 0.25, 3.3), cf * CFrame.new(0, 4.5, 0), M.Snow, C.Snow, { CanCollide = false })
	local p = cf.Position
	zone(p.X, p.Z, 8, 6)
end

local function bush(parent, pos, size)
	block(parent, Vector3.one * size, CFrame.new(pos + Vector3.new(0, size * 0.25, 0)), M.Grass, vary(rgb(40, 70, 44), 0.2), { Shape = Enum.PartType.Ball })
	block(parent, Vector3.one * size * 0.7, CFrame.new(pos + Vector3.new(size * 0.35, size * 0.1, size * 0.2)), M.Grass, vary(rgb(34, 60, 40), 0.2), { Shape = Enum.PartType.Ball })
	block(parent, Vector3.new(size * 0.8, 0.2, size * 0.8), CFrame.new(pos + Vector3.new(0, size * 0.72, 0)), M.Snow, C.Snow, { CanCollide = false })
end

local function buildDetails(env, props)
	-- Power lines along the main roads
	powerLine(props, Vector3.new(-9, 0, 64), Vector3.new(-9, 0, 172), 27)
	powerLine(props, Vector3.new(70, 0, -9), Vector3.new(172, 0, -9), 34)
	powerLine(props, Vector3.new(-172, 0, 9), Vector3.new(-70, 0, 9), 34)

	-- Rooftops: AC units, vents, satellite dish, antenna
	local labRoof = 15 + 0.4 + 1.3
	for _, p in { Vector3.new(-30, labRoof, -20), Vector3.new(-12, labRoof, 22), Vector3.new(25, labRoof, -8), Vector3.new(34, labRoof, 20) } do
		acUnit(props, p)
	end
	for _, p in { Vector3.new(-38, labRoof, 6), Vector3.new(0, labRoof, -26), Vector3.new(14, labRoof, 26), Vector3.new(38, labRoof, -28) } do
		vent(props, p)
	end
	local dish = Vector3.new(-20, labRoof, -4)
	block(props, Vector3.new(1, 5, 1), CFrame.new(dish + Vector3.new(0, 2.5, 0)), M.Metal, C.DarkMetal)
	block(props, Vector3.new(0.6, 8, 8), CFrame.new(dish + Vector3.new(0, 6, 0)) * CFrame.Angles(0, math.rad(40), math.rad(55)), M.Metal, rgb(210, 212, 216), { Shape = Enum.PartType.Cylinder })
	local ant = Vector3.new(30, labRoof, 4)
	block(props, Vector3.new(0.5, 26, 0.5), CFrame.new(ant + Vector3.new(0, 13, 0)), M.Metal, rgb(180, 50, 40))
	local blink = block(props, Vector3.new(0.9, 0.9, 0.9), CFrame.new(ant + Vector3.new(0, 26.4, 0)), M.Neon, rgb(255, 30, 30), { Shape = Enum.PartType.Ball })
	light(blink, { Range = 20, Brightness = 2, Color = rgb(255, 40, 40) })
	CollectionService:AddTag(blink, "Flicker")
	for _, p in { Vector3.new(105, 16 + 0.4 + 1.3, -130), Vector3.new(135, 17.7, -105) } do
		acUnit(props, p)
	end
	acUnit(props, Vector3.new(128, 11 + 0.4 + 1.3, 93))
	vent(props, Vector3.new(106, 12.7, 95))

	-- Lab exterior: big pipes + generators
	for _, y in { 3, 5 } do
		block(props, Vector3.new(60, 1.2, 1.2), CFrame.new(0, y, -36.4), M.Metal, rgb(110, 80, 50), { Shape = Enum.PartType.Cylinder })
	end
	generator(props, CFrame.new(-50, 0, -20) * CFrame.Angles(0, math.rad(90), 0))
	generator(props, CFrame.new(50, 0, 22) * CFrame.Angles(0, math.rad(-90), 0))

	-- Blood trail dragged out of the lab's front door
	for i = 0, 14 do
		local p = Vector3.new(math.sin(i * 0.5) * 2, 0.23, 37 + i * 1.6)
		block(props, Vector3.new(rng:NextNumber(0.8, 1.6), 0.05, rng:NextNumber(1, 1.8)), CFrame.new(p) * CFrame.Angles(0, rng:NextNumber() * 0.6, 0), M.SmoothPlastic, C.Blood, { CanCollide = false, CanQuery = false })
	end

	-- Cabin woodpiles
	for _, c in { Vector3.new(-125, 0, -112), Vector3.new(-42, 0, 140), Vector3.new(38, 0, -148), Vector3.new(152, 0, 30) } do
		woodpile(props, c + Vector3.new(-14, 0, -5), Vector3.new(1, 0, 0))
		bush(props, c + Vector3.new(12.5, 0, 9.5), 3)
	end

	-- Warehouse yard: pallets, cones, truck
	for i = 0, 3 do
		pallet(props, CFrame.new(98 + i * 5, 0, -143) * CFrame.Angles(0, rng:NextNumber() * 0.3, 0))
	end
	pallet(props, CFrame.new(98, 0.8, -143))
	for i = 0, 4 do
		cone(props, Vector3.new(88 + i * 4, 0.2, -90))
	end
	truck(props, CFrame.new(158, 0, -122))

	-- Gate: concrete barriers
	for i = -1, 1, 2 do
		barrier(props, CFrame.new(i * 12, 0, HALF - 30) * CFrame.Angles(0, math.rad(i * 10), 0))
	end
	for i = 0, 3 do
		cone(props, Vector3.new(-6 + i * 4, 0.2, HALF - 26))
	end

	-- Diner front: benches, phone booth, bushes
	bench(props, CFrame.new(100, 0, 114) * CFrame.Angles(0, math.pi, 0))
	bench(props, CFrame.new(136, 0, 114) * CFrame.Angles(0, math.pi, 0))
	phoneBooth(props, CFrame.new(96, 0, 118))
	for _, x in { 106, 112, 124, 130 } do
		bush(props, Vector3.new(x, 0, 113), 2.2)
	end

	-- Tire tracks in the snow along roads
	for _, t in { { 0, 90, 130 }, { 0, -90, 130 } } do
		for _, off in { -2.2, 2.2 } do
			block(env, Vector3.new(0.9, 0.04, t[3] * 0.6), CFrame.new(t[1] + off, 0.23, t[2]), M.Snow, C.SnowShade, { CanCollide = false })
		end
	end
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

function MapBuilder.SetupLighting()
	Lighting.ClockTime = 0.4
	Lighting.Brightness = 4
	-- the facility is lit by its own lamps: a blue-grey ambient lets them (and
	-- every glowing prop) shape the rooms, but is high enough that corners
	-- between lamps stay readable (players tune it with the brightness setting)
	Lighting.Ambient = rgb(110, 118, 138)
	Lighting.OutdoorAmbient = rgb(126, 136, 166)
	pcall(function()
		Lighting.LightingStyle = Enum.LightingStyle.Realistic
	end)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 1
	Lighting.GeographicLatitude = 48
	Lighting.ExposureCompensation = 0.3
	local customSky = Lighting:FindFirstChildOfClass("Sky") -- a sky set up in Studio is kept
	for _, c in Lighting:GetChildren() do
		if c:IsA("PostEffect") or c:IsA("Atmosphere") or (c:IsA("Sky") and c ~= customSky) then
			c:Destroy()
		end
	end
	make("Atmosphere", Lighting, {
		Density = 0.36,
		Offset = 0.15,
		Color = rgb(100, 112, 140),
		Decay = rgb(28, 34, 54),
		Glare = 0.25,
		Haze = 1.7,
	})
	if not customSky then
		make("Sky", Lighting, { StarCount = 5000, MoonAngularSize = 16, CelestialBodiesShown = true })
		if (Config.SkyAssetId or 0) ~= 0 then
			task.spawn(function()
				local ok, model = pcall(function()
					return game:GetService("InsertService"):LoadAsset(Config.SkyAssetId)
				end)
				local sky = ok and model and model:FindFirstChildWhichIsA("Sky", true)
				if sky then
					for _, old in Lighting:GetChildren() do
						if old:IsA("Sky") then
							old:Destroy()
						end
					end
					sky.Parent = Lighting
				else
					warn(("[Lighting] couldn't load sky %s (%s); keeping the starry sky"):format(
						tostring(Config.SkyAssetId), ok and "no Sky inside that asset" or tostring(model)))
				end
				if ok and model then
					model:Destroy()
				end
			end)
		end
	end
	-- a gentle grade (it was +0.5 contrast and saturation, which crushed the
	-- shadows and turned warm rooms into a red smear)
	make("ColorCorrectionEffect", Lighting, {
		Brightness = 0.02,
		Contrast = 0.15,
		Saturation = 0.08,
		TintColor = rgb(240, 243, 255),
	})
	make("BloomEffect", Lighting, { Intensity = 0.55, Size = 40, Threshold = 1.35 })
	make("SunRaysEffect", Lighting, { Intensity = 0.04, Spread = 0.6 })
	make("DepthOfFieldEffect", Lighting, { FarIntensity = 0.18, FocusDistance = 70, InFocusRadius = 60, NearIntensity = 0 })
end

-- Terrain: textured snow ground, frozen earth, drifts, hills, mountains, a
-- frozen pond and the lobby's mountain ledge. Built once at server start.
function MapBuilder.SetupTerrain()
	local t = terrain()
	if not t then
		return
	end
	local r = Random.new(99)
	local Mat = Enum.Material
	t:Clear()
	t:FillBlock(CFrame.new(0, -8, 0), Vector3.new(1400, 16, 1400), Mat.Snow)
	-- the facility (324 x 284) sits in the middle; snow drifts and hills ring it
	for i = 1, 48 do
		local a = i / 48 * math.pi * 2 + r:NextNumber() * 0.1
		local d = r:NextNumber(275, 320)
		local rad = r:NextNumber(24, 44)
		local pos = Vector3.new(math.cos(a) * d, -rad * 0.4, math.sin(a) * d)
		t:FillBall(pos, rad, Mat.Snow)
		if r:NextNumber() < 0.5 then
			t:FillBall(pos + Vector3.new(r:NextNumber(-10, 10), rad * 0.3, r:NextNumber(-10, 10)), rad * 0.35, Mat.Rock)
		end
	end
	-- no snow under the facility: its tiled floor sits on bare foundation
	t:FillBlock(CFrame.new(0, -8, 0), Vector3.new(340, 20, 300), Mat.Air)
	t:FillBlock(CFrame.new(0, -12, 0), Vector3.new(340, 8, 300), Mat.Rock)
	-- mountains on the horizon
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2 + r:NextNumber() * 0.2
		local d = r:NextNumber(400, 480)
		local rad = r:NextNumber(70, 115)
		local pos = Vector3.new(math.cos(a) * d, -rad * 0.2, math.sin(a) * d)
		t:FillBall(pos, rad, Mat.Rock)
		t:FillBall(pos + Vector3.new(0, rad * 0.5, 0), rad * 0.62, Mat.Snow)
	end
	-- the lobby ledge (lobby floor sits on a foundation at y=400)
	t:FillBlock(CFrame.new(0, 392, 0), Vector3.new(460, 8, 460), Mat.Snow)
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		local d = r:NextNumber(230, 300)
		local rad = r:NextNumber(50, 80)
		local pos = Vector3.new(math.cos(a) * d, 396 - rad * 0.25, math.sin(a) * d)
		t:FillBall(pos, rad, Mat.Rock)
		t:FillBall(pos + Vector3.new(0, rad * 0.45, 0), rad * 0.62, Mat.Snow)
	end
	pcall(function()
		t.WaterColor = rgb(40, 70, 90)
	end)
end

-- The lobby: a Weapon X holding hangar on a snowy mountain ledge.
-- Returns the lobby model; statues are added by Wolverine.MakeStatue.
local function surfaceText(p, face, props)
	local gui = make("SurfaceGui", p, {
		Face = face or Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
	})
	local label = make("TextLabel", gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
	})
	for k, v in props do
		label[k] = v
	end
	return gui, label
end

-- Rules board pieces (lobby, north wall): printed sheets, key caps, sticky
-- notes. Every SurfaceGui here is 40 px per stud.
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

local function boardGui(p, bgColor)
	local gui = make("SurfaceGui", p, { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0.35, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	local bg = make("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = bgColor, BorderSizePixel = 0 })
	return bg
end

local function boardText(parent, props)
	local label = make("TextLabel", parent, {
		BackgroundTransparency = 1,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	for k, v in props do
		label[k] = v
	end
	return label
end

-- A printed sheet: its own column of lines (UIListLayout, top to bottom)
local function boardSheet(parent, size, cf, paper)
	local p = block(parent, size, cf, M.SmoothPlastic, paper, { CanCollide = false })
	local bg = boardGui(p, paper)
	-- a little yellowing towards the bottom edge
	make("UIGradient", bg, { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(218, 214, 204)) })
	local col = make("Frame", bg, { Position = UDim2.fromOffset(36, 28), Size = UDim2.new(1, -72, 1, -56), BackgroundTransparency = 1 })
	make("UIListLayout", col, { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder })
	return p, bg, col
end

-- A key as printed on the paperwork, drawn like the real thing: a darker
-- skirt, a lighter dished top with a bevel highlight, the legend in the top
-- left corner. Wide keys (SHIFT) are 2u. "M1"/"M2" draw a mouse with that
-- button lit; "3x" draws a console with x3 stamped on it.
local function keycap(row, key, style)
	local function frame(parent, props)
		props.BorderSizePixel = 0
		return make("Frame", parent, props)
	end
	local function stroke(parent, color, thickness)
		make("UIStroke", parent, { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	end
	if key == "M1" or key == "M2" then
		local w, h, r = 58, 80, 14
		local bh = h * 0.42 -- the buttons' depth
		local body = frame(row, { Position = UDim2.fromOffset(26, -10), Size = UDim2.fromOffset(w, h), BackgroundColor3 = style.Top })
		make("UICorner", body, { CornerRadius = UDim.new(0, r) })
		stroke(body, style.Line, 3)
		-- the lit button: rounded only on its outer top corner, like the mouse
		local left = key == "M1"
		local x0 = left and 0 or w / 2
		local lit = frame(body, { Position = UDim2.fromOffset(x0, 0), Size = UDim2.fromOffset(w / 2, bh), BackgroundColor3 = style.Hot })
		make("UICorner", lit, { CornerRadius = UDim.new(0, r) })
		frame(body, { Position = UDim2.fromOffset(left and w / 4 or w / 2, 0), Size = UDim2.fromOffset(w / 4, bh), BackgroundColor3 = style.Hot })
		frame(body, { Position = UDim2.fromOffset(x0, bh / 2), Size = UDim2.fromOffset(w / 2, bh / 2), BackgroundColor3 = style.Hot })
		frame(body, { Position = UDim2.fromOffset(w / 2 - 1.5, 0), Size = UDim2.fromOffset(3, bh), BackgroundColor3 = style.Line })
		frame(body, { Position = UDim2.fromOffset(0, bh - 1.5), Size = UDim2.fromOffset(w, 3), BackgroundColor3 = style.Line })
		local wheel = frame(body, { Position = UDim2.fromOffset(w / 2 - 5, 10), Size = UDim2.fromOffset(10, 18), BackgroundColor3 = style.Skirt })
		make("UICorner", wheel, { CornerRadius = UDim.new(0.5, 0) })
		stroke(wheel, style.Line, 2)
		return
	end
	if key == "3x" then
		local mon = frame(row, { Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(72, 48), BackgroundColor3 = style.Skirt })
		make("UICorner", mon, { CornerRadius = UDim.new(0, 6) })
		stroke(mon, style.Line, 3)
		local screen = frame(mon, { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(60, 32), BackgroundColor3 = rgb(22, 60, 40) })
		make("TextLabel", screen, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = ">_", Font = Enum.Font.RobotoMono, TextSize = 22, TextColor3 = rgb(90, 240, 140), TextXAlignment = Enum.TextXAlignment.Left })
		frame(row, { Position = UDim2.fromOffset(36, 48), Size = UDim2.fromOffset(16, 8), BackgroundColor3 = style.Line })
		frame(row, { Position = UDim2.fromOffset(26, 56), Size = UDim2.fromOffset(36, 5), BackgroundColor3 = style.Line })
		local x3 = make("TextLabel", row, { Position = UDim2.fromOffset(64, 22), Size = UDim2.fromOffset(46, 38), Rotation = -8, BackgroundTransparency = 1, Text = "x3",
			Font = Enum.Font.PermanentMarker, TextSize = 36, TextColor3 = style.Hot })
		make("UIStroke", x3, { Color = style.Top, Thickness = 3 })
		return
	end
	local w, h = #key > 2 and 110 or 58, 58
	local skirt = frame(row, { Size = UDim2.fromOffset(w, h), BackgroundColor3 = style.Skirt })
	make("UICorner", skirt, { CornerRadius = UDim.new(0, 10) })
	stroke(skirt, style.Line, 2)
	local top = frame(skirt, { Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(w - 12, h - 16), BackgroundColor3 = style.Top })
	make("UICorner", top, { CornerRadius = UDim.new(0, 7) })
	make("UIGradient", top, { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(205, 205, 205)) }) -- the dish
	frame(top, { Position = UDim2.fromOffset(6, 1), Size = UDim2.new(1, -12, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45 })
	make("TextLabel", top, {
		Position = UDim2.fromOffset(7, 3), Size = UDim2.new(1, -14, 0, 24), BackgroundTransparency = 1, Text = key,
		Font = Enum.Font.GothamBold, TextSize = #key > 2 and 17 or 22, TextColor3 = style.Legend,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	})
end

-- One control: a key and what it does
local function keyRow(col, order, key, text, style)
	local row = make("Frame", col, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order })
	keycap(row, key, style)
	boardText(row, {
		Position = UDim2.fromOffset(128, 10),
		Size = UDim2.new(1, -128, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		Font = style.Font,
		TextSize = style.Size,
		TextColor3 = style.Ink,
	})
	return row
end

-- A yellow sticky note with a scrawl on it. It stands well proud of the
-- paper it's stuck over (a hair off it, it flickered) with a soft shadow.
local function stickyNote(parent, cf, text)
	block(parent, Vector3.new(4.25, 4.25, 0.02), cf * CFrame.new(0.14, -0.16, 0.1), M.SmoothPlastic, Color3.new(), { Transparency = 0.72, CanCollide = false, CastShadow = false })
	local p = block(parent, Vector3.new(4.25, 4.25, 0.06), cf, M.SmoothPlastic, rgb(246, 221, 90), { CanCollide = false })
	local bg = boardGui(p, rgb(246, 221, 90))
	make("UIGradient", bg, { Rotation = 90, Color = ColorSequence.new(rgb(255, 255, 255), rgb(225, 225, 225)) })
	boardText(bg, {
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(1, -28, 1, -28),
		Text = text,
		Font = Enum.Font.PermanentMarker,
		TextScaled = true,
		TextColor3 = rgb(32, 36, 44),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	return p
end

-- Three claw gashes ripped through a steel wall. Each is a tapered, slightly
-- curved tear: a dark void with a red glow deep inside, molten lips glowing
-- white-hot in the middle and cooling to red at the points, torn metal
-- curling out along both edges, soot round it, molten drips off the bottom
-- and sparks falling out of it. origin faces into the room (-Z out).
local function clawGouge(parent, origin, length, tilt)
	local HOT, WARM, COOL = rgb(255, 236, 170), rgb(255, 140, 40), rgb(210, 40, 16)
	local N = 12
	local soot = block(parent, Vector3.new(10, length + 5, 0.05), origin * CFrame.Angles(0, 0, math.rad(tilt)) * CFrame.new(0, 0, 0.22), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false })
	local sg = make("SurfaceGui", soot, { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 20 })
	for i = -1, 1 do
		local len = length * (i == 0 and 1 or 0.86)
		local base = origin * CFrame.Angles(0, 0, math.rad(tilt)) * CFrame.new(i * 2.5, i == 0 and 0.6 or 0, 0)
		local function at(t) -- the gash's centre line, bottom (t = 0) to top, bowed like a swipe
			return Vector3.new(1.1 * 4 * t * (1 - t), (t - 0.5) * len, 0)
		end
		for k = 0, N - 1 do
			local t0, t1 = k / N, (k + 1) / N
			local p0, p1 = at(t0), at(t1)
			local seg = p1 - p0
			local u = math.sin(math.pi * (t0 + t1) / 2) -- 0 at the points, 1 in the middle
			local w = 0.25 + 1.05 * u ^ 0.7
			local cf = base * CFrame.new((p0 + p1) / 2) * CFrame.Angles(0, 0, -math.atan2(seg.X, seg.Y))
			local sl = seg.Magnitude + 0.05
			block(parent, Vector3.new(w, sl, 0.34), cf * CFrame.new(0, 0, -0.02), M.Slate, rgb(8, 6, 6)) -- the void
			block(parent, Vector3.new(w * 0.28, sl, 0.02), cf * CFrame.new(0, 0, -0.2), M.Neon, rgb(150, 20, 10), { CanCollide = false }) -- glow deep inside
			local lip = u > 0.55 and HOT:Lerp(WARM, (1 - u) / 0.45) or WARM:Lerp(COOL, 1 - u / 0.55)
			-- every other segment's lips stand a hair prouder, so the overlap
			-- where two segments of different heat meet never flickers
			local zo = k % 2 == 0 and 0 or 0.015
			for _, s in { -1, 1 } do
				block(parent, Vector3.new(0.15, sl + 0.03, 0.4), cf * CFrame.new(s * (w / 2 + 0.03), 0, -0.04 - zo), M.Neon, lip, { CanCollide = false })
				-- torn steel curling out of the cut
				if (k + (s > 0 and 1 or 0)) % 2 == 0 and k > 0 and k < N - 1 then
					local flap = rng:NextNumber(0.5, 0.9)
					make("WedgePart", parent, {
						Size = Vector3.new(0.5, flap, 0.08), Material = M.Metal, Color = rgb(96, 98, 104), CanCollide = false,
						CFrame = cf * CFrame.new(s * (w / 2 + 0.28), rng:NextNumber(-0.3, 0.3), -0.3) * CFrame.Angles(math.rad(-rng:NextNumber(30, 55)), 0, math.rad(s * rng:NextNumber(25, 50))),
					})
				end
			end
			if k % 3 == 1 then -- soot blotches along it
				local sx, sy = (i * 2.5 + (p0.X + p1.X) / 2 + 5) * 20, ((length + 5) / 2 - (p0.Y + p1.Y) / 2 - (i == 0 and 0.6 or 0)) * 20
				local blot = make("Frame", sg, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(sx, sy), Size = UDim2.fromOffset(w * 20 + 60, len / N * 3 * 20),
					BackgroundColor3 = rgb(18, 14, 12), BackgroundTransparency = 0.72, BorderSizePixel = 0 })
				make("UICorner", blot, { CornerRadius = UDim.new(0.5, 0) })
			end
		end
		-- molten drips off the bottom point
		local tip = base * CFrame.new(at(0))
		block(parent, Vector3.new(0.09, 0.9, 0.09), tip * CFrame.new(0.05, -0.5, -0.2), M.Neon, WARM, { CanCollide = false })
		block(parent, Vector3.new(0.2, 0.26, 0.2), tip * CFrame.new(0.05, -1.02, -0.2), M.Neon, WARM, { Shape = Enum.PartType.Ball, CanCollide = false })
		-- sparks falling out of the cut
		local src = block(parent, Vector3.new(1, len * 0.8, 0.1), base * CFrame.new(0.6, 0, -0.3), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		make("ParticleEmitter", src, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Shape = Enum.ParticleEmitterShape.Box,
			Color = ColorSequence.new(rgb(255, 210, 120), rgb(255, 80, 20)), LightEmission = 1, LightInfluence = 0,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.6, 1.2), Rate = 4, Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(40, 40),
			Acceleration = Vector3.new(0, -18, 0), EmissionDirection = Enum.NormalId.Front,
		})
	end
	local glow = block(parent, Vector3.new(1, 1, 1), origin * CFrame.new(0, 0, -1.2), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false })
	light(glow, { Range = 18, Brightness = 2.4, Color = rgb(255, 120, 40) })
end

-- Lobby fittings. Every part of a light fitting is CastShadow = false: with
-- shadows on, a lamp's own bulb or shade in front of its light throws a
-- shadow over the very floor the lamp is meant to light.
local function fitting(parent, size, cf, material, color, extra)
	local p = block(parent, size, cf, material, color, extra)
	p.CastShadow = false
	return p
end

-- Yellow/black hazard stripes painted on one face of a part.
local function hazardStripes(p, face)
	local gui = make("SurfaceGui", p, { Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40 })
	local f = make("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
	local keys = {}
	for i = 0, 9 do
		local col = i % 2 == 0 and rgb(232, 184, 40) or rgb(17, 17, 17)
		table.insert(keys, ColorSequenceKeypoint.new(i == 0 and 0 or i / 10 + 0.002, col))
		table.insert(keys, ColorSequenceKeypoint.new((i + 1) / 10, col))
	end
	make("UIGradient", f, { Rotation = 60, Color = ColorSequence.new(keys) })
end

-- Industrial high-bay lamp hung from the roof at `top`, its lens `drop` studs
-- below: a finned driver, a stepped reflector and a glowing lens. One strong
-- shadowed spot lights the floor and a soft fill lights the walls and roof.
local HIGH_BAY = rgb(255, 232, 200)
local function highBay(parent, top, drop)
	local lens = top - Vector3.new(0, drop, 0)
	local up = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder standing upright
	local rod = drop - 1.9
	fitting(parent, Vector3.new(0.18, rod, 0.18), CFrame.new(top - Vector3.new(0, rod / 2, 0)), M.Metal, rgb(28, 28, 30))
	fitting(parent, Vector3.new(0.8, 1.6, 1.6), CFrame.new(lens + Vector3.new(0, 1.45, 0)) * up, M.Metal, rgb(46, 48, 54), { Shape = Enum.PartType.Cylinder })
	for k = 0, 3 do -- cooling fins
		fitting(parent, Vector3.new(2, 0.62, 0.1), CFrame.new(lens + Vector3.new(0, 1.45, 0)) * CFrame.Angles(0, math.rad(k * 45), 0), M.Metal, rgb(62, 64, 70))
	end
	for _, r in { { 2.1, 0.42, 0.86 }, { 2.9, 0.38, 0.47 }, { 3.7, 0.3, 0.13 } } do -- reflector
		fitting(parent, Vector3.new(r[2], r[1], r[1]), CFrame.new(lens + Vector3.new(0, r[3], 0)) * up, M.Metal, rgb(84, 88, 96), { Shape = Enum.PartType.Cylinder, Reflectance = 0.1 })
	end
	fitting(parent, Vector3.new(0.14, 3.9, 3.9), CFrame.new(lens + Vector3.new(0, -0.02, 0)) * up, M.Metal, rgb(34, 35, 40), { Shape = Enum.PartType.Cylinder })
	fitting(parent, Vector3.new(0.08, 3.3, 3.3), CFrame.new(lens + Vector3.new(0, -0.07, 0)) * up, M.Neon, HIGH_BAY, { Shape = Enum.PartType.Cylinder })
	-- the light itself sits just under the lens, so nothing of the fitting is in its way
	local emit = fitting(parent, Vector3.new(0.4, 0.2, 0.4), CFrame.new(lens - Vector3.new(0, 0.3, 0)), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	make("SpotLight", emit, { Face = Enum.NormalId.Bottom, Range = 60, Angle = 120, Brightness = 3.4, Color = HIGH_BAY, Shadows = true })
	light(emit, { Range = 34, Brightness = 0.7, Color = HIGH_BAY })
end

-- Caged bulkhead lamp on a wall or column: cf sits on the surface, facing
-- out. Back plate, conduit up to a junction box, a housing, a glowing glass
-- dome, a guard ring and the cage over it.
local function cagedLamp(parent, cf, color, flicker)
	local dark, steel = rgb(30, 31, 35), rgb(56, 58, 64)
	local out = CFrame.Angles(0, math.rad(90), 0) -- a cylinder pointing out of the wall
	fitting(parent, Vector3.new(1.3, 1.8, 0.16), cf * CFrame.new(0, 0, -0.08), M.Metal, steel)
	for _, y in { -0.7, 0.7 } do
		fitting(parent, Vector3.new(0.08, 0.2, 0.2), cf * CFrame.new(0, y, -0.2) * out, M.Metal, rgb(130, 132, 138), { Shape = Enum.PartType.Cylinder })
	end
	fitting(parent, Vector3.new(0.22, 1.5, 0.22), cf * CFrame.new(0, 1.65, -0.13), M.Metal, rgb(74, 76, 82))
	fitting(parent, Vector3.new(0.7, 0.55, 0.4), cf * CFrame.new(0, 2.6, -0.2), M.Metal, steel)
	fitting(parent, Vector3.new(0.48, 1.24, 1.24), cf * CFrame.new(0, 0, -0.4) * out, M.Metal, dark, { Shape = Enum.PartType.Cylinder })
	local lens = fitting(parent, Vector3.new(1, 1, 1), cf * CFrame.new(0, 0, -0.64), M.Neon, color, { Shape = Enum.PartType.Ball })
	fitting(parent, Vector3.new(0.12, 1.36, 1.36), cf * CFrame.new(0, 0, -0.66) * out, M.Metal, dark, { Shape = Enum.PartType.Cylinder })
	fitting(parent, Vector3.new(0.09, 1.2, 0.09), cf * CFrame.new(0, 0, -1.13), M.Metal, dark)
	fitting(parent, Vector3.new(1.2, 0.09, 0.09), cf * CFrame.new(0, 0, -1.13), M.Metal, dark)
	for _, a in { 45, -45 } do -- diagonal cage bars back to the ring
		fitting(parent, Vector3.new(0.07, 0.07, 0.62), cf * CFrame.Angles(0, 0, math.rad(a)) * CFrame.new(0, 0.5, -0.9) * CFrame.Angles(math.rad(-40), 0, 0), M.Metal, dark)
		fitting(parent, Vector3.new(0.07, 0.07, 0.62), cf * CFrame.Angles(0, 0, math.rad(a + 180)) * CFrame.new(0, 0.5, -0.9) * CFrame.Angles(math.rad(-40), 0, 0), M.Metal, dark)
	end
	light(lens, { Range = 20, Brightness = 1, Color = color })
	if flicker then
		CollectionService:AddTag(lens, "Flicker")
	end
end

-- A little theatre stage light: a can on a yoke with a glowing lens and
-- barn doors, hung from `top` and aimed at `target`, with a soft shaft of
-- light showing in the air. `range`/`brightness` default to a display case.
local function stageLight(parent, top, target, color, range, brightness)
	local at = top - Vector3.new(0, 0.55, 0)
	local cf = CFrame.lookAt(at, target)
	local dark = rgb(26, 26, 30)
	local along = CFrame.Angles(0, math.rad(90), 0) -- a cylinder pointing where the light points
	fitting(parent, Vector3.new(0.08, 0.5, 0.08), CFrame.new(top - Vector3.new(0, 0.25, 0)), M.Metal, dark) -- stem
	fitting(parent, Vector3.new(0.9, 0.06, 0.28), cf * CFrame.new(0, 0.4, 0.05), M.Metal, dark) -- yoke
	for _, x in { -0.43, 0.43 } do
		fitting(parent, Vector3.new(0.06, 0.46, 0.28), cf * CFrame.new(x, 0.18, 0.05), M.Metal, dark)
	end
	fitting(parent, Vector3.new(0.85, 0.7, 0.7), cf * CFrame.new(0, 0, 0.12) * along, M.Metal, rgb(40, 40, 46), { Shape = Enum.PartType.Cylinder }) -- can
	fitting(parent, Vector3.new(0.12, 0.82, 0.82), cf * CFrame.new(0, 0, -0.34) * along, M.Metal, dark, { Shape = Enum.PartType.Cylinder }) -- rim
	fitting(parent, Vector3.new(0.04, 0.56, 0.56), cf * CFrame.new(0, 0, -0.41) * along, M.Neon, color, { Shape = Enum.PartType.Cylinder }) -- lens
	for _, s in { -1, 1 } do -- barn doors, swung open
		fitting(parent, Vector3.new(0.72, 0.03, 0.34), cf * CFrame.new(0, s * 0.42, -0.52) * CFrame.Angles(math.rad(s * 38), 0, 0), M.Metal, dark)
	end
	local emit = fitting(parent, Vector3.new(0.2, 0.2, 0.2), cf * CFrame.new(0, 0, -0.46), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	make("SpotLight", emit, { Face = Enum.NormalId.Front, Range = range or 10, Angle = 48, Brightness = brightness or 4.5, Color = color })
	local a0 = make("Attachment", emit, {})
	local a1 = make("Attachment", emit, { Position = Vector3.new(0, 0, -(target - emit.Position).Magnitude) })
	make("Beam", emit, {
		Attachment0 = a0, Attachment1 = a1, FaceCamera = true, Segments = 1,
		Width0 = 0.45, Width1 = 2.1, LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new(color),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.7, 0.85), NumberSequenceKeypoint.new(1, 1) }),
	})
end

-- Steel I-beam column standing against a wall: cf at its foot on the wall
-- face, facing into the room. Anchor-bolted base plate, a hazard-striped
-- foot and stiffener plates up the web.
local function ibeam(parent, cf, height)
	local steel, web = rgb(60, 64, 72), rgb(42, 45, 52)
	block(parent, Vector3.new(0.34, height, 1.1), cf * CFrame.new(0, height / 2, -0.55), M.Metal, web)
	block(parent, Vector3.new(1.6, height, 0.26), cf * CFrame.new(0, height / 2, -1.23), M.Metal, steel)
	block(parent, Vector3.new(1.6, height, 0.2), cf * CFrame.new(0, height / 2, -0.1), M.Metal, steel)
	block(parent, Vector3.new(2.4, 0.3, 2.1), cf * CFrame.new(0, 0.15, -0.9), M.Metal, web)
	for _, x in { -0.85, 0.85 } do
		block(parent, Vector3.new(0.34, 0.24, 0.24), cf * CFrame.new(x, 0.42, -1.65) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, rgb(130, 132, 138), { Shape = Enum.PartType.Cylinder })
	end
	local collar = block(parent, Vector3.new(1.64, 2.4, 0.04), cf * CFrame.new(0, 1.6, -1.38), M.SmoothPlastic, C.Hazard, { CanCollide = false })
	hazardStripes(collar, Enum.NormalId.Front)
	for y = 5, height - 3, 6 do
		block(parent, Vector3.new(1.2, 0.2, 1), cf * CFrame.new(0, y, -0.66), M.Metal, steel)
	end
end

-- A drinks or snacks machine standing at cf (facing -Z, back on the wall):
-- a lit glass front with four shelves of stock, a keypad column with a
-- display and coin slots, a delivery flap, a glowing brand header and the
-- brand down both sides.
local VENDING = {
	Cola = {
		Name = "BERSERKER COLA", Body = rgb(168, 22, 30), Glow = rgb(255, 205, 70),
		Rows = { "can", "can", "bottle", "bottle" },
		Stock = { rgb(200, 20, 30), rgb(225, 228, 234), rgb(255, 150, 20), rgb(36, 36, 40) },
	},
	Snacks = {
		Name = "SNIKT SNACKS", Body = rgb(22, 64, 150), Glow = rgb(110, 210, 255),
		Rows = { "chips", "candy", "chips", "candy" },
		Stock = { rgb(250, 200, 30), rgb(220, 50, 40), rgb(60, 170, 70), rgb(150, 70, 200), rgb(250, 130, 30) },
	},
}
local function vendingMachine(parent, cf, kind)
	local st = VENDING[kind]
	local dark, chrome = rgb(22, 22, 26), rgb(170, 174, 182)
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	block(parent, Vector3.new(3.2, 0.2, 2.4), at(0, 0.1, 0.1), M.Metal, dark)
	local cab = block(parent, Vector3.new(3.4, 6.2, 2.3), at(0, 3.3, 0.15), M.Metal, st.Body)
	block(parent, Vector3.new(3.52, 0.16, 2.72), at(0, 6.48, 0), M.Metal, dark)
	-- the front frame: header, base panel, a stile and the keypad column
	local header = block(parent, Vector3.new(3.4, 1, 0.3), at(0, 5.9, -1.15), M.SmoothPlastic, st.Body)
	local hg = make("SurfaceGui", header, { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 60, LightInfluence = 0 })
	local hbg = make("Frame", hg, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
	make("UIGradient", hbg, { Rotation = 90, Color = ColorSequence.new(st.Glow, st.Body) })
	local ht = make("TextLabel", hbg, { Position = UDim2.fromScale(0.04, 0.12), Size = UDim2.fromScale(0.92, 0.76), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = st.Name })
	make("UIStroke", ht, { Thickness = 3 })
	block(parent, Vector3.new(3.4, 1.4, 0.3), at(0, 0.9, -1.15), M.Metal, st.Body)
	block(parent, Vector3.new(2, 0.62, 0.04), at(-0.3, 0.9, -1.31), M.SmoothPlastic, rgb(8, 8, 10))
	block(parent, Vector3.new(1.9, 0.5, 0.03), at(-0.3, 0.92, -1.335), M.SmoothPlastic, rgb(46, 50, 58))
	block(parent, Vector3.new(0.25, 3.8, 0.3), at(-1.575, 3.5, -1.15), M.Metal, st.Body)
	block(parent, Vector3.new(1, 3.8, 0.3), at(1.2, 3.5, -1.15), M.Metal, st.Body:Lerp(dark, 0.45))
	for _, x in { -1.45, 0.7 } do -- chrome edging round the glass
		block(parent, Vector3.new(0.06, 3.8, 0.06), at(x, 3.5, -1.3), M.Metal, chrome, { Reflectance = 0.3 })
	end
	-- the lit stock behind the glass
	local back = block(parent, Vector3.new(2.15, 3.8, 0.04), at(-0.375, 3.5, -1.02), M.SmoothPlastic, rgb(226, 230, 236))
	make("SurfaceLight", back, { Face = Enum.NormalId.Front, Range = 7, Angle = 150, Brightness = 1.3, Color = rgb(235, 242, 255) })
	for k, y in { 1.75, 2.65, 3.55, 4.45 } do
		block(parent, Vector3.new(2.15, 0.06, 0.24), at(-0.375, y, -1.12), M.Metal, chrome)
		block(parent, Vector3.new(2.15, 0.12, 0.03), at(-0.375, y - 0.03, -1.24), M.SmoothPlastic, rgb(250, 220, 90))
		for i, x in { -1.2, -0.65, -0.1, 0.45 } do
			local col = st.Stock[(k + i) % #st.Stock + 1]
			local row = st.Rows[k]
			if row == "can" then
				block(parent, Vector3.new(0.56, 0.34, 0.34), at(x, y + 0.31, -1.12) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, col, { Shape = Enum.PartType.Cylinder, Reflectance = 0.15 })
			elseif row == "bottle" then
				block(parent, Vector3.new(0.62, 0.3, 0.3), at(x, y + 0.34, -1.12) * CFrame.Angles(0, 0, math.rad(90)), M.Glass, col, { Shape = Enum.PartType.Cylinder, Transparency = 0.2 })
				block(parent, Vector3.new(0.16, 0.14, 0.14), at(x, y + 0.72, -1.12) * CFrame.Angles(0, 0, math.rad(90)), M.SmoothPlastic, rgb(240, 240, 240), { Shape = Enum.PartType.Cylinder })
			elseif row == "chips" then
				block(parent, Vector3.new(0.44, 0.66, 0.16), at(x, y + 0.36, -1.12) * CFrame.Angles(math.rad(-6), 0, 0), M.SmoothPlastic, col)
			else
				block(parent, Vector3.new(0.46, 0.24, 0.14), at(x, y + 0.15, -1.12), M.SmoothPlastic, col)
				block(parent, Vector3.new(0.46, 0.24, 0.14), at(x, y + 0.39, -1.12), M.SmoothPlastic, col:Lerp(Color3.new(1, 1, 1), 0.2))
			end
		end
	end
	block(parent, Vector3.new(2.15, 3.8, 0.05), at(-0.375, 3.5, -1.29), M.Glass, rgb(200, 220, 235), { Transparency = 0.78, Reflectance = 0.15 })
	-- keypad column: display, keys, coin and note slots, coin return
	block(parent, Vector3.new(0.78, 0.34, 0.04), at(1.2, 5, -1.32), M.Neon, rgb(60, 220, 140))
	local keys = block(parent, Vector3.new(0.74, 1, 0.04), at(1.2, 4.1, -1.32), M.SmoothPlastic, rgb(18, 18, 22))
	local kg = make("SurfaceGui", keys, { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 100 })
	for r = 0, 3 do
		for c = 0, 2 do
			local key = make("Frame", kg, { Position = UDim2.fromScale(0.1 + c * 0.28, 0.06 + r * 0.235), Size = UDim2.fromScale(0.24, 0.19), BackgroundColor3 = rgb(200, 204, 212), BorderSizePixel = 0 })
			make("UICorner", key, { CornerRadius = UDim.new(0.2, 0) })
		end
	end
	block(parent, Vector3.new(0.1, 0.36, 0.05), at(0.95, 3.3, -1.32), M.Metal, chrome, { Reflectance = 0.3 })
	block(parent, Vector3.new(0.46, 0.1, 0.05), at(1.3, 3.3, -1.32), M.SmoothPlastic, rgb(10, 10, 12))
	block(parent, Vector3.new(0.44, 0.36, 0.06), at(1.2, 2.2, -1.33), M.Metal, rgb(12, 12, 14))
	-- the brand down both sides
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local g = make("SurfaceGui", cab, { Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40 })
		make("Frame", g, { Position = UDim2.fromScale(0.1, 0), Size = UDim2.fromScale(0.12, 1), BackgroundColor3 = st.Glow, BorderSizePixel = 0 })
		local t = make("TextLabel", g, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.58, 0.5), Size = UDim2.fromOffset(6.2 * 40 * 0.9, 2.3 * 40 * 0.55),
			Rotation = -90, BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = st.Name,
		})
		make("UIStroke", t, { Thickness = 3 })
	end
	return cab
end
-- the facility's canteen stocks the same machines (Facility.lua)
MapBuilder.VendingMachine = vendingMachine

-- A button-tufted leather Chesterfield at cf (facing -Z, its back on +Z):
-- turned wooden feet, a deep seat with three cushions and a rolled front
-- edge, a tufted back, rolled arms and two throw pillows.
local CYL_X = CFrame.Angles(0, 0, 0) -- a cylinder already lies along X
local CYL_Z = CFrame.Angles(0, math.rad(90), 0)
local CYL_Y = CFrame.Angles(0, 0, math.rad(90))
local function couch(parent, cf, color)
	local seam, wood = color:Lerp(Color3.new(0, 0, 0), 0.35), rgb(46, 28, 18)
	for _, x in { -4.6, 4.6 } do
		for _, z in { -1.5, 1.5 } do -- turned feet
			block(parent, Vector3.new(0.7, 0.5, 0.5), cf * CFrame.new(x, 0.35, z) * CYL_Y, M.Wood, wood, { Shape = Enum.PartType.Cylinder })
			block(parent, Vector3.new(0.12, 0.66, 0.66), cf * CFrame.new(x, 0.62, z) * CYL_Y, M.Wood, wood, { Shape = Enum.PartType.Cylinder })
		end
	end
	block(parent, Vector3.new(9.6, 1.1, 3.8), cf * CFrame.new(0, 1.25, 0.1), M.Leather, color) -- base
	block(parent, Vector3.new(9.64, 0.12, 3.84), cf * CFrame.new(0, 0.74, 0.1), M.Leather, seam) -- welt
	for _, x in { -2.9, 0, 2.9 } do -- seat cushions, each with a rolled front
		block(parent, Vector3.new(2.84, 0.6, 3), cf * CFrame.new(x, 2.1, -0.15), M.Leather, vary(color, 0.05))
		block(parent, Vector3.new(2.8, 0.66, 0.66), cf * CFrame.new(x, 2.08, -1.62) * CYL_X, M.Leather, vary(color, 0.05), { Shape = Enum.PartType.Cylinder })
	end
	local back = block(parent, Vector3.new(9.6, 2.9, 0.9), cf * CFrame.new(0, 3.1, 1.55), M.Leather, color)
	for row = 0, 1 do -- tufting buttons across the back
		for k = 0, 7 - row do
			local x = -3.9 + k * 1.1 + row * 0.55
			block(parent, Vector3.new(0.16, 0.16, 0.16), cf * CFrame.new(x, 3.5 + row * 0.8, 1.08), M.Leather, seam, { Shape = Enum.PartType.Ball })
		end
	end
	block(parent, Vector3.new(9.64, 0.9, 0.9), cf * CFrame.new(0, 4.55, 1.55) * CYL_X, M.Leather, color, { Shape = Enum.PartType.Cylinder }) -- rolled top
	_ = back
	for _, x in { -5.05, 5.05 } do -- rolled arms
		block(parent, Vector3.new(0.9, 2.2, 3.8), cf * CFrame.new(x, 1.9, 0.1), M.Leather, color)
		block(parent, Vector3.new(3.86, 1.2, 1.2), cf * CFrame.new(x + (x > 0 and 0.08 or -0.08), 3.05, 0.1) * CYL_Z, M.Leather, color, { Shape = Enum.PartType.Cylinder })
		block(parent, Vector3.new(0.14, 1, 1), cf * CFrame.new(x + (x > 0 and 0.08 or -0.08), 3.05, -1.9) * CYL_Z, M.Leather, seam, { Shape = Enum.PartType.Cylinder }) -- arm face
	end
	for i, x in { -3.9, 3.9 } do -- throw pillows, leaning in the corners
		local c = i == 1 and rgb(150, 28, 32) or rgb(196, 150, 60)
		block(parent, Vector3.new(1.7, 1.5, 0.45), cf * CFrame.new(x, 3, 0.75) * CFrame.Angles(math.rad(-16), math.rad(x > 0 and -18 or 18), 0), M.Fabric, c)
	end
end

-- A lounge rug centred at pos: a deep red carpet with a gold border, a
-- diamond medallion and a white fringe along its ends.
local function loungeRug(parent, pos, w, d)
	local red, gold, dark = rgb(118, 26, 30), rgb(196, 150, 70), rgb(58, 12, 16)
	block(parent, Vector3.new(w, 0.06, d), CFrame.new(pos + Vector3.new(0, 0.03, 0)), M.Carpet, red)
	for _, band in { { 1.1, 0.5, gold }, { 1.9, 0.9, dark } } do
		local inset, bw, c = band[1], band[2], band[3]
		for _, s in { -1, 1 } do
			block(parent, Vector3.new(w - inset * 2, 0.09, bw), CFrame.new(pos + Vector3.new(0, 0.045, s * (d / 2 - inset))), M.Carpet, c)
			block(parent, Vector3.new(bw, 0.09, d - inset * 2 - bw), CFrame.new(pos + Vector3.new(s * (w / 2 - inset), 0.045, 0)), M.Carpet, c)
		end
	end
	block(parent, Vector3.new(6, 0.1, 6), CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, math.rad(45), 0), M.Carpet, gold)
	block(parent, Vector3.new(4.4, 0.12, 4.4), CFrame.new(pos + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, math.rad(45), 0), M.Carpet, dark)
	block(parent, Vector3.new(1.8, 0.14, 1.8), CFrame.new(pos + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, math.rad(45), 0), M.Carpet, red)
	for _, s in { -1, 1 } do -- fringe on the short ends
		for x = -w / 2 + 0.4, w / 2 - 0.3, 0.45 do
			block(parent, Vector3.new(0.12, 0.03, 0.55), CFrame.new(pos + Vector3.new(x, 0.015, s * (d / 2 + 0.25))), M.Fabric, rgb(226, 220, 204), { CanCollide = false })
		end
	end
end

-- A walnut coffee table at pos (long side along X): a thick top with an
-- apron, tapered legs, a shelf of magazines, and on top a tray with two
-- mugs of coffee, a stack of books and a little potted plant.
local function coffeeTable(parent, pos)
	local wood, dark = rgb(92, 58, 34), rgb(64, 40, 24)
	local cf = CFrame.new(pos)
	block(parent, Vector3.new(6.2, 0.3, 3.6), cf * CFrame.new(0, 2.05, 0), M.WoodPlanks, wood)
	block(parent, Vector3.new(5.8, 0.4, 3.2), cf * CFrame.new(0, 1.72, 0), M.Wood, dark) -- apron
	for _, x in { -2.7, 2.7 } do
		for _, z in { -1.4, 1.4 } do
			block(parent, Vector3.new(0.34, 1.7, 0.34), cf * CFrame.new(x, 0.85, z) * CFrame.Angles(math.rad(z > 0 and -4 or 4), 0, math.rad(x > 0 and 4 or -4)), M.Wood, dark)
		end
	end
	block(parent, Vector3.new(5.4, 0.16, 2.8), cf * CFrame.new(0, 0.55, 0), M.WoodPlanks, wood) -- shelf
	for k, c in { rgb(180, 40, 40), rgb(40, 90, 150), rgb(220, 200, 80) } do
		block(parent, Vector3.new(1.4, 0.06, 1.9), cf * CFrame.new(-1.2 + k * 0.25, 0.66 + k * 0.06, 0) * CFrame.Angles(0, math.rad(k * 9 - 12), 0), M.SmoothPlastic, c)
	end
	-- tray and two mugs
	local tray = cf * CFrame.new(-1.3, 2.23, 0.1) * CFrame.Angles(0, math.rad(8), 0)
	block(parent, Vector3.new(2.4, 0.06, 1.5), tray, M.Metal, rgb(170, 172, 178), { Reflectance = 0.2 })
	for _, s in { -1, 1 } do
		-- rims straddle the tray's edges (never flush with them)
		block(parent, Vector3.new(2.44, 0.16, 0.06), tray * CFrame.new(0, 0.08, s * 0.75), M.Metal, rgb(150, 152, 158))
		block(parent, Vector3.new(0.06, 0.16, 1.54), tray * CFrame.new(s * 1.21, 0.08, 0), M.Metal, rgb(150, 152, 158))
	end
	for i, c in { rgb(200, 40, 40), rgb(236, 236, 230) } do
		local mug = tray * CFrame.new(i == 1 and -0.5 or 0.55, 0.3, i == 1 and 0.1 or -0.15)
		block(parent, Vector3.new(0.5, 0.46, 0.46), mug * CYL_Y, M.SmoothPlastic, c, { Shape = Enum.PartType.Cylinder })
		block(parent, Vector3.new(0.02, 0.38, 0.38), mug * CFrame.new(0, 0.255, 0) * CYL_Y, M.SmoothPlastic, rgb(60, 34, 20), { Shape = Enum.PartType.Cylinder }) -- coffee
		block(parent, Vector3.new(0.08, 0.3, 0.2), mug * CFrame.new(0.28, 0, 0), M.SmoothPlastic, c) -- handle
	end
	-- books
	for k, c in { rgb(40, 60, 110), rgb(120, 30, 30), rgb(30, 80, 50) } do
		block(parent, Vector3.new(1.3, 0.22, 0.95), cf * CFrame.new(1.4, 2.31 + (k - 1) * 0.22, -0.2) * CFrame.Angles(0, math.rad(k * 11 - 16), 0), M.SmoothPlastic, c)
		block(parent, Vector3.new(1.22, 0.16, 0.05), cf * CFrame.new(1.4, 2.31 + (k - 1) * 0.22, -0.2) * CFrame.Angles(0, math.rad(k * 11 - 16), 0) * CFrame.new(0, 0, -0.47), M.SmoothPlastic, rgb(236, 230, 214)) -- page edges
	end
	-- a little potted plant
	local pot = cf * CFrame.new(2.4, 2.45, 1)
	block(parent, Vector3.new(0.6, 0.6, 0.6), pot * CYL_Y, M.SmoothPlastic, rgb(214, 210, 200), { Shape = Enum.PartType.Cylinder })
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		block(parent, Vector3.new(0.16, 0.7, 0.36), pot * CFrame.new(math.cos(a) * 0.12, 0.55, math.sin(a) * 0.12) * CFrame.Angles(math.cos(a) * 0.5, 0, math.sin(a) * 0.5), M.Grass, rgb(60, 130, 60))
	end
end

function MapBuilder.BuildLobby()
	local old = workspace:FindFirstChild("Lobby")
	if old then
		old:Destroy()
	end
	rng = Random.new(400)
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	local Y = 400
	local W, D, H = 120, 90, 28
	local hx, hz = W / 2, D / 2

	-- Mountain ledge + backdrop (terrain when available)
	local hasTerrain = terrain() ~= nil
	local groundY = hasTerrain and Y - 4 or Y - 0.2
	if hasTerrain then
		block(lobby, Vector3.new(W + 2, 4.4, D + 2), CFrame.new(0, Y - 2.35, 0), M.Concrete, rgb(96, 96, 100)) -- top sits 0.15 below the floor (no z-fighting)
		block(lobby, Vector3.new(W + 3, 0.6, D + 3), CFrame.new(0, Y - 4.1, 0), M.Concrete, rgb(80, 80, 84))
	else
		block(lobby, Vector3.new(420, 4, 420), CFrame.new(0, Y - 2.2, 0), M.Snow, C.Snow)
	end
	for _ = 1, 60 do
		-- keep every tree (and its branches, up to 10x its scale wide) clear of the building
		local x, z, s
		repeat
			local a = rng:NextNumber() * math.pi * 2
			local r = rng:NextNumber(80, 190)
			x, z, s = math.cos(a) * r, math.sin(a) * r, rng:NextNumber(1.3, 2.2)
			local reach = 5 * s + 3
		until math.abs(x) > hx + reach or math.abs(z) > hz + reach
		tree(lobby, Vector3.new(x, groundY, z), s, true)
	end
	for i = 1, (hasTerrain and 0 or 10) do
		local a = (i / 10) * math.pi * 2
		local r = rng:NextNumber(260, 320)
		local h = rng:NextNumber(90, 170)
		local cf = CFrame.new(math.cos(a) * r, Y + h / 2 - 30, math.sin(a) * r) * CFrame.Angles(0, -a + math.rad(45), 0)
		block(lobby, Vector3.new(150, h, 110), cf, M.Slate, vary(rgb(70, 74, 84), 0.2), { CanCollide = false })
		block(lobby, Vector3.new(80, h * 0.25, 60), cf * CFrame.new(0, h * 0.42, 0), M.Snow, C.Snow, { CanCollide = false })
	end

	-- Floor: dark concrete, hazard border, steel walkway
	-- Tiled floor (same style as the facility): dark grout under 4-stud concrete
	-- tiles in two alternating greys, with per-tile shade variation and scuffs
	block(lobby, Vector3.new(W, 0.88, D), CFrame.new(0, Y - 0.56, 0), M.SmoothPlastic, rgb(18, 19, 22))
	do
		local nx, nz = math.floor(W / 4 + 0.5), math.floor(D / 4 + 0.5)
		local sx, sz = W / nx, D / nz
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				local x, z = -hx + (i + 0.5) * sx, -hz + (j + 0.5) * sz
				local base = (i + j) % 2 == 0 and rgb(84, 87, 93) or rgb(58, 61, 67)
				local tile = block(lobby, Vector3.new(sx - 0.22, 0.12, sz - 0.22), CFrame.new(x, Y - 0.06, z), M.Concrete, vary(base, 0.1))
				if rng:NextNumber() < 0.05 then
					block(tile, Vector3.new(rng:NextNumber(0.8, 1.8), 0.02, rng:NextNumber(0.2, 0.4)), CFrame.new(x + rng:NextNumber(-1, 1), Y + 0.01, z + rng:NextNumber(-1, 1)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), M.SmoothPlastic, rgb(48, 50, 54), { Transparency = 0.35, CanCollide = false })
				end
			end
		end
	end
	for _, d in { { 0, -hz + 2, W - 2, 1.2 }, { 0, hz - 2, W - 2, 1.2 }, { -hx + 2, 0, 1.2, D - 2 }, { hx - 2, 0, 1.2, D - 2 } } do
		block(lobby, Vector3.new(d[3], 0.06, d[4]), CFrame.new(d[1], Y + 0.03, d[2]), M.SmoothPlastic, C.Hazard)
	end
	for x = -hx + 6, hx - 6, 4 do
		block(lobby, Vector3.new(0.9, 0.07, 1.25), CFrame.new(x, Y + 0.05, -hz + 2) * CFrame.Angles(0, math.rad(45), 0), M.SmoothPlastic, rgb(20, 20, 20))
		block(lobby, Vector3.new(0.9, 0.07, 1.25), CFrame.new(x, Y + 0.05, hz - 2) * CFrame.Angles(0, math.rad(45), 0), M.SmoothPlastic, rgb(20, 20, 20))
	end
	block(lobby, Vector3.new(10, 0.1, D - 10), CFrame.new(0, Y + 0.05, 0), M.DiamondPlate, rgb(80, 84, 92))

	-- X-Men logo in the floor: yellow ring broken by the X, worn paint
	local logoY = Y + 0.2
	local LR, ringW = 10, 1.7
	local yellow = rgb(232, 196, 58)
	block(lobby, Vector3.new(0.08, LR * 2 + 4, LR * 2 + 4), CFrame.new(0, logoY - 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), M.Slate, rgb(20, 20, 24), { Shape = Enum.PartType.Cylinder })
	local armW = LR * 0.36
	local function inGap(deg)
		for _, g in { 45, 225 } do
			local d = math.abs((deg - g + 180) % 360 - 180)
			if d < 15 then
				return true
			end
		end
		return false
	end
	local segs = 72
	local rMid = LR - ringW / 2
	for i = 0, segs - 1 do
		local deg = (i + 0.5) * 360 / segs
		if not inGap(deg) then
			local a0 = math.rad(deg)
			local len = 2 * math.pi * rMid / segs * 1.04
			block(lobby, Vector3.new(len, 0.06, ringW), CFrame.new(math.cos(a0) * rMid, logoY + (i % 2) * 0.008, math.sin(a0) * rMid) * CFrame.Angles(0, -a0 + math.pi / 2, 0), M.Concrete, yellow)
		end
	end
	-- the X: a thick stroke punching out through the ring gaps, and a thinner cross stroke
	block(lobby, Vector3.new(armW, 0.07, LR * 2.12), CFrame.new(0, logoY + 0.03, 0) * CFrame.Angles(0, math.rad(45), 0), M.Concrete, yellow)
	for _, sgn in { -1, 1 } do
		block(lobby, Vector3.new(armW * 0.8, 0.07, LR * 0.62), CFrame.new(sgn * LR * 0.25, logoY + 0.065, -sgn * LR * 0.25) * CFrame.Angles(0, math.rad(-45), 0), M.Concrete, yellow)
	end
	-- black cut lines separating the X from the ring
	for _, g in { 45, 225 } do
		for _, off in { -1, 1 } do
			local a0 = math.rad(g + off * 13)
			block(lobby, Vector3.new(0.35, 0.09, ringW + 0.3), CFrame.new(math.cos(a0) * rMid, logoY + 0.06, math.sin(a0) * rMid) * CFrame.Angles(0, math.pi / 2 - a0, 0), M.Slate, rgb(20, 20, 24))
		end
	end
	-- worn / scuffed paint specks
	for _ = 1, 110 do
		local r = math.sqrt(rng:NextNumber()) * LR
		local t = rng:NextNumber() * math.pi * 2
		block(lobby, Vector3.new(rng:NextNumber(0.12, 0.5), 0.1, rng:NextNumber(0.12, 0.4)),
			CFrame.new(math.cos(t) * r, logoY + 0.1 + rng:NextNumber() * 0.05, math.sin(t) * r) * CFrame.Angles(0, rng:NextNumber() * 6, 0), M.Slate, rgb(24, 22, 20), { CanCollide = false, CanQuery = false })
	end
	-- warm spotlight on the emblem
	local emblemLamp = block(lobby, Vector3.new(1.4, 0.6, 1.4), CFrame.new(0, Y + H - 2.2, 8), M.Metal, C.DarkMetal)
	make("SpotLight", emblemLamp, { Face = Enum.NormalId.Bottom, Range = 36, Angle = 45, Brightness = 2.5, Color = rgb(255, 225, 160), Shadows = true })
	make("SpawnLocation", lobby, {
		Size = Vector3.new(12, 0.2, 12),
		CFrame = CFrame.new(0, Y + 0.2, 0),
		Neutral = true,
		Duration = 0,
		Transparency = 1,
		CanCollide = false,
	})

	-- Walls: painted blockwork (the window glass is kept clear), windows in
	-- slim steel frames with nothing across the glass
	local wallStyle = { Material = M.Brick, Color = rgb(118, 120, 127), Vary = 0.05, Breakable = false, GlassTransparency = 0.86, GlassReflectance = 0.04 }
	wall(lobby, Vector3.new(-hx, 0, -hz + 0.5), Vector3.new(hx, 0, -hz + 0.5), Y, H, 1, wallStyle)
	wall(lobby, Vector3.new(-hx + 0.5, 0, -hz), Vector3.new(-hx + 0.5, 0, hz), Y, H, 1, wallStyle)
	wall(lobby, Vector3.new(hx - 0.5, 0, -hz), Vector3.new(hx - 0.5, 0, hz), Y, H, 1, wallStyle)
	local windows = {}
	for x = -45, 45, 18 do
		table.insert(windows, { At = x + hx, Width = 12, Bottom = 5, Top = 20, Glass = true })
	end
	wall(lobby, Vector3.new(-hx, 0, hz - 0.5), Vector3.new(hx, 0, hz - 0.5), Y, H, 1, wallStyle, windows)
	local southGaps = {}
	for _, w in windows do
		local x = w.At - hx
		block(lobby, Vector3.new(13, 0.4, 1.9), CFrame.new(x, Y + 4.85, hz - 0.95), M.Metal, C.DarkMetal) -- sill ledge
		block(lobby, Vector3.new(12.6, 0.45, 1.3), CFrame.new(x, Y + 20, hz - 0.5), M.Metal, C.DarkMetal) -- head
		for _, s in { -1, 1 } do
			block(lobby, Vector3.new(0.35, 15, 1.3), CFrame.new(x + s * 6.12, Y + 12.5, hz - 0.5), M.Metal, C.DarkMetal) -- jambs
		end
		table.insert(southGaps, { x + hx - 1 - 6.5, x + hx - 1 + 6.5 })
	end

	-- Wall dressing, floor to roof: a rubber kick plate, diamond-plate
	-- wainscot under a steel cap rail, the blockwork with a concrete band, a
	-- bolted steel ring beam, then corrugated cladding up to the roof. Each
	-- wall runs from `a` along t = n x up (n points into the room); `gaps` are
	-- spans the band and ring beam leave out (the windows, the notice board,
	-- the claw gouges).
	local walls = {
		South = { a = Vector3.new(-hx + 1, 0, hz - 1), n = Vector3.new(0, 0, -1), len = W - 2, band = southGaps, beam = {} },
		North = { a = Vector3.new(hx - 1, 0, -hz + 1), n = Vector3.new(0, 0, 1), len = W - 2, band = { { 7.5, 20.5 } }, beam = { { 7.5, 20.5 }, { 26.3, 103.7 } } },
		West = { a = Vector3.new(-hx + 1, 0, -hz + 1), n = Vector3.new(1, 0, 0), len = D - 2, band = {}, beam = {} },
		East = { a = Vector3.new(hx - 1, 0, hz - 1), n = Vector3.new(-1, 0, 0), len = D - 2, band = {}, beam = { { 7.6, 80.4 } } }, -- the gallery marquee takes the ring beam's place
	}
	local function onWall(w, s, y, out)
		local p = w.a + w.t * s + w.n * out + Vector3.new(0, Y + y, 0)
		return CFrame.lookAt(p, p + w.n)
	end
	local function spans(w, gaps)
		local list, s = {}, 1.3
		table.sort(gaps, function(p, q)
			return p[1] < q[1]
		end)
		for _, g in gaps do
			if g[1] > s then
				table.insert(list, { s, g[1] })
			end
			s = math.max(s, g[2])
		end
		if w.len - 1.3 > s then
			table.insert(list, { s, w.len - 1.3 })
		end
		return list
	end
	local function run(w, gaps, y, h, depth, out, material, color, inset)
		inset = inset or 0
		for _, sp in spans(w, gaps) do
			if sp[2] - sp[1] > 0.2 then
				block(lobby, Vector3.new(sp[2] - sp[1] - 2 * inset, h, depth), onWall(w, (sp[1] + sp[2]) / 2, y, out), material, color)
			end
		end
	end
	for _, w in walls do
		w.t = w.n:Cross(Vector3.yAxis)
		run(w, {}, 0.3, 0.6, 0.34, 0.17, M.Rubber, rgb(24, 24, 26))
		for s = 1.3, w.len - 1.8, 4 do
			local width = math.min(4, w.len - 1.3 - s) - 0.12
			block(lobby, Vector3.new(width, 4, 0.28), onWall(w, s + 0.06 + width / 2, 2.6, 0.14), M.DiamondPlate, vary(rgb(72, 75, 82), 0.06))
		end
		run(w, {}, 4.75, 0.3, 0.4, 0.2, M.Metal, rgb(96, 100, 108))
		run(w, w.band, 12.6, 0.8, 0.16, 0.08, M.Concrete, rgb(140, 142, 148))
		run(w, w.beam, 21.2, 1.5, 0.22, 0.62, M.Metal, rgb(56, 60, 68), 0.02) -- web: inside the flanges, not flush with them
		run(w, w.beam, 20.5, 0.2, 0.75, 0.375, M.Metal, rgb(68, 72, 80))
		run(w, w.beam, 21.9, 0.2, 0.75, 0.375, M.Metal, rgb(68, 72, 80))
		for _, sp in spans(w, w.beam) do
			for s = sp[1] + 1, sp[2] - 0.5, 4 do
				block(lobby, Vector3.new(0.14, 0.26, 0.26), onWall(w, s, 21.2, 0.8) * CFrame.Angles(0, math.rad(90), 0), M.Metal, rgb(140, 142, 148), { Shape = Enum.PartType.Cylinder })
			end
		end
		run(w, {}, 25, 6, 0.1, 0.05, M.Metal, rgb(58, 62, 70))
		for s = 1.9, w.len - 1.9, 1.25 do
			local cf = onWall(w, s, 25, 0.23)
			local onBeam = false
			for _, z in { -30, -15, 0, 15, 30 } do -- the roof I-beams land here instead
				if math.abs(w.n.Z) < 0.5 and math.abs(cf.Position.Z - z) < 0.95 then
					onBeam = true
				end
			end
			local inCorner = math.abs(cf.Position.X) > hx - 3.9 and math.abs(cf.Position.Z) > hz - 3.9 -- behind a corner column
			if not onBeam and not inCorner then
				block(lobby, Vector3.new(0.5, 6, 0.26), cf, M.Metal, rgb(74, 78, 88))
			end
		end
	end
	for _, sx in { -1, 1 } do -- corner columns
		for _, sz in { -1, 1 } do
			block(lobby, Vector3.new(2.6, H, 2.6), CFrame.new(sx * (hx - 2.3), Y + H / 2, sz * (hz - 2.3)), M.Metal, rgb(50, 53, 60))
		end
	end

	-- I-beam columns, only on bare wall (between the windows, clear of the
	-- boards, the fireplace and the machines), each with a caged wall lamp.
	-- The lamps on bare wall stretches (no column) sit straight on the wall.
	local AMBER, RED = rgb(255, 196, 110), rgb(255, 60, 40)
	local columns = {
		{ "South", 23 }, { "South", 41 }, { "South", 59 }, { "South", 77 }, { "South", 95 },
		{ "West", 14 }, { "West", 29 }, { "West", 43.5 }, { "West", 60.5 },
		{ "North", 111, true },
		{ "East", 84 },
	}
	for _, c in columns do
		local w = walls[c[1]]
		ibeam(lobby, onWall(w, c[2], 0, 0), 20.4)
		cagedLamp(lobby, onWall(w, c[2], 10.5, 1.36), c[3] and RED or AMBER, c[3])
	end
	for _, l in { { "South", 4, true }, { "South", 112.6 }, { "North", 23 }, { "North", 3.5 }, { "East", 5.8 } } do
		cagedLamp(lobby, onWall(walls[l[1]], l[2], 10.5, 0), l[3] and RED or AMBER, l[3])
	end
	-- knee braces from the walls up under the girder ends
	for _, b in { { -1, -15 }, { -1, 0 }, { -1, 15 }, { -1, 30 } } do -- (none on the east wall: the gallery marquee is there)
		local p0 = Vector3.new(b[1] * (hx - 1), Y + 22.2, b[2])
		local p1 = Vector3.new(b[1] * (hx - 4.4), Y + H - 2.75, b[2])
		local len = (p1 - p0).Magnitude
		block(lobby, Vector3.new(0.45, 0.45, len), CFrame.lookAt(p0, p1) * CFrame.new(0, 0, -len / 2), M.Metal, rgb(56, 60, 68))
	end
	for _, y in { H - 2.2, H - 3.2 } do -- pipes up high, clear of the rules board
		block(lobby, Vector3.new(W - 4, 0.8, 0.8), CFrame.new(0, Y + y, -hz + 2.2) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, math.rad(90), 0), M.Metal, rgb(110, 80, 50), { Shape = Enum.PartType.Cylinder })
	end

	-- Roof: corrugated deck on I-beam girders and purlins, with ductwork,
	-- cable trays and a sprinkler main slung underneath
	block(lobby, Vector3.new(W, 1, D), CFrame.new(0, Y + H + 0.5, 0), M.Metal, rgb(40, 42, 48))
	for z = -hz + 1.5, hz - 1.5, 1.5 do
		block(lobby, Vector3.new(W - 2, 0.35, 0.6), CFrame.new(0, Y + H - 0.175, z), M.Metal, rgb(56, 59, 66))
	end
	for x = -48, 48, 12 do
		block(lobby, Vector3.new(0.5, 0.7, D - 2), CFrame.new(x, Y + H - 0.7, 0), M.Metal, rgb(50, 53, 60))
	end
	for _, z in { -30, -15, 0, 15, 30 } do
		block(lobby, Vector3.new(W - 2, 0.24, 1.3), CFrame.new(0, Y + H - 0.47, z), M.Metal, rgb(64, 68, 76))
		block(lobby, Vector3.new(W - 2, 1.9, 0.3), CFrame.new(0, Y + H - 1.54, z), M.Metal, rgb(46, 49, 56))
		block(lobby, Vector3.new(W - 2, 0.24, 1.3), CFrame.new(0, Y + H - 2.61, z), M.Metal, rgb(64, 68, 76))
		for x = -54, 54, 9 do
			block(lobby, Vector3.new(0.16, 1.9, 1.1), CFrame.new(x, Y + H - 1.54, z), M.Metal, rgb(64, 68, 76))
		end
	end
	local DUCT, SEAM = rgb(128, 132, 138), rgb(108, 112, 118)
	for _, z in { -21.5, 21.5 } do
		local y = Y + H - 5
		block(lobby, Vector3.new(80, 2.6, 2.6), CFrame.new(0, y, z), M.Metal, DUCT, { Shape = Enum.PartType.Cylinder, Reflectance = 0.05 })
		for x = -36, 36, 8 do
			block(lobby, Vector3.new(0.3, 2.8, 2.8), CFrame.new(x, y, z), M.Metal, SEAM, { Shape = Enum.PartType.Cylinder })
		end
		for _, x in { -40, 40 } do -- elbows up into the roof
			block(lobby, Vector3.new(2.9, 2.9, 2.9), CFrame.new(x, y, z), M.Metal, SEAM, { Shape = Enum.PartType.Ball })
			block(lobby, Vector3.new(5.2, 2.6, 2.6), CFrame.new(x, y + 2.6, z) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, DUCT, { Shape = Enum.PartType.Cylinder })
		end
		for x = -32, 32, 16 do
			block(lobby, Vector3.new(0.14, 3.6, 0.14), CFrame.new(x, y + 3.1, z), M.Metal, rgb(40, 40, 44))
		end
		for _, x in { -30, -10, 10, 30 } do -- diffusers
			block(lobby, Vector3.new(2.2, 0.8, 2.2), CFrame.new(x, y - 1.5, z), M.Metal, rgb(120, 124, 130))
			block(lobby, Vector3.new(2, 0.05, 2), CFrame.new(x, y - 1.92, z), M.Metal, rgb(30, 31, 34))
		end
	end
	for _, x in { -24, 24 } do -- cable trays
		local y = Y + H - 3.2
		block(lobby, Vector3.new(1.8, 0.1, D - 2), CFrame.new(x, y, 0), M.Metal, rgb(92, 96, 104))
		for _, s in { -1, 1 } do
			block(lobby, Vector3.new(0.08, 0.45, D - 2), CFrame.new(x + s * 0.9, y + 0.2, 0), M.Metal, rgb(92, 96, 104))
		end
		for k, c in { rgb(30, 30, 32), rgb(140, 30, 26), rgb(30, 60, 120) } do
			block(lobby, Vector3.new(D - 2.4, 0.22, 0.22), CFrame.new(x - 0.56 + k * 0.28, y + 0.16, 0) * CFrame.Angles(0, math.rad(90), 0), M.Rubber, c, { Shape = Enum.PartType.Cylinder })
		end
	end
	for _, z in { -10, 10 } do -- sprinkler main
		local y = Y + H - 3.6
		block(lobby, Vector3.new(W - 4, 0.35, 0.35), CFrame.new(0, y, z), M.Metal, rgb(170, 30, 26), { Shape = Enum.PartType.Cylinder })
		for x = -52, 52, 8 do
			block(lobby, Vector3.new(0.16, 0.4, 0.16), CFrame.new(x, y - 0.35, z), M.Metal, rgb(200, 160, 60))
		end
	end

	-- Six high-bay lamps light the hall (one strong shadowed spot each, and
	-- no fitting in the way of its own light)
	for _, x in { -36, 0, 36 } do
		for _, z in { -17, 17 } do
			highBay(lobby, Vector3.new(x, Y + H - 1.05, z), 5.5)
		end
	end

	-- RULES WALL (north) -----------------------------------------------
	-- A facility notice board, not a poster: a steel plate with a stencilled
	-- banner, and the how-to-play pinned up as real paperwork (a staff memo,
	-- Subject X's file, a Sentinel pilot card) with sticky notes scrawled on.
	local rz = -hz + 1.3
	local face = CFrame.Angles(0, math.pi, 0) -- fronts face into the room
	local function onBoard(x, y, z, tilt)
		return CFrame.new(x, Y + y, rz + z) * face * CFrame.Angles(0, 0, math.rad(tilt or 0))
	end
	block(lobby, Vector3.new(76, 23.6, 0.6), onBoard(-6, 12.4, 0), M.DiamondPlate, rgb(34, 34, 38))
	local trim = rgb(58, 60, 66)
	for _, y in { 0.6, 24.2 } do
		block(lobby, Vector3.new(77.2, 0.7, 0.5), onBoard(-6, y, 0.2), M.Metal, trim)
	end
	for _, x in { -44, 32 } do
		block(lobby, Vector3.new(0.7, 24.3, 0.5), onBoard(x, 12.4, 0.2), M.Metal, trim)
		for _, y in { 0.6, 12.4, 24.2 } do -- bolt heads
			block(lobby, Vector3.new(0.35, 0.45, 0.45), onBoard(x, y, 0.5) * CFrame.Angles(0, math.rad(90), 0), M.Metal, rgb(120, 122, 128), { Shape = Enum.PartType.Cylinder })
		end
	end

	-- the banner: hazard stripes, the name stencilled in yellow, and the
	-- incident counter nobody ever gets to reset
	block(lobby, Vector3.new(72, 4, 0.2), onBoard(-6, 21.7, 0.4), M.Metal, rgb(20, 20, 22))
	local hazard = block(lobby, Vector3.new(5, 4, 0.05), onBoard(-39.5, 21.7, 0.52), M.SmoothPlastic, rgb(232, 184, 40), { CanCollide = false })
	local stripes = {}
	for i = 0, 9 do
		local col = i % 2 == 0 and rgb(232, 184, 40) or rgb(17, 17, 17)
		table.insert(stripes, ColorSequenceKeypoint.new(i == 0 and 0 or i / 10 + 0.002, col))
		table.insert(stripes, ColorSequenceKeypoint.new((i + 1) / 10, col))
	end
	make("UIGradient", boardGui(hazard, Color3.new(1, 1, 1)), { Rotation = 45, Color = ColorSequence.new(stripes) })
	local nameplate = block(lobby, Vector3.new(48, 2.8, 0.05), onBoard(-12.25, 22.2, 0.52), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false })
	surfaceText(nameplate, Enum.NormalId.Front, {
		Text = "SURVIVE THE WOLVERINE",
		FontFace = OSWALD,
		TextColor3 = rgb(232, 186, 40),
		TextTransparency = 0.06,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local strap = block(lobby, Vector3.new(48, 0.72, 0.05), onBoard(-12.25, 20.45, 0.52), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false })
	surfaceText(strap, Enum.NormalId.Front, {
		Text = "WEAPON X  ·  FACILITY 7  ·  CONTAINMENT BREACH PROTOCOL  —  READ BEFORE ENTERING",
		Font = Enum.Font.RobotoMono,
		TextColor3 = rgb(154, 154, 162),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local counter = block(lobby, Vector3.new(10.5, 3.1, 0.06), onBoard(24.15, 21.7, 0.53), M.SmoothPlastic, rgb(233, 230, 220), { CanCollide = false })
	local cbg = boardGui(counter, rgb(233, 230, 220))
	boardText(cbg, {
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -170, 1, -24),
		Text = "DAYS WITHOUT AN INCIDENT",
		FontFace = OSWALD,
		TextScaled = true,
		TextColor3 = rgb(27, 27, 27),
	})
	local digit = make("Frame", cbg, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(124, 100), BackgroundColor3 = rgb(17, 17, 17), BorderSizePixel = 0 })
	boardText(digit, {
		Size = UDim2.fromScale(1, 1),
		Text = "0",
		FontFace = OSWALD,
		TextScaled = true,
		TextColor3 = rgb(255, 51, 38),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})

	local S = Config.Sentinel
	local INK = rgb(28, 27, 25)
	local TYPE = { Skirt = rgb(62, 62, 66), Top = rgb(238, 236, 230), Legend = rgb(30, 30, 34), Line = rgb(20, 20, 22), Hot = rgb(200, 30, 30),
		Font = Enum.Font.SpecialElite, Size = 34, Ink = INK }
	local function header(col, text, color)
		boardText(col, { Size = UDim2.new(1, 0, 0, 30), Text = text, Font = Enum.Font.RobotoMono, TextSize = 24, TextColor3 = color, LayoutOrder = 1 })
	end
	local function heading(col, text, props)
		local h = boardText(col, { Size = UDim2.new(1, 0, 0, 64), Text = text, Font = Enum.Font.SpecialElite, TextSize = 58, TextColor3 = INK, LayoutOrder = 2 })
		for k, v in props or {} do
			h[k] = v
		end
		make("Frame", col, { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = h.TextColor3, BorderSizePixel = 0, LayoutOrder = 3 })
	end
	local function pin(x, y)
		block(lobby, Vector3.new(0.55, 0.55, 0.55), onBoard(x, y, 0.62), M.SmoothPlastic, rgb(194, 34, 28), { Shape = Enum.PartType.Ball, CanCollide = false })
	end

	-- 1) the staff memo: what survivors do
	local _, memo, memoCol = boardSheet(lobby, Vector3.new(21, 17.4, 0.04), onBoard(-30, 10, 0.36, -1.5), rgb(233, 227, 210))
	header(memoCol, "WEAPON X // FACILITY 7 // MEMO 0419", rgb(109, 102, 90))
	heading(memoCol, "SUBJECT X IS LOOSE.")
	keyRow(memoCol, 4, "SHIFT", "RUN. He is faster. Break his line of sight.", TYPE)
	keyRow(memoCol, 5, "E", "HIDE in anything that glows white.", TYPE)
	keyRow(memoCol, 6, "G", "FART to hide your scent. Or: Turbo Fart, Dodge, Invisibility.", TYPE)
	keyRow(memoCol, 7, "M", "MAP. Only you are on it.", TYPE)
	keyRow(memoCol, 8, "3x", "REBOOT the 3 consoles, then suit up in the Hangar.", TYPE)
	boardText(memo, {
		Position = UDim2.fromOffset(300, 600),
		Size = UDim2.fromOffset(500, 60),
		Rotation = -4,
		Text = Config.HitsToKill .. " hits = torn in half",
		Font = Enum.Font.PermanentMarker,
		TextSize = 44,
		TextColor3 = rgb(200, 21, 27),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	pin(-30, 18.3)

	-- 2) Subject X's file: what he does
	local _, file, fileCol = boardSheet(lobby, Vector3.new(21, 17.4, 0.04), onBoard(-6, 10, 0.36, 1), rgb(239, 236, 228))
	header(fileCol, "PERSONNEL FILE // SUBJECT X", rgb(109, 102, 90))
	heading(fileCol, "IF YOU ARE HIM")
	keyRow(fileCol, 4, "M1", "CLAW. Through people. Through walls.", TYPE)
	keyRow(fileCol, 5, "Q", "POUNCE from all fours.", TYPE)
	keyRow(fileCol, 6, "E", "IMPALE. Both claws in. Lift.", TYPE)
	keyRow(fileCol, 7, "R", "SNIFF. Smell every scent.", TYPE)
	keyRow(fileCol, 8, "C", "ALL FOURS. Fastest.", TYPE)
	boardText(fileCol, {
		Size = UDim2.new(0, 520, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = ("Every kill: +%d seconds.\nUnder %d%% health: RAGE."):format(Config.KillTimeBonus, Config.Rage.Threshold * 100),
		Font = Enum.Font.SpecialElite,
		TextSize = 34,
		TextColor3 = INK,
		LayoutOrder = 9,
	})
	-- his mugshot: three claw marks where a face should be
	local photo = make("Frame", file, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -40, 1, -40), Size = UDim2.fromOffset(170, 210), BackgroundColor3 = rgb(21, 21, 26), BorderSizePixel = 0 })
	make("UIStroke", photo, { Color = Color3.new(1, 1, 1), Thickness = 6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	for i = 0, 2 do
		make("Frame", photo, { Position = UDim2.fromOffset(50 + i * 30, 20), Size = UDim2.fromOffset(10, 170), Rotation = 18, BackgroundColor3 = rgb(210, 30, 30), BorderSizePixel = 0 })
	end
	local stamp = make("Frame", file, { Position = UDim2.fromOffset(420, 560), Size = UDim2.fromOffset(300, 80), Rotation = -12, BackgroundTransparency = 1 })
	make("UIStroke", stamp, { Color = rgb(200, 21, 27), Thickness = 6, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	boardText(stamp, {
		Size = UDim2.fromScale(1, 1),
		Text = "CLASSIFIED",
		FontFace = OSWALD,
		TextSize = 52,
		TextColor3 = rgb(200, 21, 27),
		TextTransparency = 0.15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	pin(-6, 18.4)

	-- 3) the Sentinel pilot card: a blueprint
	local BLUE = rgb(29, 74, 140)
	-- blueprint keys are line drawings: white lines on the blue
	local PRINT = { Skirt = rgb(38, 88, 158), Top = rgb(52, 108, 178), Legend = Color3.new(1, 1, 1), Line = Color3.new(1, 1, 1), Hot = rgb(255, 206, 60),
		Font = Enum.Font.RobotoMono, Size = 30, Ink = Color3.new(1, 1, 1) }
	local _, card, cardCol = boardSheet(lobby, Vector3.new(21, 17.4, 0.04), onBoard(18, 10, 0.36, -0.8), BLUE)
	for gx = 40, 800, 40 do
		make("Frame", card, { Position = UDim2.fromOffset(gx, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, BorderSizePixel = 0 })
	end
	for gy = 40, 680, 40 do
		make("Frame", card, { Position = UDim2.fromOffset(0, gy), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, BorderSizePixel = 0 })
	end
	cardCol.ZIndex = 2 -- the text sits over the grid
	header(cardCol, "SENTINEL MK I // PILOT CARD", rgb(185, 208, 240))
	heading(cardCol, "SUIT UP.", { FontFace = OSWALD, TextSize = 64, TextColor3 = Color3.new(1, 1, 1) })
	keyRow(cardCol, 4, "M1", "HYDRAULIC SMASH. Stuns and launches him.", PRINT)
	keyRow(cardCol, 5, "M2", ("GROUND SLAM. Hits him within %d studs."):format(S.Slam.Radius), PRINT)
	keyRow(cardCol, 6, "Q", "DEATH RAY. Melts through walls.", PRINT)
	keyRow(cardCol, 7, "E", ("INHIBITOR BLAST. Stuns him %gs."):format(S.Pulse.Stun), PRINT)
	boardText(cardCol, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = ("LINKED (%d studs) %gx\nAPART %gx · LAST SUIT 1x\nCORE BURNS OUT IN %ds"):format(S.LinkRange, S.LinkedMultiplier, S.SoloMultiplier, S.Duration),
		Font = Enum.Font.RobotoMono,
		TextSize = 30,
		LineHeight = 1.15,
		TextColor3 = Color3.new(1, 1, 1),
		LayoutOrder = 8,
	})
	for _, side in { -1, 1 } do -- taped up
		block(lobby, Vector3.new(3.5, 1, 0.03), onBoard(18 + side * 9.8, 18.5, 0.42, side * -30), M.SmoothPlastic, rgb(228, 218, 184), { Transparency = 0.3, CanCollide = false })
	end

	-- scrawled sticky notes, stuck where there was room
	stickyNote(lobby, onBoard(-18, 11.5, 0.6, 6), "he can SMELL you")
	stickyNote(lobby, onBoard(6, 13, 0.6, -7), "he heals.\nyou don't.")
	stickyNote(lobby, onBoard(26.6, 3.8, 0.6, 5), "STAY TOGETHER!!")

	-- three work lamps hanging from the ceiling, aimed at the paperwork
	for _, x in { -30, -6, 18 } do
		local headPos = Vector3.new(x, Y + 25.2, rz + 4.2)
		block(lobby, Vector3.new(0.2, H - 25.6, 0.2), CFrame.new(x, Y + (H + 25.6) / 2, rz + 4.2), M.Metal, rgb(40, 40, 44))
		local lamp = block(lobby, Vector3.new(1.4, 0.9, 1.6), CFrame.lookAt(headPos, Vector3.new(x, Y + 11, rz)), M.Metal, rgb(36, 36, 40))
		block(lobby, Vector3.new(1.1, 0.6, 0.05), lamp.CFrame * CFrame.new(0, 0, -0.81), M.Neon, rgb(255, 236, 200))
		make("SpotLight", lamp, { Face = Enum.NormalId.Front, Range = 22, Angle = 62, Brightness = 2.6, Color = rgb(255, 236, 210) })
	end
	-- He clawed through the wall next to the board
	clawGouge(lobby, CFrame.new(45, Y + 14, rz + 0.3) * CFrame.Angles(0, math.pi, 0), 20, 22)
	for _ = 1, 10 do
		block(lobby, Vector3.new(rng:NextNumber(0.6, 1.8), rng:NextNumber(0.4, 1.2), rng:NextNumber(0.6, 1.8)),
			CFrame.new(45 + rng:NextNumber(-5, 5), Y + 0.5, rz + rng:NextNumber(1.5, 6)) * CFrame.Angles(rng:NextNumber(), rng:NextNumber(), rng:NextNumber()),
			M.Concrete, rgb(64, 64, 72))
	end

	-- SUIT GALLERY (east) -----------------------------------------------
	local gx = hx - 12
	block(lobby, Vector3.new(20, 1, 70), CFrame.new(gx + 2, Y + 0.5, 0), M.Marble, rgb(26, 26, 30))
	block(lobby, Vector3.new(0.3, 0.2, 69.6), CFrame.new(gx - 8, Y + 1.05, 0), M.Neon, rgb(255, 228, 196))
	block(lobby, Vector3.new(3, 0.5, 70), CFrame.new(gx - 9.5, Y + 0.25, 0), M.Marble, rgb(34, 34, 38))
	-- a stadium-style marquee across the top of the gallery: a dark fascia
	-- with glowing gold borders, marquee bulbs and the title, and light bars
	-- down both ends framing the whole gallery like the pedestal rings
	local GOLD = rgb(255, 206, 90)
	local mf = CFrame.new(hx - 1.45, Y + 23.2, 0) * CFrame.Angles(0, math.rad(90), 0) -- X runs along the wall, -Z into the room
	local fascia = block(lobby, Vector3.new(72, 5, 0.6), mf, M.Metal, rgb(16, 16, 22))
	local fg = make("SurfaceGui", fascia, { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 24, LightInfluence = 0 })
	local fbg = make("Frame", fg, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(40, 31, 16), BorderSizePixel = 0 })
	make("UIGradient", fbg, { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(90, 90, 90)) }) -- dark bronze fading to black
	local gt = make("TextLabel", fbg, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.74),
		BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextScaled = true, Text = "SUIT GALLERY", TextColor3 = rgb(255, 214, 80) })
	make("UIStroke", gt, { Thickness = 6, Color = rgb(70, 34, 0) })
	for _, x in { 0.2, 0.8 } do
		make("TextLabel", fbg, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5), Size = UDim2.fromScale(0.05, 0.6),
			BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "★", TextColor3 = GOLD })
	end
	for _, y in { 2.45, -2.45 } do
		block(lobby, Vector3.new(72, 0.22, 0.3), mf * CFrame.new(0, y, -0.4), M.Neon, GOLD)
		for x = -35, 35, 1.75 do
			block(lobby, Vector3.new(0.34, 0.34, 0.34), mf * CFrame.new(x, y * 0.86, -0.42), M.Neon, rgb(255, 236, 190), { Shape = Enum.PartType.Ball, CanCollide = false, CastShadow = false })
		end
	end
	for _, s in { -1, 1 } do
		block(lobby, Vector3.new(0.22, 5.2, 0.3), mf * CFrame.new(s * 36, 0, -0.4), M.Neon, GOLD)
		block(lobby, Vector3.new(0.3, 19.6, 0.3), CFrame.new(hx - 1.85, Y + 10.9, s * 36), M.Neon, GOLD)
		for y = 2, 19, 1.75 do
			block(lobby, Vector3.new(0.3, 0.3, 0.3), CFrame.new(hx - 1.85, Y + y, s * 36.45), M.Neon, rgb(255, 236, 190), { Shape = Enum.PartType.Ball, CanCollide = false, CastShadow = false })
		end
		light(block(lobby, Vector3.new(0.4, 0.4, 0.4), CFrame.new(hx - 4, Y + 21, s * 30), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false }), { Range = 20, Brightness = 1, Color = GOLD })
	end
	-- a lighting bar along the gallery wall on brackets; two stage lights hang
	-- from it over each suit (see the pedestals below)
	local barX, barY = hx - 3.2, Y + 15.6
	block(lobby, Vector3.new(62, 0.34, 0.34), CFrame.new(barX, barY, 0) * CFrame.Angles(0, math.rad(90), 0), M.Metal, rgb(34, 34, 38), { Shape = Enum.PartType.Cylinder })
	for z = -30, 30, 12 do
		block(lobby, Vector3.new(2.3, 0.3, 0.3), CFrame.new(hx - 2.1, barY + 0.3, z), M.Metal, rgb(40, 40, 46))
		block(lobby, Vector3.new(0.2, 1.2, 0.6), CFrame.new(hx - 1.1, barY + 0.3, z), M.Metal, rgb(40, 40, 46))
	end
	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = lobby
	local skinOrder = { "Logan", "Comic", "WeaponX", "OldManLogan" }
	local swatches = { rgb(150, 100, 60), rgb(255, 200, 30), rgb(90, 220, 200), rgb(200, 200, 200) }
	for i, id in skinOrder do
		local z = -24 + (i - 1) * 16
		local base = CFrame.new(gx + 3, Y + 1, z)
		block(lobby, Vector3.new(1.6, 8, 8), base * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)), M.Marble, rgb(40, 40, 46), { Shape = Enum.PartType.Cylinder })
		block(lobby, Vector3.new(0.3, 8.4, 8.4), base * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)), M.Neon, swatches[i], { Shape = Enum.PartType.Cylinder })
		local spot = block(pedestals, Vector3.new(1, 1, 1), base * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, math.rad(90), 0), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false })
		spot.Name = "Pedestal_" .. id
		spot:SetAttribute("Skin", id)
		local lamp = block(lobby, Vector3.new(1.6, 1, 1.6), CFrame.new(gx - 4, Y + H - 2, z), M.Metal, C.DarkMetal)
		make("SpotLight", lamp, { Face = Enum.NormalId.Bottom, Range = 34, Angle = 40, Brightness = 5, Color = swatches[i]:Lerp(Color3.new(1, 1, 1), 0.6), Shadows = true })
		for _, dz in { -3.2, 3.2 } do -- stage lights crossing on the suit
			stageLight(lobby, Vector3.new(barX, barY - 0.17, z + dz), Vector3.new(gx + 3, Y + 6, z - dz * 0.3), swatches[i]:Lerp(Color3.new(1, 1, 1), 0.55), 18, 3.2)
		end
		local plaque = block(lobby, Vector3.new(6, 2.2, 0.3), CFrame.new(gx - 4, Y + 1.9, z) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(25), 0, 0), M.Metal, rgb(24, 24, 28))
		-- the suit's display name and price (Skins), scaled to fit the plaque
		local suit = require(ReplicatedStorage.Shared.Skins).List[id]
		local _, label = surfaceText(plaque, Enum.NormalId.Front, {
			Name = "PlaqueText", TextColor3 = swatches[i], Font = Enum.Font.GothamBlack,
			Text = suit.Name .. (suit.Price > 0 and ("\n" .. suit.Price .. " " .. Config.CoinName:upper()) or "\nFREE"),
		})
		make("UIPadding", label, { PaddingLeft = UDim.new(0.06, 0), PaddingRight = UDim.new(0.06, 0), PaddingTop = UDim.new(0.08, 0), PaddingBottom = UDim.new(0.08, 0) })
		block(lobby, Vector3.new(0.4, 1.4, 0.4), CFrame.new(gx - 4, Y + 0.7, z), M.Metal, C.DarkMetal)
	end

	-- CLAW COLLECTION (south wall): one lit glass case per claw set --------
	local Skins = require(ReplicatedStorage.Shared.Skins)
	local Costumes = require(script.Parent.Costumes)
	local cz = hz - 6.5
	-- the title hangs up on the cladding, above the windows (not across them)
	block(lobby, Vector3.new(25.2, 3.6, 0.3), CFrame.new(17.5, Y + H - 3.6, hz - 1.55), M.Metal, rgb(40, 40, 46))
	local rackTitle = block(lobby, Vector3.new(24, 2.6, 0.2), CFrame.new(17.5, Y + H - 3.6, hz - 1.8) * CFrame.Angles(0, math.pi, 0), M.SmoothPlastic, rgb(18, 18, 22))
	surfaceText(rackTitle, Enum.NormalId.Back, { Text = "CLAW COLLECTION", Font = Enum.Font.LuckiestGuy, TextColor3 = rgb(210, 230, 255) })
	for i, id in Skins.ClawOrder do
		local item = Skins.Claws[id]
		-- centred under the CLAW COLLECTION sign, clear of the suit gallery
		local x = 17.5 + (i - (#Skins.ClawOrder + 1) / 2) * 5.6
		local base = CFrame.new(x, Y, cz)
		block(lobby, Vector3.new(3.4, 3.2, 3.4), base * CFrame.new(0, 1.6, 0), M.Marble, rgb(30, 30, 34))
		block(lobby, Vector3.new(3.6, 0.25, 3.6), base * CFrame.new(0, 3.3, 0), M.Metal, rgb(70, 72, 78), { Reflectance = 0.2 })
		block(lobby, Vector3.new(3.5, 0.15, 3.5), base * CFrame.new(0, 0.1, 0), M.Neon, item.Glow)
		-- not M.Glass: Roblox won't draw SurfaceGuis (the Verity faces) behind Glass
		block(lobby, Vector3.new(3.2, 5.2, 3.2), base * CFrame.new(0, 6, 0), M.SmoothPlastic, rgb(200, 225, 240), { Transparency = 0.88, Reflectance = 0.2 })
		for _, cx in { -1.6, 1.6 } do
			for _, czz in { -1.6, 1.6 } do
				block(lobby, Vector3.new(0.14, 5.2, 0.14), base * CFrame.new(cx, 6, czz), M.Metal, rgb(50, 50, 56))
			end
		end
		block(lobby, Vector3.new(3.4, 0.3, 3.4), base * CFrame.new(0, 8.75, 0), M.Metal, rgb(50, 50, 56))
		-- a stage light hung in the top back corner, aimed at the claws
		stageLight(lobby, (base * CFrame.new(0.95, 8.6, 0.95)).Position, (base * CFrame.new(0, 5, 0)).Position, item.Glow:Lerp(Color3.new(1, 1, 1), 0.55))
		Costumes.ClawDisplay(lobby, base * CFrame.new(0, 4.35, 0) * CFrame.Angles(0, math.rad(90 + 18), math.rad(6)), item)
		local plaque = block(lobby, Vector3.new(3.2, 0.9, 0.1), base * CFrame.new(0, 2.2, -1.75) * CFrame.Angles(math.rad(12), 0, 0), M.Metal, rgb(22, 22, 26))
		surfaceText(plaque, Enum.NormalId.Front, { Text = item.Name .. (item.Price > 0 and ("\n" .. item.Price .. " " .. Config.CoinName:upper()) or "  FREE"), TextColor3 = item.Glow, Font = Enum.Font.GothamBold })
	end

	-- SENTINEL BAY (west wall, north end): every Sentinel suit on a lit
	-- plinth facing into the room, with its name and price (bought in the
	-- Armory's SENTINEL tab) --------------------------------------------
	local bayTitle = block(lobby, Vector3.new(0.2, 2.6, 24), CFrame.new(-hx + 2.1, Y + 22.5, -29), M.SmoothPlastic, rgb(18, 16, 22))
	surfaceText(bayTitle, Enum.NormalId.Right, { Text = "SENTINEL SUITS", Font = Enum.Font.LuckiestGuy, TextColor3 = rgb(205, 150, 255) })
	for i, id in Skins.SentinelOrder do
		local item = Skins.Sentinels[id]
		local z = -36 + (i - 1) * 14
		local px = -hx + 7.5
		local faceIn = CFrame.Angles(0, math.rad(-90), 0) -- facing +X, into the room
		block(lobby, Vector3.new(1.2, 10, 10), CFrame.new(px, Y + 0.6, z) * CFrame.Angles(0, 0, math.rad(90)), M.Marble, rgb(34, 32, 40), { Shape = Enum.PartType.Cylinder })
		block(lobby, Vector3.new(0.25, 10.4, 10.4), CFrame.new(px, Y + 1.1, z) * CFrame.Angles(0, 0, math.rad(90)), M.Neon, item.Swatch, { Shape = Enum.PartType.Cylinder })
		Costumes.SentinelStatue(lobby, CFrame.new(px, Y + 1.25, z) * faceIn, Config.Sentinel.Scale, id)
		local lamp = block(lobby, Vector3.new(1.6, 1, 1.6), CFrame.new(px + 4, Y + H - 2, z), M.Metal, C.DarkMetal)
		make("SpotLight", lamp, { Face = Enum.NormalId.Bottom, Range = 34, Angle = 45, Brightness = 5, Color = item.Swatch:Lerp(Color3.new(1, 1, 1), 0.6), Shadows = true })
		local plaque = block(lobby, Vector3.new(7, 2.2, 0.3), CFrame.new(px + 6.8, Y + 1.9, z) * faceIn * CFrame.Angles(math.rad(25), 0, 0), M.Metal, rgb(24, 24, 28))
		surfaceText(plaque, Enum.NormalId.Front, { Text = item.Name .. (item.Price > 0 and ("\n" .. item.Price .. " " .. Config.CoinName:upper()) or "\nFREE"), TextColor3 = item.Swatch, Font = Enum.Font.GothamBlack })
		block(lobby, Vector3.new(0.4, 1.4, 0.4), CFrame.new(px + 6.8, Y + 0.7, z), M.Metal, C.DarkMetal)
	end

	-- BRIEFING TABLE: holographic mini-map of the arena --------------------
	local bt = Vector3.new(-6, Y, -22)
	block(lobby, Vector3.new(1.2, 3, 3), CFrame.new(bt + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, rgb(40, 42, 48), { Shape = Enum.PartType.Cylinder })
	block(lobby, Vector3.new(0.6, 14, 14), CFrame.new(bt + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, rgb(30, 32, 38), { Shape = Enum.PartType.Cylinder })
	block(lobby, Vector3.new(0.2, 14.4, 14.4), CFrame.new(bt + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Neon, rgb(60, 170, 255), { Shape = Enum.PartType.Cylinder })
	local holoBase = block(lobby, Vector3.new(0.1, 12, 12), CFrame.new(bt + Vector3.new(0, 3.55, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Neon, rgb(40, 140, 255), { Shape = Enum.PartType.Cylinder, Transparency = 0.55 })
	light(holoBase, { Range = 16, Brightness = 1.4, Color = rgb(80, 170, 255) })
	local HOLO = rgb(90, 200, 255)
	local mini = 12 / 380 -- arena scaled onto the table
	for _, b in { { 0, 0, 90, 70, 16 }, { 120, -118, 56, 40, 17 }, { 118, 100, 36, 22, 11 }, { -125, -112, 22, 16, 9 }, { -42, 140, 22, 16, 9 }, { 38, -148, 22, 16, 9 }, { 152, 30, 22, 16, 9 } } do
		local h = b[5] * mini * 3
		block(lobby, Vector3.new(b[3] * mini, h, b[4] * mini), CFrame.new(bt + Vector3.new(b[1] * mini, 3.6 + h / 2, b[2] * mini)), M.Neon, HOLO, { Transparency = 0.45, CanCollide = false })
	end
	for _, r in { { 0, -56, 136, 12 }, { 0, 56, 136, 12 }, { -62, 0, 12, 100 }, { 62, 0, 12, 100 }, { 0, 121, 12, 118 }, { 0, -121, 12, 118 }, { 124, 0, 112, 12 }, { -124, 0, 112, 12 } } do
		block(lobby, Vector3.new(r[3] * mini, 0.03, r[4] * mini), CFrame.new(bt + Vector3.new(r[1] * mini, 3.62, r[2] * mini)), M.Neon, rgb(60, 140, 220), { Transparency = 0.5, CanCollide = false })
	end
	local blip = block(lobby, Vector3.new(0.35, 0.35, 0.35), CFrame.new(bt + Vector3.new(0, 4.2, 0)), M.Neon, rgb(255, 60, 40), { Shape = Enum.PartType.Ball, CanCollide = false })
	light(blip, { Range = 6, Brightness = 2, Color = rgb(255, 60, 40) })
	CollectionService:AddTag(blip, "Flicker")
	for k = 0, 5 do -- stools around the table
		local a = k / 6 * math.pi * 2
		local sp = bt + Vector3.new(math.cos(a) * 9.5, 0, math.sin(a) * 9.5)
		block(lobby, Vector3.new(1.8, 0.4, 1.8), CFrame.new(sp + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, rgb(46, 48, 54), { Shape = Enum.PartType.Cylinder })
		block(lobby, Vector3.new(0.3, 2.2, 2.2), CFrame.new(sp + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Leather, rgb(60, 24, 24), { Shape = Enum.PartType.Cylinder })
	end

	-- Planters with small pines along the walkway
	for _, z in { -34, 16, 30 } do
		for _, x in { -8.5, 8.5 } do
			local pp = Vector3.new(x, Y, z)
			block(lobby, Vector3.new(3.4, 1.6, 3.4), CFrame.new(pp + Vector3.new(0, 0.8, 0)), M.Concrete, rgb(88, 88, 94))
			block(lobby, Vector3.new(3, 0.2, 3), CFrame.new(pp + Vector3.new(0, 1.62, 0)), M.Ground, rgb(60, 44, 32))
			tree(lobby, pp + Vector3.new(0, 1.5, 0), 0.32, true)
		end
	end

	-- Vending machines in the south-east corner, clear of the windows: a
	-- cola machine against the east wall, a snack machine on the south wall
	vendingMachine(lobby, CFrame.lookAt(Vector3.new(hx - 2.3, Y, 38.2), Vector3.new(0, Y, 38.2)), "Cola")
	vendingMachine(lobby, CFrame.lookAt(Vector3.new(53.6, Y, hz - 2.3), Vector3.new(53.6, Y, 0)), "Snacks")

	-- LOUNGE (west) ----------------------------------------------------
	local lx = -hx + 14
	loungeRug(lobby, Vector3.new(lx, Y, 8), 22, 26)
	-- both sofas face the table and the fireplace (a couch's back is on its +Z)
	couch(lobby, CFrame.new(lx + 2, Y, 18), rgb(116, 62, 36))
	couch(lobby, CFrame.new(lx + 9, Y, 7) * CFrame.Angles(0, math.rad(90), 0), rgb(116, 62, 36))
	coffeeTable(lobby, Vector3.new(lx + 1, Y, 8))
	-- stone fireplace on the west wall: an open firebox (sooty back wall,
	-- pillars either side, stone over the opening) so the fire is on show, a
	-- raised stone hearth in front, logs on a bed of glowing embers
	local fz = 8
	local stone, stone2 = rgb(88, 84, 82), rgb(78, 74, 72)
	block(lobby, Vector3.new(1, 12, 12), CFrame.new(-hx + 1.5, Y + 6, fz), M.Cobblestone, stone2) -- back
	block(lobby, Vector3.new(0.2, 5, 6), CFrame.new(-hx + 2.1, Y + 2.5, fz), M.Slate, rgb(22, 18, 16)) -- soot
	for side = -1, 1, 2 do
		block(lobby, Vector3.new(2, 12, 3), CFrame.new(-hx + 3, Y + 6, fz + side * 4.5), M.Cobblestone, stone) -- pillars
	end
	block(lobby, Vector3.new(2, 7, 6), CFrame.new(-hx + 3, Y + 8.5, fz), M.Cobblestone, stone) -- over the opening
	block(lobby, Vector3.new(2.2, 0.6, 6.4), CFrame.new(-hx + 3.1, Y + 5.2, fz), M.Slate, rgb(40, 36, 34)) -- lintel
	block(lobby, Vector3.new(2.6, H - 12, 7), CFrame.new(-hx + 2.3, Y + 12 + (H - 12) / 2, fz), M.Cobblestone, stone2) -- chimney breast
	block(lobby, Vector3.new(3.4, 0.8, 13), CFrame.new(-hx + 2.8, Y + 12.2, fz), M.Wood, rgb(60, 38, 24)) -- mantel
	block(lobby, Vector3.new(2, 0.3, 6), CFrame.new(-hx + 3, Y + 0.15, fz), M.Slate, rgb(26, 22, 20)) -- firebox floor
	block(lobby, Vector3.new(1.8, 0.4, 9), CFrame.new(-hx + 4.9, Y + 0.2, fz), M.Slate, rgb(58, 54, 52)) -- hearth
	-- the fire: an iron grate on an ash bed, a stacked log pile with glowing
	-- cracks, embers scattered round it, and layered flames, sparks and smoke
	local fx0 = -hx + 3 -- middle of the firebox
	block(lobby, Vector3.new(1.9, 0.1, 5.4), CFrame.new(fx0, Y + 0.35, fz), M.Slate, rgb(62, 58, 56)) -- ash bed
	block(lobby, Vector3.new(1, 0.05, 3), CFrame.new(fx0, Y + 0.42, fz), M.Neon, rgb(200, 60, 15), { CanCollide = false }) -- glowing bed under the logs
	local IRON = rgb(30, 28, 28)
	for _, x in { -0.6, 0, 0.6 } do -- grate
		block(lobby, Vector3.new(0.12, 0.12, 4.2), CFrame.new(fx0 + x, Y + 0.72, fz), M.Metal, IRON)
	end
	for _, z in { -1.8, 1.8 } do
		block(lobby, Vector3.new(1.6, 0.14, 0.14), CFrame.new(fx0, Y + 0.64, fz + z), M.Metal, IRON)
		for _, x in { -0.7, 0.7 } do
			block(lobby, Vector3.new(0.12, 0.3, 0.12), CFrame.new(fx0 + x, Y + 0.49, fz + z), M.Metal, IRON)
		end
	end
	for _, z in { -2.2, 2.2 } do -- andirons
		block(lobby, Vector3.new(0.16, 1.3, 0.16), CFrame.new(fx0 + 0.85, Y + 0.95, fz + z), M.Metal, IRON)
		block(lobby, Vector3.new(0.3, 0.3, 0.3), CFrame.new(fx0 + 0.85, Y + 1.7, fz + z), M.Metal, IRON, { Shape = Enum.PartType.Ball })
	end
	local EMBER = rgb(255, 110, 30)
	local alongZ = CFrame.Angles(0, math.rad(90), 0) -- a cylinder lying along the firebox
	local function log(cf, len, dia, color, cracks)
		block(lobby, Vector3.new(len, dia, dia), cf, M.Wood, color, { Shape = Enum.PartType.Cylinder })
		block(lobby, Vector3.new(len * 0.7, 0.08, 0.12), cf * CFrame.new(0, -dia * 0.44, 0), M.Neon, EMBER, { CanCollide = false })
		for _, c in cracks or {} do -- glowing splits on the side facing the room
			block(lobby, Vector3.new(c[2], 0.06, 0.06), cf * CFrame.new(c[1], c[3] * dia, dia * 0.47) * CFrame.Angles(math.rad(c[4] or 0), 0, 0), M.Neon, EMBER, { CanCollide = false })
		end
	end
	log(CFrame.new(fx0 - 0.45, Y + 1.12, fz) * alongZ * CFrame.Angles(0, math.rad(4), 0), 3.6, 0.66, rgb(78, 52, 32))
	log(CFrame.new(fx0 + 0.4, Y + 1.1, fz + 0.1) * alongZ * CFrame.Angles(0, math.rad(-5), 0), 3.4, 0.62, rgb(72, 48, 30), { { -0.6, 0.9, 0.05 }, { 0.5, 0.6, -0.12 }, { 1.1, 0.4, 0.15 } })
	log(CFrame.new(fx0, Y + 1.69, fz - 1.1) * CFrame.Angles(0, math.rad(8), 0), 1.9, 0.5, rgb(54, 36, 24))
	log(CFrame.new(fx0 - 0.05, Y + 1.67, fz + 1.2) * CFrame.Angles(0, math.rad(-6), 0), 1.9, 0.5, rgb(58, 38, 26))
	log(CFrame.new(fx0 - 0.1, Y + 2.19, fz) * alongZ * CFrame.Angles(math.rad(6), 0, 0), 2.8, 0.5, rgb(40, 28, 20), { { -0.4, 0.7, 0.1 }, { 0.6, 0.5, -0.1 } })
	for _ = 1, 22 do -- embers and char round the grate
		local glowing = rng:NextNumber() < 0.6
		local sz = rng:NextNumber(0.14, 0.34)
		block(lobby, Vector3.new(sz, sz * 0.7, sz), CFrame.new(fx0 + rng:NextNumber(-0.85, 0.85), Y + 0.42 + sz * 0.3, fz + rng:NextNumber(-2.4, 2.4)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
			glowing and M.Neon or M.Slate, glowing and (rng:NextNumber() < 0.5 and EMBER or rgb(220, 50, 20)) or rgb(40, 22, 16), { CanCollide = false })
	end
	-- flames lick up out of the logs: a hot core, a wider orange body,
	-- sparks and a little smoke drawn up the flue
	local hearth = block(lobby, Vector3.new(1.2, 0.3, 3), CFrame.new(fx0, Y + 1.35, fz), M.SmoothPlastic, rgb(0, 0, 0), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	hearth.Name = "FireplaceFire"
	local NS, NK, CS, CK = NumberSequence.new, NumberSequenceKeypoint.new, ColorSequence.new, ColorSequenceKeypoint.new
	local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
	make("ParticleEmitter", hearth, {
		Name = "FlameCore", Texture = FIRE_TEX, Shape = Enum.ParticleEmitterShape.Box,
		Color = CS({ CK(0, rgb(255, 244, 200)), CK(0.3, rgb(255, 196, 80)), CK(1, rgb(255, 90, 20)) }),
		LightEmission = 1, LightInfluence = 0,
		Size = NS({ NK(0, 0.9), NK(0.35, 1.2), NK(1, 0.1) }),
		Transparency = NS({ NK(0, 0.35), NK(0.2, 0.05), NK(0.75, 0.4), NK(1, 1) }),
		Lifetime = NumberRange.new(0.45, 0.75), Rate = 60,
		Speed = NumberRange.new(2.2, 4), SpreadAngle = Vector2.new(6, 6),
		Acceleration = Vector3.new(0, 5, 0), Drag = 1,
		Rotation = NumberRange.new(-20, 20), RotSpeed = NumberRange.new(-50, 50),
		EmissionDirection = Enum.NormalId.Top, ZOffset = 0.3,
	})
	make("ParticleEmitter", hearth, {
		Name = "FlameOuter", Texture = FIRE_TEX, Shape = Enum.ParticleEmitterShape.Box,
		Color = CS({ CK(0, rgb(255, 150, 40)), CK(0.5, rgb(240, 80, 20)), CK(1, rgb(150, 30, 10)) }),
		LightEmission = 0.9, LightInfluence = 0,
		Size = NS({ NK(0, 1.4), NK(0.4, 1.9), NK(1, 0.3) }),
		Transparency = NS({ NK(0, 0.6), NK(0.25, 0.35), NK(1, 1) }),
		Lifetime = NumberRange.new(0.7, 1.1), Rate = 28,
		Speed = NumberRange.new(1.8, 3.2), SpreadAngle = Vector2.new(10, 10),
		Acceleration = Vector3.new(0, 4, 0), Drag = 0.8,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40),
		EmissionDirection = Enum.NormalId.Top, ZOffset = 0.1,
	})
	make("ParticleEmitter", hearth, {
		Name = "Sparks", Texture = "rbxasset://textures/particles/sparkles_main.dds", Shape = Enum.ParticleEmitterShape.Box,
		Color = CS(rgb(255, 220, 120), rgb(255, 110, 30)),
		LightEmission = 1, LightInfluence = 0,
		Size = NS({ NK(0, 0.14), NK(1, 0.02) }),
		Transparency = NS({ NK(0, 0), NK(0.8, 0.2), NK(1, 1) }),
		Lifetime = NumberRange.new(0.9, 1.8), Rate = 7,
		Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, 1.5, 0), Drag = 1.6,
		EmissionDirection = Enum.NormalId.Top,
	})
	make("ParticleEmitter", hearth, {
		Name = "Smoke", Texture = "rbxasset://textures/particles/smoke_main.dds", Shape = Enum.ParticleEmitterShape.Box,
		Color = CS(rgb(60, 54, 50), rgb(110, 106, 104)),
		LightEmission = 0, LightInfluence = 1,
		Size = NS({ NK(0, 0.8), NK(1, 3.2) }),
		Transparency = NS({ NK(0, 1), NK(0.25, 0.8), NK(1, 1) }),
		Lifetime = NumberRange.new(2.2, 3.2), Rate = 6,
		Speed = NumberRange.new(2.4, 3.4), SpreadAngle = Vector2.new(8, 8),
		Acceleration = Vector3.new(0, 1, 0), Drag = 0.4,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-15, 15),
		EmissionDirection = Enum.NormalId.Top,
	})
	-- the firelight hangs above the logs, so they don't shadow the hearth
	local glow = block(lobby, Vector3.new(0.4, 0.4, 0.4), CFrame.new(fx0 + 0.3, Y + 2.6, fz), M.SmoothPlastic, rgb(0, 0, 0), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	glow.Name = "FireGlow"
	light(glow, { Range = 26, Brightness = 2.5, Color = rgb(255, 150, 70), Shadows = true })
	CollectionService:AddTag(glow, "FireLight")
	-- mounted claws trophy above the fireplace
	for b = -1, 1 do
		block(lobby, Vector3.new(0.15, 4, 0.4), CFrame.new(-hx + 1.6, Y + 15.5, fz + b * 0.9) * CFrame.Angles(math.rad(b * 8), 0, 0), M.Metal, rgb(210, 214, 222), { Reflectance = 0.4 })
	end
	block(lobby, Vector3.new(0.4, 2.6, 4), CFrame.new(-hx + 1.4, Y + 13.4, fz), M.Wood, rgb(60, 38, 24))
	-- bookshelves
	for _, z in { -8, 24 } do
		block(lobby, Vector3.new(2.5, 12, 8), CFrame.new(-hx + 2.3, Y + 6, z), M.Wood, rgb(55, 36, 22))
		for s = 0, 3 do
			for b = 0, 9 do
				block(lobby, Vector3.new(1.6, rng:NextNumber(1.6, 2.4), 0.6), CFrame.new(-hx + 3, Y + 1.8 + s * 2.8, z - 3.4 + b * 0.75), M.SmoothPlastic, vary(({ rgb(120, 30, 30), rgb(30, 60, 110), rgb(40, 90, 50), rgb(160, 130, 60) })[(b + s) % 4 + 1], 0.2))
			end
		end
	end

	-- LEADERBOARD (west wall, south end) ---------------------------------
	-- south of the bookcase (the north end is the Sentinel bay), clear of the
	-- corner column (z > hz - 3.6)
	local lb = block(lobby, Vector3.new(0.4, 11, 12.4), CFrame.new(-hx + 2.9, Y + 9, 34.7), M.SmoothPlastic, rgb(14, 14, 18))
	local lbGui = make("SurfaceGui", lb, { Name = "Leaderboard", Face = Enum.NormalId.Right, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 36, LightInfluence = 0 })
	local lbBg = make("Frame", lbGui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(16, 14, 18), BorderSizePixel = 0 })
	make("UIStroke", lbBg, { Color = rgb(200, 30, 30), Thickness = 8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local lbTitle = make("TextLabel", lbBg, { Size = UDim2.fromScale(1, 0.18), BackgroundColor3 = rgb(150, 20, 20), Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = rgb(255, 220, 90), Text = "TOP HUNTERS" })
	make("UIStroke", lbTitle, { Thickness = 4 })
	local rowsFrame = make("Frame", lbBg, { Name = "Rows", Position = UDim2.fromScale(0.05, 0.22), Size = UDim2.fromScale(0.9, 0.74), BackgroundTransparency = 1 })
	make("UIListLayout", rowsFrame, { Padding = UDim.new(0.02, 0) })
	for i = 1, 6 do
		make("TextLabel", rowsFrame, {
			Name = "Row" .. i,
			Size = UDim2.fromScale(1, 0.14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = i == 1 and rgb(255, 210, 60) or rgb(220, 220, 225),
			Text = "",
			LayoutOrder = i,
		})
	end
	-- a red light bar along the top of the board (it used to hang in mid-air
	-- over the Sentinel bay, where the board once was)
	local lbLight = block(lobby, Vector3.new(0.3, 0.3, 12.4), CFrame.new(-hx + 3.25, Y + 14.7, 34.7), M.Neon, rgb(200, 30, 30))
	light(lbLight, { Range = 10, Brightness = 1, Color = rgb(255, 60, 40) })

	-- STATUS TV: mounted on the chimney breast above the fireplace, facing
	-- the sofas (GameManager writes StatusText / TimerText on "StatusScreen")
	local tvX, tvY, tvZ = -hx + 3.6, Y + 18.2, 8
	block(lobby, Vector3.new(0.35, 4.3, 6.8), CFrame.new(tvX + 0.18, tvY, tvZ), M.Metal, rgb(14, 14, 16)) -- bezel
	local screen = block(lobby, Vector3.new(0.12, 3.9, 6.4), CFrame.new(tvX + 0.4, tvY, tvZ), M.SmoothPlastic, rgb(6, 6, 8))
	screen.Name = "StatusScreen"
	block(lobby, Vector3.new(0.4, 0.3, 1.2), CFrame.new(tvX + 0.2, tvY - 2.3, tvZ), M.Metal, rgb(20, 20, 22)) -- wall bracket
	block(lobby, Vector3.new(0.05, 0.08, 0.08), CFrame.new(tvX + 0.37, tvY - 2.02, tvZ + 3), M.Neon, rgb(255, 40, 40)) -- power LED
	make("SurfaceLight", screen, { Face = Enum.NormalId.Right, Range = 10, Angle = 90, Brightness = 0.7, Color = rgb(255, 120, 100) })
	local g = make("SurfaceGui", screen, { Face = Enum.NormalId.Right, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 80, LightInfluence = 0 })
	local bg = make("Frame", g, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
	make("UIGradient", bg, { Rotation = 90, Color = ColorSequence.new(rgb(36, 8, 10), rgb(6, 4, 6)) })
	-- scanlines, for a bit of CRT grit
	for k = 0, 11 do
		make("Frame", bg, { Position = UDim2.fromScale(0, k / 12), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.8, BorderSizePixel = 0 })
	end
	make("TextLabel", bg, { Name = "StatusText", Position = UDim2.fromScale(0.05, 0.1), Size = UDim2.fromScale(0.9, 0.3), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = rgb(235, 205, 205), Text = "" })
	local t = make("TextLabel", bg, { Name = "TimerText", Position = UDim2.fromScale(0.05, 0.42), Size = UDim2.fromScale(0.9, 0.5), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = rgb(255, 200, 30), Text = "" })
	make("UIStroke", t, { Thickness = 4 })

	-- Supply crates + barrels for detail
	for i, p in { Vector3.new(-30, Y, -34), Vector3.new(22, Y, -36) } do
		local yaw = rng:NextNumber() * 0.5
		woodCrate(lobby, CFrame.new(p) * CFrame.Angles(0, yaw, 0), Vector3.new(5, 4, 4), false)
		woodCrate(lobby, CFrame.new(p + Vector3.new(0.3, 4, 0.2)) * CFrame.Angles(0, yaw + 0.3, 0), Vector3.new(3, 3, 3), false)
		woodCrate(lobby, CFrame.new(p + Vector3.new(5.2, 0, 0.5)) * CFrame.Angles(0, -yaw, 0), Vector3.new(3.4, 3.4, 3.4), false)
		steelBarrel(lobby, CFrame.new(p + Vector3.new(-3.6, 0, 2.6)), i % 2 == 0 and rgb(150, 30, 30) or rgb(40, 80, 140), false)
		steelBarrel(lobby, CFrame.new(p + Vector3.new(-4.2, 0, -0.3)), rgb(60, 110, 60), false)
	end
	block(lobby, Vector3.new(32, 3.6, 0.3), CFrame.new(-30, Y + H - 3.6, hz - 1.3), M.Metal, rgb(40, 40, 46))
	sign(lobby, CFrame.new(-30, Y + H - 3.6, hz - 1.6), Vector3.new(30, 2.6, 0.3), "WEAPON X  •  HOLDING FACILITY 7", rgb(255, 200, 30), rgb(18, 18, 22))

	lobby.Parent = workspace
	-- soften every neon light in the lobby so bloom stays crisp instead of hazy
	for _, d in lobby:GetDescendants() do
		if d:IsA("BasePart") and d.Material == M.Neon then
			local h, sat, v = d.Color:ToHSV()
			d.Color = Color3.fromHSV(h, sat * 0.7, v * 0.62)
		end
	end
	return lobby
end

function MapBuilder.Build()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	rng = Random.new(20260924)
	zones = {}

	local map = Instance.new("Model")
	map.Name = "Map"
	local function folder(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = map
		return f
	end
	local env = folder("Environment")
	local bld = folder("Buildings")
	local props = folder("Props")
	local spawns = folder("Spawns")
	local terminals = folder("Terminals")
	folder("HidingSpots")
	folder("Debris")

	if not terrain() then
		block(env, Vector3.new(2 * HALF + 260, 4, 2 * HALF + 260), CFrame.new(0, -2, 0), M.Snow, C.Snow)
	end
	zone(-100, 45, 32, 32) -- frozen pond
	-- reeds poking out of the frozen pond edge
	for k = 1, 26 do
		local a = k / 26 * math.pi * 2
		local rr = 14 + rng:NextNumber(-0.5, 1.5)
		block(env, Vector3.new(0.12, rng:NextNumber(1.2, 2.6), 0.12), CFrame.new(-100 + math.cos(a) * rr, 0.8, 45 + math.sin(a) * rr) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2)), M.Grass, rgb(120, 110, 70), { CanCollide = false })
	end

	buildLab(bld, props, map)
	buildWarehouse(bld, props, terminals, Vector3.new(120, 0, -118))
	buildDiner(bld, props, terminals, Vector3.new(118, 0, 100))
	buildContainerYard(props, map, Vector3.new(-118, 0, 112))
	local _, cabinY = buildCabin(bld, props, Vector3.new(-125, 0, -112), true)
	terminal(terminals, Vector3.new(-125 - 3, cabinY, -112 - 6.5), Vector3.new(0, 0, 1), "Terminal_Cabin")
	buildCabin(bld, props, Vector3.new(-42, 0, 140), true)
	buildCabin(bld, props, Vector3.new(38, 0, -148), false)
	buildCabin(bld, props, Vector3.new(152, 0, 30), true)
	buildGate(props, bld)
	watchtower(props, Vector3.new(-160, 0, -160))
	watchtower(props, Vector3.new(162, 0, 162))
	watchtower(props, Vector3.new(-160, 0, 40))
	buildRoads(env, props)
	buildDetails(env, props)
	buildBoundary(env)
	buildWilderness(env, props)

	map.Parent = workspace

	-- Survivor spawns: keep only spots that land on open ground
	local candidates = {
		{ -100, -75 }, { -150, -60 }, { -120, -155 }, { -60, -100 }, { 80, -70 }, { 150, -78 },
		{ 100, -160 }, { 165, -40 }, { 90, 75 }, { 160, 125 }, { 70, 150 }, { -85, 70 },
		{ -165, 150 }, { -75, 160 }, { -160, 20 }, { 40, 160 }, { -30, -100 }, { -20, 90 },
		{ 165, 60 }, { -90, -30 }, { 90, 30 }, { 30, -80 }, { -140, -20 }, { 130, -40 },
	}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = terrain() and { map, terrain() } or { map }
	for i, c in candidates do
		local hit = workspace:Raycast(Vector3.new(c[1], 80, c[2]), Vector3.new(0, -100, 0), params)
		if hit and hit.Position.Y < 1.5 then
			local s = block(spawns, Vector3.new(2, 1, 2), CFrame.new(hit.Position + Vector3.new(0, 0.5, 0)), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false })
			s.Name = "Spawn" .. i
		end
	end
	if #spawns:GetChildren() == 0 then
		block(spawns, Vector3.new(2, 1, 2), CFrame.new(0, 1, 90), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false })
	end
	return map
end

return MapBuilder
