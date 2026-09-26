-- Client-only atmosphere: camera shake, snowfall, flickering lights,
-- searchlights, the sniff tracker and the "he's close" dread.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

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
-- the player's brightness setting (Config.Brightness), applied on top of the zone
local brightness = Config.Brightness.Levels[Config.Brightness.Default]
local function scaled(c, k)
	return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end
local function applyZone(lobby, force)
	if inLobby == lobby and not force then
		return
	end
	inLobby = lobby
	if not NIGHT then
		NIGHT = {}
		for k in DAY do
			NIGHT[k] = Lighting[k]
		end
	end
	local target = table.clone(lobby and DAY or NIGHT)
	target.ExposureCompensation += brightness.Exposure
	target.Ambient = scaled(target.Ambient, brightness.Ambient)
	target.OutdoorAmbient = scaled(target.OutdoorAmbient, brightness.Ambient)
	TweenService:Create(Lighting, TweenInfo.new(force and 0.4 or 1.2), target):Play()
	if force then
		return
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		-- the lobby is daylit: keep glow tight and subtle there
		TweenService:Create(bloom, TweenInfo.new(1.2), lobby and { Intensity = 0.35, Size = 56, Threshold = 1.6 } or { Intensity = 0.55, Size = 40, Threshold = 1.35 }):Play()
	end
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		TweenService:Create(atmo, TweenInfo.new(1.2), { Density = lobby and 0.25 or 0.3, Haze = lobby and 0.8 or 1.2 }):Play()
	end
end
RunService.Heartbeat:Connect(function()
	applyZone(workspace.CurrentCamera.CFrame.Position.Y > 300)
end)

-- Brightness setting (1..#Config.Brightness.Levels): the sun button calls this
-- straight away; the saved level arrives as the "Brightness" attribute.
function Effects.SetBrightness(level)
	local l = Config.Brightness.Levels[tonumber(level) or 0]
	if not l or l == brightness then
		return
	end
	brightness = l
	if inLobby ~= nil then
		applyZone(inLobby, true)
	end
end
player:GetAttributeChangedSignal("Brightness"):Connect(function()
	Effects.SetBrightness(player:GetAttribute("Brightness"))
end)
Effects.SetBrightness(player:GetAttribute("Brightness"))

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "LocalTint"
tint.Parent = Lighting

-- Rage: his view runs hot red while it lasts
function Effects.SetRage(on)
	if on then
		TweenService:Create(tint, TweenInfo.new(0.4), { TintColor = Color3.fromRGB(255, 175, 165), Contrast = 0.22, Saturation = 0.15 }):Play()
	else
		TweenService:Create(tint, TweenInfo.new(1), { Saturation = 0 }):Play()
		Effects.SetHunterVision(player:GetAttribute("Role") == "Wolverine")
	end
end

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

-- The rage roar lands: his own camera punches out and shudders under a red
-- flash; everyone else feels it by how close they are.
function Effects.RageRoar(char)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local cam = workspace.CurrentCamera
	if char == player.Character then
		Effects.Shake(1.6)
		Interface.Flash(Color3.fromRGB(190, 0, 0), 0.45, 0.9)
		local fov = cam.FieldOfView
		local out = TweenService:Create(cam, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov + 14 })
		out:Play()
		out.Completed:Once(function()
			TweenService:Create(cam, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { FieldOfView = fov }):Play()
		end)
	else
		local d = (cam.CFrame.Position - root.Position).Magnitude
		Effects.Shake(math.clamp(1.4 - d / 90, 0, 1.4))
		if d < 70 then
			Interface.Flash(Color3.fromRGB(150, 0, 0), 0.3 * (1 - d / 70), 0.7)
		end
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

-- Pounce leap: the root is driven along a set arc (rise `height` studs, land
-- after `airTime` seconds, moving at `horizontal`), so the Humanoid's own
-- ground control can't drag it down early. It ends as soon as he's back at
-- standing height over the floor, runs into a wall, maxTime passes, or
-- something knocks him.
local activeLeap = nil
function Effects.CancelLeap()
	if activeLeap then
		activeLeap:Destroy()
		activeLeap = nil
	end
