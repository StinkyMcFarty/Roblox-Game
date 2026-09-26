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
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Costumes = require(script.Parent.Costumes)
local MapBuilder = require(script.Parent.MapBuilder)

local Facility = {}
Facility.DoorBoxes = {}

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
-- Decoration is solid (nothing visible can be walked through) but never
-- query-able, so only wall cores get broken. Invisible helpers stay ghost.
local function D(parent, size, cf, mat, color, extra)
	local p = P(parent, size, cf, mat, color, DECO)
	if extra then
		for k, v in extra do
			p[k] = v
		end
	end
	if p.Transparency < 0.95 and not (extra and extra.CanCollide == false) then
		p.CanCollide = true
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
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local count = math.max(1, math.floor(len / 12))
		-- one section per flange gap so Wolverine can tear out a length of pipe
		for k = 1, count do
			cyl(parent, a + dir * ((k - 1) * len / count), a + dir * (k * len / count), d, mat, color, nil, true)
		end
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
	-- offices: plaster over dark wood panelling
	Office = { T = 1.2, Core = M.Plaster, Upper = rgb(170, 168, 160), Lower = rgb(84, 60, 42), LowerMat = M.WoodPlanks, Line = rgb(44, 32, 24), Cornice = rgb(58, 46, 36), Pil = rgb(96, 92, 86), LowerH = 3.4, Kind = "Office" },
	-- labs, canteen and medical: white ceramic tile over a teal tiled band
	Lab = { T = 1.2, Core = M.CeramicTiles, Upper = rgb(206, 212, 216), Lower = rgb(70, 128, 134), LowerMat = M.CeramicTiles, Line = rgb(38, 44, 48), Cornice = rgb(52, 58, 62), Pil = rgb(150, 158, 164), LowerH = 3.4, Kind = "Office" },
	-- command and servers: steel panels over a diamond-plate kick band
	Dark = { T = 1.2, Core = M.Metal, Upper = rgb(70, 74, 84), Lower = rgb(36, 38, 44), LowerMat = M.DiamondPlate, Line = rgb(18, 20, 24), Cornice = rgb(24, 26, 30), Pil = rgb(44, 48, 56), LowerH = 3.4, Kind = "Office", Glow = rgb(60, 190, 255) },
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
		if a < 0.01 then
			a = 0.012 -- never share the floor plane with the wall core
		end
		if b - a > 0.02 then
			return D(core, Vector3.new(T + extraT, b - a, w - 0.03), at((a + b) / 2), mat or M.SmoothPlastic, color, extra)
		end
	end
	if st.Kind == "Office" then
		band(0, 0.4, 0.36, st.Line)
		band(0.4, st.LowerH, 0.2, st.Lower, st.LowerMat or M.SmoothPlastic)
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
			-- (each style's top trim stops at its own height, so where two
			-- styles meet at a corner their tops never share a plane)
			band(y1 - 0.42, y1 - 0.02, 0.3, st.Line)
		end
	elseif st.Kind == "Industrial" then
		band(0, st.LowerH, 0.6, st.Line, M.DiamondPlate)
		band(7.2, 7.8, 0.64, st.Line, M.Metal)
		if full then
			band(y1 - 1.04, y1 - 0.04, 0.7, st.Line, M.Metal)
		end
		-- vertical ribs
		local top = full and y1 - 1.04 or y1
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
	local header = D(parent, Vector3.new(T + jambT + 0.02, headerH, w + jambT * 2), at(o.Top + headerH / 2 - 0.1, c), mat, frameColor)
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
	-- doorway volume (used by the layout test)
	table.insert(Facility.DoorBoxes, { CFrame = at(o.Top / 2, c), Size = Vector3.new(T + 4, o.Top - 0.4, w - 0.6) })
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
					-- claws clash on painted walls like concrete (see Combat.Surface)
					core:SetAttribute("Surface", st.Core == M.Metal and "Metal" or "Stone")
					if not opts.Solid then
						breakable(core)
					end
					decorate(core, st, at, w, sp[1], sp[2], sp[3], idx)
					-- nothing hung where a door frame's trim would cut through it
					local byFrame = false
					for _, op in openings do
						if math.abs(mid - op.At) < op.W / 2 + w / 2 + 2 then
							byFrame = true
						end
					end
					if sp[3] and not opts.Plain and not byFrame then
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
				D(model, Vector3.new(T + 1.2, 0.9, len - 0.1), frame * CFrame.new(0, y, -len / 2), M.Metal, rgb(34, 33, 32))
			end
			for z = 2, len - 1, 2 do
				D(model, Vector3.new(T + 0.5, uh - 0.2, 0.4), frame * CFrame.new(0, breakH + uh / 2, -z), M.Metal, rgb(70, 66, 60))
			end
		elseif st.Kind == "Concrete" then
			D(model, Vector3.new(T + 0.2, 0.4, len - 0.1), frame * CFrame.new(0, breakH + 0.23, -len / 2), M.SmoothPlastic, st.Line)
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
	if opts.Solid then
		model:SetAttribute("Solid", true)
	end
	model.Parent = parent
	return model, frame
end

---------------------------------------------------------------------------
-- Floors & ceilings
---------------------------------------------------------------------------

-- Every kind of room has its own floor: tiles or slabs with dark grout, a
-- checker of two shades keyed to world position (so tiles line up across
-- rooms), per-tile shade variation, and on the hard floors the odd cracked,
-- stained or scuffed tile.
local FLOORS = {
	-- steel deck: big diamond-plate panels on welded seams
	Grate = { Size = 8, Mat = M.DiamondPlate, A = rgb(100, 104, 110), B = rgb(90, 94, 100), Seam = rgb(22, 23, 26), Gap = 0.18, Vary = 0.06, Wear = true },
	-- bunker corridor: polished concrete slabs with expansion joints
	Corridor = { Size = 8, Mat = M.Concrete, A = rgb(124, 126, 128), B = rgb(114, 116, 119), Seam = rgb(44, 46, 50), Gap = 0.14, Vary = 0.05, Refl = 0.04, Wear = true },
	-- hangar apron: heavy concrete slabs
	Hangar = { Size = 8, Mat = M.Concrete, A = rgb(104, 106, 110), B = rgb(96, 98, 102), Seam = rgb(30, 31, 34), Gap = 0.22, Vary = 0.06, Wear = true },
	-- clinical: pale terrazzo tiles
	LabTile = { Size = 4, Mat = M.Marble, A = rgb(184, 190, 196), B = rgb(166, 172, 180), Seam = rgb(104, 108, 114), Gap = 0.1, Vary = 0.04, Refl = 0.05 },
	-- canteen: cream and charcoal linoleum
	Checker = { Size = 4, Mat = M.SmoothPlastic, A = rgb(198, 194, 182), B = rgb(62, 66, 74), Seam = rgb(40, 42, 46), Gap = 0.06, Vary = 0.04, Wear = true },
	-- server core: raised access floor, every so often a perforated vent panel
	Rubber = { Size = 4, Mat = M.SmoothPlastic, A = rgb(72, 76, 84), B = rgb(66, 70, 78), Seam = rgb(14, 15, 18), Gap = 0.16, Vary = 0.04, Vents = true },
	-- offices: carpet tiles, a slightly different shade each quarter-turn
	Carpet = { Size = 4, Mat = M.Fabric, A = rgb(70, 78, 94), B = rgb(62, 70, 86), Seam = rgb(46, 52, 62), Gap = 0.05, Vary = 0.03 },
	WarmCarpet = { Size = 4, Mat = M.Fabric, A = rgb(104, 90, 80), B = rgb(94, 81, 72), Seam = rgb(62, 54, 48), Gap = 0.05, Vary = 0.03 },
	-- archive: dark slate
	DarkTile = { Size = 4, Mat = M.Slate, A = rgb(84, 86, 92), B = rgb(70, 72, 78), Seam = rgb(18, 19, 22), Gap = 0.16, Vary = 0.06, Wear = true },
}

local function floorTiles(parent, r, kind, x0, z0, x1, z1)
	local f = FLOORS[kind] or FLOORS.DarkTile
	x0, z0, x1, z1 = x0 or r.x0, z0 or r.z0, x1 or r.x1, z1 or r.z1
	local s = f.Size
	local nx, nz = math.max(1, math.floor((x1 - x0) / s + 0.5)), math.max(1, math.floor((z1 - z0) / s + 0.5))
	local sx, sz = (x1 - x0) / nx, (z1 - z0) / nz
	P(parent, Vector3.new(x1 - x0, 0.08, z1 - z0), CFrame.new((x0 + x1) / 2, F - 0.12, (z0 + z1) / 2), M.SmoothPlastic, f.Seam)
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local wx, wz = x0 + (i + 0.5) * sx, z0 + (j + 0.5) * sz
			local even = (math.floor(wx / s) + math.floor(wz / s)) % 2 == 0
			local roll = rng:NextNumber()
			local base = even and f.A or f.B
			if f.Wear and roll < 0.04 then
				base = base:Lerp(rgb(70, 66, 58), 0.35) -- stained
			end
			local tile = P(parent, Vector3.new(sx - f.Gap, 0.12, sz - f.Gap), CFrame.new(wx, F - 0.06, wz), f.Mat, vary(base, f.Vary),
				f.Refl and { Reflectance = f.Refl } or nil)
			if f.Vents and roll > 0.84 then
				-- perforated panel: cold air and a blue glow from the plenum
				grille(tile, N.Top, (sx - f.Gap) * 24, false, rgb(8, 14, 22), rgb(96, 104, 114), 5)
			elseif f.Wear and roll > 0.965 then
				-- a hairline crack across the tile
				local a = rng:NextNumber(-0.8, 0.8)
				D(tile, Vector3.new(0.05, 0.02, sz * 0.8), CFrame.new(wx, F + 0.01, wz) * CFrame.Angles(0, a, 0), M.SmoothPlastic, rgb(40, 42, 46))
				D(tile, Vector3.new(0.04, 0.02, sz * 0.35), CFrame.new(wx, F + 0.012, wz) * CFrame.Angles(0, a + 0.7, 0) * CFrame.new(0, 0, -sz * 0.2), M.SmoothPlastic, rgb(40, 42, 46))
			elseif f.Wear and roll > 0.94 then
				-- boot scuff
				D(tile, Vector3.new(rng:NextNumber(0.8, 1.8), 0.02, rng:NextNumber(0.2, 0.4)), CFrame.new(wx + rng:NextNumber(-1, 1), F + 0.01, wz + rng:NextNumber(-1, 1)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), M.SmoothPlastic, rgb(58, 60, 64), { Transparency = 0.35 })
			end
		end
	end
end

-- painted floor line (sits just above the tiles, never coplanar)
local function floorLine(parent, a, b, width, color, lift)
	local len = (b - a).Magnitude
	D(parent, Vector3.new(width, 0.04, len), CFrame.lookAt(a, b) * CFrame.new(0, 0.02 + (lift or 0), -len / 2), M.SmoothPlastic, color)
end

