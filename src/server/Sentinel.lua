-- The counter (like the Hulkbuster): survivors reboot 3 Sentinel terminals,
-- then ONE survivor can climb into the Sentinel suit. It can stun and hurt
-- Wolverine, but his healing factor means it only wins with help and
-- good timing. The suit powers down after Config.Sentinel.Duration seconds,
-- and Wolverine can still rip it apart.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Round = require(script.Parent.Round)
local Status = require(script.Parent.Status)
local Posture = require(script.Parent.Posture)
local Wolverine = require(script.Parent.Wolverine)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local Skins = require(ReplicatedStorage.Shared.Skins)

local Fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx")

local Sentinel = {}

local PURPLE = Color3.fromRGB(120, 40, 170)
local GREY = Color3.fromRGB(120, 124, 132)
local GLOW = Color3.fromRGB(255, 210, 60)

local cooldowns = {}
local suitsLeft = 0
local links = {} -- [Player] = Beam

local function announce(text, color)
	Fx:FireAllClients("Announce", { Text = text, Color = color or PURPLE, Duration = 3 })
end

---------------------------------------------------------------------------
-- Terminals & pod
---------------------------------------------------------------------------

local function unlockPod(pod)
	local prompt = pod:FindFirstChild("PodPrompt", true)
	if prompt then
		prompt.Enabled = true
	end
	local beacon = pod:FindFirstChild("Beacon")
	if beacon then
		TweenService:Create(beacon, TweenInfo.new(1), { Transparency = 0.55 }):Play()
	end
	local light = pod:FindFirstChild("PodLight", true)
	if light then
		light.Brightness = 4
		light.Range = 30
	end
	announce("SENTINEL SUIT ONLINE — get to the container yard!", GLOW)
end

function Sentinel.SetupRound(map)
	suitsLeft = Config.Sentinel.Suits
	cooldowns = {}
	local terminals = map:FindFirstChild("Terminals")
	local pod = map:FindFirstChild("SentinelPod")
	local total = terminals and #terminals:GetChildren() or 0
	local done = 0
	ReplicatedStorage:SetAttribute("Terminals", 0)
	ReplicatedStorage:SetAttribute("TerminalsTotal", total)
	ReplicatedStorage:SetAttribute("SuitOnline", false)

	if terminals then
		for _, term in terminals:GetChildren() do
			local prompt = term:FindFirstChild("TerminalPrompt", true)
			if prompt then
				prompt.HoldDuration = Config.Sentinel.HoldTime
				prompt.Triggered:Connect(function(player)
					if term:GetAttribute("Done") or not Round.Active then
						return
					end
					if player:GetAttribute("Role") ~= "Survivor" or not Round.Survivors[player] then
						return
					end
					term:SetAttribute("Done", true)
					prompt.Enabled = false
					local screen = term:FindFirstChild("Screen")
					if screen then
						screen.Color = Color3.fromRGB(60, 255, 120)
						local light = screen:FindFirstChildOfClass("PointLight")
						if light then
							light.Color = screen.Color
						end
						local label = screen:FindFirstChild("Label", true)
						if label then
							label.Text = "ONLINE"
						end
						Util.Sound(Config.Sounds.Terminal, screen, { Volume = 1.5, Range = 120 })
					end
					done += 1
					PlayerData.AddCoins(player, Skins.Rewards.Terminal, "Rebooted a terminal")
					ReplicatedStorage:SetAttribute("Terminals", done)
					announce(("%s rebooted a terminal (%d/%d)"):format(player.DisplayName, done, total), GLOW)
					if done >= total and pod then
						ReplicatedStorage:SetAttribute("SuitOnline", true)
						unlockPod(pod)
					end
				end)
			end
		end
	end

	if pod then
		local prompt = pod:FindFirstChild("PodPrompt", true)
		if prompt then
			prompt.HoldDuration = Config.Sentinel.PodHoldTime
			prompt.Triggered:Connect(function(player)
				if suitsLeft <= 0 or not Round.Active then
					return
				end
				if player:GetAttribute("Role") ~= "Survivor" or not Round.Survivors[player] then
					return
				end
				suitsLeft -= 1
				prompt.ObjectText = ("Sentinel Pod (%d left)"):format(suitsLeft)
				if suitsLeft <= 0 then
					prompt.Enabled = false
					local beacon = pod:FindFirstChild("Beacon")
					if beacon then
						beacon.Transparency = 1
					end
					local dummy = pod:FindFirstChild("Dummy")
					if dummy then
						dummy:Destroy()
					end
				end
				Sentinel.Become(player)
			end)
		end
	end
