-- Blocking (hold F / L1): Wolverine and the Sentinels (Config.Block).
-- A guard stops M1s from in front and clashes them off in sparks; the hit
-- that uses up the guard breaks it and stuns. Every other attack is a block
-- breaker (Block.Break). Attributes for the client: Blocking, Guard,
-- GuardMax and GuardRefill (server time the guard comes back).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Status = require(script.Parent.Status)
local VFX = require(script.Parent.VFX)
local Combat = require(script.Parent.Combat)

local Fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx")

local Block = {}
local state = setmetatable({}, { __mode = "k" })

local function clipFor(role)
	return role == "Sentinel" and "GuardUp" or "BlockX"
end

local function get(player)
	local role = player:GetAttribute("Role")
	local s = state[player]
	if not s or s.Role ~= role then
		s = { Role = role, Up = false, Guard = Config.Block.Guard[role] or 0, Token = 0 }
		state[player] = s
	end
	return s
end

local function publish(player, s)
	player:SetAttribute("Blocking", s.Up or nil)
	player:SetAttribute("Guard", s.Guard)
	player:SetAttribute("GuardMax", Config.Block.Guard[s.Role])
	player:SetAttribute("GuardRefill", s.RefillAt and workspace:GetServerTimeNow() + (s.RefillAt - os.clock()) or nil)
end

