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
						Transparency = 0.6,
						Reflectance = 0.1,
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

local function crate(parent, pos, s)
	s = s or 4
	return breakable(block(parent, Vector3.one * s, CFrame.new(pos + Vector3.new(0, s / 2, 0)) * CFrame.Angles(0, rng:NextNumber() * 0.4, 0), M.WoodPlanks, vary(C.Wood, 0.2)))
end

local function barrel(parent, pos, color)
	return breakable(block(parent, Vector3.new(3, 2.2, 2.2), CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, color or C.Rust, { Shape = Enum.PartType.Cylinder }))
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
	block(parent, Vector3.new(0.6, 14, 0.6), base * CFrame.new(0, 7, 0), M.Metal, C.DarkMetal)
	block(parent, Vector3.new(0.4, 0.4, 3.2), base * CFrame.new(0, 13.8, -1.4), M.Metal, C.DarkMetal)
	local head = block(parent, Vector3.new(1.4, 0.4, 1.2), base * CFrame.new(0, 13.5, -2.8), M.Neon, C.Lamp)
	light(head, { Range = 30, Brightness = 1.6, Color = C.Lamp, Shadows = true })
	if flicker then
		CollectionService:AddTag(head, "Flicker")
	end
end

local function tree(parent, pos, scale)
	local model = Instance.new("Model")
	model.Name = "Pine"
	local s = scale
	local trunk = block(model, Vector3.new(1.3 * s, 7 * s, 1.3 * s), CFrame.new(pos + Vector3.new(0, 3.5 * s, 0)), M.Wood, C.DarkWood)
	breakable(trunk)
	trunk:SetAttribute("Topple", true)
	local spin = rng:NextNumber() * math.pi
	for i, w in { 10, 8, 6, 4, 2.2 } do
		local y = (4.5 + i * 2.3) * s
		local cf = CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, spin + i * 0.45, 0)
		block(model, Vector3.new(w * s, 2.6 * s, w * s), cf, M.Grass, i % 2 == 0 and C.Pine or C.PineDark, { CanCollide = i == 1 })
		block(model, Vector3.new(w * s * 0.8, 0.35 * s, w * s * 0.8), cf * CFrame.new(0, 1.35 * s, 0), M.Snow, C.Snow, { CanCollide = false })
	end
	model.Parent = parent
end

local function rock(parent, pos, size)
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
			tree(env, Vector3.new(x, 0, z), rng:NextNumber(1.2, 2))
		end
	end
	for i = 1, 18 do
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
				block(env, Vector3.one * rng:NextNumber(8, 14), CFrame.new(x, -4, z), M.Snow, C.SnowShade, { Shape = Enum.PartType.Ball })
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
	Lighting.ClockTime = 0.3
	Lighting.Brightness = 1.5
	Lighting.Ambient = rgb(38, 42, 58)
	Lighting.OutdoorAmbient = rgb(70, 80, 105)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.GeographicLatitude = 55
	for _, c in Lighting:GetChildren() do
		if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") then
			c:Destroy()
		end
	end
	make("Atmosphere", Lighting, {
		Density = 0.42,
		Offset = 0.1,
		Color = rgb(95, 105, 130),
		Decay = rgb(30, 36, 52),
		Glare = 0,
		Haze = 2.2,
	})
	make("Sky", Lighting, { StarCount = 3000, MoonAngularSize = 14, CelestialBodiesShown = true })
	make("ColorCorrectionEffect", Lighting, {
		Brightness = 0.02,
		Contrast = 0.15,
		Saturation = -0.25,
		TintColor = rgb(215, 225, 255),
	})
	make("BloomEffect", Lighting, { Intensity = 0.7, Size = 28, Threshold = 1.4 })
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

