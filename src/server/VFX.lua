-- Crisp combat visuals, created on the server so everyone sees them.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(ReplicatedStorage.Shared.Util)

local Fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx")

local VFX = {}

-- Plays a keyframed clip (client/AnimClips) on a character for every player.
function VFX.Anim(char, clip, speed)
	if char then
		Fx:FireAllClients("Anim", { Char = char, Clip = clip, Speed = speed })
	end
end

function VFX.StopAnim(char, clip)
	if char then
		Fx:FireAllClients("AnimStop", { Char = char, Clip = clip })
	end
end

local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = workspace
	return p
end

-- Three curved claw crescents in front of the attacker.
-- `color` tints the outer glow (claw skin colour).
function VFX.ClawArc(root, side, color)
	color = color or Color3.fromRGB(255, 80, 60)
	local dir = side == "R" and 1 or -1
	local base = root.CFrame * CFrame.new(0, 0.8, -3.2)
	local segments = 7
	local arcRadius = 3.4
	local sweep = math.rad(110)
	for claw = -1, 1 do
		for i = 0, segments - 1 do
			local a0 = -sweep / 2 + sweep * (i / segments)
			local a1 = -sweep / 2 + sweep * ((i + 1) / segments)
			local am = (a0 + a1) / 2
			local segLen = arcRadius * (a1 - a0) * 1.08
			-- thinner at the ends of the arc, thick in the middle
			local thickness = 0.28 * (1 - math.abs(am) / (sweep / 2)) + 0.05
			local cf = base
				* CFrame.Angles(0, 0, math.rad(35 * dir))
				* CFrame.new(claw * 0.55, 0, 0)
				* CFrame.Angles(0, am * dir, 0)
				* CFrame.new(0, 0, -arcRadius)
				* CFrame.Angles(0, math.rad(90), 0)
			local core = fxPart({ Size = Vector3.new(segLen, thickness, thickness * 0.5), CFrame = cf, Color = Color3.new(1, 1, 1), Transparency = 0 })
			local glow = fxPart({ Size = Vector3.new(segLen, thickness * 2.8, thickness * 1.6), CFrame = cf, Color = color, Transparency = 0.55 })
			local delay = i * 0.012
			task.delay(delay, function()
				TweenService:Create(core, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Transparency = 1, Size = core.Size * Vector3.new(1.2, 0.2, 0.2) }):Play()
				TweenService:Create(glow, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Transparency = 1, Size = glow.Size * Vector3.new(1.3, 1.6, 1.6) }):Play()
			end)
			Debris:AddItem(core, 0.35)
			Debris:AddItem(glow, 0.35)
		end
	end
end

-- Fast bright flash + ring at a hit location.
function VFX.Impact(position, color, size)
	size = size or 1
	color = color or Color3.fromRGB(255, 60, 40)
	local ball = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6 * size, Position = position, Color = Color3.new(1, 1, 1), Transparency = 0 })
	TweenService:Create(ball, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Size = Vector3.one * 4.5 * size, Transparency = 1 }):Play()
	Debris:AddItem(ball, 0.2)
	local ring = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 1, 1) * size,
		CFrame = CFrame.new(position) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, 0),
		Color = color,
		Transparency = 0.1,
	})
	TweenService:Create(ring, TweenInfo.new(0.22, Enum.EasingStyle.Quad), { Size = Vector3.new(0.05, 7, 7) * size, Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.3)
	Util.Burst(position, Util.SparkProps, 18, 1)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14 * size
	light.Brightness = 4
	light.Parent = ball
end

-- Red claw marks slashed across a victim for a moment.
function VFX.WoundMarks(char)
	local torso = Util.Torso(char)
	if not torso then
		return
	end
	for i = -1, 1 do
		local mark = fxPart({
			Size = Vector3.new(0.12, torso.Size.Y * 1.3, 0.05),
			CFrame = torso.CFrame * CFrame.new(i * 0.35, 0, -torso.Size.Z / 2 - 0.08) * CFrame.Angles(0, 0, math.rad(30)),
			Color = Color3.fromRGB(200, 0, 0),
			Transparency = 0,
		})
		TweenService:Create(mark, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		Debris:AddItem(mark, 0.6)
	end
end

-- Dust/snow puff when a wall is shredded.
function VFX.Dust(position, color, amount)
	Util.Burst(position, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(color or Color3.fromRGB(200, 200, 205)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.8, 1.5),
		Speed = NumberRange.new(6, 14),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		RotSpeed = NumberRange.new(-60, 60),
	}, amount or 14, 2.5)
end

-- Flat shockwave ring on the ground (pounce landing, roar).
function VFX.Shockwave(position, radius, color)
	local ring = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 2, 2),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color or Color3.fromRGB(255, 240, 220),
		Transparency = 0.2,
		Material = Enum.Material.ForceField,
	})
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.45)
	VFX.Dust(position, Color3.fromRGB(235, 240, 250), 20)
