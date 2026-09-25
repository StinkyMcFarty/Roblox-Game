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
require(script.Parent:WaitForChild("Store"))
require(script.Parent:WaitForChild("Spectate"))
require(script.Parent:WaitForChild("SoundCheck"))
require(script.Parent:WaitForChild("HideGlow"))
require(script.Parent:WaitForChild("SentinelTracker"))
require(script.Parent:WaitForChild("TerminalSounds"))
require(script.Parent:WaitForChild("Minimap"))
local Anims = require(script.Parent:WaitForChild("Anims"))
local SlashFX = require(script.Parent:WaitForChild("SlashFX"))
local Minigame = require(script.Parent:WaitForChild("Minigame"))
_G.WolverineShake = function(i)
	Effects.Shake(i)
end

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
		{ Name = "Pounce", Label = "Pounce", Desc = "From all fours: leap, pin them, claw away", Icon = "🐾", KeyText = "Q", Key = Enum.KeyCode.Q, Cooldown = A.Pounce.Cooldown, Color = Color3.fromRGB(255, 140, 30) },
		{ Name = "Stab", Label = "Impale", Desc = "Both claws in. Lift them up", Icon = "🗡️", KeyText = "E", Key = Enum.KeyCode.E, Cooldown = A.Stab.Cooldown, Color = Color3.fromRGB(200, 205, 220) },
		{ Name = "Sniff", Label = "Sniff", Desc = "Sense everyone for " .. A.Sniff.Duration .. "s", Icon = "👃", KeyText = "R", Key = Enum.KeyCode.R, Cooldown = A.Sniff.Cooldown, Color = Color3.fromRGB(200, 60, 255) },
	},
	Survivor = {
		{ Name = "Fart", Label = "Fart", Desc = "Gas cloud throws off his Sniff", Icon = "💨", KeyText = "G", Key = Enum.KeyCode.G, Cooldown = Config.Fart.Cooldown, Color = Color3.fromRGB(150, 210, 50) },
	},
	Sentinel = {
		{ Name = "Punch", Label = "Hydraulic Smash", Desc = "Piston-driven haymaker. Smashes through walls, stuns and launches him", Icon = "👊", KeyText = "M1", Key = Enum.KeyCode.ButtonR2, Cooldown = S.Punch.Cooldown, Click = true, Color = Color3.fromRGB(200, 160, 255) },
		{ Name = "Laser", Label = "Death Ray", Desc = "Melts through walls. Burns him to the adamantium", Icon = "🔴", KeyText = "Q", Key = Enum.KeyCode.Q, Cooldown = S.Laser.Cooldown, Color = Color3.fromRGB(255, 90, 60) },
		{ Name = "Pulse", Label = "Inhibitor Blast", Desc = "Charge 2s (E again to cancel). Stuns him for 3s", Icon = "💥", KeyText = "E", Key = Enum.KeyCode.E, Cooldown = S.Pulse.Cooldown, Color = Color3.fromRGB(255, 210, 60) },
	},
}

local ROLE_HOLDS = {
	Wolverine = {
		{ Name = "SprintHold", Label = "Sprint", Desc = "Run into walls to tear through", Icon = "💨", KeyText = "SHIFT", Attr = "Sprinting", Color = YELLOW },
		{ Name = "FeralHold", Label = "All Fours", Desc = "Fastest. Burns stamina", Icon = "🐺", KeyText = "C", Attr = "Feral", Color = Color3.fromRGB(255, 140, 30) },
	},
	Sentinel = {
		{ Name = "LinkHold", Label = "Twin Link", Desc = "Beside the other suit: " .. S.LinkedMultiplier .. "x. Apart: " .. S.SoloMultiplier .. "x", Icon = "🔗", KeyText = "30m", Attr = "Linked", Color = Color3.fromRGB(190, 140, 255) },
		{ Name = "PursuitHold", Label = "Pursuit", Desc = "Thrusters kick in when he runs " .. S.Pursuit.Start .. "+ studs away", Icon = "🚀", KeyText = "AUTO", Attr = "Pursuit", Color = Color3.fromRGB(255, 120, 60) },
	},
	Survivor = {
		{ Name = "SprintHold", Label = "Sprint", Desc = "Run for your life", Icon = "🏃", KeyText = "SHIFT", Attr = "Sprinting", Color = Color3.fromRGB(80, 170, 255) },
		{ Name = "HideHold", Label = "Hide", Desc = "Lockers, cabinets, crates, freezers", Icon = "🚪", KeyText = "E", Attr = "Hidden", Color = Color3.fromRGB(160, 160, 170) },
	},
}

local ROLE_TITLE = {
	Wolverine = { "WOLVERINE", YELLOW },
	Survivor = { "WEAPON X SCIENTIST", Color3.fromRGB(120, 200, 255) },
	Sentinel = { "SENTINEL MK. I", Color3.fromRGB(190, 140, 255) },
}