local function ruleCard(parent, cf, icon, heading, body, accent)
	local p = block(parent, Vector3.new(15, 11, 0.4), cf, M.SmoothPlastic, rgb(16, 16, 20))
	local gui = make("SurfaceGui", p, { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0 })
	local bg = make("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
	make("UIGradient", bg, { Rotation = 90, Color = ColorSequence.new(rgb(40, 34, 38), rgb(10, 9, 12)) })
	make("UIStroke", bg, { Color = accent, Thickness = 8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local top = make("Frame", bg, { Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = accent, BorderSizePixel = 0 })
	make("UIGradient", top, { Color = ColorSequence.new(accent, Color3.new(0, 0, 0)) })
	make("TextLabel", bg, {
		Position = UDim2.fromScale(0.05, 0.1),
		Size = UDim2.fromScale(0.9, 0.32),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		Text = icon,
	})
	local h = make("TextLabel", bg, {
		Position = UDim2.fromScale(0.05, 0.44),
		Size = UDim2.fromScale(0.9, 0.18),
		BackgroundTransparency = 1,
		Font = Enum.Font.LuckiestGuy,
		TextScaled = true,
		TextColor3 = accent,
		Text = heading,
	})
	make("UIStroke", h, { Thickness = 4 })
	make("TextLabel", bg, {
		Position = UDim2.fromScale(0.07, 0.64),
		Size = UDim2.fromScale(0.86, 0.3),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = rgb(215, 210, 215),
		Text = body,
	})
	-- neon underline + small spot lamp above the card
	block(parent, Vector3.new(15, 0.25, 0.25), cf * CFrame.new(0, -5.8, -0.2), M.Neon, accent)
	local lampArm = block(parent, Vector3.new(0.4, 0.4, 2.4), cf * CFrame.new(0, 6.6, -1.2), M.Metal, C.DarkMetal)
	local head = block(parent, Vector3.new(1.4, 0.7, 1.4), cf * CFrame.new(0, 6.4, -2.4), M.Metal, C.DarkMetal)
	make("SpotLight", head, { Face = Enum.NormalId.Bottom, Range = 16, Angle = 70, Brightness = 3, Color = rgb(255, 235, 210) })
	return p, lampArm
end

-- Three glowing gouges ripped through steel, with bent metal flaps.
local function clawGouge(parent, origin, length, tilt)
	for i = -1, 1 do
		local cf = origin * CFrame.Angles(0, 0, math.rad(tilt)) * CFrame.new(i * 2.2, 0, 0)
		block(parent, Vector3.new(0.9, length, 0.3), cf, M.Slate, rgb(8, 6, 6))
		for s = -1, 1, 2 do
			block(parent, Vector3.new(0.14, length * 0.96, 0.32), cf * CFrame.new(s * 0.5, 0, 0), M.Neon, rgb(255, 120, 30))
			-- torn flaps curling out of the cut
			for f = -1, 1 do
				block(parent, Vector3.new(0.6, 1.4, 0.1), cf * CFrame.new(s * 0.75, f * length * 0.3, -0.35) * CFrame.Angles(math.rad(-35), 0, math.rad(s * 35)), M.Metal, rgb(90, 92, 98))
			end
		end
	end
	local glow = block(parent, Vector3.new(1, 1, 1), origin * CFrame.new(0, 0, -1), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false })
	light(glow, { Range = 14, Brightness = 2, Color = rgb(255, 120, 40) })
end

local function hangingLamp(parent, pos, color)
	block(parent, Vector3.new(0.15, 6, 0.15), CFrame.new(pos + Vector3.new(0, 3, 0)), M.Metal, rgb(30, 30, 30))
	local shade = block(parent, Vector3.new(1.6, 3.4, 3.4), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, rgb(40, 42, 46), { Shape = Enum.PartType.Cylinder })
	local bulb = block(parent, Vector3.new(1.2, 1.2, 1.2), CFrame.new(pos - Vector3.new(0, 0.9, 0)), M.Neon, color, { Shape = Enum.PartType.Ball })
	make("SpotLight", shade, { Face = Enum.NormalId.Left, Range = 40, Angle = 80, Brightness = 2.2, Color = color, Shadows = true })
	return bulb
end

local function couch(parent, cf, color)
	block(parent, Vector3.new(10, 1.6, 4), cf * CFrame.new(0, 1.2, 0), M.Fabric, color)
	block(parent, Vector3.new(10, 3, 1.2), cf * CFrame.new(0, 2.6, 1.6), M.Fabric, color)
	for _, x in { -5.3, 5.3 } do
		block(parent, Vector3.new(0.9, 2.4, 4), cf * CFrame.new(x, 1.8, 0), M.Fabric, color)
	end
	for _, x in { -3.3, 0, 3.3 } do
		block(parent, Vector3.new(3.1, 0.6, 3.4), cf * CFrame.new(x, 2.2, -0.2), M.Fabric, vary(color, 0.15))
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

	-- Mountain ledge + backdrop
	block(lobby, Vector3.new(420, 4, 420), CFrame.new(0, Y - 2.2, 0), M.Snow, C.Snow)
	for _ = 1, 60 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(80, 190)
		tree(lobby, Vector3.new(math.cos(a) * r, Y - 0.2, math.sin(a) * r), rng:NextNumber(1.3, 2.2))
	end
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2
		local r = rng:NextNumber(260, 320)
		local h = rng:NextNumber(90, 170)
		local cf = CFrame.new(math.cos(a) * r, Y + h / 2 - 30, math.sin(a) * r) * CFrame.Angles(0, -a + math.rad(45), 0)
		block(lobby, Vector3.new(150, h, 110), cf, M.Slate, vary(rgb(70, 74, 84), 0.2), { CanCollide = false })
		block(lobby, Vector3.new(80, h * 0.25, 60), cf * CFrame.new(0, h * 0.42, 0), M.Snow, C.Snow, { CanCollide = false })
	end

	-- Floor: dark concrete, hazard border, steel walkway
	block(lobby, Vector3.new(W, 1, D), CFrame.new(0, Y - 0.5, 0), M.Concrete, rgb(48, 48, 54))
	for _, d in { { 0, -hz + 2, W - 2, 1.2 }, { 0, hz - 2, W - 2, 1.2 }, { -hx + 2, 0, 1.2, D - 2 }, { hx - 2, 0, 1.2, D - 2 } } do
		block(lobby, Vector3.new(d[3], 0.06, d[4]), CFrame.new(d[1], Y + 0.03, d[2]), M.SmoothPlastic, C.Hazard)
	end
	for x = -hx + 6, hx - 6, 4 do
		block(lobby, Vector3.new(0.9, 0.07, 1.25), CFrame.new(x, Y + 0.05, -hz + 2) * CFrame.Angles(0, math.rad(45), 0), M.SmoothPlastic, rgb(20, 20, 20))
		block(lobby, Vector3.new(0.9, 0.07, 1.25), CFrame.new(x, Y + 0.05, hz - 2) * CFrame.Angles(0, math.rad(45), 0), M.SmoothPlastic, rgb(20, 20, 20))
	end
	block(lobby, Vector3.new(10, 0.1, D - 10), CFrame.new(0, Y + 0.05, 0), M.DiamondPlate, rgb(80, 84, 92))

	-- Glowing X emblem in the floor
	local ringY = Y + 0.12
	block(lobby, Vector3.new(0.1, 22, 22), CFrame.new(0, ringY, 0) * CFrame.Angles(0, 0, math.rad(90)), M.SmoothPlastic, rgb(20, 20, 24), { Shape = Enum.PartType.Cylinder })
	block(lobby, Vector3.new(0.12, 21, 21), CFrame.new(0, ringY + 0.01, 0) * CFrame.Angles(0, 0, math.rad(90)), M.Neon, rgb(170, 20, 20), { Shape = Enum.PartType.Cylinder })
	block(lobby, Vector3.new(0.14, 19, 19), CFrame.new(0, ringY + 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)), M.SmoothPlastic, rgb(20, 20, 24), { Shape = Enum.PartType.Cylinder })
	for _, a in { 45, -45 } do
		block(lobby, Vector3.new(2.2, 0.1, 17), CFrame.new(0, ringY + 0.05, 0) * CFrame.Angles(0, math.rad(a), 0), M.Neon, rgb(255, 190, 30))
	end
	make("SpawnLocation", lobby, {
		Size = Vector3.new(12, 0.2, 12),
		CFrame = CFrame.new(0, Y + 0.2, 0),
		Neutral = true,
		Duration = 0,
		Transparency = 1,
		CanCollide = false,
	})

	-- Walls with pillars, pipes and windows (south)
	local wallStyle = { Material = M.Concrete, Color = rgb(64, 64, 72), Vary = 0.05, Breakable = false }
	wall(lobby, Vector3.new(-hx, 0, -hz + 0.5), Vector3.new(hx, 0, -hz + 0.5), Y, H, 1, wallStyle)
	wall(lobby, Vector3.new(-hx + 0.5, 0, -hz), Vector3.new(-hx + 0.5, 0, hz), Y, H, 1, wallStyle)
	wall(lobby, Vector3.new(hx - 0.5, 0, -hz), Vector3.new(hx - 0.5, 0, hz), Y, H, 1, wallStyle)
	local windows = {}
	for x = -45, 45, 18 do
		table.insert(windows, { At = x + hx, Width = 12, Bottom = 5, Top = 20, Glass = true })
	end
	wall(lobby, Vector3.new(-hx, 0, hz - 0.5), Vector3.new(hx, 0, hz - 0.5), Y, H, 1, wallStyle, windows)
	for _, w in windows do -- window frames
		local x = w.At - hx
		block(lobby, Vector3.new(12.6, 0.6, 1.6), CFrame.new(x, Y + 5, hz - 0.5), M.Metal, C.DarkMetal)
		block(lobby, Vector3.new(12.6, 0.6, 1.6), CFrame.new(x, Y + 20, hz - 0.5), M.Metal, C.DarkMetal)
		block(lobby, Vector3.new(0.4, 15, 1.4), CFrame.new(x, Y + 12.5, hz - 0.5), M.Metal, C.DarkMetal)
	end
	for x = -hx, hx, 15 do
		for _, z in { -hz + 1.2, hz - 1.2 } do
			block(lobby, Vector3.new(1.8, H, 1.4), CFrame.new(x, Y + H / 2, z), M.Metal, rgb(58, 60, 66))
		end
	end
	for z = -hz, hz, 15 do
		for _, x in { -hx + 1.2, hx - 1.2 } do
			block(lobby, Vector3.new(1.4, H, 1.8), CFrame.new(x, Y + H / 2, z), M.Metal, rgb(58, 60, 66))
		end
	end
	for _, y in { H - 3, H - 4.4 } do
		block(lobby, Vector3.new(W - 4, 0.8, 0.8), CFrame.new(0, Y + y, -hz + 2.2) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, math.rad(90), 0), M.Metal, rgb(110, 80, 50), { Shape = Enum.PartType.Cylinder })
	end
	-- Ceiling + trusses
	block(lobby, Vector3.new(W, 1, D), CFrame.new(0, Y + H + 0.5, 0), M.Metal, rgb(30, 31, 36))
	for z = -hz + 10, hz - 10, 15 do
		block(lobby, Vector3.new(W, 1.4, 0.8), CFrame.new(0, Y + H - 0.7, z), M.Metal, rgb(52, 54, 60))
		for x = -hx + 5, hx - 5, 10 do
			block(lobby, Vector3.new(0.4, 2.4, 0.4), CFrame.new(x, Y + H - 2, z) * CFrame.Angles(0, 0, math.rad(35)), M.Metal, rgb(52, 54, 60))
		end
	end
	-- Hanging lamps: warm light pools with a few red ones for menace
	for x = -40, 40, 20 do
		for z = -24, 24, 24 do
			local red = (x == -40 and z == 24) or (x == 40 and z == -24)
			local bulb = hangingLamp(lobby, Vector3.new(x, Y + H - 7, z), red and rgb(255, 60, 40) or rgb(255, 214, 160))
			if red then
				CollectionService:AddTag(bulb, "Flicker")
			end
		end
	end

	-- RULES WALL (north) -----------------------------------------------
	local rz = -hz + 1.3
	block(lobby, Vector3.new(76, 26, 0.6), CFrame.new(-6, Y + 13.5, rz) * CFrame.Angles(0, math.pi, 0), M.DiamondPlate, rgb(28, 28, 32))
	block(lobby, Vector3.new(77, 0.4, 0.4), CFrame.new(-6, Y + 26.6, rz + 0.3), M.Neon, rgb(200, 20, 20))
	block(lobby, Vector3.new(77, 0.4, 0.4), CFrame.new(-6, Y + 0.6, rz + 0.3), M.Neon, rgb(200, 20, 20))
	for _, x in { -44.3, 32.3 } do
		block(lobby, Vector3.new(0.4, 26, 0.4), CFrame.new(x, Y + 13.6, rz + 0.3), M.Neon, rgb(200, 20, 20))
	end
	local title = block(lobby, Vector3.new(62, 8, 0.3), CFrame.new(-6, Y + 21.5, rz + 0.5) * CFrame.Angles(0, math.pi, 0), M.SmoothPlastic, rgb(12, 12, 14), { Transparency = 1 })
	local _, tl = surfaceText(title, Enum.NormalId.Front, { Text = "SURVIVE THE WOLVERINE", Font = Enum.Font.LuckiestGuy, TextColor3 = rgb(255, 200, 30) })
	make("UIStroke", tl, { Thickness = 10, Color = rgb(0, 0, 0) })
	make("UIGradient", tl, { Rotation = 90, Color = ColorSequence.new(rgb(255, 230, 90), rgb(230, 120, 10)) })
	local sub = block(lobby, Vector3.new(50, 2, 0.3), CFrame.new(-6, Y + 16.6, rz + 0.5) * CFrame.Angles(0, math.pi, 0), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
	surfaceText(sub, Enum.NormalId.Front, { Text = "ONE OF YOU IS THE MONSTER. THE REST OF YOU ARE MEAT.", Font = Enum.Font.GothamBlack, TextColor3 = rgb(230, 70, 60) })

	local rules = {
		{ "🐺", "ONE HUNTER", "A random player becomes Wolverine. Every kill buys him +15 seconds.", rgb(255, 190, 30) },
		{ "🩸", "3 HITS = DEAD", "Two hits throw you. The third tears you in half.", rgb(230, 40, 40) },
		{ "🤖", "SUIT UP", "Reboot 3 terminals. Two Sentinel suits. Stay linked or die.", rgb(180, 110, 255) },
		{ "💨", "HIDE • FART • RUN", "Lockers hide you. Gas hides your scent. Walls won't.", rgb(120, 220, 90) },
	}
	for i, r in rules do
		local x = -6 + (i - 2.5) * 17
		ruleCard(lobby, CFrame.new(x, Y + 8, rz + 0.6) * CFrame.Angles(0, math.pi, 0), r[1], r[2], r[3], r[4])
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
	block(lobby, Vector3.new(0.3, 0.2, 70), CFrame.new(gx - 8, Y + 1.05, 0), M.Neon, rgb(255, 190, 30))
	block(lobby, Vector3.new(3, 0.5, 70), CFrame.new(gx - 9.5, Y + 0.25, 0), M.Marble, rgb(34, 34, 38))
	local galleryTitle = block(lobby, Vector3.new(30, 4, 0.3), CFrame.new(hx - 1.4, Y + 23, 0) * CFrame.Angles(0, math.rad(90), 0), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
	local _, gt = surfaceText(galleryTitle, Enum.NormalId.Front, { Text = "SUIT GALLERY", Font = Enum.Font.LuckiestGuy, TextColor3 = rgb(255, 200, 30) })
	make("UIStroke", gt, { Thickness = 6 })
	for z = -30, 30, 6 do
		block(lobby, Vector3.new(0.3, 16, 0.3), CFrame.new(hx - 1.3, Y + 10, z), M.Neon, rgb(255, 170, 40), { Transparency = 0.2 })
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
		local plaque = block(lobby, Vector3.new(6, 2.2, 0.3), CFrame.new(gx - 4, Y + 1.9, z) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(25), 0, 0), M.Metal, rgb(24, 24, 28))
		surfaceText(plaque, Enum.NormalId.Front, { Name = "PlaqueText", Text = id, TextColor3 = swatches[i], Font = Enum.Font.GothamBlack })
		block(lobby, Vector3.new(0.4, 1.4, 0.4), CFrame.new(gx - 4, Y + 0.7, z), M.Metal, C.DarkMetal)
	end

	-- CLAW RACK (south-east) -------------------------------------------
	local rackC = CFrame.new(40, Y, hz - 5)
	block(lobby, Vector3.new(26, 3, 5), rackC * CFrame.new(0, 1.5, 0), M.Wood, rgb(40, 28, 20))
	block(lobby, Vector3.new(26.4, 0.3, 5.4), rackC * CFrame.new(0, 3.1, 0), M.Metal, C.DarkMetal)
	block(lobby, Vector3.new(26, 6, 5), rackC * CFrame.new(0, 6.2, 0), M.Glass, rgb(190, 220, 235), { Transparency = 0.8 })
	local rackLight = block(lobby, Vector3.new(25, 0.2, 0.5), rackC * CFrame.new(0, 9.1, 0), M.Neon, rgb(255, 240, 220))
	light(rackLight, { Range = 12, Brightness = 1.5, Color = rgb(255, 240, 220) })
	local rackTitle = block(lobby, Vector3.new(16, 2, 0.2), rackC * CFrame.new(0, 10.8, -2.4), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
	surfaceText(rackTitle, Enum.NormalId.Front, { Text = "CLAW COLLECTION", Font = Enum.Font.LuckiestGuy, TextColor3 = rgb(210, 230, 255) })
	local Skins = require(ReplicatedStorage.Shared.Skins)
	for i, id in Skins.ClawOrder do
		local item = Skins.Claws[id]
		local cx = -10.5 + (i - 1) * 4.2
		for b = -1, 1 do
			local blade = block(lobby, Vector3.new(0.12 * (item.Thick or 1), 3.6, 0.3 * (item.Thick or 1)),
				rackC * CFrame.new(cx + b * 0.5, 5.6, 0) * CFrame.Angles(0, 0, math.rad(b * 6)), item.Material, item.Color, { Reflectance = item.Reflectance })
			if item.Material == M.Neon then
				light(blade, { Range = 5, Brightness = 1, Color = item.Glow })
			end
		end
		block(lobby, Vector3.new(1.6, 0.8, 0.8), rackC * CFrame.new(cx, 3.7, 0), M.Leather, rgb(30, 22, 18))
		local tag = block(lobby, Vector3.new(3.6, 0.8, 0.1), rackC * CFrame.new(cx, 3.4, -2.56) * CFrame.Angles(math.rad(20), 0, 0), M.SmoothPlastic, rgb(20, 20, 24))
		surfaceText(tag, Enum.NormalId.Front, { Text = item.Name .. (item.Price > 0 and ("  🪙" .. item.Price) or "  FREE"), TextColor3 = item.Glow, Font = Enum.Font.GothamBold })
	end

	-- LOUNGE (west) ----------------------------------------------------
	local lx = -hx + 14
	block(lobby, Vector3.new(22, 0.08, 26), CFrame.new(lx, Y + 0.05, 8), M.Fabric, rgb(110, 20, 24))
	block(lobby, Vector3.new(19, 0.1, 23), CFrame.new(lx, Y + 0.07, 8), M.Fabric, rgb(70, 12, 16))
	couch(lobby, CFrame.new(lx + 2, Y, 18) * CFrame.Angles(0, math.pi, 0), rgb(60, 40, 30))
	couch(lobby, CFrame.new(lx + 9, Y, 7) * CFrame.Angles(0, math.rad(-90), 0), rgb(60, 40, 30))
	block(lobby, Vector3.new(6, 0.5, 4), CFrame.new(lx + 1, Y + 1.9, 8), M.Wood, rgb(70, 45, 28))
	for _, d in { Vector3.new(-2.6, 0, -1.6), Vector3.new(2.6, 0, -1.6), Vector3.new(-2.6, 0, 1.6), Vector3.new(2.6, 0, 1.6) } do
		block(lobby, Vector3.new(0.4, 1.7, 0.4), CFrame.new(Vector3.new(lx + 1, Y + 0.85, 8) + d), M.Wood, rgb(50, 32, 20))
	end
	for i = 0, 1 do
		block(lobby, Vector3.new(0.6, 0.8, 0.6), CFrame.new(lx + i * 1.6, Y + 2.55, 8), M.SmoothPlastic, i == 0 and rgb(200, 40, 40) or rgb(230, 230, 230), { Shape = Enum.PartType.Cylinder })
	end
	-- stone fireplace on the west wall
	local fz = 8
	block(lobby, Vector3.new(3, 12, 12), CFrame.new(-hx + 2.5, Y + 6, fz), M.Cobblestone, rgb(88, 84, 82))
	block(lobby, Vector3.new(2.6, H - 12, 7), CFrame.new(-hx + 2.3, Y + 12 + (H - 12) / 2, fz), M.Cobblestone, rgb(78, 74, 72))
	block(lobby, Vector3.new(3.4, 0.8, 13), CFrame.new(-hx + 2.8, Y + 12.2, fz), M.Wood, rgb(60, 38, 24))
	local hearth = block(lobby, Vector3.new(2, 4.5, 6), CFrame.new(-hx + 3.6, Y + 2.25, fz), M.Slate, rgb(15, 12, 10))
	make("Fire", hearth, { Size = 5, Heat = 6, Color = rgb(255, 150, 50), SecondaryColor = rgb(255, 70, 20) })
	light(hearth, { Range = 26, Brightness = 2.5, Color = rgb(255, 150, 70), Shadows = true })
	CollectionService:AddTag(hearth, "FireLight")
	for i = 0, 2 do
		block(lobby, Vector3.new(0.8, 0.8, 4), CFrame.new(-hx + 3.6 + (i - 1) * 0.3, Y + 0.5 + i * 0.1, fz) * CFrame.Angles(0, math.rad(i * 40), 0), M.Wood, rgb(60, 40, 24), { Shape = Enum.PartType.Cylinder })
	end
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

	-- LEADERBOARD (west wall, north) -------------------------------------
	local lb = block(lobby, Vector3.new(0.4, 12, 18), CFrame.new(-hx + 1.6, Y + 9, -26), M.SmoothPlastic, rgb(14, 14, 18))
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
	local lbLight = block(lobby, Vector3.new(0.3, 0.3, 18), CFrame.new(-hx + 2, Y + 15.4, -26), M.Neon, rgb(200, 30, 30))
	light(lbLight, { Range = 10, Brightness = 1, Color = rgb(255, 60, 40) })

	-- HANGING STATUS SCREEN (centre) --------------------------------------
	local screen = block(lobby, Vector3.new(18, 7, 18), CFrame.new(0, Y + 17, 0), M.Metal, rgb(18, 18, 22))
	screen.Name = "StatusScreen"
	for _, x in { -6, 6 } do
		block(lobby, Vector3.new(0.2, H - 20.5, 0.2), CFrame.new(x, Y + 20.5 + (H - 20.5) / 2, 0), M.Metal, rgb(30, 30, 30))
	end
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local g = make("SurfaceGui", screen, { Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 30, LightInfluence = 0 })
		local bg = make("Frame", g, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
		make("UIGradient", bg, { Rotation = 90, Color = ColorSequence.new(rgb(40, 10, 12), rgb(8, 6, 8)) })
		make("UIStroke", bg, { Color = rgb(200, 30, 30), Thickness = 6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		make("TextLabel", bg, { Name = "StatusText", Position = UDim2.fromScale(0.05, 0.08), Size = UDim2.fromScale(0.9, 0.3), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = rgb(230, 200, 200), Text = "" })
		local t = make("TextLabel", bg, { Name = "TimerText", Position = UDim2.fromScale(0.05, 0.38), Size = UDim2.fromScale(0.9, 0.55), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = rgb(255, 200, 30), Text = "" })
		make("UIStroke", t, { Thickness = 5 })
	end
	block(lobby, Vector3.new(18.4, 0.3, 18.4), CFrame.new(0, Y + 13.4, 0), M.Neon, rgb(200, 30, 30))

	-- Supply crates + barrels for detail
	for _, p in { Vector3.new(-30, Y, -36), Vector3.new(-26, Y, -38), Vector3.new(20, Y, -37), Vector3.new(-36, Y, 36), Vector3.new(14, Y, 38) } do
		block(lobby, Vector3.new(4, 4, 4), CFrame.new(p + Vector3.new(0, 2, 0)) * CFrame.Angles(0, rng:NextNumber() * 0.5, 0), M.WoodPlanks, vary(C.Wood, 0.2))
		block(lobby, Vector3.new(3, 2.2, 2.2), CFrame.new(p + Vector3.new(3.4, 1.5, 1.5)) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, rgb(150, 30, 30), { Shape = Enum.PartType.Cylinder })
	end
	sign(lobby, CFrame.new(-6, Y + H - 3.6, hz - 1.4), Vector3.new(30, 2.6, 0.3), "WEAPON X  •  HOLDING FACILITY 7", rgb(255, 200, 30), rgb(18, 18, 22))

	lobby.Parent = workspace
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

	block(env, Vector3.new(2 * HALF + 260, 4, 2 * HALF + 260), CFrame.new(0, -2, 0), M.Snow, C.Snow)

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
	params.FilterDescendantsInstances = { map }
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
