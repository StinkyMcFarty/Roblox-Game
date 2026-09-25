-- Every tunable number in the game lives here.
local Config = {}

-- Rounds ----------------------------------------------------------------
Config.MinPlayers = 2 -- real players needed to start a round in the live game
-- Bot survivors are for testing only: in Roblox Studio a round starts with
-- 1 player and bots fill in up to this many survivors. The published game
-- never spawns bots.
Config.BotFill = 6
Config.IntermissionTime = 20
Config.RoundTime = 210 -- seconds survivors must last (after the intro): 3m30s
Config.KillTimeBonus = 15 -- Wolverine gets this much extra time per kill
Config.EndScreenTime = 6

-- Wolverine intro (he is locked in the Weapon X tank room)
Config.IntroLength = 5.5 -- seconds before he is released
Config.ClawPopTime = 1.25 -- SNIKT (maps without the Weapon X tank)
Config.RoarTime = 1.9
-- Weapon X tank breakout (seconds from spawn): he drifts in the fluid, his
-- eyes snap open, two kicks crack the glass (water starts spurting), a third
-- kick shatters it and he flies out, arms cross (claws pop 0.62s later in
-- an X), roar. Most of the time is in the tank; it's quick once he's out.
Config.Intro = { Wake = 1.4, Kicks = { 2.25, 3.05 }, Burst = 3.85, Cross = 4.45, Roar = 5.1 }

-- Damage ----------------------------------------------------------------
Config.HitsToKill = 3 -- the 3rd hit always rips the survivor in half
Config.HitImmunity = 2.0 -- i-frames after being wounded (no infinite combos)
Config.WolverineHitRecovery = 0.4 -- Wolverine can't attack for this long after landing a hit
Config.Throw = { Force = 72, Up = 34, Tumble = 0.8 } -- survivors get flung on a non-lethal hit
Config.AdrenalineTime = 1.8 -- speed boost after being wounded
Config.AdrenalineBonus = 8

-- Movement --------------------------------------------------------------
Config.Survivor = {
	WalkSpeed = 16,
	SprintSpeed = 22,
	TopSpeed = 28, -- after a couple of seconds of running
	Stamina = 8, -- seconds of sprint
	StaminaRegen = 0.8, -- seconds of sprint regained per second
}

Config.Wolverine = {
	MaxHealth = 780, -- 600 x 1.3
	HealPerSecond = 14, -- healing factor
	HealDelay = 3, -- seconds after taking damage before healing starts
	Scale = 1.15,
	WalkSpeed = 17,
	-- Upright he runs 15% SLOWER than a sprinting survivor; on all fours he's
	-- 15% FASTER (so survivors can outrun him until he drops to all fours).
	SprintSpeed = Config.Survivor.SprintSpeed * 0.85,
	TopSprintSpeed = Config.Survivor.TopSpeed * 0.85,
	FeralSpeed = Config.Survivor.SprintSpeed * 1.15, -- running on all fours
	FeralTopSpeed = Config.Survivor.TopSpeed * 1.15,
	FeralStamina = 4.5,
	ImpaleShock = 0.07, -- impaling a Sentinel shocks him through his claws for this much of his health
	FeralRegen = 0.6,
}

-- Sprint momentum: after Delay seconds of running you accelerate to top
-- speed over Time seconds (stop running and it resets).
Config.SprintRamp = { Delay = 0.9, Time = 2.2 }

-- Rage: when he drops below Threshold health he snaps (at most MaxPerGame
-- times, once per dip below the line): a red aura for Duration seconds,
-- slashes AttackSpeed x faster, every hit counts Damage x (survivor wounds,
-- Sentinel armour), and every other cooldown x Cooldown.
Config.Rage = { Threshold = 0.4, Duration = 15, MaxPerGame = 2, AttackSpeed = 1.35, Damage = 1.3, Cooldown = 0.75, RoarTime = 1.5 }