local function floorText(parent, pos, yaw, w, h, text, color)
	-- a stencil sits over the painted lines (F+0.04 to F+0.055), under the stains (F+0.095)
	local p = D(parent, Vector3.new(w, 0.04, h), CFrame.new(pos + Vector3.new(0, 0.046, 0)) * CFrame.Angles(0, yaw, 0), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
	stencil(p, N.Top, text, color or rgb(226, 190, 40), 20, Enum.Font.GothamBlack)
end

-- Light fittings never cast shadows themselves: a lamp's own shade in front
-- of its light would shadow the very floor it lights.
local function fit(parent, size, cf, mat, color, extra)
	local p = D(parent, size, cf, mat, color, extra)
	p.CastShadow = false
	p.CanCollide = false
	return p
end
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder standing on end

-- A 2x4 ceiling troffer centred at pos (the ceiling's underside): a painted
-- housing, a lipped bezel and a glowing diffuser behind a louvre grid. Every
-- one is lit, and there are few of them.
local function troffer(parent, pos, color, range)
	fit(parent, Vector3.new(3.6, 0.3, 7.6), CFrame.new(pos - Vector3.new(0, 0.2, 0)), M.SmoothPlastic, rgb(206, 210, 216))
	local lens = fit(parent, Vector3.new(3, 0.06, 7), CFrame.new(pos - Vector3.new(0, 0.37, 0)), M.Neon, color)
	for _, s in { -1, 1 } do -- the lip round the diffuser
		fit(parent, Vector3.new(3.3, 0.08, 0.15), CFrame.new(pos + Vector3.new(0, -0.39, s * 3.575)), M.SmoothPlastic, rgb(186, 190, 198))
		fit(parent, Vector3.new(0.15, 0.08, 7.3), CFrame.new(pos + Vector3.new(s * 1.575, -0.39, 0)), M.SmoothPlastic, rgb(186, 190, 198))
	end
	local g = make("SurfaceGui", lens, { Face = N.Bottom, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 20, LightInfluence = 0 })
	local louvre = rgb(150, 156, 168)
	fr(g, { Position = UDim2.new(0.5, -1, 0, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = louvre })
	for k = 1, 5 do
		fr(g, { Position = UDim2.new(0, 0, k / 6, -1), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = louvre })
	end
	surfaceLight(lens, N.Bottom, range, 1.5, color, 125)
end

-- An industrial high-bay hung from the roof at `top` with its lens at lensY:
-- a rod, a finned driver, a stepped reflector and a glowing lens. A wide spot
-- lights the floor under it and a soft fill lights the walls round it.
local function highBay(parent, top, lensY, color, shadows)
	local lens = Vector3.new(top.X, lensY, top.Z)
	local rod = top.Y - lensY - 1.9
	if rod > 0.1 then
		fit(parent, Vector3.new(0.18, rod, 0.18), CFrame.new(lens + Vector3.new(0, 1.9 + rod / 2, 0)), M.Metal, rgb(28, 28, 30))
	end
	fit(parent, Vector3.new(0.8, 1.6, 1.6), CFrame.new(lens + Vector3.new(0, 1.45, 0)) * UPRIGHT, M.Metal, rgb(46, 48, 54), { Shape = Enum.PartType.Cylinder })
	for k = 0, 3 do -- cooling fins
		fit(parent, Vector3.new(2, 0.62, 0.1), CFrame.new(lens + Vector3.new(0, 1.45, 0)) * CFrame.Angles(0, math.rad(k * 45), 0), M.Metal, rgb(62, 64, 70))
	end
	for _, r in { { 2.1, 0.42, 0.86 }, { 2.9, 0.38, 0.47 }, { 3.7, 0.3, 0.13 } } do -- reflector
		fit(parent, Vector3.new(r[2], r[1], r[1]), CFrame.new(lens + Vector3.new(0, r[3], 0)) * UPRIGHT, M.Metal, rgb(84, 88, 96), { Shape = Enum.PartType.Cylinder, Reflectance = 0.1 })
	end
	fit(parent, Vector3.new(0.14, 3.9, 3.9), CFrame.new(lens + Vector3.new(0, -0.02, 0)) * UPRIGHT, M.Metal, rgb(34, 35, 40), { Shape = Enum.PartType.Cylinder })
	fit(parent, Vector3.new(0.08, 3.3, 3.3), CFrame.new(lens + Vector3.new(0, -0.07, 0)) * UPRIGHT, M.Neon, color, { Shape = Enum.PartType.Cylinder })
	-- the light sits just under the lens, so nothing of the fitting is in its way
	local emit = fit(parent, Vector3.new(0.4, 0.2, 0.4), CFrame.new(lens - Vector3.new(0, 0.3, 0)), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
	spotDown(emit, 60, 4.2, color, 120, shadows)
	pointLight(emit, 34, 0.7, color)
end

-- A canteen pendant: an enamel dome shade on a cord over the tables, a warm
-- bulb glowing under it.
local function domePendant(parent, top, lensY, color)
	local lens = Vector3.new(top.X, lensY, top.Z)
	local shade, inner = rgb(38, 44, 40), rgb(226, 222, 206)
	fit(parent, Vector3.new(0.1, top.Y - lensY - 1.3, 0.1), CFrame.new(lens + Vector3.new(0, (top.Y - lensY + 1.3) / 2, 0)), M.Rubber, rgb(20, 20, 22))
	fit(parent, Vector3.new(0.5, 0.5, 0.5), CFrame.new(lens + Vector3.new(0, 1.15, 0)) * UPRIGHT, M.Metal, rgb(160, 150, 120), { Shape = Enum.PartType.Cylinder, Reflectance = 0.2 })
	for _, r in { { 1.2, 0.3, 0.9 }, { 2.2, 0.3, 0.62 }, { 3, 0.26, 0.36 }, { 3.5, 0.2, 0.12 } } do
		fit(parent, Vector3.new(r[2], r[1], r[1]), CFrame.new(lens + Vector3.new(0, r[3], 0)) * UPRIGHT, M.Metal, shade, { Shape = Enum.PartType.Cylinder, Reflectance = 0.08 })
	end
	fit(parent, Vector3.new(0.06, 3.3, 3.3), CFrame.new(lens + Vector3.new(0, 0.03, 0)) * UPRIGHT, M.SmoothPlastic, inner, { Shape = Enum.PartType.Cylinder })
	local bulb = fit(parent, Vector3.new(0.8, 0.8, 0.8), CFrame.new(lens + Vector3.new(0, -0.05, 0)), M.Neon, color, { Shape = Enum.PartType.Ball })
	spotDown(bulb, 40, 3.2, color, 110)
	pointLight(bulb, 22, 0.5, color)
end

-- A caged twin-tube strip light for the corridors: a steel channel with end
-- caps, two glowing tubes and a wire guard across them. `long` runs it along X.
local function caged(parent, pos, long, color, shadows)
	local cf = CFrame.new(pos) * (long and CFrame.Angles(0, math.rad(90), 0) or CFrame.new())
	fit(parent, Vector3.new(1.3, 0.3, 4.6), cf * CFrame.new(0, 0.25, 0), M.Metal, rgb(58, 60, 66))
	for _, z in { -2.22, 2.22 } do -- end caps, a hair bigger than the channel
		fit(parent, Vector3.new(1.36, 0.42, 0.2), cf * CFrame.new(0, 0.1, z), M.Metal, rgb(40, 42, 46))
	end
	for _, x in { -0.3, 0.3 } do
		fit(parent, Vector3.new(4.2, 0.2, 0.2), cf * CFrame.new(x, -0.02, 0) * CFrame.Angles(0, math.rad(90), 0), M.Neon, color, { Shape = Enum.PartType.Cylinder })
	end
	for z = -1.5, 1.5, 1 do -- wire guard
		fit(parent, Vector3.new(1.1, 0.05, 0.05), cf * CFrame.new(0, -0.2, z), M.Metal, rgb(90, 94, 100))
	end
	fit(parent, Vector3.new(0.05, 0.05, 4.2), cf * CFrame.new(0, -0.22, 0), M.Metal, rgb(90, 94, 100))
	local emit = fit(parent, Vector3.new(1, 0.1, 4), cf * CFrame.new(0, -0.3, 0), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
	surfaceLight(emit, N.Bottom, 28, 1.9, color, 130, shadows)
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
		local c = rgb(182, 186, 190)
		D(parent, Vector3.new(sx, 1.4, band), CFrame.new(cx, y - 0.7, r.z0 + band / 2), M.SmoothPlastic, c)
		D(parent, Vector3.new(sx, 1.4, band), CFrame.new(cx, y - 0.7, r.z1 - band / 2), M.SmoothPlastic, c)
		D(parent, Vector3.new(band, 1.4, sz - band * 2), CFrame.new(r.x0 + band / 2, y - 0.7, cz), M.SmoothPlastic, c)
		D(parent, Vector3.new(band, 1.4, sz - band * 2), CFrame.new(r.x1 - band / 2, y - 0.7, cz), M.SmoothPlastic, c)
		-- cove light strip along the soffit edge
		for _, e in { { cx, r.z0 + band + 0.1, sx - band * 2, 0.15 }, { cx, r.z1 - band - 0.1, sx - band * 2, 0.15 } } do
			D(parent, Vector3.new(e[3], 0.12, e[4]), CFrame.new(e[1], y - 1.3, e[2]), M.Neon, rgb(120, 140, 170))
		end
		D(parent, Vector3.new(sx - band * 2, 0.2, sz - band * 2), CFrame.new(cx, y - 0.1, cz), M.Plaster, rgb(200, 202, 204)) -- acoustic tiles
		-- ceiling tile grid
		for x = r.x0 + band + 4, r.x1 - band - 1, 4 do
			D(parent, Vector3.new(0.08, 0.06, sz - band * 2), CFrame.new(x, y - 0.23, cz), M.SmoothPlastic, rgb(128, 132, 138))
		end
		for z = r.z0 + band + 4, r.z1 - band - 1, 4 do
			D(parent, Vector3.new(sx - band * 2, 0.06, 0.08), CFrame.new(cx, y - 0.235, z), M.SmoothPlastic, rgb(128, 132, 138))
		end
		-- troffers fill two cells of the grid, so the grid lines run clear of
		-- their edges: one every 12 studs across and 16 along
		for x = r.x0 + band + 6, r.x1 - band - 4, 12 do
			for z = r.z0 + band + 8, r.z1 - band - 6, 16 do
				troffer(parent, Vector3.new(x, y, z), rgb(232, 238, 248), r.h + 14)
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
			local pos = long and Vector3.new(t, y - 0.95, cz) or Vector3.new(cx, y - 0.95, t)
			D(parent, long and Vector3.new(0.9, 1.9, Wd) or Vector3.new(Wd, 1.9, 0.9), CFrame.new(pos), M.Metal, rgb(150, 150, 152))
			if i < n then
				local mid = t + L / n / 2
				local gp = long and Vector3.new(mid, y - 0.4, cz) or Vector3.new(cx, y - 0.4, mid)
				local g = D(parent, long and Vector3.new(L / n - 1, 0.1, Wd - 4) or Vector3.new(Wd - 4, 0.1, L / n - 1), CFrame.new(gp), M.Metal, rgb(26, 26, 28))
				grille(g, N.Bottom, (long and L / n or Wd) * 24, true, rgb(12, 12, 14), rgb(70, 72, 76), 14)
				if i % 2 == 0 then
					local lp = long and Vector3.new(mid, y - 2.2, cz) or Vector3.new(cx, y - 2.2, mid)
					caged(parent, lp, long, rgb(214, 228, 255), i % 4 == 0)
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
		-- a few strong lamps rather than a crowd of weak ones: about one per
		-- 28 studs each way, hung between the trusses (the containment tank
		-- in the middle of the atrium keeps its own lights)
		local nx = math.max(2, math.floor(sx / 28 + 0.5))
		local nz = math.max(2, math.floor(sz / 28 + 0.5))
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				local x, z = r.x0 + (i + 0.5) * sx / nx, r.z0 + (j + 0.5) * sz / nz
				if not (r.Id == "Atrium" and x * x + z * z < 14 * 14) then
					if r.Lamp == "Dome" then
						domePendant(parent, Vector3.new(x, y, z), y - 6.5, r.Warm or rgb(255, 204, 150))
					else
						highBay(parent, Vector3.new(x, y, z), y - 7.5, r.Warm or rgb(255, 232, 200), (i + j) % 2 == 0)
					end
				end
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

-- An office chair at cf (the sitter faces -Z): a five-star base on casters,
-- a chrome gas lift, a contoured seat with a waterfall front, a curved back
-- with a lumbar pad, and armrests.
local function officeChair(parent, cf)
	local fabric, frame, chrome = rgb(30, 32, 38), rgb(22, 22, 26), rgb(170, 174, 182)
	for k = 0, 4 do
		local a = cf * CFrame.Angles(0, k * math.pi * 2 / 5, 0)
		D(parent, Vector3.new(0.2, 0.16, 1.1), a * CFrame.new(0, 0.34, -0.55) * CFrame.Angles(math.rad(6), 0, 0), M.Metal, frame, { CanCollide = false })
		D(parent, Vector3.new(0.26, 0.26, 0.26), a * CFrame.new(0, 0.14, -1.06), M.SmoothPlastic, rgb(16, 16, 18), { Shape = Enum.PartType.Ball, CanCollide = false })
	end
	cyl(parent, (cf * CFrame.new(0, 0.3, 0)).Position, (cf * CFrame.new(0, 0.9, 0)).Position, 0.36, M.Metal, frame, nil, true)
	cyl(parent, (cf * CFrame.new(0, 0.85, 0)).Position, (cf * CFrame.new(0, 1.55, 0)).Position, 0.2, M.Metal, chrome, { Reflectance = 0.3 }, true)
	D(parent, Vector3.new(1, 0.2, 1), cf * CFrame.new(0, 1.55, 0), M.Metal, frame)
	P(parent, Vector3.new(1.9, 0.18, 1.8), cf * CFrame.new(0, 1.72, 0), M.SmoothPlastic, frame)
	D(parent, Vector3.new(1.8, 0.28, 1.6), cf * CFrame.new(0, 1.93, 0.05), M.Fabric, fabric)
	D(parent, Vector3.new(1.8, 0.34, 0.34), cf * CFrame.new(0, 1.9, -0.78), M.Fabric, fabric, { Shape = Enum.PartType.Cylinder }) -- waterfall front
	D(parent, Vector3.new(0.3, 1.2, 0.18), cf * CFrame.new(0, 2.3, 0.98) * CFrame.Angles(math.rad(12), 0, 0), M.Metal, frame) -- spine
	local back = cf * CFrame.new(0, 3.3, 1.1) * CFrame.Angles(math.rad(10), 0, 0)
	D(parent, Vector3.new(1.8, 2.3, 0.14), back, M.SmoothPlastic, frame)
	D(parent, Vector3.new(1.62, 2.08, 0.2), back * CFrame.new(0, 0.02, -0.16), M.Fabric, fabric)
	D(parent, Vector3.new(1.44, 0.5, 0.12), back * CFrame.new(0, -0.55, -0.3), M.Fabric, rgb(40, 42, 50)) -- lumbar pad
	for _, x in { -0.98, 0.98 } do -- armrests
		D(parent, Vector3.new(0.14, 0.9, 0.14), cf * CFrame.new(x, 2.25, 0.25), M.Metal, frame)
		D(parent, Vector3.new(0.3, 0.12, 1.1), cf * CFrame.new(x, 2.74, 0.1), M.SmoothPlastic, rgb(40, 40, 44))
	end
end

-- An office desk at cf (the sitter is on +Z, the screens on -Z): a laminate
-- top with a dark edge band, a drawer pedestal on the left, a panel leg on
-- the right, a modesty panel, keyboard, mouse, a mug and paperwork.
local function desk(parent, cf, w, withScreens)
	w = w or 6
	local top, body = rgb(60, 64, 72), rgb(42, 44, 50)
	P(parent, Vector3.new(w, 0.2, 3), cf * CFrame.new(0, 3.05, 0), M.SmoothPlastic, top)
	D(parent, Vector3.new(w + 0.06, 0.1, 3.06), cf * CFrame.new(0, 2.9, 0), M.SmoothPlastic, rgb(26, 28, 32)) -- edge band
	local ped = P(parent, Vector3.new(1.8, 2.8, 2.7), cf * CFrame.new(-w / 2 + 1.05, 1.45, 0), M.SmoothPlastic, body)
	for k = 0, 2 do -- drawers
		D(ped, Vector3.new(1.6, 0.8, 0.06), cf * CFrame.new(-w / 2 + 1.05, 0.55 + k * 0.9, 1.37), M.SmoothPlastic, rgb(52, 55, 62))
		D(ped, Vector3.new(0.7, 0.08, 0.1), cf * CFrame.new(-w / 2 + 1.05, 0.75 + k * 0.9, 1.43), M.Metal, rgb(170, 174, 182))
	end
	D(parent, Vector3.new(0.2, 2.8, 2.8), cf * CFrame.new(w / 2 - 0.15, 1.45, 0), M.SmoothPlastic, body) -- panel leg
	D(parent, Vector3.new(w - 2.2, 1.6, 0.1), cf * CFrame.new(0.95, 2.05, -1.35), M.SmoothPlastic, body) -- modesty panel
	if withScreens then
		local n = math.max(1, math.floor(w / 3))
		for i = 0, n - 1 do
			local x = (i - (n - 1) / 2) * 2.8
			local s = cf * CFrame.new(x, 4.6, -0.7) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.rad(-6), 0, 0)
			D(parent, Vector3.new(0.2, 1.2, 0.2), cf * CFrame.new(x, 3.75, -0.9), M.Metal, rgb(40, 40, 44))
			D(parent, Vector3.new(0.9, 0.06, 0.6), cf * CFrame.new(x, 3.18, -0.9), M.Metal, rgb(40, 40, 44)) -- stand foot
			screen(parent, s, 2.4, 1.4)
		end
		local kb = D(parent, Vector3.new(1.9, 0.08, 0.62), cf * CFrame.new(0, 3.19, 0.55), M.SmoothPlastic, rgb(24, 24, 28))
		local kg = sgui(kb, N.Top, 30)
		for row = 0, 3 do
			fr(kg, { Position = UDim2.fromScale(0.03, 0.08 + row * 0.23), Size = UDim2.fromScale(0.94, 0.16), BackgroundColor3 = rgb(70, 72, 80) })
		end
		D(parent, Vector3.new(0.26, 0.1, 0.4), cf * CFrame.new(1.35, 3.2, 0.6), M.SmoothPlastic, rgb(24, 24, 28)) -- mouse
	end
	-- a mug, and papers
	local mx = rng:NextNumber(-w / 2 + 0.5, w / 2 - 0.5)
	D(parent, Vector3.new(0.44, 0.36, 0.36), cf * CFrame.new(mx, 3.37, -0.2) * CFrame.Angles(0, 0, math.rad(90)), M.SmoothPlastic, rng:NextNumber() < 0.5 and rgb(226, 226, 220) or rgb(40, 90, 150), { Shape = Enum.PartType.Cylinder })
	for k = 1, 3 do
		D(parent, Vector3.new(0.85, 0.03, 1.1), cf * CFrame.new(rng:NextNumber(-w / 2 + 0.6, w / 2 - 0.6), 3.14 + k * 0.006, rng:NextNumber(-1, 0.4)) * CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), 0), M.SmoothPlastic, rgb(236, 236, 230))
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
			D(body, Vector3.new(0.34, s + 0.06, 0.34), cf * CFrame.new(x, s / 2 + 0.01, z), M.Metal, rgb(36, 38, 34))
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

-- A lounge sofa at cf (facing -Z) with `seats` places: feet, a piped base,
-- seat cushions with rolled fronts, leaning back cushions, rolled arms and a
-- throw pillow.
local function sofa(parent, cf, seats, color)
	color = color or rgb(40, 52, 76)
	local w = seats * 2.6
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.35)
	for _, x in { -w / 2 - 0.5, w / 2 + 0.5 } do
		for _, z in { -1.1, 1.1 } do
			D(parent, Vector3.new(0.3, 0.42, 0.3), cf * CFrame.new(x, 0.21, z), M.Metal, rgb(30, 30, 34))
		end
	end
	P(parent, Vector3.new(w, 1, 3), cf * CFrame.new(0, 0.92, 0), M.Fabric, color)
	D(parent, Vector3.new(w + 1.44, 0.1, 3.04), cf * CFrame.new(0, 0.46, 0), M.Fabric, dark) -- piping
	for i = 0, seats - 1 do
		local x = -w / 2 + 1.3 + i * 2.6
		D(parent, Vector3.new(2.48, 0.5, 2.4), cf * CFrame.new(x, 1.67, -0.1), M.Fabric, vary(color, 0.05))
		D(parent, Vector3.new(2.44, 0.52, 0.52), cf * CFrame.new(x, 1.66, -1.3), M.Fabric, vary(color, 0.05), { Shape = Enum.PartType.Cylinder })
		D(parent, Vector3.new(2.46, 1.7, 0.5), cf * CFrame.new(x, 2.62, 0.72) * CFrame.Angles(math.rad(8), 0, 0), M.Fabric, vary(color, 0.05))
	end
	D(parent, Vector3.new(w, 2.3, 0.7), cf * CFrame.new(0, 2.25, 1.15), M.Fabric, color)
	for _, x in { -w / 2 - 0.4, w / 2 + 0.4 } do
		D(parent, Vector3.new(0.8, 1.9, 3), cf * CFrame.new(x, 1.4, 0), M.Fabric, color)
		D(parent, Vector3.new(3.06, 0.9, 0.9), cf * CFrame.new(x, 2.35, 0) * CFrame.Angles(0, math.rad(90), 0), M.Fabric, color, { Shape = Enum.PartType.Cylinder })
	end
	D(parent, Vector3.new(1.5, 1.3, 0.4), cf * CFrame.new(-w / 2 + 0.9, 2.5, 0.35) * CFrame.Angles(math.rad(-14), math.rad(20), 0), M.Fabric, rgb(196, 150, 60))
end

-- A coffee table at cf (long side along X): a glass top on a steel frame,
-- a wooden shelf under it with magazines, a mug and a paper on top.
local function coffeeTable(parent, cf)
	local steel = rgb(46, 48, 54)
	P(parent, Vector3.new(4.5, 0.14, 2.4), cf * CFrame.new(0, 1.55, 0), M.Glass, rgb(150, 180, 190), { Transparency = 0.45, Reflectance = 0.15 })
	for _, x in { -2.1, 2.1 } do
		for _, z in { -1.05, 1.05 } do
			D(parent, Vector3.new(0.16, 1.46, 0.16), cf * CFrame.new(x, 0.75, z), M.Metal, steel)
		end
		D(parent, Vector3.new(0.12, 0.12, 2.26), cf * CFrame.new(x, 1.42, 0), M.Metal, steel)
	end
	for _, z in { -1.05, 1.05 } do
		D(parent, Vector3.new(4.36, 0.12, 0.12), cf * CFrame.new(0, 1.42, z), M.Metal, steel)
	end
	D(parent, Vector3.new(4.1, 0.12, 2.0), cf * CFrame.new(0, 0.45, 0), M.WoodPlanks, rgb(92, 62, 40))
	for k, c in { rgb(170, 40, 40), rgb(40, 90, 150) } do
		D(parent, Vector3.new(1.2, 0.05, 1.6), cf * CFrame.new(-0.8 + k * 0.3, 0.53 + k * 0.05, 0) * CFrame.Angles(0, math.rad(k * 12 - 10), 0), M.SmoothPlastic, c)
	end
	D(parent, Vector3.new(0.9, 0.03, 1.2), cf * CFrame.new(0.8, 1.64, 0.2) * CFrame.Angles(0, 0.3, 0), M.SmoothPlastic, rgb(230, 230, 224))
	drum(parent, (cf * CFrame.new(-1, 1.84, 0)).Position, 0.46, 0.44, M.SmoothPlastic, rgb(240, 240, 240), nil, true)
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

-- A Sentinel protocol terminal (the operator stands on the `facing` side):
-- a steel cabinet between raised side cheeks, with a vent grille, status
-- lamps and a warning plate; a sloped control deck with a keyboard, toggles
-- and a red emergency stop; a hooded monitor on two posts (red OFFLINE until
-- a survivor repairs it, then green); cables from a junction box into the
-- floor. The parts gameplay uses are "Body" (the prompt) and "Screen" (with
-- its light and Label).
local function console(parent, pos, facing, name)
	local model = Instance.new("Model")
	model.Name = name
	local cf = CFrame.lookAt(pos, pos + facing)
	local gun, steel, dark = rgb(50, 54, 62), rgb(84, 90, 100), rgb(26, 27, 31)
	D(model, Vector3.new(5.4, 0.3, 3.4), cf * CFrame.new(0, 0.15, 0.1), M.Metal, dark)
	local body = P(model, Vector3.new(4.6, 3.1, 2.4), cf * CFrame.new(0, 1.85, 0.1), M.Metal, gun)
	body.Name = "Body"
	for _, s in { -1, 1 } do -- side cheeks, standing proud of the front
		D(model, Vector3.new(0.34, 3.6, 2.9), cf * CFrame.new(s * 2.44, 2.1, 0.05), M.Metal, steel)
		D(model, Vector3.new(0.38, 0.5, 2.96), cf * CFrame.new(s * 2.44, 0.55, 0.05), M.DiamondPlate, dark) -- kick plate
	end
	-- the front: a recessed panel, a vent grille, a warning plate, status lamps
	D(model, Vector3.new(4.1, 2.4, 0.08), cf * CFrame.new(0, 1.8, -1.12), M.SmoothPlastic, rgb(36, 39, 45))
	local vent = D(model, Vector3.new(3.2, 0.7, 0.05), cf * CFrame.new(-0.2, 0.95, -1.18), M.Metal, dark)
	grille(vent, N.Front, 3.2 * 24, false, rgb(10, 10, 12), rgb(72, 76, 84), 5)
	local plate = D(model, Vector3.new(2.3, 0.42, 0.04), cf * CFrame.new(-0.6, 2.55, -1.17), M.SmoothPlastic, rgb(226, 180, 36))
	stencil(plate, N.Front, "SENTINEL PROTOCOL", rgb(20, 18, 14), 40, Enum.Font.GothamBlack)
	for k, c in { rgb(255, 60, 50), rgb(255, 170, 40), rgb(40, 90, 50) } do
		D(model, Vector3.new(0.2, 0.2, 0.06), cf * CFrame.new(1.55, 2.75 - k * 0.3, -1.18), M.Neon, c)
		D(model, Vector3.new(0.3, 0.3, 0.04), cf * CFrame.new(1.55, 2.75 - k * 0.3, -1.165), M.Metal, dark)
	end
	for _, x in { -1.9, 1.9 } do -- access panel handles
		D(model, Vector3.new(0.1, 0.8, 0.1), cf * CFrame.new(x, 1.7, -1.22), M.Metal, rgb(150, 154, 162))
	end
	-- sloped control deck
	local deck = cf * CFrame.new(0, 3.55, -0.5) * CFrame.Angles(math.rad(-20), 0, 0)
	D(model, Vector3.new(4.6, 0.26, 2.1), deck, M.Metal, steel)
	D(model, Vector3.new(4.5, 0.3, 0.2), deck * CFrame.new(0, 0.04, -1.1), M.Rubber, dark) -- padded front lip
	local kb = D(model, Vector3.new(2.5, 0.06, 0.95), deck * CFrame.new(-0.55, 0.15, 0.1), M.SmoothPlastic, rgb(20, 20, 24))
	local kg = sgui(kb, N.Top, 40)
	for row = 0, 3 do
		for col = 0, 11 do
			local key = fr(kg, { Position = UDim2.fromScale(0.02 + col * 0.081, 0.08 + row * 0.23), Size = UDim2.fromScale(0.07, 0.18), BackgroundColor3 = row == 3 and col > 3 and col < 8 and rgb(150, 154, 162) or rgb(92, 96, 106) })
			make("UICorner", key, { CornerRadius = UDim.new(0.2, 0) })
		end
	end
	for k = 0, 4 do -- a row of toggles
		D(model, Vector3.new(0.22, 0.12, 0.22), deck * CFrame.new(-1.75 + k * 0.5, 0.18, -0.65), M.Metal, dark)
		D(model, Vector3.new(0.07, 0.3, 0.07), deck * CFrame.new(-1.75 + k * 0.5, 0.3, -0.68) * CFrame.Angles(math.rad(k % 2 == 0 and 25 or -25), 0, 0), M.Metal, rgb(190, 194, 202))
	end
	-- the emergency stop: a red mushroom in a yellow collar
	D(model, Vector3.new(0.08, 0.9, 0.9), deck * CFrame.new(1.45, 0.16, 0.05) * CFrame.Angles(0, 0, math.rad(90)), M.SmoothPlastic, rgb(230, 190, 30), { Shape = Enum.PartType.Cylinder })
	D(model, Vector3.new(0.3, 0.36, 0.36), deck * CFrame.new(1.45, 0.3, 0.05) * CFrame.Angles(0, 0, math.rad(90)), M.Metal, dark, { Shape = Enum.PartType.Cylinder })
	D(model, Vector3.new(0.22, 0.6, 0.6), deck * CFrame.new(1.45, 0.52, 0.05) * CFrame.Angles(0, 0, math.rad(90)), M.SmoothPlastic, rgb(200, 24, 24), { Shape = Enum.PartType.Cylinder })
	-- hooded monitor on two posts
	for _, x in { -1.3, 1.3 } do
		D(model, Vector3.new(0.26, 2, 0.26), cf * CFrame.new(x, 4.3, 0.95), M.Metal, dark)
	end
	local mon = cf * CFrame.new(0, 5.9, 0.85) * CFrame.Angles(math.rad(-8), 0, 0)
	D(model, Vector3.new(4.7, 3.1, 0.4), mon, M.Metal, rgb(34, 36, 42))
	D(model, Vector3.new(5, 0.16, 0.9), mon * CFrame.new(0, 1.62, -0.3) * CFrame.Angles(math.rad(-10), 0, 0), M.Metal, steel) -- hood
	for _, s in { -1, 1 } do
		D(model, Vector3.new(0.16, 3.1, 0.7), mon * CFrame.new(s * 2.43, 0, -0.2), M.Metal, steel) -- side blinkers
	end
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		D(model, Vector3.new(0.34, 0.34, 0.06), mon * CFrame.new(c[1] * 2.1, c[2] * 1.3, -0.23), M.Metal, steel) -- corner plates
	end
	local scr = P(model, Vector3.new(3.9, 2.4, 0.1), mon * CFrame.new(0, 0, -0.2), M.Neon, rgb(255, 50, 50), DECO)
	scr.Name = "Screen"
	pointLight(scr, 12, 1.5, rgb(255, 50, 50))
	local gui = make("SurfaceGui", scr, { Face = N.Front, LightInfluence = 0 })
	tx(gui, { Name = "Label", Size = UDim2.fromScale(1, 1), Text = "SENTINEL\nPROTOCOL\nOFFLINE", Font = Enum.Font.Code, TextColor3 = Color3.new(1, 1, 1) })
	-- junction box and cables down into the floor
	D(model, Vector3.new(1.8, 1.2, 0.4), cf * CFrame.new(0, 1.9, 1.5), M.Metal, steel)
	for i = -1, 1 do
		cyl(model, (cf * CFrame.new(i * 0.45, 1.5, 1.62)).Position, (cf * CFrame.new(i * 0.5, 0.22, 2.2)).Position, 0.26, M.Rubber, rgb(22, 22, 24), nil, true)
		cyl(model, (cf * CFrame.new(i * 0.5, 0.2, 2.2)).Position, (cf * CFrame.new(i * 0.6, 0.2, 3.6)).Position, 0.3, M.Rubber, rgb(22, 22, 24), nil, true)
	end
	-- floor hazard ring
	local ring = D(model, Vector3.new(8, 0.04, 6), cf * CFrame.new(0, 0.02, -0.6), M.SmoothPlastic, rgb(222, 170, 28))
	hazard(ring, N.Top, 8, 10)
	D(model, Vector3.new(7, 0.05, 5), cf * CFrame.new(0, 0.03, -0.6), M.SmoothPlastic, rgb(50, 52, 56))
	make("ProximityPrompt", body, {
		Name = "TerminalPrompt",
		ActionText = "Repair",
		ObjectText = "Sentinel Protocol",
		HoldDuration = 0.25,
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
	panel(Vector3.new(t, s.Y - t, s.Z - t * 2), Vector3.new(-s.X / 2 + t / 2, (s.Y - t) / 2, 0))
	panel(Vector3.new(t, s.Y - t, s.Z - t * 2), Vector3.new(s.X / 2 - t / 2, (s.Y - t) / 2, 0))
	panel(Vector3.new(s.X + 0.04, t, s.Z + 0.04), Vector3.new(0, s.Y - t / 2 + 0.005, 0))
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
	local tankGlass = drum(parent, tp + Vector3.new(0, 8.4, 0), 9.4, 13, M.Glass, rgb(170, 220, 230), { Transparency = 0.72, Reflectance = 0.25 })
	tankGlass.Name = "TankGlass" -- Wolverine smashes out of this in the intro
	tankGlass:SetAttribute("Solid", true)
	local liquid = drum(parent, tp + Vector3.new(0, 7, 0), 8.8, 10, M.Neon, rgb(60, 200, 190), { Transparency = 0.62, CanCollide = false })
	liquid.Name = "TankLiquid"
	liquid:SetAttribute("Solid", true)
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
		local a = (k + 0.5) / 8 * math.pi * 2 -- half-step so the front is open (his breakout path)
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
		D(parent, Vector3.new(rng:NextNumber(0.3, 1.1), 0.05, rng:NextNumber(0.3, 1.1)), CFrame.new(math.cos(a) * d, y0 + 0.09, math.sin(a) * d) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), M.Glass, rgb(170, 210, 220), { Transparency = 0.4 })
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
				D(parent, Vector3.new(0.25, 3.5, 0.25), CFrame.new(x, cwY + 1.95, edgeZ), M.Metal, rgb(222, 170, 28))
			end
		end
		-- brackets back to the wall
		for x = a.X + 2, b.X, 8 do
			if math.abs(x) < 10 then
				continue
			end
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
			P(parent, Vector3.new(4, 0.4, depth + 0.05), CFrame.new(s.x, y0 + (i + 1) * cw / steps - 0.2, z), M.DiamondPlate, grateC):SetAttribute("Solid", true)
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

-- A forged-steel crucible on four legs: riveted bands, seams glowing with the
-- heat inside, a cracked crust round a white-hot pool, embers rising. One of
-- them (pouring) tips a stream of molten adamantium into an ingot mould.
local function crucible(parent, pos, pouring)
	local steel, dark, hot = rgb(62, 64, 70), rgb(34, 35, 38), rgb(255, 120, 34)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local foot = pos + Vector3.new(math.cos(a) * 6.5, 0, math.sin(a) * 6.5)
		P(parent, Vector3.new(1.2, 12, 1.2), CFrame.new(foot + Vector3.new(0, 6, 0)), M.Metal, dark)
		D(parent, Vector3.new(2.4, 0.4, 2.4), CFrame.new(foot + Vector3.new(0, 0.2, 0)), M.Metal, rgb(28, 28, 30))
		D(parent, Vector3.new(1.6, 1, 1.6), CFrame.new(foot + Vector3.new(0, 11.6, 0)), M.Metal, steel)
	end
	drum(parent, pos + Vector3.new(0, 12.4, 0), 15, 0.8, M.Metal, dark)
	drum(parent, pos + Vector3.new(0, 17, 0), 12, 8.4, M.Metal, steel, { Reflectance = 0.05 })
	ball(parent, pos + Vector3.new(0, 12.6, 0), 11, M.Metal, steel, nil, true)
	for _, y in { 14, 17, 20 } do
		drum(parent, pos + Vector3.new(0, y, 0), 12.5, 0.55, M.Metal, dark, nil, true)
		for k = 0, 11 do -- rivets round each band
			local a = k / 12 * math.pi * 2
			ball(parent, pos + Vector3.new(math.cos(a) * 6.28, y, math.sin(a) * 6.28), 0.34, M.Metal, rgb(96, 98, 104), nil, true)
		end
	end
	for _, y in { 15.5, 18.5 } do -- seams glowing between the plates
		drum(parent, pos + Vector3.new(0, y, 0), 12.08, 0.12, M.Neon, hot, { Transparency = 0.15 }, true)
	end
	drum(parent, pos + Vector3.new(0, 21.3, 0), 12.8, 0.6, M.Metal, dark, nil, true)
	drum(parent, pos + Vector3.new(0, 21.28, 0), 10.8, 0.3, M.CrackedLava, rgb(80, 36, 18), nil, true) -- crust
	local molten = drum(parent, pos + Vector3.new(0, 21.36, 0), 7.2, 0.3, M.Neon, rgb(255, 150, 50), nil, true)
	pointLight(molten, 26, 1.8, rgb(255, 140, 60), true)
	make("ParticleEmitter", molten, {
		Name = "Embers",
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 14,
		Lifetime = NumberRange.new(1.5, 3),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = N.Right, -- the drum's axis points up
		Size = NumberSequence.new(0.28, 0.05),
		Transparency = NumberSequence.new(0, 1),
		Color = ColorSequence.new(rgb(255, 200, 90), rgb(255, 80, 20)),
		LightEmission = 1,
	})
	make("ParticleEmitter", molten, {
		Name = "Heat",
		Rate = 4,
		Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(2, 4),
		EmissionDirection = N.Right,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(rgb(150, 140, 130)),
		RotSpeed = NumberRange.new(-20, 20),
	})
	-- pour spout
	wedge(parent, Vector3.new(3, 2, 4), CFrame.new(pos + Vector3.new(0, 20.6, -7.4)) * CFrame.Angles(0, math.pi, 0), M.Metal, dark)
	local label = D(parent, Vector3.new(6, 1.4, 0.1), CFrame.new(pos + Vector3.new(0, 16.4, -6.05)), M.SmoothPlastic, Color3.new(), { Transparency = 1 })
	stencil(label, N.Front, "ADAMANTIUM", rgb(230, 220, 200), 30)
	if pouring then
		-- a glowing stream from the spout down into an ingot mould
		local lip = pos + Vector3.new(0, 20.2, -9.2)
		local bottom = pos + Vector3.new(0, 1.6, -9.2)
		cyl(parent, lip, bottom, 0.55, M.Neon, rgb(255, 160, 60), nil, true)
		P(parent, Vector3.new(4.4, 1.4, 3.2), CFrame.new(pos + Vector3.new(0, 0.7, -9.2)), M.Metal, dark) -- ingot mould
		local pool = D(parent, Vector3.new(3.6, 0.1, 2.4), CFrame.new(pos + Vector3.new(0, 1.42, -9.2)), M.Neon, rgb(255, 140, 40))
		pointLight(pool, 16, 1.6, rgb(255, 130, 50))
		make("ParticleEmitter", pool, {
			Name = "Splash",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 30,
			Lifetime = NumberRange.new(0.4, 0.8),
			Speed = NumberRange.new(4, 9),
			SpreadAngle = Vector2.new(70, 70),
			Acceleration = Vector3.new(0, -30, 0),
			Size = NumberSequence.new(0.22, 0.04),
			Color = ColorSequence.new(rgb(255, 220, 120), rgb(255, 90, 20)),
			LightEmission = 1,
		})
	end
end

local function buildFoundry(parent)
	local r = ROOM.Foundry
	-- cool white work floods overhead, so the only warm light is the molten
	-- metal itself (it used to be orange lamps on rust: a flat red wash)
	r.Warm = rgb(226, 234, 255)
	floorTiles(parent, r, "Grate")
	ceiling(parent, r, "Truss")
	-- molten channel across the hall, with grates and three bridges
	local cz = -94
	P(parent, Vector3.new(r.x1 - r.x0 - 16, 0.3, 5), CFrame.new(0, F + 0.15, cz), M.Metal, rgb(34, 32, 30))
	local lava = D(parent, Vector3.new(r.x1 - r.x0 - 18, 0.1, 3), CFrame.new(0, F + 0.34, cz), M.Neon, rgb(255, 120, 26))
	for _, s in { -1, 1 } do -- cooling crust along both edges
		D(parent, Vector3.new(r.x1 - r.x0 - 18.2, 0.12, 0.7), CFrame.new(0, F + 0.35, cz + s * 1.25), M.CrackedLava, rgb(80, 36, 18))
	end
	for x = r.x0 + 10, r.x1 - 10, 14 do
		pointLight(D(parent, Vector3.new(0.2, 0.2, 0.2), CFrame.new(x, F + 1, cz), M.SmoothPlastic, Color3.new(), { Transparency = 1 }), 14, 1.3, rgb(255, 130, 50))
	end
	local cover = P(parent, Vector3.new(r.x1 - r.x0 - 18, 0.12, 3.2), CFrame.new(0, F + 0.46, cz), M.Metal, rgb(20, 20, 20), { Transparency = 0.9 })
	for x = r.x0 + 10, r.x1 - 10, 0.9 do
		D(parent, Vector3.new(0.22, 0.18, 3.26), CFrame.new(x, F + 0.47, cz), M.Metal, rgb(30, 28, 26))
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
	crucible(parent, Vector3.new(0, F, -126), true)
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
	pipe(parent, { Vector3.new(-54, F + 3, -60), Vector3.new(-54, F + 3, -89), Vector3.new(-54, F + 14, -89), Vector3.new(-54, F + 14, -106), Vector3.new(-54, F + 3, -106), Vector3.new(-54, F + 3, -136), Vector3.new(-54, F + 20, -136) }, 1.6, rgb(120, 70, 30), M.Metal)
	pipe(parent, { Vector3.new(54, F + 4, -136), Vector3.new(54, F + 4, -106), Vector3.new(54, F + 14, -106), Vector3.new(54, F + 14, -89), Vector3.new(54, F + 4, -89), Vector3.new(54, F + 4, -62), Vector3.new(54, F + 18, -62) }, 1.4, rgb(90, 96, 104), M.Foil)
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
	hidingSpot(CFrame.lookAt(Vector3.new(-50, F, -104), Vector3.new(0, F, -104)), "Crate")
	spawnAt(-20, -70)
	spawnAt(20, -110)
	spawnAt(-44, -130)
end

---------------------------------------------------------------------------
-- SENTINEL HANGAR
---------------------------------------------------------------------------

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
		-- the suit hangs in its cradle, boots just clear of the deck, held by a
		-- harness bar, shoulder clamps and cables from the gantry
		local hang = 1.4
		Costumes.SentinelStatue(dummy, CFrame.new(c + Vector3.new(0, hang, 0)), Config.Sentinel.Scale)
		local sc = Config.Sentinel.Scale
		local shoulderY = hang + (3.25 + 1.35) * sc
		D(pod, Vector3.new(8.4, 0.9, 1.4), CFrame.new(c + Vector3.new(0, shoulderY + 1.6, 0.9)), M.Metal, rgb(58, 56, 54)) -- harness bar
		for s = -1, 1, 2 do
			-- clamp arms from the bar down onto each pauldron
			D(pod, Vector3.new(0.7, 1.9, 0.7), CFrame.new(c + Vector3.new(s * 2.9, shoulderY + 0.7, 0.5)), M.Metal, rgb(70, 68, 64))
			D(pod, Vector3.new(1.4, 0.5, 1.6), CFrame.new(c + Vector3.new(s * 2.9, shoulderY - 0.2, 0.2)), M.Metal, rgb(222, 170, 28))
			-- hoist cables up to the gantry
			cable(c + Vector3.new(s * 3.2, shoulderY + 2, 0.9), c + Vector3.new(s * 3.6, 22.4, 1.4), 0.5, 0.18, rgb(30, 30, 32))
		end
		-- the charging pad under its boots, and a light shining up at it
		local pad = D(pod, Vector3.new(0.12, 6.5, 6.5), CFrame.new(c + Vector3.new(0, 0.1, -0.6)) * CFrame.Angles(0, 0, math.rad(90)), M.Neon, rgb(170, 70, 230), { Shape = Enum.PartType.Cylinder, Transparency = 0.45 })
		local up = Instance.new("SpotLight")
		up.Face = Enum.NormalId.Right -- the cylinder's axis points up
		up.Angle = 50
		up.Range = 26
		up.Brightness = 2.2
		up.Color = rgb(200, 150, 255)
		up.Parent = pad
		-- light strips up the back frame
		for s = -1, 1, 2 do
			D(pod, Vector3.new(0.3, 18, 0.2), CFrame.new(c + Vector3.new(s * 3.8, 11, 3.7)), M.Neon, rgb(170, 90, 255))
		end
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
	-- central control podium
	local podium = CFrame.new(0, F + 0.8, 106)
	P(pod, Vector3.new(6, 3.4, 3), podium * CFrame.new(0, 1.7, 0), M.Metal, rgb(40, 42, 48))
	screen(pod, podium * CFrame.new(0, 4.6, 0.6) * CFrame.Angles(math.rad(-15), math.pi, 0), 4.4, 2.2, "schematic", rgb(200, 120, 255))
	pod.Parent = ROOT

	-- giant sealed bay door on the south wall
	local door = P(parent, Vector3.new(44, 26, 1.2), CFrame.new(0, F + 13, 138.6), M.Metal, rgb(70, 68, 64))
	for x = -21, 21, 3 do
		D(door, Vector3.new(0.6, 25, 1.8), CFrame.new(x, F + 13, 138.4), M.Metal, rgb(90, 86, 80))
	end
	for _, y in { 6, 13, 20 } do
		D(door, Vector3.new(43.6, 1, 1.9), CFrame.new(0, F + y, 138.3), M.Metal, rgb(46, 44, 42))
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
	for i = 0, 2 do -- far enough apart that turned crates never cut into each other
		crate(parent, CFrame.new(46, F, 66 + i * 5.4) * CFrame.Angles(0, rng:NextNumber(-0.12, 0.12), 0), 4.4, i == 1 and "SENTINEL SPARES" or "TRASK IND.")
	end
	crate(parent, CFrame.new(46, F + 4.4, 71.4), 3.4, "HANDLE WITH CARE")
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
	local fog = drum(glass, pos + Vector3.new(0, 5.05, 0), 3.5, 7.4, M.Neon, rgb(150, 220, 255), { Transparency = 0.78 }, true)
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
	D(body, Vector3.new(0.12, 7.6, 0.2), cf * CFrame.new(1.12, 4.3, -2.4), M.Metal, rgb(120, 124, 130))
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
	for _, p in { { -104, 50 }, { -60, 50 } } do
		plant(parent, Vector3.new(p[1], F, p[2]), 1)
	end
	waitingChairs(parent, CFrame.new(-97, F, 53), 4)
	conferenceTable(parent, CFrame.new(-82, F, 40), 16)
	screen(parent, CFrame.new(-57.4, F + 7, 18) * CFrame.Angles(0, math.rad(90), 0), 9, 5, "schematic", rgb(90, 200, 255))
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
		-- clad in dull steel (bright foil flared white under the core's light)
		pipe(parent, { c + d * 8 + Vector3.new(0, 6, 0), c + d * 16 + Vector3.new(0, 6, 0), c + d * 16 + Vector3.new(0, 18, 0), Vector3.new(wallPt.X, F + 18, wallPt.Z) }, 2.4, rgb(118, 124, 134), M.Metal, rgb(52, 54, 60))
	end
	-- step-down transformers: a steel tank on a skid, a bolted cover with
	-- lifting lugs, a conservator tank on top, three skirted porcelain
	-- bushings wired up into the roof, radiator banks down both sides and a
	-- warning plate
	for i = 0, 3 do
		local p = Vector3.new(153, F, -130 + i * 16)
		local tankC, finC, dark = rgb(84, 96, 84), rgb(72, 84, 72), rgb(34, 36, 40)
		for _, x in { -2.2, 2.2 } do -- skid
			D(parent, Vector3.new(0.8, 0.6, 8.6), CFrame.new(p + Vector3.new(x, 0.3, 0)), M.Metal, dark)
		end
		P(parent, Vector3.new(5.6, 6.2, 7.6), CFrame.new(p + Vector3.new(0, 3.7, 0)), M.Metal, tankC)
		D(parent, Vector3.new(6, 0.35, 8), CFrame.new(p + Vector3.new(0, 6.95, 0)), M.Metal, finC) -- cover
		for _, x in { -2.8, 2.8 } do
			for _, z in { -3.8, 3.8 } do
				D(parent, Vector3.new(0.5, 0.6, 0.18), CFrame.new(p + Vector3.new(x, 7.3, z)), M.Metal, dark) -- lifting lugs
			end
		end
		for z = -3.6, 3.6, 0.9 do -- cover bolts
			for _, x in { -2.9, 2.9 } do
				D(parent, Vector3.new(0.14, 0.12, 0.14), CFrame.new(p + Vector3.new(x, 7.18, z)), M.Metal, rgb(150, 154, 160))
			end
		end
		-- conservator
		D(parent, Vector3.new(6.4, 1.6, 1.6), CFrame.new(p + Vector3.new(1.6, 8.9, 0)) * CFrame.Angles(0, math.rad(90), 0), M.Metal, tankC, { Shape = Enum.PartType.Cylinder })
		for _, z in { -2.4, 2.4 } do
			D(parent, Vector3.new(0.3, 1.5, 0.3), CFrame.new(p + Vector3.new(1.6, 7.8, z)), M.Metal, dark)
		end
		-- bushings: stacked porcelain skirts with a brass terminal, a cable up to the roof
		for _, z in { -2.2, 0, 2.2 } do
			local b = p + Vector3.new(-1.2, 7.1, z)
			for k = 0, 4 do
				drum(parent, b + Vector3.new(0, 0.3 + k * 0.42, 0), 1.1 - k * 0.1, 0.18, M.SmoothPlastic, rgb(128, 70, 38), nil, true)
			end
			cyl(parent, b, b + Vector3.new(0, 2.4, 0), 0.5, M.SmoothPlastic, rgb(110, 60, 32), nil, true)
			drum(parent, b + Vector3.new(0, 2.55, 0), 0.4, 0.3, M.Metal, rgb(200, 160, 70), nil, true)
			cable(b + Vector3.new(0, 2.7, 0), Vector3.new(b.X - 2, F + r.h - 2, b.Z), 1.2, 0.22, rgb(20, 20, 22))
		end
		-- radiator banks
		for _, sx in { -1, 1 } do
			for f = -3.3, 3.3, 0.55 do
				D(parent, Vector3.new(1.2, 5, 0.1), CFrame.new(p + Vector3.new(sx * 3.4, 3.6, f)), M.Metal, finC)
			end
			for _, y in { 1.3, 5.9 } do
				D(parent, Vector3.new(0.36, 0.36, 7.2), CFrame.new(p + Vector3.new(sx * 3.4, y, 0)) * CFrame.Angles(0, math.rad(90), 0), M.Metal, dark, { Shape = Enum.PartType.Cylinder })
			end
		end
		local sg = D(parent, Vector3.new(3, 2, 0.1), CFrame.new(p + Vector3.new(0, 4, -3.86)), M.SmoothPlastic, rgb(230, 190, 30))
		stencil(sg, N.Front, "⚡ DANGER 11 kV", rgb(20, 20, 20), 30)
		local plate = D(parent, Vector3.new(1.4, 0.8, 0.06), CFrame.new(p + Vector3.new(1.8, 5.8, -3.83)), M.Metal, rgb(170, 172, 176))
		stencil(plate, N.Front, "WX-T" .. (i + 1), rgb(30, 30, 34), 50, Enum.Font.Code)
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
		D(parent, Vector3.new(4.2 - (k % 2) * 0.04, 0.3, (p1 - p0).Magnitude + 0.1), CFrame.lookAt(mid, mid + (p1 - p0)) * CFrame.new(0, (k % 2) * 0.015, 0), M.DiamondPlate, rgb(66, 66, 62))
		cyl(parent, p0 + (p0 - c).Unit * 2 + Vector3.new(0, 3, 0), p1 + (p1 - c).Unit * 2 + Vector3.new(0, 3, 0), 0.18, M.Metal, rgb(222, 170, 28), nil, true)
		if k % 4 == 0 then
			cyl(parent, Vector3.new(p0.X, F, p0.Z) + (p0 - c).Unit * 2, p0 + (p0 - c).Unit * 2, 0.4, M.Metal, rgb(40, 40, 42), nil, true)
		end
	end
	hidingSpot(CFrame.lookAt(Vector3.new(154, F, -134), Vector3.new(108, F, -98)), "Locker")
	spawnAt(138, -76)
	spawnAt(128, -118)
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
		D(parent, Vector3.new(len, 0.2, 2.94), cf * CFrame.new(0, y, 0), M.Metal, frameC, { CanCollide = true })
		local x = -len / 2 + 0.6
		while x < len / 2 - 1 do
			local w = rng:NextNumber(1.2, 2.2)
			local clear = true
			for u = -len / 2, len / 2, len / 3 do
				if math.abs(u - (x + w / 2)) < w / 2 + 0.15 then
					clear = false -- would cut through an upright
				end
			end
			if clear and rng:NextNumber() < 0.85 then
				local h = rng:NextNumber(1.2, 2.1)
				D(parent, Vector3.new(w - 0.1, h, 2.4), cf * CFrame.new(x + w / 2, y + 0.1 + h / 2, rng:NextNumber(-0.2, 0.2)), M.Cardboard, vary(rgb(150, 120, 86), 0.2))
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

-- A moulded canteen chair at cf (facing -Z): a curved shell seat and back on
-- a tubular steel frame.
local function canteenChair(parent, cf, color)
	local steel = rgb(150, 154, 162)
	for _, x in { -0.55, 0.55 } do
		for _, z in { -0.5, 0.5 } do
			D(parent, Vector3.new(0.1, 1.72, 0.1), cf * CFrame.new(x, 0.86, z) * CFrame.Angles(math.rad(z * 8), 0, math.rad(x * 6)), M.Metal, steel, { CanCollide = false })
		end
		D(parent, Vector3.new(0.1, 0.1, 1.2), cf * CFrame.new(x * 1.06, 0.06, 0), M.Metal, steel, { CanCollide = false }) -- floor runner
	end
	D(parent, Vector3.new(1.46, 0.16, 1.36), cf * CFrame.new(0, 1.8, 0), M.SmoothPlastic, color)
	D(parent, Vector3.new(1.46, 0.12, 0.3), cf * CFrame.new(0, 1.84, -0.72) * CFrame.Angles(math.rad(-20), 0, 0), M.SmoothPlastic, color) -- rolled front edge
	D(parent, Vector3.new(1.4, 1.3, 0.14), cf * CFrame.new(0, 2.58, 0.7) * CFrame.Angles(math.rad(-10), 0, 0), M.SmoothPlastic, color)
	D(parent, Vector3.new(0.1, 0.9, 0.1), cf * CFrame.new(0, 2.3, 0.62) * CFrame.Angles(math.rad(-10), 0, 0), M.Metal, steel, { CanCollide = false }) -- back spine
end

-- A long canteen table (along Z) at pos: a laminate top with a steel edge on
-- two pedestal legs, three chairs down each side (a few pushed back or
-- knocked over in the panic) and whatever was left on it.
local CHAIR_COLORS = { rgb(214, 96, 36), rgb(40, 132, 140), rgb(222, 176, 40) }
local function canteenTable(parent, pos, seed)
	local cf = CFrame.new(pos)
	local steel = rgb(120, 124, 132)
	P(parent, Vector3.new(3.4, 0.22, 8.4), cf * CFrame.new(0, 3.05, 0), M.SmoothPlastic, rgb(222, 222, 216))
	D(parent, Vector3.new(3.5, 0.12, 8.5), cf * CFrame.new(0, 2.92, 0), M.Metal, steel)
	for _, z in { -2.8, 2.8 } do
		D(parent, Vector3.new(0.3, 2.8, 0.3), cf * CFrame.new(0, 1.46, z), M.Metal, steel)
		D(parent, Vector3.new(2.8, 0.18, 0.5), cf * CFrame.new(0, 0.09, z), M.Metal, rgb(70, 72, 78))
		D(parent, Vector3.new(2.6, 0.18, 0.3), cf * CFrame.new(0, 2.78, z), M.Metal, steel) -- top bracket
	end
	D(parent, Vector3.new(0.24, 0.24, 5.9), cf * CFrame.new(0, 1.2, 0), M.Metal, steel) -- stretcher
	local color = CHAIR_COLORS[seed % #CHAIR_COLORS + 1]
	for _, side in { -1, 1 } do
		for k, z in { -2.6, 0, 2.6 } do
			local roll = rng:NextNumber()
			local chair = cf * CFrame.new(side * 2.5, 0, z) * CFrame.Angles(0, side > 0 and math.rad(90) or math.rad(-90), 0)
			if roll < 0.12 then
				-- knocked over on its back
				chair = cf * CFrame.new(side * 3.6, 0.72, z) * CFrame.Angles(0, side > 0 and math.rad(90) or math.rad(-90), 0) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, -0.7, 0)
			elseif roll < 0.4 then
				chair = chair * CFrame.new(0, 0, rng:NextNumber(0.4, 1.1)) * CFrame.Angles(0, rng:NextNumber(-0.35, 0.35), 0) -- pushed back
			end
			canteenChair(parent, chair, color)
			-- a tray, a plate and a cup in front of some seats
			if (k + seed + (side > 0 and 1 or 0)) % 3 ~= 0 then
				local at = cf * CFrame.new(side * 0.95, 3.17, z + rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0)
				D(parent, Vector3.new(1.2, 0.06, 1.7), at, M.SmoothPlastic, rgb(60, 104, 140), { CanCollide = false })
				D(parent, Vector3.new(0.06, 0.9, 0.9), at * CFrame.new(0, 0.06, 0.2) * CFrame.Angles(0, 0, math.rad(90)), M.SmoothPlastic, rgb(236, 236, 230), { Shape = Enum.PartType.Cylinder, CanCollide = false })
				D(parent, Vector3.new(0.42, 0.3, 0.3), at * CFrame.new(-side * 0.3, 0.24, -0.55) * CFrame.Angles(0, 0, math.rad(90)), M.SmoothPlastic, rgb(214, 214, 208), { Shape = Enum.PartType.Cylinder, CanCollide = false })
			end
		end
	end
end

-- The lobby's vending machines (MapBuilder.VendingMachine), stood with their
-- backs to a wall at cf. The cabinet is what breaks; everything on it goes
-- with it.
local function vending(parent, cf, kind)
	local tmp = Instance.new("Model")
	local cab = MapBuilder.VendingMachine(tmp, cf, kind)
	for _, d in tmp:GetChildren() do
		if d ~= cab and d:IsA("BasePart") then
			d.CanQuery, d.CanTouch = false, false
			d.Parent = cab
		end
	end
	cab.Parent = parent
	breakable(cab)
	tmp:Destroy()
end

local function buildCanteen(parent)
	local r = ROOM.Canteen
	r.Lamp = "Dome"
	floorTiles(parent, r, "Checker")
	ceiling(parent, r, "Truss")
	-- six long tables, each under a lamp
	local seed = 0
	for _, x in { 69, 95 } do
		for _, z in { 70, 98, 124 } do
			seed += 1
			canteenTable(parent, Vector3.new(x, F, z), seed)
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
	vending(parent, CFrame.new(106, F, 90) * CFrame.Angles(0, math.rad(90), 0), "Cola")
	vending(parent, CFrame.new(106, F, 94.2) * CFrame.Angles(0, math.rad(90), 0), "Snacks")
	local menu = D(parent, Vector3.new(10, 3, 0.2), CFrame.new(81, F + 10, 139), M.SmoothPlastic, rgb(20, 20, 22))
	local g = sgui(menu, N.Front, 30, true)
	tx(g, { Size = UDim2.fromScale(1, 1), Text = "CANTEEN — TODAY: MEATLOAF · 06:00–22:00", TextColor3 = rgb(255, 200, 80), Font = Enum.Font.Code })
	hidingSpot(CFrame.lookAt(Vector3.new(60, F, 62), Vector3.new(80, F, 80)), "Freezer")
	spawnAt(76, 96)
	spawnAt(62, 128)
end

-- Bedding on a bed deck whose top is at `top` (cf's frame, the bed along X
-- with its head at +X): a mattress, a blanket over the foot two thirds with
-- a folded-back sheet, and a pillow.
local function bedding(parent, cf, top, len, blanket)
	D(parent, Vector3.new(len - 0.4, 0.5, 2.9), cf * CFrame.new(0, top + 0.25, 0), M.Fabric, rgb(214, 216, 222))
	local bl = (len - 0.4) * 0.66
	D(parent, Vector3.new(bl, 0.12, 3.04), cf * CFrame.new(-(len - 0.4) / 2 + bl / 2 - 0.02, top + 0.54, 0), M.Fabric, blanket)
	D(parent, Vector3.new(0.5, 0.14, 3.02), cf * CFrame.new(-(len - 0.4) / 2 + bl + 0.2, top + 0.55, 0), M.Fabric, rgb(236, 236, 232)) -- sheet turned down
	for _, z in { -1.52, 1.52 } do -- the blanket hangs over the sides
		D(parent, Vector3.new(bl, 0.46, 0.06), cf * CFrame.new(-(len - 0.4) / 2 + bl / 2 - 0.02, top + 0.34, z), M.Fabric, blanket)
	end
	D(parent, Vector3.new(1.1, 0.36, 2.1), cf * CFrame.new(len / 2 - 0.95, top + 0.66, 0) * CFrame.Angles(0, rng:NextNumber(-0.12, 0.12), math.rad(4)), M.Fabric, rgb(240, 240, 238))
end

-- A steel bunk bed at cf (along X, head at +X): four posts with caps, side
-- and end rails, barred head and foot panels, a ladder at the foot, bedding
-- on both decks and a storage bin under the lower one.
local BLANKETS = { rgb(40, 56, 92), rgb(70, 82, 52), rgb(110, 36, 40), rgb(60, 60, 66) }
local function bunkBed(parent, cf, k)
	local steel, cap = rgb(62, 68, 78), rgb(40, 44, 50)
	local L = 7
	for _, x in { -L / 2 + 0.15, L / 2 - 0.15 } do
		for _, z in { -1.45, 1.45 } do
			P(parent, Vector3.new(0.3, 7.6, 0.3), cf * CFrame.new(x, 3.8, z), M.Metal, steel)
			D(parent, Vector3.new(0.38, 0.2, 0.38), cf * CFrame.new(x, 7.7, z), M.Metal, cap)
		end
	end
	for _, top in { 1.6, 5.4 } do
		D(parent, Vector3.new(L - 0.3, 0.14, 3.0), cf * CFrame.new(0, top - 0.07, 0), M.Metal, rgb(50, 54, 62)) -- deck
		for _, z in { -1.45, 1.45 } do
			D(parent, Vector3.new(L - 0.3, 0.3, 0.14), cf * CFrame.new(0, top - 0.2, z), M.Metal, steel) -- side rails
		end
		for _, x in { -L / 2 + 0.15, L / 2 - 0.15 } do
			for _, dy in { 0.5, 1.1 } do
				D(parent, Vector3.new(0.12, 0.12, 2.6), cf * CFrame.new(x, top + dy, 0), M.Metal, steel) -- head/foot bars
			end
		end
		bedding(parent, cf, top, L, BLANKETS[(k + (top > 3 and 1 or 0)) % #BLANKETS + 1])
	end
	D(parent, Vector3.new(L - 0.3, 0.14, 0.12), cf * CFrame.new(0, 6.6, -1.45), M.Metal, steel) -- upper safety rail
	for _, z in { -0.6, 0.6 } do -- ladder at the foot
		D(parent, Vector3.new(0.12, 5.6, 0.12), cf * CFrame.new(-L / 2 - 0.12, 2.9, z), M.Metal, steel)
	end
	for y = 1.1, 5.1, 1 do
		D(parent, Vector3.new(0.1, 0.1, 1.24), cf * CFrame.new(-L / 2 - 0.12, y, 0), M.Metal, rgb(90, 96, 106)) -- rungs sit inside the rails
	end
	local bin = P(parent, Vector3.new(2.6, 0.9, 2.4), cf * CFrame.new(0.8, 0.45, 0), M.SmoothPlastic, rgb(60, 70, 84))
	D(bin, Vector3.new(2.66, 0.12, 2.46), cf * CFrame.new(0.8, 0.87, 0), M.SmoothPlastic, rgb(44, 52, 64)) -- lid
end

-- A single bed at cf (along X, head at +X): a panel headboard, a low frame
-- on four legs and bedding.
local function singleBed(parent, cf, k)
	local frame = rgb(58, 62, 70)
	P(parent, Vector3.new(6.6, 0.5, 3.2), cf * CFrame.new(-0.2, 1.05, 0), M.Metal, frame)
	for _, x in { -3.3, 2.9 } do
		for _, z in { -1.45, 1.45 } do
			D(parent, Vector3.new(0.26, 0.8, 0.26), cf * CFrame.new(x, 0.4, z), M.Metal, rgb(36, 38, 44))
		end
	end
	D(parent, Vector3.new(0.3, 3.2, 3.4), cf * CFrame.new(3.35, 1.6, 0), M.WoodPlanks, rgb(92, 66, 46)) -- headboard
	D(parent, Vector3.new(0.34, 0.22, 3.44), cf * CFrame.new(3.35, 3.26, 0), M.Wood, rgb(70, 50, 34))
	bedding(parent, cf * CFrame.new(-0.2, 0, 0), 1.3, 6.6, BLANKETS[k % #BLANKETS + 1])
end

-- A bedside cabinet at cf (facing -Z): two drawers, a lamp and a clock.
local function nightstand(parent, cf)
	local body = P(parent, Vector3.new(1.6, 2.2, 1.5), cf * CFrame.new(0, 1.1, 0), M.Wood, rgb(84, 60, 42))
	for k = 0, 1 do
		D(body, Vector3.new(1.4, 0.8, 0.05), cf * CFrame.new(0, 0.6 + k * 0.95, -0.77), M.Wood, rgb(100, 72, 50))
		D(body, Vector3.new(0.4, 0.08, 0.08), cf * CFrame.new(0, 0.8 + k * 0.95, -0.82), M.Metal, rgb(180, 170, 140))
	end
	D(parent, Vector3.new(0.5, 0.1, 0.5), cf * CFrame.new(-0.3, 2.25, 0.1), M.Metal, rgb(40, 40, 44)) -- lamp base
	D(parent, Vector3.new(0.08, 0.7, 0.08), cf * CFrame.new(-0.3, 2.6, 0.1), M.Metal, rgb(40, 40, 44))
	D(parent, Vector3.new(0.6, 0.5, 0.6), cf * CFrame.new(-0.3, 3.1, 0.1) * CFrame.Angles(0, 0, math.rad(90)), M.Fabric, rgb(230, 214, 176), { Shape = Enum.PartType.Cylinder }) -- shade
	local clock = D(parent, Vector3.new(0.5, 0.3, 0.2), cf * CFrame.new(0.4, 2.35, -0.3), M.SmoothPlastic, rgb(20, 20, 22))
	local g = sgui(clock, N.Front, 60, true)
	tx(g, { Size = UDim2.fromScale(1, 1), Text = "03:17", TextColor3 = rgb(255, 60, 50), Font = Enum.Font.Code })
end

-- A steel footlocker at cf (facing -Z): a banded lid and a padlock.
local function footLocker(parent, cf)
	local body = P(parent, Vector3.new(3.2, 1.5, 1.8), cf * CFrame.new(0, 0.75, 0), M.Metal, rgb(70, 80, 60))
	D(body, Vector3.new(3.26, 0.2, 1.86), cf * CFrame.new(0, 1.43, 0), M.Metal, rgb(58, 66, 50)) -- lid lip
	for _, x in { -1, 1 } do
		D(body, Vector3.new(0.22, 1.54, 1.84), cf * CFrame.new(x, 0.75, 0), M.Metal, rgb(90, 92, 96)) -- straps
	end
	D(body, Vector3.new(0.3, 0.36, 0.12), cf * CFrame.new(0, 1.05, -0.95), M.Metal, rgb(200, 170, 70)) -- padlock
end

-- A long common-room table with a bench down each side, at cf (along X).
local function messTable(parent, cf)
	local steel = rgb(110, 114, 122)
	P(parent, Vector3.new(8, 0.2, 3), cf * CFrame.new(0, 3.05, 0), M.WoodPlanks, rgb(150, 112, 74))
	for _, x in { -3.4, 3.4 } do
		D(parent, Vector3.new(0.25, 2.9, 2.6), cf * CFrame.new(x, 1.5, 0), M.Metal, steel)
		D(parent, Vector3.new(0.35, 0.16, 7.2), cf * CFrame.new(x, 0.08, 0), M.Metal, rgb(70, 72, 78)) -- foot runs under both benches
		for _, z in { -2.6, 2.6 } do
			D(parent, Vector3.new(0.25, 1.7, 0.25), cf * CFrame.new(x, 0.9, z), M.Metal, steel)
		end
	end
	for _, z in { -2.6, 2.6 } do
		P(parent, Vector3.new(8, 0.2, 1.2), cf * CFrame.new(0, 1.85, z), M.WoodPlanks, rgb(140, 104, 70))
	end
	for k = 1, 4 do -- cards and cups left mid-game
		D(parent, Vector3.new(0.5, 0.03, 0.7), cf * CFrame.new(rng:NextNumber(-3, 3), 3.165 + k * 0.012, rng:NextNumber(-1, 1)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), M.SmoothPlastic, k % 2 == 0 and rgb(240, 240, 236) or rgb(200, 40, 40))
	end
	drum(parent, (cf * CFrame.new(2.4, 3.36, 0.6)).Position, 0.44, 0.44, M.SmoothPlastic, rgb(230, 230, 224), nil, true)
end

local function buildQuarters(parent)
	local r = ROOM.Quarters
	floorTiles(parent, r, "WarmCarpet")
	ceiling(parent, r, "Coffered")
	-- a row of bunks with their heads to the east wall, a bedside cabinet
	-- between each pair and a footlocker at every foot
	for i = 0, 6 do
		local z = 68 + i * 8
		bunkBed(parent, CFrame.new(155.6, F, z), i)
		footLocker(parent, CFrame.new(150.4, F, z) * CFrame.Angles(0, math.rad(-90), 0))
		if i < 6 then
			nightstand(parent, CFrame.new(158.6, F, z + 4) * CFrame.Angles(0, math.rad(-90), 0))
		end
	end
	-- single beds, heads to the west wall, between its two doors
	for i, z in { 90, 98, 106 } do
		singleBed(parent, CFrame.new(112.6, F, z) * CFrame.Angles(0, math.pi, 0), i)
		if i < 3 then
			nightstand(parent, CFrame.new(109.6, F, z + 4) * CFrame.Angles(0, math.rad(90), 0))
		end
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
	messTable(parent, CFrame.new(132, F, 88))
	plant(parent, Vector3.new(112, F, 60), 1)
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
	floorTiles(parent, r, "LabTile")
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
	screen(parent, CFrame.new(-107.3, F + 7, 86) * CFrame.Angles(0, math.rad(-90), 0), 5, 3, "logo", rgb(90, 200, 255))
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
	-- the Weapon X operating table: a hydraulic column, a padded top in three
	-- sections tilted up, arm boards and restraint straps with buckles
	local t = CFrame.new(-134, F, 98)
	local white, chrome, dark = rgb(214, 218, 224), rgb(176, 180, 188), rgb(40, 42, 48)
	P(parent, Vector3.new(4.4, 0.4, 6), t * CFrame.new(0, 0.2, 0), M.Metal, dark) -- base plate
	D(parent, Vector3.new(3.6, 0.5, 5.2), t * CFrame.new(0, 0.62, 0), M.SmoothPlastic, white) -- base cover
	P(parent, Vector3.new(1.6, 2.4, 1.6), t * CFrame.new(0, 2.05, 0), M.Metal, chrome) -- column
	for y = 1.1, 2.9, 0.3 do -- bellows
		D(parent, Vector3.new(1.8, 0.12, 1.8), t * CFrame.new(0, y, 0), M.Rubber, rgb(30, 30, 34))
	end
	D(parent, Vector3.new(2.6, 0.5, 3), t * CFrame.new(0, 3.4, 0), M.Metal, dark) -- tilt head
	local bed = t * CFrame.new(0, 3.9, 0) * CFrame.Angles(math.rad(-20), 0, 0)
	P(parent, Vector3.new(3.2, 0.3, 9), bed, M.Metal, chrome)
	for k, seg in { { -3, 3 }, { 0.3, 3.4 }, { 3.5, 2.4 } } do -- padded sections (legs, torso, head)
		D(parent, Vector3.new(2.9, 0.34, seg[2] - 0.12), bed * CFrame.new(0, 0.3, seg[1]), M.Leather, k == 3 and rgb(34, 38, 44) or rgb(44, 48, 54))
	end
	for _, s in { -1, 1 } do
		D(parent, Vector3.new(0.12, 0.12, 8.6), bed * CFrame.new(s * 1.72, 0.1, 0), M.Metal, chrome) -- side rails
		D(parent, Vector3.new(3, 0.2, 0.9), bed * CFrame.new(s * 2.9, 0.1, 1.8) * CFrame.Angles(0, s * 0.25, 0), M.Leather, rgb(44, 48, 54)) -- arm boards
		D(parent, Vector3.new(0.8, 0.12, 0.3), bed * CFrame.new(s * 3.3, 0.28, 1.8) * CFrame.Angles(0, s * 0.25, 0), M.Leather, rgb(96, 70, 44)) -- wrist strap
	end
	for _, z in { -3.6, -1.2, 1.6 } do -- restraint straps with buckles
		D(parent, Vector3.new(3.3, 0.14, 0.44), bed * CFrame.new(0, 0.53, z), M.Leather, rgb(96, 70, 44))
		D(parent, Vector3.new(0.4, 0.18, 0.5), bed * CFrame.new(1.2, 0.56, z), M.Metal, chrome, { Reflectance = 0.3 })
	end
	-- a twin-head surgical light: ceiling hub, jointed arms, round heads with
	-- LED clusters and a handle in the middle
	local hub = Vector3.new(-134, F + r.h - 0.4, 98)
	drum(parent, hub, 2.2, 0.6, M.Metal, white, nil, true)
	cyl(parent, hub, hub - Vector3.new(0, 3.2, 0), 0.5, M.Metal, white, nil, true)
	for k, off in { Vector3.new(-3, -5.6, -1.6), Vector3.new(2.8, -5.2, 1.8) } do
		local joint = hub - Vector3.new(0, 3.2, 0)
		local elbow = joint + Vector3.new(off.X * 0.55, -0.6, off.Z * 0.55)
		local head = hub + off
		cyl(parent, joint, elbow, 0.34, M.Metal, white, nil, true)
		ball(parent, elbow, 0.6, M.Metal, dark, nil, true)
		cyl(parent, elbow, head + Vector3.new(0, 0.9, 0), 0.3, M.Metal, white, nil, true)
		local aim = CFrame.lookAt(head, Vector3.new(-134, F + 4, 98)) * CFrame.Angles(math.rad(90), 0, 0) -- the head's down axis points at the table
		D(parent, Vector3.new(2.9, 0.5, 2.9), aim * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), M.SmoothPlastic, white, { Shape = Enum.PartType.Cylinder })
		D(parent, Vector3.new(0.1, 2.6, 2.6), aim * CFrame.new(0, -0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), M.SmoothPlastic, rgb(30, 32, 36), { Shape = Enum.PartType.Cylinder })
		for j = 0, 6 do -- LED cluster
			local rr = j == 0 and 0 or 0.8
			local ang = j / 6 * math.pi * 2
			D(parent, Vector3.new(0.06, 0.62, 0.62), aim * CFrame.new(math.cos(ang) * rr, -0.14, math.sin(ang) * rr) * CFrame.Angles(0, 0, math.rad(90)), M.Neon, rgb(245, 250, 255), { Shape = Enum.PartType.Cylinder })
		end
		D(parent, Vector3.new(0.7, 0.3, 0.3), aim * CFrame.new(0, -0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), M.SmoothPlastic, rgb(60, 140, 200), { Shape = Enum.PartType.Cylinder }) -- handle
		local emit = D(parent, Vector3.new(0.2, 0.2, 0.2), aim * CFrame.new(0, -0.4, 0), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false })
		spotDown(emit, 22, 2.4, rgb(245, 250, 255), 55, k == 1) -- down the head's axis
	end
	-- robot arms on turrets, each with an adamantium injector, and the
	-- injection tanks feeding them
	for _, s in { -1, 1 } do
		local base = Vector3.new(-134 + s * 6.5, F, 98)
		local orange = rgb(230, 120, 30)
		drum(parent, base + Vector3.new(0, 0.3, 0), 3.2, 0.6, M.Metal, dark)
		for k = 0, 7 do -- anchor bolts
			local a = k / 8 * math.pi * 2
			drum(parent, base + Vector3.new(math.cos(a) * 1.35, 0.66, math.sin(a) * 1.35), 0.24, 0.16, M.Metal, chrome, nil, true)
		end
		drum(parent, base + Vector3.new(0, 1.2, 0), 2.4, 1.2, M.Metal, white) -- turret
		drum(parent, base + Vector3.new(0, 1.85, 0), 2.5, 0.14, M.Metal, orange, nil, true)
		local sh = base + Vector3.new(0, 2.6, 0)
		local el = base + Vector3.new(-s * 1.4, 6.6, -0.6)
		local wr = base + Vector3.new(-s * 3.9, 6.8, -1.3)
		local tipDir = (Vector3.new(-134, F + 5, 98) - wr).Unit
		local function segment(a0, a1, w)
			local len = (a1 - a0).Magnitude
			D(parent, Vector3.new(w, w * 0.8, len), CFrame.lookAt((a0 + a1) / 2, a1), M.SmoothPlastic, white)
			D(parent, Vector3.new(w + 0.04, 0.16, len * 0.5), CFrame.lookAt((a0 + a1) / 2, a1) * CFrame.new(0, w * 0.4, 0), M.SmoothPlastic, orange) -- stripe
		end
		local function joint(p, d)
			D(parent, Vector3.new(d * 0.9, d, d), CFrame.new(p) * CFrame.Angles(0, math.rad(90), 0), M.Metal, dark, { Shape = Enum.PartType.Cylinder })
		end
		joint(sh, 1.5)
		segment(sh, el, 1)
		joint(el, 1.2)
		segment(el, wr, 0.8)
		joint(wr, 0.9)
		-- the injector: a vial of glowing adamantium and a long needle
		local inj = CFrame.lookAt(wr, wr + tipDir)
		D(parent, Vector3.new(0.5, 0.5, 1.2), inj * CFrame.new(0, 0, -0.9), M.Metal, dark)
		D(parent, Vector3.new(0.34, 0.34, 0.9), inj * CFrame.new(0, 0, -1.9), M.Glass, rgb(200, 220, 240), { Transparency = 0.4 })
		D(parent, Vector3.new(0.2, 0.2, 0.8), inj * CFrame.new(0, 0, -1.9), M.Neon, rgb(200, 215, 235))
		D(parent, Vector3.new(0.06, 0.06, 1.2), inj * CFrame.new(0, 0, -2.9), M.Metal, rgb(220, 224, 232), { Reflectance = 0.5 })
		-- injection tank: steel caps with bolts, silver liquid behind glass,
		-- a gauge and a warning label
		local tank = Vector3.new(-134 + s * 12, F, 108)
		drum(parent, tank + Vector3.new(0, 0.5, 0), 4, 1, M.Metal, dark)
		drum(parent, tank + Vector3.new(0, 4.5, 0), 3.2, 7, M.Glass, rgb(210, 220, 230), { Transparency = 0.6 })
		drum(parent, tank + Vector3.new(0, 3.65, 0), 2.7, 5.2, M.Foil, rgb(196, 202, 212), { Reflectance = 0.35 }, true)
		local glow = drum(parent, tank + Vector3.new(0, 6.3, 0), 2.72, 0.2, M.Neon, rgb(170, 200, 255), nil, true) -- the liquid's surface
		pointLight(glow, 10, 0.6, rgb(170, 200, 255))
		drum(parent, tank + Vector3.new(0, 8.4, 0), 3.8, 0.8, M.Metal, dark)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			cyl(parent, tank + Vector3.new(math.cos(a) * 1.7, 1, math.sin(a) * 1.7), tank + Vector3.new(math.cos(a) * 1.7, 8, math.sin(a) * 1.7), 0.16, M.Metal, chrome, nil, true)
		end
		local gauge = D(parent, Vector3.new(0.9, 0.9, 0.12), CFrame.new(tank + Vector3.new(0, 1.2, -2.05)), M.Metal, rgb(230, 230, 226))
		local gg = sgui(gauge, N.Front, 60)
		fr(gg, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(0.05, 0.42), Rotation = 35, BackgroundColor3 = rgb(200, 30, 30) })
		local warn = D(parent, Vector3.new(1.4, 0.6, 0.06), CFrame.new(tank + Vector3.new(0, 7.7, -1.9)), M.SmoothPlastic, rgb(230, 184, 36))
		stencil(warn, N.Front, "ADAMANTIUM", rgb(20, 18, 14), 50)
		cable(tank + Vector3.new(0, 8.8, 0), el, 1.5, 0.25, rgb(30, 30, 32))
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
	-- recovery bays: a gurney on castors with rails and bedding, an IV stand
	-- with a drip bag, and a curtain on a ceiling track
	for i = 0, 3 do
		local p = Vector3.new(-156, F, 64 + i * 7)
		local cf = CFrame.new(p) * CFrame.Angles(0, math.rad(90), 0)
		local frame = rgb(176, 182, 190)
		for _, x in { -2.6, 2.6 } do
			for _, z in { -1.1, 1.1 } do
				D(parent, Vector3.new(0.14, 1.5, 0.14), cf * CFrame.new(x, 1.05, z), M.Metal, frame)
				D(parent, Vector3.new(0.3, 0.3, 0.3), cf * CFrame.new(x, 0.15, z), M.Rubber, rgb(30, 30, 32), { Shape = Enum.PartType.Ball })
			end
		end
		P(parent, Vector3.new(6, 0.3, 2.6), cf * CFrame.new(0, 1.9, 0), M.Metal, frame)
		D(parent, Vector3.new(5.8, 0.4, 2.4), cf * CFrame.new(0, 2.25, 0), M.Fabric, rgb(214, 226, 232))
		D(parent, Vector3.new(1.2, 0.3, 1.8), cf * CFrame.new(2.2, 2.6, 0), M.Fabric, rgb(240, 242, 244))
		D(parent, Vector3.new(3.4, 0.1, 2.5), cf * CFrame.new(-0.9, 2.5, 0), M.Fabric, rgb(120, 170, 190))
		for _, z in { -1.35, 1.35 } do
			D(parent, Vector3.new(4.6, 0.1, 0.1), cf * CFrame.new(0, 2.7, z), M.Metal, frame)
		end
		local iv = p + Vector3.new(2.2, 0, -2.4)
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			D(parent, Vector3.new(0.1, 0.1, 0.8), CFrame.new(iv) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.12, -0.4), M.Metal, frame)
		end
		cyl(parent, iv + Vector3.new(0, 0.1, 0), iv + Vector3.new(0, 6.6, 0), 0.1, M.Metal, frame, nil, true)
		D(parent, Vector3.new(0.9, 0.08, 0.08), CFrame.new(iv + Vector3.new(0, 6.5, 0)), M.Metal, frame)
		D(parent, Vector3.new(0.5, 0.9, 0.24), CFrame.new(iv + Vector3.new(0.35, 5.8, 0)), M.Glass, rgb(210, 240, 255), { Transparency = 0.35 })
		cable(iv + Vector3.new(0.35, 5.3, 0), p + Vector3.new(1.4, 2.6, -0.8), 0.6, 0.05, rgb(220, 230, 235))
		D(parent, Vector3.new(0.16, 0.16, 7), CFrame.new(p + Vector3.new(3.4, 9.2, 0)), M.Metal, rgb(160, 164, 172)) -- curtain track
		for k = 0, 5 do -- a curtain in folds
			D(parent, Vector3.new(0.12, 7.6, 1.2), CFrame.new(p + Vector3.new(3.4 + (k % 2) * 0.16, 5.2, -3 + k * 1.1)) * CFrame.Angles(0, (k % 2 == 0 and 0.18 or -0.18), 0), M.Fabric, rgb(120, 170, 170))
		end
	end
	for i = 0, 3 do
		toolChest(parent, CFrame.new(-156, F, 104 + i * 5) * CFrame.Angles(0, math.rad(-90), 0), rgb(200, 204, 210))
	end
	-- instrument trolleys: two shelves on castors, a steel tray of tools
	for i = 0, 1 do
		local cart = CFrame.new(-126 + i * 16, F, 124)
		local frame = rgb(176, 182, 190)
		P(parent, Vector3.new(4, 0.16, 2.2), cart * CFrame.new(0, 3.2, 0), M.Metal, frame)
		D(parent, Vector3.new(4, 0.16, 2.2), cart * CFrame.new(0, 1.4, 0), M.Metal, frame)
		for _, x in { -1.85, 1.85 } do
			for _, z in { -0.95, 0.95 } do
				D(parent, Vector3.new(0.12, 3.1, 0.12), cart * CFrame.new(x, 1.75, z), M.Metal, frame)
				D(parent, Vector3.new(0.26, 0.26, 0.26), cart * CFrame.new(x, 0.13, z), M.Rubber, rgb(30, 30, 32), { Shape = Enum.PartType.Ball })
			end
		end
		D(parent, Vector3.new(0.1, 0.1, 2.2), cart * CFrame.new(2.15, 3.5, 0), M.Metal, frame) -- push handle
		D(parent, Vector3.new(3.2, 0.1, 1.6), cart * CFrame.new(-0.2, 3.33, 0), M.Metal, rgb(200, 206, 214), { Reflectance = 0.3 }) -- tray
		for k = 0, 4 do
			D(parent, Vector3.new(0.1, 0.06, 1.1), cart * CFrame.new(-1.3 + k * 0.55, 3.42, 0) * CFrame.Angles(0, 0.15 * k - 0.3, 0), M.Metal, rgb(214, 222, 232), { Reflectance = 0.45 })
		end
		for k = 0, 2 do
			D(parent, Vector3.new(0.9, 0.5, 0.7), cart * CFrame.new(-1.2 + k * 1.2, 1.73, 0), M.SmoothPlastic, rgb(220, 226, 232)) -- supply boxes
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
	wallRun(parent, -56, 56, 56, 56, 34, "Concrete", { door(56, 16, 12.4), door(20, 8, 10), door(92, 8, 10) }, { Extend = 0.7 })
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
-- LIFE & WEAR: what makes the facility feel lived in and torn up. Steam
-- venting from floor grates, torn cables spitting sparks, big wall fans
-- turning, leaks dripping into puddles, oil and grime on the floors, claw
-- gashes, debris and blood where Subject X has already been, dropped
-- paperwork, a few failing tubes and amber lockdown beacons sweeping the
-- halls. client/MapLife animates the tagged parts. The floor layers sit at fixed heights so nothing is coplanar:
-- painted lines F+0.04 (F+0.055 lifted), stencils F+0.066, the atrium's
-- glowing floor ring F+0.08, stains F+0.095, paper F+0.13,
-- grates and puddles F+0.16.
---------------------------------------------------------------------------

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local function seq(a, b)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

-- a soft, irregular stain on the floor: a few overlapping round blobs. All
-- stains share one height, so one that would overlap another is skipped.
local stainsPlaced = {}
local function stain(parent, x, z, w, d, yaw, color, alpha)
	local rad = math.sqrt(w * w + d * d) / 2 -- the rotated rectangle's reach
	if Vector2.new(x, z).Magnitude < 23 + rad then
		return nil -- the atrium's layered floor discs already fill those heights
	end
	for _, o in stainsPlaced do
		if (Vector2.new(x, z) - o[1]).Magnitude < rad + o[2] + 0.2 then
			return nil
		end
	end
	table.insert(stainsPlaced, { Vector2.new(x, z), rad })
	local p = D(parent, Vector3.new(w, 0.02, d), CFrame.new(x, F + 0.085, z) * CFrame.Angles(0, yaw, 0), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false })
	local g = sgui(p, N.Top, 12)
	for _ = 1, 3 do
		local b = fr(g, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + rng:NextNumber(-0.16, 0.16), 0.5 + rng:NextNumber(-0.16, 0.16)),
			Size = UDim2.fromScale(rng:NextNumber(0.55, 0.95), rng:NextNumber(0.55, 0.95)),
			BackgroundColor3 = color,
			BackgroundTransparency = alpha + rng:NextNumber(0, 0.12),
		})
		make("UICorner", b, { CornerRadius = UDim.new(0.5, 0) })
	end
	return p
