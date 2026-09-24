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
local Costumes = require(script.Parent.Costumes)
local VFX = require(script.Parent.VFX)
local PlayerData = require(script.Parent.PlayerData)
local Skins = require(ReplicatedStorage.Shared.Skins)

local Fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx")

local Sentinel = {}

local PURPLE = Color3.fromRGB(120, 40, 170)
local GREY = Color3.fromRGB(120, 124, 132)
local GLOW = Color3.fromRGB(255, 210, 60)

local cooldowns = {}
local repairStart, repairLock = {}, {}
local finishTerminal = nil
local CHALLENGE_NAMES = { Calibrate = "Recalibrate", Wires = "Reroute Power", Sequence = "Override Code", Frequency = "Tune Frequency", Pressure = "Balance Pressure" }
local suitsLeft = 0
local links = {} -- [Player] = Beam

local function announce(text, color)
	Fx:FireAllClients("Announce", { Text = text, Color = color or PURPLE, Duration = 3 })
end

---------------------------------------------------------------------------
-- Terminals & pod
---------------------------------------------------------------------------

local function unlockPod(pod)
	for _, prompt in pod:GetDescendants() do
		if prompt.Name == "PodPrompt" and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = true
		end
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
	announce("SENTINEL PROTOCOL ONLINE — get to the Sentinel Hangar!", GLOW)
end

function Sentinel.SetupRound(map)
	suitsLeft = Config.Sentinel.Suits
	cooldowns = {}
	repairStart, repairLock = {}, {}
	for _, p in game:GetService("Players"):GetPlayers() do
		p:SetAttribute("Repairing", nil)
	end
	local terminals = map:FindFirstChild("Terminals")
	local pod = map:FindFirstChild("SentinelPod")
	local total = terminals and #terminals:GetChildren() or 0
	local done = 0
	ReplicatedStorage:SetAttribute("Terminals", 0)
	ReplicatedStorage:SetAttribute("TerminalsTotal", total)
	ReplicatedStorage:SetAttribute("SuitOnline", false)

	-- terminals: pressing E opens that console's repair minigame on the client;
	-- the result comes back through Sentinel.TerminalResult
	finishTerminal = function(term, player)
		term:SetAttribute("Done", true)
		local prompt = term:FindFirstChild("TerminalPrompt", true)
		if prompt then
			prompt.Enabled = false
		end
		local finder = term:FindFirstChild("Finder")
		if finder then
			finder:Destroy()
		end
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
	end
	if terminals then
		for _, term in terminals:GetChildren() do
			local prompt = term:FindFirstChild("TerminalPrompt", true)
			if prompt then
				prompt.ObjectText = "Sentinel Protocol — " .. (CHALLENGE_NAMES[term:GetAttribute("Challenge")] or "Repair")
				prompt.Triggered:Connect(function(player)
					if term:GetAttribute("Done") or not Round.Active then
						return
					end
					if player:GetAttribute("Role") ~= "Survivor" or not Round.Survivors[player] then
						return
					end
					if player:GetAttribute("Repairing") or (repairLock[player] or 0) > os.clock() then
						return
					end
					player:SetAttribute("Repairing", term.Name)
					repairStart[player] = os.clock()
					Fx:FireClient(player, "Minigame", { Terminal = term, Challenge = term:GetAttribute("Challenge") })
				end)
			end
		end
	end

	if pod then
		-- each docked suit has its own prompt: press E and step into that suit
		for _, prompt in pod:GetDescendants() do
			if not (prompt.Name == "PodPrompt" and prompt:IsA("ProximityPrompt")) then
				continue
			end
			prompt.HoldDuration = Config.Sentinel.PodHoldTime
			prompt.Triggered:Connect(function(player)
				if suitsLeft <= 0 or not Round.Active or not prompt.Enabled then
					return
				end
				if player:GetAttribute("Role") ~= "Survivor" or not Round.Survivors[player] then
					return
				end
				suitsLeft -= 1
				prompt.Enabled = false
				local statue = prompt:FindFirstAncestor("SentinelStatue")
				local spot = statue and statue:GetPivot()
				if statue then
					statue:Destroy()
				end
				if suitsLeft <= 0 then
					local beacon = pod:FindFirstChild("Beacon")
					if beacon then
						beacon.Transparency = 1
					end
				end
				Sentinel.Become(player)
				local char = player.Character
				if spot and char then
					char:PivotTo(CFrame.new(spot.Position + Vector3.new(0, 2, -4)) * spot.Rotation)
				end
			end)
		end
	end
