-- Sentinel console repair minigames. Each console this round has its own
-- challenge (see Facility.Build): Calibrate, Wires, Sequence, Frequency, Pressure.
-- Minigame.Start(terminal, challenge, onDone) -> onDone(ok, cancelled)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Minigame = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local GREEN = rgb(80, 255, 140)
local RED = rgb(255, 70, 60)
local INK = rgb(12, 14, 18)
local PANEL = rgb(20, 23, 28)
local DIM = rgb(150, 158, 168)

local TITLES = {
	Calibrate = { "RECALIBRATE CORE", "Lock the needle inside the green band. 3 times." },
	Wires = { "REROUTE POWER", "Connect each wire to its matching port." },
	Sequence = { "OVERRIDE CODE", "Watch the sequence, then repeat it." },
	Frequency = { "TUNE FREQUENCY", "Keep your cursor on the drifting signal." },
	Pressure = { "BALANCE PRESSURE", "Vent the gauges before they hit the red line." },
}

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in props do
		i[k] = v
	end
	i.Parent = parent
	return i
end
local function corner(p, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p)
end
local function stroke(p, c, t, tr)
	return new("UIStroke", { Color = c, Thickness = t or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end
local function label(parent, props)
	local t = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), TextScaled = true }, parent)
	for k, v in props do
		t[k] = v
	end
	return t
end
local function beep(pitch, vol)
	local s = Instance.new("Sound")
	s.SoundId = Config.Sounds.UIClick
	s.PlaybackSpeed = pitch or 1
	s.Volume = vol or 0.5
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end
local function button(parent, props)
	local b = new("TextButton", { AutoButtonColor = false, Text = "", BorderSizePixel = 0 }, parent)
	for k, v in props do
		b[k] = v
	end
	return b
end

local active = nil

function Minigame.IsOpen()
	return active ~= nil
end

