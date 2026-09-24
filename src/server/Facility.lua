-- The arena: one huge Weapon X facility, built entirely from code.
--
--                 N (z = -140)
--   +-----------+------------+-----------+
--   | ARCHIVE   |  FOUNDRY   |  REACTOR  |
--   +-----------+--+------+--+-----------+
--   |           |  | RING |  |           |
--   | COMMAND / |  +------+  | GENETICS/ |
--   | SERVERS   |  |ATRIUM|  | CRYO VAULT|
--   |           |  +------+  |           |
--   +-----------+--+------+--+-----------+
--   | SURGICAL  |  HANGAR    | CANTEEN / |
--   | WING      | (Sentinels)| QUARTERS  |
--   +-----------+------------+-----------+
--                 S (z = 140)
--
-- Survivors are Weapon X scientists. Subject X wakes in the containment tank
-- in the atrium; the three Sentinel protocol consoles are in the Foundry, the
-- Genetics lab and the Command centre; the suits are docked in the Hangar.
--
-- Walls are 4-stud columns tagged "Breakable" (Wolverine shreds them). All
-- trim on a column is parented to it, so the whole column tears out cleanly.
-- Surface detail (stencils, hazard stripes, grilles, screens) is drawn with
-- SurfaceGuis, so no image uploads are needed.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Facility = {}

local rgb = Color3.fromRGB
local M = Enum.Material
local N = Enum.NormalId
local F = 0.7 -- walking surface height
local BH = 14 -- walls are breakable up to this height
local PANEL = 4

local rng = Random.new(7)
local ROOT -- the map model being built
local cableAnchor
local lightBudget = 0

---------------------------------------------------------------------------
-- Instance helpers
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

local function P(parent, size, cf, mat, color, extra)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Material = mat
	p.Color = color
	if extra then
		for k, v in extra do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- decoration: never collides / blocks queries (so only wall cores get broken)
local DECO = { CanCollide = false, CanQuery = false, CanTouch = false }
local function D(parent, size, cf, mat, color, extra)
	local p = P(parent, size, cf, mat, color, DECO)
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

local function tag(inst, name)
	CollectionService:AddTag(inst, name)
	return inst
end

local function vary(c, amount)
	local s = 1 + (rng:NextNumber() - 0.5) * (amount or 0.06)
	return Color3.new(math.clamp(c.R * s, 0, 1), math.clamp(c.G * s, 0, 1), math.clamp(c.B * s, 0, 1))
end

local function axisCF(a, b)
	local mid = (a + b) / 2
	local d = b - a
	if math.abs(d.Unit.Y) > 0.999 then
		return CFrame.new(mid) * CFrame.Angles(0, 0, math.rad(90))
	end
	return CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
end

-- cylinder between two points
local function cyl(parent, a, b, d, mat, color, extra, deco)
	local len = (b - a).Magnitude
	local p = (deco and D or P)(parent, Vector3.new(len, d, d), axisCF(a, b), mat, color, extra)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- vertical disc / drum centred at pos
local function drum(parent, pos, dia, h, mat, color, extra, deco)
	local p = (deco and D or P)(parent, Vector3.new(h, dia, dia), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), mat, color, extra)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent, pos, dia, mat, color, extra, deco)
	local p = (deco and D or P)(parent, Vector3.one * dia, CFrame.new(pos), mat, color, extra)
	p.Shape = Enum.PartType.Ball
	return p
end

local function wedge(parent, size, cf, mat, color, extra)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Material = mat
	w.Color = color
	for k, v in DECO do
		w[k] = v
	end
	if extra then
		for k, v in extra do
			w[k] = v
		end
	end
	w.Parent = parent
	return w
end

local function pointLight(parent, range, brightness, color, shadows)
	lightBudget += 1
	return make("PointLight", parent, { Range = range, Brightness = brightness, Color = color, Shadows = shadows or false })
end

local function spotDown(parent, range, brightness, color, angle, shadows)
	lightBudget += 1
	return make("SpotLight", parent, { Face = N.Bottom, Range = range, Brightness = brightness, Color = color, Angle = angle or 90, Shadows = shadows or false })
end

local function surfaceLight(parent, face, range, brightness, color, angle, shadows)
	lightBudget += 1
	return make("SurfaceLight", parent, { Face = face, Range = range, Brightness = brightness, Color = color, Angle = angle or 110, Shadows = shadows or false })
end

---------------------------------------------------------------------------
-- Procedural surface textures (SurfaceGui)
---------------------------------------------------------------------------

local function sgui(p, face, pps, glow)
	return make("SurfaceGui", p, {
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = pps or 40,
		LightInfluence = glow and 0 or 1,
		Brightness = glow and 1.6 or 1,
		ClipsDescendants = true,
	})
end

local function fr(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function tx(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.BorderSizePixel = 0
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	for k, v in props do
		t[k] = v
	end
	t.Parent = parent
	return t
end

-- yellow/black hazard stripes on a face that is `len` studs wide
local function hazard(p, face, len, pps)
	pps = pps or 20
	local g = sgui(p, face, pps)
	local bg = fr(g, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(222, 170, 28), ClipsDescendants = true })
	local n = math.ceil(len * pps / 22) + 10
	for i = -6, n do
		fr(bg, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, i * 22, 0.5, 0), Size = UDim2.new(0, 10, 3, 0), Rotation = 40, BackgroundColor3 = rgb(26, 26, 28) })
	end
	-- scuffing
	fr(bg, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.75 })
	return g
end

-- stencilled text (painted look)
local function stencil(p, face, text, color, pps, font, align)
	local g = sgui(p, face, pps or 30)
	tx(g, {
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color or rgb(230, 230, 230),
		TextTransparency = 0.12,
		Font = font or Enum.Font.GothamBlack,
		TextXAlignment = align or Enum.TextXAlignment.Center,
	})
	return g
end

-- slatted grille (vents, ceiling grates, floor grates)
local function grille(p, face, lenPx, vertical, dark, light, pitch)
	local g = sgui(p, face, 24)
	fr(g, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = dark or rgb(20, 21, 24) })
	pitch = pitch or 10
	for i = 0, math.ceil(lenPx / pitch) do
		if vertical then
			fr(g, { Position = UDim2.new(0, i * pitch, 0, 0), Size = UDim2.new(0, math.ceil(pitch * 0.45), 1, 0), BackgroundColor3 = light or rgb(70, 74, 80) })
		else
			fr(g, { Position = UDim2.new(0, 0, 0, i * pitch), Size = UDim2.new(1, 0, 0, math.ceil(pitch * 0.45)), BackgroundColor3 = light or rgb(70, 74, 80) })
		end
	end
	return g
end

-- Screens: bezel + glowing display with live content (animated by the client)
local SCREEN_TEXT = {
	"> ADAMANTIUM BOND ........ 98.4%",
	"> SKELETAL FUSION ........ STABLE",
	"> HEALING FACTOR ......... ACTIVE",
	"> SEDATION LEVEL ......... 12%  !!",
	"> CORTICAL SUPPRESSION ... FAILING",
	"> SUBJECT X HEART RATE ... 212 BPM",
	"> CONTAINMENT GLASS ...... STRESSED",
	"> SENTINEL PROTOCOL ...... STANDBY",
	"> DEPT. H UPLINK ......... NO SIGNAL",
	"> CRYO BAY 3 TEMP ........ -196 C",
	"> REACTOR OUTPUT ......... 71%",
	"> STAFF EVAC ............. PENDING",
}

