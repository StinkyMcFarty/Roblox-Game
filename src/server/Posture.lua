-- Code-driven "animations": offsets Motor6D.C0 on R15 rigs so no animation
-- assets need uploading. Default walk/run animations still play on top.
local TweenService = game:GetService("TweenService")

local Posture = {}

local MOTORS = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
	RShoulder = { "RightUpperArm", "RightShoulder" },
	LShoulder = { "LeftUpperArm", "LeftShoulder" },
	RHip = { "RightUpperLeg", "RightHip" },
	LHip = { "LeftUpperLeg", "LeftHip" },
	-- (the lobby statues pose these too)
	RElbow = { "RightLowerArm", "RightElbow" },
	LElbow = { "LeftLowerArm", "LeftElbow" },
	RWrist = { "RightHand", "RightWrist" },
	LWrist = { "LeftHand", "LeftWrist" },
	RKnee = { "RightLowerLeg", "RightKnee" },
	LKnee = { "LeftLowerLeg", "LeftKnee" },
}

local originals = setmetatable({}, { __mode = "k" }) -- [Motor6D] = CFrame
local bases = setmetatable({}, { __mode = "k" }) -- [Model] = { [key] = CFrame }

local function getMotor(char, key)
	local info = MOTORS[key]
	local part = char and char:FindFirstChild(info[1])
	local motor = part and part:FindFirstChild(info[2])
	if motor and motor:IsA("Motor6D") then
		if not originals[motor] then
			originals[motor] = motor.C0
		end
		return motor
	end
	return nil
end

function Posture.Set(char, key, offset, duration)
	local motor = getMotor(char, key)
	if not motor then
		return
	end
	local goal = originals[motor] * offset
	if duration and duration > 0 then
		TweenService:Create(
			motor,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ C0 = goal }
		):Play()
	else
		motor.C0 = goal
	end
end

-- The resting pose a motor returns to (used by the all-fours run).
function Posture.SetBase(char, key, offset, duration)
	bases[char] = bases[char] or {}
	bases[char][key] = offset
	Posture.Set(char, key, offset, duration)
end

function Posture.Restore(char, key, duration)
	local b = bases[char]
	Posture.Set(char, key, (b and b[key]) or CFrame.identity, duration)
end

function Posture.RestoreAll(char, duration)
	for key in MOTORS do
		Posture.Restore(char, key, duration)
	end
end

-- Call BEFORE Model:ScaleTo so cached joint offsets don't go stale.
function Posture.Forget(char)
	for key in MOTORS do
		local info = MOTORS[key]
		local part = char:FindFirstChild(info[1])
		local motor = part and part:FindFirstChild(info[2])
		if motor and originals[motor] then
			motor.C0 = originals[motor]
			originals[motor] = nil
		end
	end
	bases[char] = nil
end

function Posture.Feral(char, on)
	local t = 0.18
	if on then
		Posture.SetBase(char, "Root", CFrame.new(0, -0.3, 0) * CFrame.Angles(math.rad(-68), 0, 0), t)
		Posture.SetBase(char, "Neck", CFrame.Angles(math.rad(55), 0, 0), t)
		Posture.SetBase(char, "RShoulder", CFrame.Angles(math.rad(78), 0, 0), t)
		Posture.SetBase(char, "LShoulder", CFrame.Angles(math.rad(78), 0, 0), t)
		Posture.SetBase(char, "RHip", CFrame.Angles(math.rad(60), 0, 0), t)
		Posture.SetBase(char, "LHip", CFrame.Angles(math.rad(60), 0, 0), t)
	else
		for _, key in { "Root", "Neck", "RShoulder", "LShoulder", "RHip", "LHip" } do
			Posture.SetBase(char, key, CFrame.identity, t)
		end
	end
end

-- Quick claw swipe with one arm ("R" or "L").
function Posture.Swipe(char, side)
	local key = side == "R" and "RShoulder" or "LShoulder"
	local s = side == "R" and 1 or -1
	Posture.Set(char, key, CFrame.Angles(math.rad(150), 0, math.rad(25 * s)), 0.05)
	task.delay(0.05, function()
		Posture.Set(char, key, CFrame.Angles(math.rad(60), 0, math.rad(-40 * s)), 0.1)
		task.delay(0.14, function()
			Posture.Restore(char, key, 0.2)
		end)
	end)
end

function Posture.ArmsForward(char, duration)
	Posture.Set(char, "RShoulder", CFrame.Angles(math.rad(92), 0, math.rad(-8)), duration)
	Posture.Set(char, "LShoulder", CFrame.Angles(math.rad(92), 0, math.rad(8)), duration)
end

function Posture.Roar(char)
	Posture.Set(char, "Neck", CFrame.Angles(math.rad(35), 0, 0), 0.25)
	Posture.Set(char, "Waist", CFrame.Angles(math.rad(15), 0, 0), 0.25)
	Posture.Set(char, "RShoulder", CFrame.Angles(math.rad(20), 0, math.rad(75)), 0.25)
	Posture.Set(char, "LShoulder", CFrame.Angles(math.rad(20), 0, math.rad(-75)), 0.25)
end

return Posture
