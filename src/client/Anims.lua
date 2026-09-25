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
local LEG_KEYS = { Root = true, RHip = true, LHip = true, RKnee = true, LKnee = true, RAnkle = true, LAnkle = true }
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- All-fours footfalls: heavy padded thumps with a claw click, on the stride.
local function pawStep(st, root, pitch)
	st.Paws = st.Paws or {}
	if #st.Paws == 0 then
		for i = 1, 4 do
			local snd = Instance.new("Sound")
			snd.Name = "Paw"
			snd.SoundId = Config.Sounds.Paw
			snd.Volume = 0.5
			snd.RollOffMaxDistance = 120
			snd.RollOffMinDistance = 8
			snd.Parent = root
			st.Paws[i] = snd
		end
	end
	st.PawIndex = (st.PawIndex or 0) % #st.Paws + 1
	local snd = st.Paws[st.PawIndex]
	if snd.Parent ~= root then
		snd.Parent = root
	end
	snd.PlaybackSpeed = pitch * (0.92 + math.random() * 0.16)
	snd.TimePosition = 0
	snd:Play()
end
-- A Sentinel foot slamming down: dust rolling out from under it.
local function stompDust(char, footName, k, big)
	local foot = char:FindFirstChild(footName)
	if not foot then
		return
	end
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(1, 0.2, 1)
	p.CFrame = CFrame.new(foot.Position - Vector3.new(0, foot.Size.Y * 0.5, 0))
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(150, 144, 136))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * k), NumberSequenceKeypoint.new(1, 2 * k) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(4 * k, 7 * k)
	e.SpreadAngle = Vector2.new(80, 80)
	e.EmissionDirection = Enum.NormalId.Top
	e.Drag = 6
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Rate = 0
	e.Parent = p
	e:Emit(big and 14 or 9)
	task.delay(1.2, function()
		p:Destroy()
	end)
end

-- Footsteps: custom multi-take files (tools/generate_sfx.py). Each file holds
-- several takes back to back; a random one (never the same twice running) is
-- played through PlaybackRegion. Surfaces: tile, steel grating, Sentinel stomp.
-- Wolverine layers his own on top: the weight of an adamantium skeleton, and
-- on all fours his claws biting into the floor (ClawDig.ogg holds 4 concrete
-- takes, then 3 steel ones). Range = roll-off min/max distance.
local STEP_LAYOUT = {
	Step = { Slot = 0.5, Takes = 4 },
	StepMetal = { Slot = 0.5, Takes = 4 },
	StepHeavy = { Slot = 0.8, Takes = 3, Range = { 10, 170 } },
	StepWolverine = { Slot = 0.6, Takes = 4, Range = { 8, 140 } },
	ClawDig = { Slot = 0.4, Takes = 4, Range = { 5, 95 } },
	ClawDigMetal = { Slot = 0.4, Takes = 3, First = 4, File = "ClawDig", Range = { 5, 95 } },
}
-- Until Wolverine's files are uploaded, a stand-in plays whole instead.
local STAND_IN = {
	StepWolverine = { Id = Config.Sounds.Land, Pitch = 0.55, Volume = 0.9 },
	ClawDig = { Id = Config.Sounds.Slash, Pitch = 0.62, Volume = 0.35 },
	ClawDigMetal = { Id = Config.Sounds.Slash, Pitch = 0.9, Volume = 0.3 },
}
local CUSTOM_STEPS = Config.Sounds.Step ~= ""
local METAL_FLOORS = {
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.CorrodedMetal] = true,
	[Enum.Material.Foil] = true,
}

