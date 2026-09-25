-- Verity claws: running with them out sheds a trail of tiny grinning faces
-- that spill off the blades, tumble down behind and shrink away. Runs for
-- every character on every client. A character counts as Verity when its
-- claws' face strips (Costumes.SmileyStrip, "VerityFaces") are switched on,
-- i.e. the claws are out.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SPEED = 19 -- running (a walk is 17)
local RATE = 16 -- faces a second per character
local LIFE = 1.1
local SIZE = 0.55 -- studs across
local YELLOW, INK = Color3.fromRGB(255, 214, 60), Color3.fromRGB(20, 10, 10)

local folder = Instance.new("Folder")
folder.Name = "VerityTrail"
folder.Parent = workspace

-- one little face, built once and cloned
local function frame(props, parent)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do
		f[k] = v
	end
	f.Parent = parent
	return f
end
local function round(f)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
end
local template = Instance.new("Part")
template.Anchored, template.CanCollide, template.CanQuery, template.CanTouch = true, false, false, false
template.Transparency = 1
template.Size = Vector3.one * 0.05
local bb = Instance.new("BillboardGui")
bb.Name = "Face"
bb.Size = UDim2.fromScale(SIZE, SIZE)
bb.LightInfluence = 0
bb.MaxDistance = 160
bb.Parent = template
local ball = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = YELLOW }, bb)
round(ball)
local ring = Instance.new("UIStroke")
ring.Color = INK
ring.Thickness = 1.5
ring.Parent = ball
for _, x in { 0.34, 0.66 } do
	round(frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.36), Size = UDim2.fromScale(0.13, 0.24), BackgroundColor3 = INK }, ball))
end
local clip = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.fromScale(0.66, 0.3), BackgroundTransparency = 1, ClipsDescendants = true }, ball)
local lip = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(1, 2), BackgroundColor3 = INK }, clip)
round(lip)
round(frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -3, 1, -3), BackgroundColor3 = Color3.fromRGB(250, 248, 240) }, lip))

local pool, live = {}, {}
local function take()
	local p = table.remove(pool)
	if not p then
		p = template:Clone()
	end
	p.Parent = folder
	return p
end

-- which characters have Verity claws out (checked twice a second)
local verity, nextScan = {}, 0
local function scan()
	table.clear(verity)
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local claws = char and char:FindFirstChild("Claws")
		if claws then
			for _, d in claws:GetDescendants() do
				if d:IsA("SurfaceGui") and d.Name == "VerityFaces" and d.Enabled then
					verity[char] = verity[char] or 0
					break
				end
			end
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	if now > nextScan then
		nextScan = now + 0.5
		local carry = verity
		verity = {}
		scan()
		for char, acc in carry do
			if verity[char] then
				verity[char] = acc -- keep each character's spawn timing
			end
		end
	end
	-- spawn
	for char, acc in verity do
		local root = char:FindFirstChild("HumanoidRootPart")
		if not (root and char.Parent) or char:GetAttribute("Invisible") then
			continue
		end
		local v = root.AssemblyLinearVelocity
		local flat = Vector3.new(v.X, 0, v.Z)
		if flat.Magnitude < SPEED then
			verity[char] = 0
			continue
		end
		acc += dt * RATE
		while acc >= 1 do
			acc -= 1
			local hand = char:FindFirstChild(math.random() < 0.5 and "RightHand" or "LeftHand")
			local from = (hand or root).Position + Vector3.new((math.random() - 0.5) * 0.8, -0.6 - math.random() * 0.9, (math.random() - 0.5) * 0.8)
			local p = take()
			p.CFrame = CFrame.new(from)
			p.Face.Size = UDim2.fromScale(SIZE, SIZE)
			table.insert(live, {
				Part = p,
				Pos = from,
				Vel = -flat.Unit * (2 + math.random() * 3) + Vector3.new((math.random() - 0.5) * 4, 2 + math.random() * 3, (math.random() - 0.5) * 4),
				Born = now,
				Size = SIZE * (0.7 + math.random() * 0.6),
			})
		end
		verity[char] = acc
	end
	-- fall, drift and shrink away
	for i = #live, 1, -1 do
		local f = live[i]
		local age = (now - f.Born) / LIFE
		if age >= 1 then
			f.Part.Parent = nil
			table.insert(pool, f.Part)
			table.remove(live, i)
		else
			f.Vel += Vector3.new(0, -14 * dt, 0)
			f.Pos += f.Vel * dt
			f.Part.CFrame = CFrame.new(f.Pos)
			local k = f.Size * (age < 0.6 and 1 or 1 - (age - 0.6) / 0.4)
			f.Part.Face.Size = UDim2.fromScale(k, k)
		end
	end
end)

return {}