Config.Abilities = {
	-- A slash that lands locks his claws: slash, pounce and impale all wait
	-- HitLock seconds after hitting a survivor, SentinelHitLock after a Sentinel.
	Slash = { Cooldown = 0.55, Range = 8, Width = 8, HitLock = 3, SentinelHitLock = 1 },
	-- Pounce: a scripted dive arc. He lies flat in the dive (~2 studs thick), so
	-- with his hips rising Height = 7.6 studs his back peaks ~12 studs up, just
	-- under the 12.4-stud Hangar entrance (lower doors he tears through). He
	-- lands after AirTime seconds at Forward studs/s: ~72 studs, the same
	-- distance as the old high leap.
	Pounce = { Cooldown = 15, Forward = 78, Height = 7.6, AirTime = 0.92, GrabRadius = 7, Window = 1.2 },
	Stab = { Cooldown = 15, Range = 10, Width = 8, Lunge = 60 },
	Sniff = { Cooldown = 25, Duration = 5 }, -- only 5s of tracking so he can't wallhack all round
}

-- The counter: reboot 3 Sentinel terminals, then a survivor can suit up.
Config.Sentinel = {
	HoldTime = 4,
	PodHoldTime = 2,
	Duration = 90, -- the suit powers down after this
	Armor = 6, -- Wolverine hits needed to destroy it (the last one rips it in half)
	Suits = 2, -- how many survivors can suit up per round
	-- Teamwork: suits within LinkRange of each other are "linked" and hit hard.
	-- Two suits apart barely scratch him; the last suit standing hits at 1x.
	LinkRange = 30,
	LinkedMultiplier = 1.25,
	SoloMultiplier = 0.6, -- two suits but far apart; a lone suit hits at 1x
	WalkSpeed = 18,
	-- Pursuit thrusters: once Wolverine gets Start studs away the suits surge
	-- (+Bonus speed, ramping in over Ramp seconds) and keep it until they're
	-- back within Stop studs, so he can't just run off and heal. 18 + 14 = 32
	-- beats his sprint (~24) and matches his all-fours top speed.
	Pursuit = { Start = 70, Stop = 30, Bonus = 14, Ramp = 1 },
	Scale = 1.8, -- same size as the docked suits in the Hangar
	Punch = { Cooldown = 0.9, Damage = 40, Range = 9, Stun = 0.6, Knockback = 70 },
	-- Ground Slam (right mouse): both fists overhead, then down into the floor.
	-- 1.75x a punch's damage, 1.8x its wind-up (the punch lands at 0.27s), hits
	-- him anywhere within Radius studs. The floor cracks and heals like the walls.
	Slam = { Cooldown = 8, Damage = 40 * 1.75, WindUp = 0.27 * 1.8, Radius = 30, Stun = 1, Knockback = 55 },
	-- Laser burns through walls and flashes Wolverine's adamantium skeleton
	-- Death ray: charge, then a 3s aimable beam that pushes him back; the suit
	-- is sluggish for 3s after firing.
	-- FarRangeMult: range x1.5 while he's Pursuit.Start+ studs from that suit.
	Laser = { Cooldown = 12, Charge = 0.6, Duration = 3, DPS = 32.4, Range = 260, FarRangeMult = 1.5,
		Slow = 1.5, WallsBurned = 8, Push = 22, CloseRange = 18, CloseMult = 3.2,
		-- Wolverine mashing F while beamed: Presses/sec for full resist; past
		-- Threshold he braces and walks into the beam at Walk x speed
		Resist = { Presses = 7, Threshold = 0.5, Walk = 0.38 }, Recover = 3 },
	-- Inhibitor Blast: while he's stunned by it, a punch only gives him i-frames
	-- every IFramesEvery-th hit, so the suits get a real damage window.
	Pulse = { Cooldown = 18, Charge = 2, Radius = 30, Stun = 3, Damage = 12, CancelCooldown = 3, IFramesEvery = 2 },
}

-- Survivor upgrades (bought once with coins, kept forever; client/Upgrades).
-- They're powers on the G key: a survivor equips ONE (PlayerData "Power"),
-- none = the plain fart. Order sets the order in the Upgrades window.
Config.Upgrades = {
	TurboFart = {
		Order = 1,
		Name = "Turbo Fart",
		Icon = "💨",
		Price = 300,
		Desc = "Every fart launches you: a big speed burst (and instant top speed if sprinting), leaving a trail of gas behind you.",
		Boost = 8, -- extra walk speed during the burst
		Duration = 2.5, -- seconds of burst
		TrailTime = 2, -- the gas trail fades after this long
	},
	Dodge = {
		Order = 2,
		Name = "Dodge",
		Icon = "🌀",
		Price = 300,
		Desc = "Replaces your fart. Press G just as he strikes: for a split second nothing can touch you and his attack misses.",
		Window = 0.5, -- seconds of i-frames after pressing
		Cooldown = 30,
	},
}

