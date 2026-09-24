-- Keyframed animation clips (R15). Poses are joint rotations in degrees:
--   { x, y, z [, tx, ty, tz] }
-- Joint conventions (Motor6D.Transform):
--   Shoulder +x = arm forward/up (90 forward, 180 straight up), +z = right arm out (left arm: -z)
--   Elbow +x = bend.  Hip +x = leg forward.  Knee -x = bend.
--   Root -x = whole body pitches forward, +y = turn left.  Neck +x = head back.
-- Each key: { T = seconds, Ease = "In"|"Out"|"InOut"|"Linear" (easing INTO this key), Pose = {...} }
-- Clips can set Hold = true to freeze on the last key until stopped.

local Clips = {}

local REST = {}

---------------------------------------------------------------------------
-- Wolverine: M1 slash (lunge, claw cocked high behind the head, rip across)
---------------------------------------------------------------------------
Clips.SlashR = {
	Group = "Slash",
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.09, Ease = "Out", Pose = {
			Root = { -10, -28, 0, 0, -0.25, 0 }, Waist = { 6, -22, 0 }, Neck = { -4, 18, 0 },
			RShoulder = { 168, 0, 34 }, RElbow = { 75, 0, 0 },
			LShoulder = { 82, 0, -18 }, LElbow = { 18, 0, 0 },
			RHip = { -28, 0, 0 }, RKnee = { -30, 0, 0 }, LHip = { 42, 0, 0 }, LKnee = { -38, 0, 0 },
		} },
		{ T = 0.19, Ease = "In", Pose = {
			Root = { -24, 32, 0, 0, -0.35, 0 }, Waist = { -12, 32, 0 }, Neck = { -6, -16, 0 },
			RShoulder = { 52, 0, -46 }, RElbow = { 8, 0, 0 },
			LShoulder = { -32, 0, -26 }, LElbow = { 64, 0, 0 },
			RHip = { -38, 0, 0 }, RKnee = { -22, 0, 0 }, LHip = { 48, 0, 0 }, LKnee = { -42, 0, 0 },
		} },
		{ T = 0.5, Ease = "InOut", Pose = REST },
	},
}

---------------------------------------------------------------------------
-- Pounce: crouch, then a full-length dive with both claws out front
---------------------------------------------------------------------------
local DIVE = {
	Root = { -78, 0, 0 }, Waist = { 4, 0, 0 }, Neck = { 58, 0, 0 },
	RShoulder = { 172, 0, 14 }, LShoulder = { 172, 0, -14 }, RElbow = { 6, 0, 0 }, LElbow = { 6, 0, 0 },
	RHip = { -12, 0, 0 }, LHip = { -28, 0, 0 }, RKnee = { -46, 0, 0 }, LKnee = { -18, 0, 0 },
}
Clips.Pounce = {
	Hold = true,
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.1, Ease = "Out", Pose = {
			Root = { -32, 0, 0, 0, -0.9, 0 }, Waist = { -10, 0, 0 }, Neck = { 22, 0, 0 },
			RShoulder = { -45, 0, 26 }, LShoulder = { -45, 0, -26 }, RElbow = { 30, 0, 0 }, LElbow = { 30, 0, 0 },
			RHip = { 72, 0, 0 }, LHip = { 72, 0, 0 }, RKnee = { -112, 0, 0 }, LKnee = { -112, 0, 0 },
		} },
		{ T = 0.24, Ease = "Out", Pose = DIVE },
		{ T = 1.1, Ease = "Linear", Pose = DIVE },
	},
}

-- Contact: both claws slam down into them, landing crouch
Clips.PounceStrike = {
	Keys = {
		{ T = 0, Pose = DIVE },
		{ T = 0.1, Ease = "In", Pose = {
			Root = { -38, 0, 0, 0, -0.6, 0 }, Waist = { -14, 0, 0 }, Neck = { 12, 0, 0 },
			RShoulder = { 102, 0, 10 }, LShoulder = { 102, 0, -10 }, RElbow = { 0, 0, 0 }, LElbow = { 0, 0, 0 },
			RHip = { 62, 0, 0 }, LHip = { 40, 0, 0 }, RKnee = { -95, 0, 0 }, LKnee = { -70, 0, 0 },
		} },
		{ T = 0.3, Pose = {
			Root = { -30, 0, 0, 0, -0.5, 0 }, Waist = { -8, 0, 0 }, Neck = { 18, 0, 0 },
			RShoulder = { 88, 0, 16 }, LShoulder = { 88, 0, -16 },
			RHip = { 55, 0, 0 }, LHip = { 35, 0, 0 }, RKnee = { -85, 0, 0 }, LKnee = { -60, 0, 0 },
		} },
		{ T = 0.65, Ease = "InOut", Pose = REST },
	},
}