end

function Effects.Leap(root, horizontal, height, airTime, maxTime)
	Effects.CancelLeap()
	local char = root.Parent
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local up = 4 * height / airTime -- a parabola that peaks at `height` halfway through
	local fall = 8 * height / airTime ^ 2
	local stand = (hum and hum.HipHeight or 2) + root.Size.Y / 2
	local att = Instance.new("Attachment")
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = horizontal + Vector3.new(0, up, 0)
	lv.Parent = att
	activeLeap = att
	if hum then
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	-- breakable walls (and the chunks flying off them) don't stop the dive:
	-- just ahead of him they're made passable on this client, which runs his
	-- body, and the server smashes them as he goes through (the pounce's
	-- BreakInBox), so he keeps his speed. Unbreakable walls still stop him.
	local passed = {}
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { char }
	local flat = Vector3.new(horizontal.X, 0, horizontal.Z)
	local dir = flat.Magnitude > 0.01 and flat.Unit or root.CFrame.LookVector
	local function clearAhead()
		local cf = CFrame.lookAt(root.Position, root.Position + dir) * CFrame.new(0, 0, -3.5)
		for _, p in workspace:GetPartBoundsInBox(cf, Vector3.new(7, 9, 7), overlap) do
			if p.CanCollide and not passed[p] and (p:GetAttribute("Breakable") or (p.Parent and p.Parent.Name == "Debris")) then
				passed[p] = true
				p.CanCollide = false
			end
		end
	end
	clearAhead()
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		local vy = up - fall * t
		clearAhead()
		local done = activeLeap ~= att or not att.Parent or t > (maxTime or 1.2)
		if not done and vy < 0 then
			-- coming down: stop when the floor is right under his feet
			done = workspace:Raycast(root.Position, Vector3.new(0, -(stand + 0.6), 0), params) ~= nil
		end
		if not done and t > 0.15 then
			local v = root.AssemblyLinearVelocity
			done = Vector3.new(v.X, 0, v.Z).Magnitude < horizontal.Magnitude * 0.3 -- hit a wall
		end
		if done then
			conn:Disconnect()
			att:Destroy()
			task.delay(0.6, function()
				-- anything he passed that the server didn't smash is solid again
				for p in passed do
					if p.Parent and not p:GetAttribute("Broken") then
						p.CanCollide = true
					end
				end
			end)
			if activeLeap == att then
				activeLeap = nil
				-- touch down still moving, but at running pace rather than dive speed
				if horizontal.Magnitude > 0 then
					root.AssemblyLinearVelocity = horizontal.Unit * math.min(horizontal.Magnitude, 30)
				end
			end
			return
		end
		lv.VectorVelocity = horizontal + Vector3.new(0, vy, 0)
	end)
end

function Effects.Knock(velocity, tumble, spin, duration)
	Effects.CancelLeap()
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
		Effects.Impulse(root, velocity, tonumber(duration) or 0.18)
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
-- Death-ray resist prompt (Wolverine): "MASH F" with a fill meter
---------------------------------------------------------------------------

