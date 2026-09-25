-- A soft white glow on the hiding spots near you, so survivors can spot
-- somewhere to hide. Only survivors see it, and every spot glows the same
-- whether or not someone is inside. Only the nearest few glow: the client
-- draws a limited number of Highlights at once, and Sniff needs some too.
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local RANGE = 60 -- studs
local MAX_GLOWS = 6
local WHITE = Color3.new(1, 1, 1)

local glows = {} -- [spot Model] = Highlight

local function glowFor(spot)
	local hl = glows[spot]
	if not (hl and hl.Parent) then
		hl = Instance.new("Highlight")
		hl.Name = "HideGlow"
		hl.FillColor = WHITE
		hl.FillTransparency = 0.85
		hl.OutlineColor = WHITE
		hl.OutlineTransparency = 0.25
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Adornee = spot
		hl.Parent = spot
		glows[spot] = hl
	end
	return hl
end

local function clearAll()
	for spot, hl in glows do
		hl:Destroy()
		glows[spot] = nil
	end
end

task.spawn(function()
	while true do
		task.wait(0.25)
		local map = workspace:FindFirstChild("Map")
		local folder = map and map:FindFirstChild("HidingSpots")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (folder and root and player:GetAttribute("Role") == "Survivor") then
			clearAll()
			continue
		end
		local near = {}
		for _, spot in folder:GetChildren() do
			local inside = spot:FindFirstChild("Inside")
			if spot:IsA("Model") and inside then
				local d = (inside.Position - root.Position).Magnitude
				if d <= RANGE then
					table.insert(near, { Spot = spot, Dist = d })
				end
			end
		end
		table.sort(near, function(a, b)
			return a.Dist < b.Dist
		end)
		local keep = {}
		for i = 1, math.min(MAX_GLOWS, #near) do
			local spot = near[i].Spot
			keep[spot] = true
			glowFor(spot)
		end
		for spot, hl in glows do
			if not keep[spot] then
				hl:Destroy()
				glows[spot] = nil
			end
		end
	end
end)

return {}
