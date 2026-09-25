-- Crisp anime-style slash VFX, drawn on each client every frame so they stay smooth.
--   SlashFX.Arc(char, side, color)          three razor-thin claw crescents that sweep
--                                            head-first and retract into a fine tail, plus sparks
--   SlashFX.HitFlash(pos, color, size, char) X-shaped star flare, needle burst, white-hot
--                                            core and a white body flash on the victim
-- Everything is built from beams (tapered, camera-facing ribbons) on attachments in
-- Terrain, whose attachment positions are world-space. No image assets are needed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SlashFX = {}

local DEFAULT_GLOW = Color3.fromRGB(210, 230, 255)
local WHITE = Color3.new(1, 1, 1)
local terrain = workspace.Terrain

---------------------------------------------------------------------------
-- Ribbons: a polyline of beams with a width per point (pooled)
---------------------------------------------------------------------------

local pool = {} -- [n] = { ribbon, ... }

local function takeRibbon(n, color, brightness)
	local free = pool[n]
	local r = free and table.remove(free)
	if not r then
		r = { N = n, Atts = table.create(n), Beams = table.create(n - 1) }
		for i = 1, n do
			local a = Instance.new("Attachment")
			a.Name = "SlashFX"
			a.Parent = terrain
			r.Atts[i] = a
		end
		for i = 1, n - 1 do
			local b = Instance.new("Beam")
			b.Attachment0 = r.Atts[i]
			b.Attachment1 = r.Atts[i + 1]
			b.FaceCamera = true
			b.Segments = 1
			b.LightInfluence = 0
			b.LightEmission = 1
			b.Width0 = 0
			b.Width1 = 0
			b.Parent = terrain
			r.Beams[i] = b
		end
	end
	local seq = ColorSequence.new(color)
	for _, b in r.Beams do
		b.Color = seq
		b.Brightness = brightness
		b.Enabled = true
	end
	r.T = nil
	return r
end

local function releaseRibbon(r)
	for _, b in r.Beams do
		b.Enabled = false
		b.Width0 = 0
		b.Width1 = 0
	end
	pool[r.N] = pool[r.N] or {}
	if #pool[r.N] < 24 then
		table.insert(pool[r.N], r)
	else
		for _, b in r.Beams do
			b:Destroy()
		end
		for _, a in r.Atts do
			a:Destroy()
		end
	end
end

local function setRibbon(r, points, widths, transparency)
	for i, a in r.Atts do
		a.Position = points[i]
	end
	for i, b in r.Beams do
		b.Width0 = widths[i]
		b.Width1 = widths[i + 1]
	end
	transparency = math.clamp(transparency, 0, 1)
	if r.T ~= transparency then
		r.T = transparency
		local seq = NumberSequence.new(transparency)
		for _, b in r.Beams do
			b.Transparency = seq
		end
	end
end

local function hideRibbon(r)
	for _, b in r.Beams do
		b.Width0 = 0
		b.Width1 = 0
	end
end

-- A 5-point needle: sharp at both ends with a concave taper, so it reads as a spike
local NEEDLE_W = { 0, 0.22, 1, 0.22, 0 }
local needlePts, needleW = table.create(5), table.create(5)
local function setNeedle(r, a, b, width, transparency)
	for i = 1, 5 do
		needlePts[i] = a:Lerp(b, (i - 1) / 4)
		needleW[i] = NEEDLE_W[i] * width
	end
	setRibbon(r, needlePts, needleW, transparency)
end

---------------------------------------------------------------------------
-- Frame loop
---------------------------------------------------------------------------

local active = {}
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for i = #active, 1, -1 do
		local fx = active[i]
		local ok, alive = pcall(fx.Step, now - fx.Start)
		if not ok or not alive then
			table.remove(active, i)
			for _, r in fx.Ribbons do
				releaseRibbon(r)
			end
		end
	end
end)

local function run(ribbons, step)
	table.insert(active, { Start = os.clock(), Ribbons = ribbons, Step = step })
end

local function clamp01(x)
	return math.clamp(x, 0, 1)
end
local function outCubic(x)
	return 1 - (1 - x) ^ 3
end
local function outQuad(x)
	return 1 - (1 - x) ^ 2
end
local function outExpo(x)
	return x >= 1 and 1 or 1 - 2 ^ (-10 * x)
end

---------------------------------------------------------------------------
-- Claw crescents
---------------------------------------------------------------------------

local ARC_N = 22
local HEAD_TIME = 0.085 -- blade tip sweeps the full arc
local TAIL_DELAY = 0.03
local TAIL_TIME = 0.2 -- tail chases the tip and the slash dissolves
local SWEEP = math.rad(78)

-- width along the visible part: needle-thin tail, fattest near the tip, razor point
local PROFILE_PEAK = (0.8 ^ 1.4) * (0.2 ^ 0.35)
local function profile(s)
	return (s ^ 1.4) * ((1 - s) ^ 0.35) / PROFILE_PEAK
end

