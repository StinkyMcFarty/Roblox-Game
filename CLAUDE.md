# Survive the Wolverine

A Roblox game written as code with Rojo. `default.project.json` maps `src/` into the place:
`src/shared` → ReplicatedStorage.Shared, `src/server` → ServerScriptService.Server,
`src/client` → StarterPlayerScripts.Client, `src/playerscripts/CharacterOutline.client.lua` →
StarterPlayerScripts.CharacterOutline, `src/character/Health.server.lua` → StarterCharacterScripts.

- Rebuild the place after code edits: `rojo build -o SurviveTheWolverine.rbxlx`.
- The user live-syncs with `rojo serve` + the Studio Rojo plugin into their own place file,
  **Berserker Rage** (Windows, repo cloned with GitHub Desktop). They are new to Rojo and git;
  give them short, click-by-click steps. They start the server by double-clicking
  `Start Rojo.bat` (runs `rojo.exe` from the repo folder, which git ignores; the Studio plugin is
  Rojo 7.7.0), then press Connect in the plugin.
- Sounds are synthesised by `tools/generate_sfx.py` (`python3 tools/generate_sfx.py <Name>` writes
  only that sound); store icons by `tools/generate_icons.py` into `assets/icons/`.
- `tools/preview/` renders suits offline: `run.py` runs the real `Costumes.lua` (Luau shimmed to Lua
  5.4 via lupa, mock Roblox API in `prelude.lua`) on a blocky R15 rig and dumps `scene.json`;
  `render.js` draws it with three.js (clothing templates from `assets/textures/`). Serve the repo
  root on :8765, then `node tools/preview/shot.cjs out.png "scenes=wolverine:Comic/Adamantium&views=25,160"`.
  `npm i` in tools/preview and `pip install lupa pillow` first.
- Thumbnail / icon (`assets/marketing/`): `tools/preview/thumb_scene.py` builds the Sentinel Hangar with
  the real `Facility.Build` and poses characters (`ready`, `guard`, `charge` poses) into `hangar.json` /
  `chars.json`; `thumb.html` renders them with cinematic lights, haze beams, sparks and bloom
  (`node tools/preview/thumb_shot.cjs out.png "$(cat tools/preview/thumb_thumbnail.query)" 2560 1440`,
  add `&depth=1` for the depth pass); `thumb_post.py raw depth out W H` adds background depth of
  field, haze, a painterly Kuwahara pass, the grade, glow, vignette, fringing and grain.
- **Before pushing server changes run `python3 tools/preview/smoke.py`**: it builds the lobby and the
  round map (`Facility.Build`), and dresses every suit/claw/Sentinel skin and the survivor outfit against a strict mock (Roblox API dump: unknown
  properties, bad enums and wrong value types throw like the engine). A throw in `BuildLobby`
  kills GameManager at startup (no lobby, no sprint, timer stuck on --:--). Also compile-check
  with the real `luau-compile` (github.com/luau-lang/luau releases) when available.
- `tools/publish.sh` publishes via Open Cloud (needs `ROBLOX_API_KEY`, `ROBLOX_UNIVERSE_ID`,
  `ROBLOX_PLACE_ID`).

## Still broken in the published game

- **Sniff tracker (F)** reportedly doesn't work live; it worked in Studio. Server:
  `Wolverine.lua` `sniff()` fires Fx `Sniff` / `SniffUpdate` with `Fart.SniffTargets()`. Client:
  `Effects.Sniff` / `syncScents` in `src/client/Effects.lua` draw red ghost outlines (Highlight,
  AlwaysOnTop, parts in CurrentCamera). Not yet known whether the announce text
  ("You catch their scent" / "No scent") shows live.
- **Some SFX missing live**: likely audio ownership (group-owned game vs user-owned audio) or
  moderation. `src/client/SoundCheck.lua` preloads every `Config.UploadedSounds` entry on join,
  prints `[Sounds] ...` in the F9 console for each failure, and swaps in `Config.BuiltinSounds`.

## Game rules worth knowing

- Cooldowns (`Config.Abilities`): Pounce 15s, Impale 15s. A landed M1 locks slash/pounce/impale
  for 3s on a survivor, 1s on a Sentinel (`lockClaws` in `Wolverine.lua`, client via Fx `ClawLock`).
- I-frames: an M1 just breaks them; pounce/impale break them, miss, and still go on cooldown.
  Wolverine gets 2s of i-frames when a Sentinel punch lands.
