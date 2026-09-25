-- Spectate: once you're out of the round (killed, or waiting in the lobby) you
-- can watch the match. SPECTATE sits at the top of the dock while a round is
-- on; it starts on Wolverine and the arrows (or Q / E, L1 / R1) flip between
-- him and every survivor and Sentinel still alive.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Ability = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Ability")

local player = Players.LocalPlayer
local new, corner, stroke = UIKit.new, UIKit.Corner, UIKit.Stroke
local K = UIKit.Colors

local PLAYING = { Wolverine = true, Survivor = true, Sentinel = true }
local ROLE_TEXT = {
	Wolverine = { "WOLVERINE", K.Yellow },
	Survivor = { "SURVIVOR", Color3.fromRGB(225, 228, 235) },
	Sentinel = { "SENTINEL", K.Purple },
}

local gui = new("ScreenGui", { Name = "Spectate", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

local button, buttonLabel = Shop.DockButton("SPECTATE", "👁", K.Blue, -1)
local buttonHolder = button.Parent
buttonHolder.Visible = false

-- bottom bar: < name / role >
local bar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(460, 64),
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
local barScale = new("UIScale", {}, bar)
local prevButton = UIKit.Button(bar, { Text = "◀", Color = K.Blue, Size = UDim2.fromOffset(64, 64) })
local nextButton = UIKit.Button(bar, { Text = "▶", Color = K.Blue, Size = UDim2.fromOffset(64, 64), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0) })
local plate = new("Frame", {
	Position = UDim2.fromOffset(76, 0),
	Size = UDim2.new(1, -152, 1, 0),
	BackgroundColor3 = K.Panel,
	BackgroundTransparency = 0.1,
}, bar)
corner(plate, 12)
stroke(plate, K.Blue, 2)
new("TextLabel", {
	Position = UDim2.fromOffset(0, 5),
	Size = UDim2.new(1, 0, 0, 13),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(150, 170, 200),
	Text = "SPECTATING",
}, plate)
local nameLabel = new("TextLabel", {
	Position = UDim2.fromOffset(8, 19),
	Size = UDim2.new(1, -16, 0, 26),
	BackgroundTransparency = 1,
	Font = Enum.Font.LuckiestGuy,
	TextScaled = true,
	TextColor3 = K.White,
	Text = "",
}, plate)
new("UIStroke", { Thickness = 1.5 }, nameLabel)
local roleLabel = new("TextLabel", {
	Position = UDim2.fromOffset(0, 46),
	Size = UDim2.new(1, 0, 0, 13),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	Text = "",
}, plate)

local function fitBar()
	local v = workspace.CurrentCamera.ViewportSize
	barScale.Scale = (v.X < 900 or v.Y < 520) and 0.75 or 1
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitBar)
fitBar()

---------------------------------------------------------------------------

local spectating = false
local current = nil -- the character being watched

local function roleOf(char)
	local p = Players:GetPlayerFromCharacter(char)
	if p then
		return p:GetAttribute("Role")
	end
	return char:GetAttribute("Role") -- Studio test bots
end

local function alive(char)
	local hum = char and char.Parent and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and PLAYING[roleOf(char)] == true
end

-- Everyone still in the round: Wolverine first, then the rest by name.
local function targets()
	local list = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and alive(p.Character) then
			table.insert(list, { Char = p.Character, Name = p.DisplayName })
		end
	end
	local map = workspace:FindFirstChild("Map")
	local debris = map and map:FindFirstChild("Debris")
	if debris then
		for _, m in debris:GetChildren() do
			if m:IsA("Model") and not Players:GetPlayerFromCharacter(m) and alive(m) then
				table.insert(list, { Char = m, Name = m.Name })
			end
		end
	end
	table.sort(list, function(a, b)
		local wa, wb = roleOf(a.Char) == "Wolverine", roleOf(b.Char) == "Wolverine"
		if wa ~= wb then
			return wa
		end
		return a.Name < b.Name
	end)
	return list
end

local function canSpectate()
	return ReplicatedStorage:GetAttribute("InRound") == true and not PLAYING[player:GetAttribute("Role")]
end

local function stop()
	spectating = false
	current = nil
	bar.Visible = false
	buttonLabel.Text = "SPECTATE"
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		workspace.CurrentCamera.CameraSubject = hum
	end
	Ability:FireServer("Spectate", nil)
end

-- Move to the next (dir 1) or previous (dir -1) player; from nobody, 1 picks Wolverine.
local function step(dir)
	local list = targets()
	if #list == 0 then
		stop()
		return
	end
	local index = 0
	for i, entry in list do
		if entry.Char == current then
			index = i
		end
	end
	if index == 0 then
		index = dir > 0 and 1 or #list
	else
		index = (index - 1 + dir) % #list + 1
	end
	local entry = list[index]
	current = entry.Char
	nameLabel.Text = entry.Name
	Ability:FireServer("Spectate", current) -- the server streams the map in around them
end

local function start()
	if not canSpectate() then
		return
	end
	spectating = true
	current = nil
	bar.Visible = true
	buttonLabel.Text = "STOP WATCHING"
	step(1)
end

button.Activated:Connect(function()
	if spectating then
		stop()
	else
		start()
	end
end)
prevButton.Activated:Connect(function()
	step(-1)
end)
nextButton.Activated:Connect(function()
	step(1)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not spectating then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonL1 then
		step(-1)
	elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonR1 then
		step(1)
	end
end)

RunService.RenderStepped:Connect(function()
	local available = canSpectate()
	buttonHolder.Visible = available or spectating
	if not spectating then
		return
	end
	if not available then
		stop() -- the round ended, or they're playing again
		return
	end
	if not alive(current) then
		current = nil
		step(1) -- whoever we watched is dead or gone: back to Wolverine
		if not spectating then
			return
		end
	end
	local hum = current:FindFirstChildOfClass("Humanoid")
	local cam = workspace.CurrentCamera
	if cam.CameraSubject ~= hum then
		cam.CameraType = Enum.CameraType.Custom
		cam.CameraSubject = hum -- also re-applied after our own respawn resets it
	end
	local role = ROLE_TEXT[roleOf(current)]
	if role then
		roleLabel.Text = role[1]
		roleLabel.TextColor3 = role[2]
	end
end)

return {}