local function screenContent(g, kind, accent)
	accent = accent or rgb(90, 200, 255)
	local bg = fr(g, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(6, 12, 20) })
	make("UIGradient", bg, { Color = ColorSequence.new(rgb(14, 30, 46), rgb(4, 8, 14)), Rotation = 90 })
	-- scanlines + grid
	for i = 1, 5 do
		fr(bg, { Position = UDim2.fromScale(i / 6, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = accent, BackgroundTransparency = 0.9 })
	end
	for i = 1, 3 do
		fr(bg, { Position = UDim2.fromScale(0, i / 4), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = accent, BackgroundTransparency = 0.9 })
	end
	local head = kind == "warning" and "CONTAINMENT BREACH" or ({
		vitals = "SUBJECT X — VITALS",
		graph = "CELL REGENERATION",
		dna = "GENOME MAP 04-X",
		code = "WEAPON X // SYSLOG",
		bars = "POWER DISTRIBUTION",
		schematic = "FACILITY SCHEMATIC",
		logo = "",
	})[kind] or ""
	if head ~= "" then
		tx(bg, { Position = UDim2.fromScale(0.04, 0.03), Size = UDim2.fromScale(0.92, 0.13), Text = head, TextColor3 = accent, Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Left })
	end
	if kind == "vitals" or kind == "graph" then
		-- a line graph from rotated segments
		local pts = {}
		for i = 0, 18 do
			local v
			if kind == "vitals" then
				local k = i % 6
				v = k == 2 and 0.15 or k == 3 and 0.85 or k == 4 and 0.4 or 0.55
			else
				v = 0.75 - 0.5 * (i / 18) + (rng:NextNumber() - 0.5) * 0.15
			end
			pts[i] = Vector2.new(0.05 + 0.9 * i / 18, 0.25 + 0.6 * v)
		end
		local holder = fr(bg, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Name = "Trace" })
		for i = 0, 17 do
			local a, b = pts[i], pts[i + 1]
			local mid = (a + b) / 2
			fr(holder, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(mid.X, mid.Y),
				Size = UDim2.new((b - a).Magnitude * 1.05, 0, 0, 3),
				Rotation = math.deg(math.atan2((b.Y - a.Y) * 0.56, b.X - a.X)),
				BackgroundColor3 = kind == "vitals" and rgb(90, 255, 140) or accent,
			})
		end
		tx(bg, { Name = "Blink", Position = UDim2.fromScale(0.62, 0.02), Size = UDim2.fromScale(0.34, 0.14), Text = kind == "vitals" and "212 BPM" or "+340%", TextColor3 = rgb(255, 80, 70), Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Right })
	elseif kind == "dna" then
		for i = 0, 12 do
			local t = i / 12
			local y = 0.2 + 0.72 * t
			for s = 0, 1 do
				local x = 0.5 + math.sin(t * math.pi * 4 + s * math.pi) * 0.28
				local dot = fr(bg, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(0.035, 0.035), BackgroundColor3 = s == 0 and accent or rgb(255, 120, 200) })
				make("UIAspectRatioConstraint", dot, {})
			end
			fr(bg, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, y), Size = UDim2.new(math.abs(math.sin(t * math.pi * 4)) * 0.56, 0, 0, 1), BackgroundColor3 = accent, BackgroundTransparency = 0.5 })
		end
	elseif kind == "code" then
		local lines = {}
		for i = 1, 8 do
			lines[i] = SCREEN_TEXT[(i + rng:NextInteger(0, 11)) % #SCREEN_TEXT + 1]
		end
		tx(bg, { Name = "Scroll", Position = UDim2.fromScale(0.04, 0.18), Size = UDim2.fromScale(0.92, 0.78), Text = table.concat(lines, "\n"), TextScaled = true, TextColor3 = rgb(120, 255, 160), Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	elseif kind == "bars" then
		for i = 0, 9 do
			local h = 0.2 + rng:NextNumber() * 0.6
			fr(bg, { Name = "Bar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0.06 + i * 0.09, 0.92), Size = UDim2.fromScale(0.06, h), BackgroundColor3 = i % 3 == 0 and rgb(255, 170, 50) or accent })
		end
	elseif kind == "schematic" then
		local rooms = { { 0.05, 0.2, 0.3, 0.25 }, { 0.37, 0.2, 0.26, 0.25 }, { 0.65, 0.2, 0.3, 0.25 }, { 0.05, 0.47, 0.3, 0.2 }, { 0.42, 0.47, 0.16, 0.2 }, { 0.65, 0.47, 0.3, 0.2 }, { 0.05, 0.69, 0.3, 0.25 }, { 0.37, 0.69, 0.26, 0.25 }, { 0.65, 0.69, 0.3, 0.25 } }
		for i, r in rooms do
			local f = fr(bg, { Position = UDim2.fromScale(r[1], r[2]), Size = UDim2.fromScale(r[3], r[4]), BackgroundColor3 = accent, BackgroundTransparency = i == 5 and 0.35 or 0.85 })
			make("UIStroke", f, { Color = accent, Thickness = 1 })
			if i == 5 then
				f.Name = "Blink"
				f.BackgroundColor3 = rgb(255, 60, 50)
			end
		end
	elseif kind == "warning" then
		bg.BackgroundColor3 = rgb(60, 6, 6)
		local b = fr(bg, { Name = "Blink", Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(200, 20, 20), BackgroundTransparency = 0.4 })
		tx(b, { Position = UDim2.fromScale(0.05, 0.3), Size = UDim2.fromScale(0.9, 0.4), Text = "⚠ SUBJECT X LOOSE ⚠", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack })
		tx(bg, { Position = UDim2.fromScale(0.05, 0.72), Size = UDim2.fromScale(0.9, 0.16), Text = "ALL STAFF EVACUATE — SENTINEL PROTOCOL REQUIRED", TextColor3 = rgb(255, 200, 200), Font = Enum.Font.Code })
	elseif kind == "logo" then
		tx(bg, { Position = UDim2.fromScale(0.1, 0.2), Size = UDim2.fromScale(0.8, 0.45), Text = "WEAPON X", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack })
		tx(bg, { Position = UDim2.fromScale(0.1, 0.66), Size = UDim2.fromScale(0.8, 0.14), Text = "DEPARTMENT K  ·  PROGRAM 10", TextColor3 = accent, Font = Enum.Font.Code })
	end
end

local SCREEN_KINDS = { "vitals", "graph", "dna", "code", "bars", "schematic", "code", "graph" }
local function screen(parent, cf, w, h, kind, accent)
	kind = kind or SCREEN_KINDS[rng:NextInteger(1, #SCREEN_KINDS)]
	D(parent, Vector3.new(w + 0.3, h + 0.3, 0.22), cf, M.Metal, rgb(24, 25, 28))
	local disp = D(parent, Vector3.new(w, h, 0.05), cf * CFrame.new(0, 0, -0.12), M.SmoothPlastic, rgb(8, 12, 18))
	disp.Name = "Display"
	local g = sgui(disp, N.Front, math.clamp(math.floor(260 / w), 20, 60), true)
	screenContent(g, kind, accent)
	tag(disp, "LiveScreen")
	return disp
end

---------------------------------------------------------------------------
-- Cables (sagging, drawn with beams)
---------------------------------------------------------------------------

local function att(pos)
	local a = Instance.new("Attachment")
	a.Position = pos
	a.Parent = cableAnchor
	return a
end

local function cable(a, b, sag, width, color)
	local n = 7
	local prev = att(a)
	local seq = ColorSequence.new(color or rgb(22, 22, 24))
	for i = 1, n do
		local t = i / n
		local cur = att(a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0))
		make("Beam", cableAnchor, {
			Attachment0 = prev,
			Attachment1 = cur,
			Width0 = width,
			Width1 = width,
			FaceCamera = true,
			Segments = 1,
			Color = seq,
			LightInfluence = 1,
			Transparency = NumberSequence.new(0),
			Texture = "",
		})
		prev = cur
	end
end

---------------------------------------------------------------------------
-- Pipes
---------------------------------------------------------------------------

local function pipe(parent, pts, d, color, mat, flangeColor)
	mat = mat or M.Metal
	flangeColor = flangeColor or rgb(46, 48, 52)
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		cyl(parent, a, b, d, mat, color, nil, true)
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local count = math.max(1, math.floor(len / 12))
		for k = 0, count do
			local p = a + dir * math.clamp(k * len / count, 0.4, len - 0.4)
			cyl(parent, p - dir * 0.15, p + dir * 0.15, d * 1.3, M.Metal, flangeColor, nil, true)
		end
		if i > 1 then
			ball(parent, a, d * 1.12, mat, color, nil, true)
		end
	end
end

local function valveWheel(parent, pos, facing, d, color)
	local cf = CFrame.lookAt(pos, pos + facing)
	cyl(parent, pos, pos + facing * 0.6, 0.35, M.Metal, rgb(40, 40, 44), nil, true)
	local hub = cf * CFrame.new(0, 0, -0.65)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local seg = d * math.sin(math.pi / 8) * 1.08
		D(parent, Vector3.new(seg, 0.18, 0.18), hub * CFrame.Angles(0, 0, a) * CFrame.new(0, d / 2, 0), M.Metal, color or rgb(170, 30, 26))
		if k % 2 == 0 then
			D(parent, Vector3.new(0.1, d / 2, 0.1), hub * CFrame.Angles(0, 0, a) * CFrame.new(0, d / 4, 0), M.Metal, color or rgb(170, 30, 26))
		end
	end
end

---------------------------------------------------------------------------
-- Rooms & lookups
---------------------------------------------------------------------------

local ROOMS = {
	{ Id = "Atrium", Label = "SUBJECT X CONTAINMENT", x0 = -42, z0 = -42, x1 = 42, z1 = 42, h = 40 },
	{ Id = "RingN", Label = "CONTAINMENT RING", x0 = -56, z0 = -56, x1 = 56, z1 = -42, h = 16 },
	{ Id = "RingS", Label = "CONTAINMENT RING", x0 = -56, z0 = 42, x1 = 56, z1 = 56, h = 16 },
	{ Id = "RingW", Label = "CONTAINMENT RING", x0 = -56, z0 = -42, x1 = -42, z1 = 42, h = 16 },
	{ Id = "RingE", Label = "CONTAINMENT RING", x0 = 42, z0 = -42, x1 = 56, z1 = 42, h = 16 },
	{ Id = "Foundry", Label = "ADAMANTIUM FOUNDRY", x0 = -56, z0 = -140, x1 = 56, z1 = -56, h = 30 },
	{ Id = "Hangar", Label = "SENTINEL HANGAR", x0 = -56, z0 = 56, x1 = 56, z1 = 140, h = 34 },
	{ Id = "Genetics", Label = "GENETICS LAB", x0 = 56, z0 = -56, x1 = 108, z1 = 56, h = 20 },
	{ Id = "Cryo", Label = "CRYO VAULT", x0 = 108, z0 = -56, x1 = 160, z1 = 56, h = 20 },
	{ Id = "Command", Label = "COMMAND CENTRE", x0 = -108, z0 = -56, x1 = -56, z1 = 56, h = 20 },
	{ Id = "Servers", Label = "SERVER CORE", x0 = -160, z0 = -56, x1 = -108, z1 = 56, h = 20 },
	{ Id = "Reactor", Label = "REACTOR CORE", x0 = 56, z0 = -140, x1 = 160, z1 = -56, h = 26 },
	{ Id = "Archive", Label = "RECORDS ARCHIVE", x0 = -160, z0 = -140, x1 = -56, z1 = -56, h = 18 },
	{ Id = "Canteen", Label = "STAFF CANTEEN", x0 = 56, z0 = 56, x1 = 108, z1 = 140, h = 18 },
	{ Id = "Quarters", Label = "STAFF QUARTERS", x0 = 108, z0 = 56, x1 = 160, z1 = 140, h = 18 },
	{ Id = "Reception", Label = "MEDICAL RECEPTION", x0 = -108, z0 = 56, x1 = -56, z1 = 140, h = 18 },
	{ Id = "Surgery", Label = "SURGICAL THEATRE", x0 = -160, z0 = 56, x1 = -108, z1 = 140, h = 18 },
}
local ROOM = {}
for _, r in ROOMS do
	ROOM[r.Id] = r
end

local function roomAt(x, z)
	for _, r in ROOMS do
		if x > r.x0 and x < r.x1 and z > r.z0 and z < r.z1 then
			return r
		end
	end
	return nil
end

-- door keep-out zones so scattered props never block a doorway
local doorZones = {}
local function clearAt(x, z, pad)
	pad = pad or 0
	for _, d in doorZones do
		if math.abs(x - d.X) < d.HX + pad and math.abs(z - d.Z) < d.HZ + pad then
			return false
		end
	end
	return true
end

---------------------------------------------------------------------------
-- Wall styles
---------------------------------------------------------------------------

local STYLES = {
	-- clean two-tone office/lab walls: dark wainscot, chair rail, light plaster
	Office = { T = 1.2, Core = M.Plaster, Upper = rgb(150, 156, 162), Lower = rgb(62, 70, 80), Line = rgb(34, 37, 42), Cornice = rgb(46, 50, 56), Pil = rgb(70, 76, 84), LowerH = 3.4, Kind = "Office" },
	Lab = { T = 1.2, Core = M.Plaster, Upper = rgb(160, 166, 170), Lower = rgb(84, 104, 110), Line = rgb(38, 44, 48), Cornice = rgb(52, 58, 62), Pil = rgb(92, 100, 106), LowerH = 3.4, Kind = "Office" },
	Dark = { T = 1.2, Core = M.SmoothPlastic, Upper = rgb(64, 68, 76), Lower = rgb(30, 32, 38), Line = rgb(18, 20, 24), Cornice = rgb(24, 26, 30), Pil = rgb(40, 44, 50), LowerH = 3.4, Kind = "Office", Glow = rgb(60, 190, 255) },
	-- bunker corridor: painted concrete, blue-grey dado, orange stripe, red pipe pilasters
	Concrete = { T = 1.4, Core = M.Concrete, Upper = rgb(176, 178, 180), Lower = rgb(64, 76, 90), Line = rgb(40, 44, 50), Stripe = rgb(226, 118, 32), Pil = rgb(142, 26, 22), LowerH = 2.6, Kind = "Concrete" },
	-- heavy industrial: ribbed steel, amber light bars, I-beam columns
	Industrial = { T = 1.4, Core = M.Metal, Upper = rgb(62, 58, 54), Rib = rgb(88, 82, 74), Line = rgb(34, 32, 30), Pil = rgb(40, 38, 36), LowerH = 1.3, Kind = "Industrial", LightBar = rgb(255, 212, 160) },
}

local function sideSign(parent, cf, w, text, dark)
	local plate = D(parent, Vector3.new(w, 1.2, 0.12), cf, M.SmoothPlastic, dark and rgb(20, 22, 26) or rgb(226, 230, 234))
	local g = sgui(plate, N.Front, 50, dark)
	fr(g, { Size = UDim2.new(0, 10, 1, 0), BackgroundColor3 = dark and rgb(255, 170, 40) or rgb(170, 30, 26) })
	tx(g, {
		Position = UDim2.new(0, 22, 0.14, 0),
		Size = UDim2.new(1, -30, 0.72, 0),
		Text = text,
		TextColor3 = dark and rgb(240, 240, 240) or rgb(30, 32, 36),
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	return plate
end

-- Decorates a breakable wall piece. `at(y)` returns the CFrame at height y on
-- the wall's centre line; X is across the wall. The trims pass through the
-- core so one part dresses both faces.
local function decorate(core, st, at, w, y0, y1, full, idx)
	local T = st.T
	local function band(yA, yB, extraT, color, mat, extra)
		local a, b = math.max(yA, y0), math.min(yB, y1)
		if b - a > 0.02 then
			return D(core, Vector3.new(T + extraT, b - a, w), at((a + b) / 2), mat or M.SmoothPlastic, color, extra)
		end
	end
	if st.Kind == "Office" then
		band(0, 0.4, 0.36, st.Line)
		band(0.4, st.LowerH, 0.2, st.Lower, M.SmoothPlastic)
		band(st.LowerH, st.LowerH + 0.22, 0.32, st.Line)
		if st.Glow then
			band(st.LowerH + 0.22, st.LowerH + 0.3, 0.26, st.Glow, M.Neon)
		end
		if full then
			band(y1 - 0.55, y1, 0.36, st.Cornice)
			-- subtle panel seam
			D(core, Vector3.new(T + 0.04, y1 - st.LowerH - 1.2, 0.07), at((st.LowerH + y1 - 0.6) / 2) * CFrame.new(0, 0, w / 2 - 0.03), M.SmoothPlastic, st.Line, { Transparency = 0.4 })
		end
	elseif st.Kind == "Concrete" then
		band(0, 0.35, 0.3, st.Line)
		band(0.35, st.LowerH, 0.16, st.Lower, M.Concrete)
		band(st.LowerH, st.LowerH + 0.12, 0.2, st.Line)
		band(8.1, 8.2, 0.14, st.Line)
		band(8.2, 8.62, 0.14, st.Stripe, M.SmoothPlastic)
		if full then
			band(y1 - 0.4, y1, 0.3, st.Line)
		end
	elseif st.Kind == "Industrial" then
		band(0, st.LowerH, 0.6, st.Line, M.DiamondPlate)
		band(7.2, 7.8, 0.64, st.Line, M.Metal)
		if full then
			band(y1 - 1, y1, 0.7, st.Line, M.Metal)
		end
		-- vertical ribs
		local top = full and y1 - 1 or y1
		local bottom = math.max(y0, st.LowerH)
		if top - bottom > 0.3 then
			local n = math.max(1, math.floor(w / 1.0))
			for i = 0, n - 1 do
				local z = -w / 2 + (i + 0.5) * w / n
				local ya, yb = bottom, top
				-- ribs broken by the mid band
				for _, span in { { ya, math.min(yb, 7.2) }, { math.max(ya, 7.8), yb } } do
					if span[2] - span[1] > 0.3 then
						D(core, Vector3.new(T + 0.44, span[2] - span[1], 0.34), at((span[1] + span[2]) / 2) * CFrame.new(0, 0, z), M.Metal, st.Rib)
					end
				end
			end
		end
		if full and idx % 3 == 1 and y1 > 10 then
			local bar = D(core, Vector3.new(T + 0.8, 0.28, w * 0.85), at(9.6), M.Neon, st.LightBar)
			D(core, Vector3.new(T + 0.74, 0.5, w * 0.9), at(9.6) * CFrame.new(0, 0.05, 0), M.Metal, rgb(28, 28, 30))
			if idx % 6 == 1 then
				pointLight(bar, 14, 0.7, st.LightBar)
			end
		end
	end
end

-- Features that break up long runs: stencils, vents, wall TVs, fire points...
local STENCIL_CODES = { "WX-01", "WX-04", "B-07", "SEC 3", "HAZ-2", "E-12", "WX-10", "K-09" }
local function feature(core, st, at, w, side, idx, H)
	local r = (idx * 7919) % 11
	local faceCF = function(y)
		return at(y) * CFrame.new(side * (st.T / 2 + (st.Kind == "Industrial" and 0.45 or 0.25)), 0, 0) * CFrame.Angles(0, side > 0 and math.rad(-90) or math.rad(90), 0)
	end
	-- faceCF: -Z points away from the wall (front of the feature faces the room)
	if r == 0 and H >= 9 then
		screen(core, faceCF(6.4) * CFrame.new(0, 0, -0.05), math.min(w - 0.6, 3.6), 2.1, nil, st.Glow)
	elseif r == 2 then
		local p = D(core, Vector3.new(w * 0.7, 1.2, 0.08), faceCF(st.Kind == "Concrete" and 10.2 or 5.4), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
		stencil(p, N.Front, STENCIL_CODES[idx % #STENCIL_CODES + 1], st.Kind == "Office" and rgb(60, 66, 74) or rgb(215, 215, 210), 40, Enum.Font.GothamBlack)
	elseif r == 4 then
		local v = D(core, Vector3.new(2.4, 1.2, 0.14), faceCF(st.Kind == "Industrial" and 12 or 1.3), M.Metal, rgb(40, 42, 46))
		grille(v, N.Front, 30, false, rgb(14, 15, 17), rgb(90, 94, 100), 5)
	elseif r == 6 then
		-- fire extinguisher point
		local base = faceCF(2.2)
		local red = rgb(190, 24, 20)
		D(core, Vector3.new(1.4, 3.6, 0.1), base * CFrame.new(0, 1, 0.05), M.SmoothPlastic, red)
		cyl(core, (base * CFrame.new(0, -0.1, -0.35)).Position, (base * CFrame.new(0, 1.5, -0.35)).Position, 0.55, M.SmoothPlastic, red, nil, true)
		D(core, Vector3.new(0.3, 0.3, 0.3), base * CFrame.new(0, 1.7, -0.35), M.Metal, rgb(30, 30, 32))
		local sg = D(core, Vector3.new(1.2, 0.8, 0.06), base * CFrame.new(0, 3.2, -0.02), M.SmoothPlastic, rgb(200, 30, 26))
		stencil(sg, N.Front, "FIRE", Color3.new(1, 1, 1), 40)
	elseif r == 8 then
		-- electrical box with conduit
		local base = faceCF(4.6)
		D(core, Vector3.new(1.6, 2.2, 0.5), base * CFrame.new(0, 0, -0.2), M.Metal, rgb(120, 126, 132))
		D(core, Vector3.new(1.3, 0.3, 0.1), base * CFrame.new(0, 0.6, -0.48), M.SmoothPlastic, rgb(230, 190, 30))
		cyl(core, (base * CFrame.new(0.4, 1.1, -0.2)).Position, (base * CFrame.new(0.4, H - 5, -0.2)).Position, 0.22, M.Metal, rgb(120, 126, 132), nil, true)
	elseif r == 10 and st.Kind ~= "Industrial" then
		-- keypad / intercom
		local base = faceCF(4.8)
		D(core, Vector3.new(0.7, 1, 0.2), base, M.Metal, rgb(30, 32, 36))
		D(core, Vector3.new(0.45, 0.2, 0.05), base * CFrame.new(0, 0.28, -0.12), M.Neon, rgb(60, 255, 120))
	end
end

-- Structural columns every 16 studs (not breakable)
local function pilaster(parent, st, at, H)
	local T = st.T
	if st.Kind == "Office" then
		D(parent, Vector3.new(T + 1.2, H, 1.6), at(H / 2), M.SmoothPlastic, st.Pil, { CanCollide = true })
		D(parent, Vector3.new(T + 1.5, 0.5, 1.9), at(0.25), M.SmoothPlastic, st.Line)
		D(parent, Vector3.new(T + 1.5, 0.4, 1.9), at(math.min(H, BH) - 0.2), M.SmoothPlastic, st.Line)
	elseif st.Kind == "Concrete" then
		for _, s in { -1, 1 } do
			local x = s * (T / 2 + 0.7)
			local a = (at(0) * CFrame.new(x, 0, 0)).Position
			local b = (at(H) * CFrame.new(x, 0, 0)).Position
			cyl(parent, a, b, 1.0, M.SmoothPlastic, st.Pil, nil, true)
			for y = 2, H - 1, 4 do
				D(parent, Vector3.new(0.9, 0.3, 1.3), at(y) * CFrame.new(s * (T / 2 + 0.35), 0, 0), M.Metal, rgb(40, 40, 42))
			end
			cyl(parent, a, a + Vector3.new(0, 0.5, 0), 1.4, M.Metal, rgb(40, 40, 42), nil, true)
		end
	elseif st.Kind == "Industrial" then
		D(parent, Vector3.new(T + 0.2, H, 0.6), at(H / 2), M.Metal, st.Pil, { CanCollide = true })
		for _, s in { -1, 1 } do
			D(parent, Vector3.new(0.4, H, 1.9), at(H / 2) * CFrame.new(s * (T / 2 + 1.1), 0, 0), M.Metal, st.Pil)
			D(parent, Vector3.new(1.1, H, 0.35), at(H / 2) * CFrame.new(s * (T / 2 + 0.55), 0, 0), M.Metal, st.Pil)
			local hz = D(parent, Vector3.new(0.12, 2.4, 1.9), at(1.4) * CFrame.new(s * (T / 2 + 1.36), 0, 0), M.SmoothPlastic, rgb(222, 170, 28))
			hazard(hz, s > 0 and N.Right or N.Left, 1.9, 20)
			-- rivet plates
			for y = 4, H - 2, 6 do
				D(parent, Vector3.new(0.5, 1.2, 2.2), at(y) * CFrame.new(s * (T / 2 + 1.2), 0, 0), M.Metal, rgb(52, 50, 48))
			end
		end
	end
end

local function openingFrame(parent, st, frame, o, H)
	local T = st.T
	local at = function(y, z)
		return frame * CFrame.new(0, y, -z)
	end
	local c = o.At
	local w = o.W
	local jambT = st.Kind == "Industrial" and 1.3 or st.Kind == "Concrete" and 0.9 or 0.55
	local frameColor = st.Kind == "Office" and rgb(30, 32, 36) or st.Kind == "Concrete" and rgb(96, 100, 104) or rgb(46, 44, 42)
	local mat = st.Kind == "Office" and M.SmoothPlastic or M.Metal
	if o.Bottom and o.Bottom > 0 then
		-- window: sill, head, mullions
		D(parent, Vector3.new(T + 0.5, 0.36, w + 0.4), at(o.Bottom - 0.1, c), mat, frameColor)
		D(parent, Vector3.new(T + 0.4, 0.36, w + 0.4), at(o.Top + 0.1, c), mat, frameColor)
		for s = -1, 1, 2 do
			D(parent, Vector3.new(T + 0.4, o.Top - o.Bottom, 0.3), at((o.Top + o.Bottom) / 2, c + s * (w / 2)), mat, frameColor)
		end
		local mullions = math.floor(w / 4)
		for i = 1, mullions - 1 do
			D(parent, Vector3.new(T * 0.5, o.Top - o.Bottom, 0.18), at((o.Top + o.Bottom) / 2, c - w / 2 + i * w / mullions), mat, frameColor)
		end
		return
	end
	-- doorway
	for s = -1, 1, 2 do
		local jamb = D(parent, Vector3.new(T + jambT, o.Top + 0.02, jambT), at(o.Top / 2 + 0.01, c + s * (w / 2 + jambT / 2 - 0.1)), mat, frameColor, { CanCollide = true, CanQuery = false })
		if st.Kind == "Industrial" then
			hazard(jamb, N.Right, jambT, 20)
			hazard(jamb, N.Left, jambT, 20)
		end
	end
	local headerH = st.Kind == "Industrial" and 1.6 or 0.7
	local header = D(parent, Vector3.new(T + jambT + 0.02, headerH, w + jambT * 2 - 0.2), at(o.Top + headerH / 2 - 0.1, c), mat, frameColor)
	if st.Kind == "Industrial" then
		hazard(header, N.Right, w + jambT * 2, 16)
		hazard(header, N.Left, w + jambT * 2, 16)
	end
	-- floor threshold
	local th = D(parent, Vector3.new(T + 1.6, 0.06, w - 0.2), at(0.035, c), M.DiamondPlate, rgb(90, 92, 96))
	if st.Kind ~= "Office" then
		hazard(th, N.Top, w, 12)
	end
	-- status light over the door + room signs on both faces
	local lamp = D(parent, Vector3.new(T + (st.Kind == "Industrial" and 1.5 or 0.5), 0.25, 1.4), at(o.Top + (st.Kind == "Industrial" and 1.9 or 1.0), c), M.Neon, rgb(70, 255, 120))
	tag(lamp, "DoorLamp")
	for _, s in { -1, 1 } do
		local probe = (at(0, c) * CFrame.new(s * 6, 0, 0)).Position
		local here = roomAt(probe.X, probe.Z)
		local beyond = (at(0, c) * CFrame.new(-s * 6, 0, 0)).Position
		local there = roomAt(beyond.X, beyond.Z)
		if there and (not here or here.Label ~= there.Label) then
			local y = o.Top + (st.Kind == "Industrial" and 3.2 or 2.0)
			if y < H - 0.8 then
				local proud = st.Kind == "Industrial" and 0.9 or st.Kind == "Concrete" and 0.3 or 0.2
				local cf = at(y, c) * CFrame.new(s * (T / 2 + proud), 0, 0) * CFrame.Angles(0, s > 0 and math.rad(-90) or math.rad(90), 0)
				sideSign(parent, cf, math.min(w + 2, 11), there.Label, st.Kind ~= "Office")
			end
		end
	end
	-- keep-out zone
	local centre = at(0, c).Position
	local along = frame.LookVector
	table.insert(doorZones, {
		X = centre.X,
		Z = centre.Z,
		HX = math.abs(along.X) > 0.5 and w / 2 + 2 or 9,
		HZ = math.abs(along.Z) > 0.5 and w / 2 + 2 or 9,
	})
end

-- A wall from (ax,az) to (bx,bz). Openings: { At = centre distance from a,
-- W, Top, Bottom (windows) }. opts.Solid = unbreakable (outer shell).
local wallCount = 0
local function wallRun(parent, ax, az, bx, bz, H, styleName, openings, opts)
	opts = opts or {}
	local st = STYLES[styleName]
	local T = st.T
	local A = Vector3.new(ax, F, az)
	local B = Vector3.new(bx, F, bz)
	if opts.Extend then
		local dir = (B - A).Unit
		A -= dir * opts.Extend
		B += dir * opts.Extend
		local shifted = {}
		for _, o in openings or {} do
			table.insert(shifted, { At = o.At + opts.Extend, W = o.W, Top = o.Top, Bottom = o.Bottom })
		end
		openings = shifted
	end
	local len = (B - A).Magnitude
	local frame = CFrame.lookAt(A, B)
	local model = Instance.new("Model")
	wallCount += 1
	model.Name = "Wall" .. wallCount
	openings = openings or {}
	local breakH = math.min(H, BH)

	local cuts = { 0, len }
	for _, o in openings do
		table.insert(cuts, math.clamp(o.At - o.W / 2, 0, len))
		table.insert(cuts, math.clamp(o.At + o.W / 2, 0, len))
	end
	table.sort(cuts)
	local function openingAt(t)
		for _, o in openings do
			if t > o.At - o.W / 2 and t < o.At + o.W / 2 then
				return o
			end
		end
		return nil
	end

	local idx = 0
	for i = 1, #cuts - 1 do
		local t0, t1 = cuts[i], cuts[i + 1]
		if t1 - t0 > 0.05 then
			local o = openingAt((t0 + t1) / 2)
			local segs = math.max(1, math.ceil((t1 - t0) / PANEL))
			local w = (t1 - t0) / segs
			for s = 0, segs - 1 do
				idx += 1
				local mid = t0 + w * (s + 0.5)
				local at = function(y)
					return frame * CFrame.new(0, y, -mid)
				end
				local spans
				if o then
					spans = {}
					if o.Bottom and o.Bottom > 0 then
						table.insert(spans, { 0, o.Bottom, false })
					end
					if o.Top < breakH then
						table.insert(spans, { o.Top, breakH, false })
					end
				else
					spans = { { 0, breakH, true } }
				end
				for _, sp in spans do
					local core = P(model, Vector3.new(T, sp[2] - sp[1], w), at((sp[1] + sp[2]) / 2), st.Core, vary(st.Upper, 0.03))
					if not opts.Solid then
						breakable(core)
					end
					decorate(core, st, at, w, sp[1], sp[2], sp[3], idx)
					if sp[3] and not opts.Plain then
						for _, side in { -1, 1 } do
							local probe = (at(0) * CFrame.new(side * 3, 0, 0)).Position
							if roomAt(probe.X, probe.Z) then
								feature(core, st, at, w, side, idx * 2 + side, breakH)
							end
						end
					end
				end
				if o and o.Bottom and o.Bottom > 0 then
					local g = P(model, Vector3.new(0.3, o.Top - o.Bottom, w), at((o.Top + o.Bottom) / 2), M.Glass, rgb(150, 180, 196), { Transparency = 0.72, Reflectance = 0.15 })
					breakable(g)
				end
			end
		end
	end

	-- upper structure above the breakable band
	if H > breakH + 0.05 then
		local uh = H - breakH
		P(model, Vector3.new(T, uh, len), frame * CFrame.new(0, breakH + uh / 2, -len / 2), st.Core, st.Kind == "Industrial" and rgb(46, 44, 42) or st.Upper)
		if st.Kind == "Industrial" then
			for y = breakH + 6, H - 2, 8 do
				D(model, Vector3.new(T + 1.2, 0.9, len), frame * CFrame.new(0, y, -len / 2), M.Metal, rgb(34, 33, 32))
			end
			for z = 2, len - 1, 2 do
				D(model, Vector3.new(T + 0.5, uh - 0.2, 0.4), frame * CFrame.new(0, breakH + uh / 2, -z), M.Metal, rgb(70, 66, 60))
			end
		elseif st.Kind == "Concrete" then
			D(model, Vector3.new(T + 0.2, 0.4, len), frame * CFrame.new(0, breakH + 0.2, -len / 2), M.SmoothPlastic, st.Line)
		end
	end

	-- pilasters every 16 studs, skipping openings
	if not opts.NoPilasters then
		for t = 8, len - 4, 16 do
			if not openingAt(t) and not openingAt(t - 1.5) and not openingAt(t + 1.5) then
				pilaster(model, st, function(y)
					return frame * CFrame.new(0, y, -t)
				end, H)
			end
		end
	end
	for _, o in openings do
		openingFrame(model, st, frame, o, H)
	end
	model.Parent = parent
	return model, frame
end

---------------------------------------------------------------------------
-- Floors & ceilings
---------------------------------------------------------------------------

local FLOORS = {
	Grate = { Size = 8, Mat = M.DiamondPlate, Color = rgb(74, 70, 64), Seam = rgb(22, 21, 20) },
	DarkTile = { Size = 6, Mat = M.SmoothPlastic, Color = rgb(64, 68, 74), Seam = rgb(40, 43, 48) },
	LabTile = { Size = 4, Mat = M.CeramicTiles, Color = rgb(128, 134, 140), Seam = rgb(78, 82, 88) },
	Corridor = { Size = 6, Mat = M.Slate, Color = rgb(84, 94, 104), Seam = rgb(40, 44, 50) },
	Hangar = { Size = 12, Mat = M.Concrete, Color = rgb(112, 114, 116), Seam = rgb(56, 58, 60) },
	Rubber = { Size = 6, Mat = M.Rubber, Color = rgb(40, 42, 46), Seam = rgb(20, 21, 24) },
	Carpet = { Size = 8, Mat = M.Carpet, Color = rgb(58, 62, 72), Seam = rgb(40, 42, 50) },
}

local function floorTiles(parent, r, kind, x0, z0, x1, z1)
	local f = FLOORS[kind]
	x0, z0, x1, z1 = x0 or r.x0, z0 or r.z0, x1 or r.x1, z1 or r.z1
	local s = f.Size
	local nx, nz = math.max(1, math.floor((x1 - x0) / s + 0.5)), math.max(1, math.floor((z1 - z0) / s + 0.5))
	local sx, sz = (x1 - x0) / nx, (z1 - z0) / nz
	P(parent, Vector3.new(x1 - x0, 0.08, z1 - z0), CFrame.new((x0 + x1) / 2, F - 0.12, (z0 + z1) / 2), M.SmoothPlastic, f.Seam)
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			P(parent, Vector3.new(sx - 0.12, 0.12, sz - 0.12), CFrame.new(x0 + (i + 0.5) * sx, F - 0.06, z0 + (j + 0.5) * sz), f.Mat, vary(f.Color, 0.06))
		end
	end
end

-- painted floor line (sits just above the tiles, never coplanar)
local function floorLine(parent, a, b, width, color, lift)
	local len = (b - a).Magnitude
	D(parent, Vector3.new(width, 0.04, len), CFrame.lookAt(a, b) * CFrame.new(0, 0.02 + (lift or 0), -len / 2), M.SmoothPlastic, color)
end

local function floorText(parent, pos, yaw, w, h, text, color)
	local p = D(parent, Vector3.new(w, 0.04, h), CFrame.new(pos + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, yaw, 0), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
	stencil(p, N.Top, text, color or rgb(226, 190, 40), 20, Enum.Font.GothamBlack)
end

local function lightPanel(parent, pos, w, d, color, withLight, range)
	D(parent, Vector3.new(w + 0.5, 0.3, d + 0.5), CFrame.new(pos + Vector3.new(0, 0.1, 0)), M.Metal, rgb(34, 36, 40))
	local p = D(parent, Vector3.new(w, 0.1, d), CFrame.new(pos - Vector3.new(0, 0.06, 0)), M.Neon, color or rgb(226, 234, 246))
	if withLight then
		surfaceLight(p, N.Bottom, range or 22, 0.75, color or rgb(226, 234, 246), 115)
	end
	return p
end

local function pendant(parent, pos, drop, color, range, shadows)
	local top = pos + Vector3.new(0, drop, 0)
	cyl(parent, pos + Vector3.new(0, 0.9, 0), top, 0.14, M.Metal, rgb(26, 26, 28), nil, true)
	drum(parent, pos + Vector3.new(0, 0.5, 0), 2.6, 0.9, M.Metal, rgb(30, 30, 32), nil, true)
	drum(parent, pos + Vector3.new(0, 1.1, 0), 1.3, 0.6, M.Metal, rgb(30, 30, 32), nil, true)
	local bulb = drum(parent, pos + Vector3.new(0, 0.02, 0), 2.1, 0.1, M.Neon, color, nil, true)
	spotDown(bulb, range or 44, 2.6, color, 75, shadows)
	return bulb
end

local function truss(parent, a, b, yTop, depth, color)
	-- Warren truss between two points at the ceiling (a,b are XZ ends)
	local A1 = Vector3.new(a.X, yTop, a.Z)
	local B1 = Vector3.new(b.X, yTop, b.Z)
	local A0 = A1 - Vector3.new(0, depth, 0)
	local B0 = B1 - Vector3.new(0, depth, 0)
	local cf = function(p, q, s)
		local len = (q - p).Magnitude
		local frame = math.abs((q - p).Unit.Y) > 0.999 and (CFrame.new(p) * CFrame.Angles(math.rad(90), 0, 0)) or CFrame.lookAt(p, q)
		return D(parent, Vector3.new(s, s, len), frame * CFrame.new(0, 0, -len / 2), M.Metal, color)
	end
	cf(A1, B1, 0.7)
	cf(A0, B0, 0.7)
	local len = (B1 - A1).Magnitude
	local n = math.max(2, math.floor(len / 4))
	for i = 0, n do
		local t0 = i / n
		local top = A1:Lerp(B1, t0)
		local bot = A0:Lerp(B0, t0)
		cf(bot, top, 0.35)
		if i < n then
			local nextTop = A1:Lerp(B1, (i + 1) / n)
			local nextBot = A0:Lerp(B0, (i + 1) / n)
			if i % 2 == 0 then
				cf(bot, nextTop, 0.3)
			else
				cf(top, nextBot, 0.3)
			end
		end
	end
end

local function ceiling(parent, r, kind)
	local y = F + r.h
	local cx, cz = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
	local sx, sz = r.x1 - r.x0, r.z1 - r.z0
	P(parent, Vector3.new(sx, 1.2, sz), CFrame.new(cx, y + 0.6, cz), M.Concrete, rgb(30, 31, 34))
	if kind == "Coffered" then
		-- dropped soffit around the room, recessed light grid inside
		local band = 4
		local c = rgb(110, 116, 122)
		D(parent, Vector3.new(sx, 1.4, band), CFrame.new(cx, y - 0.7, r.z0 + band / 2), M.SmoothPlastic, c)
		D(parent, Vector3.new(sx, 1.4, band), CFrame.new(cx, y - 0.7, r.z1 - band / 2), M.SmoothPlastic, c)
		D(parent, Vector3.new(band, 1.4, sz - band * 2), CFrame.new(r.x0 + band / 2, y - 0.7, cz), M.SmoothPlastic, c)
		D(parent, Vector3.new(band, 1.4, sz - band * 2), CFrame.new(r.x1 - band / 2, y - 0.7, cz), M.SmoothPlastic, c)
		-- cove light strip along the soffit edge
		for _, e in { { cx, r.z0 + band + 0.1, sx - band * 2, 0.15 }, { cx, r.z1 - band - 0.1, sx - band * 2, 0.15 } } do
			D(parent, Vector3.new(e[3], 0.12, e[4]), CFrame.new(e[1], y - 1.3, e[2]), M.Neon, rgb(120, 140, 170))
		end
		D(parent, Vector3.new(sx - band * 2, 0.2, sz - band * 2), CFrame.new(cx, y - 0.1, cz), M.SmoothPlastic, rgb(70, 74, 80))
		-- ceiling tile grid
		for x = r.x0 + band + 4, r.x1 - band - 1, 4 do
			D(parent, Vector3.new(0.08, 0.06, sz - band * 2), CFrame.new(x, y - 0.23, cz), M.SmoothPlastic, rgb(120, 126, 132))
		end
		for z = r.z0 + band + 4, r.z1 - band - 1, 4 do
			D(parent, Vector3.new(sx - band * 2, 0.06, 0.08), CFrame.new(cx, y - 0.23, z), M.SmoothPlastic, rgb(120, 126, 132))
		end
		local k = 0
		for x = r.x0 + band + 6, r.x1 - band - 4, 12 do
			for z = r.z0 + band + 6, r.z1 - band - 4, 12 do
				k += 1
				lightPanel(parent, Vector3.new(x, y - 0.3, z), 3.6, 3.6, rgb(206, 214, 228), k % 2 == 1, r.h + 6)
			end
		end
	elseif kind == "Grate" then
		-- open grate ceiling: dark void, cross beams, grate panels, pipes
		local long = sx > sz
		local L = long and sx or sz
		local Wd = long and sz or sx
		local n = math.floor(L / 8)
		for i = 0, n do
			local t = (long and r.x0 or r.z0) + i * L / n
			local pos = long and Vector3.new(t, y - 1, cz) or Vector3.new(cx, y - 1, t)
			D(parent, long and Vector3.new(0.9, 2, Wd) or Vector3.new(Wd, 2, 0.9), CFrame.new(pos), M.Metal, rgb(150, 150, 152))
			if i < n then
				local mid = t + L / n / 2
				local gp = long and Vector3.new(mid, y - 0.4, cz) or Vector3.new(cx, y - 0.4, mid)
				local g = D(parent, long and Vector3.new(L / n - 1, 0.1, Wd - 4) or Vector3.new(Wd - 4, 0.1, L / n - 1), CFrame.new(gp), M.Metal, rgb(26, 26, 28))
				grille(g, N.Bottom, (long and L / n or Wd) * 24, true, rgb(12, 12, 14), rgb(70, 72, 76), 14)
				if i % 2 == 0 then
					local lp = long and Vector3.new(mid, y - 2.2, cz) or Vector3.new(cx, y - 2.2, mid)
					D(parent, long and Vector3.new(1.4, 0.3, 4.6) or Vector3.new(4.6, 0.3, 1.4), CFrame.new(lp + Vector3.new(0, 0.2, 0)), M.Metal, rgb(40, 42, 46))
					local lamp = D(parent, long and Vector3.new(1, 0.1, 4) or Vector3.new(4, 0.1, 1), CFrame.new(lp), M.Neon, rgb(210, 226, 255))
					surfaceLight(lamp, N.Bottom, 22, 1.2, rgb(210, 226, 255), 120, i % 4 == 0)
				end
			end
		end
		-- twin red service pipes along both sides
		for _, s in { -1, 1 } do
			local off = s * (Wd / 2 - 1.6)
			local a = long and Vector3.new(r.x0 + 1, y - 2.6, cz + off) or Vector3.new(cx + off, y - 2.6, r.z0 + 1)
			local b = long and Vector3.new(r.x1 - 1, y - 2.6, cz + off) or Vector3.new(cx + off, y - 2.6, r.z1 - 1)
			pipe(parent, { a, b }, 0.9, rgb(142, 26, 22), M.SmoothPlastic)
			local a2 = a + (long and Vector3.new(0, 0.3, -s * 1.2) or Vector3.new(-s * 1.2, 0.3, 0))
			local b2 = b + (long and Vector3.new(0, 0.3, -s * 1.2) or Vector3.new(-s * 1.2, 0.3, 0))
			pipe(parent, { a2, b2 }, 0.5, rgb(170, 172, 176), M.Foil)
		end
	elseif kind == "Truss" then
		local long = sx > sz
		local L = long and sx or sz
		local n = math.floor(L / 16)
		for i = 1, n - 1 do
			local t = (long and r.x0 or r.z0) + i * L / n
			local a = long and Vector3.new(t, 0, r.z0 + 1) or Vector3.new(r.x0 + 1, 0, t)
			local b = long and Vector3.new(t, 0, r.z1 - 1) or Vector3.new(r.x1 - 1, 0, t)
			truss(parent, a, b, y - 0.2, 3.6, rgb(58, 56, 54))
		end
		-- pendants between trusses
		local k = 0
		for x = r.x0 + 10, r.x1 - 6, 18 do
			for z = r.z0 + 10, r.z1 - 6, 18 do
				k += 1
				pendant(parent, Vector3.new(x, y - 7, z), 6.5, r.Warm or rgb(255, 204, 150), r.h + 14, k % 3 == 1)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Props
---------------------------------------------------------------------------

local function plant(parent, pos, s)
	s = s or 1
	drum(parent, pos + Vector3.new(0, 1 * s, 0), 1.8 * s, 2 * s, M.Concrete, rgb(70, 72, 76))
	drum(parent, pos + Vector3.new(0, 2.02 * s, 0), 1.9 * s, 0.14 * s, M.Concrete, rgb(90, 92, 96), nil, true)
	drum(parent, pos + Vector3.new(0, 2.05 * s, 0), 1.5 * s, 0.1, M.Ground, rgb(44, 34, 26), nil, true)
	for i = 1, 11 do
		local yaw = i * 2.4 + rng:NextNumber() * 0.4
		local tilt = math.rad(20 + (i % 4) * 14)
		local len = (1.8 + rng:NextNumber() * 1.4) * s
		local base = CFrame.new(pos + Vector3.new(0, 2.1 * s, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, 0)
		D(parent, Vector3.new(0.5 * s, 0.05, len), base * CFrame.new(0, 0, -len / 2), M.SmoothPlastic, vary(rgb(52, 92, 48), 0.25))
		D(parent, Vector3.new(0.34 * s, 0.05, len * 0.6), base * CFrame.new(0, 0.02, -len * 0.8) * CFrame.Angles(math.rad(-25), 0, 0), M.SmoothPlastic, vary(rgb(62, 104, 54), 0.25))
	end
end

local function waitingChairs(parent, cf, count)
	local leather = rgb(34, 36, 42)
	local metal = rgb(120, 124, 130)
	D(parent, Vector3.new(count * 2.2, 0.2, 0.3), cf * CFrame.new(0, 1.1, 0.2), M.Metal, metal, { CanCollide = true })
	for i = 0, count - 1 do
		local c = cf * CFrame.new((i - (count - 1) / 2) * 2.2, 0, 0)
		P(parent, Vector3.new(1.9, 0.35, 1.8), c * CFrame.new(0, 1.5, 0), M.Leather, leather)
		D(parent, Vector3.new(1.9, 2, 0.3), c * CFrame.new(0, 2.6, 0.95) * CFrame.Angles(math.rad(-10), 0, 0), M.Leather, leather)
		D(parent, Vector3.new(0.14, 0.9, 1.6), c * CFrame.new(-1.05, 2, 0), M.Metal, metal)
		for _, x in { -0.8, 0.8 } do
			D(parent, Vector3.new(0.14, 1.2, 0.14), c * CFrame.new(x, 0.6, -0.6), M.Metal, metal)
		end
	end
	D(parent, Vector3.new(0.14, 0.9, 1.6), cf * CFrame.new(count * 1.1 + 0.05, 2, 0), M.Metal, metal)
end

local function officeChair(parent, cf)
	local c = rgb(28, 30, 34)
	for k = 0, 4 do
		D(parent, Vector3.new(0.18, 0.14, 1.2), cf * CFrame.Angles(0, k * math.pi * 2 / 5, 0) * CFrame.new(0, 0.2, -0.6), M.Metal, rgb(60, 62, 66))
	end
	cyl(parent, (cf * CFrame.new(0, 0.2, 0)).Position, (cf * CFrame.new(0, 1.6, 0)).Position, 0.25, M.Metal, rgb(90, 92, 96), nil, true)
	P(parent, Vector3.new(1.8, 0.4, 1.8), cf * CFrame.new(0, 1.8, 0), M.Fabric, c)
	D(parent, Vector3.new(1.7, 2.2, 0.3), cf * CFrame.new(0, 3.1, 0.85) * CFrame.Angles(math.rad(-8), 0, 0), M.Fabric, c)
end

local function desk(parent, cf, w, withScreens)
	w = w or 6
	local top = rgb(52, 56, 62)
	P(parent, Vector3.new(w, 0.25, 3), cf * CFrame.new(0, 3, 0), M.SmoothPlastic, top)
	D(parent, Vector3.new(w, 0.08, 3.02), cf * CFrame.new(0, 3.16, 0), M.SmoothPlastic, rgb(190, 194, 200), { Transparency = 0.5 })
	for _, x in { -w / 2 + 0.2, w / 2 - 0.2 } do
		P(parent, Vector3.new(0.3, 3, 2.8), cf * CFrame.new(x, 1.5, 0), M.SmoothPlastic, rgb(40, 42, 46))
	end
	D(parent, Vector3.new(w - 0.4, 2, 0.15), cf * CFrame.new(0, 1.9, -1.3), M.SmoothPlastic, rgb(40, 42, 46))
	if withScreens then
		local n = math.max(1, math.floor(w / 3))
		for i = 0, n - 1 do
			local x = (i - (n - 1) / 2) * 2.8
			local s = cf * CFrame.new(x, 4.6, -0.7) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.rad(-6), 0, 0)
			D(parent, Vector3.new(0.2, 1.2, 0.2), cf * CFrame.new(x, 3.7, -0.9), M.Metal, rgb(40, 40, 44))
			screen(parent, s, 2.4, 1.4)
		end
		D(parent, Vector3.new(1.8, 0.1, 0.6), cf * CFrame.new(0, 3.2, 0.6), M.SmoothPlastic, rgb(30, 30, 34))
	end
	-- papers
	for _ = 1, 3 do
		D(parent, Vector3.new(0.85, 0.03, 1.1), cf * CFrame.new(rng:NextNumber(-w / 2 + 0.6, w / 2 - 0.6), 3.14, rng:NextNumber(-1, 0.4)) * CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), 0), M.SmoothPlastic, rgb(236, 236, 230))
	end
end

local function crate(parent, cf, s, label)
	s = s or 4
	local body = P(parent, Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), M.Metal, vary(rgb(70, 76, 64), 0.1))
	breakable(body)
	for _, y in { 0.2, s - 0.2 } do
		D(body, Vector3.new(s + 0.12, 0.3, s + 0.12), cf * CFrame.new(0, y, 0), M.Metal, rgb(36, 38, 34))
	end
	for _, x in { -s / 2 + 0.15, s / 2 - 0.15 } do
		for _, z in { -s / 2 + 0.15, s / 2 - 0.15 } do
			D(body, Vector3.new(0.34, s, 0.34), cf * CFrame.new(x, s / 2, z), M.Metal, rgb(36, 38, 34))
		end
	end
	local lab = D(body, Vector3.new(s * 0.7, s * 0.3, 0.05), cf * CFrame.new(0, s * 0.55, -s / 2 - 0.03), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
	stencil(lab, N.Front, label or "WEAPON X", rgb(225, 225, 215), 30)
	return body
end

local function barrel(parent, pos, color)
	local b = drum(parent, pos + Vector3.new(0, 2, 0), 2.4, 4, M.Metal, color or rgb(40, 70, 120))
	breakable(b)
	for _, y in { 0.6, 2, 3.4 } do
		drum(b, pos + Vector3.new(0, y, 0), 2.52, 0.18, M.Metal, rgb(40, 40, 42), nil, true)
	end
	return b
end

local function sofa(parent, cf, seats, color)
	color = color or rgb(40, 52, 76)
	local w = seats * 2.6
	P(parent, Vector3.new(w, 1.6, 3), cf * CFrame.new(0, 0.8, 0), M.Fabric, color)
	for i = 0, seats - 1 do
		D(parent, Vector3.new(2.5, 0.5, 2.5), cf * CFrame.new(-w / 2 + 1.3 + i * 2.6, 1.85, -0.15), M.Fabric, vary(color, 0.05))
	end
	D(parent, Vector3.new(w, 2.4, 0.8), cf * CFrame.new(0, 2.2, 1.1), M.Fabric, color)
	for _, x in { -w / 2 - 0.4, w / 2 + 0.4 } do
		D(parent, Vector3.new(0.8, 2.3, 3), cf * CFrame.new(x, 1.15, 0), M.Fabric, color)
	end
end

local function coffeeTable(parent, cf)
	P(parent, Vector3.new(4.5, 0.2, 2.4), cf * CFrame.new(0, 1.5, 0), M.Glass, rgb(40, 44, 50), { Transparency = 0.3 })
	D(parent, Vector3.new(4.2, 1.4, 0.2), cf * CFrame.new(0, 0.7, 0), M.Metal, rgb(30, 30, 32))
	D(parent, Vector3.new(0.9, 0.05, 1.2), cf * CFrame.new(0.8, 1.63, 0.2) * CFrame.Angles(0, 0.3, 0), M.SmoothPlastic, rgb(230, 230, 224))
	drum(parent, (cf * CFrame.new(-1, 1.85, 0)).Position, 0.5, 0.5, M.SmoothPlastic, rgb(240, 240, 240), nil, true)
end

local function toolChest(parent, cf, color)
	local body = P(parent, Vector3.new(4, 3.6, 2), cf * CFrame.new(0, 1.8, 0), M.Metal, color or rgb(170, 30, 26))
	breakable(body)
	for i = 0, 4 do
		D(body, Vector3.new(3.6, 0.08, 0.05), cf * CFrame.new(0, 0.6 + i * 0.62, -1.02), M.Metal, rgb(30, 30, 32))
		D(body, Vector3.new(1, 0.12, 0.1), cf * CFrame.new(0, 0.85 + i * 0.62, -1.05), M.Metal, rgb(180, 184, 190))
	end
	for _, x in { -1.6, 1.6 } do
		drum(body, (cf * CFrame.new(x, 0.25, -0.6)).Position, 0.5, 0.3, M.Rubber, rgb(20, 20, 20), nil, true)
	end
	D(body, Vector3.new(0.9, 0.3, 0.7), cf * CFrame.new(-1, 3.75, 0), M.Metal, rgb(200, 190, 40))
end

local function cableReel(parent, pos, yaw)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
	for _, x in { -1, 1 } do
		D(parent, Vector3.new(0.2, 4, 4), cf * CFrame.new(x, 2, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, 0, math.rad(-90)), M.WoodPlanks, rgb(130, 96, 60), { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 4, 4) })
	end
	cyl(parent, (cf * CFrame.new(-0.9, 2, 0)).Position, (cf * CFrame.new(0.9, 2, 0)).Position, 3, M.Rubber, rgb(26, 26, 28), { CanCollide = true })
end

local function scaffold(parent, base, w, d, h)
	local c = rgb(200, 150, 30)
	for _, x in { -w / 2, w / 2 } do
		for _, z in { -d / 2, d / 2 } do
			cyl(parent, base + Vector3.new(x, 0, z), base + Vector3.new(x, h, z), 0.3, M.Metal, c, { CanCollide = true })
		end
	end
	for y = 4, h, 4 do
		D(parent, Vector3.new(w, 0.3, d), CFrame.new(base + Vector3.new(0, y, 0)), M.DiamondPlate, rgb(70, 70, 66), { CanCollide = true })
		for _, z in { -d / 2, d / 2 } do
			cyl(parent, base + Vector3.new(-w / 2, y - 4, z), base + Vector3.new(w / 2, y, z), 0.18, M.Metal, c, nil, true)
		end
	end
end

local function turbine(parent, cf)
	local grey = rgb(96, 102, 110)
	local body = P(parent, Vector3.new(18, 7, 7), cf * CFrame.new(0, 4.4, 0) * CFrame.Angles(0, 0, 0), M.Metal, grey, { Shape = Enum.PartType.Cylinder })
	for x = -7.5, 7.5, 2.5 do
		D(body, Vector3.new(0.5, 7.5, 7.5), cf * CFrame.new(x, 4.4, 0), M.Metal, rgb(70, 74, 80), { Shape = Enum.PartType.Cylinder })
	end
	D(body, Vector3.new(4, 5, 5), cf * CFrame.new(10.5, 4.4, 0), M.Metal, rgb(200, 150, 30), { Shape = Enum.PartType.Cylinder })
	P(parent, Vector3.new(16, 1, 6), cf * CFrame.new(0, 0.5, 0), M.Metal, rgb(40, 40, 42))
	for _, x in { -6, 0, 6 } do
		D(parent, Vector3.new(1.2, 1.4, 6.4), cf * CFrame.new(x, 1.4, 0), M.Metal, rgb(40, 40, 42))
	end
	pipe(parent, { (cf * CFrame.new(-4, 8, 0)).Position, (cf * CFrame.new(-4, 14, 0)).Position, (cf * CFrame.new(-4, 14, 8)).Position }, 1.2, rgb(186, 190, 196), M.Foil)
	local gauge = D(parent, Vector3.new(2, 1.4, 0.2), cf * CFrame.new(3, 3, -3.7), M.SmoothPlastic, rgb(20, 20, 22))
	local g = sgui(gauge, N.Front, 40, true)
	tx(g, { Size = UDim2.fromScale(1, 1), Text = "RPM 3600\nTEMP 412°", TextColor3 = rgb(120, 255, 160), Font = Enum.Font.Code })
end

local function conferenceTable(parent, cf, len)
	P(parent, Vector3.new(len, 0.3, 5), cf * CFrame.new(0, 3, 0), M.WoodPlanks, rgb(60, 44, 32))
	for _, x in { -len / 2 + 2, len / 2 - 2 } do
		D(parent, Vector3.new(1.2, 3, 3), cf * CFrame.new(x, 1.5, 0), M.Metal, rgb(30, 30, 32))
	end
	local n = math.floor(len / 3.2)
	for i = 0, n - 1 do
		local x = -len / 2 + 1.6 + i * 3.2
		officeChair(parent, cf * CFrame.new(x, 0, 3.6) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0))
		officeChair(parent, cf * CFrame.new(x, 0, -3.6) * CFrame.Angles(0, math.pi + rng:NextNumber(-0.3, 0.3), 0))
		if rng:NextNumber() < 0.5 then
			D(parent, Vector3.new(0.85, 0.03, 1.1), cf * CFrame.new(x, 3.17, rng:NextNumber(-1.6, 1.6)) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0), M.SmoothPlastic, rgb(236, 236, 230))
		end
	end
end

local function conveyor(parent, a, b)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2)
	P(parent, Vector3.new(3.4, 0.4, len), cf * CFrame.new(0, 2.8, 0), M.Rubber, rgb(26, 26, 28))
	for _, x in { -1.9, 1.9 } do
		D(parent, Vector3.new(0.4, 1, len), cf * CFrame.new(x, 2.9, 0), M.Metal, rgb(200, 150, 30))
	end
	for z = -len / 2 + 1, len / 2 - 1, 1.2 do
		D(parent, Vector3.new(3.4, 0.5, 0.5), cf * CFrame.new(0, 2.5, z), M.Metal, rgb(120, 124, 130), { Shape = Enum.PartType.Cylinder })
	end
	for z = -len / 2 + 1.5, len / 2 - 1, 5 do
		for _, x in { -1.6, 1.6 } do
			D(parent, Vector3.new(0.4, 2.4, 0.4), cf * CFrame.new(x, 1.2, z), M.Metal, rgb(40, 40, 42))
		end
		D(parent, Vector3.new(2.2, 0.6, 0.9), cf * CFrame.new(0, 3.3, z + 2), M.Metal, rgb(205, 208, 216), { Reflectance = 0.3 })
	end
end

---------------------------------------------------------------------------
-- Gameplay objects: consoles, hiding spots, spawns
---------------------------------------------------------------------------

local function console(parent, pos, facing, name)
	local model = Instance.new("Model")
	model.Name = name
	local cf = CFrame.lookAt(pos, pos + facing)
	local body = P(model, Vector3.new(5, 3.4, 2.4), cf * CFrame.new(0, 1.7, 0), M.Metal, rgb(40, 42, 48))
	body.Name = "Body"
	D(model, Vector3.new(5.4, 0.3, 3), cf * CFrame.new(0, 3.5, -0.2) * CFrame.Angles(math.rad(14), 0, 0), M.Metal, rgb(28, 30, 34))
	local keys = D(model, Vector3.new(3.6, 0.12, 1.2), cf * CFrame.new(0, 3.72, -0.6) * CFrame.Angles(math.rad(14), 0, 0), M.SmoothPlastic, rgb(18, 18, 20))
	grille(keys, N.Top, 86, true, rgb(10, 10, 12), rgb(60, 62, 66), 7)
	D(model, Vector3.new(5, 0.2, 0.2), cf * CFrame.new(0, 0.3, -1.25), M.Neon, rgb(255, 170, 40))
	-- tilted display on a stand
	D(model, Vector3.new(0.4, 2.2, 0.4), cf * CFrame.new(0, 4.6, 0.7), M.Metal, rgb(30, 30, 34))
	D(model, Vector3.new(4.6, 3, 0.3), cf * CFrame.new(0, 6, 0.6) * CFrame.Angles(math.rad(-8), 0, 0), M.Metal, rgb(24, 25, 28))
	local scr = P(model, Vector3.new(4.2, 2.6, 0.1), cf * CFrame.new(0, 6, 0.42) * CFrame.Angles(math.rad(-8), 0, 0), M.Neon, rgb(255, 50, 50), DECO)
	scr.Name = "Screen"
	pointLight(scr, 12, 1.5, rgb(255, 50, 50))
	local gui = make("SurfaceGui", scr, { Face = N.Front, LightInfluence = 0 })
	tx(gui, { Name = "Label", Size = UDim2.fromScale(1, 1), Text = "SENTINEL\nPROTOCOL\nOFFLINE", Font = Enum.Font.Code, TextColor3 = Color3.new(1, 1, 1) })
	-- cable bundle into the floor
	for i = -1, 1 do
		cyl(model, (cf * CFrame.new(i * 0.4, 0.2, 1.3)).Position, (cf * CFrame.new(i * 0.5, 0.2, 3.5)).Position, 0.3, M.Rubber, rgb(22, 22, 24), nil, true)
	end
	-- floor hazard ring
	local ring = D(model, Vector3.new(8, 0.04, 6), cf * CFrame.new(0, 0.02, -0.6), M.SmoothPlastic, rgb(222, 170, 28))
	hazard(ring, N.Top, 8, 10)
	D(model, Vector3.new(7, 0.05, 5), cf * CFrame.new(0, 0.03, -0.6), M.SmoothPlastic, rgb(50, 52, 56))
	make("ProximityPrompt", body, {
		Name = "TerminalPrompt",
		ActionText = "Reboot",
		ObjectText = "Sentinel Protocol",
		HoldDuration = Config.Sentinel.HoldTime,
		MaxActivationDistance = 9,
		RequiresLineOfSight = false,
	})
	model.Parent = parent
	return model
end

local SPOT_KINDS = {
	Locker = { Size = Vector3.new(3, 7.5, 2.6), Material = M.Metal, Color = rgb(70, 86, 104) },
	Cabinet = { Size = Vector3.new(3.5, 7, 3), Material = M.Metal, Color = rgb(96, 100, 104) },
	Freezer = { Size = Vector3.new(6, 8, 6), Material = M.SmoothPlastic, Color = rgb(215, 220, 225) },
	Crate = { Size = Vector3.new(5, 5, 5), Material = M.Metal, Color = rgb(70, 76, 64) },
}

local function hidingSpot(cf, kind)
	local folder = ROOT:FindFirstChild("HidingSpots")
	local k = SPOT_KINDS[kind]
	local s = k.Size
	local t = 0.3
	local model = Instance.new("Model")
	model.Name = kind
	local function panel(size, offset, color)
		return breakable(P(model, size, cf * CFrame.new(offset), k.Material, color or k.Color))
	end
	panel(Vector3.new(s.X, s.Y, t), Vector3.new(0, s.Y / 2, s.Z / 2 - t / 2))
	panel(Vector3.new(t, s.Y, s.Z), Vector3.new(-s.X / 2 + t / 2, s.Y / 2, 0))
	panel(Vector3.new(t, s.Y, s.Z), Vector3.new(s.X / 2 - t / 2, s.Y / 2, 0))
	panel(Vector3.new(s.X, t, s.Z), Vector3.new(0, s.Y - t / 2, 0))
	local door = panel(Vector3.new(s.X - 0.1, s.Y - 0.1, t), Vector3.new(0, s.Y / 2, -s.Z / 2 + t / 2), vary(k.Color, 0.08))
	D(door, Vector3.new(0.2, 1, 0.2), cf * CFrame.new(s.X * 0.32, s.Y * 0.5, -s.Z / 2 - 0.1), M.Metal, rgb(30, 30, 32))
	if kind == "Locker" or kind == "Cabinet" then
		for i = 0, 3 do
			D(door, Vector3.new(s.X * 0.6, 0.08, 0.05), cf * CFrame.new(0, s.Y * 0.78 + i * 0.22, -s.Z / 2 - 0.02), M.Metal, rgb(26, 28, 30))
		end
		local plate = D(door, Vector3.new(s.X * 0.5, 0.5, 0.04), cf * CFrame.new(0, s.Y * 0.62, -s.Z / 2 - 0.03), M.SmoothPlastic, rgb(230, 230, 226))
		stencil(plate, N.Front, kind == "Locker" and ("WX-%03d"):format(rng:NextInteger(1, 400)) or "FILES", rgb(30, 30, 30), 40, Enum.Font.Code)
	elseif kind == "Freezer" then
		D(door, Vector3.new(0.4, 3, 0.5), cf * CFrame.new(s.X * 0.35, s.Y * 0.5, -s.Z / 2 - 0.25), M.Metal, rgb(170, 174, 180))
		local w = D(door, Vector3.new(2.6, 0.9, 0.05), cf * CFrame.new(0, s.Y * 0.8, -s.Z / 2 - 0.03), M.SmoothPlastic, rgb(40, 110, 200))
		stencil(w, N.Front, "COLD STORE  -18°C", Color3.new(1, 1, 1), 40)
	end
	local inside = P(model, Vector3.one, cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, math.pi, 0), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false })
	inside.Name = "Inside"
	local exit = P(model, Vector3.one, cf * CFrame.new(0, 0, -s.Z / 2 - 2.5) * CFrame.Angles(0, math.pi, 0), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false })
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

local spawnPoints = {}
local function spawnAt(x, z)
	table.insert(spawnPoints, Vector3.new(x, F, z))
end

---------------------------------------------------------------------------
-- ATRIUM: Subject X containment
---------------------------------------------------------------------------

local function buildAtrium(parent)
	local r = ROOM.Atrium
	r.Warm = rgb(255, 200, 140)
	floorTiles(parent, r, "Grate")
	ceiling(parent, r, "Truss")
	local y0 = F

	-- floor medallion around the containment cell
	drum(parent, Vector3.new(0, y0 + 0.03, 0), 46, 0.06, M.Metal, rgb(40, 38, 36), nil, true)
	drum(parent, Vector3.new(0, y0 + 0.05, 0), 44, 0.06, M.Neon, rgb(255, 150, 60), nil, true)
	drum(parent, Vector3.new(0, y0 + 0.07, 0), 43.2, 0.06, M.DiamondPlate, rgb(58, 56, 52), nil, true)
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		D(parent, Vector3.new(0.4, 0.06, 4), CFrame.new(0, y0 + 0.1, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -19.5), M.SmoothPlastic, rgb(222, 170, 28))
	end

	-- containment cell: breakable armoured glass on a steel frame
	local cx, cz = 13, 13
	local glassFolder = Instance.new("Model")
	glassFolder.Name = "Containment"
	for _, side in { { -cx, -cz, cx, -cz }, { -cx, cz, cx, cz }, { -cx, -cz, -cx, cz }, { cx, -cz, cx, cz } } do
		local a = Vector3.new(side[1], y0, side[2])
		local b = Vector3.new(side[3], y0, side[4])
		local len = (b - a).Magnitude
		local fcf = CFrame.lookAt(a, b)
		for t = 0, len - 3.25, 3.25 do
			local mid = t + 1.625
			local g = P(glassFolder, Vector3.new(0.5, 12, 3.1), fcf * CFrame.new(0, 7, -mid), M.Glass, rgb(140, 190, 205), { Transparency = 0.6, Reflectance = 0.2 })
			breakable(g)
			g:SetAttribute("NoRegen", true)
			D(g, Vector3.new(0.55, 0.12, 3.1), fcf * CFrame.new(0, 7, -mid), M.Metal, rgb(60, 62, 66), { Transparency = 0.3 })
		end
		for t = 0, len, 3.25 do
			P(glassFolder, Vector3.new(0.8, 12, 0.4), fcf * CFrame.new(0, 7, -t), M.Metal, rgb(46, 44, 42))
		end
		D(glassFolder, Vector3.new(1.4, 1, len + 0.8), fcf * CFrame.new(0, 0.5, -len / 2), M.Metal, rgb(36, 34, 32))
		local top = D(glassFolder, Vector3.new(1.6, 1.2, len + 1.2), fcf * CFrame.new(0, 13.6, -len / 2), M.Metal, rgb(36, 34, 32))
		hazard(top, N.Front, 1.6, 20)
		for s = -1, 1, 2 do
			local strip = D(glassFolder, Vector3.new(0.1, 0.2, len - 1), fcf * CFrame.new(s * 0.72, 12.9, -len / 2), M.Neon, rgb(255, 60, 40))
			tag(strip, "Alarm")
		end
	end
	glassFolder.Parent = parent
	local warn = D(parent, Vector3.new(16, 2.4, 0.2), CFrame.new(0, y0 + 16.4, cz + 0.8) * CFrame.Angles(0, math.pi, 0), M.SmoothPlastic, rgb(20, 20, 22))
	stencil(warn, N.Front, "SUBJECT X — LETHAL — DO NOT OPEN", rgb(255, 70, 50), 30)

	-- the adamantium tank
	local tp = Vector3.new(0, y0, -3)
	drum(parent, tp + Vector3.new(0, 0.7, 0), 15, 1.4, M.Metal, rgb(40, 40, 42))
	drum(parent, tp + Vector3.new(0, 1.6, 0), 13, 0.6, M.DiamondPlate, rgb(70, 68, 64))
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		D(parent, Vector3.new(0.6, 1.2, 1.4), CFrame.new(tp + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -7.2), M.Metal, rgb(54, 52, 50))
	end
	drum(parent, tp + Vector3.new(0, 8.4, 0), 9.4, 13, M.Glass, rgb(170, 220, 230), { Transparency = 0.72, Reflectance = 0.25 })
	local liquid = drum(parent, tp + Vector3.new(0, 7, 0), 8.8, 10, M.Neon, rgb(60, 200, 190), { Transparency = 0.62, CanCollide = false })
	pointLight(liquid, 30, 2.2, rgb(70, 230, 210), true)
	make("ParticleEmitter", liquid, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 14,
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(1.5, 3),
		EmissionDirection = N.Top,
		SpreadAngle = Vector2.new(20, 20),
		Size = NumberSequence.new(0.22, 0.05),
		Transparency = NumberSequence.new(0.3, 1),
		Color = ColorSequence.new(rgb(200, 255, 250)),
		LightEmission = 0.8,
	})
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local p = tp + Vector3.new(math.cos(a) * 4.9, 0, math.sin(a) * 4.9)
		cyl(parent, p + Vector3.new(0, 1.9, 0), p + Vector3.new(0, 14.8, 0), 0.45, M.Metal, rgb(70, 68, 64), nil, true)
	end
	drum(parent, tp + Vector3.new(0, 15.6, 0), 11, 1.8, M.Metal, rgb(46, 44, 42))
	drum(parent, tp + Vector3.new(0, 16.9, 0), 8, 0.8, M.Metal, rgb(64, 62, 58))
	drum(parent, tp + Vector3.new(0, 15.6, 0), 11.2, 0.25, M.Neon, rgb(60, 200, 190), nil, true)
	-- hoses up into the ceiling apparatus
	local yTop = F + r.h
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local base = tp + Vector3.new(math.cos(a) * 3.2, 17.3, math.sin(a) * 3.2)
		local mid = tp + Vector3.new(math.cos(a) * 7, 24, math.sin(a) * 7)
		local top = tp + Vector3.new(math.cos(a) * 11, yTop - 7.5, math.sin(a) * 11)
		pipe(parent, { base, mid, top }, 0.9, rgb(34, 34, 36), M.Rubber, rgb(90, 88, 84))
	end
	-- ceiling ring apparatus
	local ringY = yTop - 7
	for k = 0, 23 do
		local a0, a1 = k / 24 * math.pi * 2, (k + 1) / 24 * math.pi * 2
		local p0 = tp + Vector3.new(math.cos(a0) * 12, ringY, math.sin(a0) * 12)
		local p1 = tp + Vector3.new(math.cos(a1) * 12, ringY, math.sin(a1) * 12)
		cyl(parent, p0, p1, 1.6, M.Metal, rgb(48, 46, 44), nil, true)
		if k % 2 == 0 then
			ball(parent, p0 - Vector3.new(0, 0.9, 0), 0.5, M.Neon, rgb(255, 150, 60), nil, true)
		end
	end
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		cyl(parent, tp + Vector3.new(math.cos(a) * 12, ringY, math.sin(a) * 12), tp + Vector3.new(math.cos(a) * 12, yTop, math.sin(a) * 12), 0.8, M.Metal, rgb(40, 38, 36), nil, true)
		cable(tp + Vector3.new(math.cos(a) * 12, ringY - 0.6, math.sin(a) * 12), tp + Vector3.new(math.cos(a + 0.4) * 5, 17.2, math.sin(a + 0.4) * 5), 3, 0.28)
	end

	-- restraint frame where he wakes
	local rf = Vector3.new(0, y0, 7.5)
	D(parent, Vector3.new(9, 0.8, 0.8), CFrame.new(rf + Vector3.new(0, 9.2, 0)), M.Metal, rgb(40, 38, 36), { CanCollide = true })
	for _, x in { -4.1, 4.1 } do
		P(parent, Vector3.new(0.8, 9.2, 0.8), CFrame.new(rf + Vector3.new(x, 4.6, 0)), M.Metal, rgb(40, 38, 36))
		for _, y in { 3, 6.2 } do
			D(parent, Vector3.new(1.6, 0.5, 0.5), CFrame.new(rf + Vector3.new(x * 0.8, y, 0)), M.Metal, rgb(90, 86, 80))
		end
		cable(rf + Vector3.new(x, 9.4, 0), Vector3.new(x * 2.6, yTop - 7.5, 3), 2, 0.2)
	end
	local spawn = P(ROOT, Vector3.new(2, 1, 2), CFrame.lookAt(Vector3.new(0, y0 + 3.5, 5.6), Vector3.new(0, y0 + 3.5, 30)), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false })
	spawn.Name = "WolverineSpawn"

	-- consoles facing the tank + broken glass & blood story beats
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local p = Vector3.new(math.cos(a) * 24, y0, math.sin(a) * 24)
		local cf = CFrame.lookAt(p, Vector3.new(0, y0, 0))
		desk(parent, cf, 7, true)
		officeChair(parent, cf * CFrame.new(0, 0, 2.6) * CFrame.Angles(0, math.rad(rng:NextNumber(-30, 30)), 0))
	end
	for i = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(14, 19)
		D(parent, Vector3.new(rng:NextNumber(0.3, 1.1), 0.05, rng:NextNumber(0.3, 1.1)), CFrame.new(math.cos(a) * d, y0 + 0.04, math.sin(a) * d) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), M.Glass, rgb(170, 210, 220), { Transparency = 0.4 })
	end
	for i = 1, 9 do
		D(parent, Vector3.new(rng:NextNumber(0.6, 1.8), 0.03, rng:NextNumber(0.6, 1.6)), CFrame.new(rng:NextNumber(-3, 3), y0 + 0.03, 15 + i * 2.6 + rng:NextNumber(-0.6, 0.6)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), M.SmoothPlastic, rgb(70, 6, 6))
	end

	-- structural columns (cover + scale)
	for _, x in { -30, 30 } do
		for _, z in { -30, 30 } do
			local base = Vector3.new(x, y0, z)
			P(parent, Vector3.new(3.4, r.h, 3.4), CFrame.new(base + Vector3.new(0, r.h / 2, 0)), M.Metal, rgb(44, 42, 40))
			for _, y in { 1, 12, 24 } do
				D(parent, Vector3.new(4, 1.4, 4), CFrame.new(base + Vector3.new(0, y, 0)), M.Metal, rgb(34, 33, 32))
			end
			local hz = D(parent, Vector3.new(3.6, 2.2, 3.6), CFrame.new(base + Vector3.new(0, 3, 0)), M.SmoothPlastic, rgb(222, 170, 28))
			for _, f in { N.Front, N.Back, N.Left, N.Right } do
				hazard(hz, f, 3.6, 20)
			end
			for k = 0, 3 do
				local a = k * math.pi / 2
				cyl(parent, base + Vector3.new(math.cos(a) * 2.2, 4.3, math.sin(a) * 2.2), base + Vector3.new(math.cos(a) * 2.2, r.h, math.sin(a) * 2.2), 0.35, M.Metal, rgb(90, 86, 80), nil, true)
			end
			local sc = CFrame.lookAt(base + Vector3.new(0, 8, 0), Vector3.new(0, y0 + 8, 0)) * CFrame.new(0, 0, -1.85)
			screen(parent, sc, 2.8, 1.8, "vitals", rgb(255, 170, 60))
		end
	end

	-- huge wall displays + alarm beacons above the breakable band
	screen(parent, CFrame.new(0, y0 + 24, -41.1) * CFrame.Angles(0, math.pi, 0), 26, 10, "warning")
	screen(parent, CFrame.new(0, y0 + 24, 41.1), 22, 9, "logo", rgb(255, 170, 60))
	screen(parent, CFrame.new(-41.1, y0 + 24, 0) * CFrame.Angles(0, math.rad(-90), 0), 18, 8, "dna", rgb(90, 220, 255))
	screen(parent, CFrame.new(41.1, y0 + 24, 0) * CFrame.Angles(0, math.rad(90), 0), 18, 8, "graph", rgb(255, 170, 60))
	for _, p in { Vector3.new(-40.8, 17, -20), Vector3.new(40.8, 17, 20), Vector3.new(20, 17, -40.8), Vector3.new(-20, 17, 40.8) } do
		local b = ball(parent, p + Vector3.new(0, y0, 0), 1.2, M.Neon, rgb(255, 40, 30), nil, true)
		drum(parent, p + Vector3.new(0, y0 - 0.8, 0), 1.3, 0.5, M.Metal, rgb(30, 30, 32), nil, true)
		local s = make("SpotLight", b, { Range = 50, Brightness = 0, Color = rgb(255, 40, 30), Angle = 45, Face = N.Front })
		lightBudget += 1
		tag(b, "AlarmBeacon")
		s.Name = "Beam"
	end

	-- catwalk ring at 14 studs with two staircases
	local cw = 14
	local cwY = y0 + cw
	local W = 5
	local grateC = rgb(56, 54, 50)
	local runs = {
		{ Vector3.new(-42 + 1.4, cwY, -40.6 + W / 2), Vector3.new(42 - 1.4, cwY, -40.6 + W / 2), "x" },
		{ Vector3.new(-42 + 1.4, cwY, 40.6 - W / 2), Vector3.new(42 - 1.4, cwY, 40.6 - W / 2), "x" },
	}
	for _, rn in runs do
		local a, b = rn[1], rn[2]
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local deck = P(parent, Vector3.new(len, 0.5, W), CFrame.new(mid), M.DiamondPlate, grateC)
		grille(deck, N.Bottom, len * 24, true, rgb(10, 10, 12), rgb(60, 58, 54), 8)
		local inner = mid.Z > 0 and -1 or 1
		local gap = mid.Z > 0 and 36 or -36 -- where the stair lands
		local edgeZ = mid.Z + inner * (W / 2 - 0.15)
		for x = a.X, b.X, 4 do
			D(parent, Vector3.new(0.3, 0.3, W), CFrame.new(x, cwY - 0.8, mid.Z), M.Metal, rgb(40, 38, 36))
			if math.abs(x - gap) > 3 then
				D(parent, Vector3.new(0.25, 3.4, 0.25), CFrame.new(x, cwY + 1.9, edgeZ), M.Metal, rgb(222, 170, 28))
			end
		end
		-- brackets back to the wall
		for x = a.X + 2, b.X, 8 do
			wedge(parent, Vector3.new(0.3, 2.4, 2.4), CFrame.new(x, cwY - 1.45, mid.Z - inner * (W / 2 - 1.2)) * CFrame.Angles(0, inner > 0 and 0 or math.pi, 0) * CFrame.Angles(math.pi, 0, 0), M.Metal, rgb(40, 38, 36))
		end
		for _, seg in { { a.X, gap - 2.6 }, { gap + 2.6, b.X } } do
			local sl = seg[2] - seg[1]
			local sm = (seg[1] + seg[2]) / 2
			P(parent, Vector3.new(sl, 0.2, 0.2), CFrame.new(sm, cwY + 3.5, edgeZ), M.Metal, rgb(222, 170, 28))
			D(parent, Vector3.new(sl, 0.2, 0.2), CFrame.new(sm, cwY + 1.8, edgeZ), M.Metal, rgb(222, 170, 28))
			local kick = D(parent, Vector3.new(sl, 0.5, 0.1), CFrame.new(sm, cwY + 0.5, edgeZ + inner * 0.05), M.SmoothPlastic, rgb(222, 170, 28))
			hazard(kick, inner > 0 and N.Back or N.Front, sl, 12)
			P(parent, Vector3.new(sl, 3.2, 0.1), CFrame.new(sm, cwY + 1.85, edgeZ), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
		end
	end
	-- stairs up to the catwalks (west -> north walk, east -> south walk)
	for _, s in { { x = -36, from = -18, to = -35.6 }, { x = 36, from = 18, to = 35.6 } } do
		local steps = 20
		local dir = s.to > s.from and 1 or -1
		local run = math.abs(s.to - s.from)
		local depth = run / steps
		for i = 0, steps - 1 do
			local z = s.from + dir * (i + 0.5) * depth
			P(parent, Vector3.new(4, 0.4, depth + 0.05), CFrame.new(s.x, y0 + (i + 1) * cw / steps - 0.2, z), M.DiamondPlate, grateC)
			D(parent, Vector3.new(4, 0.08, 0.14), CFrame.new(s.x, y0 + (i + 1) * cw / steps + 0.02, z - dir * (depth / 2 - 0.08)), M.SmoothPlastic, rgb(222, 170, 28))
		end
		local a = Vector3.new(s.x, y0, s.from)
		local b = Vector3.new(s.x, cwY, s.to)
		for _, off in { -2.1, 2.1 } do
			cyl(parent, a + Vector3.new(off, 3.4, 0), b + Vector3.new(off, 3.4, 0), 0.22, M.Metal, rgb(222, 170, 28), nil, true)
			D(parent, Vector3.new(0.3, 1.2, (b - a).Magnitude), CFrame.lookAt(a + Vector3.new(off, -0.5, 0), b + Vector3.new(off, -0.5, 0)) * CFrame.new(0, 0, -(b - a).Magnitude / 2), M.Metal, rgb(40, 38, 36))
			for i = 2, steps - 1, 4 do
				local t = (i + 1) / steps
				local p = a:Lerp(b, t) + Vector3.new(off, 0, 0)
				cyl(parent, p, p + Vector3.new(0, 3.4, 0), 0.18, M.Metal, rgb(222, 170, 28), nil, true)
			end
		end
		cyl(parent, Vector3.new(s.x, y0, s.from + dir * run * 0.7), Vector3.new(s.x, y0 + cw * 0.7 - 0.6, s.from + dir * run * 0.7), 0.7, M.Metal, rgb(40, 38, 36), nil, true)
	end
	-- floor markings
	floorText(parent, Vector3.new(0, y0, 24.5), 0, 14, 3, "CONTAINMENT ZONE — AUTHORISED ONLY", rgb(226, 190, 40))
	floorLine(parent, Vector3.new(-6, y0, 42), Vector3.new(-6, y0, 20), 0.35, rgb(170, 30, 26))
	floorLine(parent, Vector3.new(6, y0, 42), Vector3.new(6, y0, 20), 0.35, rgb(170, 30, 26))
end

---------------------------------------------------------------------------
-- RING CORRIDOR (bunker style)
---------------------------------------------------------------------------

local function buildRing(parent)
	for _, id in { "RingN", "RingS", "RingW", "RingE" } do
		local r = ROOM[id]
		floorTiles(parent, r, "Corridor")
		ceiling(parent, r, "Grate")
		local long = (r.x1 - r.x0) > (r.z1 - r.z0)
		local cx, cz = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
		-- twin red lines down the corridor
		for _, off in { -4.4, -3.8 } do
			if long then
				floorLine(parent, Vector3.new(r.x0 + 1, F, cz + off), Vector3.new(r.x1 - 1, F, cz + off), 0.22, rgb(170, 30, 26))
			else
				floorLine(parent, Vector3.new(cx + off, F, r.z0 + 1), Vector3.new(cx + off, F, r.z1 - 1), 0.22, rgb(170, 30, 26))
			end
		end
	end
	-- benches, bins, wall-mounted monitors and crates along the ring
	for _, b in {
		{ -24, -45.5, 0 }, { 24, -45.5, 0 }, { -24, 52.6, math.pi }, { 24, 52.6, math.pi },
		{ -45.6, -24, math.rad(90) }, { 52.6, 24, math.rad(-90) },
	} do
		if clearAt(b[1], b[2], 1) then
			local cf = CFrame.new(b[1], F, b[2]) * CFrame.Angles(0, b[3], 0)
			P(parent, Vector3.new(6, 0.4, 1.8), cf * CFrame.new(0, 1.8, 0), M.Metal, rgb(170, 172, 176))
			for _, x in { -2.4, 2.4 } do
				D(parent, Vector3.new(0.4, 1.6, 1.6), cf * CFrame.new(x, 0.8, 0), M.Metal, rgb(60, 62, 66))
				wedge(parent, Vector3.new(0.4, 0.8, 1.2), cf * CFrame.new(x, 0.4, 0.9), M.Metal, rgb(60, 62, 66))
			end
		end
	end
	for _, c in { { -52, -52 }, { 52, -52 }, { -52, 52 }, { 52, 52 } } do
		crate(parent, CFrame.new(c[1], F, c[2]) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), 4, "DEPT. H")
		barrel(parent, Vector3.new(c[1] + (c[1] > 0 and -3.6 or 3.6), F, c[2]), rgb(150, 30, 26))
	end
	spawnAt(-30, -49)
	spawnAt(30, 49)
	spawnAt(-49, 30)
	spawnAt(49, -30)
