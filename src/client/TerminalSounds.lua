-- Terminals sound alive when you're near one: a looping console hum
-- (TerminalHum, once uploaded) and, until it's repaired, restless beeps
-- calling you over. Played locally, only for terminals within RANGE studs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer

local RANGE = 45 -- studs
local HUM = Config.Sounds.TerminalHum
local BEEP = Config.Sounds.Terminal

local near = {} -- [terminal Model] = { Hum = Sound?, NextBeep = os.clock() }

local function sound(id, parent, volume)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = RANGE
	s.Parent = parent
	return s
end

local function drop(term)
	local st = near[term]
	if st and st.Hum then
		st.Hum:Destroy()
	end
	near[term] = nil
end

task.spawn(function()
	while true do
		task.wait(0.3)
		local map = workspace:FindFirstChild("Map")
		local folder = map and map:FindFirstChild("Terminals")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local seen = {}
		if folder and root then
			for _, term in folder:GetChildren() do
				local body = term:FindFirstChild("Body")
				if body and (body.Position - root.Position).Magnitude < RANGE then
					seen[term] = true
					local st = near[term]
					if not st then
						st = { NextBeep = os.clock() + math.random() * 2 }
						near[term] = st
						if HUM ~= "" then
							st.Hum = sound(HUM, body, 0.6)
							st.Hum.Looped = true
							st.Hum.TimePosition = math.random() * 7 -- consoles side by side don't hum in step
							st.Hum:Play()
						end
					end
					local done = term:GetAttribute("Done") == true
					if st.Hum then
						st.Hum.Volume = done and 0.3 or 0.6 -- repaired ones settle down
					end
					if not done and BEEP ~= "" and os.clock() >= st.NextBeep then
						st.NextBeep = os.clock() + 2.5 + math.random() * 3
						local b = sound(BEEP, body, 0.35)
						b.PlaybackSpeed = 0.8 + math.random() * 0.5
						b:Play()
						b.Ended:Connect(function()
							b:Destroy()
						end)
					end
				end
			end
		end
		for term in near do
			if not seen[term] then
				drop(term)
			end
		end
	end
end)

return {}
