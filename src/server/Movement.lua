-- Server-authoritative walk speeds, sprint/feral stamina and status slowdowns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Round = require(script.Parent.Round)
local Status = require(script.Parent.Status)

local Movement = {}
local states = {}

local function getState(player)
	local s = states[player]
	if not s then
		s = { Sprint = false, Feral = false, Stamina = 1, Exhausted = false, FeralOn = false, SentStamina = -1 }
		states[player] = s
	end
	return s
end

function Movement.SetInput(player, key, value)
	local s = getState(player)
	if key == "Sprint" then
		s.Sprint = value == true
	elseif key == "Feral" then
		s.Feral = value == true
	end
end

function Movement.IsCharging(player)
	local s = states[player]
	return s ~= nil and (s.Sprint or s.FeralOn)
end

function Movement.Reset(player)
	states[player] = nil
	player:SetAttribute("Feral", false)
	player:SetAttribute("Sprinting", false)
	player:SetAttribute("Stamina", 1)
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

RunService.Heartbeat:Connect(function(dt)
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = Util.Humanoid(char)
		local root = Util.Root(char)
		if hum and root and hum.Health > 0 then
			local s = getState(player)
			local role = player:GetAttribute("Role")
			local v = root.AssemblyLinearVelocity
			local moving = Vector3.new(v.X, 0, v.Z).Magnitude > 2 or hum.MoveDirection.Magnitude > 0.1
			local speed = Config.Survivor.WalkSpeed
			local feralActive = false
			-- momentum: keep running and you build up to top speed
			local ramp = Config.SprintRamp
			local charging = moving and (s.Sprint or s.Feral) and not s.Exhausted
			s.RunTime = charging and (s.RunTime or 0) + dt or 0
			local build = math.clamp((s.RunTime - ramp.Delay) / ramp.Time, 0, 1)
			build = build * build * (3 - 2 * build) -- smoothstep
			player:SetAttribute("RunBuild", math.floor(build * 20) / 20)

			if role == "Wolverine" then
				local c = Config.Wolverine
				speed = c.WalkSpeed
				if s.Feral and not s.Exhausted and moving then
					speed = c.FeralSpeed + (c.FeralTopSpeed - c.FeralSpeed) * build
					feralActive = true
					s.Stamina = math.max(0, s.Stamina - dt / c.FeralStamina)
					if s.Stamina <= 0 then
						s.Exhausted = true
					end
				else
					if s.Sprint then
						speed = c.SprintSpeed + (c.TopSprintSpeed - c.SprintSpeed) * build
					end
					s.Stamina = math.min(1, s.Stamina + dt * c.FeralRegen / c.FeralStamina)
					if s.Exhausted and s.Stamina > 0.3 then
						s.Exhausted = false
					end
				end
				if not Round.Released then
					speed = 0
				end
			elseif role == "Sentinel" then
				speed = Config.Sentinel.WalkSpeed
			else
				local c = Config.Survivor
				if s.Sprint and moving and not s.Exhausted then
					speed = c.SprintSpeed + (c.TopSpeed - c.SprintSpeed) * build
					s.Stamina = math.max(0, s.Stamina - dt / c.Stamina)
					if s.Stamina <= 0 then
						s.Exhausted = true
					end
				else
					s.Stamina = math.min(1, s.Stamina + dt * c.StaminaRegen / c.Stamina)
					if s.Exhausted and s.Stamina > 0.35 then
						s.Exhausted = false
					end
				end
			end

			if Status.Has(player, "Boost") then
				speed += Config.AdrenalineBonus
			end
			if Status.Has(player, "Slowed") then
				speed *= 0.55
			end
			if Status.Has(player, "Gassed") then
				speed *= Config.Fart.GasSlow
			end
			if Status.Has(player, "Stunned") or Status.Has(player, "Frozen") then
				speed = 0
			end

			if hum.WalkSpeed ~= speed then
				hum.WalkSpeed = speed
			end
			local canJump = speed > 0
			hum.JumpHeight = canJump and 7.2 or 0
			hum.JumpPower = canJump and 50 or 0

			local sprinting = moving and speed > Config.Survivor.WalkSpeed + 1 and not feralActive
				and (s.Sprint or Status.Has(player, "Boost"))
			if sprinting ~= s.SprintOn then
				s.SprintOn = sprinting
				player:SetAttribute("Sprinting", sprinting)
			end

			if feralActive ~= s.FeralOn then
				s.FeralOn = feralActive
				player:SetAttribute("Feral", feralActive)
				if not feralActive then
					s.FeralEnded = os.clock()
				end
			end

			if math.abs(s.Stamina - s.SentStamina) > 0.01 or (s.Stamina == 1 and s.SentStamina ~= 1) then
				s.SentStamina = s.Stamina
				player:SetAttribute("Stamina", s.Stamina)
			end
		end
	end
end)

-- Is he on all fours right now (with a short grace for stride hiccups / lag)?
function Movement.IsFeral(player)
	local s = states[player]
	if player:GetAttribute("Feral") then
		return true
	end
	return s ~= nil and s.FeralEnded ~= nil and os.clock() - s.FeralEnded < 0.35
end

return Movement