local resistPresses = {}
local resistGui = Instance.new("ScreenGui")
resistGui.Name = "BeamResist"
resistGui.ResetOnSpawn = false
resistGui.Enabled = false
resistGui.Parent = player:WaitForChild("PlayerGui")
local resistFrame = Instance.new("Frame")
resistFrame.AnchorPoint = Vector2.new(0.5, 0.5)
resistFrame.Position = UDim2.fromScale(0.5, 0.7)
resistFrame.Size = UDim2.fromOffset(300, 58)
resistFrame.BackgroundColor3 = Color3.fromRGB(14, 12, 20)
resistFrame.BackgroundTransparency = 0.2
resistFrame.Parent = resistGui
Instance.new("UICorner", resistFrame).CornerRadius = UDim.new(0, 10)
local resistStroke = Instance.new("UIStroke", resistFrame)
resistStroke.Color = Color3.fromRGB(255, 60, 40)
resistStroke.Thickness = 2
local resistScale = Instance.new("UIScale", resistFrame)
local resistText = Instance.new("TextLabel")
resistText.Position = UDim2.fromOffset(10, 4)
resistText.Size = UDim2.new(1, -20, 0, 26)
resistText.BackgroundTransparency = 1
resistText.Font = Enum.Font.GothamBlack
resistText.TextScaled = true
resistText.TextColor3 = Color3.new(1, 1, 1)
resistText.Parent = resistFrame
local resistBar = Instance.new("Frame")
resistBar.Position = UDim2.fromOffset(12, 36)
resistBar.Size = UDim2.new(1, -24, 0, 12)
resistBar.BackgroundColor3 = Color3.fromRGB(40, 36, 48)
resistBar.Parent = resistFrame
Instance.new("UICorner", resistBar).CornerRadius = UDim.new(1, 0)
local resistFill = Instance.new("Frame")
resistFill.Size = UDim2.fromScale(0, 1)
resistFill.BackgroundColor3 = Color3.fromRGB(255, 120, 40)
resistFill.Parent = resistBar
Instance.new("UICorner", resistFill).CornerRadius = UDim.new(1, 0)
local resistMark = Instance.new("Frame") -- the brace threshold
resistMark.AnchorPoint = Vector2.new(0.5, 0.5)
resistMark.Position = UDim2.fromScale(Config.Sentinel.Laser.Resist.Threshold, 0.5)
resistMark.Size = UDim2.new(0, 2, 1, 6)
resistMark.BackgroundColor3 = Color3.new(1, 1, 1)
resistMark.Parent = resistBar

