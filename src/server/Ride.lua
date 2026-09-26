-- Riding a Sentinel (Config.Ride): Wolverine pounces into a suit's back or
-- side and clings on, stabbing the power pack on its back, until the pilot
-- bucks him off, crushes him into a wall, another suit punches him off, the
-- suit blasts or slams him clear, or he leaps off himself.
--
-- Pinning (also the grab's hold, Sentinel.lua): the pinned character is
-- anchored and the server moves it with the suit every frame (so hits find
-- him there), while every client pins it locally every render frame
-- (client/Glue.lua) so it sticks to the suit smoothly on every screen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Round = require(script.Parent.Round)
local Status = require(script.Parent.Status)
local VFX = require(script.Parent.VFX)
local Combat = require(script.Parent.Combat)
local Block = require(script.Parent.Block)

local Fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx")

local Ride = {}
-- filled in by Wolverine.lua and Sentinel.lua (which require this module)
Ride.DamageWolverine = function(_amount, _by) end
Ride.StunWolverine = function(_seconds) end
Ride.Power = function(_suit)
	return 1
end

local GOLD = Color3.fromRGB(255, 205, 60)
local RED = Color3.fromRGB(255, 80, 60)

---------------------------------------------------------------------------
-- Pinning one character to another
---------------------------------------------------------------------------

local pins = {} -- [char] = { To = char, Offset = CFrame, Saved = { [part] = CanCollide } }

function Ride.Pin(char, toChar, offset)
	local root, toRoot = Util.Root(char), Util.Root(toChar)
	if not (root and toRoot) then
		return false
	end
	local saved = {}
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") then
			saved[p] = p.CanCollide
			p.CanCollide = false -- he mustn't block the suit he's on
		end
	end
	root.Anchored = true
	root.CFrame = toRoot.CFrame * offset
	pins[char] = { To = toChar, Offset = offset, Saved = saved }
	Fx:FireAllClients("Glue", { Char = char, To = toChar, Offset = offset })
	return true
end

-- Let go: optionally set down at `place`, unanchored and handed back to
-- `owner`'s client to move.
function Ride.Unpin(char, place, owner)
	local pinned = pins[char]
	pins[char] = nil
	Fx:FireAllClients("Glue", { Char = char })
	if pinned then
		for p, was in pinned.Saved do
			if p.Parent then
				p.CanCollide = was
			end
		end
	end
	local root = Util.Root(char)
	if root and root.Parent then
		if place then
			root.CFrame = place
		end
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		if owner then
			pcall(function()
				root:SetNetworkOwner(owner)
			end)
		end
	end
end

function Ride.IsPinned(char)
	return pins[char] ~= nil
end

---------------------------------------------------------------------------
-- The ride
---------------------------------------------------------------------------

local ride = nil -- { W, S, WChar, SChar, Start, Jolts, LastJolt, NextStab, Stabs, Side, BuckSide }

-- where he clings, in the suit's root space (it faces -Z): chest on the power
-- pack between its shoulder blades, head just behind its head
local function backOffset(sRoot)
	local k = sRoot.Size.Y / 2 -- 1.8 for a suit
	return CFrame.new(0, 0.53 * k, 1.31 * k + 0.72)
end
-- the power pack, and the way out of the suit's back
local function packPoint(sRoot)
	local k = sRoot.Size.Y / 2
	return (sRoot.CFrame * CFrame.new(0, 0.97 * k, 1.05 * k)).Position
end
local function standHeight(char)
	local hum, root = Util.Humanoid(char), Util.Root(char)
	return (hum and hum.HipHeight or 2) + (root and root.Size.Y / 2 or 1)
end
local floorRay = RaycastParams.new()
floorRay.FilterType = Enum.RaycastFilterType.Exclude
local function groundBelow(pos, exclude)
	floorRay.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -30, 0), floorRay)
	return hit and hit.Position.Y or pos.Y - 4
end
local function clawColor(char)
	return char and char:GetAttribute("ClawGlow") or Color3.fromRGB(255, 60, 50)
end

function Ride.IsRiding(player)
	return ride ~= nil and ride.W == player