-- Survivor fart: masks your scent from Wolverine's Sniff
Config.Fart = {
	Cooldown = 45, MaskTime = 10, CloudTime = 10, -- the cloud (and its Sniff decoy) lasts 10s
	-- Wolverine caught in the fresh cloud: can't attack and staggers slowly
	GasRadius = 7, GasWindow = 4, GasTime = 2, GasSlow = 0.4,
}

-- Monetization ----------------------------------------------------------
-- Create a Developer Product (29 Robux) in the Creator Dashboard under
-- your experience > Monetization > Developer Products, then paste its ID here.
-- The button shows the dashboard's real price once it loads; this is the
-- fallback label.
Config.GuaranteedWolverineProductId = 3714579231
Config.GuaranteedWolverinePrice = 29

-- Game Pass: doubles your chance of being picked as Wolverine every round.
-- Creator Dashboard > your experience > Monetization > Passes: create a pass
-- priced 250 Robux, then paste its ID here.
Config.DoubleChanceGamepassId = 1995650487

-- What the in-game currency is called on screen (saves still store it as Coins).
Config.CoinName = "Berserker Coins"

-- Coin packs (Store button). For each pack create a Developer Product in the
-- Creator Dashboard (Monetization > Developer Products) at the Robux price
-- below, then paste its ID into ProductId. Bigger packs give a bonus.
-- Roughly: a match pays 50 (died) to 150 (survived), more for kills and takedowns;
-- claws cost 400-2200, suits 2000-6000.
Config.CoinPacks = {
	{ Id = "Handful", Name = "Handful of Berserker Coins", Coins = 500, Robux = 49, Bonus = "", ProductId = 3714579257 },
	{ Id = "Pouch", Name = "Pouch of Berserker Coins", Coins = 1200, Robux = 99, Bonus = "+20% BONUS", ProductId = 3714579267 },
	{ Id = "Crate", Name = "Crate of Berserker Coins", Coins = 3000, Robux = 199, Bonus = "+50% BONUS", ProductId = 3714579287 },
	{ Id = "Vault", Name = "Weapon X Vault", Coins = 7000, Robux = 399, Bonus = "+75% BONUS", ProductId = 3714579305 },
}

-- AFK: players marked AFK sit out matches. Roblox fires Player.Idled after
-- ~2 minutes without input; that marks you AFK automatically.
Config.AutoAfk = true

-- Every round you play without being Wolverine adds this much weight to
-- your odds (everyone starts at weight 1).
Config.WolverinePityWeight = 1

-- Daily challenges (reset every 24 hours per player). Rewards are coins.
Config.DailyChallenges = {
	{ Id = "BecomeWolverine", Text = "Become Wolverine", Goal = 1, Reward = 100 },
	{ Id = "WolverineKills", Text = "Rip apart 5 survivors as Wolverine", Goal = 5, Reward = 150 },
	{ Id = "SurviveTime", Text = "Survive Wolverine for 5 minutes total", Goal = 300, Reward = 120 },
	{ Id = "PlayMatches", Text = "Play 3 matches", Goal = 3, Reward = 80 },
}

-- Daily login reward: Base + PerStreakDay * (streak - 1), capped at MaxStreak days
Config.WallRegen = 10 -- seconds before shredded walls/props grow back

-- Skybox: a Creator Store sky model, loaded into Lighting when the server
-- starts. It has to be in the game owner's inventory (Roblox only lets a game
-- load assets its owner has). 0 = the built-in starry night sky.
Config.SkyAssetId = 10594688909
Config.DailyReward = { Base = 50, PerStreakDay = 25, MaxStreak = 7 }