---------------------------------------------------------------------------
-- Impale: low crouch, then an uppercut that lifts them overhead on one arm
---------------------------------------------------------------------------
local LIFTED = {
	Root = { 6, 14, 0, 0, 0.1, 0 }, Waist = { 12, 10, 0 }, Neck = { 38, 0, 0 },
	RShoulder = { 176, 0, -6 }, RElbow = { 2, 0, 0 },
	LShoulder = { -22, 0, -28 }, LElbow = { 42, 0, 0 },
	RHip = { -16, 0, 0 }, LHip = { 26, 0, 0 }, RKnee = { -12, 0, 0 }, LKnee = { -18, 0, 0 },
}
Clips.Impale = {
	Hold = true,
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.12, Ease = "Out", Pose = {
			Root = { -16, -22, 0, 0, -0.55, 0 }, Waist = { -6, -12, 0 }, Neck = { 6, 0, 0 },
			RShoulder = { -38, 0, 22 }, RElbow = { 62, 0, 0 },
			LShoulder = { 34, 0, -22 }, LElbow = { 40, 0, 0 },
			RHip = { 42, 0, 0 }, LHip = { -12, 0, 0 }, RKnee = { -64, 0, 0 }, LKnee = { -32, 0, 0 },
		} },
		{ T = 0.25, Ease = "In", Pose = LIFTED },
		{ T = 1.5, Ease = "Linear", Pose = LIFTED },
	},
}

-- Hurl them off the claws
Clips.ImpaleThrow = {
	Keys = {
		{ T = 0, Pose = LIFTED },
		{ T = 0.14, Ease = "In", Pose = {
			Root = { -18, -10, 0 }, Waist = { -14, -18, 0 }, Neck = { -4, 0, 0 },
			RShoulder = { 100, 0, -34 }, RElbow = { 4, 0, 0 },
			LShoulder = { -30, 0, -20 }, RHip = { 30, 0, 0 }, LHip = { -20, 0, 0 },
		} },
		{ T = 0.5, Ease = "InOut", Pose = REST },
	},
}

---------------------------------------------------------------------------
-- Finisher: grab, then tear them apart
---------------------------------------------------------------------------
Clips.Rip = {
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.2, Ease = "Out", Pose = {
			Root = { -6, 0, 0 }, Waist = { -6, 0, 0 }, Neck = { 8, 0, 0 },
			RShoulder = { 122, 0, 10 }, LShoulder = { 122, 0, -10 }, RElbow = { 30, 0, 0 }, LElbow = { 30, 0, 0 },
		} },
		{ T = 0.5, Pose = {
			Root = { -4, 0, 0, 0, -0.2, 0 }, Waist = { -2, 0, 0 }, Neck = { 12, 0, 0 },
			RShoulder = { 128, 0, 14 }, LShoulder = { 128, 0, -14 }, RElbow = { 24, 0, 0 }, LElbow = { 24, 0, 0 },
			RKnee = { -20, 0, 0 }, LKnee = { -20, 0, 0 },
		} },
		{ T = 0.64, Ease = "In", Pose = {
			Root = { 6, 0, 0 }, Waist = { 16, 0, 0 }, Neck = { 38, 0, 0 },
			RShoulder = { 96, 0, 86 }, LShoulder = { 96, 0, -86 }, RElbow = { 8, 0, 0 }, LElbow = { 8, 0, 0 },
		} },
		{ T = 1.1, Pose = {
			Root = { 8, 0, 0 }, Waist = { 18, 0, 0 }, Neck = { 40, 0, 0 },
			RShoulder = { 88, 0, 90 }, LShoulder = { 88, 0, -90 },
		} },
		{ T = 1.4, Ease = "InOut", Pose = REST },
	},
}