local function sparks(center, s, color, count)
	local ribbons, list = {}, {}
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	for i = 1, count do
		local r = takeRibbon(5, i % 2 == 0 and WHITE or color, 4)
		table.insert(ribbons, r)
		local a = math.random() * math.pi * 2
		list[i] = {
			R = r,
			A = a,
			R0 = (0.25 + math.random() * 0.35) * s,
			R1 = (1.2 + math.random() * 1.1) * s,
			L = (0.55 + math.random() * 0.5) * s,
			Life = 0.13 + math.random() * 0.08,
		}
	end
	run(ribbons, function(t)
		local cf = cam.CFrame
		local alive = false
		for _, sp in list do
			local k = t / sp.Life
			if k < 1 then
				alive = true
				local d = cf.RightVector * math.cos(sp.A) + cf.UpVector * math.sin(sp.A)
				local r = sp.R0 + (sp.R1 - sp.R0) * outQuad(k)
				local len = sp.L * (1 - k * 0.75)
				setNeedle(sp.R, center + d * r, center + d * (r + len), 0.075 * s * (1 - k), k > 0.5 and (k - 0.5) * 2 or 0)
			else
				hideRibbon(sp.R)
			end
		end
		return alive
	end)
end

function SlashFX.Arc(char, side, color)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	color = color or char:GetAttribute("ClawGlow") or DEFAULT_GLOW
	local dir = side == "L" and -1 or 1
	local s = math.max(0.6, root.Size.Y / 2) -- follows character scale (Wolverine is 1.15x)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	-- The swing is an arch in front of him that bows away from the camera, rolled so
	-- the claws come down from high on the swinging side (reads as a crescent from behind).
	local rot = CFrame.lookAt(Vector3.zero, look)
	local roll = math.rad(38 * dir)
	local cr, sr = math.cos(roll), math.sin(roll)
	local from, to = SWEEP * dir, -SWEEP * dir
	local function arcPoint(center, a, rc)
		local x, y = rc * math.sin(a), rc * math.cos(a) - rc * 0.55
		local z = -(2.6 + 1.3 * math.cos(a)) * s
		return center + rot:VectorToWorldSpace(Vector3.new(x * cr - y * sr, x * sr + y * cr, z))
	end

	local claws, ribbons = {}, {}
	for k = -1, 1 do
		local c = {
			Radius = (3.3 + k * 0.42) * s,
			Delay = (k + 1) * 0.011,
			Width = (0.2 - math.abs(k) * 0.035) * s,
			Glow = takeRibbon(ARC_N, color, 2.2),
			Core = takeRibbon(ARC_N, WHITE, 5),
		}
		table.insert(claws, c)
		table.insert(ribbons, c.Glow)
		table.insert(ribbons, c.Core)
	end

	local pts, coreW, glowW = table.create(ARC_N), table.create(ARC_N), table.create(ARC_N)
	local sparked = false
	run(ribbons, function(t)
		if not root.Parent then
			return false
		end
		local center = root.Position + Vector3.new(0, 0.5 * s, 0)
		local alive = false
		for _, c in claws do
			local tt = t - c.Delay
			if tt <= 0 then
				alive = true
				hideRibbon(c.Glow)
				hideRibbon(c.Core)
				continue
			end
			local head = outCubic(clamp01(tt / HEAD_TIME))
			local tail = outQuad(clamp01((tt - TAIL_DELAY) / TAIL_TIME))
			if tail >= 0.999 then
				hideRibbon(c.Glow)
				hideRibbon(c.Core)
				continue
			end
			alive = true
			local radius = c.Radius * (1 + 0.07 * tail)
			local thin = 1 - 0.55 * tail
			for i = 1, ARC_N do
				local u = (i - 1) / (ARC_N - 1)
				local a = from + (to - from) * (tail + (head - tail) * u)
				pts[i] = arcPoint(center, a, radius)
				local w = c.Width * profile(u) * thin
				coreW[i] = w
				glowW[i] = w * 3.4
			end
			setRibbon(c.Core, pts, coreW, tail > 0.55 and (tail - 0.55) / 0.45 or 0)
			setRibbon(c.Glow, pts, glowW, 0.4 + 0.6 * tail)
		end
		if not sparked and t > HEAD_TIME * 0.85 then
			sparked = true
			local p = arcPoint(center, from + (to - from) * 0.62, 3.1 * s)
			sparks(p, s, color, 6)
		end
		return alive
	end)
end

---------------------------------------------------------------------------
-- Hit flash
---------------------------------------------------------------------------

