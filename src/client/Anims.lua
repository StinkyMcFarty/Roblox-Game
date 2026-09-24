-- Client animation engine. Runs on every client for every character, so all
-- players see smooth full-framerate animation.
--   * Loops: survivor flee sprint, Wolverine's feral hunting run, all-fours gallop
--   * One-shot clips (AnimClips) triggered by the server: slashes, pounce,
--     impale, rip, roar, reactions, Sentinel moves...
-- Poses override Motor6D.Transform after Roblox's Animator (PreSimulation).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clips = require(script.Parent:WaitForChild("AnimClips"))

local Anims = {}
print("[Anims] animation engine running")

local rad = math.rad
local JOINTS = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
	RShoulder = { "RightUpperArm", "RightShoulder" },
	LShoulder = { "LeftUpperArm", "LeftShoulder" },
	RElbow = { "RightLowerArm", "RightElbow" },
	LElbow = { "LeftLowerArm", "LeftElbow" },
	RWrist = { "RightHand", "RightWrist" },
	LWrist = { "LeftHand", "LeftWrist" },
	RHip = { "RightUpperLeg", "RightHip" },
	LHip = { "LeftUpperLeg", "LeftHip" },
	RKnee = { "RightLowerLeg", "RightKnee" },
	LKnee = { "LeftLowerLeg", "LeftKnee" },
	RAnkle = { "RightFoot", "RightAnkle" },
	LAnkle = { "LeftFoot", "LeftAnkle" },
}

-- R6 bodies have fewer joints, and theirs are rotated; poses are converted
-- into each R6 joint's frame so the same animations work on either rig.
local R6_JOINTS = {
	Root = { "HumanoidRootPart", "RootJoint" },
	Neck = { "Torso", "Neck" },
	RShoulder = { "Torso", "Right Shoulder" },
	LShoulder = { "Torso", "Left Shoulder" },
	RHip = { "Torso", "Right Hip" },
	LHip = { "Torso", "Left Hip" },
}

local states = setmetatable({}, { __mode = "k" })
local diagnosed = setmetatable({}, { __mode = "k" })

local function getState(char)
	local st = states[char]
	if not st then
		local motors, conj = {}, {}
		local r6 = char:FindFirstChild("Torso") ~= nil and char:FindFirstChild("UpperTorso") == nil
		for key, info in (r6 and R6_JOINTS or JOINTS) do
			local part = char:FindFirstChild(info[1])
			local j = nil
			if part then
				-- Prefer the upgraded AnimationConstraint joint if the avatar has one,
				-- otherwise the classic Motor6D (both expose a writable Transform).
				for _, child in part:GetChildren() do
					if child.Name == info[2] and child:IsA("AnimationConstraint") then
						j = child
					end
				end
				if not j then
					local m = part:FindFirstChild(info[2])
					if m and m:IsA("Motor6D") then
						j = m
					end
				end
			end
			if j then
				motors[key] = j
				if r6 then
					conj[key] = j.C0 - j.C0.Position
				end
			end
		end
		local count = 0
		for _ in motors do
			count += 1
		end
		if not diagnosed[char] then
			diagnosed[char] = true
			local sample = motors.RShoulder
			print(("[Anims] %s: %s rig, %d animatable joints (%s)"):format(
				char.Name, r6 and "R6" or "R15", count, sample and sample.ClassName or "none"))
			if count == 0 then
				local kinds = {}
				for _, d in char:GetDescendants() do
					if d:IsA("JointInstance") or d:IsA("Constraint") then
						kinds[d.ClassName .. ":" .. d.Name] = true
					end
				end
				local list = {}
				for k in kinds do
					table.insert(list, k)
				end
				warn("[Anims] no joints found on " .. char.Name .. ". Joints present: " .. table.concat(list, ", "))
			end
		end
		st = { Motors = motors, Conj = conj, Phase = 0, LoopBlend = 0, Loop = nil, Clip = nil, NextLook = 0, LookUntil = 0, LookSide = 1 }
		states[char] = st
	end
	return st