---------------------------------------------------------------------------
-- Intro: SNIKT (fists up, claws out) and the roar
---------------------------------------------------------------------------
Clips.Snikt = {
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.18, Ease = "Out", Pose = {
			Waist = { 6, 0, 0 }, Neck = { -12, 0, 0 },
			RShoulder = { 94, 0, 26 }, LShoulder = { 94, 0, -26 }, RElbow = { 112, 0, 0 }, LElbow = { 112, 0, 0 },
			RHip = { 10, 0, 0 }, RKnee = { -18, 0, 0 }, LKnee = { -10, 0, 0 },
		} },
		{ T = 0.3, Ease = "In", Pose = {
			Waist = { 8, 0, 0 }, Neck = { -14, 0, 0 },
			RShoulder = { 100, 0, 38 }, LShoulder = { 100, 0, -38 }, RElbow = { 98, 0, 0 }, LElbow = { 98, 0, 0 },
			RHip = { 10, 0, 0 }, RKnee = { -18, 0, 0 }, LKnee = { -10, 0, 0 },
		} },
		{ T = 1.1, Pose = {
			Waist = { 8, 0, 0 }, Neck = { -14, 0, 0 },
			RShoulder = { 100, 0, 38 }, LShoulder = { 100, 0, -38 }, RElbow = { 98, 0, 0 }, LElbow = { 98, 0, 0 },
			RKnee = { -18, 0, 0 }, LKnee = { -10, 0, 0 },
		} },
		{ T = 1.4, Ease = "InOut", Pose = REST },
	},
}

local ROAR = {
	Root = { 8, 0, 0, 0, -0.35, 0 }, Waist = { 22, 0, 0 }, Neck = { 42, 0, 0 },
	RShoulder = { 30, 0, 72 }, LShoulder = { 30, 0, -72 }, RElbow = { 72, 0, 0 }, LElbow = { 72, 0, 0 },
	RHip = { 6, 0, 12 }, LHip = { 6, 0, -12 }, RKnee = { -22, 0, 0 }, LKnee = { -22, 0, 0 },
}
Clips.Roar = {
	Tremble = true,
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.28, Ease = "Out", Pose = ROAR },
		{ T = 1.7, Pose = ROAR },
		{ T = 2.1, Ease = "InOut", Pose = REST },
	},
}

-- Quick snarl after every kill
Clips.Snarl = {
	Tremble = true,
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.18, Ease = "Out", Pose = { Waist = { 14, 0, 0 }, Neck = { 30, 0, 0 }, RShoulder = { 40, 0, 50 }, LShoulder = { 40, 0, -50 }, RElbow = { 60, 0, 0 }, LElbow = { 60, 0, 0 } } },
		{ T = 0.8, Pose = { Waist = { 14, 0, 0 }, Neck = { 30, 0, 0 }, RShoulder = { 40, 0, 50 }, LShoulder = { 40, 0, -50 }, RElbow = { 60, 0, 0 }, LElbow = { 60, 0, 0 } } },
		{ T = 1.05, Ease = "InOut", Pose = REST },
	},
}

-- Sniff: head up, testing the air
Clips.Sniff = {
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.25, Ease = "Out", Pose = { Neck = { 32, -20, 0 }, Waist = { 6, 0, 0 } } },
		{ T = 0.55, Ease = "InOut", Pose = { Neck = { 30, 22, 0 }, Waist = { 6, 0, 0 } } },
		{ T = 0.85, Ease = "InOut", Pose = { Neck = { 26, 0, 0 } } },
		{ T = 1.1, Ease = "InOut", Pose = REST },
	},
}

---------------------------------------------------------------------------
-- Victim reactions
---------------------------------------------------------------------------
Clips.HitReact = {
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.07, Ease = "Out", Pose = { Root = { 14, 0, 0 }, Waist = { 22, 0, 0 }, Neck = { 26, 0, 0 }, RShoulder = { 40, 0, 50 }, LShoulder = { 40, 0, -50 }, RElbow = { 50, 0, 0 }, LElbow = { 50, 0, 0 } } },
		{ T = 0.5, Ease = "InOut", Pose = REST },
	},
}