end

-- a floor grate breathing steam, with a bigger hiss now and then
local function steamVent(parent, x, z)
	local g = D(parent, Vector3.new(2.6, 0.06, 2.6), CFrame.new(x, F + 0.13, z), M.Metal, rgb(40, 42, 46), { CanCollide = false })
	grille(g, N.Top, 2.6 * 24, false, rgb(10, 10, 12), rgb(84, 88, 94), 6)
	D(parent, Vector3.new(2.9, 0.04, 2.9), CFrame.new(x, F + 0.12, z), M.Metal, rgb(26, 27, 30), { CanCollide = false }) -- frame
	local src = D(parent, Vector3.new(2.2, 0.2, 2.2), CFrame.new(x, F + 0.4, z), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false })
	make("ParticleEmitter", src, {
		Name = "Steam", Texture = SMOKE, Shape = Enum.ParticleEmitterShape.Box,
		Color = ColorSequence.new(rgb(228, 232, 238)), LightEmission = 0.1, LightInfluence = 1,
		Size = seq(1.2, 5.5), Transparency = seq(0.55, 1),
		Lifetime = NumberRange.new(1.6, 2.8), Rate = 3, Speed = NumberRange.new(5, 9), SpreadAngle = Vector2.new(14, 14),
		Acceleration = Vector3.new(0, 1.5, 0), Drag = 1.2, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40),
		EmissionDirection = N.Top,
	})
	tag(src, "SteamBurst")
