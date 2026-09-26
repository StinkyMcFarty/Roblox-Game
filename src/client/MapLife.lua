-- The facility's moving parts, animated on each client (only near the camera):
--   Spin        a Model turning about its pivot's Z axis (a fan's blades) or,
--               with Axis = "Y", its Y axis (a lockdown beacon's lamp), at its
--               "Speed" attribute (rad/s)
--   Sparks      a torn cable end: every so often it spits a burst from its
--               "Sparks" emitter and flashes its light
--   SteamBurst  a vent: its "Steam" emitter hisses out a big puff now and then
-- Tags come from the map build (Facility.lua, LIFE & WEAR).
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local NEAR = 140 -- studs: nothing further away is animated

local fans = {} -- [model] = { Base = CFrame, Angle = number, Speed = number }
local function addFan(m)
	if m:IsA("Model") then
		fans[m] = {
			Base = m:GetPivot(),
			Angle = math.random() * math.pi * 2,
			Speed = m:GetAttribute("Speed") or 6,
			Y = m:GetAttribute("Axis") == "Y",
		}
	end
end
local function watch(tagName, add, list)
	for _, inst in CollectionService:GetTagged(tagName) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(inst)
		list[inst] = nil
	end)
end
watch("Spin", addFan, fans)

local sparks = {} -- [part] = next burst time
watch("Sparks", function(p)
	sparks[p] = os.clock() + math.random() * 2
end, sparks)

local steam = {}
watch("SteamBurst", function(p)
	steam[p] = os.clock() + 2 + math.random() * 6
end, steam)

local function near(pos, camPos)
	return (pos - camPos).Magnitude < NEAR
end

RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local now = os.clock()
	for m, st in fans do
		if m.Parent and near(st.Base.Position, camPos) then
			st.Angle = (st.Angle + st.Speed * dt) % (math.pi * 2)
			m:PivotTo(st.Base * (st.Y and CFrame.Angles(0, st.Angle, 0) or CFrame.Angles(0, 0, st.Angle)))
		end
	end
	for p, t in sparks do
		if now >= t then
			sparks[p] = now + 0.35 + math.random() * 2.4
			if p.Parent and near(p.Position, camPos) then
				local e = p:FindFirstChild("Sparks")
				if e then
					e:Emit(math.random(8, 22))
				end
				local l = p:FindFirstChildWhichIsA("Light")
				if l then
					l.Brightness = 2.5 + math.random() * 2
					task.delay(0.06 + math.random() * 0.08, function()
						l.Brightness = 0
					end)
				end
			end
		end
	end
	for p, t in steam do
		if now >= t then
			steam[p] = now + 4 + math.random() * 7
			local e = p.Parent and near(p.Position, camPos) and p:FindFirstChild("Steam")
			if e then
				e:Emit(math.random(18, 30))
			end
		end
	end
end)

return {}
