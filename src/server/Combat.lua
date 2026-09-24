-- Hits, wounds, wall shredding and the rip-in-half finisher.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Round = require(script.Parent.Round)
local Status = require(script.Parent.Status)
local Hiding = require(script.Parent.Hiding)
local VFX = require(script.Parent.VFX)

local Fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx")

local Combat = {}

local regenLater

local function debrisFolder()
	local map = Round.Map
	return (map and map:FindFirstChild("Debris")) or workspace
end

---------------------------------------------------------------------------
-- Environment destruction
---------------------------------------------------------------------------

-- Trees fall over when their trunk is shredded.
local function topple(part, origin)
	local model = part.Parent
	if not (model and model:IsA("Model")) then
		return
	end
	local push = Util.Flat(part.Position - origin)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= part then
			p.Anchored = false
			p.CanCollide = false
			p.AssemblyLinearVelocity = push * 12 + Vector3.new(0, 4, 0)
			p.AssemblyAngularVelocity = push:Cross(Vector3.yAxis) * -1.5
		end
	end
	model.Parent = debrisFolder()
	Debris:AddItem(model, 7)
end

-- Shredded walls/props grow back after Config.WallRegen seconds (with all their
-- trim, which is parented to them). Waits until nobody is standing in the spot.
local regenParams = OverlapParams.new()
regenParams.FilterType = Enum.RaycastFilterType.Include
local function blocked(part)
	local chars = {}
	for _, p in game:GetService("Players"):GetPlayers() do
		if p.Character then
			table.insert(chars, p.Character)
		end
	end
	local debris = Round.Map and Round.Map:FindFirstChild("Debris")
	if debris then
		table.insert(chars, debris) -- bots live here
	end
	regenParams.FilterDescendantsInstances = chars
	for _, hit in workspace:GetPartBoundsInBox(part.CFrame, part.Size + Vector3.new(0.6, 0.6, 0.6), regenParams) do
		local model = hit:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			return true
		end
	end
	return false
end

regenLater = function(part)
	local home = part.Parent
	local map = Round.Map
	if part:GetAttribute("NoRegen") or not home or not map then
		part:Destroy()
		return
	end
	part.Parent = nil
	task.delay(Config.WallRegen or 20, function()
		while true do
			if Round.Map ~= map or not home:IsDescendantOf(workspace) then
				part:Destroy()
				return
			end
			if not blocked(part) then
				break
			end
			task.wait(1.5)
		end
		part:SetAttribute("Broken", nil)
		part.Parent = home
		-- quick materialise flash
		local ghost = part:Clone()
		for _, d in ghost:GetChildren() do
			d:Destroy()
		end
		ghost:SetAttribute("Breakable", nil)
		ghost.Material = Enum.Material.Neon
		ghost.Color = Color3.fromRGB(120, 200, 255)
		ghost.Transparency = 0.4
		ghost.CanCollide = false
		ghost.CanQuery = false
		ghost.Size = part.Size + Vector3.new(0.08, 0.08, 0.08)
		ghost.Parent = debrisFolder()
		TweenService:Create(ghost, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		Debris:AddItem(ghost, 0.6)
	end)
end

function Combat.BreakPart(part, origin, force)
	if not part:GetAttribute("Breakable") or part:GetAttribute("Broken") then
		return false
	end
	part:SetAttribute("Broken", true)
	if part:GetAttribute("Topple") then
		topple(part, origin)
	end

	local size, cf = part.Size, part.CFrame
	local nx = math.clamp(math.ceil(size.X / 3.5), 1, 3)
	local ny = math.clamp(math.ceil(size.Y / 4), 1, 3)
	local nz = math.clamp(math.ceil(size.Z / 3.5), 1, 3)
	local chunk = Vector3.new(size.X / nx, size.Y / ny, size.Z / nz)
	local folder = debrisFolder()

	for ix = 1, nx do
		for iy = 1, ny do
			for iz = 1, nz do
				local offset = Vector3.new(
					(ix - 0.5) * chunk.X - size.X / 2,
					(iy - 0.5) * chunk.Y - size.Y / 2,
					(iz - 0.5) * chunk.Z - size.Z / 2
				)
				local c = Instance.new("Part")
				c.Size = chunk * 0.9
				c.CFrame = cf * CFrame.new(offset) * CFrame.Angles(math.random() * 0.3, math.random() * 0.3, math.random() * 0.3)
				c.Color = part.Color
				c.Material = part.Material
				c.Transparency = part.Transparency
				c.Reflectance = part.Reflectance
				c.TopSurface = Enum.SurfaceType.Smooth
				c.BottomSurface = Enum.SurfaceType.Smooth
				c.CanTouch = false
				c.CanQuery = false
				c.Parent = folder
				local away = Util.Flat(c.Position - origin)
				c.AssemblyLinearVelocity = away * force * (0.5 + math.random() * 0.7)
					+ Vector3.new(0, 8 + math.random() * 22, 0)
				c.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 20
				Debris:AddItem(c, 5)
				task.delay(2, function()
					if c.Parent then
						c.CanCollide = false
					end
				end)
			end
		end
	end
	regenLater(part)
	return true
end

local METAL = {
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.CorrodedMetal] = true,
	[Enum.Material.Foil] = true,
}
function Combat.IsMetal(part)
	return METAL[part.Material] == true