end
-- whoever is on this suit's back (nil if nobody)
function Ride.Rider(suit)
	return ride ~= nil and ride.S == suit and ride.W or nil
end

-- He lands on its back. Returns false if he can't (and the pounce goes on).
function Ride.Start(w, s)
	if ride then
		return false
	end
	local wChar, sChar = w.Character, s.Character
	local wRoot, sRoot = Util.Root(wChar), Util.Root(sChar)
	if not (wRoot and sRoot and Util.IsAlive(wChar) and Util.IsAlive(sChar)) then
		return false
	end
	Block.Break(s) -- a pounce breaks a guard
	ride = { W = w, S = s, WChar = wChar, SChar = sChar, Start = os.clock(), Jolts = 0, LastJolt = 0, NextStab = os.clock() + 0.25, Stabs = 0 }
	w:SetAttribute("Riding", true)
	s:SetAttribute("Ridden", true)
	Status.Apply(s, "PursuitHold", Config.Sentinel.Pursuit.HitGrace) -- he's on it: its thrusters cut out
	Ride.Pin(wChar, sChar, backOffset(sRoot))
	VFX.StopAnim(wChar, nil)
	VFX.Anim(wChar, "RideMount")
	VFX.Anim(sChar, "RiddenHit")
	-- the slam of him hitting its back: the suit lurches forward
	local at = packPoint(sRoot)
	local out = -Util.Flat(sRoot.CFrame.LookVector)
	Fx:FireAllClients("HitStop", { Attacker = wChar, Victim = sChar, Duration = 0.13 })
	Fx:FireAllClients("Shake", { Position = at, Intensity = 1.3, Radius = 90 })
	Combat.MetalSparks(at, out)
	VFX.Impact(at, clawColor(wChar), 1.4, sChar, true)
	Util.SoundAt(Config.Sounds.PounceHit, at, { Volume = 2.2, Pitch = 0.8, Range = 240 })
	Util.SoundAt(Config.Sounds.Punch, at, { Volume = 2, Pitch = 0.55, Range = 240 })
	Util.FireClient(Fx, s, "Knock", { Velocity = -out * 26, Duration = 0.16 })
	Util.FireClient(Fx, w, "Announce", { Text = "ON ITS BACK! M1: STAB THE CORE   SPACE: LEAP OFF", Color = GOLD, Duration = 2.5 })
	Util.FireClient(Fx, s, "Announce", { Text = "HE'S ON YOUR BACK! MASH SPACE TO BUCK HIM. BACK TO A WALL + SPACE CRUSHES HIM", Color = RED, Duration = 2.8 })
	return true
end