end

-- Result of a repair minigame from the client. Validated: still a survivor,
-- still at that console, and it took a believable amount of time.
function Sentinel.TerminalResult(player, data)
	if type(data) ~= "table" then
		return
	end
	local term = data.Terminal
	local started = repairStart[player]
	if player:GetAttribute("Repairing") == nil then
		return
	end
	local name = player:GetAttribute("Repairing")
	player:SetAttribute("Repairing", nil)
	repairStart[player] = nil
	if typeof(term) ~= "Instance" or term.Name ~= name or not Round.Map or not term:IsDescendantOf(Round.Map) then
		return
	end
	if term:GetAttribute("Done") or not Round.Active or not Round.Survivors[player] then
		return
	end
	local root = Util.Root(player.Character)
	local body = term:FindFirstChild("Body")
	if not (root and body) or (root.Position - body.Position).Magnitude > 16 then
		return
	end
	if data.Cancel then
		return
	end
	if data.Ok == true and started and os.clock() - started >= 1.5 then
		finishTerminal(term, player)
	else
		-- botched repair: alarm, and Wolverine hears exactly where you are
		repairLock[player] = os.clock() + 4
		local screen = term:FindFirstChild("Screen")
		if screen then
			Util.Sound(Config.Sounds.Terminal, screen, { Volume = 3, Pitch = 0.5, Range = 300 })
			Util.Sound(Config.Sounds.Terminal, screen, { Volume = 3, Pitch = 0.45, Range = 300 })
		end
		Util.FireClient(Fx, Round.Wolverine, "Noise", { Position = body.Position, Text = "ALARM" })
		Util.FireClient(Fx, player, "Announce", { Text = "REPAIR FAILED — ALARM TRIPPED", Color = Color3.fromRGB(255, 70, 60), Duration = 2.5 })
	end
end

---------------------------------------------------------------------------
-- Suit up / power down
---------------------------------------------------------------------------

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

	Posture.Forget(char)
	pcall(function()
		char:ScaleTo(Config.Sentinel.Scale)
	end)
	Costumes.DressSentinel(char)

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
			local face = p:FindFirstChildOfClass("Decal")
			if face then
				face.Transparency = 0
			end
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
	if isLinked(player) then
		return Config.Sentinel.LinkedMultiplier
	end
	-- the last suit standing fights at full strength
	return #sentinels() <= 1 and 1 or Config.Sentinel.SoloMultiplier
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
	VFX.Anim(char, "Punch")
	task.wait(0.12) -- connect on the punch frame
	local w, _, wRoot = wolverineParts()
	local fist = root.CFrame * CFrame.new(0, 0.5, -3.2)
	local hit = false
	if wRoot then
		local box = root.CFrame * CFrame.new(0, 0, -cfg.Range / 2 + 0.5)
		local bcf, bsize = Combat.BodyBox(wRoot)
		if Combat.BoxOverlap(box, Vector3.new(9, 11, cfg.Range + 1), bcf, bsize) then
			hit = true
			local mult = power(player)
			Wolverine.Damage(cfg.Damage * mult)
			stunWolverine(cfg.Stun * mult)
			local dir = Util.Flat(wRoot.Position - root.Position)
			Fx:FireClient(w, "Knock", { Velocity = dir * cfg.Knockback + Vector3.new(0, 25, 0) })
			Util.Sound(Config.Sounds.PounceHit, wRoot, { Volume = 2.5, Pitch = 0.55, Range = 220 })
			Util.Sound(Config.Sounds.Punch, wRoot, { Volume = 2, Pitch = 0.6 })
			Fx:FireAllClients("Shake", { Position = wRoot.Position, Intensity = 0.9, Radius = 45 })
			Fx:FireAllClients("HitStop", { Attacker = char, Victim = w and w.Character, Duration = 0.1 })
			fist = CFrame.new(wRoot.Position)
		end
	end
	if not hit then
		Util.Sound(Config.Sounds.Slash, root, { Pitch = 0.5, Volume = 1.3 })
	end
	Fx:FireAllClients("Smash", { Char = char, Position = fist.Position, Dir = root.CFrame.LookVector, Hit = hit })
