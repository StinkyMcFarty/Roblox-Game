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

local states = setmetatable({}, { __mode = "k" })

local function getState(char)
	local st = states[char]
	if not st then
		local motors = {}
		for key, info in JOINTS do
			local part = char:FindFirstChild(info[1])
			local j = part and part:FindFirstChild(info[2])
			if j and j:IsA("Motor6D") then
				motors[key] = j
			end
		end
		st = { Motors = motors, Phase = 0, LoopBlend = 0, Loop = nil, Clip = nil, NextLook = 0, LookUntil = 0, LookSide = 1 }
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

-- Samples a clip at time t. Returns { joint = CFrame }.
local function sample(clip, t)
	local keys = clip.Keys
	local last = keys[#keys]
	if t >= last.T then
		local out = {}
		for j, a in last.Pose do
			out[j] = cf(a)
		end
		-- joints animated earlier in the clip return to rest
		for _, k in keys do
			for j in k.Pose do
				out[j] = out[j] or CFrame.identity
			end
		end
		return out
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
	local out = {}
	local seen = {}
	for _, k in keys do
		for j in k.Pose do
			seen[j] = true
		end
	end
	for j in seen do
		local a = k0.Pose[j] and cf(k0.Pose[j]) or CFrame.identity
		local b = k1.Pose[j] and cf(k1.Pose[j]) or CFrame.identity
		out[j] = a:Lerp(b, alpha)
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
local function fleePose(s, c, look)
	local up = math.abs(c)
	return {
		Root = CFrame.new(0, up * 0.25 - 0.1, 0) * CFrame.Angles(rad(-16), 0, 0),
		Waist = CFrame.Angles(rad(-6), rad(14 * s) + look * 0.35, 0),
		Neck = CFrame.Angles(rad(12), look, 0),
		RShoulder = CFrame.Angles(rad(-75 * s + 15), 0, rad(6)),
		LShoulder = CFrame.Angles(rad(75 * s + 15), 0, rad(-6)),
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
local function huntPose(s, c)
	local up = math.abs(c)
	return {
		Root = CFrame.new(0, up * 0.22 - 0.35, 0) * CFrame.Angles(rad(-34), rad(6 * s), 0),
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

-- Wolverine on all fours: a real quadruped gallop.
local function gallopPose(p)
	local front = math.sin(p)
	local back = math.sin(p + math.pi * 0.85)
	local flex = math.sin(p * 2)
	return {
		Root = CFrame.new(0, -0.55 + math.abs(math.sin(p)) * 0.3, 0) * CFrame.Angles(rad(-74 + flex * 6), 0, 0),
		Waist = CFrame.Angles(rad(flex * 10), 0, 0),
		Neck = CFrame.Angles(rad(62 - flex * 6), 0, 0),
		RShoulder = CFrame.Angles(rad(82 + front * 42), 0, rad(8)),
		LShoulder = CFrame.Angles(rad(82 + math.sin(p + 0.45) * 42), 0, rad(-8)),
		RElbow = CFrame.Angles(rad(18 + 40 * math.max(0, -front)), 0, 0),
		LElbow = CFrame.Angles(rad(18 + 40 * math.max(0, -math.sin(p + 0.45))), 0, 0),
		RWrist = CFrame.Angles(rad(-35), 0, 0),
		LWrist = CFrame.Angles(rad(-35), 0, 0),
		RHip = CFrame.Angles(rad(78 + back * 44), 0, 0),
		LHip = CFrame.Angles(rad(78 + math.sin(p + math.pi * 0.85 + 0.4) * 44), 0, 0),
		RKnee = CFrame.Angles(rad(-(40 + 60 * math.max(0, back))), 0, 0),
		LKnee = CFrame.Angles(rad(-(40 + 60 * math.max(0, math.sin(p + math.pi * 0.85 + 0.4)))), 0, 0),
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

local step = RunService.PreSimulation or RunService.Stepped
step:Connect(function(a, b)
	local dt = typeof(b) == "number" and b or a
	local now = os.clock()
	for _, char in characters() do
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		if not (hum and root and hum.RigType == Enum.HumanoidRigType.R15) then
			continue
		end
		local st = states[char]
		local role = attr(char, "Role")
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local airborne = hum:GetState() == Enum.HumanoidStateType.Freefall
		local alive = hum.Health > 0

		-- choose the loop
		local loop = nil
		if alive and not root.Anchored then
			if attr(char, "Feral") and speed > 4 then
				loop = "Gallop"
			elseif attr(char, "Sprinting") and speed > 8 and not airborne then
				loop = role == "Wolverine" and "Hunt" or "Flee"
			end
		end
		if not st and not loop then
			continue
		end
		st = st or getState(char)

		-- loop blend
		if loop then
			st.Loop = loop
		end
		st.LoopBlend = math.clamp(st.LoopBlend + (loop and dt * 7 or -dt * 7), 0, 1)
		st.Phase += dt * math.max(speed, 10) * (st.Loop == "Gallop" and 0.36 or 0.5)

		local pose = {}
		if st.LoopBlend > 0 and st.Loop then
			local s, c = math.sin(st.Phase), math.cos(st.Phase)
			if st.Loop == "Gallop" then
				pose = gallopPose(st.Phase)
			elseif st.Loop == "Hunt" then
				pose = huntPose(s, c)
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
				pose = fleePose(s, c, look)
			end
		end

		-- one-shot clip on top
		local clipPose, clipWeight = nil, 0
		local clip = st.Clip
		if clip then
			local t = (now - clip.Start) * clip.Speed
			local length = clip.Def.Keys[#clip.Def.Keys].T
			local ending = clip.Stopping or (not clip.Def.Hold and t >= length)
			clip.Weight = math.clamp(clip.Weight + (ending and -dt * 9 or dt * 18), 0, 1)
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

		if st.LoopBlend <= 0 and not st.Clip then
			states[char] = nil
			continue
		end

		for key, m in st.Motors do
			if m.Parent then
				local base = m.Transform
				local target = base
				local lp = pose[key]
				if lp then
					target = base:Lerp(lp, st.LoopBlend)
				end
				local cp = clipPose and clipPose[key]
				if cp then
					target = target:Lerp(cp, clipWeight)
				end
				if target ~= base then
					m.Transform = target
				end
			end
		end
	end
end)

return Anims