-- M1 while riding: the claws go into the power pack. Every 3rd stab he
-- drives both in and twists (Twist x, and they burst out of its chest).
function Ride.Stab(w)
	local r = ride
	if not (r and r.W == w) or os.clock() < r.NextStab then
		return
	end
	local cfg = Config.Ride
	local raging = w:GetAttribute("Rage") == true
	r.NextStab = os.clock() + cfg.StabCooldown * (raging and 1 / Config.Rage.AttackSpeed or 1)
	r.Stabs += 1
	local big = r.Stabs % 3 == 0
	r.Side = r.Side == "R" and "L" or "R"
	VFX.Anim(r.WChar, big and "RideTwist" or (r.Side == "R" and "RideStabR" or "RideStabL"))
	-- the strike frame of the clip: the claws go in
	task.delay(big and 0.15 or 0.11, function()
		if ride ~= r then
			return
		end
		local sRoot, sTorso = Util.Root(r.SChar), Util.Torso(r.SChar)
		if not (sRoot and sTorso) then
			return
		end
		local at = packPoint(sRoot)
		local out = -Util.Flat(sRoot.CFrame.LookVector)
		local glow = clawColor(r.WChar)
		Fx:FireAllClients("HitStop", { Attacker = r.WChar, Victim = r.SChar, Duration = big and 0.15 or 0.075 })
		Fx:FireAllClients("Shake", { Position = at, Intensity = big and 1.3 or 0.6, Radius = 70 })
		Combat.MetalSparks(at, (out + Vector3.new(0, 0.4, 0)).Unit)
		VFX.Impact(at, glow, big and 1.7 or 1.05, r.SChar, true)
		Fx:FireAllClients("Electric", { Char = r.SChar, Duration = big and 0.9 or 0.3 })
		Util.Burst(sTorso, Util.SparkProps, big and 50 or 18, 1.3)
		Util.SoundAt(Config.Sounds.Impale, at, { Volume = big and 2.4 or 1.7, Pitch = (big and 0.85 or 1.1) * (0.95 + math.random() * 0.1), Range = 220 })
		Util.SoundAt(Config.Sounds.Punch, at, { Volume = 1.5, Pitch = big and 0.5 or 0.75, Range = 200 })
		if big then
			-- all the way through: the claws punch out of its chest
			local front = (sRoot.CFrame * CFrame.new(0, 0.97 * sRoot.Size.Y / 2, -0.9 * sRoot.Size.Y / 2)).Position
			Fx:FireAllClients("ImpaleBurst", { Position = front, Dir = (-out + Vector3.new(0, 0.25, 0)).Unit, Color = glow, Heavy = true })
		end
		Status.Apply(r.S, "PursuitHold", Config.Sentinel.Pursuit.HitGrace)
		local armor = (r.S:GetAttribute("Armor") or 1) - cfg.StabArmor * (raging and Config.Rage.Damage or 1) * (big and cfg.Twist or 1)
		r.S:SetAttribute("Armor", armor)
		local hum = Util.Humanoid(r.SChar)
		if hum then
			hum.Health = hum.MaxHealth * math.max(0.05, armor / Config.Sentinel.Armor)
		end
		Util.FireClient(Fx, r.S, "Hurt", {})
		Util.FireClient(Fx, r.W, "HitConfirm", {})
		if armor <= 0 then
			local s = r.S
			Ride.End("dropped")
			if Combat.OnSuitDestroyed then
				Combat.OnSuitDestroyed(s) -- he tore it open from behind
			end
		end
	end)
end

-- backed into a wall with him on its back
local crushRay = RaycastParams.new()
crushRay.FilterType = Enum.RaycastFilterType.Exclude
local crush -- (below: it ends the ride)
-- the wall right behind him, if the suit's back is up against one
local function wallBehind(r, sRoot, extra)
	local debris = Round.Map and Round.Map:FindFirstChild("Debris")
	crushRay.FilterDescendantsInstances = debris and { r.WChar, r.SChar, debris } or { r.WChar, r.SChar }
	local k = sRoot.Size.Y / 2
	local look = Util.Flat(sRoot.CFrame.LookVector)
	local reach = 1.31 * k + 0.72 + 1.1 + (extra or 0) -- past his back
	for _, y in { 0.5 * k, 1.2 * k } do
		local hit = workspace:Raycast(sRoot.Position + Vector3.new(0, y, 0), -look * reach, crushRay)
		if hit and math.abs(hit.Normal.Y) < 0.5 then
			return hit
		end
	end
	return nil
end
crush = function(r, sRoot, hit)
	local look = Util.Flat(sRoot.CFrame.LookVector)
	local at = hit.Position
	VFX.Anim(r.SChar, "SlamBack")
	Fx:FireAllClients("HitStop", { Attacker = r.SChar, Victim = r.WChar, Duration = 0.17 })
	Fx:FireAllClients("Shake", { Position = at, Intensity = 1.9, Radius = 130 })
	Combat.SmashInBox(CFrame.lookAt(at, at - look) * CFrame.new(0, 0, -1), Vector3.new(8, 11, 5), sRoot.Position, 95)
	VFX.Dust(at + look * 0.5, hit.Instance.Color:Lerp(Color3.fromRGB(200, 196, 188), 0.5), 18)
	VFX.Shockwave(Vector3.new(at.X, groundBelow(at, { r.WChar, r.SChar }) + 0.2, at.Z), 16)
	Util.SoundAt(Config.Sounds.SentinelSmash ~= "" and Config.Sounds.SentinelSmash or Config.Sounds.Impact, at, { Volume = 2.6, Pitch = 0.75, Range = 300 })
	Util.SoundAt(Config.Sounds.Break, at, { Volume = 2, Pitch = 0.8, Range = 260 })
	local w, s = r.W, r.S
	Ride.End("crushed")
	Ride.DamageWolverine(Config.Ride.CrushDamage * Ride.Power(s), s)
	Ride.StunWolverine(Config.Ride.CrushStun)
	Util.FireClient(Fx, w, "Announce", { Text = "CRUSHED!", Color = RED, Duration = 1.4 })
	Util.FireClient(Fx, s, "Announce", { Text = "CRUSHED HIM!", Color = GOLD, Duration = 1.4 })
