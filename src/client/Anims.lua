-- Procedural sprint animations, applied on every client to every sprinting
-- character. We override Motor6D.Transform after Roblox's Animator runs
-- (PreSimulation), so this fully replaces the default run while sprinting.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

local state = setmetatable({}, { __mode = "k" }) -- [Model] = { Phase, Blend, Motors, LookUntil, NextLook, LookSide }

local function motors(char)
	local m = {}
	for key, info in JOINTS do
		local part = char:FindFirstChild(info[1])
		local j = part and part:FindFirstChild(info[2])
		if j and j:IsA("Motor6D") then
			m[key] = j
		end
	end
	return m
end

local function isSprinting(char)
	if char:GetAttribute("Sprinting") then
		return true, char:GetAttribute("Role") or "Survivor"
	end
	local p = Players:GetPlayerFromCharacter(char)
	if p and p:GetAttribute("Sprinting") then
		return true, p:GetAttribute("Role")
	end
	return false, nil
end

local function wolverineNear(root)
	local name = ReplicatedStorage:GetAttribute("Wolverine")
	local w = name and Players:FindFirstChild(name)
	local wRoot = w and w.Character and w.Character:FindFirstChild("HumanoidRootPart")
	return wRoot ~= nil and (wRoot.Position - root.Position).Magnitude < 70
end

-- Survivor: running for their life.
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
		RWrist = CFrame.Angles(rad(10), 0, 0),
		LWrist = CFrame.Angles(rad(10), 0, 0),
		RHip = CFrame.Angles(rad(60 * s + 8), 0, 0),
		LHip = CFrame.Angles(rad(-60 * s + 8), 0, 0),
		RKnee = CFrame.Angles(rad(-(15 + 85 * math.max(0, -s))), 0, 0),
		LKnee = CFrame.Angles(rad(-(15 + 85 * math.max(0, s))), 0, 0),
		RAnkle = CFrame.Angles(rad(-20 * s), 0, 0),
		LAnkle = CFrame.Angles(rad(20 * s), 0, 0),
	}
end

-- Wolverine: low, heavy, claws forward, shoulders rolling.
local function huntPose(s, c)
	local up = math.abs(c)
	return {
		Root = CFrame.new(0, up * 0.18 - 0.25, 0) * CFrame.Angles(rad(-24), 0, 0),
		Waist = CFrame.Angles(rad(-10), rad(18 * s), 0),
		Neck = CFrame.Angles(rad(22), rad(-10 * s), 0),
		RShoulder = CFrame.Angles(rad(-55 * s + 35), 0, rad(18)),
		LShoulder = CFrame.Angles(rad(55 * s + 35), 0, rad(-18)),
		RElbow = CFrame.Angles(rad(45), 0, 0),
		LElbow = CFrame.Angles(rad(45), 0, 0),
		RWrist = CFrame.identity,
		LWrist = CFrame.identity,
		RHip = CFrame.Angles(rad(55 * s + 15), 0, 0),
		LHip = CFrame.Angles(rad(-55 * s + 15), 0, 0),
		RKnee = CFrame.Angles(rad(-(25 + 75 * math.max(0, -s))), 0, 0),
		LKnee = CFrame.Angles(rad(-(25 + 75 * math.max(0, s))), 0, 0),
		RAnkle = CFrame.Angles(rad(-15 * s), 0, 0),
		LAnkle = CFrame.Angles(rad(15 * s), 0, 0),
	}
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
			if m:IsA("Model") and m:GetAttribute("Sprinting") ~= nil then
				table.insert(list, m)
			end
		end
	end
	return list
end

local step = RunService.PreSimulation or RunService.Stepped
step:Connect(function(a, b)
	local dt = typeof(b) == "number" and b or a
	local now = os.clock()
	for _, char in characters() do
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 and hum.RigType == Enum.HumanoidRigType.R15 then
			local st = state[char]
			local sprinting, role = isSprinting(char)
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local feral = role == "Wolverine" and (Players:GetPlayerFromCharacter(char) or char):GetAttribute("Feral")
			local active = sprinting and speed > 8 and not root.Anchored and not feral
				and hum:GetState() ~= Enum.HumanoidStateType.Freefall

			if active and not st then
				st = { Phase = 0, Blend = 0, Motors = motors(char), LookUntil = 0, NextLook = now + 1.5, LookSide = 1 }
				state[char] = st
			end
			if st then
				st.Blend = math.clamp(st.Blend + (active and dt * 8 or -dt * 8), 0, 1)
				if st.Blend <= 0 and not active then
					state[char] = nil
				else
					st.Phase += dt * math.max(speed, 10) * 0.52
					local s, c = math.sin(st.Phase), math.cos(st.Phase)
					local pose
					if role == "Wolverine" then
						pose = huntPose(s, c)
					else
						-- Panicked glances back when he's close
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
					for key, cf in pose do
						local m = st.Motors[key]
						if m and m.Parent then
							m.Transform = m.Transform:Lerp(cf, st.Blend)
						end
					end
				end
			end
		end
	end
end)

return Anims
