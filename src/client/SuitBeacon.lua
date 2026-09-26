-- When the last terminal is repaired (ReplicatedStorage SuitOnline turns
-- true) the docked Sentinel suits light up with an outline you can see
-- through every wall for 8 seconds (DURATION), so survivors can find
-- the Hangar from anywhere on the map. Wolverine doesn't get it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local DURATION = 8
local COLOR = Color3.fromRGB(196, 150, 255)

local current = nil

local function beacon()
	if player:GetAttribute("Role") == "Wolverine" then
		return
	end
	local map = workspace:FindFirstChild("Map")
	local pod = map and map:FindFirstChild("SentinelPod")
	local suits = pod and (pod:FindFirstChild("Dummy") or pod)
	if not suits then
		return
	end
	if current then
		current:Destroy()
	end
	local hl = Instance.new("Highlight")
	hl.Name = "SuitBeacon"
	hl.Adornee = suits
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.FillColor = COLOR
	hl.FillTransparency = 0.72
	hl.OutlineColor = COLOR
	hl.OutlineTransparency = 0
	hl.Parent = workspace
	current = hl
	-- a slow pulse, then it fades out over the last second
	task.spawn(function()
		local t0 = os.clock()
		while hl.Parent and os.clock() - t0 < DURATION - 1 do
			local k = (math.sin((os.clock() - t0) * 4) + 1) / 2
			hl.FillTransparency = 0.6 + k * 0.25
			task.wait()
		end
		if hl.Parent then
			TweenService:Create(hl, TweenInfo.new(1), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
			task.wait(1)
			hl:Destroy()
		end
		if current == hl then
			current = nil
		end
	end)
end

ReplicatedStorage:GetAttributeChangedSignal("SuitOnline"):Connect(function()
	if ReplicatedStorage:GetAttribute("SuitOnline") == true then
		beacon()
	elseif current then
		current:Destroy()
		current = nil
	end
end)

return {}