local function footstep(st, root, kind, volume, pitch)
	local layout = STEP_LAYOUT[kind]
	local range = layout.Range or { 5, 85 }
	local file = layout.File or kind
	local id = Config.Sounds[file]
	local standIn = STAND_IN[kind]
	if standIn and (Config.UploadedSounds[file] or 0) == 0 then
		id, layout = standIn.Id, nil
		volume *= standIn.Volume
		pitch *= standIn.Pitch
	elseif kind == "StepHeavy" and id == Config.Sounds.StepMetal then
		layout = STEP_LAYOUT.StepMetal -- heavy file not uploaded yet: pitched-down grate
	end
	st.Steps = st.Steps or {}
	local pool = st.Steps[kind]
	if not pool then
		pool = { Index = 0, Last = -1 }
		for i = 1, 3 do
			local snd = Instance.new("Sound")
			snd.Name = kind
			snd.SoundId = id
			snd.PlaybackRegionsEnabled = layout ~= nil
			snd.RollOffMode = Enum.RollOffMode.InverseTapered
			snd.RollOffMinDistance = range[1]
			snd.RollOffMaxDistance = range[2]
			snd.Parent = root
			pool[i] = snd
		end
		st.Steps[kind] = pool
	end
	pool.Index = pool.Index % 3 + 1
	local snd = pool[pool.Index]
	if snd.Parent ~= root then
		snd.Parent = root
	end
	local from = 0
	if layout then
		local take = math.random(0, layout.Takes - 2)
		if take >= pool.Last then
			take += 1
		end
		pool.Last = take
		from = ((layout.First or 0) + take) * layout.Slot
		snd.PlaybackRegion = NumberRange.new(from, from + layout.Slot - 0.02)
	end
	snd.Volume = volume * (0.88 + math.random() * 0.12)
	snd.PlaybackSpeed = pitch * (0.95 + math.random() * 0.1)
	snd.TimePosition = from
	snd:Play()
end

local TAU = math.pi * 2
-- Gallop footfalls: the loop phase at which each paw strikes (matched to
-- gallopPose). The hind feet land together at the start of the stride, the
-- clawed front paws half a stride later.
local PAW_HITS = {
	{ Phase = 0.1, Front = false },
	{ Phase = 0.45, Front = false },
	{ Phase = 0.25 + math.pi, Front = true },
	{ Phase = 0.6 + math.pi, Front = true },
}

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

-- Wolverine walking: a heavy, hunched prowl. Shoulders roll against the
-- hips, arms hang low and wide with the claws out, weight drops into each
-- step and the head stays locked on his prey.
local function prowlPose(s, c)
	local plant = math.abs(s) ^ 3 -- heel strike
	return {
		Root = CFrame.new(0, math.abs(c) * 0.12 - 0.34 - plant * 0.08, 0) * CFrame.Angles(rad(-20), rad(6 * s), rad(4 * s)),
		Waist = CFrame.Angles(rad(-8 + plant * 3), rad(-13 * s), rad(-3 * s)),
		Neck = CFrame.Angles(rad(22), rad(9 * s), rad(-2 * s)),
		RShoulder = CFrame.Angles(rad(10 - 26 * s), rad(-6), rad(26 + 4 * c)),
		LShoulder = CFrame.Angles(rad(10 + 26 * s), rad(6), rad(-26 - 4 * c)),
		RElbow = CFrame.Angles(rad(42 + 14 * math.max(0, -s)), 0, 0),
		LElbow = CFrame.Angles(rad(42 + 14 * math.max(0, s)), 0, 0),
		RWrist = CFrame.Angles(rad(-18), 0, rad(8)),
		LWrist = CFrame.Angles(rad(-18), 0, rad(-8)),
		RHip = CFrame.Angles(rad(36 * s + 14), 0, rad(3)),
		LHip = CFrame.Angles(rad(-36 * s + 14), 0, rad(-3)),
		RKnee = CFrame.Angles(rad(-(22 + 55 * math.max(0, -s))), 0, 0),
		LKnee = CFrame.Angles(rad(-(22 + 55 * math.max(0, s))), 0, 0),
		RAnkle = CFrame.Angles(rad(-14 * s + 6), 0, 0),
		LAnkle = CFrame.Angles(rad(14 * s + 6), 0, 0),
	}
end

