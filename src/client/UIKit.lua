-- Shared UI building blocks: animated buttons, panels, gradients.
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local UIKit = {}

UIKit.Colors = {
	Ink = Color3.fromRGB(12, 12, 16),
	Panel = Color3.fromRGB(22, 22, 28),
	Card = Color3.fromRGB(32, 32, 40),
	Yellow = Color3.fromRGB(255, 200, 30),
	Red = Color3.fromRGB(225, 45, 45),
	Green = Color3.fromRGB(80, 220, 120),
	Blue = Color3.fromRGB(80, 170, 255),
	Purple = Color3.fromRGB(170, 110, 255),
	White = Color3.new(1, 1, 1),
}

local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BOUNCE = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function UIKit.new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end
local new = UIKit.new

function UIKit.Corner(p, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 10) }, p)
end

function UIKit.Stroke(p, color, thickness, transparency)
	return new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, p)
end

function UIKit.Gradient(p, top, bottom, rotation)
	return new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	}, p)
end

local function darker(c, f)
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

-- Hover = a quick blade slice, click = a short metallic SNIKT
local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxasset://sounds/unsheath.wav"
clickSound.Volume = 0.35
clickSound.PlaybackSpeed = 1.5
clickSound.Parent = SoundService

local hoverSound = Instance.new("Sound")
hoverSound.SoundId = "rbxasset://sounds/swordslash.wav"
hoverSound.Volume = 0.18
hoverSound.PlaybackSpeed = 1.6
hoverSound.Parent = SoundService
local lastHover = 0

-- Makes any GuiButton feel alive: grows + glows on hover, squishes on press.
function UIKit.Animate(button, accent)
	local scale = button:FindFirstChildOfClass("UIScale") or new("UIScale", {}, button)
	local stroke = button:FindFirstChildOfClass("UIStroke")
	local baseThickness = stroke and stroke.Thickness or 0
	local shine = button:FindFirstChild("Shine")
	local hovering = false

	button.AutoButtonColor = false
	button.MouseEnter:Connect(function()
		hovering = true
		if os.clock() - lastHover > 0.08 then
			lastHover = os.clock()
			hoverSound.PlaybackSpeed = 1.45 + math.random() * 0.3
			hoverSound:Play()
		end
		TweenService:Create(scale, BOUNCE, { Scale = 1.07 }):Play()
		if stroke then
			TweenService:Create(stroke, FAST, { Thickness = baseThickness + 1.5, Color = accent or stroke.Color }):Play()
		end
		if shine then
			shine.Position = UDim2.fromScale(-0.6, 0)
			TweenService:Create(shine, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(1.2, 0) }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		TweenService:Create(scale, FAST, { Scale = 1 }):Play()
		if stroke then
			TweenService:Create(stroke, FAST, { Thickness = baseThickness }):Play()
		end
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, FAST, { Scale = 0.93 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, BOUNCE, { Scale = hovering and 1.07 or 1 }):Play()
	end)
	button.Activated:Connect(function()
		clickSound:Play()
		if not hovering then -- touch: do a quick pop
			scale.Scale = 0.93
			TweenService:Create(scale, BOUNCE, { Scale = 1 }):Play()
		end
	end)
end