local function flashBody(char)
	if not (char and char.Parent) then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "HitFlash"
	h.FillColor = WHITE
	h.OutlineColor = WHITE
	h.FillTransparency = 0.05
	h.OutlineTransparency = 0.2
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = char
	task.delay(0.06, function()
		TweenService:Create(h, TweenInfo.new(0.14, Enum.EasingStyle.Quad), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	end)
	task.delay(0.3, function()
		h:Destroy()
	end)
end

function SlashFX.HitFlash(position, color, size, victim)
	local cam = workspace.CurrentCamera
	if not (cam and position) then
		return
	end
	color = color or DEFAULT_GLOW
	size = size or 1
	flashBody(victim)

	-- white-hot core + light
	local core = Instance.new("Part")
	core.Shape = Enum.PartType.Ball
	core.Anchored, core.CanCollide, core.CanQuery, core.CanTouch, core.CastShadow = true, false, false, false, false
	core.Material = Enum.Material.Neon
	core.Color = WHITE
	core.Size = Vector3.one * 1.3 * size
	core.Position = position
	core.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18 * size
	light.Brightness = 7
	light.Parent = core
	TweenService:Create(core, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Size = Vector3.one * 3 * size, Transparency = 1 }):Play()
	TweenService:Create(light, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	task.delay(0.3, function()
		core:Destroy()
	end)

	local ribbons = {}
	-- the X: one long diagonal spike + a shorter crossing one
	local base = math.rad(25 + math.random() * 30) * (math.random() < 0.5 and 1 or -1)
	local cross = {
		{ A = base, L = 10 * size, W = 0.5 * size },
		{ A = base + math.rad(75 + math.random() * 30), L = 6.5 * size, W = 0.4 * size },
	}
	for _, c in cross do
		c.Glow = takeRibbon(5, color, 2.5)
		c.Core = takeRibbon(5, WHITE, 6)
		table.insert(ribbons, c.Glow)
		table.insert(ribbons, c.Core)
	end
	-- starburst needles
	local burst = {}
	for i = 1, 14 do
		local r = takeRibbon(5, i % 3 == 0 and color or WHITE:Lerp(color, 0.35), 4)
		table.insert(ribbons, r)
		burst[i] = {
			R = r,
			A = math.random() * math.pi * 2,
			R0 = (0.35 + math.random() * 0.6) * size,
			R1 = (2.6 + math.random() * 3.4) * size,
			L = (0.9 + math.random() * 1.6) * size,
			W = (0.09 + math.random() * 0.07) * size,
			Life = 0.17 + math.random() * 0.13,
		}
	end

	local LIFE = 0.34
	run(ribbons, function(t)
		local cf = cam.CFrame
		-- pull the flare toward the camera so it isn't buried inside the body
		local p = position + (cf.Position - position).Unit * 1.6 * size
		local right, up = cf.RightVector, cf.UpVector
		local k = t / LIFE
		if k >= 1 then
			return false
		end
		local grow = outExpo(clamp01(t / 0.05))
		for _, c in cross do
			local d = right * math.cos(c.A) + up * math.sin(c.A)
			local half = c.L * (0.2 + 0.8 * grow) * (1 + 0.18 * k) / 2
			local w = c.W * (1 - k) ^ 1.4
			setNeedle(c.Core, p - d * half, p + d * half, w, k < 0.35 and 0 or (k - 0.35) / 0.65)
			setNeedle(c.Glow, p - d * half * 1.05, p + d * half * 1.05, w * 3, 0.3 + 0.7 * k)
		end
		for _, b in burst do
			local q = t / b.Life
			if q < 1 then
				local d = right * math.cos(b.A) + up * math.sin(b.A)
				local r = b.R0 + (b.R1 - b.R0) * outQuad(q)
				local len = b.L * (1 - q * 0.7)
				setNeedle(b.R, p + d * r, p + d * (r + len), b.W * (1 - q), q > 0.5 and (q - 0.5) * 2 or 0)
			else
				hideRibbon(b.R)
			end
		end
		return true
	end)
end

---------------------------------------------------------------------------
-- Sentinel laser
---------------------------------------------------------------------------

local LASER_RED = Color3.fromRGB(255, 50, 40)
local function starFlare(pos, color, size, life)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local ribbons, spikes = {}, {}
	for i = 1, 8 do
		local r = takeRibbon(5, i <= 2 and WHITE or color, i <= 2 and 6 or 3)
		table.insert(ribbons, r)
		spikes[i] = { R = r, A = (i <= 2 and (i * math.pi / 2 + 0.6) or math.random() * math.pi * 2), L = (i <= 2 and 5 or 1.5 + math.random() * 2) * size, W = (i <= 2 and 0.35 or 0.12) * size }
	end
	run(ribbons, function(t)
		local k = t / life
		if k >= 1 then
			return false
		end
		local cf = cam.CFrame
		local p = pos + (cf.Position - pos).Unit * 0.8
		for i, sp in spikes do
			local d = cf.RightVector * math.cos(sp.A) + cf.UpVector * math.sin(sp.A)
			if i <= 2 then
				local half = sp.L * (0.4 + 0.6 * outExpo(math.min(1, t / 0.05))) / 2
				setNeedle(sp.R, p - d * half, p + d * half, sp.W * (1 - k), k < 0.4 and 0 or (k - 0.4) / 0.6)
			else
				local r0 = 0.3 * size + sp.L * outQuad(k)
				setNeedle(sp.R, p + d * r0, p + d * (r0 + sp.L * (1 - k)), sp.W * (1 - k), k)
			end
		end
		return true
	end)
end

-- ring of ribbon segments facing `normal`
local function setRing(r, center, normal, radius, width, transparency)
	local n = r.N
	local side = normal:Cross(Vector3.new(0, 1, 0))
	if side.Magnitude < 0.01 then
		side = Vector3.new(1, 0, 0)
	end
	side = side.Unit
	local up = side:Cross(normal).Unit
	local pts, ws = table.create(n), table.create(n)
	for i = 1, n do
		local a = (i - 1) / (n - 1) * math.pi * 2
		pts[i] = center + (side * math.cos(a) + up * math.sin(a)) * radius
		ws[i] = width
	end
	setRibbon(r, pts, ws, transparency)
end

local function chestCF(char)
	local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
	if not torso then
		return nil
	end
	return torso.CFrame * CFrame.new(0, torso.Size.Y * 0.26, -torso.Size.Z * 0.9), torso
end

-- Charge-up: energy streaks pulled into a swelling, flickering core; shock
-- rings pulse outward and the whole area turns red.
function SlashFX.LaserCharge(char, duration)
	local c0, torso = chestCF(char)
	local cam = workspace.CurrentCamera
	if not (c0 and cam) then
		return
	end
	local LIFE = duration or 0.6
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Anchored, orb.CanCollide, orb.CanQuery, orb.CanTouch, orb.CastShadow = true, false, false, false, false
	orb.Material = Enum.Material.Neon
	orb.Size = Vector3.one * 0.3
	orb.Parent = workspace
	local shell = orb:Clone()
	shell.Material = Enum.Material.ForceField
	shell.Color = LASER_RED
	shell.Parent = workspace
	local pl = Instance.new("PointLight")
	pl.Color = LASER_RED
	pl.Parent = orb
	local ribbons, streaks, rings = {}, {}, {}
	for i = 1, 16 do
		local r = takeRibbon(5, i % 3 == 0 and WHITE or LASER_RED, 6)
		table.insert(ribbons, r)
		streaks[i] = { R = r, A = math.random() * math.pi * 2, D = 4 + math.random() * 4, Delay = math.random() * LIFE * 0.4 }
	end
	for i = 1, 3 do
		local r = takeRibbon(24, i == 2 and WHITE or LASER_RED, 5)
		table.insert(ribbons, r)
		rings[i] = { R = r, Start = (i - 1) * LIFE / 3 }
	end
	if _G.WolverineShake and (cam.CFrame.Position - c0.Position).Magnitude < 40 then
		_G.WolverineShake(0.25)
	end
	run(ribbons, function(t)
		local k = t / LIFE
		if k >= 1 or not torso.Parent then
			orb:Destroy()
			shell:Destroy()
			return false
		end
		local c = chestCF(char) or c0
		local jitter = 0.85 + math.random() * 0.3
		orb.CFrame = c
		orb.Size = Vector3.one * (0.3 + 2.4 * k * k) * jitter
		orb.Color = LASER_RED:Lerp(WHITE, k)
		shell.CFrame = c
		shell.Size = orb.Size * 1.8
		pl.Range = 6 + 30 * k
		pl.Brightness = 1 + 8 * k
		local cf = cam.CFrame
		for _, st in streaks do
			local q = math.clamp((t - st.Delay) / (LIFE - st.Delay), 0, 1)
			local d = cf.RightVector * math.cos(st.A) + cf.UpVector * math.sin(st.A)
			local r = st.D * (1 - q)
			setNeedle(st.R, c.Position + d * r, c.Position + d * (r + 2 * (1 - q) + 0.2), 0.16 * (1 - q * 0.5), (q <= 0 or q >= 1) and 1 or 0)
		end
		for _, rg in rings do
			local q = (t - rg.Start) / (LIFE / 2)
			if q > 0 and q < 1 then
				setRing(rg.R, c.Position, c.LookVector, 0.6 + 4 * outQuad(q), 0.12 * (1 - q), q)
			else
				hideRibbon(rg.R)
			end
		end
		return true
	end)
end

-- Persistent death ray per Sentinel, fed by the server ~15x a second and
-- smoothed every frame so aiming feels fluid. Layers, inside out: a white-hot
-- core, hot/red/crimson glows, two spiralling coils, lightning crackling
-- round it, energy slugs racing down it, a flaring star at the chest and a
-- molten impact with shock rings, sparks and a scorch mark.
local beams = {}

local LASER_HOT = Color3.fromRGB(255, 80, 55)
local LASER_DEEP = Color3.fromRGB(150, 0, 20)
local BOLT_N = 20
local PULSES = 5
local PULSE_SPEED = 240 -- studs/s the energy slugs race down the beam
local SPARKS = 20

-- the server sends the beam's full length when it hits nothing
local laserCfg = Config.Sentinel.Laser
local function openEnded(len)
	return math.abs(len - laserCfg.Range) < 3 or math.abs(len - laserCfg.Range * laserCfg.FarRangeMult) < 3
end

local function glowBall(color, material)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = material
	p.Color = color
	p.Size = Vector3.one * 0.2
	p.Parent = workspace
	return p
end

local function buildBeam(char)
	local COIL_N = 32
	local b = {
		Core = takeRibbon(2, WHITE, 12),
		Inner = takeRibbon(2, LASER_HOT, 7),
		Glow = takeRibbon(2, LASER_RED, 5),
		Halo = takeRibbon(2, Color3.fromRGB(200, 10, 30), 2.5),
		-- two faint wide layers so the outer glow fades out instead of ending in a hard edge
		Auras = { takeRibbon(2, LASER_DEEP, 1.5), takeRibbon(2, LASER_DEEP, 1.2) },
		Coils = { takeRibbon(COIL_N, Color3.fromRGB(255, 90, 70), 6), takeRibbon(COIL_N, WHITE, 6) },
		Muzzle = takeRibbon(24, WHITE, 6),
		Muzzle2 = takeRibbon(24, LASER_RED, 5),
		ImpactRings = { takeRibbon(24, WHITE, 6), takeRibbon(24, LASER_RED, 5) },
		Bolts = {},
		Pulses = {},
		Flare = {},
		Sparks = {},
		COIL_N = COIL_N,
		Start = os.clock(),
		LastUpdate = os.clock(),
		Ending = nil,
	}
	b.Ribbons = { b.Core, b.Inner, b.Glow, b.Halo, b.Auras[1], b.Auras[2], b.Coils[1], b.Coils[2], b.Muzzle, b.Muzzle2, b.ImpactRings[1], b.ImpactRings[2] }
	for i = 1, 3 do
		local r = takeRibbon(BOLT_N, i == 1 and WHITE or Color3.fromRGB(255, 110, 90), 7)
		table.insert(b.Ribbons, r)
		b.Bolts[i] = { R = r, Next = 0, Offs = table.create(BOLT_N) }
	end
	for i = 1, PULSES do
		local r = takeRibbon(5, WHITE, 9)
		table.insert(b.Ribbons, r)
		b.Pulses[i] = { R = r, Phase = (i - 1) / PULSES }
	end
	for i = 1, 4 do
		local r = takeRibbon(5, i <= 2 and WHITE or LASER_RED, i <= 2 and 8 or 5)
		table.insert(b.Ribbons, r)
		b.Flare[i] = { R = r, A = (i - 1) * math.pi / 4 + (i <= 2 and 0 or math.pi / 8), L = i <= 2 and 9 or 5, W = i <= 2 and 0.5 or 0.3 }
	end
	for i = 1, SPARKS do
		local r = takeRibbon(5, i % 3 == 0 and WHITE or Color3.fromRGB(255, 170, 60), 6)
		table.insert(b.Ribbons, r)
		b.Sparks[i] = { R = r, T = -math.random() * 0.35 }
	end
	local holder = Instance.new("Part")
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.Transparency = true, false, false, false, 1
	holder.Size = Vector3.one * 0.2
	holder.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = LASER_RED
	light.Brightness = 7
	light.Range = 40
	light.Parent = holder
	b.Holder, b.Light = holder, light
	-- white-hot balls at the chest and the impact, each in a red heat shell
	b.MuzzleOrb = glowBall(WHITE, Enum.Material.Neon)
	b.MuzzleShell = glowBall(LASER_RED, Enum.Material.ForceField)
	b.ImpactOrb = glowBall(WHITE, Enum.Material.Neon)
	b.ImpactShell = glowBall(LASER_RED, Enum.Material.ForceField)
	local impactLight = Instance.new("PointLight")
	impactLight.Color = Color3.fromRGB(255, 90, 50)
	impactLight.Brightness = 8
	impactLight.Range = 24
	impactLight.Parent = b.ImpactOrb
	b.ImpactLight = impactLight
	b.Parts = { holder, b.MuzzleOrb, b.MuzzleShell, b.ImpactOrb, b.ImpactShell }
	return b
end

function SlashFX.BeamUpdate(char, from, to, hit, burns)
	if not (char and from and to) then
		return
	end
	local b = beams[char]
	if not b then
		b = buildBeam(char)
		b.From, b.To = from, to
		b.TargetFrom, b.TargetTo = from, to
		beams[char] = b
		starFlare(from, LASER_RED, 2.2, 0.6)
		local cam = workspace.CurrentCamera
		if _G.WolverineShake and cam then
			local d = (cam.CFrame.Position - from).Magnitude
			_G.WolverineShake(math.clamp(0.7 - d / 150, 0.2, 0.7))
		end
		local cpts, cw = table.create(b.COIL_N), table.create(b.COIL_N)
		local bpts, bw = table.create(BOLT_N), table.create(BOLT_N)
		run(b.Ribbons, function(t)
			local now = os.clock()
			-- safety: the server stopped talking
			if not b.Ending and now - b.LastUpdate > 0.5 then
				b.Ending = now
			end
			local fade = 1
			if b.Ending then
				fade = 1 - (now - b.Ending) / 0.25
				if fade <= 0 then
					for _, p in b.Parts do
						p:Destroy()
					end
					if beams[char] == b then
						beams[char] = nil
					end
					return false
				end
			end
			local alpha = math.min(1, (now - (b.Frame or now)) * 18)
			b.Frame = now
			b.From = b.From:Lerp(b.TargetFrom, alpha)
			b.To = b.To:Lerp(b.TargetTo, alpha)
			local from2, to2 = b.From, b.To
			local len = (to2 - from2).Magnitude
			if len < 0.1 then
				return true
			end
			local dir = (to2 - from2) / len
			local on = outExpo(math.min(1, t / 0.06))
			local surge = 1 + math.sin(t * 70) * 0.1 + (math.random() - 0.5) * 0.14
			local w = on * fade * surge
			local punch = 1 + math.max(0, 1 - t / 0.2) * 1.2
			local wp = w * punch
			local pts = { from2, to2 }
			setRibbon(b.Core, pts, { 0.85 * wp, 0.7 * wp }, 0)
			setRibbon(b.Inner, pts, { 2.0 * wp, 1.6 * wp }, 0.1)
			setRibbon(b.Glow, pts, { 4.2 * wp, 3.4 * wp }, 0.35)
			setRibbon(b.Halo, pts, { 7 * wp, 5.6 * wp }, 0.65)
			setRibbon(b.Auras[1], pts, { 10 * wp, 8 * wp }, 0.84)
			setRibbon(b.Auras[2], pts, { 13.5 * wp, 11 * wp }, 0.92)
			local side = dir:Cross(Vector3.new(0, 1, 0))
			side = side.Magnitude > 0.01 and side.Unit or Vector3.new(1, 0, 0)
			local up = side:Cross(dir).Unit
			for ci, coil in b.Coils do
				local phase = t * 26 + ci * math.pi
				for i = 1, b.COIL_N do
					local u = (i - 1) / (b.COIL_N - 1)
					local a = phase + u * len * 0.8
					local rad = 1.4 * w * (0.6 + 0.4 * math.sin(u * 14 + t * 30))
					cpts[i] = from2 + dir * (u * len) + (side * math.cos(a) + up * math.sin(a)) * rad
					cw[i] = 0.18 * w * (1 - u * 0.4)
				end
				setRibbon(coil, cpts, cw, 0.1)
			end
			-- lightning crackling round the beam, re-jagged many times a second
			for _, bolt in b.Bolts do
				if now >= bolt.Next then
					bolt.Next = now + 0.035 + math.random() * 0.05
					bolt.Show = math.random() < 0.85
					for i = 1, BOLT_N do
						bolt.Offs[i] = { math.random() * math.pi * 2, 1.2 + math.random() * 1.8 }
					end
				end
				if bolt.Show then
					for i = 1, BOLT_N do
						local u = (i - 1) / (BOLT_N - 1)
						local pin = math.sin(u * math.pi) ^ 0.4 -- both ends sit on the beam
						local o = bolt.Offs[i]
						bpts[i] = from2 + dir * (u * len) + (side * math.cos(o[1]) + up * math.sin(o[1])) * (o[2] * w * pin)
						bw[i] = 0.16 * w
					end
					setRibbon(bolt.R, bpts, bw, 0)
				else
					hideRibbon(bolt.R)
				end
			end
			-- energy slugs racing from the suit to the target
			for _, pulse in b.Pulses do
				local u = (t * PULSE_SPEED / len + pulse.Phase) % 1
				local half = math.min(4, len * 0.05)
				local p = from2 + dir * (u * len)
				setNeedle(pulse.R, p - dir * half, p + dir * half, 2.2 * w, 0.1 + 0.5 * u)
			end
			-- muzzle: double ring, a rotating star and a white-hot ball at the chest
			setRing(b.Muzzle, from2 + dir * 0.6, dir, 1.8 + math.sin(t * 40) * 0.3, 0.24 * w, 0.15)
			setRing(b.Muzzle2, from2 + dir * 1.6, dir, 2.6 + math.sin(t * 33 + 1) * 0.4, 0.2 * w, 0.4)
			local cam = workspace.CurrentCamera
			if cam then
				local cf = cam.CFrame
				local p = from2 + (cf.Position - from2).Unit * 0.8
				for i, sp in b.Flare do
					local a = sp.A + t * (i <= 2 and 0.8 or -1.2)
					local d = cf.RightVector * math.cos(a) + cf.UpVector * math.sin(a)
					local l = sp.L * (0.85 + math.random() * 0.3) * w / 2
					setNeedle(sp.R, p - d * l, p + d * l, sp.W * w, 0.05)
				end
			end
			local orb = (1.5 + math.random() * 0.4) * w
			b.MuzzleOrb.Size = Vector3.one * orb
			b.MuzzleOrb.Position = from2
			b.MuzzleShell.Size = Vector3.one * orb * 2.2
			b.MuzzleShell.Position = from2
			-- impact: molten ball, shock rings, sparks (nothing if it hits thin air)
			local open = openEnded(len)
			for ri, ring in b.ImpactRings do
				local q = (t / 0.24 + ri * 0.5) % 1
				if open then
					hideRibbon(ring)
				else
					setRing(ring, to2 - dir * 0.3, dir, 0.8 + 5 * outQuad(q), 0.35 * (1 - q) * w, q)
				end
			end
			local imp = open and 0 or (2.2 + math.random() * 0.8) * w
			b.ImpactOrb.Size = Vector3.one * math.max(0.05, imp)
			b.ImpactOrb.Position = to2 - dir * 0.4
			b.ImpactOrb.Transparency = open and 1 or 0
			b.ImpactShell.Size = Vector3.one * math.max(0.05, imp * 2)
			b.ImpactShell.Position = to2 - dir * 0.4
			b.ImpactShell.Transparency = open and 1 or 0
			b.ImpactLight.Enabled = not open
			b.ImpactLight.Brightness = 8 * fade
			for _, sp in b.Sparks do
				sp.T += 1 / 60
				local q = sp.T / 0.35
				if q >= 1 and not b.Ending and not open then
					sp.T = 0
					sp.D = (-dir + Vector3.new(math.random() - 0.5, math.random() * 0.9, math.random() - 0.5) * 1.9).Unit
					sp.Speed = 18 + math.random() * 26
					sp.Origin = to2
					q = 0
				end
				if q > 0 and q < 1 and sp.D then
					local p0 = sp.Origin + sp.D * sp.Speed * 0.35 * q + Vector3.new(0, -8 * q * q, 0)
					setNeedle(sp.R, p0, p0 + sp.D * 1.4, 0.12, q)
				else
					hideRibbon(sp.R)
				end
			end
			b.Holder.Position = (from2 + to2) / 2
			b.Light.Range = math.min(60, len / 2 + 14)
			b.Light.Brightness = 7 * fade
			-- a low rumble for anyone near either end
			if cam and _G.WolverineShake and now - (b.LastRumble or 0) > 0.1 then
				b.LastRumble = now
				local d = math.min((cam.CFrame.Position - from2).Magnitude, open and math.huge or (cam.CFrame.Position - to2).Magnitude)
				if d < 45 then
					_G.WolverineShake(0.12 * (1 - d / 45) * fade)
				end
			end
			return true
		end)
	end
	b.TargetFrom, b.TargetTo = from, to
	b.LastUpdate = os.clock()
	b.Ending = nil
	for _, p in burns or {} do
		starFlare(p, Color3.fromRGB(255, 150, 60), 1.4, 0.5)
	end
	if hit and os.clock() - (b.LastHitFlash or 0) > 0.3 then
		b.LastHitFlash = os.clock()
		SlashFX.HitFlash(to, LASER_RED, 1.5)
	end
	local dir = (to - from)
	if dir.Magnitude > 0.1 and not openEnded(dir.Magnitude) and os.clock() - (b.LastScorch or 0) > 0.25 then
		b.LastScorch = os.clock()
		dir = dir.Unit
		local scorch = Instance.new("Part")
		scorch.Shape = Enum.PartType.Cylinder
		scorch.Anchored, scorch.CanCollide, scorch.CanQuery, scorch.CanTouch, scorch.CastShadow = true, false, false, false, false
		scorch.Material = Enum.Material.Neon
		scorch.Color = Color3.fromRGB(255, 120, 40)
		scorch.Size = Vector3.new(0.06, 3.2, 3.2)
		scorch.CFrame = CFrame.lookAt(to - dir * 0.05, to - dir) * CFrame.Angles(0, math.rad(90), 0)
		scorch.Parent = workspace
		TweenService:Create(scorch, TweenInfo.new(2.6), { Color = Color3.fromRGB(30, 20, 18), Transparency = 1, Size = Vector3.new(0.06, 2, 2) }):Play()
		task.delay(2.7, function()
			scorch:Destroy()
		end)
	end
end

function SlashFX.BeamEnd(char)
	local b = beams[char]
	if b and not b.Ending then
		b.Ending = os.clock()
		starFlare(b.To, Color3.fromRGB(255, 160, 80), 1.6, 0.5)
	end
end

-- Sentinel M1: a hydraulic smash. Shock ring blasts off the fist, streaks
-- spear forward and a heavy flare lands on contact.
function SlashFX.Smash(char, position, dir, hit)
	local cam = workspace.CurrentCamera
	if not (position and dir and cam) then
		return
	end
	dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, 0, -1)
	local gold = Color3.fromRGB(255, 210, 90)
	local ribbons = {}
	local rings = {}
	for i = 1, 3 do
		local r = takeRibbon(28, i == 1 and WHITE or gold, i == 1 and 6 or 3)
		table.insert(ribbons, r)
		rings[i] = { R = r, Delay = (i - 1) * 0.04, Size = (hit and 5 or 3.5) + i }
	end
	local streaks = {}
	for i = 1, 10 do
		local r = takeRibbon(5, i % 2 == 0 and WHITE or gold, 4)
		table.insert(ribbons, r)
		local side = dir:Cross(Vector3.new(0, 1, 0))
		side = side.Magnitude > 0.01 and side.Unit or Vector3.new(1, 0, 0)
		local up = side:Cross(dir).Unit
		local a = math.random() * math.pi * 2
		streaks[i] = { R = r, Off = (side * math.cos(a) + up * math.sin(a)) * (0.6 + math.random() * 1.6), L = 2 + math.random() * 3 }
	end
	local LIFE = 0.35
	run(ribbons, function(t)
		local k = t / LIFE
		if k >= 1 then
			return false
		end
		for _, rg in rings do
			local q = math.clamp((t - rg.Delay) / (LIFE - rg.Delay), 0, 1)
			if q > 0 and q < 1 then
				setRing(rg.R, position + dir * (0.5 + q * 1.5), dir, 0.5 + rg.Size * outQuad(q), 0.3 * (1 - q), q)
			else
				hideRibbon(rg.R)
			end
		end
		for _, st in streaks do
			local p0 = position + st.Off + dir * (1 + 6 * outQuad(k))
			setNeedle(st.R, p0, p0 + dir * st.L * (1 - k), 0.12 * (1 - k), k)
		end
		return true
	end)
	if hit then
		SlashFX.HitFlash(position, gold, 1.5)
	end