function Minigame.Start(term, challenge, onDone)
	if active then
		return
	end
	local info = TITLES[challenge] or TITLES.Calibrate
	local gui = new("ScreenGui", { Name = "Repair", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30 }, player:WaitForChild("PlayerGui"))
	local shade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1 }, gui)
	TweenService:Create(shade, TweenInfo.new(0.2), { BackgroundTransparency = 0.55 }):Play()
	local panel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, 320),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.05,
	}, gui)
	corner(panel, 12)
	stroke(panel, GREEN, 1.5, 0.45)
	new("UIGradient", { Color = ColorSequence.new(rgb(30, 34, 40), rgb(14, 16, 20)), Rotation = 90 }, panel)
	local scale = new("UIScale", { Scale = 0.85 }, panel)
	local cam = workspace.CurrentCamera
	local fit = math.min(1, (cam.ViewportSize.X - 20) / 480, (cam.ViewportSize.Y - 20) / 320)
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = fit }):Play()

	new("Frame", { Size = UDim2.new(0, 3, 0, 26), Position = UDim2.fromOffset(18, 18), BackgroundColor3 = GREEN, BorderSizePixel = 0 }, panel)
	label(panel, { Position = UDim2.fromOffset(28, 14), Size = UDim2.new(1, -120, 0, 22), Text = info[1], TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })
	label(panel, { Position = UDim2.fromOffset(28, 38), Size = UDim2.new(1, -56, 0, 16), Text = info[2], TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham, TextColor3 = DIM })
	label(panel, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 16), Size = UDim2.fromOffset(110, 14), Text = "SENTINEL PROTOCOL", Font = Enum.Font.Code, TextColor3 = GREEN, TextXAlignment = Enum.TextXAlignment.Right })
	label(panel, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(300, 12), Text = "Walk away to cancel", Font = Enum.Font.Gotham, TextColor3 = rgb(110, 116, 124) })
	local body = new("Frame", { Position = UDim2.fromOffset(24, 70), Size = UDim2.new(1, -48, 1, -100), BackgroundTransparency = 1 }, panel)

	local conns = {}
	local finished = false
	local state = { Body = body }
	local function finish(ok, cancelled)
		if finished then
			return
		end
		finished = true
		for _, c in conns do
			c:Disconnect()
		end
		if not cancelled then
			beep(ok and 1.4 or 0.5, ok and 0.6 or 0.9)
			local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = ok and GREEN or RED, BackgroundTransparency = 0.4, ZIndex = 20 }, panel)
			corner(flash, 12)
			label(flash, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(360, 44), Text = ok and "SYSTEM ONLINE" or "ALARM TRIPPED", Font = Enum.Font.GothamBlack, ZIndex = 21 })
		end
		task.delay(cancelled and 0 or 0.6, function()
			TweenService:Create(scale, TweenInfo.new(0.15), { Scale = fit * 0.85 }):Play()
			TweenService:Create(shade, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
			task.wait(0.16)
			gui:Destroy()
			active = nil
			onDone(ok, cancelled)
		end)
	end
	state.Finish = finish
	state.Conn = function(c)
		table.insert(conns, c)
	end
	active = state

	-- cancel if you walk off, get hit or die
	local startHits = player:GetAttribute("Hits")
	table.insert(conns, RunService.Heartbeat:Connect(function()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local bodyPart = term and term:FindFirstChild("Body")
		if not (root and hum and bodyPart) or hum.Health <= 0 or (root.Position - bodyPart.Position).Magnitude > 14 or player:GetAttribute("Hits") ~= startHits then
			finish(false, true)
		end
	end))

	local game_ = Minigame[challenge] or Minigame.Calibrate
	task.spawn(game_, state)
end

---------------------------------------------------------------------------
-- 1. Calibrate: stop the needle in the band, three times, faster each time
---------------------------------------------------------------------------
function Minigame.Calibrate(st)
	local body = st.Body
	local bar = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = INK }, body)
	corner(bar, 6)
	stroke(bar, rgb(60, 66, 74), 1)
	for i = 1, 19 do
		new("Frame", { Position = UDim2.new(i / 20, 0, 1, -8), Size = UDim2.new(0, 1, 0, 6), BackgroundColor3 = rgb(70, 76, 84), BorderSizePixel = 0 }, bar)
	end
	local zone = new("Frame", { Size = UDim2.new(0.18, 0, 1, 0), BackgroundColor3 = GREEN, BackgroundTransparency = 0.55, BorderSizePixel = 0 }, bar)
	stroke(zone, GREEN, 1)
	local needle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 4, 1, 10), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, bar)
	local pips = {}
	for i = 1, 3 do
		local p = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, (i - 2) * 30, 0, 100), Size = UDim2.fromOffset(20, 8), BackgroundColor3 = rgb(50, 54, 60) }, body)
		corner(p, 4)
		pips[i] = p
	end
	local lock = button(body, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 130), Size = UDim2.fromOffset(170, 40), BackgroundColor3 = rgb(30, 60, 42) })
	corner(lock, 8)
	stroke(lock, GREEN, 1.5, 0.3)
	label(lock, { Size = UDim2.fromScale(1, 1), Text = "LOCK  [SPACE]", Font = Enum.Font.GothamBold, TextScaled = false, TextSize = 16 })

	local round, t = 1, 0
	local widths, speeds = { 0.18, 0.13, 0.09 }, { 0.8, 1.1, 1.45 }
	local function place()
		zone.Size = UDim2.new(widths[round], 0, 1, 0)
		zone.Position = UDim2.new(math.random() * (0.9 - widths[round]) + 0.05, 0, 0, 0)
	end
	place()
	local pos = 0
	st.Conn(RunService.RenderStepped:Connect(function(dt)
		t += dt * speeds[round]
		pos = 1 - math.abs((t % 2) - 1) -- ping-pong 0..1
		needle.Position = UDim2.fromScale(pos, 0.5)
	end))
	local function press()
		local z0 = zone.Position.X.Scale
		if pos >= z0 and pos <= z0 + widths[round] then
			pips[round].BackgroundColor3 = GREEN
			beep(1 + round * 0.15, 0.5)
			if round == 3 then
				st.Finish(true)
				return
			end
			round += 1
			place()
		else
			st.Finish(false)
		end
	end
	st.Conn(lock.Activated:Connect(press))
	st.Conn(UserInputService.InputBegan:Connect(function(input, gp)
		if not gp and input.KeyCode == Enum.KeyCode.Space then
			press()
		end
	end))
end