end

-- a cable torn out of the ceiling, frayed copper at its end spitting sparks
local function tornCable(parent, x, z, top)
	local a = Vector3.new(x, top, z)
	local tip = Vector3.new(x + rng:NextNumber(-1.2, 1.2), top - rng:NextNumber(3.2, 4.6), z + rng:NextNumber(-1.2, 1.2))
	D(parent, Vector3.new(1, 0.4, 1), CFrame.new(a + Vector3.new(0, 0.2, 0)), M.Metal, rgb(34, 36, 40), { CanCollide = false }) -- the ripped junction box
	cable(a, tip, 0.4, 0.28, rgb(20, 20, 22))
	cable(a + Vector3.new(0.3, 0, 0.2), tip + Vector3.new(0.35, 0.7, -0.2), 0.3, 0.2, rgb(150, 30, 24))
	for _ = 1, 3 do
		D(parent, Vector3.new(0.05, 0.4, 0.05), CFrame.new(tip) * CFrame.Angles(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8)) * CFrame.new(0, -0.18, 0), M.Metal, rgb(200, 120, 60), { CanCollide = false })
	end
	local spark = D(parent, Vector3.new(0.18, 0.18, 0.18), CFrame.new(tip), M.Neon, rgb(255, 170, 70), { CanCollide = false })
	make("ParticleEmitter", spark, {
		Name = "Sparks", Texture = SPARKLE,
		Color = ColorSequence.new(rgb(255, 232, 150), rgb(255, 120, 30)), LightEmission = 1, LightInfluence = 0,
		Size = seq(0.22, 0), Lifetime = NumberRange.new(0.4, 0.9), Rate = 0, Speed = NumberRange.new(4, 12),
		SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -40, 0), Drag = 1.5, EmissionDirection = N.Bottom,
	})
	pointLight(spark, 14, 0, rgb(170, 205, 255)) -- dark until MapLife flashes it
	tag(spark, "Sparks")
