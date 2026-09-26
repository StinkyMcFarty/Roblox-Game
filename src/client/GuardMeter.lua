-- Guard meter for Wolverine and the Sentinels (Config.Block): one pip per
-- hit the guard can take, lit gold while the block is up, and a countdown
-- while it refills. Reads the player's Guard, GuardMax, Blocking and
-- GuardRefill attributes (server/Block.lua).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local new, corner, stroke = UIKit.new, UIKit.Corner, UIKit.Stroke
local K = UIKit.Colors

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 205, 60)
local EMPTY = Color3.fromRGB(46, 46, 56)

local gui = new("ScreenGui", { Name = "GuardMeter", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 4 }, player:WaitForChild("PlayerGui"))
local box = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -66), -- just above the stamina bar
	Size = UDim2.fromOffset(210, 26),
	BackgroundColor3 = K.Ink,
	BackgroundTransparency = 0.25,
	Visible = false,
}, gui)
corner(box, 8)
local boxStroke = stroke(box, Color3.fromRGB(70, 70, 84), 1.5)
local label = new("TextLabel", {
	Position = UDim2.fromOffset(10, 0),
	Size = UDim2.new(0, 70, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = K.White,
	Text = "GUARD  F",
}, box)
local pipRow = new("Frame", { Position = UDim2.fromOffset(82, 6), Size = UDim2.new(1, -92, 0, 14), BackgroundTransparency = 1 }, box)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center }, pipRow)
local refill = new("TextLabel", {
	Position = UDim2.fromOffset(82, 0),
	Size = UDim2.new(1, -92, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = Color3.fromRGB(190, 190, 205),
	Text = "",
}, box)

local pips = {}
local function setPips(n)
	while #pips < n do
		local pip = new("Frame", { Size = UDim2.fromOffset(18, 10), BackgroundColor3 = EMPTY }, pipRow)
		corner(pip, 3)
		table.insert(pips, pip)
	end
	for i, pip in pips do
		pip.Visible = i <= n
	end
end

RunService.RenderStepped:Connect(function()
	local role = player:GetAttribute("Role")
	local max = player:GetAttribute("GuardMax")
	if not (role == "Wolverine" or role == "Sentinel") or not ReplicatedStorage:GetAttribute("InRound") or not max then
		box.Visible = false
		return
	end
	box.Visible = true
	setPips(max)
	local guard = player:GetAttribute("Guard") or max
	local up = player:GetAttribute("Blocking") == true
	for i = 1, max do
		pips[i].BackgroundColor3 = i <= guard and (up and GOLD or K.White) or EMPTY
	end
	boxStroke.Color = up and GOLD or Color3.fromRGB(70, 70, 84)
	local back = player:GetAttribute("GuardRefill")
	local left = back and back - workspace:GetServerTimeNow() or 0
	if left > 0 and guard < max then
		refill.Text = ("%ds"):format(math.ceil(left))
	else
		refill.Text = ""
	end
end)

return {}
