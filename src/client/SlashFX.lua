-- Crisp anime-style slash VFX, drawn on each client every frame so they stay smooth.
--   SlashFX.Arc(char, side, color)          three razor-thin claw crescents that sweep
--                                            head-first and retract into a fine tail, plus sparks
--   SlashFX.HitFlash(pos, color, size, char) X-shaped star flare, needle burst, white-hot
--                                            core and a white body flash on the victim
-- Everything is built from beams (tapered, camera-facing ribbons) on attachments in
-- Terrain, whose attachment positions are world-space. No image assets are needed.
local Players = game:GetService("Players")
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

-- a camera-facing star: two long white spikes crossing, needles bursting out
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
	local function arcPoint(center, a, rc, push)
		local x, y = rc * math.sin(a), rc * math.cos(a) - rc * 0.55
		local z = -(2.6 + 1.3 * math.cos(a)) * s - (push or 0)
		return center + rot:VectorToWorldSpace(Vector3.new(x * cr - y * sr, x * sr + y * cr, z))
	end

	-- three blades, each a white-hot edge in a coloured glow inside a wide faint
	-- smear (the motion blur of the swing)
	local claws, ribbons = {}, {}
	for k = -1, 1 do
		local c = {
			Radius = (3.3 + k * 0.45) * s,
			Delay = (k + 1) * 0.011,
			Width = (0.26 - math.abs(k) * 0.045) * s,
			Smear = takeRibbon(ARC_N, color, 1.3),
			Glow = takeRibbon(ARC_N, color, 2.6),
			Core = takeRibbon(ARC_N, WHITE, 6),
		}
		table.insert(claws, c)
		table.insert(ribbons, c.Smear)
		table.insert(ribbons, c.Glow)
		table.insert(ribbons, c.Core)
	end
	-- the slash wave: a crescent of cut air that flies on ahead of the claws
	local wave = { Core = takeRibbon(ARC_N, WHITE, 5), Glow = takeRibbon(ARC_N, color, 2.2) }
	table.insert(ribbons, wave.Core)
	table.insert(ribbons, wave.Glow)
	local WAVE_START, WAVE_LIFE = HEAD_TIME * 0.7, 0.22

	local pts, coreW, glowW, smearW = table.create(ARC_N), table.create(ARC_N), table.create(ARC_N), table.create(ARC_N)
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
				hideRibbon(c.Smear)
				hideRibbon(c.Glow)
				hideRibbon(c.Core)
				continue
			end
			local head = outCubic(clamp01(tt / HEAD_TIME))
			local tail = outQuad(clamp01((tt - TAIL_DELAY) / TAIL_TIME))
			if tail >= 0.999 then
				hideRibbon(c.Smear)
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
				glowW[i] = w * 3.6
				smearW[i] = w * 8
			end
			setRibbon(c.Core, pts, coreW, tail > 0.55 and (tail - 0.55) / 0.45 or 0)
			setRibbon(c.Glow, pts, glowW, 0.35 + 0.65 * tail)
			setRibbon(c.Smear, pts, smearW, 0.78 + 0.22 * tail)
		end
		local q = (t - WAVE_START) / WAVE_LIFE
		if q > 0 and q < 1 then
			alive = true
			local push = 12 * s * outQuad(q)
			for i = 1, ARC_N do
				local u = (i - 1) / (ARC_N - 1)
				local a = from + (to - from) * u
				pts[i] = arcPoint(center, a, 3.6 * s * (1 + 0.35 * q), push)
				local w = 0.22 * s * math.sin(u * math.pi) ^ 0.6 * (1 - q)
				coreW[i] = w
				glowW[i] = w * 4
			end
			setRibbon(wave.Core, pts, coreW, q)
			setRibbon(wave.Glow, pts, glowW, 0.45 + 0.55 * q)
		else
			hideRibbon(wave.Core)
			hideRibbon(wave.Glow)
			alive = alive or q <= 0
		end
		if not sparked and t > HEAD_TIME * 0.85 then
			sparked = true
			local p = arcPoint(center, from + (to - from) * 0.62, 3.1 * s)
			sparks(p, s * 1.3, color, 12)
			-- a glint on each blade tip as the swing finishes
			for _, c in claws do
				starFlare(arcPoint(center, to, c.Radius), color, 0.35 * s, 0.22)
			end
			if char == Players.LocalPlayer.Character and _G.WolverineShake then
				_G.WolverineShake(0.12)
			end
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

-- Three claw gashes raked across a hit: they rip open end to end in a blink,
-- hang for a moment (white-hot edge, claw-coloured glow, a wide red bleed)
-- and fade.
local BLEED = Color3.fromRGB(200, 10, 20)
local function clawRake(position, color, size)
	local cam = workspace.CurrentCamera
	local ribbons, gashes = {}, {}
	local base = math.rad(-50 - math.random() * 25) * (math.random() < 0.5 and 1 or -1)
	for k = -1, 1 do
		local g = {
			Off = k * 0.75 * size,
			L = (5.2 - math.abs(k) * 1.1) * size,
			Delay = (k + 1) * 0.012,
			Bleed = takeRibbon(5, BLEED, 2),
			Glow = takeRibbon(5, color, 3),
			Core = takeRibbon(5, WHITE, 7),
		}
		table.insert(ribbons, g.Bleed)
		table.insert(ribbons, g.Glow)
		table.insert(ribbons, g.Core)
		table.insert(gashes, g)
	end
	local LIFE = 0.5
	run(ribbons, function(t)
		if t >= LIFE then
			return false
		end
		local cf = cam.CFrame
		local p = position + (cf.Position - position).Unit * 1.8 * size
		local d = cf.RightVector * math.cos(base) + cf.UpVector * math.sin(base)
		local n = cf.RightVector * -math.sin(base) + cf.UpVector * math.cos(base)
		for _, g in gashes do
			local tt = t - g.Delay
			if tt <= 0 then
				hideRibbon(g.Bleed)
				hideRibbon(g.Glow)
				hideRibbon(g.Core)
				continue
			end
			local open = outExpo(clamp01(tt / 0.06)) -- rips end to end
			local fadeK = clamp01((tt - 0.12) / (LIFE - 0.12))
			local a = p + n * g.Off - d * g.L / 2
			local b = a + d * g.L * open
			local w = 0.3 * size * (1 - fadeK * 0.6)
			setNeedle(g.Core, a, b, w, fadeK)
			setNeedle(g.Glow, a, b, w * 3.2, 0.3 + 0.7 * fadeK)
			setNeedle(g.Bleed, a, b, w * 6, 0.55 + 0.45 * fadeK)
		end
		return true
	end)
end