end

-- A big extractor fan on a wall: a dark throat, a ring housing, a guard and
-- five blades that turn (client/MapLife spins the "Spin" model).
-- cf sits on the wall face, facing into the room (-Z out).
local function wallFan(parent, cf, r)
	local dark = rgb(34, 36, 40)
	local out = CFrame.Angles(0, math.rad(90), 0) -- a cylinder along the fan's axis
	D(parent, Vector3.new(0.12, r * 2 + 0.3, r * 2 + 0.3), cf * CFrame.new(0, 0, -0.08) * out, M.SmoothPlastic, rgb(10, 10, 12), { Shape = Enum.PartType.Cylinder })
	for k = 0, 15 do -- the ring
		local a = k / 16 * math.pi * 2
		D(parent, Vector3.new(0.4, 2 * math.pi * (r + 0.2) / 16 * 1.12, 0.7), cf * CFrame.Angles(0, 0, a) * CFrame.new(r + 0.2, 0, -0.4), M.Metal, dark)
	end
	for _, a in { 0, 90 } do -- guard bars
		D(parent, Vector3.new(r * 2 + 0.2, 0.1, 0.1), cf * CFrame.Angles(0, 0, math.rad(a + 45)) * CFrame.new(0, 0, -0.78), M.Metal, rgb(60, 62, 68), { CanCollide = false })
	end
	local blades = Instance.new("Model")
	blades.Name = "FanBlades"
	D(blades, Vector3.new(0.4, 0.9, 0.9), cf * CFrame.new(0, 0, -0.4) * out, M.Metal, rgb(70, 72, 78), { Shape = Enum.PartType.Cylinder, CanCollide = false })
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		D(blades, Vector3.new(0.9, r - 0.35, 0.06), cf * CFrame.new(0, 0, -0.42) * CFrame.Angles(0, 0, a) * CFrame.new(0, (r - 0.35) / 2 + 0.3, 0) * CFrame.Angles(0, math.rad(28), 0), M.Metal, rgb(92, 96, 104), { CanCollide = false })
	end
	blades.WorldPivot = cf * CFrame.new(0, 0, -0.4) -- turns about the fan's axis (its Z)
	blades:SetAttribute("Speed", rng:NextNumber(5, 9))
	blades.Parent = parent
	tag(blades, "Spin")