---------------------------------------------------------------------------
-- 2. Wires: match four colours (one mistake allowed)
---------------------------------------------------------------------------
function Minigame.Wires(st)
	local body = st.Body
	local colors = { rgb(255, 70, 60), rgb(70, 150, 255), rgb(255, 210, 60), rgb(120, 255, 120) }
	local order = { 1, 2, 3, 4 }
	for i = 4, 2, -1 do
		local j = math.random(i)
		order[i], order[j] = order[j], order[i]
	end
	local strikes, matched, selected = 0, 0, nil
	local left, right = {}, {}
	local lines = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, body)
	local function node(parent, x, y, c)
		local b = button(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(x, 0, 0, y), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = c })
		corner(b, 13)
		stroke(b, Color3.new(1, 1, 1), 2, 0.6)
		return b
	end
	local function drawLine(a, b, c)
		local ap = a.AbsolutePosition + a.AbsoluteSize / 2 - body.AbsolutePosition
		local bp = b.AbsolutePosition + b.AbsoluteSize / 2 - body.AbsolutePosition
		local mid = (ap + bp) / 2
		local d = bp - ap
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(mid.X, mid.Y), Size = UDim2.fromOffset(d.Magnitude, 5), Rotation = math.deg(math.atan2(d.Y, d.X)), BackgroundColor3 = c, BorderSizePixel = 0 }, lines)
	end
	for i = 1, 4 do
		local y = 14 + (i - 1) * 42
		local l = node(body, 0.06, y, colors[i])
		local r = node(body, 0.94, y, colors[order[i]])
		left[i], right[i] = l, r
		label(body, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.06, 22, 0, y), Size = UDim2.fromOffset(60, 12), Text = ("L%d-%02d"):format(i, math.random(10, 99)), Font = Enum.Font.Code, TextColor3 = DIM })
		st.Conn(l.Activated:Connect(function()
			if l:GetAttribute("Done") then
				return
			end
			if selected then
				left[selected].Size = UDim2.fromOffset(26, 26)
			end
			selected = i
			l.Size = UDim2.fromOffset(32, 32)
			beep(1.2, 0.3)
		end))
		st.Conn(r.Activated:Connect(function()
			if not selected or r:GetAttribute("Done") then
				return
			end
			if order[i] == selected then
				drawLine(left[selected], r, colors[selected])
				left[selected]:SetAttribute("Done", true)
				r:SetAttribute("Done", true)
				left[selected].Size = UDim2.fromOffset(26, 26)
				selected = nil
				matched += 1
				beep(1.5, 0.4)
				if matched == 4 then
					st.Finish(true)
				end
			else
				strikes += 1
				beep(0.6, 0.6)
				if strikes >= 2 then
					st.Finish(false)
				end
			end
		end))
	end
end

---------------------------------------------------------------------------
-- 3. Sequence: watch 5 flashes on a 3x3 keypad, repeat them
---------------------------------------------------------------------------
function Minigame.Sequence(st)
	local body = st.Body
	local grid = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(186, 186), BackgroundTransparency = 1 }, body)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(56, 56), CellPadding = UDim2.fromOffset(9, 9) }, grid)
	local pads = {}
	for i = 1, 9 do
		local p = button(grid, { BackgroundColor3 = rgb(34, 38, 44), LayoutOrder = i })
		corner(p, 8)
		stroke(p, rgb(70, 76, 84), 1)
		label(p, { Size = UDim2.fromScale(1, 1), Text = tostring(i), Font = Enum.Font.Code, TextScaled = false, TextSize = 18, TextColor3 = DIM })
		pads[i] = p
	end
	local status = label(body, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 192), Size = UDim2.fromOffset(300, 16), Text = "WATCH", Font = Enum.Font.Code, TextColor3 = GREEN })
	local seq = {}
	for i = 1, 5 do
		local v
		repeat
			v = math.random(9)
		until v ~= seq[i - 1]
		seq[i] = v
	end
	local accepting, idx = false, 1
	local function flash(p, c)
		p.BackgroundColor3 = c
		task.delay(0.3, function()
			p.BackgroundColor3 = rgb(34, 38, 44)
		end)
	end
	for i, p in pads do
		st.Conn(p.Activated:Connect(function()
			if not accepting then
				return
			end
			if i == seq[idx] then
				flash(p, GREEN)
				beep(1 + idx * 0.1, 0.4)
				idx += 1
				if idx > #seq then
					st.Finish(true)
				end
			else
				flash(p, RED)
				st.Finish(false)
			end
		end))
	end
	task.wait(0.6)
	for _, v in seq do
		pads[v].BackgroundColor3 = GREEN
		beep(1 + v * 0.05, 0.35)
		task.wait(0.38)
		pads[v].BackgroundColor3 = rgb(34, 38, 44)
		task.wait(0.14)
	end
	status.Text = "REPEAT"
	accepting = true
end