- Rage (`Config.Rage`, `updateRage` in `Wolverine.lua`): below 40% HP, at most twice a round (once
  per dip), 15s of red aura, slashes 1.35x faster, hits count 1.3x (`Combat.Hit` amount; Hits/Armor
  can be fractional), other cooldowns x0.75. Client reads the `Rage` attribute for its timers.
  It opens with a roar (`Config.Rage.RoarTime` 1.5s, clip `RageRoar`, Fx `RageRoar`): frozen and
  untouchable (`roarUntil`), then the Duration starts. While raging `Anims.lua` adds `rageHunch`
  and heavier breathing with exhale puffs (`rageExhale`).
- Sniff is on R. The death-ray resist mash is F (`Resist` action in ClientMain; with no keyboard
  the Sniff button does it). The release cutscene (5.5s) is timed by
  `Config.IntroLength` / `Config.Intro`: float, wake, two kicks crack the tank (`crackGlass`),
  a flying kick shatters it (`shatterTank`: shards; the column collapses as falling water blobs
  (server-owned, splash where `landing()` says they come down), floods the plinth, spills over
  its lip and spreads across the floor found by raycast, not the plinth top).
- Impale (`stab` in `Wolverine.lua`): claws burst out their back (`SlashFX.ImpaleBurst`); a
  survivor who lives is kicked off the blades (`ImpaleKick`). A Sentinel is heaved overhead on
  both claws (`ImpaleHeavy`) and shocks him for `Config.Wolverine.ImpaleShock` (7%) of his health;
  Sentinels spark (`Electric` Fx) when impaled or torn apart.
- Pounce is a scripted dive arc (`Effects.Leap`): Height 7.6, AirTime 0.92, Forward 78 (~72 studs).
  It keeps full speed through breakable walls: `clearAhead` makes `Breakable` parts (and
  `Debris` chunks) just ahead non-colliding on his client while the server's pounce loop smashes
  them; unbroken ones are solid again 0.6s after the leap.
- Running does not break walls; M1, pounce, impale and Sentinel punches do. Wall cores carry a
  `Surface` attribute (`Facility.lua`) that picks the clash effect (`Combat.StoneClash` etc).
- Sentinels: linked (within 30 studs of each other) hit at 1.25x, apart 0.6x, a lone suit 1x.
  Pursuit thrusters (`Config.Sentinel.Pursuit`, `Movement.lua`): once Wolverine hasn't hit a
  suit for 2.5s (`HitGrace`; `Combat.Hit` refreshes the `PursuitHold` status) it gets +14 speed,
  cut the moment he hits it again. Death ray: 32.4 DPS, range 260, x1.5 (390) while he's
  `Laser.FarAt` (70)+ studs from that suit. The pilot aims left/right; within `Laser.LockWidth`
  (4) studs of its line the beam tilts onto him, so jumping doesn't dodge it.
  Inhibitor Blast (`Config.Sentinel.Pulse`): radius 30, shatters his i-frames, and during its
  stun a punch grants i-frames only every 2nd hit (`pulseStun` in `Sentinel.lua`).
- Sentinel walk/run: `SENTINEL LOCOMOTION` block in `Anims.lua` (`heavyLeg` stride model,
  `stompPose` walk, `chargePose` run above 23 speed, `sentinelWarp` lingers on each footfall;
  translations scale with the suit via `st.Scale`). Heels strike at phase 0/pi: `stompDust` +
  shake + StepHeavy. Preview the cycle: `python3 tools/preview/cycle.py stomp 10 none`, then
  render with `compose=1&nofloor=1`.
- Sentinel moves run one at a time (`perform`/`acting` in `Sentinel.lua`, `Acting` attribute).
  Ground Slam (`Config.Sentinel.Slam`, right mouse / L2): 1.75x punch damage within 30 studs;
  floor cracks are client-side (`SlashFX.GroundSlam`) and heal after `Config.WallRegen`.
- Sentinel footsteps: `SentinelWalk.ogg` / `SentinelRun.ogg` (4 takes each: the leg motor, then the
  steel foot clanking down at `Lead` seconds, then hydraulics venting). `Anims.lua` starts each take
  `Lead` ahead of the heel strike (phase 0/pi) so the clank lands on it; dust and shake stay on the
  strike. (Both are uploaded; with either at 0 in `Config.UploadedSounds` it plays the old `StepHeavy`.)
- Sentinel punch VFX (`SlashFX.Smash`): a ForceField pressure disc, two thick shock rings, a cone of
  speed spikes, steam venting from the punching arm's elbow, sparks + flare on a hit.
- Sentinels see Wolverine's outline through walls while they're 50+ studs from him
  (`src/client/SentinelTracker.lua`). A fart while sprinting skips the sprint build-up
  (`Movement.MaxOut`). Death ray colours live in the `BEAM` table in `SlashFX.lua`.
- Client Highlights/adornments are parented in the workspace, not `CurrentCamera` (suspected cause
  of Sniff ghosts not drawing live; ghosts now go in a local `ScentGhosts` folder).
