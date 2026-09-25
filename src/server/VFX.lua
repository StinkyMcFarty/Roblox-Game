-- Crisp combat visuals, created on the server so everyone sees them.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(ReplicatedStorage.Shared.Util)

local Fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx")

local VFX = {}

-- Plays a keyframed clip (client/AnimClips) on a character for every player.
local animLogs = 0
function VFX.Anim(char, clip, speed)
	if char and animLogs < 12 then
		animLogs += 1
		print(("[Anims] server -> %s plays %s"):format(char.Name, clip))
	end
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

-- Three razor-thin claw crescents in front of the attacker, drawn by every client
-- (client/SlashFX) so they render smoothly. `color` is the claw skin's glow.
function VFX.ClawArc(root, side, color)
	if root and root.Parent then
		Fx:FireAllClients("Slash", { Char = root.Parent, Side = side, Color = color })
	end
end

-- X-shaped star flare, needle burst and a white body flash at a hit location.
-- `victim` (optional character) flashes white for a frame; `claw` adds three
-- glowing claw gashes raked across the hit.
function VFX.Impact(position, color, size, victim, claw)
	Fx:FireAllClients("HitFlash", { Position = position, Color = color, Size = size or 1, Victim = victim, Claw = claw == true })
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