-- Sounds ----------------------------------------------------------------
-- rbxasset:// sounds ship with Roblox. Leave "" to skip a sound.
-- Paste a Creator Store sound ID (rbxassetid://123...) into Roar/Heartbeat/etc
-- to make it much scarier.
Config.Sounds = {
	Snikt = "rbxasset://sounds/unsheath.wav",
	Slash = "rbxasset://sounds/swordslash.wav",
	Lunge = "rbxasset://sounds/swordlunge.wav",
	Land = "rbxasset://sounds/action_jump_land.mp3",
	Gore = "rbxasset://sounds/impact_water.mp3",
	Break = "rbxasset://sounds/action_jump_land.mp3",
	Terminal = "rbxasset://sounds/electronicpingshort.wav",
	Roar = "", -- put a roar sound id here!
	Sniff = "",
	Fart = "", -- put a fart sound id here for maximum comedy
	Heartbeat = "",
	Punch = "rbxasset://sounds/action_jump_land.mp3",
	Laser = "rbxasset://sounds/electronicpingshort.wav",
	-- New crisp SFX (synthesised in tools/generate_sfx.py, upload & paste IDs):
	Whoosh = "rbxasset://sounds/swordlunge.wav",
	Stab = "rbxasset://sounds/swordslash.wav",
	Impact = "rbxasset://sounds/action_jump_land.mp3",
	Leap = "rbxasset://sounds/swordlunge.wav",
	Tear = "rbxasset://sounds/impact_water.mp3",
	UIHover = "rbxasset://sounds/swordslash.wav",
	UIClick = "rbxasset://sounds/unsheath.wav",
	Paw = "rbxasset://sounds/action_jump_land.mp3", -- all-fours footfalls
}

-- CRISP SFX: original sounds synthesised by tools/generate_sfx.py live in
-- assets/sfx/*.ogg. Upload them (Studio: View > Asset Manager > Bulk Import),
-- right-click each > Copy Asset ID, and paste the number next to its name.
-- Anything left at 0 falls back to the built-in sound above.
Config.UploadedSounds = {
	Snikt = 0, Slash = 117112770329180, Whoosh = 0, Stab = 0, Impact = 0, Leap = 0, Land = 0,
	Roar = 72884290623385, Snarl = 0, Tear = 0, Gore = 0, Break = 0, Heartbeat = 94699316471373, Fart = 130496994474771,
	Sniff = 0, Laser = 0, Punch = 0, Terminal = 0, UIHover = 0, UIClick = 0, Paw = 90700737432630,
	PounceHit = 140573962847729, Impale = 100362323212257, DeathRay = 89285816836463, Chase = 71009071343057,
	PounceLeap = 92649317075292, -- pounce launch
	Scream = 94756257053291, -- kill scream after ripping someone in half
	Step = 101289698791450, StepMetal = 112150969278482, StepHeavy = 114217739046080, -- footsteps (4 takes per file; see Anims.lua)
	StepWolverine = 103555591209626, -- Wolverine's heavy adamantium footfalls (4 takes)
	ClawDig = 81900803629932, -- his claws biting into the floor on all fours (4 concrete + 3 steel takes)
	ClawStone = 79213537781413, -- his claws clashing into concrete walls
	ClawFlesh = 137648114004971, -- his claws tearing through a survivor
	SentinelSwing = 103865520255704, -- Sentinel punch wind-up (servos, hydraulics, the fist moving the air)
	SentinelSmash = 93700336440724, -- Sentinel fist landing (on Wolverine or through a wall)
	TerminalHum = 0, -- terminals idling near you (8s loop); paste its ID here once uploaded
}
Config.Sounds.Snarl = Config.Sounds.Snarl or ""
Config.BuiltinSounds = table.clone(Config.Sounds) -- stand-ins if an upload won't play (client/SoundCheck)
for name, id in Config.UploadedSounds do
	if id and id ~= 0 then
		Config.Sounds[name] = "rbxassetid://" .. (type(id) == "number" and string.format("%.0f", id) or tostring(id))
	end
end

-- Pounce / Impale use their own clean sounds once uploaded; until then they
-- reuse the (clean) slash rather than the old built-in sword sounds.
Config.Sounds.PounceHit = Config.Sounds.PounceHit or Config.Sounds.Slash
Config.Sounds.Impale = Config.Sounds.Impale or Config.Sounds.Slash
Config.Sounds.DeathRay = Config.Sounds.DeathRay or Config.Sounds.Laser
Config.Sounds.Chase = Config.Sounds.Chase or ""
Config.Sounds.TerminalHum = Config.Sounds.TerminalHum or "" -- silent until uploaded (beeps still play)
Config.Sounds.Scream = Config.Sounds.Scream or Config.Sounds.Snarl
-- Footsteps: until Step is uploaded, walking keeps Roblox's default running sound.
Config.Sounds.Step = Config.Sounds.Step or ""
Config.Sounds.StepMetal = Config.Sounds.StepMetal or Config.Sounds.Step
Config.Sounds.StepHeavy = Config.Sounds.StepHeavy or Config.Sounds.StepMetal

return Config