end

-- Claws on metal: a spray of molten sparks off the point of contact, an
-- orange flash and a steel screech. dir = which way the sparks fly.
function Combat.MetalSparks(position, dir)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	dir = (dir and dir.Magnitude > 0.01) and dir.Unit or Vector3.yAxis
	anchor.CFrame = CFrame.lookAt(position, position + (dir + Vector3.new(0, 0.6, 0)).Unit)
	anchor.Parent = debrisFolder()
	local streaks = table.clone(Util.MoltenStreakProps)
	streaks.EmissionDirection = Enum.NormalId.Front
	local globs = table.clone(Util.MoltenGlobProps)
	globs.EmissionDirection = Enum.NormalId.Front
	Util.Burst(anchor, streaks, 55, 1.2)
	Util.Burst(anchor, globs, 14, 1.6)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Range = 14
	light.Brightness = 6
	light.Shadows = false
	light.Parent = anchor
	TweenService:Create(light, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	Util.SoundAt(Config.Sounds.Snikt, position, { Volume = 1.4, Pitch = 1.25 + math.random() * 0.2, Range = 160 })
	Debris:AddItem(anchor, 2.5)
end

-- Breaks every breakable map part inside a box. Returns how many broke.
function Combat.BreakInBox(cframe, size, origin, force)
	local map = Round.Map
	if not map then
		return 0
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	local n = 0
	local metalAt = nil
	for _, p in workspace:GetPartBoundsInBox(cframe, size, params) do
		local metal = METAL[p.Material] and p.Position
		if Combat.BreakPart(p, origin, force or 40) then
			n += 1
			metalAt = metalAt or metal
		end
	end
	if metalAt then
		-- sparks off the face nearest him, flying back past the claws
		local toward = Util.Flat(origin - metalAt)
		Combat.MetalSparks(metalAt:Lerp(origin, 0.25) + Vector3.new(0, 0.5, 0), toward)
	end
	if n > 0 then
		VFX.Dust(cframe.Position, Color3.fromRGB(190, 185, 180), 8 + n * 3)
		Util.SoundAt(Config.Sounds.Break, cframe.Position, { Volume = 1.6, Pitch = 0.55 + math.random() * 0.2, Range = 260 })
		Util.SoundAt(Config.Sounds.Slash, cframe.Position, { Volume = 1, Pitch = 0.7, Range = 180 })
	end
	return n
end

---------------------------------------------------------------------------
-- Finding survivors
---------------------------------------------------------------------------

local function sorted(list, from)
	table.sort(list, function(a, b)
		return (a.Root.Position - from).Magnitude < (b.Root.Position - from).Magnitude
	end)
	return list
end

-- Blocky hitboxes: every character is a body-sized box (scaled with the
-- character); an attack lands when its box overlaps that body box at all.
function Combat.BodyBox(root)
	local k = root.Size.Y / 2
	return root.CFrame * CFrame.new(0, -0.4 * k, 0), Vector3.new(3.4, 5.8, 2.4) * k
end

-- oriented box vs oriented box (separating axis test)
function Combat.BoxOverlap(cfA, sizeA, cfB, sizeB)
	local ea, eb = sizeA / 2, sizeB / 2
	local A = { cfA.RightVector, cfA.UpVector, cfA.LookVector }
	local B = { cfB.RightVector, cfB.UpVector, cfB.LookVector }
	local ae = { ea.X, ea.Y, ea.Z }
	local be = { eb.X, eb.Y, eb.Z }
	local d = cfB.Position - cfA.Position
	local function separated(axis)
		if axis.Magnitude < 1e-6 then
			return false
		end
		axis = axis.Unit
		local ra = math.abs(A[1]:Dot(axis)) * ae[1] + math.abs(A[2]:Dot(axis)) * ae[2] + math.abs(A[3]:Dot(axis)) * ae[3]
		local rb = math.abs(B[1]:Dot(axis)) * be[1] + math.abs(B[2]:Dot(axis)) * be[2] + math.abs(B[3]:Dot(axis)) * be[3]
		return math.abs(d:Dot(axis)) > ra + rb
	end
	for i = 1, 3 do
		if separated(A[i]) or separated(B[i]) then
			return false
		end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			if separated(A[i]:Cross(B[j])) then
				return false
			end
		end
	end
	return true
end

function Combat.FindTargets(cframe, size)
	local found = {}
	for player in Round.Survivors do
		local char = player.Character
		local root = Util.Root(char)
		if root and Util.IsAlive(char) and not Status.Has(player, "Busy") then
			local bcf, bsize = Combat.BodyBox(root)
			if Combat.BoxOverlap(cframe, size, bcf, bsize) then
				table.insert(found, { Player = player, Char = char, Root = root })
			end
		end
	end
	return sorted(found, cframe.Position)
end

function Combat.FindNear(position, radius)
	local found = {}
	local probe = Vector3.one * radius * 2
	for player in Round.Survivors do
		local char = player.Character
		local root = Util.Root(char)
		if root and Util.IsAlive(char) and not Status.Has(player, "Busy") then
			local bcf, bsize = Combat.BodyBox(root)
			if (root.Position - position).Magnitude <= radius or Combat.BoxOverlap(CFrame.new(position), probe, bcf, bsize) then
				table.insert(found, { Player = player, Char = char, Root = root })
			end
		end
	end
	return sorted(found, position)
end

---------------------------------------------------------------------------
-- Hits
---------------------------------------------------------------------------

function Combat.Blood(part, amount)
	if part then
		Util.Burst(part, Util.BloodProps, amount or 30, 2)
	end
end

-- Registers one hit. Returns "kill", "hit" or nil (not hittable right now).
-- Drags a survivor out of their hiding spot (no-op if not hiding).
function Combat.PullOut(victim)
	if Hiding.IsHidden(victim) then
		Hiding.Leave(victim, true)
		return true
	end
	return false
end

-- Hitting someone on i-frames doesn't hurt them, but it shatters the i-frames.
function Combat.BreakShield(victim)
	if not Status.Has(victim, "Immune") then
		return false
	end
	Status.Clear(victim, "Immune")
	local char = victim.Character
	local glow = char and char:FindFirstChild("IFrameGlow")
	if glow then
		glow:Destroy()
	end
	local torso = Util.Torso(char)
	if torso then
		VFX.Impact(torso.Position, Color3.fromRGB(160, 220, 255), 0.8, char)
		Util.Sound(Config.Sounds.Slash, torso, { Volume = 1.2, Pitch = 1.6 })
	end
	return true
end

function Combat.Hit(victim, ignoreImmunity)
	if not Round.Survivors[victim] then
		return nil
	end
	if Combat.PullOut(victim) then
		ignoreImmunity = true
	end
	if not ignoreImmunity and Status.Has(victim, "Immune") then
		Combat.BreakShield(victim)
		return nil
	end
	if not Util.IsAlive(victim.Character) then
		return nil
	end
	if victim:GetAttribute("Role") == "Sentinel" then
		local armor = (victim:GetAttribute("Armor") or 1) - 1
		victim:SetAttribute("Armor", armor)
		if armor <= 0 and Combat.OnSuitDestroyed then
			-- the suit blows apart and the pilot is thrown clear (as a normal hit)
			Combat.OnSuitDestroyed(victim)
		end
		return "hit"
	end
	local hits = (victim:GetAttribute("Hits") or 0) + 1
	victim:SetAttribute("Hits", hits)
	return hits >= Config.HitsToKill and "kill" or "hit"
end

-- Non-lethal hit: blood, knockback, i-frames and an adrenaline burst.
-- opts (optional): { Force, Up, Dir } to customise the throw.
function Combat.Wound(killer, victim, opts)
	opts = opts or {}
	local char = victim.Character
	local hum, root = Util.Humanoid(char), Util.Root(char)
	if not (hum and root) then
		return
	end
	if victim:GetAttribute("Role") == "Sentinel" then
		hum.Health = hum.MaxHealth * math.max(0.05, (victim:GetAttribute("Armor") or 1) / Config.Sentinel.Armor)
		local kRoot0 = killer and Util.Root(killer.Character)
		local torso0 = Util.Torso(char) or root
		Combat.MetalSparks(torso0.Position, kRoot0 and Util.Flat(kRoot0.Position - torso0.Position) or nil)
	else
		local hits = victim:GetAttribute("Hits") or 0
		hum.Health = hum.MaxHealth * math.max(0.05, 1 - hits / Config.HitsToKill)
		Combat.Blood(Util.Torso(char), 35)
	end
	Util.Sound(Config.Sounds.Impact, root, { Pitch = 0.95 + math.random() * 0.1, Volume = 1.1 })
	Util.Sound(Config.Sounds.Gore, root, { Pitch = 0.8, Volume = 0.7 })
	Status.Apply(victim, "Immune", Config.HitImmunity)
	Status.Apply(victim, "Boost", Config.HitImmunity + Config.AdrenalineTime)
	Status.Apply(killer, "Busy", Config.WolverineHitRecovery)

	-- Crisp hit feedback
	local torso = Util.Torso(char) or root
	local kChar = killer and killer.Character
	VFX.Impact(torso.Position, kChar and kChar:GetAttribute("ClawGlow") or Color3.fromRGB(255, 60, 50), 1, char)
	VFX.WoundMarks(char)
	VFX.IFrames(char, Config.HitImmunity)
	VFX.ThrowTrail(char, Config.Throw.Tumble + 0.3)
	VFX.Anim(char, "HitReact")
	Fx:FireAllClients("HitStop", { Attacker = killer.Character, Victim = char, Duration = 0.08 })
	Fx:FireAllClients("Shake", { Position = root.Position, Intensity = 0.5, Radius = 35 })

	-- Throw them away from Wolverine
	local kRoot = Util.Root(killer.Character)
	local dir = opts.Dir or (kRoot and Util.Flat(root.Position - kRoot.Position) or Util.Flat(-root.CFrame.LookVector))
	local throw = dir * (opts.Force or Config.Throw.Force) + Vector3.new(0, opts.Up or Config.Throw.Up, 0)
	if victim.IsBot then
		local hum2 = Util.Humanoid(char)
		hum2.PlatformStand = true
		root.AssemblyLinearVelocity = throw
		root.AssemblyAngularVelocity = dir:Cross(Vector3.yAxis) * -8
		task.delay(Config.Throw.Tumble, function()
			if hum2.Parent and hum2.Health > 0 then
				hum2.PlatformStand = false
				hum2:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end
	Util.FireClient(Fx, victim, "Knock", { Velocity = throw, Tumble = Config.Throw.Tumble, Spin = dir:Cross(Vector3.yAxis) * -8 })
	Util.FireClient(Fx, victim, "Hurt", {})
	Util.FireClient(Fx, killer, "HitConfirm", {})
end

---------------------------------------------------------------------------
-- The finisher: rip in half
---------------------------------------------------------------------------

local function bloodPool(position)
	local result = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -20, 0), (function()
		local p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Include
		p.FilterDescendantsInstances = { Round.Map, workspace:FindFirstChildOfClass("Terrain") }
		return p
	end)())
	if not result then
		return
	end
	local pool = Instance.new("Part")
	pool.Shape = Enum.PartType.Cylinder
	pool.Anchored = true
	pool.CanCollide = false
	pool.CanQuery = false
	pool.CanTouch = false
	pool.Color = Color3.fromRGB(75, 0, 0)
	pool.Material = Enum.Material.SmoothPlastic
	pool.Reflectance = 0.15
	pool.Size = Vector3.new(0.08, 1, 1)
	pool.CFrame = CFrame.new(result.Position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pool.Parent = debrisFolder()
	TweenService:Create(pool, TweenInfo.new(2.5, Enum.EasingStyle.Quad), { Size = Vector3.new(0.08, 8, 8) }):Play()
end

local function tearEmitter(part, yOffset)
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, yOffset, 0)
	att.Parent = part
	local pe = Instance.new("ParticleEmitter")
	for k, v in Util.BloodProps do
		pe[k] = v
	end
	pe.Rate = 45
	pe.Speed = NumberRange.new(4, 12)
	pe.Parent = att
	task.delay(3, function()
		pe.Enabled = false
	end)