- Minimap (`src/client/Minimap.lua`, top left; M shows/hides it, tap/click enlarges): short room names
  (`SHORT`), the Sentinel docks as two heads (`Pod` in the JSON), rooms + floor-standing
  wall pieces published by `publishMinimap` in `Facility.lua` (ReplicatedStorage attribute
  `Minimap`, JSON). It shows only the local player - never other players or Wolverine.
- Terminal ambience (`src/client/TerminalSounds.lua`): beeps (`Terminal`) and an idle hum
  (`TerminalHum`), both uploaded.
- Survivor upgrades (`Config.Upgrades`, `PlayerData.BuyUpgrade`/`HasUpgrade`, saved as `Upgrades`,
  UI `src/client/Upgrades.lua` on the lobby dock). They're powers on G and only ONE is equipped
  (`PlayerData.Power`/`EquipUpgrade`, saved + attribute `Power`, "" = plain fart; buying equips).
  Turbo Fart (300): every fart also gives `FartBoost` (+8 speed, 2.5s) and a gas trail that fades
  after 2s (`Fart.Trail`). Dodge (300): replaces the fart; G gives 0.5s of i-frames (`Fart.Dodge`,
  statuses `Immune` + `Dodging`), 30s cooldown; a hit in that window whiffs (`Combat.BreakShield`
  fires Fx `Dodged`) and a landed dodge gives `DodgeBoost` (x1.25 speed, 3s). Invisibility (500):
  replaces the fart, 8s gone, 40s cooldown (`Fart.Vanish`, character attribute `Invisible`;
  `src/client/Vanish.lua` hides them on every other client and shows the owner a ghost outline;
  Sniff still finds them; a hit or suiting up ends it). Dodge also costs 500. Client swaps the G
  kit entry by `Power` (`DODGE_KIT`/`VANISH_KIT`/`TURBO_KIT`).
- Wolverine suits (`Costumes.lua`): everyone is a blocky R15 (`blockyDescription`). Shared sculpt
  helpers `shoulders` (rolls + deltoid caps), `physique` (pecs, abs, traps), `pointFlap` (comic
  cuff/boot points). Comic and Weapon X no longer use a Shirt texture (the top is 3D); body
  colours only turn skin-tone under a texture that covers that slot (`SHIRT_SLOTS`/`PANTS_SLOTS`).
- Sentinel suit skins: palettes in `Costumes.SentinelSkins`, shop data in `Skins.Sentinels`
  (Armory SENTINEL tab, `PlayerData.BuySentinel`/`EquipSentinel`, saved `OwnedSentinels`/
  `SentinelSkin`). Verity (3000): black/yellow suit with the grin (`Costumes.Smiley`) on its face;
  Verity claws (3000) are yellow blades covered in grins (`SmileyStrip`, `drawGrin`), a black
  edge and a grin badge on each forearm; running with them out sheds a trail of tiny faces
  (`src/client/VerityTrail.lua`). Claw cases aren't Glass (Glass hides SurfaceGuis behind it).
- Survivors see a white glow on the 6 nearest hiding spots (`src/client/HideGlow.lua`); keep the
  client's Highlight count low (Roblox caps it at 31), which is why Sniff ghosts also draw boxes.
- Sentinel pilot exit: destroyed by Wolverine → Hits = 2 (one from death); timed out → full health.
- Lobby how-to-play board (`RULES WALL` in `MapBuilder.lua`, north wall): a notice board with
  pinned paperwork (staff memo = survivors, Subject X file = Wolverine, blueprint pilot card =
  Sentinels), key caps, sticky notes. Numbers come from `Config`; update the copy when controls
  or mechanics change.
- No resetting in a round: ClientMain `syncReset` sets `ResetButtonCallback` false while the
  role is Survivor/Wolverine/Sentinel (true in the lobby or dead).
- Map brightness setting (`Config.Brightness`, five levels, 3 = as built): sun button top left
  (`src/client/Brightness.lua`), applied in `Effects.lua` on top of the lobby/arena lighting zone
  (`Effects.SetBrightness`: exposure offset + ambient scale), saved as `Brightness` in
  PlayerData (Shop remote action "Brightness").
- Auto-AFK (`Config.AutoAfk`, `Store.lua`): Roblox's `Idled` marks you AFK only while in the
  lobby, and any input clears it; the AFK button's own AFK stays on.
- Currency is shown as "Berserker Coins" (`Config.CoinName`); saves still use the key `Coins`.
- leaderstats Wins and Kills are saved (`PlayerData.AddStat`, GameManager `stat`); everyone is
  saved after each round (`PlayerData.SaveAll`).
