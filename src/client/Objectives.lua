-- Round objectives, down the left of the screen under the minimap, so a new
-- player always knows what to do next:
--   Survivors  1. Find and repair the terminals (n / total)
--              2. Activate the Sentinel suits (unlocked when every terminal is
--                 fixed; they're in the Sentinel Hangar)
--              3. Hunt the Berserker (once someone is in a suit)
--   Sentinels  Hunt the Berserker
--   Wolverine  Hunt the scientists (kills / survivors who started the round)
-- A finished objective ticks green. Reads ReplicatedStorage's Terminals,
-- TerminalsTotal, SuitOnline, SurvivorsTotal and Kills, and players' Role.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local new, corner, stroke = UIKit.new, UIKit.Corner, UIKit.Stroke
local K = UIKit.Colors

local player = Players.LocalPlayer
local GREY = Color3.fromRGB(150, 150, 165)

local gui = new("ScreenGui", { Name = "Objectives", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 4 }, player:WaitForChild("PlayerGui"))
local panel = new("Frame", {
	Position = UDim2.fromOffset(16, 64), -- moved under the minimap when it's up
	Size = UDim2.fromOffset(262, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = K.Ink,
	BackgroundTransparency = 0.2,
	Visible = false,
}, gui)
corner(panel, 10)
stroke(panel, Color3.fromRGB(70, 70, 84), 1.5)
new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, panel)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 16),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = K.Yellow,
	Text = "OBJECTIVES",
	LayoutOrder = 0,
}, panel)

-- one row: a check box, the objective and a smaller hint under it
local rows = {}
local function row(i)
	if rows[i] then
		return rows[i]
	end
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = i }, panel)
	local box = new("Frame", { Position = UDim2.fromOffset(0, 2), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.fromRGB(30, 30, 38) }, f)
	corner(box, 4)
	local boxStroke = stroke(box, GREY, 1.5)
	local tick = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "✓", TextColor3 = Color3.new(1, 1, 1), Visible = false }, box)
	local body = new("Frame", { Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -24, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, f)
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, body)
	local text = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 16, TextWrapped = true, RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = K.White, Text = "", LayoutOrder = 1,
	}, body)
	new("UIStroke", { Thickness = 1, Transparency = 0.5 }, text)
	local sub = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 13, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 190, 205), Text = "", LayoutOrder = 2,
	}, body)
	rows[i] = { Frame = f, Box = box, BoxStroke = boxStroke, Tick = tick, Text = text, Sub = sub, Done = false }
	return rows[i]
end

local function show(i, o)
	local r = row(i)
	r.Frame.Visible = true
	r.Text.Text = o.Done and ('<font color="#8a8a96"><s>%s</s></font>'):format(o.Text) or o.Text
	r.Text.TextColor3 = o.Active and K.Yellow or K.White
	r.Sub.Text = (not o.Done and o.Sub) or ""
	r.Sub.Visible = r.Sub.Text ~= ""
	if o.Done ~= r.Done then
		r.Done = o.Done
		r.Tick.Visible = o.Done
		if o.Done then
			-- ticked off: a quick green pop
			r.Box.BackgroundColor3 = Color3.new(1, 1, 1)
			TweenService:Create(r.Box, TweenInfo.new(0.4), { BackgroundColor3 = K.Green }):Play()
			r.BoxStroke.Color = K.Green
		else
			r.Box.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
			r.BoxStroke.Color = GREY
		end
	end
	r.BoxStroke.Color = o.Done and K.Green or (o.Active and K.Yellow or GREY)
end

local function objectives()
	if not ReplicatedStorage:GetAttribute("InRound") then
		return nil
	end
	local role = player:GetAttribute("Role")
	local total = ReplicatedStorage:GetAttribute("TerminalsTotal") or 3
	local fixed = math.min(ReplicatedStorage:GetAttribute("Terminals") or 0, total)
	local online = ReplicatedStorage:GetAttribute("SuitOnline") == true
	local manned = false
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == "Sentinel" then
			manned = true
		end
	end
	if role == "Wolverine" then
		local n = ReplicatedStorage:GetAttribute("SurvivorsTotal") or 0
		local kills = ReplicatedStorage:GetAttribute("Kills") or 0
		return {
			{ Text = ("Hunt the scientists  %d/%d"):format(kills, n), Sub = "Slash them with your claws. Sniff (R) sniffs out anyone hiding.", Done = n > 0 and kills >= n, Active = true },
		}
	elseif role == "Sentinel" then
		return {
			{ Text = "Hunt the Berserker", Sub = "Punch (click) and Ground Slam (right click). Stay near the other suit: you hit harder together.", Active = true },
		}
	elseif role == "Survivor" then
		local list = {
			{ Text = ("Find and repair %d terminals  %d/%d"):format(total, fixed, total), Sub = "They glow white. Walk up to one and press E.", Done = fixed >= total or online },
			{
				Text = "Activate the Sentinel suits",
				Sub = online and "They're online in the Sentinel Hangar. Walk up to a suit and press E."
					or "They unlock when every terminal is repaired.",
				Done = manned,
			},
		}
		if manned then
			table.insert(list, { Text = "Hunt the Berserker", Sub = "The suits are up. Stay alive and keep him busy for them.", Active = true })
		end
		return list
	end
	return nil
end

-- sit under the small minimap (its big view is drawn over this panel)
local function place()
	local mini = gui.Parent:FindFirstChild("Minimap")
	local map = mini and mini.Enabled and mini:FindFirstChild("Map")
	local y = map and map.Visible and map.Position.Y.Offset + map.Size.Y.Offset + 12 or 64
	panel.Position = UDim2.fromOffset(16, y)
end

task.spawn(function()
	while true do
		local list = objectives()
		panel.Visible = list ~= nil
		place()
		for i = 1, math.max(#rows, list and #list or 0) do
			if list and list[i] then
				show(i, list[i])
			elseif rows[i] then
				rows[i].Frame.Visible = false
			end
		end
		task.wait(0.2)
	end
end)

return {}
