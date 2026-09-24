-- Every tunable number in the game lives here.
local Config = {}

-- Rounds ----------------------------------------------------------------
Config.MinPlayers = 1 -- a round starts even with 1 player (bots fill in)
-- If there are fewer survivors than this, bot survivors are added so
-- Wolverine always has someone to hunt.
Config.BotFill = 5
Config.IntermissionTime = 20
Config.RoundTime = 150 -- seconds survivors must last (after the intro)
Config.KillTimeBonus = 15 -- Wolverine gets this much extra time per kill
Config.EndScreenTime = 6

-- Wolverine intro (he is locked in the Weapon X tank room)
Config.IntroLength = 7 -- seconds before he is released
Config.ClawPopTime = 2.5 -- SNIKT
Config.RoarTime = 3.8

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
	Stamina = 5, -- seconds of sprint
	StaminaRegen = 0.8, -- seconds of sprint regained per second
}

Config.Wolverine = {
	MaxHealth = 600,
	HealPerSecond = 14, -- healing factor
	HealDelay = 3, -- seconds after taking damage before healing starts
	Scale = 1.15,
	WalkSpeed = 17,
	SprintSpeed = 23,
	FeralSpeed = 31, -- running on all fours
	FeralStamina = 4.5,
	FeralRegen = 0.6,
	ShredSpeed = 19, -- moving faster than this tears through walls in his path
}

Config.Abilities = {
	Slash = { Cooldown = 0.55, Range = 8, Width = 8 },
	Pounce = { Cooldown = 9, Forward = 90, Up = 38, GrabRadius = 6.5, Window = 1.0 },
	Stab = { Cooldown = 6, Range = 8, Lunge = 60 },
	Sniff = { Cooldown = 25, Duration = 5 }, -- only 5s of tracking so he can't wallhack all round
}

-- The counter: reboot 3 Sentinel terminals, then a survivor can suit up.
Config.Sentinel = {
	HoldTime = 4,
	PodHoldTime = 2,
	Duration = 45, -- the suit powers down after this
	Armor = 4, -- Wolverine hits needed to destroy it (the last one rips it in half)
	Suits = 2, -- how many survivors can suit up per round
	-- Teamwork: suits within LinkRange of each other are "linked" and hit hard.
	-- Alone they barely scratch him (his healing outpaces them).
	LinkRange = 30,
	LinkedMultiplier = 1.6,
	SoloMultiplier = 0.5,
	WalkSpeed = 18,
	Scale = 1.35,
	Punch = { Cooldown = 0.9, Damage = 40, Range = 9, Stun = 0.6, Knockback = 70 },
	-- Laser burns through walls and flashes Wolverine's adamantium skeleton
	Laser = { Cooldown = 4, Damage = 30, Range = 260, Slow = 2.5, WallsBurned = 3 },
	Pulse = { Cooldown = 18, Radius = 16, Stun = 2.2, Damage = 10 },
}

-- Survivor fart: masks your scent from Wolverine's Sniff
Config.Fart = { Cooldown = 60, MaskTime = 20, CloudTime = 20 }

-- Monetization ----------------------------------------------------------
-- Create a Developer Product (80 Robux) in the Creator Dashboard under
-- your experience > Monetization > Developer Products, then paste its ID here.
Config.GuaranteedWolverineProductId = 0

-- Every round you play without being Wolverine adds this much weight to
-- your odds (everyone starts at weight 1).
Config.WolverinePityWeight = 1

-- Daily challenges (reset every day at 00:00 UTC). Rewards are coins.
Config.DailyChallenges = {
	{ Id = "BecomeWolverine", Text = "Become Wolverine", Goal = 1, Reward = 100 },
	{ Id = "WolverineKills", Text = "Rip apart 5 survivors as Wolverine", Goal = 5, Reward = 150 },
	{ Id = "SurviveTime", Text = "Survive Wolverine for 5 minutes total", Goal = 300, Reward = 120 },
	{ Id = "PlayMatches", Text = "Play 3 matches", Goal = 3, Reward = 80 },
}

-- Daily login reward: Base + PerStreakDay * (streak - 1), capped at MaxStreak days
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
}

return Config
