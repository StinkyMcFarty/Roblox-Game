-- Hiding spots (lockers, wardrobes, dumpsters, freezer). Hidden survivors are
-- invisible, but Wolverine's Sniff still shows the spot, and clawing it or
-- smashing it drags them out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(ReplicatedStorage.Shared.Util)
local Round = require(script.Parent.Round)

local Hiding = {}

local occupantOf = {} -- [Model] = Player
local spotOf = {} -- [Player] = Model
local saved = {} -- [Player] = { [Instance] = transparency }

local function setVisible(player, char, visible)
	if visible then
		for inst, t in saved[player] or {} do
			if inst.Parent then
				inst.Transparency = t
			end
		end
		saved[player] = nil
	else
		local store = {}
		for _, d in char:GetDescendants() do
			if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
				store[d] = d.Transparency
				d.Transparency = 1
			end
		end
		saved[player] = store
	end
	local hum = Util.Humanoid(char)
	if hum then
		hum.DisplayDistanceType = visible and Enum.HumanoidDisplayDistanceType.Viewer or Enum.HumanoidDisplayDistanceType.None
	end
end

local function prompt(spot)
	return spot:FindFirstChild("HidePrompt", true)
end

function Hiding.IsHidden(player)
	return spotOf[player] ~= nil
end

function Hiding.SpotOf(player)
	return spotOf[player]
end

function Hiding.Leave(player, ejected)
	local spot = spotOf[player]
	if not spot then
		return
	end
	spotOf[player] = nil
	occupantOf[spot] = nil
	player:SetAttribute("Hidden", false)
	local p = prompt(spot)
	if p then
		p.ActionText = "Hide"
	end
	local char = player.Character
	local root = Util.Root(char)
	if char then
		setVisible(player, char, true)
	end
	if root then
		local exit = spot:FindFirstChild("Exit")
		root.Anchored = false
		if exit then
			root.CFrame = exit.CFrame + Vector3.new(0, 3, 0)
		end
		if ejected then
			root.AssemblyLinearVelocity = Vector3.new(0, 20, 0)
		end
	end
end

function Hiding.Enter(player, spot)
	if spotOf[player] or occupantOf[spot] then
		return
	end
	if player:GetAttribute("Role") ~= "Survivor" or not Round.Survivors[player] then
		return
	end
	local char = player.Character
	local root = Util.Root(char)
	local inside = spot:FindFirstChild("Inside")
	if not (root and inside and Util.IsAlive(char)) then
		return
	end
	spotOf[player] = spot
	occupantOf[spot] = player
	player:SetAttribute("Hidden", true)
	local p = prompt(spot)
	if p then
		p.ActionText = "Leave"
	end
	root.Anchored = true
	root.CFrame = inside.CFrame
	setVisible(player, char, false)
end

function Hiding.SetupRound(map)
	for player in spotOf do
		Hiding.Leave(player)
	end
	occupantOf, spotOf = {}, {}
	local folder = map:FindFirstChild("HidingSpots")
	if not folder then
		return
	end
	for _, spot in folder:GetChildren() do
		local p = prompt(spot)
		if p then
			p.Triggered:Connect(function(player)
				if occupantOf[spot] == player then
					Hiding.Leave(player)
				elseif not occupantOf[spot] then
					Hiding.Enter(player, spot)
				end
			end)
		end
		-- Smashing the spot throws whoever is inside out
		for _, part in spot:GetDescendants() do
			if part:IsA("BasePart") and part:GetAttribute("Breakable") then
				part.Destroying:Connect(function()
					local who = occupantOf[spot]
					if who then
						Hiding.Leave(who, true)
					end
				end)
			end
		end
	end
end

function Hiding.Clear(player)
	if spotOf[player] then
		Hiding.Leave(player)
	end
	saved[player] = nil
end

return Hiding
