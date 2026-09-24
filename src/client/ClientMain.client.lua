-- Input + role handling. PC keys, gamepad and mobile touch buttons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Interface = require(script.Parent:WaitForChild("Interface"))
local Effects = require(script.Parent:WaitForChild("Effects"))
require(script.Parent:WaitForChild("Shop"))
local Daily = require(script.Parent:WaitForChild("Daily"))
local Anims = require(script.Parent:WaitForChild("Anims"))
local SlashFX = require(script.Parent:WaitForChild("SlashFX"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Ability = Remotes:WaitForChild("Ability")
local Fx = Remotes:WaitForChild("Fx")

local player = Players.LocalPlayer
local A = Config.Abilities
local S = Config.Sentinel

local YELLOW = Color3.fromRGB(255, 200, 30)
local RED = Color3.fromRGB(230, 50, 50)
local ROLE_KIT = {
	Wolverine = {
		{ Name = "Slash", Label = "Claw Slash", Desc = "Shreds survivors and walls", Icon = "🩸", KeyText = "M1", Key = Enum.KeyCode.ButtonR2, Cooldown = A.Slash.Cooldown, Click = true, Color = RED },
		{ Name = "Pounce", Label = "Pounce", Desc = "Leap, pin them down, claw away", Icon = "🐾", KeyText = "Q", Key = Enum.KeyCode.Q, Cooldown = A.Pounce.Cooldown, Color = Color3.fromRGB(255, 140, 30) },
		{ Name = "Stab", Label = "Impale", Desc = "Both claws in. Lift them up", Icon = "🗡️", KeyText = "E", Key = Enum.KeyCode.E, Cooldown = A.Stab.Cooldown, Color = Color3.fromRGB(200, 205, 220) },
		{ Name = "Sniff", Label = "Sniff", Desc = "Sense everyone for " .. A.Sniff.Duration .. "s", Icon = "👃", KeyText = "F", Key = Enum.KeyCode.F, Cooldown = A.Sniff.Cooldown, Color = Color3.fromRGB(200, 60, 255) },
	},
	Survivor = {
		{ Name = "Fart", Label = "Fart", Desc = "Gas cloud throws off his Sniff", Icon = "💨", KeyText = "G", Key = Enum.KeyCode.G, Cooldown = Config.Fart.Cooldown, Color = Color3.fromRGB(150, 210, 50) },
	},
	Sentinel = {
		{ Name = "Punch", Label = "Punch", Desc = "Stun + knockback", Icon = "👊", KeyText = "M1", Key = Enum.KeyCode.ButtonR2, Cooldown = S.Punch.Cooldown, Click = true, Color = Color3.fromRGB(200, 160, 255) },
		{ Name = "Laser", Label = "Laser", Desc = "Burns through walls, exposes bone", Icon = "🔴", KeyText = "Q", Key = Enum.KeyCode.Q, Cooldown = S.Laser.Cooldown, Color = Color3.fromRGB(255, 90, 60) },
		{ Name = "Pulse", Label = "Inhibitor Pulse", Desc = "Stuns him if he's close", Icon = "💥", KeyText = "E", Key = Enum.KeyCode.E, Cooldown = S.Pulse.Cooldown, Color = Color3.fromRGB(255, 210, 60) },
	},
}

local ROLE_HOLDS = {
	Wolverine = {
		{ Name = "SprintHold", Label = "Sprint", Desc = "Run into walls to tear through", Icon = "💨", KeyText = "SHIFT", Attr = "Sprinting", Color = YELLOW },
		{ Name = "FeralHold", Label = "All Fours", Desc = "Fastest. Burns stamina", Icon = "🐺", KeyText = "C", Attr = "Feral", Color = Color3.fromRGB(255, 140, 30) },
	},
	Sentinel = {
		{ Name = "LinkHold", Label = "Link", Desc = "Stay near the other suit: 1.6x power", Icon = "🔗", KeyText = "30m", Attr = "Linked", Color = Color3.fromRGB(190, 140, 255) },
	},
	Survivor = {
		{ Name = "SprintHold", Label = "Sprint", Desc = "Run for your life", Icon = "🏃", KeyText = "SHIFT", Attr = "Sprinting", Color = Color3.fromRGB(80, 170, 255) },
		{ Name = "HideHold", Label = "Hide", Desc = "Lockers, cabinets, crates, freezers", Icon = "🚪", KeyText = "E", Attr = "Hidden", Color = Color3.fromRGB(160, 160, 170) },
	},
}

local ROLE_TITLE = {
	Wolverine = { "WOLVERINE", YELLOW },
	Survivor = { "WEAPON X SCIENTIST", Color3.fromRGB(120, 200, 255) },
	Sentinel = { "SENTINEL SYSTEMS", Color3.fromRGB(190, 140, 255) },
}

local HINTS = {
	Wolverine = "Shift: sprint   C / Ctrl: run on all fours\nRunning into walls tears through them. Hit anyone 3 times to rip them in half.",
	Sentinel = "M1 punch stuns him. Q laser burns through walls. E pulse stuns everything close.\nThe suit dies in " .. S.Duration .. "s — make it count.",
	Survivor = "Subject X is loose. Reboot the 3 Sentinel Protocol consoles (Foundry, Genetics Lab, Command Centre), then suit up in the Hangar.\nShift: sprint. G: fart (hides your scent). He tears through walls — keep moving.",
	Lobby = "Waiting for the next round.",
	Dead = "You were torn apart. Wait for the next round.",
}

local readyAt = {}
local slashSide = 0
local lastPredictedSlash = -1
local PREDICT = { Pounce = "Pounce", Stab = "Impale", Sniff = "Sniff", Punch = "Punch", Laser = "Laser", Pulse = "Pulse", Fart = "Fart" }
local currentKit = {}

local function kitEntry(name)
	for _, a in currentKit do
		if a.Name == name then
			return a
		end
	end
	return nil
end

local function aimPoint()
	local cam = workspace.CurrentCamera
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return cam.CFrame.Position + cam.CFrame.LookVector * 250
	end
	local mouse = player:GetMouse()
	return mouse.Hit.Position
end

local function activate(name)
	local entry = kitEntry(name)
	if not entry then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum) or hum.Health <= 0 then
		return
	end
	if player:GetAttribute("Role") == "Wolverine" and not ReplicatedStorage:GetAttribute("Released") then
		return
	end
	if os.clock() < (readyAt[name] or 0) then
		return
	end
	readyAt[name] = os.clock() + entry.Cooldown
	Interface.StartCooldown(name, entry.Cooldown)

	-- play our own animation instantly (the server's copy is de-duplicated)
	local predict = PREDICT[name]
	if name == "Slash" then
		slashSide = slashSide % 2 + 1
		predict = slashSide == 1 and "SlashR" or "SlashL"
	end
	if predict then
		Anims.Play(char, predict)
	end
	if name == "Slash" then
		-- draw our own claw crescents on the strike frame (the server's copy is skipped)
		local side = slashSide == 1 and "R" or "L"
		lastPredictedSlash = os.clock()
		task.delay(0.12, function()
			if char.Parent and hum.Health > 0 then
				SlashFX.Arc(char, side)
			end
		end)
	end

	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	if name == "Pounce" then
		Effects.Impulse(root, look * A.Pounce.Forward + Vector3.new(0, A.Pounce.Up, 0), 0.22)
		Effects.Shake(0.3)
	elseif name == "Stab" then
		Effects.Impulse(root, look * A.Stab.Lunge * 0.6 + Vector3.new(0, 2, 0), 0.12)
	end

	local arg = nil
	if name == "Laser" then
		arg = aimPoint()
	end
	Ability:FireServer(name, arg)
end

local function unbindAll()
	for _, a in currentKit do
		ContextActionService:UnbindAction("Ability_" .. a.Name)
	end
	ContextActionService:UnbindAction("Feral")
	currentKit = {}
end

local function holdAction(actionName, remoteName, keys, title)
	ContextActionService:BindAction(actionName, function(_, state)
		if state == Enum.UserInputState.Begin then
			Ability:FireServer(remoteName, true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			Ability:FireServer(remoteName, false)
		end
		return Enum.ContextActionResult.Pass
	end, true, table.unpack(keys))
	ContextActionService:SetTitle(actionName, title)
end

local function applyRole(role)
	unbindAll()
	currentKit = ROLE_KIT[role] or {}
	local title = ROLE_TITLE[role]
	Interface.SetAbilities(currentKit, ROLE_HOLDS[role], title and title[1], title and title[2])
	Interface.SetHint(HINTS[role] or "")

	for i, a in currentKit do
		ContextActionService:BindAction("Ability_" .. a.Name, function(_, state)
			if state == Enum.UserInputState.Begin then
				activate(a.Name)
			end
			return Enum.ContextActionResult.Sink
		end, true, a.Key)
		ContextActionService:SetTitle("Ability_" .. a.Name, a.Label)
		ContextActionService:SetPosition("Ability_" .. a.Name, UDim2.new(1, -70 - ((i - 1) % 2) * 70, 1, -200 - math.floor((i - 1) / 2) * 70))
	end
	if role == "Wolverine" then
		holdAction("Feral", "Feral", { Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonL2 }, "Feral")
		ContextActionService:SetPosition("Feral", UDim2.new(1, -210, 1, -130))
	end

	pcall(function()
		game:GetService("ProximityPromptService").Enabled = role ~= "Wolverine" and role ~= "Sentinel"
	end)
	Effects.SetHunterVision(role == "Wolverine")

	if role == "Wolverine" then
		Interface.RoleBanner("YOU ARE WOLVERINE", "Hunt them down. Every kill buys you more time.", Color3.fromRGB(255, 205, 30))
	elseif role == "Survivor" then
		Interface.RoleBanner("SURVIVE", "He's waking up. Get away from the lab.", Color3.fromRGB(230, 230, 235))
	elseif role == "Sentinel" then
		Interface.RoleBanner("SENTINEL ONLINE", "Hunt the mutant.", Color3.fromRGB(200, 160, 255))
	end
end

-- Sprint works for everyone (shift / L3 / touch button)
holdAction("Sprint", "Sprint", { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 }, "Sprint")
ContextActionService:SetPosition("Sprint", UDim2.new(1, -140, 1, -130))

-- Mouse click for M1 abilities
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		for _, a in currentKit do
			if a.Click then
				activate(a.Name)
			end
		end
	end
end)

-- Jump to climb out of a hiding spot
UserInputService.JumpRequest:Connect(function()
	if player:GetAttribute("Hidden") then
		Ability:FireServer("Unhide")
	end
end)
player:GetAttributeChangedSignal("Hidden"):Connect(function()
	if player:GetAttribute("Hidden") then
		Interface.Announce("Hiding... he can still smell you. Jump to get out.", Color3.fromRGB(200, 200, 210), 3)
		Interface.Flash(Color3.new(0, 0, 0), 0.6, 0.6)
	end
end)

-- This game is built for R15 bodies (elbows, knees, waist). Warn if not.
player.CharacterAdded:Connect(function(char)
	task.wait(1)
	if char:FindFirstChild("Torso") and not char:FindFirstChild("UpperTorso") and game:GetService("RunService"):IsStudio() then
		Interface.Announce("R6 avatar detected: set Game Settings > Avatar > Avatar Type to R15 for full animations", Color3.fromRGB(255, 170, 60), 8)
	end
end)

player:GetAttributeChangedSignal("Role"):Connect(function()
	applyRole(player:GetAttribute("Role"))
end)
applyRole(player:GetAttribute("Role"))

---------------------------------------------------------------------------
-- Server effects
---------------------------------------------------------------------------

Fx.OnClientEvent:Connect(function(kind, data)
	data = data or {}
	if kind == "Anim" then
		Anims.Play(data.Char, data.Clip, data.Speed)
	elseif kind == "HitStop" then
		if data.Attacker and (data.Duration or 0) > 0 then
			Anims.HitStop(data.Attacker, data.Duration)
		end
		if data.Victim then
			Anims.Jolt(data.Victim, 1.2)
		end
	elseif kind == "Slash" then
		if not (data.Char == player.Character and os.clock() - lastPredictedSlash < 0.6) then
			SlashFX.Arc(data.Char, data.Side, data.Color)
		end
	elseif kind == "HitFlash" then
		SlashFX.HitFlash(data.Position, data.Color, data.Size, data.Victim)
	elseif kind == "AnimStop" then
		Anims.Stop(data.Char, data.Clip)
	elseif kind == "Announce" then
		Interface.Announce(data.Text, data.Color, data.Duration)
	elseif kind == "Shake" then
		Effects.ShakeAt(data.Position, data.Intensity, data.Radius)
	elseif kind == "Roar" then
		Effects.Roar(data.Position)
	elseif kind == "Knock" then
		Effects.Knock(data.Velocity, data.Tumble, data.Spin)
	elseif kind == "Hurt" then
		Effects.Hurt()
	elseif kind == "Grabbed" then
		Interface.Flash(Color3.fromRGB(160, 0, 0), 0.4, 0.6)
		Effects.Shake(0.8)
	elseif kind == "HitConfirm" then
		Effects.Shake(0.25)
	elseif kind == "Gore" then
		Effects.Gore(data.Position)
	elseif kind == "Sniff" then
		Effects.Sniff(data.Duration, data.Targets)
	elseif kind == "Sniffed" then
		Effects.Sniffed()
	elseif kind == "KillFeed" then
		Interface.KillFeed(data.Text)
	elseif kind == "TimeBonus" then
		Interface.TimeBonus(data.Seconds)
	elseif kind == "Stunned" then
		if data.Name == player.Name then
			Interface.Announce("STUNNED", Color3.fromRGB(255, 210, 60), data.Duration)
		end
	elseif kind == "DailyReward" then
		Daily.ShowReward(data.Amount, data.Streak)
	elseif kind == "Coins" then
		Interface.KillFeed(("+%d coins  (%s)"):format(data.Amount, data.Reason))
	end
end)
