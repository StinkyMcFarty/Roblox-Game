-- Crisp anime-style slash VFX, drawn on each client every frame so they stay smooth.
--   SlashFX.Arc(char, side, color)          three razor-thin claw crescents that sweep
--                                            head-first and retract into a fine tail, plus sparks
--   SlashFX.HitFlash(pos, color, size, char) X-shaped star flare, needle burst, white-hot
--                                            core and a white body flash on the victim
-- Everything is built from beams (tapered, camera-facing ribbons) on attachments in
-- Terrain, whose attachment positions are world-space. No image assets are needed.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

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

function SlashFX.Laser(from, to, burns, hitTarget)
	if not (from and to) then
		return
	end
	local core = takeRibbon(2, WHITE, 8)
	local glow = takeRibbon(2, LASER_RED, 4)
	local halo = takeRibbon(2, LASER_RED, 2)
	local LIFE = 0.42
	local pts = { from, to }
	run({ core, glow, halo }, function(t)
		local k = t / LIFE
		if k >= 1 then
			return false
		end
		local on = outExpo(math.min(1, t / 0.04))
		local fade = k < 0.35 and 1 or (1 - (k - 0.35) / 0.65)
		local shimmer = 1 + math.sin(t * 90) * 0.12
		local w = on * fade * shimmer
		setRibbon(core, pts, { 0.34 * w, 0.28 * w }, 0)
		setRibbon(glow, pts, { 1.1 * w, 0.9 * w }, 0.25 + 0.5 * (1 - fade))
		setRibbon(halo, pts, { 2.6 * w, 2.2 * w }, 0.7 + 0.3 * (1 - fade))
		return true
	end)
	-- muzzle, burn-through points, impact
	starFlare(from, LASER_RED, 0.7, 0.25)
	for _, b in burns or {} do
		starFlare(b, Color3.fromRGB(255, 150, 60), 0.8, 0.3)
	end
	if hitTarget then
		SlashFX.HitFlash(to, LASER_RED, 1.3)
	else
		starFlare(to, Color3.fromRGB(255, 150, 60), 1, 0.35)
	end
	local light = Instance.new("Part")
	light.Anchored, light.CanCollide, light.CanQuery, light.CanTouch, light.Transparency = true, false, false, false, 1
	light.Size = Vector3.one * 0.2
	light.Position = (from + to) / 2
	light.Parent = workspace
	local pl = Instance.new("PointLight")
	pl.Color = LASER_RED
	pl.Range = math.min(60, (to - from).Magnitude / 2 + 10)
	pl.Brightness = 4
	pl.Parent = light
	TweenService:Create(pl, TweenInfo.new(LIFE), { Brightness = 0 }):Play()
	task.delay(LIFE + 0.05, function()
		light:Destroy()
	end)
end

return SlashFX