function Effects.ResistPress()
	table.insert(resistPresses, os.clock())
	resistScale.Scale = 1.08
	TweenService:Create(resistScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
end

RunService.RenderStepped:Connect(function()
	local beamed = player:GetAttribute("Role") == "Wolverine"
		and workspace:GetServerTimeNow() - (player:GetAttribute("BeamedAt") or 0) < 0.4
	resistGui.Enabled = beamed
	if not beamed then
		table.clear(resistPresses)
		return
	end
	local now = os.clock()
	while resistPresses[1] and now - resistPresses[1] > 1 do
		table.remove(resistPresses, 1)
	end
	local level = math.clamp(#resistPresses / Config.Sentinel.Laser.Resist.Presses, 0, 1)
	resistFill.Size = UDim2.fromScale(level, 1)
	local bracing = level >= Config.Sentinel.Laser.Resist.Threshold
	resistFill.BackgroundColor3 = bracing and Color3.fromRGB(255, 220, 90) or Color3.fromRGB(255, 120, 40)
	local key = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and "TAP SNIFF" or "MASH F"
	resistText.Text = bracing and "PUSHING THROUGH — KEEP MASHING!" or (key .. " TO PUSH THROUGH THE BEAM")
end)

---------------------------------------------------------------------------
-- Intro camera (Wolverine only): watch yourself smash out of the tank
---------------------------------------------------------------------------

function Effects.IntroCam(data)
	local cam = workspace.CurrentCamera
	if typeof(data.Tank) ~= "Vector3" or typeof(data.Land) ~= "Vector3" then
		return
	end
	local dir = typeof(data.Dir) == "Vector3" and data.Dir or Vector3.zAxis
	local side = dir:Cross(Vector3.yAxis)
	local start = os.clock()
	local burst, release = data.Burst or 3, data.Release or 8
	local SWING = 0.8 -- the flying kick (0.42s on the server) plus the landing
	-- the camera's three marks: pushed in on the tank, then pulled back ahead
	-- of the landing spot, then tight on the X
	local tankEye = data.Tank + dir * 11 + side * 1
	local landEye = data.Land + dir * 11 + side * 1.5 + Vector3.new(0, 0.6, 0)
	-- keep the camera out of walls (the tank's own glass and fluid don't count)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local ignore = {}
	for _, name in { "TankGlass", "TankLiquid" } do
		local part = workspace:FindFirstChild(name, true)
		if part then
			table.insert(ignore, part)
		end
	end
	local focus = nil
	cam.CameraType = Enum.CameraType.Scriptable
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - start
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		-- track him wherever he actually is (smoothed, so replication jitter
		-- doesn't shake the shot); the tank until he's loaded in
		local target = root and root.Position or data.Tank
		focus = focus and focus:Lerp(target, 1 - math.exp(-dt * 16)) or target
		local eye, look
		if t < burst then
			-- slow push in on the tank, low angle, on him as he floats and kicks
			local u = t / burst
			eye = data.Tank + dir * (15 - 4 * u) + side * (3 - 2 * u) + Vector3.new(0, -1 + u, 0)
			look = focus + Vector3.new(0, 0.3, 0)
		elseif t < burst + SWING then
			-- the flying kick: the camera swings back and out to the side ahead
			-- of him, following him through the air to the landing
			local u = (t - burst) / SWING
			local e = 1 - (1 - u) ^ 2
			local arc = math.sin(u * math.pi)
			eye = tankEye:Lerp(landEye, e) + side * arc * 3 + Vector3.new(0, arc * 1.2, 0)
			look = focus + Vector3.new(0, 0.3 + 1.1 * e, 0)
		else
			-- in front of the landing spot, tight on the X
			local u = math.clamp((t - burst - SWING) / 1.2, 0, 1)
			local ease = 1 - (1 - u) ^ 3
			eye = data.Land + dir * (11 - 3.5 * ease) + side * (1.5 - 1.5 * ease) + Vector3.new(0, 0.6, 0)
			look = focus + Vector3.new(0, 1.4 - 0.6 * ease, 0)
		end
		if char then
			ignore[#ignore + 1] = char
			params.FilterDescendantsInstances = ignore
			ignore[#ignore] = nil
			local hit = workspace:Raycast(look, eye - look, params)
			if hit then
				eye = hit.Position + (look - eye).Unit * 0.6
			end
		end
		cam.CFrame = CFrame.lookAt(eye, look)
		if t > release - 0.6 or player:GetAttribute("Role") ~= "Wolverine" then
			conn:Disconnect()
			cam.CameraType = Enum.CameraType.Custom
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				cam.CameraSubject = hum
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Sniff tracker
---------------------------------------------------------------------------

-- Every scent (a real survivor, a hiding spot or a fart decoy) is drawn the
-- same way, a red body outline seen through walls, so Wolverine can't tell a decoy
-- from a person. Positions stream from the server (SniffUpdate), so it works
-- at any range and doesn't depend on the target's character being loaded.
local SCENT = Color3.fromRGB(255, 40, 40)
local GHOST_PARTS = {
	{ Vector3.new(2, 2, 1), Vector3.new(0, 0, 0) }, -- torso
	{ Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.65, 0) }, -- head
	{ Vector3.new(1, 2, 1), Vector3.new(-1.55, 0, 0) },
	{ Vector3.new(1, 2, 1), Vector3.new(1.55, 0, 0) },
	{ Vector3.new(0.95, 2, 1), Vector3.new(-0.5, -2, 0) },
	{ Vector3.new(0.95, 2, 1), Vector3.new(0.5, -2, 0) },
}

local function scentGhost(big)
	local model = Instance.new("Model")
	model.Name = "Scent"
	local scale = big and 1.8 or 1
	local core
	for i, spec in GHOST_PARTS do
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = SCENT
		p.Transparency = 0.99 -- only the outline shows (Highlight skips fully transparent parts)
		p.Size = spec[1] * scale
		p:SetAttribute("Offset", spec[2] * scale)
		p.Parent = model
		-- a see-through red body drawn through walls. The Highlight below adds the
		-- crisp outline, but Highlights can fail to show live (the client caps how
		-- many draw at once), so the ghost must not depend on it.
		local box = Instance.new("BoxHandleAdornment")
		box.Adornee = p
		box.AlwaysOnTop = true
		box.ZIndex = 1
		box.Size = p.Size
		box.Color3 = SCENT
		box.Transparency = 0.6
		box.Parent = p
		if i == 1 then
			core = p
		end
	end
	model.PrimaryPart = core
	local hl = Instance.new("Highlight")
	hl.FillColor = SCENT
	hl.FillTransparency = 1
	hl.OutlineColor = SCENT
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Adornee = model
	hl.Parent = model
	-- a local folder in the workspace rather than the camera: Highlights and
	-- adornments under the camera may not draw in the live game
	local folder = workspace:FindFirstChild("ScentGhosts")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ScentGhosts"
		folder.Parent = workspace
	end
	model.Parent = folder
	return { Model = model, Core = core }
end

local function placeGhost(m, cf)
	for _, p in m.Model:GetChildren() do
		if p:IsA("BasePart") then
			p.CFrame = cf * CFrame.new(p:GetAttribute("Offset"))
		end
	end
end

local sniffMarks = nil -- [Id] = mark, while a sniff is live

local function syncScents(targets)
	if not sniffMarks then
		return
	end
	local seen = {}
	for _, t in targets or {} do
		if type(t.Id) == "string" and typeof(t.Position) == "Vector3" then
			seen[t.Id] = true
			local m = sniffMarks[t.Id]
			if m and m.Big ~= (t.Big == true) then
				m.Model:Destroy()
				m = nil
			end
			if not m then
				m = scentGhost(t.Big)
				m.Big = t.Big == true
				m.CF = CFrame.new(t.Position) * CFrame.Angles(0, tonumber(t.Yaw) or 0, 0)
				placeGhost(m, m.CF)
				sniffMarks[t.Id] = m
			end
			m.Goal = CFrame.new(t.Position) * CFrame.Angles(0, tonumber(t.Yaw) or 0, 0)
		end
	end
	for id, m in sniffMarks do
		if not seen[id] then
			m.Model:Destroy()
			sniffMarks[id] = nil
		end
	end
end

function Effects.SniffUpdate(targets)
	syncScents(targets)
end

function Effects.Sniff(duration, targets)
	if sniffMarks then
		for _, m in sniffMarks do
			m.Model:Destroy()
		end
	end
	sniffMarks = {}
	local myMarks = sniffMarks
	syncScents(targets)
	local count = 0
	for _ in sniffMarks do
		count += 1
	end
	print(("[Sniff] %d scent(s) from the server, %d drawn"):format(type(targets) == "table" and #targets or -1, count))

	TweenService:Create(tint, TweenInfo.new(0.3), { Saturation = -0.85, TintColor = Color3.fromRGB(255, 190, 180) }):Play()
	Interface.Announce(count > 0 and ("You catch their scent...  (%d)"):format(count) or "No scent...", Color3.fromRGB(255, 90, 90), 2)
	Effects.Shake(0.3)
	-- a red scent wave rolls out from him
	local myRoot0 = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if myRoot0 then
		local wave = Instance.new("Part")
		wave.Shape = Enum.PartType.Ball
		wave.Anchored, wave.CanCollide, wave.CanQuery, wave.CanTouch, wave.CastShadow = true, false, false, false, false
		wave.Material = Enum.Material.ForceField
		wave.Color = SCENT
		wave.Size = Vector3.one * 4
		wave.Position = myRoot0.Position
		wave.Parent = workspace.CurrentCamera
		TweenService:Create(wave, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Size = Vector3.one * 160, Transparency = 1 }):Play()
		task.delay(1, function()
			wave:Destroy()
		end)
	end
	local conn = RunService.RenderStepped:Connect(function(dt)
		local alpha = math.min(1, dt * 12)
		for _, m in myMarks do
			m.CF = m.CF:Lerp(m.Goal, alpha)
			placeGhost(m, m.CF)
		end
	end)
	task.delay(duration, function()
		conn:Disconnect()
		for _, m in myMarks do
			m.Model:Destroy()
		end
		table.clear(myMarks)
		if sniffMarks == myMarks then
			sniffMarks = nil
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
