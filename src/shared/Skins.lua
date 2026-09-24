-- Wolverine skins. Prices are in Coins (earned by playing).
-- "Skin" in a colour slot means "keep the player's own skin tone".
local rgb = Color3.fromRGB

local YELLOW = rgb(245, 195, 20)
local BLUE = rgb(25, 60, 150)
local DENIM = rgb(48, 66, 104)
local LEATHER = rgb(92, 60, 38)
local BOOT = rgb(55, 38, 26)

local Skins = {}

Skins.Order = { "Logan", "Comic", "WeaponX", "OldManLogan" }

Skins.List = {
	Logan = {
		Name = "Logan",
		Price = 0,
		Description = "The regular. Tank top, leather jacket, sideburns.",
		Swatch = LEATHER,
		Colors = {
			UpperTorso = rgb(225, 225, 220), LowerTorso = DENIM,
			UpperArm = LEATHER, LowerArm = LEATHER, Hand = "Skin",
			UpperLeg = DENIM, LowerLeg = DENIM, Foot = BOOT,
		},
		KeepHair = true,
	},
	Comic = {
		Name = "Comic Wolverine",
		Price = 500,
		Description = "Straight off the page. Yellow and blue with the iconic cowl.",
		Swatch = YELLOW,
		Colors = {
			UpperTorso = YELLOW, LowerTorso = BLUE,
			UpperArm = YELLOW, LowerArm = YELLOW, Hand = BLUE,
			UpperLeg = YELLOW, LowerLeg = BLUE, Foot = BLUE,
		},
	},
	WeaponX = {
		Name = "Weapon X",
		Price = 1000,
		Description = "Fresh out of the tank. Wired helmet, scars, nothing to lose.",
		Swatch = rgb(120, 200, 190),
		Colors = {
			UpperTorso = "Skin", LowerTorso = rgb(55, 58, 64),
			UpperArm = "Skin", LowerArm = "Skin", Hand = "Skin",
			UpperLeg = rgb(55, 58, 64), LowerLeg = "Skin", Foot = "Skin",
		},
	},
	OldManLogan = {
		Name = "Old Man Logan",
		Price = 1500,
		Description = "Grey beard, long coat, and a lot of anger left.",
		Swatch = rgb(150, 150, 150),
		Colors = {
			UpperTorso = rgb(88, 94, 104), LowerTorso = rgb(60, 44, 34),
			UpperArm = rgb(60, 44, 34), LowerArm = rgb(60, 44, 34), Hand = "Skin",
			UpperLeg = rgb(40, 44, 54), LowerLeg = rgb(40, 44, 54), Foot = BOOT,
		},
	},
}

Skins.Default = "Logan"

-- Coins handed out by the server
Skins.Rewards = {
	Survive = 60,
	Kill = 25,
	WolverineWin = 100,
	Terminal = 15,
	SentinelTakedown = 150,
	Participation = 10,
}

return Skins
