-- Pins one character to another on this screen every frame (server/Ride.lua):
-- Wolverine clinging to a Sentinel's back, or held up in its fist. The server
-- keeps its own anchored copy in place for hits; pinning it here, just before
-- the camera, keeps it stuck to the suit smoothly however the suit moves.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Effects = require(script.Parent:WaitForChild("Effects"))

local player = Players.LocalPlayer
local Fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx")
local pins = {} -- [char] = { To = char, Offset = CFrame }

Fx.OnClientEvent:Connect(function(kind, data)
	if kind ~= "Glue" or type(data) ~= "table" or typeof(data.Char) ~= "Instance" then
		return
	end
	if typeof(data.To) == "Instance" and typeof(data.Offset) == "CFrame" then
		pins[data.Char] = { To = data.To, Offset = data.Offset }
		if data.Char == player.Character then
			Effects.CancelLeap() -- caught mid-pounce: the dive stops here
		end
	else
		pins[data.Char] = nil
	end
end)

RunService:BindToRenderStep("Glue", Enum.RenderPriority.Camera.Value - 1, function()
	for char, pin in pins do
		local root = char.Parent and char:FindFirstChild("HumanoidRootPart")
		local to = pin.To.Parent and pin.To:FindFirstChild("HumanoidRootPart")
		if root and to and root.Anchored then
			root.CFrame = to.CFrame * pin.Offset
		elseif not (root and to) then
			pins[char] = nil
		end
	end
end)

return {}