end

-- Two piercing streaks for the impale.
function VFX.Pierce(root, color)
	for s = -1, 1, 2 do
		local cf = root.CFrame * CFrame.new(s * 0.5, 0.8, -3.5)
		local streak = fxPart({ Size = Vector3.new(0.12, 0.12, 5), CFrame = cf, Color = Color3.new(1, 1, 1) })
		local glow = fxPart({ Size = Vector3.new(0.4, 0.4, 5.5), CFrame = cf, Color = color or Color3.fromRGB(255, 70, 50), Transparency = 0.5 })
		TweenService:Create(streak, TweenInfo.new(0.2), { Transparency = 1, Size = Vector3.new(0.02, 0.02, 7) }):Play()
		TweenService:Create(glow, TweenInfo.new(0.25), { Transparency = 1, Size = Vector3.new(0.8, 0.8, 7) }):Play()
		Debris:AddItem(streak, 0.3)
		Debris:AddItem(glow, 0.3)
	end
end

-- Blood spraying out of the victim's back (impale).
function VFX.ExitSpray(char, direction)
	local torso = Util.Torso(char)
	if not torso then
		return
	end
	local anchor = Instance.new("Attachment")
	anchor.CFrame = CFrame.lookAt(Vector3.zero, torso.CFrame:VectorToObjectSpace(direction))
	anchor.Parent = torso
	local pe = Instance.new("ParticleEmitter")
	for k, v in Util.BloodProps do
		pe[k] = v
	end
	pe.EmissionDirection = Enum.NormalId.Front
	pe.SpreadAngle = Vector2.new(20, 20)
	pe.Speed = NumberRange.new(18, 30)
	pe.Rate = 220
	pe.Parent = anchor
	task.delay(0.25, function()
		pe.Enabled = false
	end)
	Debris:AddItem(anchor, 2)
end

-- Flickering shield shimmer during i-frames (visible to everyone).
function VFX.IFrames(char, duration)
	local old = char:FindFirstChild("IFrameGlow")
	if old then
		old:Destroy()
	end
	local hl = Instance.new("Highlight")
	hl.Name = "IFrameGlow"
	hl.FillColor = Color3.fromRGB(220, 240, 255)
	hl.OutlineColor = Color3.fromRGB(140, 220, 255)
	hl.FillTransparency = 0.55
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = char
	local tw = TweenService:Create(hl, TweenInfo.new(0.12, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), { FillTransparency = 0.95 })
	tw:Play()
	task.delay(duration, function()
		tw:Cancel()
		if hl.Parent then
			TweenService:Create(hl, TweenInfo.new(0.25), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
			Debris:AddItem(hl, 0.3)
		end
	end)
end

-- Streaky trail on someone being thrown.
function VFX.ThrowTrail(char, duration)
	local root = Util.Root(char)
	if not root then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.3
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 20, 20))
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail.Parent = root
	Debris:AddItem(trail, duration)
	Debris:AddItem(a0, duration)
	Debris:AddItem(a1, duration)
end

return VFX