Clips.Impaled = {
	Hold = true,
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.15, Ease = "Out", Pose = {
			Root = { 24, 0, 0 }, Waist = { 30, 0, 0 }, Neck = { 44, 0, 0 },
			RShoulder = { 30, 0, 62 }, LShoulder = { 40, 0, -55 }, RElbow = { 20, 0, 0 }, LElbow = { 40, 0, 0 },
			RHip = { 18, 0, 0 }, LHip = { -16, 0, 0 }, RKnee = { -40, 0, 0 }, LKnee = { -20, 0, 0 },
		} },
	},
}

Clips.Grabbed = {
	Hold = true,
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.15, Ease = "Out", Pose = {
			Waist = { 18, 0, 0 }, Neck = { 30, 0, 0 },
			RShoulder = { 140, 0, 40 }, LShoulder = { 140, 0, -40 }, RElbow = { 60, 0, 0 }, LElbow = { 60, 0, 0 },
			RHip = { 20, 0, 0 }, LHip = { -12, 0, 0 }, RKnee = { -50, 0, 0 }, LKnee = { -24, 0, 0 },
		} },
	},
}

Clips.Fart = {
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.15, Ease = "Out", Pose = { Root = { -26, 0, 0 }, Waist = { -12, 0, 0 }, Neck = { 20, 0, 0 }, RHip = { 26, 0, 0 }, LHip = { 26, 0, 0 } } },
		{ T = 0.55, Pose = { Root = { -26, 0, 0 }, Waist = { -12, 0, 0 }, Neck = { 20, 0, 0 }, RHip = { 26, 0, 0 }, LHip = { 26, 0, 0 } } },
		{ T = 0.8, Ease = "InOut", Pose = REST },
	},
}

---------------------------------------------------------------------------
-- Sentinel
---------------------------------------------------------------------------
Clips.Punch = {
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.09, Ease = "Out", Pose = { Waist = { 0, -26, 0 }, Root = { -4, -10, 0 }, RShoulder = { -40, 0, 22 }, RElbow = { 100, 0, 0 }, LShoulder = { 60, 0, -10 }, LElbow = { 80, 0, 0 } } },
		{ T = 0.17, Ease = "In", Pose = { Waist = { -6, 28, 0 }, Root = { -12, 14, 0 }, RShoulder = { 92, 0, 0 }, RElbow = { 0, 0, 0 }, LShoulder = { 20, 0, -20 }, LElbow = { 90, 0, 0 }, LHip = { 24, 0, 0 } } },
		{ T = 0.5, Ease = "InOut", Pose = REST },
	},
}

Clips.Laser = {
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.12, Ease = "Out", Pose = { Waist = { 18, 0, 0 }, Neck = { 12, 0, 0 }, RShoulder = { -30, 0, 44 }, LShoulder = { -30, 0, -44 }, RElbow = { 30, 0, 0 }, LElbow = { 30, 0, 0 }, Root = { 4, 0, 0, 0, -0.2, 0 } } },
		{ T = 0.5, Pose = { Waist = { 20, 0, 0 }, Neck = { 12, 0, 0 }, RShoulder = { -32, 0, 46 }, LShoulder = { -32, 0, -46 }, RElbow = { 30, 0, 0 }, LElbow = { 30, 0, 0 }, Root = { 4, 0, 0, 0, -0.2, 0 } } },
		{ T = 0.75, Ease = "InOut", Pose = REST },
	},
}