end

-- aim updates streamed from the firing client while the beam is live
local laserAim = {}
function Sentinel.Aim(player, pos)
	if typeof(pos) == "Vector3" and player:GetAttribute("Beaming") then
		laserAim[player] = pos
	end
end

local function laser(player, char, root, aim)
	local cfg = Config.Sentinel.Laser
	local torso = Util.Torso(char) or root
	laserAim[player] = typeof(aim) == "Vector3" and aim or nil
	VFX.Anim(char, "DeathRay")
	Util.Sound(Config.Sounds.DeathRay, root, { Volume = 2.8, Range = 320, Pitch = Config.UploadedSounds.DeathRay ~= 0 and 1 or 0.4 })
	Fx:FireAllClients("LaserCharge", { Char = char, Time = cfg.Charge })
	Status.Apply(player, "Slowed", cfg.Charge + cfg.Duration)
	task.wait(cfg.Charge)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local burnedTotal = 0
	local lastKnock, lastReveal = 0, 0
	local t0 = os.clock()
	local last = os.clock()
	player:SetAttribute("Beaming", true)
	while os.clock() - t0 < cfg.Duration do
		if not (char.Parent and Util.IsAlive(char)) or player:GetAttribute("Role") ~= "Sentinel" or not Round.Active then
			break
		end
		local dt = os.clock() - last
		last = os.clock()
		local origin = torso.Position + root.CFrame.LookVector * 1.8 + Vector3.new(0, 0.6, 0)
		local dir = root.CFrame.LookVector
		local target = laserAim[player]
		if target and (target - origin).Magnitude > 2 then
			dir = (target - origin).Unit
			if dir:Dot(root.CFrame.LookVector) < 0.1 then -- no shooting behind you
				dir = root.CFrame.LookVector
			end
		end
		local ignore = { char }
		local from, remaining = origin, cfg.Range
		local endPos = origin + dir * cfg.Range
		local burns = {}
		local _, wChar, wRoot = wolverineParts()
		local hitW = false
		while remaining > 0 do
			params.FilterDescendantsInstances = ignore
			local hit = workspace:Raycast(from, dir * remaining, params)
			if not hit then
				break
			end
			if wChar and hit.Instance:IsDescendantOf(wChar) then
				endPos = hit.Position
				hitW = true
				break
			end
			if hit.Instance:GetAttribute("Breakable") and burnedTotal < cfg.WallsBurned then
				burnedTotal += 1
				Combat.BreakPart(hit.Instance, hit.Position - dir * 3, 25)
				table.insert(burns, hit.Position)
				remaining -= (hit.Position - from).Magnitude
				from = hit.Position
			else
				endPos = hit.Position
				break
			end
		end
		-- forgiving hit test: anywhere within a few studs of the beam counts
		if not hitW and wRoot then
			local seg = endPos - origin
			local segLen = seg.Magnitude
			if segLen > 0.1 then
				local u = math.clamp((wRoot.Position - origin):Dot(seg / segLen), 0, segLen)
				local closest = origin + seg / segLen * u
				if (wRoot.Position - closest).Magnitude < 3.5 then
					hitW = true
					endPos = closest
				end
			end
		end
		if hitW then
			Wolverine.Damage(cfg.DPS * dt * power(player))
			Status.Apply(Round.Wolverine, "Slowed", cfg.Slow)
			if os.clock() - lastReveal > 0.6 then
				lastReveal = os.clock()
				Wolverine.RevealSkeleton()
			end
			if os.clock() - lastKnock > 0.3 and wRoot then
				lastKnock = os.clock()
				Util.FireClient(Fx, Round.Wolverine, "Knock", { Velocity = Util.Flat(dir) * cfg.Push + Vector3.new(0, 3, 0) })
			end
		end
		Fx:FireAllClients("LaserBeam", { Char = char, From = origin, To = endPos, Hit = hitW, Burns = burns })
		task.wait(0.07)
	end
	player:SetAttribute("Beaming", nil)
	laserAim[player] = nil
	Fx:FireAllClients("LaserEnd", { Char = char })
	VFX.StopAnim(char, "DeathRay")
	-- the core has to cool down: sluggish for a few seconds
	Status.Apply(player, "Slowed", cfg.Recover)
	Util.FireClient(Fx, player, "Announce", { Text = "CORE VENTING", Color = Color3.fromRGB(255, 120, 80), Duration = cfg.Recover })