end

---------------------------------------------------------------------------
-- Suit up / power down
---------------------------------------------------------------------------

local function gear(char, anchor, size, color, material, offset)
	local folder = char:FindFirstChild("SentinelGear")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SentinelGear"
		folder.Parent = char
	end
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = anchor.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = anchor
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	p.Parent = folder
	return p
end

function Sentinel.Become(player)
	local char = player.Character
	local hum, root = Util.Humanoid(char), Util.Root(char)
	if not (hum and root) then
		return
	end
	player:SetAttribute("Role", "Sentinel")
	player:SetAttribute("Armor", Config.Sentinel.Armor)
	player:SetAttribute("SuitEnds", workspace:GetServerTimeNow() + Config.Sentinel.Duration)
	cooldowns[player] = {}

	for _, d in char:GetChildren() do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("Accessory") then
			d:Destroy()
		end
	end
	for _, p in char:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.Color = (p.Name:find("Hand") or p.Name:find("Foot") or p.Name:find("Lower")) and GREY or PURPLE
			p.Material = Enum.Material.Metal
		end
	end
	Posture.Forget(char)
	pcall(function()
		char:ScaleTo(Config.Sentinel.Scale)
	end)

	local head = char:FindFirstChild("Head")
	if head then
		local hs = head.Size
		gear(char, head, hs * 1.12, PURPLE, nil, CFrame.new(0, 0.05, 0))
		gear(char, head, Vector3.new(hs.X * 0.8, hs.Y * 0.14, 0.05), GLOW, Enum.Material.Neon, CFrame.new(0, hs.Y * 0.08, -hs.Z * 0.57))
	end
	local torso = Util.Torso(char)
	if torso then
		local ts = torso.Size
		gear(char, torso, Vector3.new(ts.X * 0.35, ts.Y * 0.3, 0.1), GLOW, Enum.Material.Neon, CFrame.new(0, ts.Y * 0.1, -ts.Z * 0.55))
		gear(char, torso, Vector3.new(ts.X * 1.5, ts.Y * 0.35, ts.Z * 1.1), GREY, nil, CFrame.new(0, ts.Y * 0.4, 0))
	end

	hum.MaxHealth = 100
	hum.Health = 100
	Util.Burst(root, Util.SparkProps, 40, 2)
	Util.Sound(Config.Sounds.Terminal, root, { Volume = 2, Pitch = 0.6, Range = 300 })
	announce(player.DisplayName .. " suited up as a SENTINEL! Stay together to link up.", GLOW)
	Fx:FireAllClients("Shake", { Position = root.Position, Intensity = 0.6, Radius = 80 })

	task.delay(Config.Sentinel.Duration, function()
		if player:GetAttribute("Role") == "Sentinel" and player.Character == char and Util.IsAlive(char) then
			Sentinel.PowerDown(player)
		end
	end)
end

function Sentinel.PowerDown(player)
	local char = player.Character
	if not char then
		return
	end
	player:SetAttribute("Role", "Survivor")
	player:SetAttribute("Armor", nil)
	player:SetAttribute("SuitEnds", nil)
	local folder = char:FindFirstChild("SentinelGear")
	if folder then
		folder:Destroy()
	end
	Posture.Forget(char)
	pcall(function()
		char:ScaleTo(1)
	end)
	for _, p in char:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.Color = GREY
		end
	end
	local hum = Util.Humanoid(char)
	if hum then
		hum.Health = hum.MaxHealth * math.max(0.05, 1 - (player:GetAttribute("Hits") or 0) / Config.HitsToKill)
	end
	Fx:FireClient(player, "Announce", { Text = "Suit powered down. RUN.", Color = Color3.fromRGB(255, 80, 80), Duration = 2.5 })
end

---------------------------------------------------------------------------
-- Suit abilities
---------------------------------------------------------------------------