- Lobby shell (`BuildLobby` in `MapBuilder.lua`): walls are dressed per wall (`walls` table, `onWall`
  places parts along each inner face; `gaps` keep the band/ring beam off the windows, notice board
  and claw gouges). Light fittings use `fitting()` (CastShadow = false): a shadowed lamp whose own
  bulb or shade is in front of it shadows the floor it lights (the old hanging lamps did). Nothing
  goes across the south windows; the claw and WEAPON X signs hang above them.
- Lobby preview: the preview mock can build the lobby (`MapBuilder.BuildLobby`); `Color3:ToHSV` in
  `prelude.lua` returns real hues (the lobby softens its neon through HSV).
- Facility light fittings are real lights, not Neon: the lit diffuser/lens is a `glowFace`
  (SurfaceGui, LightInfluence 0) on SmoothPlastic, the light itself a Surface/SpotLight.
  Panelled (Coffered) rooms: a plain grid, one `troffer` per 16 x 20 studs, each brighter by
  how many fewer there are than the old 12 x 16 grid (so rooms stay as bright).
- Lighting (`MapBuilder.SetupLighting`): gentle grade (contrast 0.15, saturation 0.08), bloom
  0.55/40/1.35 (client arena zone matches), low blue-grey ambient so lamps shape the rooms.
  Foundry: cool work floods, forged-steel crucibles (one pouring into a mould).
- Sky: `Config.SkyAssetId` loads via InsertService at server start unless a Sky is placed in
  Lighting in Studio.
- Facility floors (`FLOORS` in `Facility.lua`, keyed by the kind each room passes to `floorTiles`):
  steel deck (`Grate`), concrete slabs (`Corridor`, `Hangar`), terrazzo (`LabTile`), canteen
  linoleum (`Checker`), carpet (`Carpet`, `WarmCarpet`), raised floor with vents (`Rubber`), slate
  (`DarkTile`).
- LIFE & WEAR (`lifeAndWear` in `Facility.lua`): steam vents, sparking torn cables, wall fans,
  leaks + puddles, stains, claw gashes with blood, paperwork, flickering tubes, lockdown beacons
  (spinning amber lamp + Beam shaft). `src/client/MapLife.lua` animates tags `Spin` (Model about
  its pivot's Z, or Y with attribute `Axis = "Y"`), `Sparks` and `SteamBurst` near the camera.
  Floor layers have fixed heights (see the section comment); keep new floor decals off them.
- Z-fighting: `python3 tools/preview/zfight.py <dump.json> --detail --floor <floorY>` lists
  coplanar overlapping faces/SurfaceGuis that are visible and look different, with the gap.
  Dumps: `run.py` (suits), `thumb_scene.py` with `FULLMAP=1 ROOMFILE=map.json` (whole facility).
  Anything at gap 0.000 is real (bar round parts, which it approximates as squares).
- Stamina bar (`Interface.lua`): no label, just the number (100 when rested, counts down).
- Objectives panel (`src/client/Objectives.lua`, left, just under the minimap) replaces the old
  top-centre terminal counter. Survivors: repair the terminals (n/total), activate the Sentinel
  suits, then "Hunt the Berserker" once someone is in a suit; Sentinels: hunt the Berserker;
  Wolverine: "Hunt the scientists kills/n" (ReplicatedStorage `SurvivorsTotal` / `Kills`, set by
  GameManager at round start and on each kill).

## Monetization (IDs in `src/shared/Config.lua`)

A developer product only sells in the experience it was made in (a foreign ID gives Roblox's
"something went wrong"). `checkProducts` in `PlayerData.lua` checks the IDs against the game's own
products at server start, swaps a foreign one for this game's product with the same name (else the
same unique price), warns `[Store] ...` in the server console with the ID to paste into Config, and
publishes the IDs in use (ReplicatedStorage `ProductIds`, read by `Config.ProductId`). Game pass
IDs aren't checked.

| Item | Price | Config |
| --- | --- | --- |
| 2x Wolverine Chance (Game Pass) | R$250 | `DoubleChanceGamepassId` |
| Become Wolverine | R$29 | `GuaranteedWolverineProductId` (the button shows no price; the Roblox prompt does) |

Become Wolverine tokens queue (`queueOf` in `PlayerData.lua`): earlier rounds first, same-round
buyers in random order; the rest keep their token for later rounds (attribute `WolverineQueue`).
| Handful of Berserker Coins (500) | R$49 | `CoinPacks[1].ProductId` |
| Pouch of Berserker Coins (1,200) | R$99 | `CoinPacks[2].ProductId` |
| Crate of Berserker Coins (3,000) | R$199 | `CoinPacks[3].ProductId` |
| Weapon X Vault (7,000) | R$399 | `CoinPacks[4].ProductId` |