end

-- a leak: water dripping from the ceiling into a puddle
local function leak(parent, x, z, top, size)
	D(parent, Vector3.new(0.04, size, size), CFrame.new(x, F + 0.14, z) * CFrame.Angles(0, 0, math.rad(90)), M.Glass, rgb(64, 78, 92),
		{ Shape = Enum.PartType.Cylinder, Transparency = 0.3, Reflectance = 0.3, CanCollide = false })
	local src = D(parent, Vector3.new(0.3, 0.1, 0.3), CFrame.new(x + 0.2, top - 0.4, z), M.Metal, rgb(90, 64, 40), { CanCollide = false }) -- the rusty seam it drips from
	local h = top - 0.4 - F
	make("ParticleEmitter", src, {
		Name = "Drip", Texture = SPARKLE,
		Color = ColorSequence.new(rgb(190, 215, 235)), LightEmission = 0.3, LightInfluence = 1,
		Size = seq(0.12, 0.1), Transparency = seq(0.1, 0.3),
		Lifetime = NumberRange.new(math.sqrt(2 * h / 60)), Rate = 1.6, Speed = NumberRange.new(0),
		Acceleration = Vector3.new(0, -60, 0), EmissionDirection = N.Bottom,
	})
end

-- Three claw gashes torn into a wall by Subject X, painted on a clear plate
-- just proud of the wall (a SurfaceGui, so they lie flat on it from every
-- angle): tapered, bowed dark cuts with bright torn-steel rims. cf sits on the
-- wall face facing into the room (-Z out); `out` clears that wall's trim.
local function wallGashes(parent, cf, len, out)
	local W, H, PPS = 8, len + 2, 30
	local plate = D(parent, Vector3.new(W, H, 0.05), cf * CFrame.new(0, 0, -out), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false })
	local g = sgui(plate, N.Front, PPS)
	local tilt = math.rad(-18)
	local function gui(x, y) -- wall studs (X along cf's right, Y up) to canvas pixels
		local X = x * math.cos(tilt) - y * math.sin(tilt)
		local Y = x * math.sin(tilt) + y * math.cos(tilt)
		return (W / 2 - X) * PPS, (H / 2 - Y) * PPS
	end
	for i = -1, 1 do
		local n = 8
		local function at(t)
			return i * 1.1 + 2 * t * (1 - t), (t - 0.5) * len + (i == 0 and 0.3 or 0)
		end
		for k = 0, n - 1 do
			local t0, t1 = k / n, (k + 1) / n
			local ax, ay = gui(at(t0))
			local bx, by = gui(at(t1))
			local w = (0.12 + 0.42 * math.sin(math.pi * (t0 + t1) / 2) ^ 0.7) * PPS
			local seg = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) + 6 -- overlap, so the cut runs smooth
			local rot = math.deg(math.atan2(-(bx - ax), by - ay))
			for layer, c in { { w + 5, rgb(190, 192, 198) }, { w, rgb(12, 10, 10) } } do
				fr(g, {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2),
					Size = UDim2.fromOffset(c[1], seg + (layer == 1 and 2 or 0)), Rotation = rot, BackgroundColor3 = c[2], ZIndex = layer,
				})
			end
		end
	end
	-- chunks knocked out of the wall
	local foot = (cf * CFrame.new(0, 0, -1.4)).Position
	for _ = 1, 6 do
		local s = rng:NextNumber(0.3, 0.8)
		D(parent, Vector3.new(s, s * 0.7, s), CFrame.new(foot.X + rng:NextNumber(-1.6, 1.6), F + s * 0.35, foot.Z + rng:NextNumber(-1.6, 1.6))
			* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), M.Concrete, rgb(96, 96, 100), { CanCollide = false })
	end
