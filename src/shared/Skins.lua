-- Wolverine skins. Prices are in Coins (earned by playing).
-- "Skin" in a colour slot means "keep the player's own skin tone".
--
-- REALISTIC TEXTURES: the painted suit textures live in assets/textures/.
-- Upload them in Studio (View > Asset Manager > Bulk Import), right-click
-- each image > Copy Asset ID, and paste the numbers into Textures below.
-- Until then each suit uses its flat colours + 3D gear.
-- HairAccessoryId: optional Marketplace hair accessory ID (e.g. a messy
-- "Wolverine hair"). 0 keeps the player's own hair.
local rgb = Color3.fromRGB

local YELLOW = rgb(245, 195, 20)
local BLUE = rgb(25, 60, 150)
local DENIM = rgb(48, 66, 104)
local BOOT = rgb(55, 38, 26)

local Skins = {}

Skins.Order = { "Logan", "Comic", "WeaponX", "OldManLogan" }

Skins.List = {
	Logan = {
		Name = "Logan",
		Price = 0,
		Description = "The regular. Grey tee, jeans, beard and a bad attitude.",
		Swatch = rgb(196, 198, 196),
		Colors = {
			UpperTorso = rgb(196, 198, 196), LowerTorso = DENIM,
			UpperArm = rgb(196, 198, 196), LowerArm = "Skin", Hand = "Skin",
			UpperLeg = DENIM, LowerLeg = DENIM, Foot = BOOT,
		},
		KeepHair = true,
		Textures = { Shirt = 72143365011183, Pants = 80981964263373, Face = 127116209556275 },
		HairAccessoryId = 0,
	},
	Comic = {
		Name = "Comic Wolverine",
		Price = 2000,
		Description = "Jim Lee classic. Wild hair, mutton chops, shoulder pads, tiger stripes.",
		KeepHair = true,
		Textures = { Shirt = 112579941158359, Pants = 84892200431804, Face = 108529900389924 },
		HairAccessoryId = 0,
		Swatch = YELLOW,
		Colors = {
			UpperTorso = YELLOW, LowerTorso = BLUE,
			UpperArm = "Skin", LowerArm = BLUE, Hand = BLUE,
			UpperLeg = YELLOW, LowerLeg = BLUE, Foot = BLUE,
		},
	},
	WeaponX = {
		Name = "Weapon X",
		Price = 4000,
		Description = "Fresh out of the tank. Visor helmet, cables, harness, scars.",
		Textures = { Shirt = 125698769813626, Pants = 121111924489660, Face = 101452932954846 },
		HairAccessoryId = 0,
		Swatch = rgb(120, 200, 190),
		Colors = {
			UpperTorso = "Skin", LowerTorso = rgb(55, 58, 64),
			UpperArm = "Skin", LowerArm = "Skin", Hand = "Skin",
			UpperLeg = rgb(55, 58, 64), LowerLeg = "Skin", Foot = "Skin",
		},
	},
	OldManLogan = {
		Name = "Old Man Logan",
		Price = 6000,
		Description = "Grey beard, long duster coat, and a lot of anger left.",
		KeepHair = true,
		Textures = { Shirt = 91199990464230, Pants = 131767294384086, Face = 109948303211918 },
		HairAccessoryId = 0,
		Swatch = rgb(150, 150, 150),
		Colors = {
			UpperTorso = rgb(88, 94, 104), LowerTorso = rgb(60, 44, 34),
			UpperArm = rgb(60, 44, 34), LowerArm = rgb(60, 44, 34), Hand = "Skin",
			UpperLeg = rgb(40, 44, 54), LowerLeg = rgb(40, 44, 54), Foot = BOOT,
		},
	},
}

Skins.Default = "Logan"

-- Claw skins (separate from suits)
Skins.ClawOrder = { "Adamantium", "Bone", "Gold", "Blood", "Obsidian", "Cosmic" }
Skins.DefaultClaw = "Adamantium"
Skins.Claws = {
	Adamantium = {
		Name = "Adamantium", Price = 0, Description = "Unbreakable. The classic.",
		Color = rgb(210, 214, 222), Material = Enum.Material.Metal, Reflectance = 0.4, Glow = rgb(210, 230, 255),
	},
	Bone = {
		Name = "Bone Claws", Price = 400, Description = "Before the metal. Raw and jagged.",
		Color = rgb(232, 222, 196), Material = Enum.Material.SmoothPlastic, Reflectance = 0, Glow = rgb(255, 235, 200), Thick = 1.5,
	},
	Gold = {
		Name = "Gold", Price = 900, Description = "Flex while you shred.",
		Color = rgb(255, 196, 40), Material = Enum.Material.Metal, Reflectance = 0.5, Glow = rgb(255, 210, 80),
	},
	Blood = {
		Name = "Blood-Soaked", Price = 1100, Description = "They never get clean. Drips as you move.",
		Color = rgb(130, 0, 0), Material = Enum.Material.SmoothPlastic, Reflectance = 0.25, Glow = rgb(255, 30, 30), Drip = true,
	},
	Obsidian = {
		Name = "Obsidian", Price = 1400, Description = "Black glass edges with a violet gleam.",
		Color = rgb(22, 20, 28), Material = Enum.Material.Glass, Reflectance = 0.35, Glow = rgb(150, 60, 255),
	},
	Cosmic = {
		Name = "Cosmic", Price = 2200, Description = "Forged in a dying star. Glows and sparkles.",
		Color = rgb(120, 90, 255), Material = Enum.Material.Neon, Reflectance = 0, Glow = rgb(90, 220, 255), Sparkle = true,
	},
}

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