end

---------------------------------------------------------------------------
-- FOUNDRY
---------------------------------------------------------------------------

local function crucible(parent, pos)
	local rust = rgb(78, 58, 46)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local foot = pos + Vector3.new(math.cos(a) * 6.5, 0, math.sin(a) * 6.5)
		P(parent, Vector3.new(1.2, 12, 1.2), CFrame.new(foot + Vector3.new(0, 6, 0)), M.Metal, rgb(40, 38, 36))
		D(parent, Vector3.new(2.4, 0.4, 2.4), CFrame.new(foot + Vector3.new(0, 0.2, 0)), M.Metal, rgb(34, 32, 30))
	end
	drum(parent, pos + Vector3.new(0, 12.4, 0), 15, 0.8, M.Metal, rgb(44, 42, 40))
	drum(parent, pos + Vector3.new(0, 17, 0), 12, 8.4, M.CorrodedMetal, rust)
	ball(parent, pos + Vector3.new(0, 12.6, 0), 11, M.CorrodedMetal, rust, nil, true)
	for _, y in { 14, 17, 20 } do
		drum(parent, pos + Vector3.new(0, y, 0), 12.4, 0.5, M.Metal, rgb(40, 38, 36), nil, true)
	end
	drum(parent, pos + Vector3.new(0, 21.3, 0), 12.6, 0.4, M.Metal, rgb(30, 28, 26), nil, true)
	local molten = drum(parent, pos + Vector3.new(0, 21.2, 0), 10.4, 0.3, M.Neon, rgb(255, 120, 30), nil, true)
	pointLight(molten, 34, 2.6, rgb(255, 130, 50), true)
	make("ParticleEmitter", molten, {
		Rate = 6,
		Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(2, 4),
		EmissionDirection = N.Top,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(rgb(120, 110, 100)),
		RotSpeed = NumberRange.new(-20, 20),
	})
	-- pour spout
	wedge(parent, Vector3.new(3, 2, 4), CFrame.new(pos + Vector3.new(0, 20.6, -7.4)) * CFrame.Angles(0, math.pi, 0), M.CorrodedMetal, rust)
	local label = D(parent, Vector3.new(6, 1.4, 0.1), CFrame.new(pos + Vector3.new(0, 16.4, -6.05)), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
	stencil(label, N.Front, "ADAMANTIUM", rgb(230, 220, 200), 30)
end

local function buildFoundry(parent)
	local r = ROOM.Foundry
	r.Warm = rgb(255, 180, 110)
	floorTiles(parent, r, "Grate")
	ceiling(parent, r, "Truss")
	-- molten channel across the hall, with grates and three bridges
	local cz = -94
	P(parent, Vector3.new(r.x1 - r.x0 - 4, 0.3, 5), CFrame.new(0, F + 0.15, cz), M.Metal, rgb(34, 32, 30))
	local lava = D(parent, Vector3.new(r.x1 - r.x0 - 6, 0.1, 3), CFrame.new(0, F + 0.34, cz), M.Neon, rgb(255, 110, 20))
	for x = r.x0 + 6, r.x1 - 6, 14 do
		pointLight(D(parent, Vector3.new(0.2, 0.2, 0.2), CFrame.new(x, F + 1, cz), M.SmoothPlastic, Color3.new(), { Transparency = 1 }), 16, 1.8, rgb(255, 120, 40))
	end
	local cover = P(parent, Vector3.new(r.x1 - r.x0 - 6, 0.12, 3.2), CFrame.new(0, F + 0.46, cz), M.Metal, rgb(20, 20, 20), { Transparency = 0.9 })
	for x = r.x0 + 4, r.x1 - 4, 0.9 do
		D(parent, Vector3.new(0.22, 0.18, 3.2), CFrame.new(x, F + 0.46, cz), M.Metal, rgb(30, 28, 26))
	end
	for _, x in { -30, 0, 30 } do
		local deck = D(parent, Vector3.new(6, 0.3, 6), CFrame.new(x, F + 0.6, cz), M.DiamondPlate, rgb(80, 76, 70))
		hazard(D(parent, Vector3.new(6, 0.05, 0.6), CFrame.new(x, F + 0.78, cz - 2.7), M.SmoothPlastic, rgb(222, 170, 28)), N.Top, 6, 20)
		hazard(D(parent, Vector3.new(6, 0.05, 0.6), CFrame.new(x, F + 0.78, cz + 2.7), M.SmoothPlastic, rgb(222, 170, 28)), N.Top, 6, 20)
		_ = deck
	end
	_ = lava
	_ = cover
	crucible(parent, Vector3.new(-32, F, -120))
	crucible(parent, Vector3.new(0, F, -126))
	crucible(parent, Vector3.new(32, F, -120))
	-- gantry crane
	local railY = F + 24
	for _, x in { -48, 48 } do
		P(parent, Vector3.new(1.2, 1.8, r.z1 - r.z0 - 4), CFrame.new(x, railY, (r.z0 + r.z1) / 2), M.Metal, rgb(222, 170, 28))
	end
	local bz = -104
	local bridge = D(parent, Vector3.new(98, 2.4, 3), CFrame.new(0, railY + 1.8, bz), M.Metal, rgb(222, 170, 28))
	hazard(bridge, N.Front, 98, 8)
	hazard(bridge, N.Back, 98, 8)
	D(parent, Vector3.new(5, 3, 5), CFrame.new(-8, railY + 0.4, bz), M.Metal, rgb(50, 48, 46))
	cyl(parent, Vector3.new(-8, railY - 1, bz), Vector3.new(-8, F + 14.6, bz), 0.3, M.Metal, rgb(30, 30, 30), nil, true)
	-- hanging ladle
	local lp = Vector3.new(-8, F + 11, bz)
	drum(parent, lp, 6, 5, M.CorrodedMetal, rgb(70, 52, 42), { CanCollide = true })
	drum(parent, lp + Vector3.new(0, 2.6, 0), 6.3, 0.4, M.Metal, rgb(34, 32, 30), nil, true)
	cyl(parent, lp + Vector3.new(-3.3, 1.5, 0), lp + Vector3.new(-3.3, 3.8, 0), 0.4, M.Metal, rgb(34, 32, 30), nil, true)
	cyl(parent, lp + Vector3.new(3.3, 1.5, 0), lp + Vector3.new(3.3, 3.8, 0), 0.4, M.Metal, rgb(34, 32, 30), nil, true)
	cyl(parent, lp + Vector3.new(-3.3, 3.8, 0), lp + Vector3.new(3.3, 3.8, 0), 0.4, M.Metal, rgb(34, 32, 30), nil, true)
	-- conveyor carrying fresh bars to the press
	conveyor(parent, Vector3.new(-24, F, -80), Vector3.new(14, F, -80))
	local press = CFrame.new(20, F, -80)
	P(parent, Vector3.new(8, 3, 7), press * CFrame.new(0, 1.5, 0), M.Metal, rgb(46, 44, 42))
	for _, x in { -3.2, 3.2 } do
		P(parent, Vector3.new(1.2, 14, 1.2), press * CFrame.new(x, 7, 0), M.Metal, rgb(200, 150, 30))
	end
	P(parent, Vector3.new(8, 2.4, 7), press * CFrame.new(0, 13.2, 0), M.Metal, rgb(46, 44, 42))
	D(parent, Vector3.new(5, 3, 5), press * CFrame.new(0, 8.5, 0), M.Metal, rgb(70, 68, 64))
	cyl(parent, (press * CFrame.new(0, 10, 0)).Position, (press * CFrame.new(0, 12, 0)).Position, 2, M.Metal, rgb(200, 204, 212), { Reflectance = 0.3 }, true)
	local hz = D(parent, Vector3.new(8.2, 1, 7.2), press * CFrame.new(0, 2.6, 0), M.SmoothPlastic, rgb(222, 170, 28))
	hazard(hz, N.Front, 8.2, 16)
	hazard(hz, N.Back, 8.2, 16)
	local glow = D(parent, Vector3.new(4, 0.2, 4), press * CFrame.new(0, 3.1, 0), M.Neon, rgb(255, 130, 40))
	pointLight(glow, 12, 1.5, rgb(255, 130, 40))
	for x = -40, 40, 16 do
		cable(Vector3.new(x, F + 24, -60), Vector3.new(x + 6, F + 24, -66), 6, 0.3, rgb(40, 38, 36))
	end
	-- ingot pallets (adamantium bars)
	for i = 0, 5 do
		local base = Vector3.new(-44 + (i % 3) * 7, F, -72 - math.floor(i / 3) * 7)
		P(parent, Vector3.new(4.6, 0.6, 4.6), CFrame.new(base + Vector3.new(0, 0.3, 0)), M.WoodPlanks, rgb(110, 84, 56))
		for layer = 0, 2 do
			for j = 0, 3 do
				local rot = layer % 2 == 0 and 0 or math.pi / 2
				D(parent, Vector3.new(4, 0.6, 0.9), CFrame.new(base + Vector3.new(0, 0.9 + layer * 0.62, 0)) * CFrame.Angles(0, rot, 0) * CFrame.new(0, 0, -1.4 + j * 0.95), M.Metal, rgb(200, 204, 212), { Reflectance = 0.25 })
			end
		end
	end
	-- wall piping with valves
	pipe(parent, { Vector3.new(-54, F + 3, -60), Vector3.new(-54, F + 3, -136), Vector3.new(-54, F + 20, -136) }, 1.6, rgb(120, 70, 30), M.Metal)
	pipe(parent, { Vector3.new(54, F + 4, -136), Vector3.new(54, F + 4, -62), Vector3.new(54, F + 18, -62) }, 1.4, rgb(90, 96, 104), M.Foil)
	pipe(parent, { Vector3.new(-50, F + 22, -138), Vector3.new(50, F + 22, -138) }, 2.2, rgb(60, 58, 56), M.Metal)
	for _, z in { -80, -110, -128 } do
		valveWheel(parent, Vector3.new(-52.8, F + 3, z), Vector3.new(1, 0, 0), 1.6)
	end
	for i = 0, 2 do
		barrel(parent, Vector3.new(40 + i * 3, F, -66), rgb(160, 110, 30))
	end
	crate(parent, CFrame.new(46, F, -76), 4.5, "ADAMANTIUM ORE")
	crate(parent, CFrame.new(46, F + 4.5, -76) * CFrame.Angles(0, 0.3, 0), 3.5, "FRAGILE")
	-- the terminal
	console(ROOT:FindFirstChild("Terminals"), Vector3.new(26, F, -70), Vector3.new(0, 0, 1), "Terminal_Foundry")
	hidingSpot(CFrame.lookAt(Vector3.new(-50, F, -104), Vector3.new(0, F, -104)), "Crate")
	spawnAt(-20, -70)
	spawnAt(20, -110)
	spawnAt(-44, -130)
end

---------------------------------------------------------------------------
-- SENTINEL HANGAR
---------------------------------------------------------------------------

local function sentinelFigure(parent, base)
	local purple = rgb(112, 36, 150)
	local grey = rgb(150, 154, 160)
	local dark = rgb(40, 40, 46)
	local s = 1.9
	local function b(size, off, color, mat)
		return D(parent, size * s, CFrame.new(base + off * s), mat or M.Metal, color, { Reflectance = 0.1 })
	end
	b(Vector3.new(1.2, 3.4, 1.2), Vector3.new(-0.8, 1.7, 0), grey)
	b(Vector3.new(1.2, 3.4, 1.2), Vector3.new(0.8, 1.7, 0), grey)
	b(Vector3.new(1.5, 0.6, 1.9), Vector3.new(-0.8, 0.3, -0.2), purple)
	b(Vector3.new(1.5, 0.6, 1.9), Vector3.new(0.8, 0.3, -0.2), purple)
	b(Vector3.new(3.2, 1.2, 1.8), Vector3.new(0, 3.9, 0), purple)
	b(Vector3.new(3.8, 3, 2.2), Vector3.new(0, 5.9, 0), purple)
	b(Vector3.new(2.4, 1.6, 0.3), Vector3.new(0, 5.6, -1.15), grey)
	local core = b(Vector3.new(0.9, 0.9, 0.2), Vector3.new(0, 6.3, -1.25), rgb(255, 210, 60), M.Neon)
	_ = core
	for _, x in { -2.7, 2.7 } do
		b(Vector3.new(1.8, 1.4, 1.8), Vector3.new(x, 7, 0), purple)
		b(Vector3.new(1.1, 2.6, 1.1), Vector3.new(x, 5.2, 0), grey)
		b(Vector3.new(1.4, 1.8, 1.4), Vector3.new(x, 3.1, 0), purple)
	end
	b(Vector3.new(1.6, 1.7, 1.6), Vector3.new(0, 8.3, 0), purple)
	b(Vector3.new(1.3, 0.35, 0.1), Vector3.new(0, 8.5, -0.82), rgb(255, 210, 60), M.Neon)
	b(Vector3.new(1.7, 0.4, 1.7), Vector3.new(0, 9.2, 0), dark)
end

local function buildHangar(parent)
	local r = ROOM.Hangar
	r.Warm = rgb(235, 225, 210)
	floorTiles(parent, r, "Hangar")
	ceiling(parent, r, "Truss")
	-- painted bay markings
	for _, x in { -16, 16 } do
		floorLine(parent, Vector3.new(x - 9, F, 96), Vector3.new(x + 9, F, 96), 0.5, rgb(226, 190, 40))
		floorLine(parent, Vector3.new(x - 9, F, 132), Vector3.new(x + 9, F, 132), 0.5, rgb(226, 190, 40))
		floorLine(parent, Vector3.new(x - 9, F, 96), Vector3.new(x - 9, F, 132), 0.5, rgb(226, 190, 40), 0.015)
		floorLine(parent, Vector3.new(x + 9, F, 96), Vector3.new(x + 9, F, 132), 0.5, rgb(226, 190, 40), 0.015)
		floorText(parent, Vector3.new(x, F, 92), 0, 14, 3, x < 0 and "SENTINEL BAY 01" or "SENTINEL BAY 02", rgb(226, 190, 40))
	end
	floorLine(parent, Vector3.new(0, F, 58), Vector3.new(0, F, 90), 0.4, rgb(226, 190, 40))
	floorText(parent, Vector3.new(0, F, 74), math.pi / 2, 14, 3, "KEEP CLEAR", rgb(226, 190, 40))

	-- the Sentinel pod: two docked suits in cradles
	local pod = Instance.new("Model")
	pod.Name = "SentinelPod"
	local base = P(pod, Vector3.new(44, 0.8, 30), CFrame.new(0, F + 0.4, 116), M.DiamondPlate, rgb(60, 58, 56))
	local podLight = pointLight(base, 16, 1, rgb(160, 60, 220))
	podLight.Name = "PodLight"
	local dummy = Instance.new("Model")
	dummy.Name = "Dummy"
	for _, x in { -16, 16 } do
		local c = Vector3.new(x, F + 0.8, 118)
		sentinelFigure(dummy, c)
		-- cradle: back frame, clamps, umbilicals, gantry
		D(pod, Vector3.new(10, 22, 1.2), CFrame.new(c + Vector3.new(0, 11, 4.4)), M.Metal, rgb(46, 44, 42))
		for _, cx in { -4.6, 4.6 } do
			P(pod, Vector3.new(1.4, 24, 1.4), CFrame.new(c + Vector3.new(cx, 12, 3)), M.Metal, rgb(222, 170, 28))
			for _, y in { 6, 12, 17 } do
				D(pod, Vector3.new(2.6, 0.8, 3), CFrame.new(c + Vector3.new(cx * 0.8, y, 1.8)), M.Metal, rgb(70, 68, 64))
			end
		end
		D(pod, Vector3.new(12, 1.6, 6), CFrame.new(c + Vector3.new(0, 23.2, 2)), M.Metal, rgb(222, 170, 28))
		for k = -1, 1 do
			cable(c + Vector3.new(k * 2, 22.4, 1), c + Vector3.new(k * 1.2, 14, -0.5), 1.4, 0.35, rgb(24, 24, 26))
		end
		screen(pod, CFrame.new(c + Vector3.new(7.4, 5, -1)) * CFrame.Angles(0, math.rad(20), 0), 3, 2, "bars", rgb(200, 120, 255))
		local ring = D(pod, Vector3.new(13, 0.06, 13), CFrame.new(c + Vector3.new(0, 0.04, -1)), M.SmoothPlastic, rgb(222, 170, 28))
		hazard(ring, N.Top, 13, 10)
		D(pod, Vector3.new(12, 0.08, 12), CFrame.new(c + Vector3.new(0, 0.06, -1)), M.DiamondPlate, rgb(56, 54, 52))
	end
	dummy.Parent = pod
	local beacon = P(pod, Vector3.new(3, r.h, 3), CFrame.new(0, F + r.h / 2, 112), M.Neon, rgb(160, 60, 220), { Transparency = 1, CanCollide = false, CanQuery = false, Shape = Enum.PartType.Cylinder })
	beacon.CFrame = CFrame.new(0, F + r.h / 2, 112) * CFrame.Angles(0, 0, math.rad(90))
	beacon.Size = Vector3.new(r.h, 2.4, 2.4)
	beacon.Name = "Beacon"
	-- central control podium
	local podium = CFrame.new(0, F + 0.8, 106)
	P(pod, Vector3.new(6, 3.4, 3), podium * CFrame.new(0, 1.7, 0), M.Metal, rgb(40, 42, 48))
	screen(pod, podium * CFrame.new(0, 4.6, 0.6) * CFrame.Angles(math.rad(-15), math.pi, 0), 4.4, 2.2, "schematic", rgb(200, 120, 255))
	make("ProximityPrompt", base, {
		Name = "PodPrompt",
		ActionText = "Enter Sentinel Suit",
		ObjectText = "Sentinel Pod",
		HoldDuration = Config.Sentinel.PodHoldTime,
		MaxActivationDistance = 14,
		RequiresLineOfSight = false,
		Enabled = false,
	})
	pod.Parent = ROOT

	-- giant sealed bay door on the south wall
	local door = P(parent, Vector3.new(44, 26, 1.2), CFrame.new(0, F + 13, 138.6), M.Metal, rgb(70, 68, 64))
	for x = -21, 21, 3 do
		D(door, Vector3.new(0.6, 25, 1.8), CFrame.new(x, F + 13, 138.4), M.Metal, rgb(90, 86, 80))
	end
	for _, y in { 6, 13, 20 } do
		D(door, Vector3.new(44, 1, 2), CFrame.new(0, F + y, 138.3), M.Metal, rgb(46, 44, 42))
	end
	local hz = D(door, Vector3.new(44, 2.4, 0.1), CFrame.new(0, F + 1.4, 137.15), M.SmoothPlastic, rgb(222, 170, 28))
	hazard(hz, N.Front, 44, 10)
	D(door, Vector3.new(31, 3.2, 0.2), CFrame.new(0, F + 22.5, 137.2), M.Metal, rgb(26, 26, 28))
	local dl = D(door, Vector3.new(30, 2.6, 0.1), CFrame.new(0, F + 22.5, 137.05), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
	stencil(dl, N.Front, "HANGAR 7 — SENTINEL DEPLOYMENT", rgb(226, 190, 40), 20)

	-- service clutter
	for i = 0, 3 do
		local tank = drum(parent, Vector3.new(-50, F + 3, 70 + i * 5), 3.4, 6, M.Metal, rgb(140, 30, 26))
		breakable(tank)
		drum(tank, Vector3.new(-50, F + 6.2, 70 + i * 5), 1.2, 0.6, M.Metal, rgb(60, 60, 62), nil, true)
	end
	for i = 0, 2 do
		crate(parent, CFrame.new(46, F, 66 + i * 5) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), 4.4, i == 1 and "SENTINEL SPARES" or "TRASK IND.")
	end
	crate(parent, CFrame.new(46, F + 4.4, 71), 3.4, "HANDLE WITH CARE")
	-- a spare Sentinel head on a stand
	local hp = Vector3.new(40, F, 90)
	P(parent, Vector3.new(4, 3, 4), CFrame.new(hp + Vector3.new(0, 1.5, 0)), M.Metal, rgb(46, 44, 42))
	D(parent, Vector3.new(5, 5.2, 5), CFrame.new(hp + Vector3.new(0, 5.6, 0)), M.Metal, rgb(112, 36, 150))
	D(parent, Vector3.new(4, 0.9, 0.2), CFrame.new(hp + Vector3.new(0, 6.3, -2.55)), M.Neon, rgb(255, 210, 60))
	D(parent, Vector3.new(5.2, 1.2, 5.2), CFrame.new(hp + Vector3.new(0, 8.6, 0)), M.Metal, rgb(40, 40, 46))
	hidingSpot(CFrame.lookAt(Vector3.new(-48, F, 124), Vector3.new(0, F, 124)), "Crate")
	scaffold(parent, Vector3.new(-30, F, 104), 6, 5, 16)
	scaffold(parent, Vector3.new(30, F, 104), 6, 5, 16)
	for i = 0, 3 do
		toolChest(parent, CFrame.new(-53, F, 108 + i * 5) * CFrame.Angles(0, math.rad(-90), 0), i % 2 == 0 and rgb(170, 30, 26) or rgb(40, 60, 110))
	end
	cableReel(parent, Vector3.new(24, F, 72), 0.4)
	cableReel(parent, Vector3.new(-20, F, 64), -0.3)
	-- overhead gantry crane
	for _, x in { -52, 52 } do
		P(parent, Vector3.new(1.2, 1.8, 80), CFrame.new(x, F + 28, 98), M.Metal, rgb(222, 170, 28))
	end
	local br = D(parent, Vector3.new(104, 2.4, 3), CFrame.new(0, F + 29.8, 84), M.Metal, rgb(222, 170, 28))
	hazard(br, N.Front, 104, 8)
	hazard(br, N.Back, 104, 8)
	D(parent, Vector3.new(4, 3, 4), CFrame.new(10, F + 28.2, 84), M.Metal, rgb(50, 48, 46))
	cyl(parent, Vector3.new(10, F + 26.6, 84), Vector3.new(10, F + 16, 84), 0.25, M.Metal, rgb(30, 30, 30), nil, true)
	D(parent, Vector3.new(1.4, 1.8, 0.5), CFrame.new(10, F + 15.2, 84), M.Metal, rgb(222, 170, 28))
	spawnAt(-30, 70)
	spawnAt(30, 80)
end

---------------------------------------------------------------------------
-- GENETICS LAB + CRYO VAULT
---------------------------------------------------------------------------

local function labBench(parent, cf, len)
	local white = rgb(222, 226, 228)
	P(parent, Vector3.new(len, 3.1, 3.2), cf * CFrame.new(0, 1.55, 0), M.SmoothPlastic, rgb(160, 166, 172))
	D(parent, Vector3.new(len + 0.3, 0.25, 3.5), cf * CFrame.new(0, 3.2, 0), M.SmoothPlastic, rgb(40, 42, 46))
	for i = 0, math.floor(len / 2) - 1 do
		for _, s in { -1, 1 } do
			D(parent, Vector3.new(1.8, 1.2, 0.08), cf * CFrame.new(-len / 2 + 1 + i * 2, 2.1, s * 1.62), M.SmoothPlastic, white)
			D(parent, Vector3.new(0.6, 0.1, 0.1), cf * CFrame.new(-len / 2 + 1 + i * 2, 2.5, s * 1.68), M.Metal, rgb(60, 62, 66))
		end
	end
	-- equipment on top
	local x = -len / 2 + 1.4
	while x < len / 2 - 1 do
		local pick = rng:NextInteger(1, 4)
		local top = cf * CFrame.new(x, 3.32, rng:NextNumber(-0.6, 0.6))
		if pick == 1 then -- microscope
			D(parent, Vector3.new(0.9, 0.2, 1.2), top * CFrame.new(0, 0.1, 0), M.SmoothPlastic, white)
			D(parent, Vector3.new(0.3, 1.4, 0.3), top * CFrame.new(0, 0.8, 0.4), M.SmoothPlastic, white)
			cyl(parent, (top * CFrame.new(0, 1.3, 0.3)).Position, (top * CFrame.new(0, 1.7, -0.3)).Position, 0.25, M.Metal, rgb(30, 30, 32), nil, true)
		elseif pick == 2 then -- beakers
			for k = 0, 2 do
				local p = (top * CFrame.new(k * 0.5 - 0.5, 0.35, 0)).Position
				drum(parent, p, 0.4, 0.7, M.Glass, rgb(220, 240, 245), { Transparency = 0.6 }, true)
				drum(parent, p - Vector3.new(0, 0.12, 0), 0.34, 0.4, M.Neon, ({ rgb(90, 255, 140), rgb(90, 200, 255), rgb(255, 90, 200) })[k + 1], { Transparency = 0.25 }, true)
			end
		elseif pick == 3 then -- centrifuge
			D(parent, Vector3.new(1.4, 0.8, 1.4), top * CFrame.new(0, 0.4, 0), M.SmoothPlastic, rgb(200, 204, 208))
			drum(parent, (top * CFrame.new(0, 0.82, 0)).Position, 1.1, 0.06, M.Glass, rgb(160, 200, 220), { Transparency = 0.4 }, true)
		else -- monitor
			screen(parent, top * CFrame.new(0, 1, 0) * CFrame.Angles(0, math.pi, 0), 1.8, 1.1, rng:NextNumber() < 0.5 and "dna" or "graph")
		end
		x += rng:NextNumber(2, 3)
	end
end

local function cryoPod(parent, pos, facing, specimen)
	local cf = CFrame.lookAt(pos, pos + facing)
	drum(parent, pos + Vector3.new(0, 0.6, 0), 4.6, 1.2, M.Metal, rgb(170, 176, 182))
	drum(parent, pos + Vector3.new(0, 1.25, 0), 3.8, 0.2, M.Neon, rgb(120, 210, 255), nil, true)
	local glass = drum(parent, pos + Vector3.new(0, 5.2, 0), 3.8, 7.8, M.Glass, rgb(200, 235, 250), { Transparency = 0.55, Reflectance = 0.2 })
	breakable(glass)
	local fog = drum(glass, pos + Vector3.new(0, 5, 0), 3.5, 7.4, M.Neon, rgb(150, 220, 255), { Transparency = 0.78 }, true)
	pointLight(fog, 9, 0.8, rgb(150, 220, 255))
	if specimen then
		-- a frozen silhouette inside
		local d = rgb(60, 70, 80)
		D(glass, Vector3.new(1.4, 1.8, 0.8), cf * CFrame.new(0, 5.4, 0), M.SmoothPlastic, d)
		D(glass, Vector3.new(0.9, 0.9, 0.9), cf * CFrame.new(0, 6.9, 0), M.SmoothPlastic, d)
		D(glass, Vector3.new(0.6, 2, 0.6), cf * CFrame.new(-0.4, 3.5, 0), M.SmoothPlastic, d)
		D(glass, Vector3.new(0.6, 2, 0.6), cf * CFrame.new(0.4, 3.5, 0), M.SmoothPlastic, d)
		D(glass, Vector3.new(0.4, 1.8, 0.4), cf * CFrame.new(-1, 5.3, 0) * CFrame.Angles(0, 0, 0.15), M.SmoothPlastic, d)
		D(glass, Vector3.new(0.4, 1.8, 0.4), cf * CFrame.new(1, 5.3, 0) * CFrame.Angles(0, 0, -0.15), M.SmoothPlastic, d)
	end
	drum(parent, pos + Vector3.new(0, 9.5, 0), 4.6, 1, M.Metal, rgb(170, 176, 182))
	drum(parent, pos + Vector3.new(0, 10.2, 0), 2.6, 0.5, M.Metal, rgb(90, 94, 100), nil, true)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		cyl(parent, pos + Vector3.new(math.cos(a) * 1.95, 1.2, math.sin(a) * 1.95), pos + Vector3.new(math.cos(a) * 1.95, 9, math.sin(a) * 1.95), 0.2, M.Metal, rgb(150, 156, 162), nil, true)
	end
	local plate = D(parent, Vector3.new(2.4, 0.7, 0.1), cf * CFrame.new(0, 0.7, -2.36), M.SmoothPlastic, rgb(20, 24, 30))
	local g = sgui(plate, N.Front, 50, true)
	tx(g, { Size = UDim2.fromScale(1, 1), Text = ("SPECIMEN %03d  -196°C"):format(rng:NextInteger(1, 199)), TextColor3 = rgb(140, 220, 255), Font = Enum.Font.Code })
	cyl(parent, pos + Vector3.new(0, 10.4, 0), pos + Vector3.new(0, 18, 0) + facing * -2, 0.5, M.Rubber, rgb(30, 30, 32), nil, true)
end

local function buildGenetics(parent)
	local r = ROOM.Genetics
	floorTiles(parent, r, "LabTile")
	ceiling(parent, r, "Coffered")
	for i, z in { -36, -12, 12, 36 } do
		labBench(parent, CFrame.new(82, F, z) * CFrame.Angles(0, math.rad(90), 0), 14)
		officeChair(parent, CFrame.new(86.2, F, z + 3) * CFrame.Angles(0, math.rad(90 + i * 20), 0))
	end
	-- DNA hologram table
	local hp = Vector3.new(97, F, 0)
	drum(parent, hp + Vector3.new(0, 1.4, 0), 6, 2.8, M.Metal, rgb(40, 44, 50))
	drum(parent, hp + Vector3.new(0, 2.85, 0), 6.2, 0.12, M.Neon, rgb(80, 200, 255), nil, true)
	drum(parent, hp + Vector3.new(0, 2.9, 0), 5.4, 0.1, M.Glass, rgb(80, 200, 255), { Transparency = 0.5 }, true)
	for i = 0, 26 do
		local t = i / 26
		for s = 0, 1 do
			local a = t * math.pi * 5 + s * math.pi
			ball(parent, hp + Vector3.new(math.cos(a) * 1.4, 3.6 + t * 6, math.sin(a) * 1.4), 0.36, M.ForceField, s == 0 and rgb(80, 200, 255) or rgb(255, 90, 200), nil, true)
		end
		if i % 2 == 0 then
			local a = t * math.pi * 5
			cyl(parent, hp + Vector3.new(math.cos(a) * 1.4, 3.6 + t * 6, math.sin(a) * 1.4), hp + Vector3.new(-math.cos(a) * 1.4, 3.6 + t * 6, -math.sin(a) * 1.4), 0.1, M.ForceField, rgb(120, 220, 255), nil, true)
		end
	end
	pointLight(D(parent, Vector3.one * 0.2, CFrame.new(hp + Vector3.new(0, 6, 0)), M.SmoothPlastic, Color3.new(), { Transparency = 1 }), 16, 1.5, rgb(80, 200, 255))
	-- fume hoods along the north wall
	for x = 64, 100, 9 do
		if not clearAt(x, -52, 2) then
			continue
		end
		local cf = CFrame.new(x, F, -52.2)
		P(parent, Vector3.new(7, 3.2, 3.2), cf * CFrame.new(0, 1.6, 0), M.SmoothPlastic, rgb(200, 206, 210))
		D(parent, Vector3.new(7, 4.2, 0.2), cf * CFrame.new(0, 5.4, -1.5), M.Glass, rgb(200, 220, 230), { Transparency = 0.6 })
		D(parent, Vector3.new(7, 1.4, 3.2), cf * CFrame.new(0, 8.2, 0), M.SmoothPlastic, rgb(200, 206, 210))
		surfaceLight(D(parent, Vector3.new(6.4, 0.1, 2.6), cf * CFrame.new(0, 7.45, 0.1), M.Neon, rgb(230, 240, 255)), N.Bottom, 8, 1, rgb(230, 240, 255))
		cyl(parent, cf.Position + Vector3.new(0, 8.9, 0.6), cf.Position + Vector3.new(0, 20, 0.6), 1.2, M.Foil, rgb(190, 192, 196), nil, true)
	end
	-- whiteboard with notes
	local wb = D(parent, Vector3.new(10, 4.5, 0.2), CFrame.new(68, F + 6.5, 55.1), M.SmoothPlastic, rgb(240, 242, 244))
	local g = sgui(wb, N.Front, 30)
	tx(g, { Position = UDim2.fromScale(0.04, 0.05), Size = UDim2.fromScale(0.92, 0.9), Text = "SUBJECT X — DAY 41\n• bonding holds @ 98%\n• sedation losing effect?!\n• DO NOT enter tank room alone\n• Sentinel protocol = LAST RESORT", TextColor3 = rgb(30, 60, 160), Font = Enum.Font.PermanentMarker, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	for _, x in { 60, 76, 96 } do
		if clearAt(x, 52, 1) then
			plant(parent, Vector3.new(x, F, 52.5), 0.9)
		end
	end
	console(ROOT:FindFirstChild("Terminals"), Vector3.new(100, F, 18), Vector3.new(-1, 0, 0), "Terminal_Genetics")
	hidingSpot(CFrame.lookAt(Vector3.new(104, F, -12), Vector3.new(0, F, -12)), "Cabinet")
	spawnAt(70, 0)
	spawnAt(96, -22)
end

local function buildCryo(parent)
	local r = ROOM.Cryo
	floorTiles(parent, r, "LabTile")
	ceiling(parent, r, "Coffered")
	for i = 0, 6 do
		local z = -44 + i * 14.5
		if clearAt(120, z, 2.5) then
			cryoPod(parent, Vector3.new(120, F, z), Vector3.new(1, 0, 0), i % 2 == 0)
		end
		cryoPod(parent, Vector3.new(152, F, z), Vector3.new(-1, 0, 0), i % 3 ~= 1)
	end
	-- frost haze and cold light
	for z = -40, 40, 20 do
		pointLight(D(parent, Vector3.one * 0.2, CFrame.new(135, F + 4, z), M.SmoothPlastic, Color3.new(), { Transparency = 1 }), 24, 0.7, rgb(150, 210, 255))
	end
	local mist = D(parent, Vector3.new(24, 0.2, 100), CFrame.new(135, F + 0.1, 0), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
	make("ParticleEmitter", mist, {
		Rate = 10,
		Lifetime = NumberRange.new(6, 9),
		Speed = NumberRange.new(0.3, 0.8),
		EmissionDirection = N.Top,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 8) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(rgb(200, 230, 255)),
	})
	local dcf = CFrame.new(146, F, 52) * CFrame.Angles(0, math.pi, 0)
	desk(parent, dcf, 8, true)
	officeChair(parent, dcf * CFrame.new(0, 0, 2.6))
	hidingSpot(CFrame.lookAt(Vector3.new(116, F, 50), Vector3.new(130, F, 50)), "Freezer")
	spawnAt(135, -20)
	spawnAt(135, 30)
end

---------------------------------------------------------------------------
-- COMMAND CENTRE + SERVER CORE
---------------------------------------------------------------------------

local function serverRack(parent, cf)
	local body = P(parent, Vector3.new(2.8, 8.6, 4.6), cf * CFrame.new(0, 4.3, 0), M.Metal, rgb(24, 25, 28))
	breakable(body)
	local front = D(body, Vector3.new(2.5, 8, 0.1), cf * CFrame.new(0, 4.3, -2.32), M.SmoothPlastic, rgb(14, 15, 18))
	local g = sgui(front, N.Front, 16, true)
	fr(g, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(12, 13, 16) })
	for row = 0, 7 do
		fr(g, { Position = UDim2.new(0, 3, 0, 4 + row * 15.5), Size = UDim2.new(1, -6, 0, 13), BackgroundColor3 = rgb(30, 32, 36) })
		for k = 0, 1 do
			local led = fr(g, { Position = UDim2.new(0, 6 + k * 6, 0, 8 + row * 15.5), Size = UDim2.new(0, 3, 0, 3), BackgroundColor3 = rng:NextNumber() < 0.75 and rgb(60, 255, 120) or rgb(255, 150, 40) })
			if rng:NextNumber() < 0.4 then
				led.Name = "Blink"
			end
		end
	end
	tag(front, "LiveScreen")
	D(body, Vector3.new(2.9, 0.3, 4.7), cf * CFrame.new(0, 8.75, 0), M.Metal, rgb(40, 42, 46))
	D(body, Vector3.new(0.12, 7.6, 0.2), cf * CFrame.new(1.2, 4.3, -2.4), M.Metal, rgb(120, 124, 130))
	return body
end

local function buildServers(parent)
	local r = ROOM.Servers
	floorTiles(parent, r, "Rubber")
	ceiling(parent, r, "Grate")
	for _, x in { -150, -140, -130, -120 } do
		for _, zr in { { -44, -8 }, { 8, 44 } } do
			for z = zr[1], zr[2] - 2.9, 3 do
				local facing = (x == -150 or x == -130) and 1 or -1
				serverRack(parent, CFrame.new(x, F, z + 1.5) * CFrame.Angles(0, facing > 0 and math.rad(-90) or math.rad(90), 0))
			end
			-- overhead cable tray
			D(parent, Vector3.new(2.4, 0.3, zr[2] - zr[1]), CFrame.new(x, F + 10.2, (zr[1] + zr[2]) / 2), M.Metal, rgb(90, 94, 100))
			for k = -1, 1 do
				D(parent, Vector3.new(0.3, 0.3, zr[2] - zr[1]), CFrame.new(x + k * 0.6, F + 10.5, (zr[1] + zr[2]) / 2), M.Rubber, ({ rgb(30, 90, 200), rgb(220, 180, 30), rgb(30, 30, 32) })[k + 2])
			end
		end
	end
	-- cold aisle floor light strips
	for _, x in { -145, -125 } do
		for _, zr in { { -44, -8 }, { 8, 44 } } do
			local strip = D(parent, Vector3.new(0.3, 0.05, zr[2] - zr[1]), CFrame.new(x, F + 0.03, (zr[1] + zr[2]) / 2), M.Neon, rgb(60, 170, 255))
			_ = strip
		end
		pointLight(D(parent, Vector3.one * 0.2, CFrame.new(x, F + 1, 0), M.SmoothPlastic, Color3.new(), { Transparency = 1 }), 22, 0.6, rgb(60, 170, 255))
	end
	hidingSpot(CFrame.lookAt(Vector3.new(-157, F, 0), Vector3.new(0, F, 0)), "Cabinet")
	spawnAt(-135, -30)
	spawnAt(-135, 30)
end

local function buildCommand(parent)
	local r = ROOM.Command
	floorTiles(parent, r, "Carpet")
	ceiling(parent, r, "Coffered")
	-- video wall on the north side
	local vw = CFrame.new(-90, F + 9, -54.6) * CFrame.Angles(0, math.pi, 0)
	D(parent, Vector3.new(34, 13, 0.6), vw, M.Metal, rgb(16, 16, 18))
	local kinds = { "schematic", "vitals", "warning", "dna", "graph", "code", "bars", "logo", "code" }
	local k = 0
	for row = 0, 2 do
		for col = 0, 2 do
			k += 1
			screen(parent, vw * CFrame.new(-10.8 + col * 10.8, 4 - row * 4, -0.4), 10.4, 3.8, kinds[k], rgb(90, 200, 255))
		end
	end
	-- two curved rows of consoles facing the wall
	for rowI, rad in { 18, 28 } do
		local centre = Vector3.new(-90, F, -52)
		for i = -2, 2 do
			local a = math.rad(i * (rowI == 1 and 17 or 12))
			local p = centre + Vector3.new(math.sin(a) * rad, 0, math.cos(a) * rad)
			local cf = CFrame.lookAt(p, centre)
			desk(parent, cf, 6, true)
			officeChair(parent, cf * CFrame.new(0, 0, 2.6) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0))
		end
	end
	-- holo map table
	local hp = Vector3.new(-82, F, 20)
	P(parent, Vector3.new(14, 3, 8), CFrame.new(hp + Vector3.new(0, 1.5, 0)), M.Metal, rgb(30, 32, 36))
	D(parent, Vector3.new(14.2, 0.1, 8.2), CFrame.new(hp + Vector3.new(0, 3.05, 0)), M.Neon, rgb(60, 180, 255), { Transparency = 0.3 })
	for _, rm in ROOMS do
		local s = 0.04
		local cx, cz = (rm.x0 + rm.x1) / 2 * s, (rm.z0 + rm.z1) / 2 * s
		D(parent, Vector3.new((rm.x1 - rm.x0) * s - 0.1, rm.h * s * 1.5, (rm.z1 - rm.z0) * s - 0.1), CFrame.new(hp + Vector3.new(cx, 3.1 + rm.h * s * 0.75, cz)), M.ForceField, rm.Id == "Atrium" and rgb(255, 80, 60) or rgb(90, 200, 255))
	end
	console(ROOT:FindFirstChild("Terminals"), Vector3.new(-66, F, -20), Vector3.new(0, 0, 1), "Terminal_Command")
	for _, p in { { -104, 50 }, { -60, 50 } } do
		plant(parent, Vector3.new(p[1], F, p[2]), 1)
	end
	waitingChairs(parent, CFrame.new(-97, F, 53), 4)
	conferenceTable(parent, CFrame.new(-82, F, 40), 16)
	screen(parent, CFrame.new(-57.4, F + 7, 40) * CFrame.Angles(0, math.rad(90), 0), 9, 5, "schematic", rgb(90, 200, 255))
	for i = 0, 3 do
		local body = P(parent, Vector3.new(3, 5, 2.4), CFrame.new(-106, F + 2.5, 24 + i * 3.2), M.Metal, rgb(96, 100, 104))
		breakable(body)
		for k = 0, 2 do
			D(body, Vector3.new(0.05, 1.2, 2), CFrame.new(-104.47, F + 1 + k * 1.5, 24 + i * 3.2), M.Metal, rgb(60, 62, 66))
		end
	end
	spawnAt(-70, 30)
	spawnAt(-100, -10)
end

---------------------------------------------------------------------------
-- REACTOR
---------------------------------------------------------------------------

local function buildReactor(parent)
	local r = ROOM.Reactor
	r.Warm = rgb(200, 220, 255)
	floorTiles(parent, r, "Grate")
	ceiling(parent, r, "Truss")
	local c = Vector3.new(108, F, -98)
	drum(parent, c + Vector3.new(0, 1, 0), 26, 2, M.Metal, rgb(46, 46, 50))
	local ring = D(parent, Vector3.new(0.06, 30, 30), CFrame.new(c + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.SmoothPlastic, rgb(222, 170, 28), { Shape = Enum.PartType.Cylinder })
	_ = ring
	drum(parent, c + Vector3.new(0, 3.5, 0), 18, 3, M.Metal, rgb(70, 72, 78))
	local core = drum(parent, c + Vector3.new(0, 12, 0), 7, 14, M.Neon, rgb(70, 160, 255))
	pointLight(core, 50, 3, rgb(90, 170, 255), true)
	drum(parent, c + Vector3.new(0, 12, 0), 8.4, 14.2, M.Glass, rgb(160, 200, 255), { Transparency = 0.7 })
	for y = 5.5, 18.5, 2.6 do
		drum(parent, c + Vector3.new(0, y, 0), 9.6, 0.6, M.Metal, rgb(60, 62, 68), nil, true)
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		cyl(parent, c + Vector3.new(math.cos(a) * 4.4, 5, math.sin(a) * 4.4), c + Vector3.new(math.cos(a) * 4.4, 19, math.sin(a) * 4.4), 0.6, M.Metal, rgb(80, 82, 88), nil, true)
	end
	drum(parent, c + Vector3.new(0, 20.2, 0), 14, 2.4, M.Metal, rgb(56, 58, 64))
	ball(parent, c + Vector3.new(0, 21.4, 0), 9, M.Metal, rgb(66, 68, 74), nil, true)
	-- coolant loops into the walls
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local wallPt = c + d * 44
		wallPt = Vector3.new(math.clamp(wallPt.X, 58, 158), 0, math.clamp(wallPt.Z, -138, -58))
		pipe(parent, { c + d * 8 + Vector3.new(0, 6, 0), c + d * 16 + Vector3.new(0, 6, 0), c + d * 16 + Vector3.new(0, 18, 0), Vector3.new(wallPt.X, F + 18, wallPt.Z) }, 2.4, rgb(186, 190, 196), M.Foil)
	end
	-- transformers with radiator fins
	for i = 0, 3 do
		local p = Vector3.new(153, F, -130 + i * 16)
		P(parent, Vector3.new(6, 7, 8), CFrame.new(p + Vector3.new(0, 3.5, 0)), M.Metal, rgb(90, 100, 88))
		for f = -3.4, 3.4, 0.6 do
			D(parent, Vector3.new(1.4, 5.6, 0.12), CFrame.new(p + Vector3.new(-3.6, 3.4, f)), M.Metal, rgb(80, 90, 78))
		end
		for _, z in { -2, 0, 2 } do
			cyl(parent, p + Vector3.new(0, 7, z), p + Vector3.new(0, 8.8, z), 0.6, M.SmoothPlastic, rgb(140, 100, 60), nil, true)
		end
		local sg = D(parent, Vector3.new(3, 2, 0.1), CFrame.new(p + Vector3.new(0, 4, -4.06)), M.SmoothPlastic, rgb(230, 190, 30))
		stencil(sg, N.Front, "⚡ 11 kV", rgb(20, 20, 20), 30)
	end
	screen(parent, CFrame.new(108, F + 10, -57.2), 14, 6, "bars", rgb(90, 170, 255))
	turbine(parent, CFrame.new(80, F, -128))
	turbine(parent, CFrame.new(80, F, -72))
	for i = -1, 1 do
		local cf = CFrame.lookAt(Vector3.new(108 + i * 8, F, -66), Vector3.new(108, F, -98))
		desk(parent, cf, 6, true)
		officeChair(parent, cf * CFrame.new(0, 0, 2.6))
	end
	-- catwalk ring around the core
	for k = 0, 23 do
		local a0, a1 = k / 24 * math.pi * 2, (k + 1) / 24 * math.pi * 2
		local p0 = c + Vector3.new(math.cos(a0) * 15, 10, math.sin(a0) * 15)
		local p1 = c + Vector3.new(math.cos(a1) * 15, 10, math.sin(a1) * 15)
		local mid = (p0 + p1) / 2
		D(parent, Vector3.new(4.2, 0.3, (p1 - p0).Magnitude + 0.1), CFrame.lookAt(mid, mid + (p1 - p0)) , M.DiamondPlate, rgb(66, 66, 62))
		cyl(parent, p0 + (p0 - c).Unit * 2 + Vector3.new(0, 3, 0), p1 + (p1 - c).Unit * 2 + Vector3.new(0, 3, 0), 0.18, M.Metal, rgb(222, 170, 28), nil, true)
		if k % 4 == 0 then
			cyl(parent, Vector3.new(p0.X, F, p0.Z) + (p0 - c).Unit * 2, p0 + (p0 - c).Unit * 2, 0.4, M.Metal, rgb(40, 40, 42), nil, true)
		end
	end
	hidingSpot(CFrame.lookAt(Vector3.new(154, F, -134), Vector3.new(108, F, -98)), "Locker")
	spawnAt(138, -76)
	spawnAt(80, -70)
end

---------------------------------------------------------------------------
-- RECORDS ARCHIVE
---------------------------------------------------------------------------

local function shelf(parent, cf, len)
	local frameC = rgb(70, 74, 80)
	for x = -len / 2, len / 2, len / 3 do
		P(parent, Vector3.new(0.3, 12, 3), cf * CFrame.new(x, 6, 0), M.Metal, frameC)
	end
	for y = 0.4, 11.4, 2.75 do
		D(parent, Vector3.new(len, 0.2, 3), cf * CFrame.new(0, y, 0), M.Metal, frameC, { CanCollide = true })
		local x = -len / 2 + 0.6
		while x < len / 2 - 1 do
			local w = rng:NextNumber(1.2, 2.2)
			if rng:NextNumber() < 0.85 then
				D(parent, Vector3.new(w - 0.1, rng:NextNumber(1.2, 2.1), 2.4), cf * CFrame.new(x + w / 2, y + 0.8, rng:NextNumber(-0.2, 0.2)), M.Cardboard, vary(rgb(150, 120, 86), 0.2))
			end
			x += w
		end
	end
end

local function buildArchive(parent)
	local r = ROOM.Archive
	floorTiles(parent, r, "DarkTile")
	ceiling(parent, r, "Coffered")
	for z = -130, -76, 8 do
		shelf(parent, CFrame.new(-138, F, z), 30)
		shelf(parent, CFrame.new(-96, F, z), 30)
	end
	-- reading desk with a warm lamp
	local dcf = CFrame.new(-117, F, -100)
	desk(parent, dcf, 8, true)
	officeChair(parent, dcf * CFrame.new(0, 0, 2.6))
	local lamp = D(parent, Vector3.new(0.8, 0.4, 0.8), dcf * CFrame.new(3, 4.6, -0.4), M.Neon, rgb(255, 200, 130))
	pointLight(lamp, 14, 1.4, rgb(255, 190, 120), true)
	cyl(parent, (dcf * CFrame.new(3, 3.2, -0.4)).Position, (dcf * CFrame.new(3, 4.5, -0.4)).Position, 0.12, M.Metal, rgb(30, 30, 30), nil, true)
	-- scattered files
	for _ = 1, 20 do
		D(parent, Vector3.new(0.9, 0.03, 1.2), CFrame.new(rng:NextNumber(-126, -108), F + 0.03, rng:NextNumber(-114, -86)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), M.SmoothPlastic, rgb(232, 230, 220))
	end
	for i = 0, 2 do
		hidingSpot(CFrame.lookAt(Vector3.new(-157.4, F, -76 - i * 5), Vector3.new(-100, F, -76 - i * 5)), "Cabinet")
	end
	for _, x in { -148, -86 } do
		local cf = CFrame.new(x, F, -64) * CFrame.Angles(0, math.pi, 0)
		desk(parent, cf, 6, true)
		officeChair(parent, cf * CFrame.new(0, 0, 2.6))
	end
	local copier = P(parent, Vector3.new(4, 3.6, 3), CFrame.new(-100, F + 1.8, -62), M.SmoothPlastic, rgb(200, 202, 204))
	breakable(copier)
	D(copier, Vector3.new(3.4, 0.4, 2.2), CFrame.new(-100, F + 3.8, -62.2), M.SmoothPlastic, rgb(60, 62, 66))
	D(copier, Vector3.new(1, 0.2, 0.1), CFrame.new(-99, F + 3.2, -63.55), M.Neon, rgb(60, 255, 120))
	spawnAt(-117, -120)
	spawnAt(-117, -70)
end

---------------------------------------------------------------------------
-- CANTEEN + QUARTERS
---------------------------------------------------------------------------

local function octaTable(parent, pos)
	local top = rgb(150, 154, 160)
	drum(parent, pos + Vector3.new(0, 3, 0), 6.2, 0.3, M.SmoothPlastic, top)
	drum(parent, pos + Vector3.new(0, 2.8, 0), 6.4, 0.14, M.Metal, rgb(90, 94, 100), nil, true)
	cyl(parent, pos + Vector3.new(0, 0.1, 0), pos + Vector3.new(0, 2.9, 0), 0.6, M.Metal, rgb(90, 94, 100), nil, true)
	drum(parent, pos + Vector3.new(0, 0.1, 0), 2.6, 0.2, M.Metal, rgb(90, 94, 100), nil, true)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local s = pos + Vector3.new(math.cos(a) * 4.3, 0, math.sin(a) * 4.3)
		drum(parent, s + Vector3.new(0, 1.9, 0), 1.6, 0.3, M.SmoothPlastic, top)
		cyl(parent, s + Vector3.new(0, 0.1, 0), s + Vector3.new(0, 1.8, 0), 0.25, M.Metal, rgb(90, 94, 100), nil, true)
		if rng:NextNumber() < 0.3 then
			D(parent, Vector3.new(1.2, 0.1, 1.6), CFrame.new(pos + Vector3.new(math.cos(a) * 1.8, 3.2, math.sin(a) * 1.8)) * CFrame.Angles(0, a, 0), M.SmoothPlastic, rgb(60, 110, 150))
		end
	end
end

local function vending(parent, cf, color)
	local body = P(parent, Vector3.new(4, 7.5, 3), cf * CFrame.new(0, 3.75, 0), M.SmoothPlastic, color)
	breakable(body)
	local win = D(body, Vector3.new(2.6, 5, 0.1), cf * CFrame.new(-0.5, 4.3, -1.52), M.Glass, rgb(160, 200, 220), { Transparency = 0.4 })
	pointLight(win, 8, 0.8, rgb(220, 240, 255))
	for row = 0, 4 do
		for col = 0, 3 do
			D(body, Vector3.new(0.45, 0.6, 0.4), cf * CFrame.new(-1.4 + col * 0.6, 2.4 + row * 0.95, -1.2), M.SmoothPlastic, vary(({ rgb(220, 40, 40), rgb(40, 120, 220), rgb(240, 200, 30), rgb(60, 180, 90) })[(row + col) % 4 + 1], 0.2))
		end
	end
	D(body, Vector3.new(0.8, 2.2, 0.1), cf * CFrame.new(1.4, 4.6, -1.52), M.SmoothPlastic, rgb(20, 20, 22))
	D(body, Vector3.new(2.6, 0.8, 0.1), cf * CFrame.new(-0.5, 1, -1.52), M.SmoothPlastic, rgb(20, 20, 22))
end

local function buildCanteen(parent)
	local r = ROOM.Canteen
	floorTiles(parent, r, "LabTile")
	ceiling(parent, r, "Truss")
	for _, x in { 70, 84, 97 } do
		for _, z in { 72, 88, 104, 120 } do
			octaTable(parent, Vector3.new(x, F, z))
		end
	end
	-- serving line along the south wall
	local line = CFrame.new(81, F, 134.6)
	P(parent, Vector3.new(38, 3.4, 3), line * CFrame.new(0, 1.7, 0), M.SmoothPlastic, rgb(200, 204, 208))
	D(parent, Vector3.new(38, 0.2, 3.4), line * CFrame.new(0, 3.5, 0), M.Metal, rgb(160, 164, 170))
	D(parent, Vector3.new(38, 0.2, 0.3), line * CFrame.new(0, 3.2, -2), M.Metal, rgb(160, 164, 170))
	for x = -17, 17, 3.6 do
		D(parent, Vector3.new(3, 0.2, 2.4), line * CFrame.new(x, 3.62, 0), M.Metal, rgb(30, 30, 32))
	end
	D(parent, Vector3.new(38, 2.4, 0.2), line * CFrame.new(0, 5.6, -1.2), M.Glass, rgb(200, 220, 230), { Transparency = 0.6 })
	for x = -15, 15, 10 do
		local lamp = D(parent, Vector3.new(4, 0.2, 1.2), line * CFrame.new(x, 7.4, 0), M.Neon, rgb(255, 214, 160))
		surfaceLight(lamp, N.Bottom, 10, 1, rgb(255, 214, 160))
	end
	vending(parent, CFrame.new(104.8, F, 92) * CFrame.Angles(0, math.rad(90), 0), rgb(160, 20, 24))
	vending(parent, CFrame.new(104.8, F, 100) * CFrame.Angles(0, math.rad(90), 0), rgb(24, 70, 150))
	local menu = D(parent, Vector3.new(10, 3, 0.2), CFrame.new(81, F + 10, 139), M.SmoothPlastic, rgb(20, 20, 22))
	local g = sgui(menu, N.Front, 30, true)
	tx(g, { Size = UDim2.fromScale(1, 1), Text = "CANTEEN — TODAY: MEATLOAF · 06:00–22:00", TextColor3 = rgb(255, 200, 80), Font = Enum.Font.Code })
	hidingSpot(CFrame.lookAt(Vector3.new(60, F, 62), Vector3.new(80, F, 80)), "Freezer")
	spawnAt(76, 96)
	spawnAt(62, 128)
end

local function buildQuarters(parent)
	local r = ROOM.Quarters
	floorTiles(parent, r, "Carpet")
	ceiling(parent, r, "Coffered")
	-- bunk beds
	for i = 0, 4 do
		local cf = CFrame.new(154, F, 66 + i * 10) * CFrame.Angles(0, math.rad(90), 0)
		for _, y in { 1.6, 5.4 } do
			P(parent, Vector3.new(7, 0.5, 3.2), cf * CFrame.new(0, y, 0), M.Metal, rgb(80, 84, 90))
			D(parent, Vector3.new(6.6, 0.5, 2.9), cf * CFrame.new(0, y + 0.5, 0), M.Fabric, rgb(210, 214, 220))
			D(parent, Vector3.new(4.4, 0.2, 3), cf * CFrame.new(0.9, y + 0.8, 0), M.Fabric, rgb(56, 70, 96))
			D(parent, Vector3.new(1.2, 0.4, 2), cf * CFrame.new(-2.7, y + 0.9, 0), M.Fabric, rgb(236, 236, 236))
		end
		for _, x in { -3.4, 3.4 } do
			for _, z in { -1.5, 1.5 } do
				D(parent, Vector3.new(0.3, 8, 0.3), cf * CFrame.new(x, 4, z), M.Metal, rgb(60, 64, 70))
			end
		end
		local foot = P(parent, Vector3.new(3.4, 1.6, 2), cf * CFrame.new(0, 0.8, -3.2), M.Metal, rgb(70, 80, 60))
		breakable(foot)
	end
	-- locker bank (four are hiding spots)
	for i = 0, 9 do
		local pos = Vector3.new(112 + i * 3.1, F, 137.6)
		if i % 3 == 1 then
			hidingSpot(CFrame.lookAt(pos, pos - Vector3.new(0, 0, 1)), "Locker")
		else
			local body = P(parent, Vector3.new(3, 7.5, 2.6), CFrame.new(pos + Vector3.new(0, 3.75, 0)), M.Metal, vary(rgb(70, 86, 104), 0.08))
			breakable(body)
			for k = 0, 3 do
				D(body, Vector3.new(1.8, 0.08, 0.05), CFrame.new(pos + Vector3.new(0, 5.8 + k * 0.22, -1.32)), M.Metal, rgb(26, 28, 30))
			end
		end
	end
	for _, z in { 80, 104 } do
		P(parent, Vector3.new(1.8, 1.6, 8), CFrame.new(130, F + 0.8, z), M.WoodPlanks, rgb(120, 90, 60))
	end
	plant(parent, Vector3.new(112, F, 60), 1)
	for i = 0, 2 do
		local cf = CFrame.new(138, F, 66 + i * 10) * CFrame.Angles(0, math.rad(90), 0)
		P(parent, Vector3.new(7, 0.5, 3.2), cf * CFrame.new(0, 1.6, 0), M.Metal, rgb(80, 84, 90))
		D(parent, Vector3.new(6.6, 0.5, 2.9), cf * CFrame.new(0, 2.1, 0), M.Fabric, rgb(210, 214, 220))
		D(parent, Vector3.new(4.4, 0.25, 3), cf * CFrame.new(0.9, 2.45, 0), M.Fabric, rgb(96, 40, 40))
		D(parent, Vector3.new(1.2, 0.4, 2), cf * CFrame.new(-2.7, 2.5, 0), M.Fabric, rgb(236, 236, 236))
		for _, x in { -3.4, 3.4 } do
			D(parent, Vector3.new(0.3, 2.2, 3.2), cf * CFrame.new(x, 1.1, 0), M.Metal, rgb(60, 64, 70))
		end
	end
	sofa(parent, CFrame.new(122, F, 112) * CFrame.Angles(0, math.rad(90), 0), 3, rgb(70, 40, 36))
	coffeeTable(parent, CFrame.new(128, F, 112) * CFrame.Angles(0, math.rad(90), 0))
	screen(parent, CFrame.new(108.9, F + 6.5, 100) * CFrame.Angles(0, math.rad(-90), 0), 6, 3.4, "code", rgb(120, 255, 160))
	screen(parent, CFrame.new(150, F + 7, 57.3) * CFrame.Angles(0, math.pi, 0), 7, 4, "logo", rgb(255, 170, 60))
	spawnAt(130, 92)
	spawnAt(140, 120)
end

---------------------------------------------------------------------------
-- MEDICAL: reception + surgical theatre
---------------------------------------------------------------------------

local function buildReception(parent)
	local r = ROOM.Reception
	floorTiles(parent, r, "DarkTile")
	ceiling(parent, r, "Coffered")
	-- reception counter
	local c = CFrame.new(-82, F, 108)
	P(parent, Vector3.new(16, 3.8, 3), c * CFrame.new(0, 1.9, 0), M.SmoothPlastic, rgb(40, 42, 48))
	D(parent, Vector3.new(16.4, 0.25, 1.4), c * CFrame.new(0, 4.3, -0.8), M.SmoothPlastic, rgb(120, 126, 132))
	D(parent, Vector3.new(16.2, 0.2, 3.2), c * CFrame.new(0, 3, 0), M.SmoothPlastic, rgb(160, 166, 172))
	local front = D(parent, Vector3.new(10, 1.2, 0.08), c * CFrame.new(0, 2.2, -1.55), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
	stencil(front, N.Front, "MEDICAL INTAKE", rgb(170, 176, 184), 30, Enum.Font.Michroma)
	P(parent, Vector3.new(3, 3.8, 9), c * CFrame.new(-9.5, 1.9, 3), M.SmoothPlastic, rgb(40, 42, 48))
	screen(parent, c * CFrame.new(-3, 4.1, 0.5) * CFrame.Angles(0, math.pi, 0), 1.8, 1.1, "vitals")
	screen(parent, c * CFrame.new(3, 4.1, 0.5) * CFrame.Angles(0, math.pi, 0), 1.8, 1.1, "code")
	officeChair(parent, c * CFrame.new(-2, 0, 2.4))
	officeChair(parent, c * CFrame.new(3, 0, 2.6) * CFrame.Angles(0, 0.6, 0))
	-- waiting area
	waitingChairs(parent, CFrame.new(-82, F, 138), 6)
	waitingChairs(parent, CFrame.new(-104, F, 80) * CFrame.Angles(0, math.rad(-90), 0), 4)
	waitingChairs(parent, CFrame.new(-104, F, 128) * CFrame.Angles(0, math.rad(-90), 0), 4)
	screen(parent, CFrame.new(-82, F + 8, 138.7), 8, 4.5, "logo", rgb(90, 200, 255))
	for _, p in { { -104, 60 }, { -60, 60 }, { -104, 136 }, { -60, 136 }, { -92, 138 }, { -72, 138 } } do
		plant(parent, Vector3.new(p[1], F, p[2]), 1.1)
	end
	-- lounge
	sofa(parent, CFrame.new(-100, F, 94) * CFrame.Angles(0, math.rad(-90), 0), 3)
	sofa(parent, CFrame.new(-94, F, 84) * CFrame.Angles(0, math.pi, 0), 2)
	coffeeTable(parent, CFrame.new(-94, F, 94) * CFrame.Angles(0, math.rad(90), 0))
	screen(parent, CFrame.new(-107.3, F + 7, 94) * CFrame.Angles(0, math.rad(-90), 0), 5, 3, "logo", rgb(90, 200, 255))
	local cs = CFrame.new(-58, F, 128) * CFrame.Angles(0, math.rad(90), 0)
	P(parent, Vector3.new(6, 3.2, 2.4), cs * CFrame.new(0, 1.6, 0), M.WoodPlanks, rgb(60, 44, 32))
	D(parent, Vector3.new(1.4, 1.8, 1.4), cs * CFrame.new(-1.6, 4.1, 0.2), M.Metal, rgb(30, 30, 32))
	D(parent, Vector3.new(0.4, 0.3, 0.1), cs * CFrame.new(-1.6, 4.4, -0.52), M.Neon, rgb(255, 80, 60))
	for k = 0, 3 do
		drum(parent, (cs * CFrame.new(0.6 + k * 0.6, 3.45, 0)).Position, 0.45, 0.5, M.SmoothPlastic, rgb(240, 240, 240), nil, true)
	end
	-- water cooler
	local wc = Vector3.new(-60, F, 118)
	P(parent, Vector3.new(1.8, 3.4, 1.8), CFrame.new(wc + Vector3.new(0, 1.7, 0)), M.SmoothPlastic, rgb(220, 224, 228))
	drum(parent, wc + Vector3.new(0, 4.6, 0), 1.4, 2.4, M.Glass, rgb(120, 180, 255), { Transparency = 0.4 })
	hidingSpot(CFrame.lookAt(Vector3.new(-60, F, 86), Vector3.new(-82, F, 86)), "Cabinet")
	spawnAt(-82, 90)
	spawnAt(-70, 124)
end

local function buildSurgery(parent)
	local r = ROOM.Surgery
	floorTiles(parent, r, "LabTile")
	ceiling(parent, r, "Coffered")
	-- the Weapon X operating table (tilted, with restraints)
	local t = CFrame.new(-134, F, 98)
	P(parent, Vector3.new(4, 3, 4), t * CFrame.new(0, 1.5, 0), M.Metal, rgb(150, 156, 162))
	local bed = t * CFrame.new(0, 3.6, 0) * CFrame.Angles(math.rad(-20), 0, 0)
	P(parent, Vector3.new(3.4, 0.5, 9), bed, M.Metal, rgb(190, 196, 202))
	D(parent, Vector3.new(3.2, 0.2, 8.6), bed * CFrame.new(0, 0.3, 0), M.Leather, rgb(40, 44, 48))
	for _, z in { -3.4, -1, 1.6, 3.6 } do
		D(parent, Vector3.new(3.6, 0.3, 0.5), bed * CFrame.new(0, 0.5, z), M.Leather, rgb(80, 60, 40))
	end
	-- surgical lamp cluster
	local lampBase = Vector3.new(-134, F + r.h - 0.5, 98)
	cyl(parent, lampBase, lampBase - Vector3.new(0, 5, 0), 0.4, M.Metal, rgb(200, 204, 210), nil, true)
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		local p = lampBase - Vector3.new(0, 7, 0) + Vector3.new(math.cos(a) * 2.2, 0, math.sin(a) * 2.2)
		cyl(parent, lampBase - Vector3.new(0, 5, 0), p + Vector3.new(0, 0.6, 0), 0.25, M.Metal, rgb(200, 204, 210), nil, true)
		drum(parent, p, 2.4, 0.8, M.Metal, rgb(220, 224, 228), nil, true)
		local lens = drum(parent, p - Vector3.new(0, 0.45, 0), 2, 0.1, M.Neon, rgb(245, 250, 255), nil, true)
		spotDown(lens, 18, 2, rgb(245, 250, 255), 50, k == 0)
	end
	-- robotic arms + adamantium injection tanks
	for _, s in { -1, 1 } do
		local base = Vector3.new(-134 + s * 6, F, 98)
		drum(parent, base + Vector3.new(0, 0.6, 0), 2.4, 1.2, M.Metal, rgb(60, 62, 66))
		local j1 = base + Vector3.new(0, 5, 0)
		local j2 = base + Vector3.new(-s * 2.5, 8.5, -1)
		local tip = base + Vector3.new(-s * 4.4, 6.4, -1.6)
		cyl(parent, base + Vector3.new(0, 1.2, 0), j1, 0.9, M.Metal, rgb(220, 224, 228), nil, true)
		ball(parent, j1, 1.3, M.Metal, rgb(60, 62, 66), nil, true)
		cyl(parent, j1, j2, 0.7, M.Metal, rgb(220, 224, 228), nil, true)
		ball(parent, j2, 1, M.Metal, rgb(60, 62, 66), nil, true)
		cyl(parent, j2, tip, 0.45, M.Metal, rgb(220, 224, 228), nil, true)
		cyl(parent, tip, tip + (tip - j2).Unit * 1.2, 0.12, M.Metal, rgb(200, 210, 220), { Reflectance = 0.4 }, true)
		local tank = Vector3.new(-134 + s * 12, F, 108)
		drum(parent, tank + Vector3.new(0, 4, 0), 3.2, 8, M.Glass, rgb(210, 220, 230), { Transparency = 0.55 })
		drum(parent, tank + Vector3.new(0, 3.2, 0), 2.8, 6, M.Metal, rgb(200, 204, 212), { Reflectance = 0.4 }, true)
		drum(parent, tank + Vector3.new(0, 8.2, 0), 3.6, 0.6, M.Metal, rgb(60, 62, 66), nil, true)
		cable(tank + Vector3.new(0, 8.4, 0), j2, 1.5, 0.25, rgb(30, 30, 32))
	end
	-- observation windows are on the partition wall; x-ray light boxes
	for i = 0, 2 do
		local lb = D(parent, Vector3.new(3, 3.6, 0.2), CFrame.new(-150 + i * 4, F + 7, 139.2), M.Neon, rgb(210, 230, 255))
		local g = sgui(lb, N.Front, 30, true)
		fr(g, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(20, 30, 40), BackgroundTransparency = 0.2 })
		-- skeleton hand with claws
		for k = 0, 2 do
			fr(g, { Position = UDim2.fromScale(0.3 + k * 0.15, 0.1), Size = UDim2.fromScale(0.04, 0.5), BackgroundColor3 = rgb(230, 240, 255) })
		end
		fr(g, { Position = UDim2.fromScale(0.25, 0.58), Size = UDim2.fromScale(0.5, 0.3), BackgroundColor3 = rgb(190, 205, 220) })
	end
	-- trays, IV stands, curtains
	for i = 0, 3 do
		local p = Vector3.new(-156, F, 64 + i * 7)
		P(parent, Vector3.new(3, 1, 6.4), CFrame.new(p + Vector3.new(0, 1.8, 0)), M.Metal, rgb(170, 176, 182))
		D(parent, Vector3.new(2.8, 0.4, 6), CFrame.new(p + Vector3.new(0, 2.5, 0)), M.Fabric, rgb(220, 230, 235))
		cyl(parent, p + Vector3.new(2.2, 0, -2), p + Vector3.new(2.2, 6.4, -2), 0.12, M.Metal, rgb(180, 184, 190), nil, true)
		D(parent, Vector3.new(0.6, 1, 0.3), CFrame.new(p + Vector3.new(2.2, 5.6, -2)), M.Glass, rgb(200, 240, 255), { Transparency = 0.3 })
		D(parent, Vector3.new(0.1, 8, 6.6), CFrame.new(p + Vector3.new(3.4, 5, 0)), M.Fabric, rgb(120, 170, 170), { Transparency = 0.1 })
	end
	for i = 0, 3 do
		toolChest(parent, CFrame.new(-156, F, 104 + i * 5) * CFrame.Angles(0, math.rad(-90), 0), rgb(200, 204, 210))
	end
	for i = 0, 1 do
		local cart = CFrame.new(-126 + i * 16, F, 124)
		P(parent, Vector3.new(4, 0.2, 2.2), cart * CFrame.new(0, 3.2, 0), M.Metal, rgb(200, 204, 210))
		D(parent, Vector3.new(4, 0.2, 2.2), cart * CFrame.new(0, 1.2, 0), M.Metal, rgb(200, 204, 210))
		for _, x in { -1.8, 1.8 } do
			for _, z in { -0.9, 0.9 } do
				D(parent, Vector3.new(0.15, 3.2, 0.15), cart * CFrame.new(x, 1.6, z), M.Metal, rgb(150, 156, 162))
			end
		end
		for k = 0, 3 do
			D(parent, Vector3.new(0.12, 0.08, 1.4), cart * CFrame.new(-1.2 + k * 0.7, 3.35, 0) * CFrame.Angles(0, 0.2 * k, 0), M.Metal, rgb(210, 220, 230), { Reflectance = 0.4 })
		end
	end
	spawnAt(-120, 70)
	spawnAt(-146, 124)
end

---------------------------------------------------------------------------
-- Walls
---------------------------------------------------------------------------

local function door(At, W, Top)
	return { At = At, W = W, Top = Top or 11 }
end
local function window(At, W, Bottom, Top)
	return { At = At, W = W, Bottom = Bottom or 3.6, Top = Top or 10 }
end

local function buildWalls(parent)
	-- Atrium (84 long walls, doors centred, observation windows)
	wallRun(parent, -42, -42, 42, -42, 40, "Industrial", { door(42, 14, 13), window(18, 12), window(66, 12) }, { Extend = 0.7 })
	wallRun(parent, -42, 42, 42, 42, 40, "Industrial", { door(42, 14, 13), window(18, 12), window(66, 12) }, { Extend = 0.7 })
	wallRun(parent, -42, -42 + 0.7, -42, 42 - 0.7, 40, "Industrial", { door(41.3, 14, 13), window(17.3, 12), window(65.3, 12) })
	wallRun(parent, 42, -42 + 0.7, 42, 42 - 0.7, 40, "Industrial", { door(41.3, 14, 13), window(17.3, 12), window(65.3, 12) })
	-- Ring outer walls
	wallRun(parent, -56, -56, 56, -56, 30, "Concrete", { door(56, 12, 12), door(20, 8, 10), door(92, 8, 10) }, { Extend = 0.7 })
	wallRun(parent, -56, 56, 56, 56, 34, "Concrete", { door(56, 16, 14), door(20, 8, 10), door(92, 8, 10) }, { Extend = 0.7 })
	wallRun(parent, -56, -56 + 0.7, -56, 56 - 0.7, 20, "Concrete", { door(55.3, 10, 11), door(19.3, 8, 10), door(91.3, 8, 10) })
	wallRun(parent, 56, -56 + 0.7, 56, 56 - 0.7, 20, "Concrete", { door(55.3, 10, 11), door(19.3, 8, 10), door(91.3, 8, 10) })
	-- North/south wing separators
	wallRun(parent, 56, -140 + 0.7, 56, -56 - 0.7, 30, "Industrial", { door(42, 10, 11) })
	wallRun(parent, -56, -140 + 0.7, -56, -56 - 0.7, 30, "Industrial", { door(42, 10, 11) })
	wallRun(parent, 56, 56 + 0.7, 56, 140 - 0.7, 34, "Industrial", { door(42, 10, 11) })
	wallRun(parent, -56, 56 + 0.7, -56, 140 - 0.7, 34, "Industrial", { door(42, 10, 11) })
	-- East/west corner separators
	wallRun(parent, 56.7, -56, 160, -56, 26, "Concrete", { door(26, 10, 11), door(78, 10, 11) })
	wallRun(parent, -160, -56, -56.7, -56, 20, "Office", { door(26, 10, 11), door(94, 10, 11) })
	wallRun(parent, 56.7, 56, 160, 56, 20, "Lab", { door(26, 10, 11), door(78, 10, 11) })
	wallRun(parent, -160, 56, -56.7, 56, 20, "Office", { door(26, 10, 11), door(78, 10, 11) })
	-- Partitions inside wings
	wallRun(parent, 108, -56 + 0.7, 108, 56 - 0.7, 20, "Lab", { door(20, 8, 10), door(92, 8, 10), window(38, 14), window(55.3, 8, 3.6, 10), window(73, 14) })
	wallRun(parent, -108, -56 + 0.7, -108, 56 - 0.7, 20, "Dark", { door(55.3, 8, 10), window(20, 14), window(38, 12), window(73, 12), window(91, 14) })
	wallRun(parent, 108, 56 + 0.7, 108, 140 - 0.7, 18, "Office", { door(22, 8, 10), door(62, 8, 10) })
	wallRun(parent, -108, 56 + 0.7, -108, 140 - 0.7, 18, "Lab", { door(42, 8, 10), window(18, 14), window(66, 14) })

	-- Outer shell (unbreakable), styled per room
	local shell = {
		{ -160, -140, -56, -140, "Office" }, { -56, -140, 56, -140, "Industrial" }, { 56, -140, 160, -140, "Industrial" },
		{ -160, 140, -56, 140, "Lab" }, { -56, 140, 56, 140, "Industrial" }, { 56, 140, 160, 140, "Office" },
		{ -160, -140, -160, -56, "Office" }, { -160, -56, -160, 56, "Dark" }, { -160, 56, -160, 140, "Lab" },
		{ 160, -140, 160, -56, "Industrial" }, { 160, -56, 160, 56, "Lab" }, { 160, 56, 160, 140, "Office" },
	}
	for _, s in shell do
		local ax, az, bx, bz = s[1], s[2], s[3], s[4]
		local st = STYLES[s[5]]
		-- sit the shell just outside the rooms
		local ox = (ax == bx) and (ax > 0 and st.T / 2 or -st.T / 2) or 0
		local oz = (az == bz) and (az > 0 and st.T / 2 or -st.T / 2) or 0
		wallRun(parent, ax + ox, az + oz, bx + ox, bz + oz, 41.3, s[5], nil, { Solid = true })
	end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------

local function build()
	rng = Random.new(20260924)
	doorZones = {}
	spawnPoints = {}
	wallCount = 0
	lightBudget = 0

	local map = Instance.new("Model")
	map.Name = "Map"
	ROOT = map
	local function folder(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = map
		return f
	end
	local structure = folder("Structure")
	local props = folder("Props")
	local spawns = folder("Spawns")
	folder("Terminals")
	folder("HidingSpots")
	folder("Debris")

	cableAnchor = P(map, Vector3.one, CFrame.new(), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Name = "CableAnchor" })

	-- foundation slab under everything
	P(structure, Vector3.new(324, 0.6, 284), CFrame.new(0, 0.3, 0), M.Concrete, rgb(30, 31, 34))
	-- roof over the whole complex so it reads as one building from outside
	P(structure, Vector3.new(326, 2, 286), CFrame.new(0, F + 42, 0), M.Concrete, rgb(90, 92, 96))
	P(structure, Vector3.new(326, 0.6, 286), CFrame.new(0, F + 43.3, 0), M.Snow, rgb(228, 234, 242))

	buildWalls(structure)
	buildAtrium(props)
	buildRing(props)
	buildFoundry(props)
	buildHangar(props)
	buildGenetics(props)
	buildCryo(props)
	buildServers(props)
	buildCommand(props)
	buildReactor(props)
	buildArchive(props)
	buildCanteen(props)
	buildQuarters(props)
	buildReception(props)
	buildSurgery(props)

	for i, p in spawnPoints do
		local s = P(spawns, Vector3.new(2, 1, 2), CFrame.new(p + Vector3.new(0, 0.5, 0)), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false })
		s.Name = "Spawn" .. i
	end
	map:SetAttribute("Lights", lightBudget)
	return map
end

-- Built once, then cloned each round (so shredded walls come back instantly).
local template = nil
function Facility.Build()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	if not template then
		template = build()
		local count = 0
		for _, d in template:GetDescendants() do
			if d:IsA("BasePart") then
				count += 1
			end
		end
		print(("[Facility] built: %d parts, %d lights"):format(count, template:GetAttribute("Lights") or 0))
	end
	local map = template:Clone()
	map.Parent = workspace
	return map
end

return Facility
