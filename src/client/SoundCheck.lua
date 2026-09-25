-- Checks every uploaded sound once when you join. Roblox refuses to play an
-- upload the experience isn't allowed to use (e.g. the game is owned by a
-- group but the audio by a person) or one still waiting for moderation, and
-- that fails silently. So: each one that fails is listed in the F9 console
-- under [Sounds] with the reason, and from then on it plays its built-in
-- stand-in instead of nothing.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local fallback = {} -- [uploaded SoundId that failed] = built-in SoundId

local function patch(sound)
	local id = fallback[sound.SoundId]
	if id then
		local playing = sound.IsPlaying
		sound.SoundId = id
		if playing then
			sound:Play()
		end
	end
end

task.spawn(function()
	local probes, nameOf = {}, {}
	for name, id in Config.UploadedSounds do
		if id and id ~= 0 and Config.Sounds[name] then
			local s = Instance.new("Sound")
			s.SoundId = Config.Sounds[name]
			nameOf[s.SoundId] = name
			table.insert(probes, s)
		end
	end
	local failed = {}
	pcall(function()
		ContentProvider:PreloadAsync(probes, function(contentId, status)
			if status ~= Enum.AssetFetchStatus.Success and nameOf[contentId] then
				local name = nameOf[contentId]
				table.insert(failed, ("%s (%s: %s)"):format(name, contentId, status.Name))
				local builtin = Config.BuiltinSounds[name]
				if builtin and builtin ~= "" and builtin ~= contentId then
					fallback[contentId] = builtin
				end
			end
		end)
	end)
	if #failed == 0 then
		print(("[Sounds] all %d uploaded sounds loaded"):format(#probes))
		return
	end
	warn(("[Sounds] %d of %d uploaded sounds won't play here: %s"):format(#failed, #probes, table.concat(failed, ", ")))
	warn("[Sounds] Fix: make sure the game and the audio belong to the same owner, or give this experience permission on each sound (Creator Dashboard > the audio > Permissions), and that each one passed moderation.")
	for _, d in workspace:GetDescendants() do
		if d:IsA("Sound") then
			patch(d)
		end
	end
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Sound") then
			patch(d)
		end
	end)
end)

return {}