---------------------------------------------------------------------------
-- 4. Frequency: hold the cursor on a drifting signal until it locks
---------------------------------------------------------------------------
function Minigame.Frequency(st)
	local body = st.Body
	local bar = new("Frame", { Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = INK }, body)
	corner(bar, 6)
	stroke(bar, rgb(60, 66, 74), 1)
	for i = 1, 40 do -- faux spectrum
		new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(i / 41, 0, 1, -4), Size = UDim2.new(0, 3, 0, math.random(4, 30)), BackgroundColor3 = rgb(50, 70, 60), BorderSizePixel = 0 }, bar)
	end
	local target = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0.14, 0, 1, 0), BackgroundColor3 = GREEN, BackgroundTransparency = 0.6, BorderSizePixel = 0 }, bar)
	stroke(target, GREEN, 1)
	local cursor = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 4, 1, 12), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, bar)
	local lockBg = new("Frame", { Position = UDim2.new(0, 0, 0, 110), Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = INK }, body)
	corner(lockBg, 6)
	local lockFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0 }, lockBg)
	corner(lockFill, 6)
	label(body, { Position = UDim2.new(0, 0, 0, 128), Size = UDim2.new(1, 0, 0, 14), Text = "Move the mouse (or A / D) to follow the signal", Font = Enum.Font.Gotham, TextColor3 = DIM })
	local timer = label(body, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 90), Size = UDim2.fromOffset(80, 14), Text = "", Font = Enum.Font.Code, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right })
	local t, prog, cur = 0, 0, 0.5
	local seed = math.random() * 100
	local limit = 14
	st.Conn(RunService.RenderStepped:Connect(function(dt)
		t += dt
		local tx = 0.5 + 0.38 * math.sin(t * 0.9 + seed) * math.cos(t * 0.37 + seed * 2)
		target.Position = UDim2.fromScale(tx, 0)
		-- mouse / touch position, or keyboard nudge
		local keys = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
		if keys ~= 0 then
			cur = math.clamp(cur + keys * dt * 0.6, 0, 1)
		elseif UserInputService.MouseEnabled then
			local m = UserInputService:GetMouseLocation()
			cur = math.clamp((m.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		end
		cursor.Position = UDim2.fromScale(cur, 0.5)
		local on = math.abs(cur - tx) < 0.07
		cursor.BackgroundColor3 = on and GREEN or Color3.new(1, 1, 1)
		prog = math.clamp(prog + (on and dt * 0.42 or -dt * 0.2), 0, 1)
		lockFill.Size = UDim2.fromScale(prog, 1)
		timer.Text = ("%.1fs"):format(math.max(0, limit - t))
		if prog >= 1 then
			st.Finish(true)
		elseif t > limit then
			st.Finish(false)
		end
	end))
	st.Conn(UserInputService.TouchMoved:Connect(function(touch)
		cur = math.clamp((touch.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
	end))
end

---------------------------------------------------------------------------
-- 5. Pressure: keep three gauges below the red line for 7 seconds
---------------------------------------------------------------------------
function Minigame.Pressure(st)
	local body = st.Body
	local gauges = {}
	for i = 1, 3 do
		local x = (i - 2) * 110
		local g = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, x, 0, 0), Size = UDim2.fromOffset(46, 150), BackgroundColor3 = INK }, body)
		corner(g, 6)
		stroke(g, rgb(60, 66, 74), 1)
		new("Frame", { Position = UDim2.new(0, 0, 0.12, 0), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 3 }, g)
		local fill = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.3), BackgroundColor3 = GREEN, BorderSizePixel = 0 }, g)
		corner(fill, 6)
		local vent = button(body, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, x, 0, 158), Size = UDim2.fromOffset(78, 28), BackgroundColor3 = rgb(34, 38, 44) })
		corner(vent, 6)
		stroke(vent, GREEN, 1, 0.4)
		label(vent, { Size = UDim2.fromScale(1, 1), Text = ("VENT %d"):format(i), Font = Enum.Font.GothamBold, TextScaled = false, TextSize = 13 })
		local gauge = { Fill = fill, Level = 0.2 + math.random() * 0.2, Rate = 0.12 + math.random() * 0.12 }
		gauges[i] = gauge
		local function ventIt()
			gauge.Level = math.max(0, gauge.Level - 0.42)
			beep(0.9 + i * 0.1, 0.3)
		end
		st.Conn(vent.Activated:Connect(ventIt))
		st.Conn(UserInputService.InputBegan:Connect(function(input, gp)
			if not gp and input.KeyCode == ({ Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three })[i] then
				ventIt()
			end
		end))
	end
	local timeBg = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 194), Size = UDim2.new(0.8, 0, 0, 6), BackgroundColor3 = INK }, body)
	corner(timeBg, 3)
	local timeFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0 }, timeBg)
	corner(timeFill, 3)
	local t, HOLD = 0, 7
	st.Conn(RunService.RenderStepped:Connect(function(dt)
		t += dt
		for _, g in gauges do
			if math.random() < dt * 0.6 then
				g.Rate = 0.1 + math.random() * 0.18
			end
			g.Level += g.Rate * dt
			g.Fill.Size = UDim2.fromScale(1, math.clamp(g.Level, 0, 1))
			g.Fill.BackgroundColor3 = GREEN:Lerp(RED, math.clamp((g.Level - 0.5) / 0.38, 0, 1))
			if g.Level >= 0.88 then
				st.Finish(false)
				return
			end
		end
		timeFill.Size = UDim2.fromScale(math.min(1, t / HOLD), 1)
		if t >= HOLD then
			st.Finish(true)
		end
	end))
end

return Minigame