end

local function cf(a)
	return CFrame.new(a[4] or 0, a[5] or 0, a[6] or 0) * CFrame.Angles(rad(a[1]), rad(a[2]), rad(a[3]))
end

local EASE = {
	Linear = function(t) return t end,
	In = function(t) return t * t * t end,
	Out = function(t) return 1 - (1 - t) ^ 3 end,
	InOut = function(t) return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2 end,
}

-- Follow-through: the hips lead, the torso follows, the arm whips through
-- last and the hand trails behind it. Seconds of lag per joint.
local LAG = {
	Root = 0, RHip = 0, LHip = 0, Waist = 0.018, RKnee = 0.02, LKnee = 0.02, RAnkle = 0.03, LAnkle = 0.03,
	Neck = 0.035, RShoulder = 0.032, LShoulder = 0.032, RElbow = 0.055, LElbow = 0.055, RWrist = 0.075, LWrist = 0.075,
}

local function jointsOf(clip)
	if not clip.Joints then
		local seen = {}
		for _, k in clip.Keys do
			for j in k.Pose do
				seen[j] = true
			end
		end
		clip.Joints = seen
	end
	return clip.Joints
end

local function sampleJoint(clip, j, t)
	local keys = clip.Keys
	local last = keys[#keys]
	if t <= 0 then
		return keys[1].Pose[j] and cf(keys[1].Pose[j]) or CFrame.identity
	end
	if t >= last.T then
		return last.Pose[j] and cf(last.Pose[j]) or CFrame.identity
	end
	local k0, k1 = keys[1], keys[2]
	for i = 1, #keys - 1 do
		if t >= keys[i].T and t < keys[i + 1].T then
			k0, k1 = keys[i], keys[i + 1]
			break
		end
	end
	local alpha = (t - k0.T) / math.max(1e-3, k1.T - k0.T)
	alpha = (EASE[k1.Ease or "InOut"] or EASE.InOut)(math.clamp(alpha, 0, 1))
	local a = k0.Pose[j] and cf(k0.Pose[j]) or CFrame.identity
	local b = k1.Pose[j] and cf(k1.Pose[j]) or CFrame.identity
	return a:Lerp(b, alpha)
end

-- Samples a clip at time t with per-joint follow-through lag.
local function sample(clip, t)
	local out = {}
	for j in jointsOf(clip) do
		out[j] = sampleJoint(clip, j, t - (LAG[j] or 0))
	end
	return out
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Anims.Play(char, name, speed)
	local clip = Clips[name]
	if not (char and clip) then
		return
	end
	local st = getState(char)
	-- ignore the server echo of a clip we already predicted locally
	if st.Clip and (st.Clip.Name == name or (clip.Group and st.Clip.Def.Group == clip.Group)) and os.clock() - st.Clip.Start < 0.25 then
		return
	end
	st.Clip = { Name = name, Def = clip, Start = os.clock(), Speed = speed or 1, Weight = 0, Stopping = false }
end

-- Freeze the current clip for a few frames (impact weight).
function Anims.HitStop(char, duration)
	local st = states[char]
	if st and st.Clip then
		st.Clip.Start += duration
		st.FrozenUntil = os.clock() + duration
	end
end

-- Kick the springs: the whole upper body shudders from an impact.
function Anims.Jolt(char, strength)
	local st = getState(char)
	strength = strength or 1
	for _, key in { "Waist", "Neck", "RShoulder", "LShoulder", "Root" } do
		local sp = st.Springs and st.Springs[key]
		if sp then
			sp.Vel += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 60 * strength
		end
	end
	st.JoltKick = strength
end

function Anims.Stop(char, name)
	local st = states[char]
	if st and st.Clip and (name == nil or st.Clip.Name == name) then
		st.Clip.Stopping = true
	end
end

---------------------------------------------------------------------------
-- Loops
---------------------------------------------------------------------------

-- Survivor: running for their life (looks back when he's close)
local function fleePose(s, c, look, build)
	build = build or 0
	local up = math.abs(c)
	local pump = 75 + 18 * build
	return {
		Root = CFrame.new(0, up * (0.25 + 0.1 * build) - 0.1, 0) * CFrame.Angles(rad(-16 - 12 * build), 0, 0),
		Waist = CFrame.Angles(rad(-6), rad(14 * s) + look * 0.35, 0),
		Neck = CFrame.Angles(rad(12), look, 0),
		RShoulder = CFrame.Angles(rad(-pump * s + 15), 0, rad(6)),
		LShoulder = CFrame.Angles(rad(pump * s + 15), 0, rad(-6)),
		RElbow = CFrame.Angles(rad(85 + 15 * s), 0, 0),
		LElbow = CFrame.Angles(rad(85 - 15 * s), 0, 0),
		RHip = CFrame.Angles(rad(60 * s + 8), 0, 0),
		LHip = CFrame.Angles(rad(-60 * s + 8), 0, 0),
		RKnee = CFrame.Angles(rad(-(15 + 85 * math.max(0, -s))), 0, 0),
		LKnee = CFrame.Angles(rad(-(15 + 85 * math.max(0, s))), 0, 0),
		RAnkle = CFrame.Angles(rad(-20 * s), 0, 0),
		LAnkle = CFrame.Angles(rad(20 * s), 0, 0),
	}
end

-- Wolverine: feral charge. Deep forward lean, arms swept back and out so
-- the claws trail behind him, huge powerful strides.
local function huntPose(s, c, build)
	build = build or 0
	local up = math.abs(c)
	return {
		Root = CFrame.new(0, up * 0.22 - 0.35 - 0.1 * build, 0) * CFrame.Angles(rad(-34 - 10 * build), rad(6 * s), 0),
		Waist = CFrame.Angles(rad(-8), rad(12 * s), 0),
		Neck = CFrame.Angles(rad(34), rad(-8 * s), 0),
		RShoulder = CFrame.Angles(rad(-58 + 16 * s), 0, rad(34)),
		LShoulder = CFrame.Angles(rad(-58 - 16 * s), 0, rad(-34)),
		RElbow = CFrame.Angles(rad(22), 0, 0),
		LElbow = CFrame.Angles(rad(22), 0, 0),
		RWrist = CFrame.Angles(rad(-20), 0, 0),
		LWrist = CFrame.Angles(rad(-20), 0, 0),
		RHip = CFrame.Angles(rad(70 * s + 22), 0, 0),
		LHip = CFrame.Angles(rad(-70 * s + 22), 0, 0),
		RKnee = CFrame.Angles(rad(-(28 + 95 * math.max(0, -s))), 0, 0),
		LKnee = CFrame.Angles(rad(-(28 + 95 * math.max(0, s))), 0, 0),
		RAnkle = CFrame.Angles(rad(-25 * s), 0, 0),
		LAnkle = CFrame.Angles(rad(25 * s), 0, 0),
	}
end

-- Wolverine on all fours: a smooth bounding lope. The spine stretches as
-- the front paws reach and bunches as the back legs drive; the head stays
-- level and locked forward while the body flows underneath it.
local function gallopPose(p)
	local function wave(x) -- smoother than a plain sine: fuller reach, quick recovery
		return math.sin(x) + 0.22 * math.sin(2 * x)
	end
	local front = wave(p)
	local front2 = wave(p + 0.35)
	local back = wave(p + math.pi)
	local back2 = wave(p + math.pi + 0.35)
	local spine = math.sin(p + math.pi * 0.5) -- + = stretched, - = bunched
	local pitch = -76 + spine * 5
	local bounce = (1 - math.cos(p * 2)) * 0.14
	return {
		Root = CFrame.new(0, -0.62 + bounce, 0) * CFrame.Angles(rad(pitch), rad(math.sin(p) * 3), rad(math.sin(p) * 3)),
		Waist = CFrame.Angles(rad(spine * 9), rad(-math.sin(p) * 4), 0),
		Neck = CFrame.Angles(rad(64 - spine * 14 - (pitch + 76)), rad(math.sin(p) * 2), 0), -- counters the spine: head stays level
		RShoulder = CFrame.Angles(rad(84 + front * 46), 0, rad(10)),
		LShoulder = CFrame.Angles(rad(84 + front2 * 46), 0, rad(-10)),
		RElbow = CFrame.Angles(rad(14 + 48 * math.max(0, -front)), 0, 0),
		LElbow = CFrame.Angles(rad(14 + 48 * math.max(0, -front2)), 0, 0),
		RWrist = CFrame.Angles(rad(-30 - 25 * math.max(0, front)), 0, 0),
		LWrist = CFrame.Angles(rad(-30 - 25 * math.max(0, front2)), 0, 0),
		RHip = CFrame.Angles(rad(80 + back * 46), 0, rad(4)),
		LHip = CFrame.Angles(rad(80 + back2 * 46), 0, rad(-4)),
		RKnee = CFrame.Angles(rad(-(34 + 70 * math.max(0, back))), 0, 0),
		LKnee = CFrame.Angles(rad(-(34 + 70 * math.max(0, back2))), 0, 0),
		RAnkle = CFrame.Angles(rad(20 * back), 0, 0),
		LAnkle = CFrame.Angles(rad(20 * back2), 0, 0),
	}
end

local function attr(char, name)
	local v = char:GetAttribute(name)
	if v ~= nil then
		return v
	end
	local p = Players:GetPlayerFromCharacter(char)
	return p and p:GetAttribute(name)
end

local function wolverineNear(root)
	local name = ReplicatedStorage:GetAttribute("Wolverine")
	local w = name and Players:FindFirstChild(name)
	local wRoot = w and w.Character and w.Character:FindFirstChild("HumanoidRootPart")
	return wRoot ~= nil and (wRoot.Position - root.Position).Magnitude < 70
end

local function characters()
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	local map = workspace:FindFirstChild("Map")
	local debris = map and map:FindFirstChild("Debris")
	if debris then
		for _, m in debris:GetChildren() do
			if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
				table.insert(list, m)
			end
		end
	end
	for char in states do
		if char.Parent and not table.find(list, char) then
			table.insert(list, char)
		end
	end
	return list
end

---------------------------------------------------------------------------
-- Per-frame
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Idle / breathing layers
---------------------------------------------------------------------------

-- Wolverine standing still: hunched predator stance, claws ready, flexing.
local function predatorIdle(t)
	local flex = math.max(0, math.sin(t * 0.9)) ^ 3
	return {
		Root = CFrame.new(0, -0.25, 0) * CFrame.Angles(rad(-12), 0, 0),
		Waist = CFrame.Angles(rad(-8), rad(math.sin(t * 0.4) * 4), 0),
		Neck = CFrame.Angles(rad(16), rad(math.sin(t * 0.37) * 12), 0),
		RShoulder = CFrame.Angles(rad(22), 0, rad(16)),
		LShoulder = CFrame.Angles(rad(22), 0, rad(-16)),
		RElbow = CFrame.Angles(rad(32 + flex * 18), 0, 0),
		LElbow = CFrame.Angles(rad(32 + math.max(0, math.sin(t * 0.9 + 1.7)) ^ 3 * 18), 0, 0),
		RWrist = CFrame.Angles(rad(-10 - flex * 14), 0, 0),
		LWrist = CFrame.Angles(rad(-10), 0, 0),
		RHip = CFrame.Angles(rad(14), 0, rad(6)),
		LHip = CFrame.Angles(rad(8), 0, rad(-6)),
		RKnee = CFrame.Angles(rad(-20), 0, 0),
		LKnee = CFrame.Angles(rad(-14), 0, 0),
	}
end

-- Additive breathing: chest rises, shoulders lift, head counters.
local function breath(phase, amp)
	local b = math.sin(phase)
	return {
		Waist = CFrame.Angles(rad(b * 2.2 * amp), 0, 0),
		Neck = CFrame.Angles(rad(-b * 1.4 * amp), 0, 0),
		RShoulder = CFrame.Angles(0, 0, rad(b * 1.6 * amp)),
		LShoulder = CFrame.Angles(0, 0, rad(-b * 1.6 * amp)),
		Root = CFrame.new(0, b * 0.02 * amp, 0),
	}
end

---------------------------------------------------------------------------
-- Springs: every joint chases its target with a little overshoot + settle
---------------------------------------------------------------------------

local SPRING = {
	Root = { 520, 0.8 }, Waist = { 380, 0.62 }, Neck = { 300, 0.6 },
	RShoulder = { 260, 0.5 }, LShoulder = { 260, 0.5 }, RElbow = { 300, 0.48 }, LElbow = { 300, 0.48 },
	RWrist = { 340, 0.45 }, LWrist = { 340, 0.45 },
	RHip = { 420, 0.7 }, LHip = { 420, 0.7 }, RKnee = { 440, 0.7 }, LKnee = { 440, 0.7 },
	RAnkle = { 460, 0.75 }, LAnkle = { 460, 0.75 },
}

local function springStep(sp, target, dt, key)
	local cfg = SPRING[key] or { 350, 0.6 }
	local k, zeta = cfg[1], cfg[2]
	local d = 2 * zeta * math.sqrt(k)
	local diff = sp.Cur:Inverse() * target
	local axis, angle = diff:ToAxisAngle()
	if angle > math.pi then
		angle -= math.pi * 2
	end
	local err = axis * angle
	if err ~= err or math.abs(angle) < 1e-5 then -- NaN / identity guard
		err = Vector3.zero
	end
	if sp.Vel ~= sp.Vel then
		sp.Vel = Vector3.zero
	end
	sp.Vel += (err * k - sp.Vel * d) * dt
	local w = sp.Vel * dt
	local mag = w.Magnitude
	local rot = mag > 1e-6 and CFrame.fromAxisAngle(w / mag, mag) or CFrame.identity
	local pos = sp.Cur.Position:Lerp(target.Position, math.min(1, dt * 18))
	sp.Cur = (CFrame.new(pos) * (sp.Cur - sp.Cur.Position) * rot)
	return sp.Cur
end

---------------------------------------------------------------------------
-- Per-frame
---------------------------------------------------------------------------

local step = RunService.PreSimulation or RunService.Stepped
step:Connect(function(a, b)
	local dt = math.min(typeof(b) == "number" and b or a, 1 / 20)
	local now = os.clock()
	for _, char in characters() do
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		if not (hum and root) then
			continue
		end
		local st = getState(char)
		local role = attr(char, "Role")
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local airborne = hum:GetState() == Enum.HumanoidStateType.Freefall
		local alive = hum.Health > 0
		if not alive then
			continue
		end

		-- choose the loop
		local loop = nil
		if not root.Anchored then
			if attr(char, "Feral") and speed > 4 then
				loop = "Gallop"
			elseif attr(char, "Sprinting") and speed > 8 and not airborne then
				loop = role == "Wolverine" and "Hunt" or "Flee"
			end
		end
		if loop then
			st.Loop = loop
		end
		st.LoopBlend = math.clamp(st.LoopBlend + (loop and dt * 7 or -dt * 7), 0, 1)
		st.Phase += dt * math.max(speed, 10) * (st.Loop == "Gallop" and 0.36 or 0.5)

		-- predator idle blend (Wolverine standing / walking slowly, no clip)
		local wantIdle = role == "Wolverine" and speed < 6 and not st.Clip and not loop and not root.Anchored
		st.IdleBlend = math.clamp((st.IdleBlend or 0) + (wantIdle and dt * 3 or -dt * 6), 0, 1)

		-- breathing: calm when rested, ragged panting when out of stamina / after sprinting
		local stamina = attr(char, "Stamina") or 1
		local exertion = math.clamp((1 - stamina) * 1.4 + (speed > 12 and 0.4 or 0), 0, 1)
		st.Exertion = (st.Exertion or 0) + (exertion - (st.Exertion or 0)) * math.min(1, dt * 1.5)
		local rate = (role == "Wolverine" and 1.4 or 1.7) + st.Exertion * 5.5
		st.BreathPhase = (st.BreathPhase or 0) + dt * rate
		local breathAmp = (role == "Wolverine" and 1.8 or 1) * (1 + st.Exertion * 1.6)

		local pose = {}
		if st.LoopBlend > 0 and st.Loop then
			local s, c = math.sin(st.Phase), math.cos(st.Phase)
			if st.Loop == "Gallop" then
				pose = gallopPose(st.Phase)
			elseif st.Loop == "Hunt" then
				pose = huntPose(s, c, attr(char, "RunBuild"))
			else
				local look = 0
				if now > st.NextLook and wolverineNear(root) then
					st.LookUntil = now + 0.45
					st.NextLook = now + 1.6 + math.random() * 1.8
					st.LookSide = math.random() < 0.5 and -1 or 1
				end
				if now < st.LookUntil then
					look = rad(70) * st.LookSide
				end
				pose = fleePose(s, c, look, attr(char, "RunBuild"))
			end
		end
		local idle = st.IdleBlend > 0 and predatorIdle(now) or nil

		-- one-shot clip on top
		local clipPose, clipWeight = nil, 0
		local clip = st.Clip
		if clip then
			local frozen = st.FrozenUntil and now < st.FrozenUntil
			local t = (now - clip.Start) * clip.Speed
			local length = clip.Def.Keys[#clip.Def.Keys].T + 0.08
			local ending = clip.Stopping or (not clip.Def.Hold and t >= length)
			if not frozen then
				clip.Weight = math.clamp(clip.Weight + (ending and -dt * 9 or dt * 18), 0, 1)
			end
			if ending and clip.Weight <= 0 then
				st.Clip = nil
			else
				clipPose = sample(clip.Def, math.min(t, length))
				clipWeight = clip.Weight
				if clip.Def.Tremble then
					local j = rad(1.6)
					for _, key in { "Neck", "Waist", "RShoulder", "LShoulder" } do
						if clipPose[key] then
							clipPose[key] = clipPose[key] * CFrame.Angles((math.random() - 0.5) * j, (math.random() - 0.5) * j, 0)
						end
					end
				end
			end
		end

		local breathPose = breath(st.BreathPhase, breathAmp)
		local layered = st.LoopBlend > 0 or st.IdleBlend > 0 or st.Clip ~= nil
		st.Springs = st.Springs or {}
		for key, m in st.Motors do
			if m.Parent then
				local R = st.Conj[key]
				local base = R and (R * m.Transform * R:Inverse()) or m.Transform
				local target = base
				if idle and idle[key] then
					target = target:Lerp(idle[key], st.IdleBlend)
				end
				local lp = pose[key]
				if lp then
					target = target:Lerp(lp, st.LoopBlend)
				end
				local cp = clipPose and clipPose[key]
				if cp then
					target = target:Lerp(cp, clipWeight)
				end
				local br = breathPose[key]
				if br then
					target = target * br
				end
				-- springs give follow-through + overshoot when our layers drive the joint
				local sp = st.Springs[key]
				if not sp then
					sp = { Cur = target, Vel = Vector3.zero }
					st.Springs[key] = sp
				end
				local final
				if layered or (st.JoltKick or 0) > 0.01 then
					final = springStep(sp, target, dt, key)
				else
					sp.Cur = target
					sp.Vel = Vector3.zero
					final = target
				end
				m.Transform = R and (R:Inverse() * final * R) or final
			end
		end
		st.JoltKick = math.max(0, (st.JoltKick or 0) - dt * 2)
	end
end)

return Anims