end

function Combat.RipInHalf(char, base)
	local hum = Util.Humanoid(char)
	local root = Util.Root(char)
	if not (hum and root) then
		return
	end
	hum.BreakJointsOnDeath = false
	local upper, lower
	local upperTorso = char:FindFirstChild("UpperTorso")
	if upperTorso then
		upper, lower = upperTorso, char:FindFirstChild("LowerTorso")
		-- cut every joint linking the halves (Motor6D, or the upgraded
		-- AnimationConstraint + BallSocketConstraint pair)
		for _, d in char:GetDescendants() do
			local a0, a1
			if d:IsA("JointInstance") or d:IsA("AnimationConstraint") then
				a0, a1 = d.Part0, d.Part1
			elseif d:IsA("Constraint") then
				a0 = d.Attachment0 and d.Attachment0.Parent
				a1 = d.Attachment1 and d.Attachment1.Parent
			end
			if (a0 == upper and a1 == lower) or (a0 == lower and a1 == upper) then
				d:Destroy()
			end
		end
	else -- R6: the legs come off
		local torso = char:FindFirstChild("Torso")
		if torso then
			for _, n in { "Right Hip", "Left Hip" } do
				local j = torso:FindFirstChild(n)
				if j then
					j:Destroy()
				end
			end
		end
		upper, lower = torso, char:FindFirstChild("Right Leg")
	end

	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = d.Name ~= "HumanoidRootPart"
		end
	end
	hum.PlatformStand = true
	hum.Health = 0
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			pcall(function()
				d:SetNetworkOwner(nil)
			end)
		end
	end

	local side = base.RightVector
	if upper then
		tearEmitter(upper, -upper.Size.Y / 2)
		upper.AssemblyLinearVelocity = side * 20 + Vector3.new(0, 26, 0) - base.LookVector * 6
		upper.AssemblyAngularVelocity = base.LookVector * 8
	end
	if lower then
		tearEmitter(lower, lower.Size.Y / 2)
		lower.AssemblyLinearVelocity = -side * 20 + Vector3.new(0, 14, 0)
		lower.AssemblyAngularVelocity = -base.LookVector * 8
	end
	local leftLeg = char:FindFirstChild("Left Leg")
	if leftLeg and not upperTorso then
		leftLeg.AssemblyLinearVelocity = -side * 16 + Vector3.new(0, 10, 0)
	end
	Combat.Blood(upper or root, 80)
	Combat.Blood(lower or root, 60)
	Util.Sound(Config.Sounds.Gore, root, { Volume = 2, Pitch = 0.5, Range = 200 })
	Util.Sound(Config.Sounds.Slash, root, { Volume = 2, Pitch = 0.6, Range = 200 })
	bloodPool(root.Position)