function SlashFX.HitFlash(position, color, size, victim, claw)
	local cam = workspace.CurrentCamera
	if not (cam and position) then
		return
	end
	color = color or DEFAULT_GLOW
	size = size or 1
	flashBody(victim)
	if claw then
		clawRake(position, color, size)
		sparks(position, 1.4 * size, color, 10)
	end

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

-- The death ray's colours, inside out. Change these to recolour the whole
-- effect (charge-up, beam, lightning, impact).
local BEAM = {
	Core = WHITE,
	Inner = Color3.fromRGB(90, 225, 255), -- electric cyan
	Glow = Color3.fromRGB(255, 40, 200), -- magenta
	Halo = Color3.fromRGB(150, 30, 255), -- purple
	Deep = Color3.fromRGB(70, 0, 150), -- violet haze
	Coil = Color3.fromRGB(255, 110, 235),
	Bolt = Color3.fromRGB(150, 240, 255),
	Spark = Color3.fromRGB(255, 190, 90),
	Light = Color3.fromRGB(210, 60, 255),
}
local LASER_RED = BEAM.Glow

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

local BOLT_N = 20
local PULSES = 5
local PULSE_SPEED = 240 -- studs/s the energy slugs race down the beam
local SPARKS = 28
local CORONA = 10 -- jagged spikes blasting out of the impact

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
		Inner = takeRibbon(2, BEAM.Inner, 5),
		Glow = takeRibbon(2, BEAM.Glow, 4),
		Halo = takeRibbon(2, BEAM.Halo, 2.5),
		-- two faint wide layers so the outer glow fades out instead of ending in a hard edge
		Auras = { takeRibbon(2, BEAM.Deep, 1.5), takeRibbon(2, BEAM.Deep, 1.2) },
		Coils = { takeRibbon(COIL_N, BEAM.Coil, 6), takeRibbon(COIL_N, BEAM.Inner, 6) },
		Muzzle = takeRibbon(24, WHITE, 6),
		Muzzle2 = takeRibbon(24, BEAM.Inner, 5),
		ImpactRings = { takeRibbon(24, WHITE, 7), takeRibbon(24, BEAM.Inner, 6), takeRibbon(24, BEAM.Glow, 5) },
		Corona = {},
		ImpactFlare = {},
		Bolts = {},
		Pulses = {},
		Flare = {},
		Sparks = {},
		COIL_N = COIL_N,
		Start = os.clock(),
		LastUpdate = os.clock(),
		Ending = nil,
	}
	b.Ribbons = { b.Core, b.Inner, b.Glow, b.Halo, b.Auras[1], b.Auras[2], b.Coils[1], b.Coils[2], b.Muzzle, b.Muzzle2, b.ImpactRings[1], b.ImpactRings[2], b.ImpactRings[3] }
	for i = 1, 3 do
		local r = takeRibbon(BOLT_N, i == 1 and WHITE or BEAM.Bolt, 7)
		table.insert(b.Ribbons, r)
		b.Bolts[i] = { R = r, Next = 0, Offs = table.create(BOLT_N) }
	end
	for i = 1, PULSES do
		local r = takeRibbon(5, BEAM.Bolt, 6)
		table.insert(b.Ribbons, r)
		b.Pulses[i] = { R = r, Phase = (i - 1) / PULSES }
	end
	for i = 1, 4 do
		local r = takeRibbon(5, i <= 2 and WHITE or BEAM.Inner, i <= 2 and 8 or 5)
		table.insert(b.Ribbons, r)
		b.Flare[i] = { R = r, A = (i - 1) * math.pi / 4 + (i <= 2 and 0 or math.pi / 8), L = i <= 2 and 9 or 5, W = i <= 2 and 0.5 or 0.3 }
	end
	for i = 1, SPARKS do
		local r = takeRibbon(5, i % 3 == 0 and WHITE or BEAM.Spark, 6)
		table.insert(b.Ribbons, r)
		b.Sparks[i] = { R = r, T = -math.random() * 0.35 }
	end
	for i = 1, CORONA do
		local r = takeRibbon(5, i % 2 == 0 and WHITE or (i % 3 == 0 and BEAM.Glow or BEAM.Inner), 8)
		table.insert(b.Ribbons, r)
		b.Corona[i] = { R = r, Next = 0 }
	end
	for i = 1, 4 do
		local r = takeRibbon(5, i <= 2 and WHITE or BEAM.Glow, i <= 2 and 10 or 6)
		table.insert(b.Ribbons, r)
		b.ImpactFlare[i] = { R = r, A = (i - 1) * math.pi / 4 + 0.4, L = i <= 2 and 16 or 9, W = i <= 2 and 0.7 or 0.4 }
	end
	local holder = Instance.new("Part")
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.Transparency = true, false, false, false, 1
	holder.Size = Vector3.one * 0.2
	holder.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = BEAM.Light
	light.Brightness = 7
	light.Range = 40
	light.Parent = holder
	b.Holder, b.Light = holder, light
	-- white-hot balls at the chest and the impact, each in a red heat shell
	b.MuzzleOrb = glowBall(WHITE, Enum.Material.Neon)
	b.MuzzleShell = glowBall(BEAM.Glow, Enum.Material.ForceField)
	b.ImpactOrb = glowBall(WHITE, Enum.Material.Neon)
	b.ImpactShell = glowBall(BEAM.Inner, Enum.Material.ForceField)
	b.ImpactHaze = glowBall(BEAM.Glow, Enum.Material.ForceField)
	local impactLight = Instance.new("PointLight")
	impactLight.Color = BEAM.Light
	impactLight.Brightness = 12
	impactLight.Range = 34
	impactLight.Parent = b.ImpactOrb
	b.ImpactLight = impactLight
	b.Parts = { holder, b.MuzzleOrb, b.MuzzleShell, b.ImpactOrb, b.ImpactShell, b.ImpactHaze }
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
		starFlare(from, BEAM.Inner, 2.2, 0.6)
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
			setRibbon(b.Core, pts, { 0.6 * wp, 0.5 * wp }, 0)
			setRibbon(b.Inner, pts, { 1.8 * wp, 1.4 * wp }, 0.2)
			setRibbon(b.Glow, pts, { 4.2 * wp, 3.4 * wp }, 0.45)
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
			-- impact: a blinding core in a cyan/magenta fireball, shock rings
			-- slamming outward, a jagged corona, a huge flare and a spark spray
			-- (none of it if the beam ends in thin air)
			local open = openEnded(len)
			local hitAt = to2 - dir * 0.4
			for ri, ring in b.ImpactRings do
				local q = (t / 0.2 + ri / #b.ImpactRings) % 1
				if open then
					hideRibbon(ring)
				else
					setRing(ring, to2 - dir * 0.3, dir, 1 + 8 * outQuad(q), 0.5 * (1 - q) * w, q * 0.9)
				end
			end
			local throb = 1 + 0.25 * math.sin(t * 55) + (math.random() - 0.5) * 0.3
			local imp = open and 0 or 3 * throb * w
			b.ImpactOrb.Size = Vector3.one * math.max(0.05, imp)
			b.ImpactOrb.Position = hitAt
			b.ImpactShell.Size = Vector3.one * math.max(0.05, imp * 2)
			b.ImpactShell.Position = hitAt
			b.ImpactHaze.Size = Vector3.one * math.max(0.05, imp * 3.4)
			b.ImpactHaze.Position = hitAt
			for _, part in { b.ImpactOrb, b.ImpactShell, b.ImpactHaze } do
				part.Transparency = open and 1 or 0
			end
			b.ImpactLight.Enabled = not open
			b.ImpactLight.Brightness = 12 * fade * throb
			if cam then
				local cf = cam.CFrame
				local p = hitAt + (cf.Position - hitAt).Unit * 1.2
				for i, sp in b.ImpactFlare do
					if open then
						hideRibbon(sp.R)
					else
						local a = sp.A + t * (i <= 2 and -0.6 or 0.9)
						local d = cf.RightVector * math.cos(a) + cf.UpVector * math.sin(a)
						local l = sp.L * (0.8 + math.random() * 0.4) * w / 2
						setNeedle(sp.R, p - d * l, p + d * l, sp.W * w, 0)
					end
				end
				-- corona: spikes stabbing out of the hit, re-drawn many times a second
				for _, sp in b.Corona do
					if open then
						hideRibbon(sp.R)
					else
						if now >= sp.Next then
							sp.Next = now + 0.03 + math.random() * 0.05
							sp.A = math.random() * math.pi * 2
							sp.L = 2.5 + math.random() * 5
						end
						local d = cf.RightVector * math.cos(sp.A) + cf.UpVector * math.sin(sp.A)
						local r0 = 1.2 * w
						setNeedle(sp.R, p + d * r0, p + d * (r0 + sp.L * w), 0.45 * w, 0.05)
					end
				end
			end
			for _, sp in b.Sparks do
				sp.T += 1 / 60
				local q = sp.T / 0.35
				if q >= 1 and not b.Ending and not open then
					sp.T = 0
					sp.D = (-dir + Vector3.new(math.random() - 0.5, math.random() * 0.9, math.random() - 0.5) * 2.2).Unit
					sp.Speed = 24 + math.random() * 36
					sp.Origin = to2
					q = 0
				end
				if q > 0 and q < 1 and sp.D then
					local p0 = sp.Origin + sp.D * sp.Speed * 0.35 * q + Vector3.new(0, -8 * q * q, 0)
					setNeedle(sp.R, p0, p0 + sp.D * 1.8, 0.14, q)
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
				local dFrom = (cam.CFrame.Position - from2).Magnitude
				local dTo = open and math.huge or (cam.CFrame.Position - to2).Magnitude
				local rumble = math.max(0.12 * (1 - dFrom / 45), 0.28 * (1 - dTo / 60))
				if rumble > 0 then
					_G.WolverineShake(rumble * fade)
				end
			end
			return true
		end)
	end
	b.TargetFrom, b.TargetTo = from, to
	b.LastUpdate = os.clock()
	b.Ending = nil
	for _, p in burns or {} do
		starFlare(p, BEAM.Spark, 1.8, 0.5)
	end
	if hit and os.clock() - (b.LastHitFlash or 0) > 0.3 then
		b.LastHitFlash = os.clock()
		SlashFX.HitFlash(to, BEAM.Glow, 2.2)
	end
	local dir = (to - from)
	if dir.Magnitude > 0.1 and not openEnded(dir.Magnitude) and os.clock() - (b.LastScorch or 0) > 0.25 then
		b.LastScorch = os.clock()
		dir = dir.Unit
		local scorch = Instance.new("Part")
		scorch.Shape = Enum.PartType.Cylinder
		scorch.Anchored, scorch.CanCollide, scorch.CanQuery, scorch.CanTouch, scorch.CastShadow = true, false, false, false, false
		scorch.Material = Enum.Material.Neon
		scorch.Color = BEAM.Inner
		scorch.Size = Vector3.new(0.06, 4.5, 4.5)
		scorch.CFrame = CFrame.lookAt(to - dir * 0.05, to - dir) * CFrame.Angles(0, math.rad(90), 0)
		scorch.Parent = workspace
		TweenService:Create(scorch, TweenInfo.new(2.6), { Color = Color3.fromRGB(30, 20, 18), Transparency = 1, Size = Vector3.new(0.06, 2.8, 2.8) }):Play()
		task.delay(2.7, function()
			scorch:Destroy()
		end)
	end