local function wolverineParts()
	local w = Round.Wolverine
	local char = w and w.Character
	return w, char, Util.Root(char)
end

local function sentinels()
	local list = {}
	for p in Round.Survivors do
		if p:GetAttribute("Role") == "Sentinel" and Util.IsAlive(p.Character) then
			table.insert(list, p)
		end
	end
	return list
end

local function isLinked(player)
	local root = Util.Root(player.Character)
	if not root then
		return false
	end
	for _, other in sentinels() do
		local r = Util.Root(other.Character)
		if other ~= player and r and (r.Position - root.Position).Magnitude <= Config.Sentinel.LinkRange then
			return true
		end
	end
	return false
end

local function power(player)
	return isLinked(player) and Config.Sentinel.LinkedMultiplier or Config.Sentinel.SoloMultiplier
end

-- Energy tether between linked suits + "Linked" attribute for the HUD
RunService.Heartbeat:Connect(function()
	for p, beam in links do
		if not (p.Parent and p:GetAttribute("Role") == "Sentinel") then
			beam:Destroy()
			links[p] = nil
		end
	end
	local list = sentinels()
	for _, p in list do
		local linked = isLinked(p)
		if p:GetAttribute("Linked") ~= linked then
			p:SetAttribute("Linked", linked)
		end
	end
	if #list >= 2 then
		local a, b = list[1], list[2]
		local ta, tb = Util.Torso(a.Character), Util.Torso(b.Character)
		local beam = links[a]
		if ta and tb and isLinked(a) then
			if not beam then
				local att0 = Instance.new("Attachment")
				att0.Name = "LinkAtt"
				att0.Parent = ta
				local att1 = Instance.new("Attachment")
				att1.Name = "LinkAtt"
				att1.Parent = tb
				beam = Instance.new("Beam")
				beam.Attachment0 = att0
				beam.Attachment1 = att1
				beam.Color = ColorSequence.new(Color3.fromRGB(200, 120, 255), Color3.fromRGB(255, 210, 60))
				beam.LightEmission = 1
				beam.Width0 = 0.6
				beam.Width1 = 0.6
				beam.CurveSize0 = 2
				beam.CurveSize1 = -2
				beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				beam.TextureSpeed = 3
				beam.Transparency = NumberSequence.new(0.2)
				beam.FaceCamera = true
				beam.Parent = ta
				links[a] = beam
			end
		elseif beam then
			beam:Destroy()
			links[a] = nil
		end
	end
end)

local function stunWolverine(duration)
	local w = Round.Wolverine
	if w then
		Status.Apply(w, "Stunned", duration)
		Fx:FireAllClients("Stunned", { Name = w.Name, Duration = duration })
	end
end

local function punch(player, char, root)
	local cfg = Config.Sentinel.Punch
	Posture.Set(char, "RShoulder", CFrame.Angles(math.rad(95), 0, 0), 0.06)
	task.delay(0.2, function()
		Posture.Restore(char, "RShoulder", 0.2)
	end)
	local w, _, wRoot = wolverineParts()
	if not wRoot then
		return
	end
	local rel = root.CFrame:PointToObjectSpace(wRoot.Position)
	if rel.Z < 1 and rel.Z > -cfg.Range and math.abs(rel.X) < 5 and math.abs(rel.Y) < 6 then
		local mult = power(player)
		Wolverine.Damage(cfg.Damage * mult)
		stunWolverine(cfg.Stun * mult)
		local dir = Util.Flat(wRoot.Position - root.Position)
		Fx:FireClient(w, "Knock", { Velocity = dir * cfg.Knockback + Vector3.new(0, 25, 0) })
		Util.Sound(Config.Sounds.Punch, wRoot, { Volume = 2, Pitch = 0.6 })
		Fx:FireAllClients("Shake", { Position = wRoot.Position, Intensity = 0.6, Radius = 40 })
	else
		Util.Sound(Config.Sounds.Lunge, root, { Pitch = 0.5 })
	end
end

local function beamSegment(from, to, width, color, transparency)
	local len = (to - from).Magnitude
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Size = Vector3.new(len, width, width)
	p.CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0)
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Size = Vector3.new(len, 0.05, 0.05),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, 0.4)
	return p