end

-- a failing fluorescent tube hanging off one chain, flickering
local function brokenTube(parent, x, z, top, yaw)
	local hang = CFrame.new(x, top - 1.8, z) * CFrame.Angles(0, yaw, math.rad(22))
	D(parent, Vector3.new(4.2, 0.3, 0.6), hang * CFrame.new(0, 0.24, 0), M.Metal, rgb(52, 54, 58), { CanCollide = false })
	local tube = D(parent, Vector3.new(3.9, 0.16, 0.16), hang, M.Neon, rgb(210, 226, 255), { CanCollide = false })
	pointLight(tube, 16, 0.8, rgb(200, 220, 255))
	tag(tube, "Flicker")
	local hook = (hang * CFrame.new(-2, 0.35, 0)).Position
	cable(Vector3.new(hook.X, top, hook.Z), hook, 0, 0.08, rgb(40, 40, 42))
end

-- A lockdown beacon hanging from the roof steel: an amber dome with a lamp
-- and reflector turning inside it, sweeping a beam round the room
-- (client/MapLife turns the "Spin" model about its Y axis). pos is the
-- dome's centre, poleTop the underside of the steel it hangs from, tilt how
-- far the beam dips (radians).
local function beacon(parent, pos, poleTop, tilt, reach)
	local dark, amber = rgb(30, 31, 34), rgb(255, 150, 40)
	local y = Vector3.yAxis
	cyl(parent, pos + y * 0.85, Vector3.new(pos.X, poleTop, pos.Z), 0.22, M.Metal, dark, nil, true)
	D(parent, Vector3.new(1.2, 0.12, 1.2), CFrame.new(pos.X, poleTop - 0.1, pos.Z), M.Metal, dark) -- clamp plate
	drum(parent, pos + y * 0.66, 1.4, 0.42, M.Metal, dark, nil, true)
	drum(parent, pos, 1.1, 0.9, M.Glass, amber, { Transparency = 0.45, Reflectance = 0.1 }, true)
	drum(parent, pos - y * 0.5, 0.8, 0.12, M.Metal, dark, nil, true)
	for k = 0, 3 do -- guard cage
		local a = k / 4 * math.pi * 2 + math.pi / 4
		D(parent, Vector3.new(0.08, 1.04, 0.08), CFrame.new(pos + Vector3.new(math.cos(a) * 0.62, -0.02, math.sin(a) * 0.62)), M.Metal, dark)
	end
	local spin = Instance.new("Model")
	spin.Name = "BeaconSpin"
	local ghost = { CanCollide = false }
	D(spin, Vector3.new(0.34, 0.34, 0.34), CFrame.new(pos), M.Neon, rgb(255, 204, 130), { Shape = Enum.PartType.Ball, CanCollide = false })
	for k = -1, 1 do -- a curved reflector behind the lamp
		D(spin, Vector3.new(0.26, 0.64, 0.05), CFrame.new(pos) * CFrame.Angles(0, k * 0.52, 0) * CFrame.new(0, 0, 0.34), M.Foil, rgb(255, 196, 120), ghost)
	end
	local head = D(spin, Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos) * CFrame.Angles(-tilt, 0, 0), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false })
	lightBudget += 1
	make("SpotLight", head, { Face = N.Front, Range = 36, Brightness = 7, Color = amber, Angle = 34, Shadows = false })
	-- the visible shaft of light, swept round with the lamp
	local a0 = make("Attachment", head, { Position = Vector3.new(0, 0, -0.3) })
	local a1 = make("Attachment", head, { Position = Vector3.new(0, 0, -reach) })
	make("Beam", head, {
		Attachment0 = a0, Attachment1 = a1, Width0 = 0.7, Width1 = reach * 0.55, FaceCamera = true, Segments = 1,
		Color = ColorSequence.new(rgb(255, 176, 80)), LightEmission = 1, LightInfluence = 0,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.6, 0.86), NumberSequenceKeypoint.new(1, 1) }),
	})
	spin.WorldPivot = CFrame.new(pos)
	spin:SetAttribute("Speed", 4.2)
	spin:SetAttribute("Axis", "Y")
	spin.Parent = parent
	tag(spin, "Spin")
