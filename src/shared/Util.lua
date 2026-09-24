local Debris = game:GetService("Debris")

local Util = {}

function Util.Sound(id, parent, opts)
	if not id or id == "" or not parent then
		return nil
	end
	opts = opts or {}
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = opts.Volume or 0.8
	s.PlaybackSpeed = opts.Pitch or 1
	s.RollOffMaxDistance = opts.Range or 200
	s.RollOffMinDistance = opts.MinRange or 10
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, opts.Life or 8)
	return s
end

-- Plays a sound at a world position (spawns a tiny invisible anchor part).
function Util.SoundAt(id, position, opts)
	if not id or id == "" then
		return nil
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position
	anchor.Parent = workspace
	Debris:AddItem(anchor, (opts and opts.Life) or 6)
	return Util.Sound(id, anchor, opts)
end

-- A short particle burst that replicates (Emit() does not replicate from the server).
function Util.Burst(parent, props, count, lifetime)
	local att = Instance.new("Attachment")
	if typeof(parent) == "Vector3" then
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one * 0.2
		anchor.Position = parent
		anchor.Parent = workspace
		Debris:AddItem(anchor, 3)
		parent = anchor
	end
	att.Parent = parent
	local pe = Instance.new("ParticleEmitter")
	for k, v in props do
		pe[k] = v
	end
	pe.Rate = (count or 20) / 0.12
	pe.Parent = att
	task.delay(0.12, function()
		pe.Enabled = false
	end)
	Debris:AddItem(att, lifetime or 3)
	return pe
end

Util.BloodProps = {
	Texture = "rbxasset://textures/particles/smoke_main.dds",
	Color = ColorSequence.new(Color3.fromRGB(140, 0, 0), Color3.fromRGB(70, 0, 0)),
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0.15),
	}),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Lifetime = NumberRange.new(0.5, 1),
	Speed = NumberRange.new(8, 22),
	SpreadAngle = Vector2.new(70, 70),
	Acceleration = Vector3.new(0, -70, 0),
	Drag = 1.5,
	LightInfluence = 1,
}

Util.SparkProps = {
	Texture = "rbxasset://textures/particles/sparkles_main.dds",
	Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), Color3.fromRGB(255, 150, 40)),
	LightEmission = 1,
	Size = NumberSequence.new(0.3, 0),
	Lifetime = NumberRange.new(0.2, 0.45),
	Speed = NumberRange.new(10, 24),
	SpreadAngle = Vector2.new(180, 180),
	Acceleration = Vector3.new(0, -40, 0),
}

function Util.Root(char)
	return char and char:FindFirstChild("HumanoidRootPart")
end

function Util.Humanoid(char)
	return char and char:FindFirstChildOfClass("Humanoid")
end

function Util.IsAlive(char)
	local hum = Util.Humanoid(char)
	return hum ~= nil and hum.Health > 0
end

-- Works for R15 ("RightHand") and R6 ("Right Arm").
function Util.Hand(char, side)
	return char:FindFirstChild(side .. "Hand") or char:FindFirstChild(side .. " Arm")
end

function Util.Torso(char)
	return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
end

function Util.Flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return f.Unit
end

return Util