end

-- Inhibitor Blast: a 2s charge (cancel with E again, or it breaks if Wolverine
-- lands a hit), then a mutant-suppression shockwave that stuns him for 3s.
local charging = {}
local function pulse(player, char, root)
	local cfg = Config.Sentinel.Pulse
	local token = {}
	charging[player] = token
	player:SetAttribute("PulseCharging", true)
	VFX.Anim(char, "PulseCharge")
	Fx:FireAllClients("PulseCharge", { Char = char, Time = cfg.Charge })
	Util.Sound(Config.Sounds.DeathRay, root, { Volume = 1.6, Range = 200, Pitch = 0.55 })
	Status.Apply(player, "Slowed", cfg.Charge)
	local armor0 = player:GetAttribute("Armor")
	local t0 = os.clock()
	local cancelled = false
	while os.clock() - t0 < cfg.Charge do
		task.wait(0.05)
		if charging[player] ~= token or not (char.Parent and Util.IsAlive(char)) or player:GetAttribute("Role") ~= "Sentinel" or player:GetAttribute("Armor") ~= armor0 or not Round.Active then
			cancelled = true
			break
		end
	end
	if charging[player] == token then
		charging[player] = nil
	end
	player:SetAttribute("PulseCharging", nil)
	if cancelled then
		VFX.StopAnim(char, "PulseCharge")
		Fx:FireAllClients("PulseCancel", { Char = char })
		local cd = cooldowns[player]
		if cd then
			cd.Pulse = os.clock() + cfg.CancelCooldown
		end
		Status.Apply(player, "Slowed", 0)
		return
	end
	VFX.StopAnim(char, "PulseCharge")
	VFX.Anim(char, "Pulse")
	task.wait(0.28) -- slam frame
	Fx:FireAllClients("PulseBlast", { Position = root.Position, Radius = cfg.Radius })
	Util.Sound(Config.Sounds.PounceHit, root, { Volume = 3, Pitch = 0.4, Range = 300 })
	Util.Sound(Config.Sounds.Roar, root, { Volume = 0.6, Pitch = 2.2, Range = 120 })
	Fx:FireAllClients("Shake", { Position = root.Position, Intensity = 1.2, Radius = 70 })
	local _, _, wRoot = wolverineParts()
	if wRoot then
		local bcf, bsize = Combat.BodyBox(wRoot)
		local near = (wRoot.Position - root.Position).Magnitude <= cfg.Radius
		if near or Combat.BoxOverlap(CFrame.new(root.Position), Vector3.one * cfg.Radius * 1.4, bcf, bsize) then
			Wolverine.Damage(cfg.Damage * power(player))
			stunWolverine(cfg.Stun)
			Wolverine.RevealSkeleton()
		end
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
	if ability == "LaserAim" then
		Sentinel.Aim(player, arg)
		return
	end
	if player:GetAttribute("Beaming") then
		return
	end
	if ability == "Pulse" and charging[player] then
		charging[player] = nil -- cancel the charge
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