end

---------------------------------------------------------------------------
-- Inhibitor Blast
---------------------------------------------------------------------------

local GOLD = Color3.fromRGB(255, 210, 90)
local pulseState = {}

-- jagged lightning between two points
local function setBolt(r, a, b, jag, width, transparency)
	local n = r.N
	local pts, ws = table.create(n), table.create(n)
	local d = b - a
	local side = d:Cross(Vector3.new(0, 1, 0))
	side = side.Magnitude > 0.01 and side.Unit or Vector3.new(1, 0, 0)
	local up = side:Cross(d.Unit)
	for i = 1, n do
		local u = (i - 1) / (n - 1)
		local off = (i == 1 or i == n) and Vector3.zero or (side * (math.random() - 0.5) + up * (math.random() - 0.5)) * jag
		pts[i] = a + d * u + off
		ws[i] = width * (1 - math.abs(u - 0.5))
	end
	setRibbon(r, pts, ws, transparency)
end

function SlashFX.PulseCharge(char, duration)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	duration = duration or 2
	local state = { Cancelled = false }
	pulseState[char] = state
	local sphere = Instance.new("Part")
	sphere.Shape = Enum.PartType.Ball
	sphere.Anchored, sphere.CanCollide, sphere.CanQuery, sphere.CanTouch, sphere.CastShadow = true, false, false, false, false
	sphere.Material = Enum.Material.ForceField
	sphere.Color = GOLD
	sphere.Size = Vector3.one * 2
	sphere.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Parent = sphere
	local ribbons, bolts = {}, {}
	for i = 1, 6 do
		local r = takeRibbon(8, i % 2 == 0 and WHITE or GOLD, 6)
		table.insert(ribbons, r)
		bolts[i] = r
	end
	local ring = takeRibbon(32, GOLD, 5)
	local ring2 = takeRibbon(32, WHITE, 5)
	table.insert(ribbons, ring)
	table.insert(ribbons, ring2)
	state.Sphere = sphere
	run(ribbons, function(t)
		local k = math.min(1, t / duration)
		if state.Cancelled or t > duration + 0.4 or not root.Parent then
			sphere:Destroy()
			return false
		end
		local s = root.Size.Y / 2
		local c = root.Position
		local rad = (3 + 5 * k * k) * s
		sphere.Position = c
		sphere.Size = Vector3.one * rad * (0.95 + math.random() * 0.1)
		light.Range = 8 + 22 * k
		light.Brightness = 1 + 6 * k
		-- lightning crawling over the sphere, more of it as the charge builds
		for i, b in bolts do
			if math.random() < 0.35 + 0.5 * k then
				local a1 = math.random() * math.pi * 2
				local a2 = a1 + (math.random() - 0.5) * 2
				local e1 = (math.random() - 0.5) * 1.6
				local p1 = c + Vector3.new(math.cos(a1) * math.cos(e1), math.sin(e1), math.sin(a1) * math.cos(e1)) * rad * 0.5
				local p2 = c + Vector3.new(math.cos(a2), (math.random() - 0.5), math.sin(a2)) * rad * 0.5
				setBolt(b, p1, p2, 0.8 * s, (0.1 + 0.12 * k) * s, 0)
			else
				hideRibbon(b)
			end
			_ = i
		end
		-- spinning ground rings tightening in
		local floor = c - Vector3.new(0, 2.8 * s, 0)
		setRing(ring, floor, Vector3.new(0, 1, 0), (7 - 3 * k) * s, 0.25 * s, 0.2)
		setRing(ring2, floor + Vector3.new(0, 0.05, 0), Vector3.new(0, 1, 0), (5 - 2.5 * k + math.sin(t * 20) * 0.2) * s, 0.12 * s, 0.1)
		return true
	end)