-- SENTINEL LOCOMOTION ------------------------------------------------------
-- (tools/preview/cycle.py renders these: keep them pure, phase in, joints out)
-- Phase p runs 0..2pi per stride: the right heel strikes at 0, the left at pi.
-- The loop feeds a warped phase so each stride lingers on its footfall and
-- hurries through the swing (sentinelWarp). k = the suit's scale, so the body
-- drop reads the same on a 1.8x Sentinel.
local SENTINEL_WARP = 0.2

local function sentinelWarp(p)
	return p - SENTINEL_WARP * math.sin(2 * p)
end

local function smooth01(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- One leg through a stride (phi 0 = heel strike). duty: share of the stride
-- the foot is planted. reach: hip swing either side (deg); lift: knee bend
-- hauling the foot through; load: how far the knee buckles taking the weight;
-- over: how far the thigh drives up past its landing angle before the leg
-- straightens and the foot slams down. Returns hip pitch, knee (negative =
-- bent) and ankle, in degrees.
local function heavyLeg(phi, duty, reach, lift, load, over)
	local u = (phi % TAU) / TAU
	local hip, knee
	if u < duty then
		local v = u / duty -- planted: the leg sweeps back under the body
		hip = reach * (1 - 2 * v)
		knee = -(8 + load * math.sin(math.pi * math.min(1, v / 0.45)))
	else
		local v = (u - duty) / (1 - duty)
		-- swing: the thigh drives up and forward (knee high), then the shin
		-- swings out straight and the whole leg drops onto the heel
		local drive = 1 - (1 - math.min(1, v / 0.72)) ^ 2
		hip = -reach + (2 * reach + over) * drive - over * smooth01((v - 0.72) / 0.28)
		knee = -(8 + lift * math.sin(math.pi * math.min(1, v / 0.8)))
	end
	return hip, knee, -(hip + knee) * 0.6 -- the ankle keeps the sole near flat
end

-- Walking: tons of armour on every step. Long slow strides; each foot slams
-- down, the body drops hard onto it and the knee buckles taking the weight,
-- then it rolls over the planted leg. The pelvis turns with the stride, the
-- chest counter-turns, and the arms swing heavily a beat behind the legs.
local function stompPose(p, k)
	local rh, rk, ra = heavyLeg(p, 0.58, 40, 70, 34, 16)
	local lh, lk, la = heavyLeg(p + math.pi, 0.58, 40, 70, 34, 16)
	local q = (p % math.pi) / math.pi -- 0 at every heel strike
	local thud = math.exp(-q * 7) -- the weight landing
	local bob = (-0.42 * thud + 0.14 * math.sin(math.pi * q) - 0.14) * k
	local side = math.cos(p - 0.9) -- > 0: the weight is over the right foot
	local turn = math.cos(p) -- the pelvis turns with the forward leg
	local arm = math.cos(p - 0.5) -- the arms lag the legs
	return {
		Root = CFrame.new(side * 0.16 * k, bob, 0) * CFrame.Angles(rad(-9 + thud * 5), rad(9 * turn), rad(-side * 6)),
		Waist = CFrame.Angles(rad(-4 - thud * 4), rad(-7 * turn), rad(side * 3)),
		Neck = CFrame.Angles(rad(6 + thud * 7), rad(-3 * turn), rad(side * 3)),
		RShoulder = CFrame.Angles(rad(8 - 26 * arm + thud * 6), 0, rad(18)),
		LShoulder = CFrame.Angles(rad(8 + 26 * arm + thud * 6), 0, rad(-18)),
		RElbow = CFrame.Angles(rad(24 + 18 * math.max(0, -arm)), 0, 0),
		LElbow = CFrame.Angles(rad(24 + 18 * math.max(0, arm)), 0, 0),
		RHip = CFrame.Angles(rad(rh), 0, rad(7)),
		LHip = CFrame.Angles(rad(lh), 0, rad(-7)),
		RKnee = CFrame.Angles(rad(rk), 0, 0),
		LKnee = CFrame.Angles(rad(lk), 0, 0),
		RAnkle = CFrame.Angles(rad(ra), 0, 0),
		LAnkle = CFrame.Angles(rad(la), 0, 0),
	}
end

-- Running (pursuit thrusters): heavy but fast. Leaning hard into it, huge
-- pounding strides with the knees driving high, arms pumping, and a big drop
-- through the whole body on every footfall.
local function chargePose(p, k)
	local rh, rk, ra = heavyLeg(p, 0.44, 44, 100, 34, 20)
	local lh, lk, la = heavyLeg(p + math.pi, 0.44, 44, 100, 34, 20)
	local q = (p % math.pi) / math.pi
	local thud = math.exp(-q * 6)
	local bob = (-0.44 * thud + 0.32 * math.sin(math.pi * math.min(1, q * 1.1)) - 0.3) * k
	local side = math.cos(p - 0.7)
	local turn = math.cos(p)
	local arm = math.cos(p - 0.35)
	return {
		Root = CFrame.new(side * 0.1 * k, bob, 0) * CFrame.Angles(rad(-17 + thud * 6), rad(12 * turn), rad(-side * 5)),
		Waist = CFrame.Angles(rad(-8 - thud * 5), rad(-12 * turn), rad(side * 3)),
		Neck = CFrame.Angles(rad(20 + thud * 6), rad(-4 * turn), 0),
		RShoulder = CFrame.Angles(rad(16 - 58 * arm), 0, rad(20)),
		LShoulder = CFrame.Angles(rad(16 + 58 * arm), 0, rad(-20)),
		RElbow = CFrame.Angles(rad(78 + 18 * arm), 0, 0),
		LElbow = CFrame.Angles(rad(78 - 18 * arm), 0, 0),
		RHip = CFrame.Angles(rad(rh), 0, rad(5)),
		LHip = CFrame.Angles(rad(lh), 0, rad(-5)),
		RKnee = CFrame.Angles(rad(rk), 0, 0),
		LKnee = CFrame.Angles(rad(lk), 0, 0),
		RAnkle = CFrame.Angles(rad(ra), 0, 0),
		LAnkle = CFrame.Angles(rad(la), 0, 0),
	}
end
-- END SENTINEL LOCOMOTION ----------------------------------------------------

-- Sentinel standing: wide armoured stance, systems idling.
local function sentinelIdle(t)
	local hum = math.sin(t * 1.3)
	return {
		Root = CFrame.new(0, -0.08 + hum * 0.02, 0),
		Waist = CFrame.Angles(0, rad(math.sin(t * 0.3) * 4), 0),
		Neck = CFrame.Angles(rad(3), rad(math.sin(t * 0.45) * 14), 0),
		RShoulder = CFrame.Angles(rad(4), 0, rad(14)),
		LShoulder = CFrame.Angles(rad(4), 0, rad(-14)),
		RElbow = CFrame.Angles(rad(14), 0, 0),
		LElbow = CFrame.Angles(rad(14), 0, 0),
		RHip = CFrame.Angles(0, 0, rad(5)),
		LHip = CFrame.Angles(0, 0, rad(-5)),
	}
end

-- Wolverine on all fours: a bounding gallop. The spine stretches as the
-- front paws reach and bunches as the back legs drive; the head stays level
-- and locked forward while the body flows underneath it. The hind legs drive
-- back short and hard, kick up high behind him as they leave the floor and
-- stay folded up through the swing until they reach under his belly to land.
local HIND_LIFT_OFF = 4.366 -- where hindWave bottoms out (the foot leaves the floor)
local HIND_SWING = 3.834 -- phase the foot then spends in the air
local function hindLift(x) -- 0 on the floor, up to 1 tucked high mid-swing
	local u = ((x - HIND_LIFT_OFF) % TAU) / HIND_SWING
	return u < 1 and math.sin(math.pi * u ^ 0.8) or 0
end

local function gallopPose(p)
	local function wave(x) -- smoother than a plain sine: fuller reach, quick recovery
		return math.sin(x) + 0.22 * math.sin(2 * x)
	end
	local function hindWave(x) -- the other way round: a quick drive, a long swing
		return math.sin(x) - 0.22 * math.sin(2 * x)
	end
	local function hindHip(b) -- reaches under his belly, kicks out long behind
		return 76 + b * 48 + math.min(0, b) * 12
	end
	local front = wave(p)
	local front2 = wave(p + 0.35)
	local back = hindWave(p + math.pi)
	local back2 = hindWave(p + math.pi + 0.35)
	local lift = hindLift(p + math.pi)
	local lift2 = hindLift(p + math.pi + 0.35)
	local spine = math.sin(p + math.pi * 0.5) -- + = stretched, - = bunched
	local buck = math.max(0, math.sin(p - 0.35)) ^ 2 -- rear tips up as the hind legs push off
	local pitch = -76 + spine * 5 - buck * 6
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
		RHip = CFrame.Angles(rad(hindHip(back)), 0, rad(4)),
		LHip = CFrame.Angles(rad(hindHip(back2)), 0, rad(-4)),
		RKnee = CFrame.Angles(rad(-(30 + 50 * math.max(0, back) + 78 * lift)), 0, 0),
		LKnee = CFrame.Angles(rad(-(30 + 50 * math.max(0, back2) + 78 * lift2)), 0, 0),
		RAnkle = CFrame.Angles(rad(18 * back - 35 * lift), 0, 0), -- toes point as the foot kicks up
		LAnkle = CFrame.Angles(rad(18 * back2 - 35 * lift2), 0, 0),
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

-- Rage stance, added on top of everything else: he leans further over, head
-- jutting forward, shoulders rolled up and in, arms held heavier.
local function rageHunch(w)
	return {
		Root = CFrame.new(0, -0.12 * w, 0) * CFrame.Angles(rad(-10 * w), 0, 0),
		Waist = CFrame.Angles(rad(-8 * w), 0, 0),
		Neck = CFrame.Angles(rad(10 * w), 0, 0),
		RShoulder = CFrame.Angles(rad(8 * w), 0, rad(6 * w)),
		LShoulder = CFrame.Angles(rad(8 * w), 0, rad(-6 * w)),
		RElbow = CFrame.Angles(rad(10 * w), 0, 0),
		LElbow = CFrame.Angles(rad(10 * w), 0, 0),
	}
end

-- Each hard exhale in a rage shows: a hot puff from his mouth.
local function rageExhale(char)
	local head = char:FindFirstChild("Head")
	if not head then
		return
	end
	local at = head:FindFirstChild("RageBreathAt")
	local em = at and at:FindFirstChild("RageBreath")
	if not em then
		at = Instance.new("Attachment")
		at.Name = "RageBreathAt"
		at.Position = Vector3.new(0, -0.25, -0.6) -- his mouth; Front is the way he faces
		at.Parent = head
		em = Instance.new("ParticleEmitter")
		em.Name = "RageBreath"
		em.Texture = "rbxasset://textures/particles/smoke_main.dds"
		em.Color = ColorSequence.new(Color3.fromRGB(255, 225, 215), Color3.fromRGB(180, 150, 150))
		em.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.3, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		})
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1.4) })
		em.Lifetime = NumberRange.new(0.45, 0.8)
		em.Speed = NumberRange.new(5, 8)
		em.SpreadAngle = Vector2.new(18, 18)
		em.Drag = 4
		em.Acceleration = Vector3.new(0, 1.5, 0)
		em.Rotation = NumberRange.new(0, 360)
		em.RotSpeed = NumberRange.new(-60, 60)
		em.LightEmission = 0.1
		em.EmissionDirection = Enum.NormalId.Front
		em.Rate = 0
		em.Parent = at
	end
	em:Emit(6)
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
		if not st.ScaleAt or now - st.ScaleAt > 1 then
			-- suits are scaled up (Config.Sentinel.Scale): body moves scale with them
			st.ScaleAt = now
			local ok, k = pcall(char.GetScale, char)
			st.Scale = ok and k or 1
		end
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
			elseif role == "Sentinel" and not airborne and speed > 1.5 then
				loop = speed > 23 and "Charge" or "Stomp" -- a Sentinel never uses the survivor run
			elseif attr(char, "Sprinting") and speed > 8 and not airborne then
				loop = role == "Wolverine" and "Hunt" or "Flee"
			elseif role == "Wolverine" and speed > 1.5 and not airborne then
				loop = "Prowl"
			end
		end
		if loop then
			st.Loop = loop
		end
		st.LoopBlend = math.clamp(st.LoopBlend + (loop and dt * 7 or -dt * 7), 0, 1)
		local prevPhase = st.Phase
		st.Phase += dt * math.max(speed, (st.Loop == "Prowl" or st.Loop == "Stomp") and 6 or 10) * (st.Loop == "Gallop" and 0.36 or st.Loop == "Prowl" and 0.55 or st.Loop == "Stomp" and 0.45 or st.Loop == "Charge" and 0.34 or 0.5)

		-- all-fours footfalls (and custom footsteps) replace the normal running sound
		local running = root:FindFirstChild("Running")
		local galloping = st.Loop == "Gallop" and loop == "Gallop"
		if running and running:IsA("Sound") then
			if galloping or CUSTOM_STEPS then
				st.RunVolume = st.RunVolume or running.Volume
				running.Volume = 0
			elseif st.RunVolume then
				running.Volume = st.RunVolume
				st.RunVolume = nil
			end
		end
		if galloping and st.LoopBlend > 0.5 then
			if not airborne then
				local metalFloor = METAL_FLOORS[hum.FloorMaterial]
				for _, hit in PAW_HITS do
					local off = hit.Phase
					if math.floor((prevPhase - off) / TAU) ~= math.floor((st.Phase - off) / TAU) then
						if hit.Front then
							-- his claws are out: they bite into the floor with every stride
							pawStep(st, root, 1.08)
							footstep(st, root, metalFloor and "ClawDigMetal" or "ClawDig", 0.5, 1)
						else
							-- hind feet: the full weight of an adamantium skeleton
							pawStep(st, root, 0.85)
							footstep(st, root, "StepWolverine", 0.5, 1.1)
						end
					end
				end
			end
		elseif CUSTOM_STEPS and speed > 1.5 and hum.FloorMaterial ~= Enum.Material.Air and not airborne then
			local kind = role == "Sentinel" and "StepHeavy" or (METAL_FLOORS[hum.FloorMaterial] and "StepMetal" or "Step")
			local vol, pitch = 0.26, 1
			if role == "Sentinel" then
				vol, pitch = st.Loop == "Charge" and 0.8 or 0.6, (Config.Sounds.StepHeavy == Config.Sounds.StepMetal and 0.6 or 1) * (st.Loop == "Charge" and 0.92 or 1)
			elseif role == "Wolverine" then
				vol, pitch = 0.36, 0.8 -- the boot on the floor; StepWolverine below carries his weight
			elseif speed > 18 then
				vol = 0.36
			end
			local stepped = false
			local stomping = st.Loop == "Stomp" or st.Loop == "Charge"
			if loop and st.Loop == loop and st.LoopBlend > 0.5 then
				-- heel strike lands where the stride peaks (|sin phase| = 1); a
				-- Sentinel's heels strike at 0 and pi (see SENTINEL LOCOMOTION)
				local off = stomping and 0 or math.pi / 2
				stepped = math.floor((prevPhase - off) / math.pi) ~= math.floor((st.Phase - off) / math.pi)
				st.StepDist = 0
			else
				-- plain walk (Roblox's own walk animation): one footfall per stride
				st.StepDist = (st.StepDist or 0) + speed * dt
				if st.StepDist >= 5.2 then
					st.StepDist -= 5.2
					stepped = true
				end
			end
			if stepped then
				footstep(st, root, kind, vol, pitch)
				if role == "Sentinel" then
					if stomping and loop then
						-- dust bursts out from under the foot that just landed
						local right = math.floor(st.Phase / math.pi) % 2 == 0
						stompDust(char, right and "RightFoot" or "LeftFoot", st.Scale or 1, st.Loop == "Charge")
					end
					if _G.WolverineShake then
						-- the deck shakes under a Sentinel's footfall (harder at a run)
						local d = (workspace.CurrentCamera.CFrame.Position - root.Position).Magnitude
						local amt = (st.Loop == "Charge" and 0.42 or 0.24) * math.clamp(1 - d / 60, 0, 1)
						if amt > 0.02 then
							_G.WolverineShake(amt)
						end
					end
				end
				if role == "Wolverine" then
					-- adamantium skeleton: every footfall lands far heavier than a survivor's
					footstep(st, root, "StepWolverine", st.Loop == "Hunt" and loop == "Hunt" and 0.85 or 0.65, 1)
				end
			end
		end

		-- predator idle blend (Wolverine standing / walking slowly, no clip)
		local wantIdle = (role == "Wolverine" or role == "Sentinel") and not st.Clip and not loop and not root.Anchored
		st.IdleBlend = math.clamp((st.IdleBlend or 0) + (wantIdle and dt * 3 or -dt * 6), 0, 1)

		-- breathing: calm when rested, ragged panting when out of stamina / after sprinting
		local stamina = attr(char, "Stamina") or 1
		local exertion = math.clamp((1 - stamina) * 1.4 + (speed > 12 and 0.4 or 0), 0, 1)
		st.Exertion = (st.Exertion or 0) + (exertion - (st.Exertion or 0)) * math.min(1, dt * 1.5)
		local rate = (role == "Wolverine" and 1.4 or 1.7) + st.Exertion * 5.5
		-- rage: he hunches lower and heaves, big ragged breaths he can't hold in
		local roaring = st.Clip ~= nil and st.Clip.Name == "RageRoar"
		local raging = role == "Wolverine" and attr(char, "Rage") == true and st.Loop ~= "Gallop" and not roaring
		st.RageBlend = math.clamp((st.RageBlend or 0) + (raging and dt * 2 or -dt * 1.5), 0, 1)
		rate *= 1 + st.RageBlend * 0.9
		local prevBreath = st.BreathPhase or 0
		st.BreathPhase = prevBreath + dt * rate
		local breathAmp = (role == "Wolverine" and 1.8 or 1) * (1 + st.Exertion * 1.6) * (1 + st.RageBlend * 1.4)
		if st.RageBlend > 0.5 and math.sin(prevBreath) > 0 and math.sin(st.BreathPhase) <= 0 then
			rageExhale(char)
		end

		local pose = {}
		if st.LoopBlend > 0 and st.Loop then
			local s, c = math.sin(st.Phase), math.cos(st.Phase)
			if st.Loop == "Gallop" then
				pose = gallopPose(st.Phase)
			elseif st.Loop == "Hunt" then
				pose = huntPose(s, c, attr(char, "RunBuild"))
			elseif st.Loop == "Prowl" then
				pose = prowlPose(s, c)
			elseif st.Loop == "Stomp" then
				pose = stompPose(sentinelWarp(st.Phase), st.Scale)
			elseif st.Loop == "Charge" then
				pose = chargePose(sentinelWarp(st.Phase), st.Scale)
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
		local idle = st.IdleBlend > 0 and (role == "Sentinel" and sentinelIdle(now) or predatorIdle(now)) or nil

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

		-- clips marked LegsWhenMoving (the death ray, the blast charge) keep the
		-- upper body in the clip but hand the legs to the walk when it moves
		local legsFree = clip ~= nil and clip.Def.LegsWhenMoving and st.LoopBlend > 0.25

		local breathPose = breath(st.BreathPhase, breathAmp)
		local hunch = st.RageBlend > 0.01 and rageHunch(st.RageBlend) or nil
		local layered = st.LoopBlend > 0 or st.IdleBlend > 0 or st.Clip ~= nil or hunch ~= nil
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
				if cp and legsFree and LEG_KEYS[key] then
					cp = nil
				end
				if cp then
					target = target:Lerp(cp, clipWeight)
				end
				local hp = hunch and hunch[key]
				if hp then
					target = hp * target -- leans the whole pose over, on top of whatever it's doing
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
