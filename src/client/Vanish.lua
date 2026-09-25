-- Invisibility power (Config.Upgrades.Invisible). While a character has the
-- "Invisible" attribute, every other client hides it completely: body, suit
-- gear, the drawn face, name tag, shadow, glows and trails. Its own player
-- sees a faint ghost with a glowing outline so they know where they are
-- (nobody else gets that). Wolverine's Sniff still finds them: the scent
-- list comes from the server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local OUTLINE = Color3.fromRGB(150, 230, 255)

local active = {} -- [char] = { Saved = { [inst] = { [prop] = value } }, Outline = Highlight? }

local function remember(state, inst, prop, value)
	local s = state.Saved[inst]
	if not s then
		s = {}
		state.Saved[inst] = s
	end
	if s[prop] == nil then
		s[prop] = inst[prop]
	end
	inst[prop] = value
end

-- everything on the character that could give them away (for other players)
local function hideExtras(char, state, d)
	if d == state.Outline then
		return
	end
	if d:IsA("BasePart") then
		remember(state, d, "CastShadow", false)
	elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
		remember(state, d, "Enabled", false)
	elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Highlight") or d:IsA("Light")
		or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
		remember(state, d, "Enabled", false)
	elseif d:IsA("Humanoid") then
		remember(state, d, "DisplayDistanceType", Enum.HumanoidDisplayDistanceType.None)
	end
end

local function start(char)
	if active[char] then
		return
	end
	local own = char == player.Character
	local state = { Saved = {}, Own = own }
	active[char] = state
	if own then
		-- just for you: a faint ghost of yourself with a glowing outline
		local hl = Instance.new("Highlight")
		hl.Name = "VanishOutline"
		hl.FillColor = OUTLINE
		hl.FillTransparency = 0.85
		hl.OutlineColor = OUTLINE
		hl.OutlineTransparency = 0.15
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Adornee = char
		hl.Parent = char
		state.Outline = hl
		for _, d in char:GetDescendants() do
			if d:IsA("SurfaceGui") then
				remember(state, d, "Enabled", false) -- the drawn face would float there
			end
		end
	else
		for _, d in char:GetDescendants() do
			hideExtras(char, state, d)
		end
		state.Added = char.DescendantAdded:Connect(function(d)
			hideExtras(char, state, d)
		end)
	end
end

local function stop(char)
	local state = active[char]
	if not state then
		return
	end
	active[char] = nil
	if state.Added then
		state.Added:Disconnect()
	end
	if state.Outline then
		state.Outline:Destroy()
	end
	for inst, props in state.Saved do
		if inst.Parent then
			for prop, value in props do
				inst[prop] = value
			end
		end
	end
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
			d.LocalTransparencyModifier = 0
		end
	end
end

-- The camera scripts set your own character's LocalTransparencyModifier as you
-- zoom, so it's enforced every frame, after the camera.
RunService:BindToRenderStep("Vanish", Enum.RenderPriority.Camera.Value + 5, function()
	for char, state in active do
		if not char.Parent then
			active[char] = nil
			continue
		end
		local ltm = state.Own and 0.8 or 1
		for _, d in char:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
				d.LocalTransparencyModifier = ltm
			end
		end
	end
end)

local function watch(char)
	local function sync()
		if char:GetAttribute("Invisible") then
			start(char)
		else
			stop(char)
		end
	end
	char:GetAttributeChangedSignal("Invisible"):Connect(sync)
	sync()
end

local function track(p)
	p.CharacterAdded:Connect(watch)
	if p.Character then
		watch(p.Character)
	end
end
Players.PlayerAdded:Connect(track)
for _, p in Players:GetPlayers() do
	track(p)
end

return {}