-- the guard comes back `seconds` after letting go (raising it again first
-- puts the refill off until the next time it's lowered)
local function refillLater(player, s, seconds)
	s.Token += 1
	local token = s.Token
	s.RefillAt = os.clock() + seconds
	task.delay(seconds, function()
		if s.Token == token and not s.Up then
			s.Guard = Config.Block.Guard[s.Role] or 0
			s.RefillAt = nil
			if player.Parent then
				publish(player, s)
			end
		end
	end)
end

local function lower(player, s, refill)
	s.Up = false
	if player.Character then
		VFX.StopAnim(player.Character, clipFor(s.Role))
	end
	refillLater(player, s, refill)
	publish(player, s)
end

local function stun(player, seconds)
	if player:GetAttribute("Role") == "Wolverine" and player:GetAttribute("Rage") then
		-- berserk: he shrugs stuns off and is only slowed
		Status.Apply(player, "Slowed", seconds)
		Fx:FireAllClients("Stunned", { Name = player.Name, Duration = seconds, Rage = true })
		return
	end
	Status.Apply(player, "Stunned", seconds)
	Fx:FireAllClients("Stunned", { Name = player.Name, Duration = seconds })
end

-- where the guard is: his crossed claws / the suit's raised forearms
local function guardPoint(player)
	local root = Util.Root(player.Character)
	if not root then
		return nil
	end
	local k = root.Size.Y / 2 -- 1 at normal size, 1.8 for a suit
	return root.Position + root.CFrame.LookVector * 1.4 * k + Vector3.new(0, 1.2 * k, 0)
end
Block.GuardPoint = guardPoint

function Block.Set(player, on)
	local role = player:GetAttribute("Role")
	if role ~= "Wolverine" and role ~= "Sentinel" then
		return
	end
	local s = get(player)
	if not on then
		if s.Up then
			lower(player, s, Config.Block.Refill)
		end
		return
	end
	local char = player.Character
	if s.Up or not Util.IsAlive(char) or s.Guard <= 0 then
		return -- already up, or the guard hasn't come back yet
	end
	if Status.Has(player, "Stunned") or Status.Has(player, "Frozen") or Status.Has(player, "Busy") then
		return
	end
	s.Up = true
	s.Token += 1 -- a pending refill waits for the next time it's lowered
	s.RefillAt = nil
	local token = s.Token
	VFX.Anim(char, clipFor(role))
	publish(player, s)
	task.delay(Config.Block.MaxHold, function()
		if s.Token == token and s.Up then
			lower(player, s, Config.Block.Refill) -- arms give out: can't hold it forever
		end
	end)
end

function Block.IsUp(player)
	local s = state[player]
	return s ~= nil and s.Up
end

-- Is the guard up and turned toward `from`?
function Block.Facing(player, from)
	if not Block.IsUp(player) then
		return false
	end
	local root = Util.Root(player.Character)
	if not root then
		return false
	end
	local to = Vector3.new(from.X - root.Position.X, 0, from.Z - root.Position.Z)
	if to.Magnitude < 0.01 then
		return true
	end
	return Util.Flat(root.CFrame.LookVector):Dot(to.Unit) >= Config.Block.Arc
end

-- steel on steel: sparks fly off the guard back at the attacker, a clang,
-- and the two are shoved apart
function Block.Clash(defender, attacker)
	local dRoot, aRoot = Util.Root(defender.Character), Util.Root(attacker.Character)
	local at = guardPoint(defender)
	if not (dRoot and aRoot and at) then
		return
	end
	local dir = Util.Flat(aRoot.Position - dRoot.Position)
	Combat.MetalSparks(at, dir)
	Util.SoundAt(Config.Sounds.Punch, at, { Volume = 1.6, Pitch = 1.45 + math.random() * 0.15, Range = 180 })
	Fx:FireAllClients("HitStop", { Attacker = attacker.Character, Victim = defender.Character, Duration = 0.09 })
	Fx:FireAllClients("Shake", { Position = at, Intensity = 0.6, Radius = 50 })
	Util.FireClient(Fx, defender, "Knock", { Velocity = -dir * Config.Block.Push, Duration = 0.15 })
	Util.FireClient(Fx, attacker, "Knock", { Velocity = dir * Config.Block.Push * 0.6, Duration = 0.12 })
end

-- The block gives out: the guard's gone, stunned, and it takes
-- BrokenRefill seconds to come back. Every non-M1 attack does this to a
-- raised guard (before landing as usual). Returns whether it was up.
function Block.Break(player)
	local s = state[player]
	if not (s and s.Up) then
		return false
	end
	s.Up = false
	s.Guard = 0
	local char = player.Character
	local at = guardPoint(player)
	if char then
		VFX.StopAnim(char, clipFor(s.Role))
		VFX.Anim(char, "GuardBreak")
	end
	if at then
		VFX.Impact(at, Color3.fromRGB(255, 220, 120), 1.4, char)
		Util.SoundAt(Config.Sounds.Break, at, { Volume = 1.8, Pitch = 1.3, Range = 220 })
		Util.SoundAt(Config.Sounds.Punch, at, { Volume = 1.8, Pitch = 0.8, Range = 220 })
	end
	refillLater(player, s, Config.Block.BrokenRefill)
	publish(player, s)
	stun(player, Config.Block.BreakStun)
	Util.FireClient(Fx, player, "Announce", { Text = "GUARD BROKEN", Color = Color3.fromRGB(255, 90, 60), Duration = 1.5 })
	return true
end

-- An M1 (his slash, a suit's punch) from attacker reaching defender.
-- nil: not blocked, resolve it as usual. "blocked": it clashed off the guard
-- (no damage). "broken": it used up the guard, which breaks (no damage, but
-- they're stunned).
function Block.TryM1(defender, attacker)
	local aRoot = Util.Root(attacker.Character)
	if not (aRoot and Block.Facing(defender, aRoot.Position)) then
		return nil
	end
	local s = state[defender]
	s.Guard -= 1
	Block.Clash(defender, attacker)
	if s.Guard <= 0 then
		Block.Break(defender)
		return "broken"
	end
	publish(defender, s)
	return "blocked"
end

-- new round / out of a suit: guard down and full
function Block.Reset(player)
	state[player] = nil
	player:SetAttribute("Blocking", nil)
	player:SetAttribute("Guard", nil)
	player:SetAttribute("GuardMax", nil)
	player:SetAttribute("GuardRefill", nil)
end

return Block