end

function SlashFX.PulseCancel(char)
	local st = pulseState[char]
	if st then
		st.Cancelled = true
		pulseState[char] = nil
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			starFlare(root.Position, GOLD, 0.8, 0.3)
		end
	end
end

function SlashFX.PulseBlast(position, radius)
	if not position then
		return
	end
	radius = radius or 20
	-- clear any charge visuals near this blast
	for char, st in pulseState do
		local r = char:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - position).Magnitude < 6 then
			st.Cancelled = true
			pulseState[char] = nil
		end
	end
	local dome = Instance.new("Part")
	dome.Shape = Enum.PartType.Ball
	dome.Anchored, dome.CanCollide, dome.CanQuery, dome.CanTouch, dome.CastShadow = true, false, false, false, false
	dome.Material = Enum.Material.ForceField
	dome.Color = GOLD
	dome.Size = Vector3.one * 4
	dome.Position = position
	dome.Parent = workspace
	local core = dome:Clone()
	core.Material = Enum.Material.Neon
	core.Color = WHITE
	core.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 60
	light.Brightness = 10
	light.Parent = core
	TweenService:Create(dome, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { Size = Vector3.one * radius * 2.2, Transparency = 1 }):Play()
	TweenService:Create(core, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = Vector3.one * 9, Transparency = 1 }):Play()
	TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	task.delay(0.7, function()
		dome:Destroy()
		core:Destroy()
	end)
	-- ground shock rings + lightning bolts ripping outward
	local ribbons, rings, bolts = {}, {}, {}
	for i = 1, 3 do
		local r = takeRibbon(40, i == 1 and WHITE or GOLD, 6)
		table.insert(ribbons, r)
		rings[i] = { R = r, Delay = (i - 1) * 0.07 }
	end
	for i = 1, 10 do
		local r = takeRibbon(9, i % 2 == 0 and WHITE or GOLD, 7)
		table.insert(ribbons, r)
		local a = i / 10 * math.pi * 2 + math.random() * 0.4
		bolts[i] = { R = r, Dir = Vector3.new(math.cos(a), (math.random() - 0.3) * 0.5, math.sin(a)).Unit }
	end
	local floor = position - Vector3.new(0, 2.6, 0)
	local LIFE = 0.55
	run(ribbons, function(t)
		local k = t / LIFE
		if k >= 1 then
			return false
		end
		for _, rg in rings do
			local q = math.clamp((t - rg.Delay) / (LIFE - rg.Delay), 0, 1)
			if q > 0 and q < 1 then
				setRing(rg.R, floor, Vector3.new(0, 1, 0), 2 + radius * 1.1 * outQuad(q), 0.6 * (1 - q), q)
			else
				hideRibbon(rg.R)
			end
		end
		for _, b in bolts do
			local len = radius * (0.3 + 0.9 * outQuad(math.min(1, k * 2)))
			setBolt(b.R, position, position + b.Dir * len, 1.6, 0.35 * (1 - k), k)
		end
		return true
	end)
	if _G.WolverineShake then
		local cam = workspace.CurrentCamera
		local d = cam and (cam.CFrame.Position - position).Magnitude or 999
		if d < radius * 3 then
			_G.WolverineShake(1.2 * (1 - d / (radius * 3)))
		end
	end
	SlashFX.HitFlash(position, GOLD, 2)
end

return SlashFX