end

function SlashFX.BeamEnd(char)
	local b = beams[char]
	if b and not b.Ending then
		b.Ending = os.clock()
		starFlare(b.To, BEAM.Inner, 2.2, 0.55)
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

-- The Inhibitor Blast's colours: molten gold with electric-blue arcs.
local PULSE = {
	Core = WHITE,
	Hot = Color3.fromRGB(255, 240, 170),
	Gold = Color3.fromRGB(255, 200, 60),
	Ember = Color3.fromRGB(255, 120, 20),
	Arc = Color3.fromRGB(90, 190, 255),
}
local GOLD = PULSE.Gold
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

-- a flat polygon on the floor (n-1 sides), spun by `rot`: the hexagon sigils
local function setPoly(r, center, radius, rot, width, transparency)
	local n = r.N
	local pts, ws = table.create(n), table.create(n)
	for i = 1, n do
		local a = rot + (i - 1) / (n - 1) * math.pi * 2
		pts[i] = center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius
		ws[i] = width
	end
	setRibbon(r, pts, ws, transparency)
end

local function ball(color, material)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = material
	p.Color = color
	p.Size = Vector3.one * 0.5
	p.Parent = workspace
	return p
end

-- Charge: a crackling gold sphere with a white-hot core, energy sucked up out
-- of the floor into it, and two hexagon sigils spinning tighter on the ground.
function SlashFX.PulseCharge(char, duration)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	duration = duration or 2
	local state = { Cancelled = false }
	pulseState[char] = state
	local sphere = ball(GOLD, Enum.Material.ForceField)
	local core = ball(PULSE.Hot, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Parent = core
	local ribbons, bolts, streaks = {}, {}, {}
	for i = 1, 10 do
		local r = takeRibbon(8, i % 3 == 0 and PULSE.Arc or (i % 2 == 0 and WHITE or GOLD), 7)
		table.insert(ribbons, r)
		bolts[i] = r
	end
	for i = 1, 14 do
		local r = takeRibbon(5, i % 3 == 0 and WHITE or PULSE.Hot, 7)
		table.insert(ribbons, r)
		streaks[i] = { R = r, A = math.random() * math.pi * 2, T = math.random() }
	end
	local ring = takeRibbon(32, GOLD, 6)
	local ring2 = takeRibbon(32, WHITE, 6)
	local hex = takeRibbon(7, PULSE.Arc, 7)
	local hex2 = takeRibbon(7, GOLD, 7)
	for _, r in { ring, ring2, hex, hex2 } do
		table.insert(ribbons, r)
	end
	state.Sphere = sphere
	run(ribbons, function(t)
		local k = math.min(1, t / duration)
		if state.Cancelled or t > duration + 0.4 or not root.Parent then
			sphere:Destroy()
			core:Destroy()
			return false
		end
		local s = root.Size.Y / 2
		local c = root.Position
		local rad = (3 + 6 * k * k) * s
		local flicker = 0.92 + math.random() * 0.16
		sphere.Position = c
		sphere.Size = Vector3.one * rad * flicker
		core.Position = c
		core.Size = Vector3.one * (0.6 + 2.6 * k * k) * s * flicker
		core.Color = GOLD:Lerp(WHITE, k)
		light.Range = 10 + 30 * k
		light.Brightness = 2 + 10 * k
		-- lightning crawling over the sphere, more of it as the charge builds
		for _, b in bolts do
			if math.random() < 0.3 + 0.6 * k then
				local a1 = math.random() * math.pi * 2
				local a2 = a1 + (math.random() - 0.5) * 2.4
				local e1 = (math.random() - 0.5) * 1.6
				local p1 = c + Vector3.new(math.cos(a1) * math.cos(e1), math.sin(e1), math.sin(a1) * math.cos(e1)) * rad * 0.5
				local p2 = c + Vector3.new(math.cos(a2), (math.random() - 0.5), math.sin(a2)) * rad * 0.5
				setBolt(b, p1, p2, 1 * s, (0.12 + 0.16 * k) * s, 0)
			else
				hideRibbon(b)
			end
		end
		-- energy pulled up out of the floor into the core
		local floor = c - Vector3.new(0, 2.8 * s, 0)
		for _, st in streaks do
			st.T += (1 / 60) * (1.2 + 2 * k)
			local q = st.T % 1
			local from = floor + Vector3.new(math.cos(st.A), 0, math.sin(st.A)) * (6 - 2 * k) * s
			local p = from:Lerp(c, q * q)
			local d = (c - from).Unit
			setNeedle(st.R, p, p + d * (1.2 + 1.5 * k) * s, (0.1 + 0.12 * k) * s, q < 0.1 and 1 - q * 10 or q)
		end
		-- spinning ground rings and hexagon sigils tightening in
		setRing(ring, floor, Vector3.new(0, 1, 0), (7.5 - 3 * k) * s, 0.3 * s, 0.15)
		setRing(ring2, floor + Vector3.new(0, 0.05, 0), Vector3.new(0, 1, 0), (5.5 - 2.5 * k + math.sin(t * 20) * 0.2) * s, 0.14 * s, 0.1)
		setPoly(hex, floor + Vector3.new(0, 0.08, 0), (6.5 - 2.5 * k) * s, t * (1.5 + 4 * k), 0.2 * s, 0.1)
		setPoly(hex2, floor + Vector3.new(0, 0.1, 0), (4.2 - 1.5 * k) * s, -t * (2 + 5 * k), 0.16 * s, 0.15)
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

-- The blast: a blinding white flash inside a gold dome and an electric-blue
-- second dome, a pillar of light punching up, shock rings and a hexagon sigil
-- blasting across the floor, forked lightning ripping out to the edge, a
-- spray of embers, and electric arcs crackling on the ground afterwards.
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
	local dome = ball(GOLD, Enum.Material.ForceField)
	dome.Size = Vector3.one * 4
	dome.Position = position
	local dome2 = ball(PULSE.Arc, Enum.Material.ForceField)
	dome2.Size = Vector3.one * 2
	dome2.Position = position
	local core = ball(WHITE, Enum.Material.Neon)
	core.Size = Vector3.one * 4
	core.Position = position
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 60
	light.Brightness = 14
	light.Parent = core
	TweenService:Create(dome, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { Size = Vector3.one * radius * 2.2, Transparency = 1 }):Play()
	TweenService:Create(dome2, TweenInfo.new(0.7, Enum.EasingStyle.Quint), { Size = Vector3.one * radius * 1.7, Transparency = 1 }):Play()
	TweenService:Create(core, TweenInfo.new(0.28, Enum.EasingStyle.Quad), { Size = Vector3.one * 14, Transparency = 1 }):Play()
	TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	-- a flat shockwave of light racing along the floor
	local floor = position - Vector3.new(0, 2.6, 0)
	local wave = Instance.new("Part")
	wave.Shape = Enum.PartType.Cylinder
	wave.Anchored, wave.CanCollide, wave.CanQuery, wave.CanTouch, wave.CastShadow = true, false, false, false, false
	wave.Material = Enum.Material.Neon
	wave.Color = PULSE.Hot
	wave.Transparency = 0.35
	wave.Size = Vector3.new(0.15, 4, 4)
	wave.CFrame = CFrame.new(floor + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	wave.Parent = workspace
	TweenService:Create(wave, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Size = Vector3.new(0.05, radius * 2.3, radius * 2.3), Transparency = 1, Color = GOLD }):Play()
	task.delay(0.9, function()
		dome:Destroy()
		dome2:Destroy()
		core:Destroy()
		wave:Destroy()
	end)
	starFlare(position, GOLD, 3, 0.6)
	local ribbons, rings, bolts, forks, embers, arcs = {}, {}, {}, {}, {}, {}
	for i = 1, 4 do
		local r = takeRibbon(40, i == 1 and WHITE or (i == 3 and PULSE.Arc or GOLD), 7)
		table.insert(ribbons, r)
		rings[i] = { R = r, Delay = (i - 1) * 0.06 }
	end
	local sigil = takeRibbon(7, PULSE.Arc, 8)
	local sigil2 = takeRibbon(7, WHITE, 8)
	table.insert(ribbons, sigil)
	table.insert(ribbons, sigil2)
	-- the pillar: a column of light slamming up out of the blast
	local pillar = { takeRibbon(2, WHITE, 10), takeRibbon(2, GOLD, 6), takeRibbon(2, PULSE.Arc, 3) }
	for _, r in pillar do
		table.insert(ribbons, r)
	end
	for i = 1, 16 do
		local r = takeRibbon(10, i % 3 == 0 and PULSE.Arc or (i % 2 == 0 and WHITE or GOLD), 8)
		table.insert(ribbons, r)
		local a = i / 16 * math.pi * 2 + math.random() * 0.3
		bolts[i] = { R = r, Dir = Vector3.new(math.cos(a), (math.random() - 0.3) * 0.5, math.sin(a)).Unit }
		if i % 2 == 0 then
			local f = takeRibbon(6, PULSE.Arc, 7)
			table.insert(ribbons, f)
			forks[#forks + 1] = { R = f, Bolt = bolts[i], Turn = (math.random() - 0.5) * 1.4 }
		end
	end
	for i = 1, 24 do
		local r = takeRibbon(5, i % 3 == 0 and WHITE or PULSE.Ember, 6)
		table.insert(ribbons, r)
		local a = math.random() * math.pi * 2
		embers[i] = { R = r, D = Vector3.new(math.cos(a), 0.4 + math.random() * 0.9, math.sin(a)).Unit, Speed = 30 + math.random() * 40 }
	end
	for i = 1, 6 do
		local r = takeRibbon(8, i % 2 == 0 and PULSE.Arc or WHITE, 7)
		table.insert(ribbons, r)
		arcs[i] = r
	end
	local LIFE = 0.95
	run(ribbons, function(t)
		local k = t / LIFE
		if k >= 1 then
			return false
		end
		for _, rg in rings do
			local q = math.clamp((t - rg.Delay) / (0.6 - rg.Delay), 0, 1)
			if q > 0 and q < 1 then
				setRing(rg.R, floor, Vector3.new(0, 1, 0), 2 + radius * 1.15 * outQuad(q), 0.9 * (1 - q), q)
			else
				hideRibbon(rg.R)
			end
		end
		local qs = math.min(1, t / 0.55)
		setPoly(sigil, floor + Vector3.new(0, 0.12, 0), 3 + radius * 0.9 * outCubic(qs), t * 3, 0.5 * (1 - qs), qs)
		setPoly(sigil2, floor + Vector3.new(0, 0.14, 0), 2 + radius * 0.6 * outCubic(qs), -t * 4, 0.3 * (1 - qs), qs)
		-- pillar punches up fast, then thins and fades
		local qp = math.min(1, t / 0.5)
		local top = position + Vector3.new(0, 6 + 60 * outExpo(math.min(1, t / 0.12)), 0)
		local pw = (1 - qp)
		local pts = { floor, top }
		setRibbon(pillar[1], pts, { 3 * pw, 0.6 * pw }, qp)
		setRibbon(pillar[2], pts, { 7 * pw, 1.5 * pw }, 0.3 + 0.7 * qp)
		setRibbon(pillar[3], pts, { 12 * pw, 3 * pw }, 0.6 + 0.4 * qp)
		-- forked lightning ripping out to the edge of the blast
		local kb = math.min(1, t / 0.6)
		for _, b in bolts do
			local len = radius * (0.3 + 0.9 * outQuad(math.min(1, kb * 2)))
			b.Tip = position + b.Dir * len
			setBolt(b.R, position, b.Tip, 2, 0.45 * (1 - kb), kb)
		end
		for _, f in forks do
			local mid = position:Lerp(f.Bolt.Tip, 0.55)
			local d = CFrame.Angles(0, f.Turn, 0):VectorToWorldSpace(f.Bolt.Dir)
			setBolt(f.R, mid, mid + d * radius * 0.45 * outQuad(math.min(1, kb * 2)), 1.2, 0.28 * (1 - kb), kb)
		end
		-- embers flung out and falling
		for _, e in embers do
			local q = math.min(1, t / 0.8)
			local p0 = position + e.D * e.Speed * 0.5 * q + Vector3.new(0, -14 * q * q, 0)
			setNeedle(e.R, p0, p0 + e.D * 1.6, 0.14, q)
		end
		-- leftover arcs crackling across the floor
		for _, r in arcs do
			if t > 0.2 and math.random() < 0.6 then
				local a = math.random() * math.pi * 2
				local d0 = math.random() * radius * 0.8
				local p1 = floor + Vector3.new(math.cos(a) * d0, 0.2, math.sin(a) * d0)
				local a2 = a + (math.random() - 0.5) * 1.2
				local p2 = p1 + Vector3.new(math.cos(a2), 0, math.sin(a2)) * (3 + math.random() * 5)
				setBolt(r, p1, p2, 1.2, 0.25 * (1 - k), k)
			else
				hideRibbon(r)
			end
		end
		return true
	end)
	if _G.WolverineShake then
		local cam = workspace.CurrentCamera
		local d = cam and (cam.CFrame.Position - position).Magnitude or 999
		if d < radius * 3 then
			_G.WolverineShake(1.6 * (1 - d / (radius * 3)))
		end
	end
	SlashFX.HitFlash(position, GOLD, 2.6)
end

---------------------------------------------------------------------------
-- Sentinel Ground Slam: the floor cracks open, slabs heave up, rocks fly,
-- then it all knits back together (like the walls, after Config.WallRegen)
---------------------------------------------------------------------------

local slamFolder = nil
local function slamPart(props)
	if not (slamFolder and slamFolder.Parent) then
		slamFolder = Instance.new("Folder")
		slamFolder.Name = "SlamFX"
		slamFolder.Parent = workspace
	end
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = slamFolder
	return p
end

function SlashFX.GroundSlam(position, radius)
	if not position then
		return
	end
	radius = radius or 30
	-- what the floor is made of, so the broken slabs match it
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	if slamFolder then
		table.insert(ignore, slamFolder)
	end
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -8, 0), params)
	local floorY = hit and hit.Position.Y or position.Y
	local mat = hit and hit.Instance.Material or Enum.Material.Concrete
	local col = hit and hit.Instance.Color or Color3.fromRGB(70, 70, 74)
	local c = Vector3.new(position.X, floorY, position.Z)
	local healAt = Config.WallRegen or 10
	local pieces = {}

	-- flash, and shock rings racing across the floor
	starFlare(c + Vector3.new(0, 2, 0), Color3.fromRGB(255, 200, 120), 3, 0.5)
	local ribbons, rings = {}, {}
	for i = 1, 3 do
		local r = takeRibbon(40, i == 1 and WHITE or Color3.fromRGB(255, 190, 110), 5)
		table.insert(ribbons, r)
		rings[i] = { R = r, Delay = (i - 1) * 0.07 }
	end
	run(ribbons, function(t)
		if t > 0.8 then
			return false
		end
		for _, rg in rings do
			local q = math.clamp((t - rg.Delay) / 0.55, 0, 1)
			if q > 0 and q < 1 then
				setRing(rg.R, c + Vector3.new(0, 0.15, 0), Vector3.new(0, 1, 0), 2 + radius * outQuad(q), 0.8 * (1 - q), q)
			else
				hideRibbon(rg.R)
			end
		end
		return true
	end)

	-- the crater and its white-hot heart
	local crater = slamPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 10, 10), Material = Enum.Material.Slate, Color = col:Lerp(Color3.new(0, 0, 0), 0.65) })
	crater.CFrame = CFrame.new(c + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local glow = slamPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 6, 6), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 150, 60) })
	glow.CFrame = CFrame.new(c + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90))
	TweenService:Create(glow, TweenInfo.new(1.6), { Transparency = 1, Size = Vector3.new(0.1, 3, 3) }):Play()
	table.insert(pieces, crater)

	-- jagged cracks running out from the crater, glowing then cooling
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2 + (math.random() - 0.5) * 0.5
		local p0 = c + Vector3.new(math.cos(a), 0, math.sin(a)) * 3.5
		local reach = radius * (0.35 + math.random() * 0.25)
		local len = 0
		while len < reach do
			a += (math.random() - 0.5) * 0.9
			local seg = 1.8 + math.random() * 2.2
			local p1 = p0 + Vector3.new(math.cos(a), 0, math.sin(a)) * seg
			local width = 0.45 * (1 - len / reach) + 0.08
			local mid = (p0 + p1) / 2 + Vector3.new(0, 0.05, 0)
			local cf = CFrame.lookAt(mid, mid + (p1 - p0))
			local crack = slamPart({ Size = Vector3.new(width, 0.06, seg + 0.1), Material = Enum.Material.Slate, Color = Color3.fromRGB(18, 16, 15), CFrame = cf })
			local lava = slamPart({ Size = Vector3.new(width * 0.45, 0.07, seg + 0.1), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 120, 40), CFrame = cf })
			TweenService:Create(lava, TweenInfo.new(1.2 + math.random() * 0.8), { Transparency = 1, Color = Color3.fromRGB(120, 20, 0) }):Play()
			table.insert(pieces, crack)
			p0 = p1
			len += seg
		end
	end

	-- slabs of floor heaving up round the crater
	for k = 1, 12 do
		local a = k / 12 * math.pi * 2 + math.random() * 0.4
		local d = 4.5 + math.random() * 4
		local size = Vector3.new(2.5 + math.random() * 2.5, 0.7, 2 + math.random() * 2)
		local base = CFrame.new(c + Vector3.new(math.cos(a) * d, -0.25, math.sin(a) * d)) * CFrame.Angles(0, -a, 0)
		local slab = slamPart({ Size = size, Material = mat, Color = col:Lerp(Color3.new(0, 0, 0), 0.15), CFrame = base, CanCollide = false })
		local tilt = math.rad(15 + math.random() * 25)
		local up = base * CFrame.new(0, 0.5 + math.random() * 0.9, 0) * CFrame.Angles(0, 0, -tilt)
		TweenService:Create(slab, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = up }):Play()
		slab:SetAttribute("Home", true)
		table.insert(pieces, slab)
		task.delay(healAt, function()
			if slab.Parent then
				TweenService:Create(slab, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { CFrame = base, Transparency = 1 }):Play()
			end
		end)
	end

	-- rocks flung up and out
	local rocks = {}
	for k = 1, 16 do
		local s = 0.4 + math.random() * 0.8
		local rock = slamPart({ Size = Vector3.new(s, s * 0.8, s * 1.1), Material = mat, Color = col })
		local a = math.random() * math.pi * 2
		rocks[k] = { P = rock, V = Vector3.new(math.cos(a) * (8 + math.random() * 16), 18 + math.random() * 22, math.sin(a) * (8 + math.random() * 16)), Spin = Vector3.new(math.random() * 8, math.random() * 8, math.random() * 8) }
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > 1.6 then
			conn:Disconnect()
			for _, r in rocks do
				r.P:Destroy()
			end
			return
		end
		for _, r in rocks do
			local p = c + r.V * t + Vector3.new(0, -60 * t * t / 2, 0)
			if p.Y < c.Y then
				p = Vector3.new(p.X, c.Y + 0.2, p.Z)
			end
			r.P.CFrame = CFrame.new(p) * CFrame.Angles(r.Spin.X * t, r.Spin.Y * t, r.Spin.Z * t)
			r.P.Transparency = math.clamp((t - 1.1) / 0.5, 0, 1)
		end
	end)

	-- the floor heals: cracks and crater fade, the slabs sink back (above)
	task.delay(healAt, function()
		for _, p in pieces do
			if p.Parent and not p:GetAttribute("Home") then
				TweenService:Create(p, TweenInfo.new(0.8), { Transparency = 1 }):Play()
			end
		end
		task.wait(0.9)
		for _, p in pieces do
			p:Destroy()
		end
		glow:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Impale: the claws punch out through their back
---------------------------------------------------------------------------

-- Three long blades of light burst out along `dir` from the victim's back
-- (six for a Sentinel: both claws), a shock ring around the wound, a white
-- flare, and a spray of glowing shards.
function SlashFX.ImpaleBurst(position, dir, color, heavy)
	if not (position and dir) then
		return
	end
	color = color or DEFAULT_GLOW
	local cam = workspace.CurrentCamera
	starFlare(position + dir * 1.2, color, heavy and 2.4 or 1.8, 0.45)
	local side = dir:Cross(Vector3.new(0, 0, 1))
	side = side.Magnitude > 0.01 and side.Unit or Vector3.new(1, 0, 0)
	local ribbons, blades, shards = {}, {}, {}
	local sets = heavy and { -1.1, 1.1 } or { 0 }
	for _, off in sets do
		for k = -1, 1 do
			local b = {
				Glow = takeRibbon(5, color, 3),
				Core = takeRibbon(5, WHITE, 8),
				From = position + side * (off + k * 0.32),
				L = (5.5 - math.abs(k) * 1.2) * (heavy and 1.3 or 1),
			}
			table.insert(ribbons, b.Glow)
			table.insert(ribbons, b.Core)
			table.insert(blades, b)
		end
	end
	local ring = takeRibbon(24, color, 5)
	local ring2 = takeRibbon(24, WHITE, 6)
	table.insert(ribbons, ring)
	table.insert(ribbons, ring2)
	for i = 1, 14 do
		local r = takeRibbon(5, i % 3 == 0 and WHITE or color, 5)
		table.insert(ribbons, r)
		local d = (dir + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.3).Unit
		shards[i] = { R = r, D = d, Speed = 18 + math.random() * 22 }
	end
	local LIFE = 0.45
	run(ribbons, function(t)
		local k = t / LIFE
		if k >= 1 or not cam then
			return false
		end
		local grow = outExpo(clamp01(t / 0.06))
		for _, b in blades do
			local tip = b.From + dir * b.L * grow
			local w = 0.32 * (1 - k)
			setNeedle(b.Core, b.From - dir * 0.3, tip, w, k)
			setNeedle(b.Glow, b.From - dir * 0.3, tip + dir * 0.4, w * 3.2, 0.3 + 0.7 * k)
		end
		setRing(ring, position + dir * 0.4, dir, 0.8 + 3.2 * outQuad(k), 0.3 * (1 - k), k)
		setRing(ring2, position + dir * 0.6, dir, 0.5 + 2 * outQuad(k), 0.18 * (1 - k), k)
		for _, s in shards do
			local p0 = position + s.D * s.Speed * 0.4 * outQuad(k) + Vector3.new(0, -5 * k * k, 0)
			setNeedle(s.R, p0, p0 + s.D * 1.2, 0.1 * (1 - k), k)
		end
		return true
	end)
end

-- The kick that boots them off his claws: a flat shock ring off the sole of
-- his boot, a burst of streaks and a white flare.
function SlashFX.KickImpact(position, dir)
	if not (position and dir) then
		return
	end
	starFlare(position, WHITE, 1.6, 0.35)
	local ribbons, streaks = {}, {}
	local ring = takeRibbon(24, WHITE, 6)
	local ring2 = takeRibbon(24, Color3.fromRGB(255, 200, 150), 4)
	table.insert(ribbons, ring)
	table.insert(ribbons, ring2)
	for i = 1, 10 do
		local r = takeRibbon(5, i % 2 == 0 and WHITE or Color3.fromRGB(255, 210, 170), 5)
		table.insert(ribbons, r)
		local d = (dir + Vector3.new(math.random() - 0.5, (math.random() - 0.3) * 0.8, math.random() - 0.5) * 0.7).Unit
		streaks[i] = { R = r, D = d, L = 2 + math.random() * 2.5 }
	end
	local LIFE = 0.35
	run(ribbons, function(t)
		local k = t / LIFE
		if k >= 1 then
			return false
		end
		setRing(ring, position, dir, 0.6 + 3.5 * outQuad(k), 0.35 * (1 - k), k)
		setRing(ring2, position + dir * 0.8, dir, 0.4 + 2.2 * outQuad(k), 0.22 * (1 - k), k)
		for _, s in streaks do
			local p0 = position + s.D * (1 + 9 * outQuad(k))
			setNeedle(s.R, p0, p0 + s.D * s.L * (1 - k), 0.14 * (1 - k), k)
		end
		return true
	end)
end

---------------------------------------------------------------------------
-- Electricity: a Sentinel shorting out, and it shocking him through his claws
---------------------------------------------------------------------------

local ARC_BLUE = Color3.fromRGB(120, 220, 255)
local function visibleParts(char)
	local list = {}
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.9 and d.Name ~= "HumanoidRootPart" then
			table.insert(list, d)
		end
	end
	return list
end

-- Arcs crackling over a character (jumping between random parts of it) and
-- sparks spitting off it, for `duration` seconds.
function SlashFX.Electric(char, duration)
	if not (char and char.Parent) then
		return
	end
	duration = duration or 1.2
	local parts = visibleParts(char)
	if #parts < 2 then
		return
	end
	local ribbons, bolts = {}, {}
	for i = 1, 6 do
		local r = takeRibbon(8, i % 2 == 0 and WHITE or ARC_BLUE, 8)
		table.insert(ribbons, r)
		bolts[i] = { R = r, Next = 0 }
	end
	local nextSpark = 0
	run(ribbons, function(t)
		if t >= duration or not char.Parent then
			return false
		end
		local now = os.clock()
		for _, b in bolts do
			if now >= b.Next then
				b.Next = now + 0.04 + math.random() * 0.08
				b.A = parts[math.random(#parts)]
				b.B = parts[math.random(#parts)]
				b.Show = math.random() < 0.7 and b.A ~= b.B
			end
			if b.Show and b.A.Parent and b.B.Parent and (b.A.Position - b.B.Position).Magnitude > 0.2 then
				local fade = 1 - t / duration
				setBolt(b.R, b.A.Position, b.B.Position, 1.2, 0.16 * fade + 0.04, 0)
			else
				hideRibbon(b.R)
			end
		end
		if now >= nextSpark then
			nextSpark = now + 0.12
			local p = parts[math.random(#parts)]
			if p.Parent then
				sparks(p.Position, 1.2, ARC_BLUE, 5)
			end
		end
		return true
	end)
end

-- Arcs leaping from one character to another (the suit into his claws) and
-- crawling over the one being shocked.
function SlashFX.Electrocute(fromChar, toChar, duration)
	if not (fromChar and toChar and fromChar.Parent and toChar.Parent) then
		return
	end
	duration = duration or 0.3
	local src, dst = visibleParts(fromChar), visibleParts(toChar)
	local claws = toChar:FindFirstChild("Claws")
	if claws then
		local list = visibleParts(claws)
		if #list > 0 then
			dst = list
		end
	end
	if #src == 0 or #dst == 0 then
		return
	end
	local ribbons, bolts = {}, {}
	for i = 1, 4 do
		local r = takeRibbon(10, i % 2 == 0 and WHITE or ARC_BLUE, 9)
		table.insert(ribbons, r)
		bolts[i] = r
	end
	run(ribbons, function(t)
		if t >= duration or not (fromChar.Parent and toChar.Parent) then
			return false
		end
		for _, r in bolts do
			local a, b = src[math.random(#src)], dst[math.random(#dst)]
			if a.Parent and b.Parent and (a.Position - b.Position).Magnitude > 0.2 then
				setBolt(r, a.Position, b.Position, 1.6, 0.22, 0)
			end
		end
		return true
	end)
	SlashFX.Electric(toChar, duration + 0.2)
end

---------------------------------------------------------------------------
-- Pounce: a launch burst, claw trails and speed lines through the dive, an
-- X of claw gashes on the catch, and a heavy landing when he misses
---------------------------------------------------------------------------

local TRAIL_N = 14
function SlashFX.PounceTrail(char, color, duration)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	color = color or char:GetAttribute("ClawGlow") or DEFAULT_GLOW
	duration = duration or 1
	-- launch: a burst kicked back off the floor behind him
	local back = -Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	back = back.Magnitude > 0.01 and back.Unit or Vector3.new(0, 0, 1)
	SlashFX.KickImpact(root.Position - Vector3.new(0, 2.2, 0), (back + Vector3.new(0, 0.4, 0)).Unit)
	local hands = {}
	for _, name in { "RightHand", "LeftHand" } do
		local h = char:FindFirstChild(name)
		if h then
			table.insert(hands, { Part = h, Hist = {}, Glow = takeRibbon(TRAIL_N, color, 3), Core = takeRibbon(TRAIL_N, WHITE, 7) })
		end
	end
	local ribbons, lines = {}, {}
	for _, h in hands do
		table.insert(ribbons, h.Glow)
		table.insert(ribbons, h.Core)
	end
	for i = 1, 10 do
		local r = takeRibbon(5, i % 3 == 0 and color or WHITE, 3)
		table.insert(ribbons, r)
		lines[i] = { R = r, T = math.random() * 0.25 }
	end
	local pts, ws, wg = table.create(TRAIL_N), table.create(TRAIL_N), table.create(TRAIL_N)
	run(ribbons, function(t)
		if not root.Parent then
			return false
		end
		local k = t / (duration + 0.25) -- trails fade out just after he lands
		if k >= 1 then
			return false
		end
		local fade = t < duration and 1 or 1 - (t - duration) / 0.25
		for _, h in hands do
			local hist = h.Hist
			if t < duration then
				table.insert(hist, 1, h.Part.Position)
				if #hist > TRAIL_N then
					table.remove(hist)
				end
			end
			if #hist >= 2 then
				for i = 1, TRAIL_N do
					pts[i] = hist[math.min(i, #hist)]
					local u = (i - 1) / (TRAIL_N - 1)
					ws[i] = 0.28 * (1 - u) * fade
					wg[i] = ws[i] * 3.6
				end
				setRibbon(h.Core, pts, ws, 1 - fade)
				setRibbon(h.Glow, pts, wg, 0.35 + 0.65 * (1 - fade))
			end
		end
		-- speed lines streaming back off his body
		local vel = root.AssemblyLinearVelocity
		local dir = vel.Magnitude > 2 and vel.Unit or -back
		for _, l in lines do
			l.T += 1 / 60
			local q = (l.T % 0.25) / 0.25
			if not l.Off or q < l.Q0 then
				l.Off = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3.2
			end
			l.Q0 = q
			local p0 = root.Position + l.Off - dir * (1 + 5 * q)
			setNeedle(l.R, p0, p0 - dir * 3 * (1 - q), 0.08 * fade, t < duration and q or 1)
		end
		return true
	end)
end

-- The catch: two sets of claw gashes crossing in an X, a big flare and a ring
function SlashFX.PounceStrike(position, dir, color)
	if not position then
		return
	end
	color = color or DEFAULT_GLOW
	clawRake(position, color, 1.5)
	task.delay(0.05, function()
		clawRake(position, color, 1.5)
	end)
	starFlare(position, color, 2.4, 0.45)
	sparks(position, 2, color, 14)
	if dir then
		SlashFX.KickImpact(position, dir)
	end
end

-- Whiffed: he lands hard on all fours, the floor ringing out round him
function SlashFX.PounceLand(position)
	if not position then
		return
	end
	local ribbons = { takeRibbon(32, WHITE, 5), takeRibbon(32, Color3.fromRGB(220, 210, 190), 3) }
	local streaks = {}
	for i = 1, 12 do
		local r = takeRibbon(5, Color3.fromRGB(230, 220, 200), 3)
		table.insert(ribbons, r)
		local a = i / 12 * math.pi * 2 + math.random() * 0.3
		streaks[i] = { R = r, D = Vector3.new(math.cos(a), 0.15, math.sin(a)).Unit, L = 1.5 + math.random() * 2 }
	end
	local LIFE = 0.45
	run(ribbons, function(t)
		local k = t / LIFE
		if k >= 1 then
			return false
		end
		setRing(ribbons[1], position + Vector3.new(0, 0.2, 0), Vector3.new(0, 1, 0), 1 + 9 * outQuad(k), 0.5 * (1 - k), k)
		setRing(ribbons[2], position + Vector3.new(0, 0.25, 0), Vector3.new(0, 1, 0), 0.6 + 6 * outQuad(k), 0.3 * (1 - k), k)
		for _, s in streaks do
			local p0 = position + Vector3.new(0, 0.3, 0) + s.D * (1 + 8 * outQuad(k))
			setNeedle(s.R, p0, p0 + s.D * s.L * (1 - k), 0.12 * (1 - k), k)
		end
		return true
	end)
end

-- Rage roar: blood-red shock rings rolling out across the floor, a red star
-- bursting from his chest and embers ripped up around him.
function SlashFX.RageBurst(char)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local RED, HOT = Color3.fromRGB(255, 30, 20), Color3.fromRGB(255, 120, 80)
	local floor = root.Position - Vector3.new(0, 2.8, 0)
	starFlare(root.Position + Vector3.new(0, 1.2, 0), RED, 2.2, 0.5)
	local ribbons = { takeRibbon(36, RED, 6), takeRibbon(36, HOT, 4), takeRibbon(36, RED, 4) }
	local embers = {}
	for i = 1, 16 do
		local r = takeRibbon(5, i % 3 == 0 and HOT or RED, 3)
		table.insert(ribbons, r)
		local a = i / 16 * math.pi * 2 + math.random() * 0.3
		embers[i] = {
			R = r,
			D = Vector3.new(math.cos(a), 0.35 + math.random() * 0.9, math.sin(a)).Unit,
			L = 2 + math.random() * 2.5,
			V = 14 + math.random() * 10,
		}
	end
	local LIFE = 0.9
	run(ribbons, function(t)
		local k = t / LIFE
		if k >= 1 then
			return false
		end
		local up = Vector3.new(0, 1, 0)
		setRing(ribbons[1], floor + Vector3.new(0, 0.2, 0), up, 1.5 + 22 * outCubic(k), 0.9 * (1 - k), k)
		local k2 = clamp01((t - 0.12) / (LIFE - 0.12))
		setRing(ribbons[2], floor + Vector3.new(0, 0.3, 0), up, 1 + 14 * outCubic(k2), 0.5 * (1 - k2), k2)
		setRing(ribbons[3], root.Position, up, 2 + 9 * outQuad(math.min(1, k * 2)), 0.35 * (1 - math.min(1, k * 2)), math.min(1, k * 2))
		for _, e in embers do
			local dist = e.V * t - 6 * t * t
			local p0 = root.Position + e.D * (1 + dist)
			setNeedle(e.R, p0, p0 + e.D * e.L * (1 - k), 0.14 * (1 - k), k)
		end
		return true
	end)
end

return SlashFX