end

-- Hitscan chest laser. Burns through a few breakable walls on the way.
local function laser(player, char, root, aim)
	local cfg = Config.Sentinel.Laser
	local torso = Util.Torso(char) or root
	local origin = torso.Position + root.CFrame.LookVector * 1.8
	local dir = root.CFrame.LookVector
	if typeof(aim) == "Vector3" and (aim - origin).Magnitude > 2 then
		dir = (aim - origin).Unit
		-- Don't allow shooting backwards
		if dir:Dot(root.CFrame.LookVector) < -0.2 then
			dir = root.CFrame.LookVector
		end
	end

	Posture.ArmsForward(char, 0.05)
	task.delay(0.35, function()
		Posture.RestoreAll(char, 0.2)
	end)
	Util.Sound(Config.Sounds.Laser, root, { Volume = 2, Pitch = 0.4, Range = 250 })
	Util.Burst(origin, Util.SparkProps, 20, 1)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { char }
	local from = origin
	local remaining = cfg.Range
	local burned = 0
	local endPos = origin + dir * cfg.Range
	local _, wChar = wolverineParts()

	while remaining > 0 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(from, dir * remaining, params)
		if not hit then
			break
		end
		if wChar and hit.Instance:IsDescendantOf(wChar) then
			endPos = hit.Position
			Wolverine.Damage(cfg.Damage * power(player))
			Wolverine.RevealSkeleton()
			Status.Apply(Round.Wolverine, "Slowed", cfg.Slow)
			Fx:FireAllClients("Shake", { Position = hit.Position, Intensity = 0.5, Radius = 40 })
			break
		end
		if hit.Instance:GetAttribute("Breakable") and burned < cfg.WallsBurned then
			burned += 1
			Combat.BreakPart(hit.Instance, hit.Position - dir * 3, 25)
			Util.Burst(hit.Position, Util.SparkProps, 25, 1.5)
			remaining -= (hit.Position - from).Magnitude
			from = hit.Position
		else
			endPos = hit.Position
			Util.Burst(hit.Position, Util.SparkProps, 25, 1.5)
			break
		end
	end

	-- Hot core + wide glow
	beamSegment(origin, endPos, 0.5, Color3.fromRGB(255, 250, 220), 0)
	beamSegment(origin, endPos, 1.6, Color3.fromRGB(255, 60, 40), 0.55)
end

local function pulse(player, char, root)
	local cfg = Config.Sentinel.Pulse
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Ball
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.ForceField
	ring.Color = GLOW
	ring.Size = Vector3.one * 2
	ring.Position = root.Position
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.35), { Size = Vector3.one * cfg.Radius * 2, Transparency = 0.6 }):Play()
	Debris:AddItem(ring, 0.5)
	Util.Sound(Config.Sounds.Laser, root, { Volume = 2, Pitch = 0.3, Range = 200 })
	Fx:FireAllClients("Shake", { Position = root.Position, Intensity = 0.8, Radius = 50 })
	local _, _, wRoot = wolverineParts()
	if wRoot and (wRoot.Position - root.Position).Magnitude <= cfg.Radius then
		local mult = power(player)
		Wolverine.Damage(cfg.Damage * mult)
		stunWolverine(cfg.Stun * mult)
	end
end

function Sentinel.Handle(player, ability, arg)
	if player:GetAttribute("Role") ~= "Sentinel" or not Round.Active then
		return
	end
	local char = player.Character
	local root = Util.Root(char)
	if not (root and Util.IsAlive(char)) or Status.Has(player, "Busy") or Status.Has(player, "Frozen") then
		return
	end
	local cfg = Config.Sentinel[ability]
	if type(cfg) ~= "table" or not cfg.Cooldown then
		return
	end
	local cd = cooldowns[player]
	if not cd then
		cd = {}
		cooldowns[player] = cd
	end
	if (cd[ability] or 0) > os.clock() then
		return
	end
	cd[ability] = os.clock() + cfg.Cooldown - 0.1

	if ability == "Punch" then
		punch(player, char, root)
	elseif ability == "Laser" then
		laser(player, char, root, arg)
	elseif ability == "Pulse" then
		pulse(player, char, root)
	end
end

return Sentinel
