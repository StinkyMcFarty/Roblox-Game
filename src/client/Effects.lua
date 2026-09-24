-- Client-only atmosphere: camera shake, snowfall, flickering lights,
-- searchlights, the sniff tracker and the "he's close" dread.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Interface = require(script.Parent.Interface)

local player = Players.LocalPlayer
local Effects = {}

---------------------------------------------------------------------------
-- Camera shake
---------------------------------------------------------------------------

local shake = 0
RunService:BindToRenderStep("WolverineShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shake > 0.001 then
		local cam = workspace.CurrentCamera
		local s = shake
		cam.CFrame = cam.CFrame * CFrame.Angles(
			(math.random() - 0.5) * s * 0.07,
			(math.random() - 0.5) * s * 0.07,
			(math.random() - 0.5) * s * 0.035
		)
		shake = math.max(0, shake - dt * 2.4)
	end
end)

function Effects.Shake(amount)
	shake = math.max(shake, amount)
end

function Effects.ShakeAt(position, intensity, radius)
	local cam = workspace.CurrentCamera
	local d = (cam.CFrame.Position - position).Magnitude
	local falloff = math.clamp(1 - d / (radius or 60), 0, 1)
	if falloff > 0 then
		Effects.Shake(intensity * falloff)
	end
end

---------------------------------------------------------------------------
-- Tint (used by sniff + the Wolverine's hunting vision)
---------------------------------------------------------------------------

-- Lighting zones: bright snowy day in the lobby, dark night in the arena.
local NIGHT, DAY = nil, {
	ClockTime = 15.5, Brightness = 4, ExposureCompensation = -0.15,
	Ambient = Color3.fromRGB(124, 155, 184), OutdoorAmbient = Color3.fromRGB(157, 178, 255),
}
local inLobby = nil
local function applyZone(lobby)
	if inLobby == lobby then
		return
	end
	inLobby = lobby
	if not NIGHT then
		NIGHT = {}
		for k in DAY do
			NIGHT[k] = Lighting[k]
		end
	end
	local target = lobby and DAY or NIGHT
	TweenService:Create(Lighting, TweenInfo.new(1.2), target):Play()
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		-- the lobby is daylit: keep glow tight and subtle there
		TweenService:Create(bloom, TweenInfo.new(1.2), lobby and { Intensity = 0.35, Size = 56, Threshold = 1.6 } or { Intensity = 0.9, Size = 56, Threshold = 1.15 }):Play()
	end
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		TweenService:Create(atmo, TweenInfo.new(1.2), { Density = lobby and 0.25 or 0.3, Haze = lobby and 0.8 or 1.2 }):Play()
	end
end
RunService.Heartbeat:Connect(function()
	applyZone(workspace.CurrentCamera.CFrame.Position.Y > 300)
end)

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "LocalTint"
tint.Parent = Lighting

function Effects.SetHunterVision(on)
	TweenService:Create(tint, TweenInfo.new(1), {
		TintColor = on and Color3.fromRGB(255, 225, 220) or Color3.new(1, 1, 1),
		Contrast = on and 0.1 or 0,
	}):Play()
end

---------------------------------------------------------------------------
-- Roar / gore / hurt
---------------------------------------------------------------------------

function Effects.Roar(position)
	local d = (workspace.CurrentCamera.CFrame.Position - position).Magnitude
	Effects.Shake(math.clamp(1.6 - d / 220, 0.25, 1.6))
	if d < 160 then
		Interface.Flash(Color3.fromRGB(150, 0, 0), 0.35, 0.8)
	end
end

function Effects.Gore(position)
	local d = (workspace.CurrentCamera.CFrame.Position - position).Magnitude
	if d < 40 then
		Interface.Flash(Color3.fromRGB(120, 0, 0), 0.5 * (1 - d / 40), 0.6)
	end
end

function Effects.Hurt()
	Interface.Flash(Color3.fromRGB(200, 0, 0), 0.55, 0.7)
	Effects.Shake(1)
end

function Effects.Knock(velocity, tumble, spin)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum) then
		return
	end
	if tumble then
		-- Ragdoll-ish tumble through the air, then scramble back up
		hum.PlatformStand = true
		Effects.Impulse(root, velocity, 0.15)
		if typeof(spin) == "Vector3" then
			root.AssemblyAngularVelocity = spin
		end
		task.delay(tumble, function()
			if hum.Parent and hum.Health > 0 then
				hum.PlatformStand = false
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	else
		Effects.Impulse(root, velocity, 0.18)
	end
end

-- Short burst of velocity that the Humanoid can't immediately cancel.
function Effects.Impulse(root, velocity, duration)
	local att = Instance.new("Attachment")
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = velocity
	lv.Parent = root
	task.delay(duration, function()
		lv:Destroy()
		att:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Sniff tracker
---------------------------------------------------------------------------

local function decoyMark(position)
	-- A fake scent trail: the gas cloud glows like a survivor would
	local ghost = Instance.new("Part")
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.Size = Vector3.new(2, 5, 1)
	ghost.Material = Enum.Material.Neon
	ghost.Color = Color3.fromRGB(255, 40, 40)
	ghost.Transparency = 0.5
	ghost.Position = position + Vector3.new(0, 2, 0)
	ghost.Parent = workspace.CurrentCamera
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(255, 40, 40)
	hl.OutlineColor = Color3.fromRGB(255, 220, 220)
	hl.FillTransparency = 0.45
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = ghost
	return ghost
end

function Effects.Sniff(duration, targets)
	local marks = {}
	local tracked = {}
	local extraChars = {}
	for _, t in targets or {} do
		if typeof(t.Char) == "Instance" then
			table.insert(extraChars, t.Char)
		elseif t.Name then
			tracked[t.Name] = true
		elseif typeof(t.Position) == "Vector3" then
			local ghost = decoyMark(t.Position)
			local hidingTag = t.Hiding
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(120, 30)
			bb.StudsOffset = Vector3.new(0, 3.5, 0)
			bb.AlwaysOnTop = true
			bb.Adornee = ghost
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBlack
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(255, 80, 80)
			label.TextStrokeTransparency = 0
			label.Parent = bb
			bb.Parent = ghost
			table.insert(marks, { Highlight = ghost, Billboard = bb, Label = label, Part = ghost, Prefix = hidingTag and "HIDING " or "" })
		end
	end
	local toMark = {}
	for _, p in Players:GetPlayers() do
		local role = p:GetAttribute("Role")
		if p ~= player and p.Character and (role == "Survivor" or role == "Sentinel") and (targets == nil or tracked[p.Name]) then
			table.insert(toMark, p.Character)
		end
	end
	for _, c in extraChars do
		table.insert(toMark, c)
	end
	for _, char in toMark do
		do
			local hl = Instance.new("Highlight")
			hl.FillColor = Color3.fromRGB(255, 40, 40)
			hl.OutlineColor = Color3.fromRGB(255, 220, 220)
			hl.FillTransparency = 0.45
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Adornee = char
			hl.Parent = char

			local head = char:FindFirstChild("Head")
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(120, 30)
			bb.StudsOffset = Vector3.new(0, 3.5, 0)
			bb.AlwaysOnTop = true
			bb.Adornee = head
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBlack
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(255, 80, 80)
			label.TextStrokeTransparency = 0
			label.Parent = bb
			bb.Parent = head
			table.insert(marks, { Highlight = hl, Billboard = bb, Label = label, Part = char:FindFirstChild("HumanoidRootPart") })
		end
	end

	TweenService:Create(tint, TweenInfo.new(0.3), { Saturation = -0.85, TintColor = Color3.fromRGB(255, 190, 180) }):Play()
	print(("[Sniff] %d scent(s) marked for %.0fs"):format(#marks, duration or 0))
	Interface.Announce(#marks > 0 and ("You catch their scent...  (%d)"):format(#marks) or "No scent...", Color3.fromRGB(255, 90, 90), 2)
	Effects.Shake(0.3)
	-- a red scent wave rolls out from him
	local myRoot0 = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if myRoot0 then
		local wave = Instance.new("Part")
		wave.Shape = Enum.PartType.Ball
		wave.Anchored, wave.CanCollide, wave.CanQuery, wave.CanTouch, wave.CastShadow = true, false, false, false, false
		wave.Material = Enum.Material.ForceField
		wave.Color = Color3.fromRGB(255, 40, 40)
		wave.Size = Vector3.one * 4
		wave.Position = myRoot0.Position
		wave.Parent = workspace.CurrentCamera
		TweenService:Create(wave, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Size = Vector3.one * 160, Transparency = 1 }):Play()
		task.delay(1, function()
			wave:Destroy()
		end)
	end
	-- screen-edge arrows toward every scent
	local arrowGui = Instance.new("ScreenGui")
	arrowGui.Name = "ScentArrows"
	arrowGui.IgnoreGuiInset = true
	arrowGui.ResetOnSpawn = false
	arrowGui.Parent = player:WaitForChild("PlayerGui")
	local arrows = {}
	for i, m in marks do
		local a = Instance.new("TextLabel")
		a.AnchorPoint = Vector2.new(0.5, 0.5)
		a.Size = UDim2.fromOffset(34, 34)
		a.BackgroundTransparency = 1
		a.Font = Enum.Font.GothamBlack
		a.TextScaled = true
		a.Text = "▲"
		a.TextColor3 = Color3.fromRGB(255, 70, 70)
		a.TextStrokeTransparency = 0.2
		a.Parent = arrowGui
		arrows[i] = a
	end

	local conn = RunService.RenderStepped:Connect(function()
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local cam = workspace.CurrentCamera
		local vp = cam.ViewportSize
		for i, m in marks do
			local r = m.Part
			local arrow = arrows[i]
			if myRoot and r and r.Parent then
				m.Label.Text = (m.Prefix or "") .. math.floor((r.Position - myRoot.Position).Magnitude) .. "m"
				local sp, onScreen = cam:WorldToViewportPoint(r.Position)
				if onScreen and sp.Z > 0 and sp.X > 0 and sp.X < vp.X and sp.Y > 0 and sp.Y < vp.Y then
					arrow.Visible = false
				else
					-- point from screen centre toward the target, pinned to the edge
					local rel = cam.CFrame:PointToObjectSpace(r.Position)
					local dir = Vector2.new(rel.X, -rel.Y)
					if dir.Magnitude < 0.01 then
						dir = Vector2.new(0, 1)
					end
					dir = dir.Unit
					local c = vp / 2
					local k = math.min((c.X - 40) / math.max(math.abs(dir.X), 1e-3), (c.Y - 40) / math.max(math.abs(dir.Y), 1e-3))
					local pos = c + dir * k
					arrow.Visible = true
					arrow.Position = UDim2.fromOffset(pos.X, pos.Y)
					arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
				end
			elseif arrow then
				arrow.Visible = false
			end
		end
	end)
	task.delay(duration, function()
		conn:Disconnect()
		arrowGui:Destroy()
		for _, m in marks do
			m.Highlight:Destroy()
			m.Billboard:Destroy()
		end
		TweenService:Create(tint, TweenInfo.new(0.8), { Saturation = 0 }):Play()
		Effects.SetHunterVision(player:GetAttribute("Role") == "Wolverine")
	end)
end

function Effects.Sniffed()
	Interface.Announce("Wolverine has caught your scent...", Color3.fromRGB(255, 70, 70), 2.5)
	Interface.Flash(Color3.fromRGB(120, 0, 0), 0.25, 1.2)
	Effects.Shake(0.25)
end

---------------------------------------------------------------------------
-- Dread: vignette + heartbeat when Wolverine is near
---------------------------------------------------------------------------

-- Terror radius: a heartbeat that speeds up as he closes in (lub-dub beats
-- scheduled by hand so the tempo tracks distance), plus chase music when he's
-- right on you. Works with the built-in thump until a heartbeat is uploaded.
local TERROR_RADIUS = 90
local CHASE_RADIUS = 36
local uploadedBeat = (Config.UploadedSounds.Heartbeat or 0) ~= 0
local function beatSound(pitch)
	local s = Instance.new("Sound")
	s.SoundId = uploadedBeat and Config.Sounds.Heartbeat or "rbxasset://sounds/action_jump_land.mp3"
	s.PlaybackSpeed = pitch
	s.Parent = workspace.CurrentCamera
	return s
end
local lub, dub = beatSound(uploadedBeat and 1 or 0.34), beatSound(uploadedBeat and 1 or 0.3)
local chase
if Config.Sounds.Chase and Config.Sounds.Chase ~= "" then
	chase = Instance.new("Sound")
	chase.SoundId = Config.Sounds.Chase
	chase.Looped = true
	chase.Volume = 0
	chase.Parent = workspace.CurrentCamera
end
local nextBeat, chaseHold, chaseVol = 0, 0, 0

RunService.Heartbeat:Connect(function(dt)
	local role = player:GetAttribute("Role")
	local level = 0
	local inRound = ReplicatedStorage:GetAttribute("InRound") == true
	if inRound and (role == "Survivor" or role == "Sentinel") then
		local wName = ReplicatedStorage:GetAttribute("Wolverine")
		local wPlayer = wName and Players:FindFirstChild(wName)
		local wRoot = wPlayer and wPlayer.Character and wPlayer.Character:FindFirstChild("HumanoidRootPart")
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if wRoot and myRoot then
			local d = (wRoot.Position - myRoot.Position).Magnitude
			level = math.clamp(1 - (d - 10) / (TERROR_RADIUS - 10), 0, 1)
			if level > 0.75 then
				shake = math.max(shake, (level - 0.75) * 0.5)
			end
			if d < CHASE_RADIUS then
				chaseHold = os.clock() + 4
			end
		end
	end
	Interface.SetDanger(level)

	-- heartbeat: 60 bpm at the edge of the radius, 170 bpm when he's on you
	local now = os.clock()
	if level > 0.02 and now >= nextBeat then
		local bpm = 60 + 110 * level ^ 1.3
		nextBeat = now + 60 / bpm
		local vol = (uploadedBeat and 0.6 or 1.1) * (0.35 + 0.65 * level)
		lub.Volume = vol
		if uploadedBeat then
			-- the uploaded file is a full lub-dub; tighten it as he closes in
			lub.PlaybackSpeed = 1 + level * 0.45
			lub.TimePosition = 0
			lub:Play()
		else
			lub:Play()
			task.delay(math.clamp(0.28 - level * 0.12, 0.14, 0.28), function()
				dub.Volume = vol * 0.75
				dub:Play()
			end)
		end
	elseif level <= 0.02 then
		nextBeat = now
	end

	-- chase music fades in fast, lingers a few seconds after you break away
	if chase then
		local want = (inRound and now < chaseHold) and 0.9 or 0
		chaseVol += (want - chaseVol) * math.min(1, dt * (want > chaseVol and 3 or 0.7))
		chase.Volume = chaseVol
		if chaseVol > 0.01 and not chase.IsPlaying then
			chase:Play()
		elseif chaseVol <= 0.01 and chase.IsPlaying then
			chase:Stop()
		end
	end
end)

---------------------------------------------------------------------------
-- Snow, flickering lights, searchlights
---------------------------------------------------------------------------

local snow = Instance.new("Part")
snow.Name = "SnowEmitter"
snow.Anchored = true
snow.CanCollide = false
snow.CanQuery = false
snow.CanTouch = false
snow.Transparency = 1
snow.Size = Vector3.new(140, 1, 140)
snow.Parent = workspace.CurrentCamera
local flakes = Instance.new("ParticleEmitter")
flakes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
flakes.EmissionDirection = Enum.NormalId.Bottom
flakes.Rate = 350
flakes.Lifetime = NumberRange.new(6, 8)
flakes.Speed = NumberRange.new(6, 10)
flakes.Size = NumberSequence.new(0.18)
flakes.Color = ColorSequence.new(Color3.new(1, 1, 1))
flakes.LightEmission = 0.3
flakes.Acceleration = Vector3.new(3, 0, 1.5)
flakes.SpreadAngle = Vector2.new(15, 15)
flakes.Parent = snow

local baseCFrames = setmetatable({}, { __mode = "k" })
local roofClock, screenClock = 0, 0
local roofParams = RaycastParams.new()
roofParams.FilterType = Enum.RaycastFilterType.Exclude
roofParams.FilterDescendantsInstances = { workspace.CurrentCamera }
local flickerClock = 0
RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	snow.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 35, 0))

	flickerClock += dt
	if flickerClock > 0.07 then
		flickerClock = 0
		for _, p in CollectionService:GetTagged("Flicker") do
			if p:IsA("BasePart") and math.random() < 0.12 then
				local on = math.random() < 0.6
				p.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
				local l = p:FindFirstChildWhichIsA("Light")
				if l then
					l.Enabled = on
				end
			end
		end
		for _, p in CollectionService:GetTagged("FireLight") do
			local l = p:FindFirstChildWhichIsA("Light")
			if l then
				l.Brightness = 1.6 + math.random() * 0.8
			end
		end
	end

	-- no snow indoors: stop emitting when there's a roof over the camera
	roofClock += dt
	if roofClock > 0.4 then
		roofClock = 0
		local hit = workspace:Raycast(cam.CFrame.Position, Vector3.new(0, 120, 0), roofParams)
		flakes.Enabled = hit == nil
	end

	-- facility alarm: once Subject X is loose, beacons spin and alarm strips pulse
	local t = os.clock()
	local alarm = ReplicatedStorage:GetAttribute("Released") == true and ReplicatedStorage:GetAttribute("InRound") == true
	local pulse = 0.5 + 0.5 * math.sin(t * 6)
	for _, b in CollectionService:GetTagged("AlarmBeacon") do
		local beam = b:FindFirstChild("Beam")
		if beam then
			beam.Brightness = alarm and 6 or 0
		end
		if alarm then
			local base = baseCFrames[b]
			if not base then
				base = b.CFrame
				baseCFrames[b] = base
			end
			b.CFrame = base * CFrame.Angles(0, t * 5, 0)
		end
		b.Color = alarm and Color3.fromRGB(255, 40 + 40 * pulse, 30) or Color3.fromRGB(90, 20, 18)
	end
	for _, p in CollectionService:GetTagged("Alarm") do
		p.Transparency = alarm and (0.6 - 0.6 * pulse) or 0
	end
	for _, p in CollectionService:GetTagged("DoorLamp") do
		p.Color = alarm and (pulse > 0.5 and Color3.fromRGB(255, 40, 30) or Color3.fromRGB(80, 10, 8)) or Color3.fromRGB(70, 255, 120)
	end
	-- live screens: flicker LEDs, blink warnings, jiggle bar charts
	screenClock += dt
	if screenClock > 0.15 then
		screenClock = 0
		local screens = CollectionService:GetTagged("LiveScreen")
		for _ = 1, math.min(#screens, 12) do
			local disp = screens[math.random(1, #screens)]
			local gui = disp and disp:FindFirstChildOfClass("SurfaceGui")
			if gui then
				for _, d in gui:GetDescendants() do
					if d.Name == "Blink" and d:IsA("GuiObject") then
						d.Visible = math.random() < 0.7
					elseif d.Name == "Bar" and d:IsA("Frame") then
						d.Size = UDim2.fromScale(d.Size.X.Scale, math.clamp(d.Size.Y.Scale + (math.random() - 0.5) * 0.2, 0.1, 0.85))
					end
				end
			end
		end
	end

	for _, p in CollectionService:GetTagged("Searchlight") do
		if p:IsA("BasePart") then
			local base = baseCFrames[p]
			if not base then
				base = p.CFrame
				baseCFrames[p] = base
			end
			p.CFrame = base * CFrame.Angles(0, t * 0.5 + base.Position.X, 0) * CFrame.Angles(math.rad(-30), 0, 0)
		end
	end
end)

return Effects