local HINTS = {
	Wolverine = "Shift: sprint   C / Ctrl: run on all fours\nClaw (M1) or pounce through walls. Hit anyone 3 times to rip them in half.",
	Sentinel = "MUTANT-HUNTER ONLINE. M1 Hydraulic Smash · Q Death Ray · E Inhibitor Blast.\nLinked: " .. S.LinkedMultiplier .. "x power. Apart: " .. S.SoloMultiplier .. "x. Last suit standing: 1x. Core burns out in " .. S.Duration .. "s.",
	Survivor = "Subject X is loose. Reboot the 3 Sentinel Protocol consoles (Foundry, Genetics Lab, Command Centre), then suit up in the Hangar.\nShift: sprint. G: fart (hides your scent). He tears through walls — keep moving.",
	Lobby = "Waiting for the next round.",
	Dead = "You were torn apart. Wait for the next round.",
}

local readyAt = {}
local slashSide = 0
local lastPredictedSlash = -1
local PREDICT = { Pounce = "Pounce", Stab = "Impale", Sniff = "Sniff", Punch = "Punch", Laser = "DeathRay", Pulse = "PulseCharge", Fart = "Fart" }
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
	-- under a Sentinel death ray, R (Sniff) is mashed to force through it
	if name == "Sniff" and workspace:GetServerTimeNow() - (player:GetAttribute("BeamedAt") or 0) < 0.4 then
		Ability:FireServer("Resist")
		Effects.ResistPress()
		return
	end
	-- pressing the blast key again while it's charging cancels it
	if name == "Pulse" and player:GetAttribute("PulseCharging") then
		Ability:FireServer("Pulse")
		return
	end
	if os.clock() < (readyAt[name] or 0) then
		return
	end
	if player:GetAttribute("Role") == "Sentinel" and player:GetAttribute("Acting") then
		return -- one Sentinel move at a time
	end
	if name == "Pounce" and not player:GetAttribute("Feral") then
		Interface.Announce("Get on all fours to pounce (hold C)", Color3.fromRGB(255, 140, 30), 1.2)
		return
	end
	-- enraged (Config.Rage): slashes come faster, everything else cools down quicker
	local cooldown = entry.Cooldown
	if player:GetAttribute("Rage") and player:GetAttribute("Role") == "Wolverine" then
		cooldown *= name == "Slash" and 1 / Config.Rage.AttackSpeed or Config.Rage.Cooldown
	end
	readyAt[name] = os.clock() + cooldown
	Interface.StartCooldown(name, cooldown)

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
		task.delay(player:GetAttribute("Rage") and 0.12 / Config.Rage.AttackSpeed or 0.12, function()
			if char.Parent and hum.Health > 0 then
				SlashFX.Arc(char, side)
			end
		end)
	end

	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	if name == "Pounce" then
		Effects.Leap(root, look * A.Pounce.Forward, A.Pounce.Height, A.Pounce.AirTime, A.Pounce.Window)
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
---------------------------------------------------------------------------
-- Shift lock on Left Alt (Shift is sprint): mouse locked to the centre,
-- over-the-shoulder camera, character turns with the camera.
---------------------------------------------------------------------------
local RunServiceSL = game:GetService("RunService")
local shiftLock = false
local crosshair = Instance.new("ScreenGui")
crosshair.Name = "ShiftLock"
crosshair.IgnoreGuiInset = true
crosshair.ResetOnSpawn = false
crosshair.Enabled = false
crosshair.Parent = player:WaitForChild("PlayerGui")
for _, sz in { Vector2.new(14, 2), Vector2.new(2, 14) } do
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(sz.X, sz.Y)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.2
	f.BorderSizePixel = 0
	f.Parent = crosshair
end

local function setShiftLock(on)
	shiftLock = on
	crosshair.Enabled = on
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = not on
		hum.CameraOffset = on and Vector3.new(1.75, 0.3, 0) or Vector3.zero
	end
	if not on then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.LeftAlt then
		setShiftLock(not shiftLock)
	end
end)
player.CharacterAdded:Connect(function()
	task.defer(setShiftLock, shiftLock)
end)

RunServiceSL:BindToRenderStep("AltShiftLock", Enum.RenderPriority.Camera.Value + 1, function()
	if not shiftLock then
		return
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum) or root.Anchored or hum.Health <= 0 or hum.Sit then
		return
	end
	hum.AutoRotate = false
	local look = workspace.CurrentCamera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
end)

-- While the death ray is live: stream the aim point and turn the suit to face it
local aimClock = 0
game:GetService("RunService").RenderStepped:Connect(function(dt)
	if not player:GetAttribute("Beaming") then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum) then
		return
	end
	local target = aimPoint()
	local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	if flat.Magnitude > 1 then
		hum.AutoRotate = false
		root.CFrame = root.CFrame:Lerp(CFrame.lookAt(root.Position, root.Position + flat), math.min(1, dt * 8))
	end
	aimClock += dt
	if aimClock > 0.066 then
		aimClock = 0
		Ability:FireServer("LaserAim", target)
	end
end)
player:GetAttributeChangedSignal("Beaming"):Connect(function()
	if not player:GetAttribute("Beaming") and not shiftLock then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.AutoRotate = true
		end
	end
end)

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