-- Death ray: brace and wind the core up, then lean into the beam and hold it
Clips.DeathRay = {
	Hold = true,
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.3, Ease = "Out", Pose = { Waist = { -14, 0, 0 }, Neck = { -10, 0, 0 }, RShoulder = { -40, 0, 30 }, LShoulder = { -40, 0, -30 }, RElbow = { 70, 0, 0 }, LElbow = { 70, 0, 0 }, Root = { 0, 0, 0, 0, -0.5, 0.2 }, RHip = { 30, 0, 8 }, LHip = { -10, 0, -8 }, RKnee = { -40, 0, 0 }, LKnee = { -25, 0, 0 } } },
		{ T = 0.6, Ease = "Back", Pose = { Waist = { 16, 0, 0 }, Neck = { 8, 0, 0 }, RShoulder = { -55, 0, 58 }, LShoulder = { -55, 0, -58 }, RElbow = { 20, 0, 0 }, LElbow = { 20, 0, 0 }, Root = { 6, 0, 0, 0, -0.45, 0 }, RHip = { 34, 0, 10 }, LHip = { -18, 0, -10 }, RKnee = { -36, 0, 0 }, LKnee = { -20, 0, 0 } } },
		{ T = 1.2, Ease = "InOut", Pose = { Waist = { 18, 0, 0 }, Neck = { 9, 0, 0 }, RShoulder = { -58, 0, 60 }, LShoulder = { -58, 0, -60 }, RElbow = { 18, 0, 0 }, LElbow = { 18, 0, 0 }, Root = { 7, 0, 0, 0, -0.45, 0 }, RHip = { 34, 0, 10 }, LHip = { -18, 0, -10 }, RKnee = { -36, 0, 0 }, LKnee = { -20, 0, 0 } } },
	},
	Tremble = true,
}

-- Inhibitor Blast charge: crouch, fists pulled in to the core, trembling with power
Clips.PulseCharge = {
	Hold = true,
	Tremble = true,
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.35, Ease = "Out", Pose = { Root = { 0, 0, 0, 0, -0.6, 0 }, Waist = { -8, 0, 0 }, Neck = { -6, 0, 0 }, RShoulder = { 60, 0, 30 }, LShoulder = { 60, 0, -30 }, RElbow = { 110, 0, 0 }, LElbow = { 110, 0, 0 }, RHip = { 40, 0, 12 }, LHip = { 40, 0, -12 }, RKnee = { -60, 0, 0 }, LKnee = { -60, 0, 0 } } },
		{ T = 2, Ease = "InOut", Pose = { Root = { 0, 0, 0, 0, -0.7, 0 }, Waist = { -12, 0, 0 }, Neck = { -10, 0, 0 }, RShoulder = { 64, 0, 36 }, LShoulder = { 64, 0, -36 }, RElbow = { 118, 0, 0 }, LElbow = { 118, 0, 0 }, RHip = { 44, 0, 14 }, LHip = { 44, 0, -14 }, RKnee = { -66, 0, 0 }, LKnee = { -66, 0, 0 } } },
	},
}

Clips.Pulse = {
	Keys = {
		{ T = 0, Pose = REST },
		{ T = 0.16, Ease = "Out", Pose = { RShoulder = { 170, 0, 20 }, LShoulder = { 170, 0, -20 }, Neck = { 20, 0, 0 }, Waist = { 10, 0, 0 } } },
		{ T = 0.3, Ease = "In", Pose = { RShoulder = { 40, 0, 60 }, LShoulder = { 40, 0, -60 }, Root = { -20, 0, 0, 0, -0.7, 0 }, RHip = { 50, 0, 0 }, LHip = { 50, 0, 0 }, RKnee = { -70, 0, 0 }, LKnee = { -70, 0, 0 } } },
		{ T = 0.75, Ease = "InOut", Pose = REST },
	},
}

---------------------------------------------------------------------------
-- Mirroring (makes SlashL from SlashR)
---------------------------------------------------------------------------
local SWAP = {
	RShoulder = "LShoulder", LShoulder = "RShoulder", RElbow = "LElbow", LElbow = "RElbow",
	RWrist = "LWrist", LWrist = "RWrist", RHip = "LHip", LHip = "RHip",
	RKnee = "LKnee", LKnee = "RKnee", RAnkle = "LAnkle", LAnkle = "RAnkle",
}
local function mirror(clip)
	local out = { Group = clip.Group, Hold = clip.Hold, Tremble = clip.Tremble, Keys = {} }
	for _, k in clip.Keys do
		local pose = {}
		for joint, a in k.Pose do
			pose[SWAP[joint] or joint] = { a[1], -a[2], -a[3], -(a[4] or 0), a[5] or 0, a[6] or 0 }
		end
		table.insert(out.Keys, { T = k.T, Ease = k.Ease, Pose = pose })
	end
	return out
end
Clips.SlashL = mirror(Clips.SlashR)

return Clips
