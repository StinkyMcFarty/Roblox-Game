-- Sentinel targeting: while you pilot a Sentinel and Wolverine is more than
-- RANGE studs away, his outline shows through walls so you can hunt him down.
-- It switches off once you're within RANGE of him.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local RANGE = 50 -- studs
local COLOR = Color3.fromRGB(255, 40, 200) -- the death ray's magenta

local hl = Instance.new("Highlight")
hl.Name = "SentinelTracker"
hl.FillColor = COLOR
hl.FillTransparency = 0.8
hl.OutlineColor = COLOR
hl.OutlineTransparency = 0
hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
hl.Enabled = false

task.spawn(function()
	while true do
		task.wait(0.2)
		local name = ReplicatedStorage:GetAttribute("Wolverine")
		local w = name and Players:FindFirstChild(name)
		local wChar = w and w.Character
		local wRoot = wChar and wChar:FindFirstChild("HumanoidRootPart")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local show = player:GetAttribute("Role") == "Sentinel"
			and wRoot ~= nil
			and root ~= nil
			and (wRoot.Position - root.Position).Magnitude > RANGE
		if show then
			hl.Adornee = wChar
			hl.Parent = workspace -- not the camera: Highlights in there may not draw live
		end
		hl.Enabled = show
	end
end)

return {}