end

-- the suit's back thrusters fire (bucking)
local THRUST = {
	Texture = "rbxasset://textures/particles/smoke_main.dds",
	Color = ColorSequence.new(Color3.fromRGB(255, 190, 110), Color3.fromRGB(90, 86, 84)),
	LightEmission = 0.6,
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.2) }),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
	Lifetime = NumberRange.new(0.25, 0.5),
	Speed = NumberRange.new(24, 36),
	SpreadAngle = Vector2.new(14, 14),
	EmissionDirection = Enum.NormalId.Bottom,
}
local function thrusterBlast(sRoot)
	local k = sRoot.Size.Y / 2
	for _, x in { -0.52, 0.52 } do
		Util.Burst((sRoot.CFrame * CFrame.new(x * k, 0.4 * k, 1.1 * k)).Position, THRUST, 26, 1)
	end
end

-- The pilot jumps while he's on its back: the suit twists violently and its
-- thrusters fire. The Jolts-th throws him off.
function Ride.Buck(s)
	local r = ride
	if not (r and r.S == s) or os.clock() - r.LastJolt < Config.Ride.JoltGap then
		return
	end
	r.LastJolt = os.clock()
	r.Jolts += 1
	local sRoot = Util.Root(r.SChar)
	if not sRoot then
		return
	end
	-- its back to a wall: the buck throws itself back and crushes him into it
	local wall = wallBehind(r, sRoot, 2.5)
	if wall then
		crush(r, sRoot, wall)
		return
	end
	local last = r.Jolts >= Config.Ride.Jolts
	r.BuckSide = r.BuckSide == "L" and "R" or "L"
	VFX.Anim(r.SChar, last and "BuckThrow" or "Buck" .. r.BuckSide)
	thrusterBlast(sRoot)
	Util.Sound(Config.Sounds.Whoosh, sRoot, { Volume = 1.6, Pitch = 0.7, Range = 160 })
	Util.Sound(Config.Sounds.Punch, sRoot, { Volume = 1.2, Pitch = 0.5, Range = 160 })
	Fx:FireAllClients("HitStop", { Attacker = r.SChar, Victim = r.WChar, Duration = 0.05 })
	Fx:FireAllClients("Shake", { Position = sRoot.Position, Intensity = last and 1.2 or 0.7, Radius = 70 })
	Util.FireClient(Fx, r.W, "Announce", { Text = ("HOLD ON! %d/%d"):format(r.Jolts, Config.Ride.Jolts), Color = RED, Duration = 0.6 })
	if last then
		task.delay(0.16, function() -- on the heave of the throw
			if ride == r then
				Ride.End("shaken", { Side = r.BuckSide == "L" and -1 or 1 })
			end
		end)
	end
end