player:GetAttributeChangedSignal("Rage"):Connect(function()
	local on = player:GetAttribute("Rage") == true and player:GetAttribute("Role") == "Wolverine"
	Effects.SetRage(on)
	if on then
		Interface.Announce(("RAGE! %ds: faster slashes, harder hits, quicker cooldowns"):format(Config.Rage.Duration), Color3.fromRGB(255, 60, 40), 3)
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
	elseif kind == "Minigame" then
		local term = data.Terminal
		Minigame.Start(term, data.Challenge, function(ok, cancelled)
			Ability:FireServer("TerminalResult", { Terminal = term, Ok = ok, Cancel = cancelled })
		end)
	elseif kind == "Noise" then
		-- a survivor botched a repair: Wolverine sees where the alarm went off
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
		p.Size = Vector3.one
		p.Position = data.Position
		p.Parent = workspace
		local bb = Instance.new("BillboardGui")
		bb.AlwaysOnTop = true
		bb.Size = UDim2.fromOffset(90, 40)
		bb.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(255, 70, 60)
		t.TextStrokeTransparency = 0.3
		t.Text = "⚠ " .. (data.Text or "NOISE")
		t.Parent = bb
		game:GetService("TweenService"):Create(t, TweenInfo.new(5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		game:GetService("Debris"):AddItem(p, 5.2)
	elseif kind == "PulseCharge" then
		SlashFX.PulseCharge(data.Char, data.Time)
	elseif kind == "PulseCancel" then
		SlashFX.PulseCancel(data.Char)
		if data.Char == player.Character then
			readyAt.Pulse = os.clock() + Config.Sentinel.Pulse.CancelCooldown
			Interface.StartCooldown("Pulse", Config.Sentinel.Pulse.CancelCooldown)
		end
	elseif kind == "PulseBlast" then
		SlashFX.PulseBlast(data.Position, data.Radius)
	elseif kind == "LaserCharge" then
		SlashFX.LaserCharge(data.Char, data.Time)
	elseif kind == "LaserBeam" then
		SlashFX.BeamUpdate(data.Char, data.From, data.To, data.Hit, data.Burns)
	elseif kind == "LaserEnd" then
		SlashFX.BeamEnd(data.Char)
	elseif kind == "Smash" then
		SlashFX.Smash(data.Char, data.Position, data.Dir, data.Hit)
	elseif kind == "HitFlash" then
		SlashFX.HitFlash(data.Position, data.Color, data.Size, data.Victim, data.Claw)
	elseif kind == "AnimStop" then
		Anims.Stop(data.Char, data.Clip)
	elseif kind == "Announce" then
		Interface.Announce(data.Text, data.Color, data.Duration)
	elseif kind == "Shake" then
		Effects.ShakeAt(data.Position, data.Intensity, data.Radius)
	elseif kind == "Roar" then
		Effects.Roar(data.Position)
	elseif kind == "Knock" then
		Effects.Knock(data.Velocity, data.Tumble, data.Spin, data.Duration)
	elseif kind == "Hurt" then
		Effects.Hurt()
	elseif kind == "Grabbed" then
		Interface.Flash(Color3.fromRGB(160, 0, 0), 0.4, 0.6)
		Effects.Shake(0.8)
	elseif kind == "ClawLock" then
		-- his slash landed: these attacks wait (unless already cooling down longer)
		local seconds = tonumber(data.Seconds) or 0
		for _, name in data.Abilities or {} do
			if (readyAt[name] or 0) < os.clock() + seconds then
				readyAt[name] = os.clock() + seconds
				Interface.StartCooldown(name, seconds)
			end
		end
	elseif kind == "HitConfirm" then
		Effects.Shake(0.25)
	elseif kind == "Gore" then
		Effects.Gore(data.Position)
	elseif kind == "Sniff" then
		Effects.Sniff(data.Duration, data.Targets)
	elseif kind == "SniffUpdate" then
		Effects.SniffUpdate(data.Targets)
	elseif kind == "Sniffed" then
		Effects.Sniffed()
	elseif kind == "KillFeed" then
		Interface.KillFeed(data.Text)
	elseif kind == "TimeBonus" then
		Interface.TimeBonus(data.Seconds)
	elseif kind == "IntroCam" then
		Effects.IntroCam(data)
	elseif kind == "Gassed" then
		Interface.Announce("GASSED!", Color3.fromRGB(150, 220, 60), data.Duration)
		Interface.Flash(Color3.fromRGB(110, 170, 30), 0.45, data.Duration)
		Effects.Shake(0.4)
	elseif kind == "Stunned" then
		if data.Name == player.Name then
			Interface.Announce("STUNNED", Color3.fromRGB(255, 210, 60), data.Duration)
		end
	elseif kind == "DailyReward" then
		Daily.ShowReward(data.Amount, data.Streak)
	elseif kind == "Coins" then
		Interface.KillFeed(("+%d %s  (%s)"):format(data.Amount, Config.CoinName, data.Reason))
	end
end)