-- A chunky game-style button with gradient, stroke, drop shadow and shine sweep.
function UIKit.Button(parent, props)
	local accent = props.Color or UIKit.Colors.Yellow
	local holder = new("Frame", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(150, 52),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
	}, parent)
	-- drop shadow
	local shadow = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		ZIndex = holder.ZIndex,
	}, holder)
	UIKit.Corner(shadow, 12)

	local b = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		ZIndex = holder.ZIndex + 1,
		ClipsDescendants = true,
	}, holder)
	UIKit.Corner(b, 12)
	UIKit.Gradient(b, props.Top or darker(accent, 0.55), props.Bottom or darker(accent, 0.25))
	UIKit.Stroke(b, darker(accent, 0.9), 2)

	-- glossy top half
	local gloss = new("Frame", {
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = b.ZIndex + 1,
	}, b)
	UIKit.Corner(gloss, 12)

	-- shine sweep on hover
	local shine = new("Frame", {
		Name = "Shine",
		Size = UDim2.new(0.35, 0, 1, 0),
		Position = UDim2.fromScale(-0.6, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		Rotation = 15,
		ZIndex = b.ZIndex + 2,
	}, b)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, shine)

	local hasIcon = props.Icon ~= nil
	if hasIcon then
		new("TextLabel", {
			Name = "Icon",
			Size = UDim2.new(0, 34, 1, -12),
			Position = UDim2.fromOffset(8, 6),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			TextColor3 = accent,
			Text = props.Icon,
			ZIndex = b.ZIndex + 3,
		}, b)
	end
	local label = new("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, hasIcon and -52 or -16, 1, -14),
		Position = UDim2.fromOffset(hasIcon and 44 or 8, 7),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextXAlignment = hasIcon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
		TextColor3 = Color3.new(1, 1, 1),
		Text = props.Text or "",
		ZIndex = b.ZIndex + 3,
	}, b)
	new("UIStroke", { Thickness = 1.5, Transparency = 0.3 }, label)
	new("UITextSizeConstraint", { MaxTextSize = props.MaxText or 22 }, label)

	UIKit.Animate(b, Color3.new(1, 1, 1))
	return b, label, holder
end

-- Recolours a button made with UIKit.Button.
function UIKit.Recolor(button, accent)
	local g = button:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(darker(accent, 0.55), darker(accent, 0.25))
	end
	local s = button:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = darker(accent, 0.9)
	end
end

-- Standard window: title bar, close button, pop-in animation.
function UIKit.Window(parent, title, size, accent)
	local w = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = UIKit.Colors.Panel,
		Visible = false,
		ZIndex = 30,
	}, parent)
	UIKit.Corner(w, 16)
	UIKit.Gradient(w, Color3.fromRGB(34, 32, 40), Color3.fromRGB(14, 14, 18))
	UIKit.Stroke(w, accent, 2.5)
	local scale = new("UIScale", {}, w)

	local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = accent, ZIndex = 31 }, w)
	UIKit.Corner(bar, 16)
	UIKit.Gradient(bar, darker(accent, 0.7), darker(accent, 0.35))
	new("Frame", { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -16), BackgroundColor3 = darker(accent, 0.35), BorderSizePixel = 0, ZIndex = 31 }, bar)
	-- claw scratches in the title bar
	for i = 0, 2 do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -90 - i * 12, 0.5, 0),
			Size = UDim2.fromOffset(4, 44),
			Rotation = 25,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.6,
			ZIndex = 32,
		}, bar)
	end
	local t = new("TextLabel", {
		Position = UDim2.fromOffset(20, 8),
		Size = UDim2.new(1, -140, 0, 40),
		BackgroundTransparency = 1,
		Font = Enum.Font.LuckiestGuy,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = title,
		ZIndex = 33,
	}, bar)
	new("UIStroke", { Thickness = 2 }, t)

	local close = UIKit.Button(w, {
		Text = "X",
		Color = UIKit.Colors.Red,
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -52, 0, 8),
		ZIndex = 34,
	})

	local api = { Frame = w, Scale = scale, Base = 1 }
	function api.Open()
		w.Visible = true
		scale.Scale = api.Base * 0.8
		TweenService:Create(scale, BOUNCE, { Scale = api.Base }):Play()
	end
	function api.Close()
		local tw = TweenService:Create(scale, FAST, { Scale = api.Base * 0.85 })
		tw:Play()
		tw.Completed:Wait()
		w.Visible = false
	end
	function api.Toggle()
		if w.Visible then
			api.Close()
		else
			api.Open()
		end
	end
	close.Activated:Connect(api.Close)

	-- keep it on screen for phones
	local function fit()
		local cam = workspace.CurrentCamera
		local s = math.min(1, (cam.ViewportSize.X - 24) / size.X.Offset, (cam.ViewportSize.Y - 24) / size.Y.Offset)
		api.Base = math.max(0.4, s)
		if w.Visible then
			scale.Scale = api.Base
		end
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	return api
end

return UIKit