-- He comes off. reason: "leap" / "timeout" (he kicks off), "shaken" (bucked
-- off), "punched" / "blasted" (another hit flung him, opts.Dir), "crushed"
-- (into a wall), "dropped" / "grabbed" / "gone" (just let go).
function Ride.End(reason, opts)
	local r = ride
	if not r then
		return
	end
	ride = nil
	opts = opts or {}
	r.W:SetAttribute("Riding", nil)
	if r.S.Parent then
		r.S:SetAttribute("Ridden", nil)
	end
	local wChar, sChar = r.WChar, r.SChar
	local wRoot, sRoot = Util.Root(wChar), Util.Root(sChar)
	VFX.StopAnim(wChar, nil)
	if not (wRoot and wRoot.Parent) then
		Ride.Unpin(wChar)
		return
	end
	-- set down upright where he is (the fling carries him from there)
	local look = sRoot and Util.Flat(sRoot.CFrame.LookVector) or Util.Flat(wRoot.CFrame.LookVector)
	local out = -look -- out of the suit's back
	local here = wRoot.Position
	local owner = r.W.Parent and r.W or nil
	if reason == "crushed" then
		-- slides down between the suit and the wall, onto the floor
		local ground = groundBelow(here, { wChar, sChar })
		Ride.Unpin(wChar, CFrame.lookAt(Vector3.new(here.X, ground + standHeight(wChar), here.Z), Vector3.new(here.X, ground + standHeight(wChar), here.Z) + look), owner)
		VFX.Anim(wChar, "Crushed")
		return
	end
	Ride.Unpin(wChar, CFrame.lookAt(here, here + look), owner)
	if reason == "leap" or reason == "timeout" then
		-- both boots into its back: he flips off behind it, the suit stumbles
		VFX.Anim(wChar, "RideLeapOff")
		Util.FireClient(Fx, r.W, "Knock", { Velocity = out * 42 + Vector3.new(0, 34, 0), Duration = 0.22 })
		if sRoot then
			Util.FireClient(Fx, r.S, "Knock", { Velocity = look * 30, Duration = 0.15 })
			local at = packPoint(sRoot)
			Fx:FireAllClients("KickImpact", { Position = at, Dir = look })
			Util.SoundAt(Config.Sounds.Punch, at, { Volume = 1.8, Pitch = 0.7, Range = 200 })
			Fx:FireAllClients("Shake", { Position = at, Intensity = 0.8, Radius = 60 })
		end
	elseif reason == "shaken" then
		-- thrown off over its shoulder
		local side = look:Cross(Vector3.yAxis) * (opts.Side or 1)
		VFX.Anim(wChar, "Flung")
		Util.FireClient(Fx, r.W, "Knock", { Velocity = side * 58 + out * 14 + Vector3.new(0, 40, 0), Tumble = 0.9, Spin = look * 10 })
		Ride.DamageWolverine(Config.Ride.ShakeDamage * Ride.Power(r.S), r.S)
		Util.FireClient(Fx, r.S, "Announce", { Text = "BUCKED HIM OFF!", Color = GOLD, Duration = 1.4 })
	elseif reason == "punched" or reason == "blasted" then
		local dir = typeof(opts.Dir) == "Vector3" and Util.Flat(opts.Dir) or out
		VFX.Anim(wChar, "Flung")
		Util.FireClient(Fx, r.W, "Knock", { Velocity = dir * 78 + Vector3.new(0, 34, 0), Tumble = 1, Spin = dir:Cross(Vector3.yAxis) * -9 })
	end
end

local nextCrushCheck = 0
RunService.Heartbeat:Connect(function()
	-- pinned characters ride along with whoever holds them
	for char, pinned in pins do
		local root, toRoot = Util.Root(char), Util.Root(pinned.To)
		if root and toRoot and char.Parent and pinned.To.Parent then
			root.CFrame = toRoot.CFrame * pinned.Offset
		elseif not char.Parent then
			pins[char] = nil -- gone (left, or the round's over)
			Fx:FireAllClients("Glue", { Char = char })
		end
	end
	local r = ride
	if not r then
		return
	end
	local ok = Round.Active and r.W.Parent ~= nil and r.S.Parent ~= nil and Round.Wolverine == r.W
		and r.S:GetAttribute("Role") == "Sentinel" and r.W.Character == r.WChar and r.S.Character == r.SChar
		and Util.IsAlive(r.WChar) and Util.IsAlive(r.SChar)
	if not ok then
		Ride.End("gone")
		return
	end
	if os.clock() - r.Start > Config.Ride.MaxTime then
		Ride.End("timeout")
		return
	end
	-- the pilot backing him into a wall
	if os.clock() < nextCrushCheck then
		return
	end
	nextCrushCheck = os.clock() + 0.05
	local sRoot = Util.Root(r.SChar)
	if not sRoot then
		return
	end
	local look = Util.Flat(sRoot.CFrame.LookVector)
	local backing = -sRoot.AssemblyLinearVelocity:Dot(look)
	if backing > 5 then -- (walking backwards: shift lock)
		local hit = wallBehind(r, sRoot)
		if hit then
			crush(r, sRoot, hit)
		end
	end
end)

return Ride