end

local function lifeAndWear(parent, keepClear)
	stainsPlaced = {}
	local function free(x, z, pad)
		if not clearAt(x, z, pad) then
			return false
		end
		for _, p in keepClear do
			if (Vector3.new(x, 0, z) - Vector3.new(p.X, 0, p.Z)).Magnitude < pad + 5 then
				return false
			end
		end
		return true
	end
	local function top(x, z)
		local r = roomAt(x, z)
		return F + (r and r.h or 16) - 1.4
	end

	-- steam through floor grates
	for _, v in {
		{ -44, -74 }, { 40, -96 }, { -18, -128 }, { 12, -64 }, -- Foundry
		{ 66, -66 }, { 150, -70 }, { 72, -130 }, { 150, -130 }, -- Reactor
		{ -49, -49 }, { 49, -49 }, { -49, 49 }, { 49, 49 }, -- Ring corners
		{ -50, 62 }, { 50, 134 }, -- Hangar
	} do
		if free(v[1], v[2], 2) then
			steamVent(parent, v[1], v[2])
		end
	end
	-- torn cables spitting sparks
	for _, v in {
		{ -20, -49 }, { 28, 49 }, { -49, -24 }, { 49, 26 }, { -134, 40 }, { -70, -44 },
		{ 70, -44 }, { -120, -128 }, { 70, 132 }, { -150, 64 }, { 120, -62 },
	} do
		tornCable(parent, v[1], v[2], top(v[1], v[2]))
	end
	-- extractor fans high on the outer walls
	for _, v in {
		{ Vector3.new(160, F + 14, -110), Vector3.new(-1, 0, 0) }, { Vector3.new(160, F + 14, -84), Vector3.new(-1, 0, 0) }, -- Reactor
		{ Vector3.new(-160, F + 12, -24), Vector3.new(1, 0, 0) }, { Vector3.new(-160, F + 12, 24), Vector3.new(1, 0, 0) }, -- Server core
		{ Vector3.new(-30, F + 19, -140), Vector3.new(0, 0, 1) }, { Vector3.new(30, F + 19, -140), Vector3.new(0, 0, 1) }, -- Foundry
	} do
		wallFan(parent, CFrame.lookAt(v[1], v[1] + v[2]), 2.4)
	end
	-- leaks
	local puddles = {}
	for _, v in { { 120, -30, 3.4 }, { 150, 10, 2.6 }, { 128, 42, 3 }, { -30, 49, 3 }, { 49, -20, 2.4 }, { 84, 132, 2.8 }, { -150, 132, 2.6 }, { 150, 100, 2.4 } } do
		if free(v[1], v[2], 2) then
			leak(parent, v[1], v[2], top(v[1], v[2]) + 1.2, v[3])
			table.insert(puddles, v)
		end
	end
	-- where he's already been: gashes, debris, blood
	local CONCRETE, OFFICE, STEEL = 0.32, 0.32, 0.45
	for _, v in {
		{ Vector3.new(-26, F + 5.5, -55.3), Vector3.new(0, 0, 1), CONCRETE, true }, -- Ring N
		{ Vector3.new(18, F + 5.5, 55.3), Vector3.new(0, 0, -1), CONCRETE, true }, -- Ring S
		{ Vector3.new(107.4, F + 5, 129), Vector3.new(-1, 0, 0), OFFICE, true }, -- Canteen
		{ Vector3.new(-130, F + 5, -140), Vector3.new(0, 0, 1), OFFICE, false }, -- Archive
		{ Vector3.new(-160, F + 5, 92), Vector3.new(1, 0, 0), OFFICE, true }, -- Surgery
		{ Vector3.new(107.4, F + 5, -48), Vector3.new(-1, 0, 0), OFFICE, false }, -- Genetics
		{ Vector3.new(-107.4, F + 5, 48), Vector3.new(1, 0, 0), OFFICE, true }, -- Command
		{ Vector3.new(44, F + 6, -140), Vector3.new(0, 0, 1), STEEL, false }, -- Foundry
	} do
		wallGashes(parent, CFrame.lookAt(v[1], v[1] + v[2]), 7, v[3])
		if v[4] then
			local at = v[1] + v[2] * 3.2
			stain(parent, at.X, at.Z, 3.2, 2.6, rng:NextNumber(0, 3), rgb(78, 6, 6), 0.2)
			local drag = v[1] + v[2] * 9 + v[2]:Cross(Vector3.yAxis) * rng:NextNumber(-2, 2)
			stain(parent, drag.X, drag.Z, 1.2, 6, math.atan2(v[2].X, v[2].Z) + rng:NextNumber(-0.4, 0.4), rgb(70, 6, 6), 0.35)
		end
	end
	-- oil and rust on the industrial floors (only there: on clean floors a
	-- dark blot reads as a hole)
	for _, r in ROOMS do
		local industrial = r.Id == "Foundry" or r.Id == "Reactor" or r.Id == "Hangar"
		local n = industrial and math.floor((r.x1 - r.x0) * (r.z1 - r.z0) / 500) or 0
		for _ = 1, n do
			local x, z = rng:NextNumber(r.x0 + 2, r.x1 - 2), rng:NextNumber(r.z0 + 2, r.z1 - 2)
			local wet = false
			for _, p in puddles do
				if (Vector2.new(x, z) - Vector2.new(p[1], p[2])).Magnitude < p[3] + 3 then
					wet = true
				end
			end
			if not wet and clearAt(x, z, 0) then
				local roll = rng:NextNumber()
				local s = rng:NextNumber(1.6, industrial and 5.5 or 3.5)
				if roll < 0.6 then
					stain(parent, x, z, s, s * rng:NextNumber(0.5, 0.9), rng:NextNumber(0, 3), rgb(24, 20, 16), 0.66) -- oil
				else
					stain(parent, x, z, s, s * 0.7, rng:NextNumber(0, 3), rgb(96, 54, 26), 0.72) -- rust
				end
			end
		end
	end
	-- paperwork everyone dropped running for it
	for _, b in { { -156, -136, -60, -60, 32 }, { -104, -52, -60, 52, 14 }, { -104, 60, -60, 136, 12 } } do
		for _ = 1, b[5] do
			local x, z = rng:NextNumber(b[1], b[3]), rng:NextNumber(b[2], b[4])
			if clearAt(x, z, 0) then
				D(parent, Vector3.new(0.85, 0.02, 1.1), CFrame.new(x, F + 0.12, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), M.SmoothPlastic,
					rng:NextNumber() < 0.8 and rgb(232, 230, 222) or rgb(236, 220, 150), { CanCollide = false })
			end
		end
	end
	-- lockdown beacons: from the ring's cross beams and the big rooms' trusses
	for _, v in { { -32, -49 }, { 32, -49 }, { -32, 49 }, { 32, 49 }, { -49, 0 }, { 49, 0 } } do
		beacon(parent, Vector3.new(v[1], F + 12.6, v[2]), F + 14.1, math.rad(12), 6)
	end
	for _, v in {
		{ -24, -103, "Foundry" }, { 24, -103, "Foundry" },
		{ 56 + 104 / 6, -103, "Reactor" }, { 160 - 104 / 6, -103, "Reactor" },
		{ -24, 93, "Hangar" }, { 24, 93, "Hangar" },
		{ -23, 25.2, "Atrium" }, { 23, -25.2, "Atrium" },
	} do
		local h = ROOM[v[3]].h
		beacon(parent, Vector3.new(v[1], F + h - 5.6, v[2]), F + h - 3.9, math.rad(30), 16)
	end
	-- failing tubes in the ring
	for _, v in { { 10, -49, 0 }, { -49, 30, math.pi / 2 }, { -10, 49, 0 }, { 49, -30, math.pi / 2 } } do
		brokenTube(parent, v[1], v[2], top(v[1], v[2]) + 1.2, v[3])
	end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------

local function build()
	rng = Random.new(20260924)
	doorZones = {}
	Facility.DoorBoxes = {}
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
	local terminalsFolder = folder("Terminals")
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

	-- every candidate Sentinel console; three are picked (from different wings) each round
	local TERMINAL_SPOTS = {
		{ "Foundry", Vector3.new(26, F, -70), Vector3.new(0, 0, 1) },
		{ "Genetics", Vector3.new(100, F, 18), Vector3.new(-1, 0, 0) },
		{ "Genetics", Vector3.new(64, F, 12), Vector3.new(1, 0, 0) },
		{ "Cryo", Vector3.new(135, F, 2), Vector3.new(0, 0, -1) },
		{ "Command", Vector3.new(-66, F, -20), Vector3.new(0, 0, 1) },
		{ "Servers", Vector3.new(-113, F, -30), Vector3.new(-1, 0, 0) },
		{ "Reactor", Vector3.new(86, F, -110), Vector3.new(1, 0, 0) },
		{ "Archive", Vector3.new(-117, F, -74), Vector3.new(0, 0, 1) },
		{ "Canteen", Vector3.new(60, F, 110), Vector3.new(1, 0, 0) },
		{ "Quarters", Vector3.new(144, F, 62), Vector3.new(0, 0, 1) },
		{ "Reception", Vector3.new(-100, F, 62), Vector3.new(0, 0, 1) },
		{ "Hangar", Vector3.new(-38, F, 88), Vector3.new(1, 0, 0) },
	}
	for i, spot in TERMINAL_SPOTS do
		local m = console(terminalsFolder, spot[2], spot[3], ("Terminal_%s_%d"):format(spot[1], i))
		m:SetAttribute("Wing", spot[1])
	end
	local consoles = {}
	for _, spot in TERMINAL_SPOTS do
		table.insert(consoles, spot[2])
	end
	lifeAndWear(props, consoles)

	-- Everything Wolverine or a Sentinel could reasonably wreck is breakable:
	-- furniture, machines, screens, pods, pillars, door frames... Not the floor,
	-- ceilings, roof, outer shell, stairs, consoles or the docked suits. Parts
	-- parented to a breakable part go with it (so walls regrow with their trim).
	local function isSolid(d)
		local a = d
		while a and a ~= map do
			if a:GetAttribute("Solid") then
				return true
			end
			a = a.Parent
		end
		return false
	end
	for _, folderName in { "Props", "Structure" } do
		for _, d in map:FindFirstChild(folderName):GetDescendants() do
			if d:IsA("BasePart") and not d:GetAttribute("Breakable") and d.Transparency < 0.95 and not d.Parent:IsA("BasePart") then
				local sz = d.Size
				local biggest = math.max(sz.X, sz.Y, sz.Z)
				local volume = sz.X * sz.Y * sz.Z
				local onFloor = d.CFrame.Position.Y < F + 0.15 and sz.Y < 0.3
				if biggest <= 46 and volume <= 1600 and not onFloor and not isSolid(d) then
					d:SetAttribute("Breakable", true)
					d.CanQuery = true
				end
			end
		end
	end

	for i, p in spawnPoints do
		local s = P(spawns, Vector3.new(2, 1, 2), CFrame.new(p + Vector3.new(0, 0.5, 0)), M.SmoothPlastic, Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false })
		s.Name = "Spawn" .. i
	end
	map:SetAttribute("Lights", lightBudget)
	return map
end

-- The minimap's picture of the facility (client/Minimap): room rectangles and
-- every floor-standing wall piece, flattened to 2D. Published once as JSON so
-- players see the whole map even if distant parts haven't streamed in. Door
-- gaps show up naturally: the pieces above doorways don't reach the floor
-- (the wall under a window does, so windows read as wall, not a way through).
local function publishMinimap(map)
	local walls = {}
	local structure = map:FindFirstChild("Structure")
	for _, d in structure and structure:GetDescendants() or {} do
		if d:IsA("BasePart") and d.Transparency < 0.5 and d.Size.Y >= 2.5 and d.Position.Y - d.Size.Y / 2 <= F + 1.5 then
			local cf, sz = d.CFrame, d.Size
			local along, len, thick = cf.LookVector, sz.Z, sz.X
			if sz.X > sz.Z then
				along, len, thick = cf.RightVector, sz.X, sz.Z
			end
			if thick <= 3 and len >= 1 and math.abs(along.Y) < 0.2 then
				local r = function(v)
					return math.floor(v * 10 + 0.5) / 10
				end
				table.insert(walls, { r(cf.Position.X), r(cf.Position.Z), r(len), r(math.deg(math.atan2(along.Z, along.X))) })
			end
		end
	end
	local rooms = {}
	for _, rm in ROOMS do
		table.insert(rooms, { rm.Label, rm.x0, rm.z0, rm.x1, rm.z1, rm.Id })
	end
	-- where the Sentinel suits are docked (drawn as two Sentinel heads)
	local pod = map:FindFirstChild("SentinelPod")
	local podAt = pod and pod:GetPivot().Position
	ReplicatedStorage:SetAttribute("Minimap", HttpService:JSONEncode({
		Rooms = rooms,
		Walls = walls,
		Bounds = { -162, -142, 162, 142 },
		Pod = podAt and { math.floor(podAt.X + 0.5), math.floor(podAt.Z + 0.5) } or nil,
	}))
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
		publishMinimap(template)
	end
	local map = template:Clone()
	-- this round's three consoles: random spots in different wings, each with
	-- a different repair challenge, outlined in faint green so they can be found
	local terminals = map:FindFirstChild("Terminals")
	if terminals then
		local list = terminals:GetChildren()
		for i = #list, 2, -1 do
			local j = math.random(i)
			list[i], list[j] = list[j], list[i]
		end
		local challenges = { "Calibrate", "Wires", "Sequence", "Frequency", "Pressure" }
		for i = #challenges, 2, -1 do
			local j = math.random(i)
			challenges[i], challenges[j] = challenges[j], challenges[i]
		end
		local used, kept = {}, 0
		for _, term in list do
			local wing = term:GetAttribute("Wing")
			if kept < 3 and not used[wing] then
				used[wing] = true
				kept += 1
				term:SetAttribute("Challenge", challenges[kept])
				local h = Instance.new("Highlight")
				h.Name = "Finder" -- the same soft white glow as the hiding spots (client/HideGlow)
				h.FillColor = Color3.new(1, 1, 1)
				h.FillTransparency = 0.85
				h.OutlineColor = Color3.new(1, 1, 1)
				h.OutlineTransparency = 0.25
				h.DepthMode = Enum.HighlightDepthMode.Occluded
				h.Parent = term
			else
				term:Destroy()
			end
		end
	end
	map.Parent = workspace
	return map
end

return Facility