end

-- Full kill sequence. Yields ~1 second. Call with task.spawn.
function Combat.Execute(killer, victim)
	local kChar, vChar = killer.Character, victim.Character
	local kRoot, vRoot = Util.Root(kChar), Util.Root(vChar)
	if not (kRoot and vRoot and Util.IsAlive(vChar)) then
		return
	end
	Round.Survivors[victim] = nil
	victim:SetAttribute("Role", "Dead")
	Status.Apply(killer, "Busy", 1.4)
	Status.Apply(killer, "Frozen", 1.4)
	Status.Apply(victim, "Busy", 10)
	Status.Apply(victim, "Frozen", 10)

	local look = Util.Flat(vRoot.Position - kRoot.Position)
	local base = CFrame.lookAt(kRoot.Position, kRoot.Position + look)
	kRoot.Anchored = true
	vRoot.Anchored = true
	kRoot.CFrame = base
	vRoot.CFrame = base * CFrame.new(0, 0.5, -3) * CFrame.Angles(0, math.pi, 0)

	-- Grab & lift
	VFX.Anim(kChar, "Rip")
	VFX.Anim(vChar, "Grabbed")
	Util.Sound(Config.Sounds.Lunge, kRoot, { Pitch = 0.8, Volume = 1.5 })
	TweenService:Create(vRoot, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		CFrame = base * CFrame.new(0, 2.4, -2.7) * CFrame.Angles(0, math.pi, 0),
	}):Play()
	Fx:FireAllClients("Shake", { Position = kRoot.Position, Intensity = 0.7, Radius = 70 })
	Util.FireClient(Fx, victim, "Grabbed", {})
	task.wait(0.62)

	-- Tear (synced with the Rip clip's pull-apart key)
	if vChar.Parent then
		VFX.StopAnim(vChar)
		Fx:FireAllClients("HitStop", { Attacker = kChar, Victim = vChar, Duration = 0.12 })
		Combat.RipInHalf(vChar, base)
		Util.Sound(Config.Sounds.Tear, kRoot, { Volume = 2, Range = 220 })
		Fx:FireAllClients("Shake", { Position = kRoot.Position, Intensity = 1.2, Radius = 90 })
		Fx:FireAllClients("Gore", { Position = kRoot.Position, Victim = victim.Name })
	end
	task.wait(0.55)
	VFX.Anim(kChar, "Snarl")
	local kHead = kChar:FindFirstChild("Head")
	if kHead then
		-- the cartoon berserker scream over what's left of them
		Util.Sound(Config.Sounds.Scream, kHead, { Volume = 2.6, Range = 420, MinRange = 30 })
	end
	if kRoot.Parent then
		kRoot.Anchored = false
	end
	Status.Clear(killer, "Frozen")
	Status.Clear(killer, "Busy")
	Round.FireKilled(victim, killer)
end

-- Convenience used by every Wolverine attack.
function Combat.Resolve(killer, victim, ignoreImmunity)
	local result = Combat.Hit(victim, ignoreImmunity)
	if result == "kill" then
		Combat.Execute(killer, victim)
	elseif result == "hit" then
		Combat.Wound(killer, victim)
	end
	return result
end

return Combat
