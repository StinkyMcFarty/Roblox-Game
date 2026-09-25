# Survive the Wolverine

A Roblox game written as code with Rojo. `default.project.json` maps `src/` into the place:
`src/shared` → ReplicatedStorage.Shared, `src/server` → ServerScriptService.Server,
`src/client` → StarterPlayerScripts.Client, `src/playerscripts/CharacterOutline.client.lua` →
StarterPlayerScripts.CharacterOutline, `src/character/Health.server.lua` → StarterCharacterScripts.

- Rebuild the place after code edits: `rojo build -o SurviveTheWolverine.rbxlx`.
- The user live-syncs with `rojo serve` + the Studio Rojo plugin into their own place file,
  **Berserker Rage** (Windows, repo cloned with GitHub Desktop). They are new to Rojo and git;
  give them short, click-by-click steps.
- Sounds are synthesised by `tools/generate_sfx.py` (`python3 tools/generate_sfx.py <Name>` writes
  only that sound); store icons by `tools/generate_icons.py` into `assets/icons/`.
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
- Sniff is on R (also the death-ray resist mash). The release cutscene (5.5s) is timed by
  `Config.IntroLength` / `Config.Intro`: float, wake, two kicks crack the tank (`crackGlass`),
  a flying kick shatters it (`shatterTank`: shards, torrent, spreading puddle).
- Impale (`stab` in `Wolverine.lua`): claws burst out their back (`SlashFX.ImpaleBurst`); a
  survivor who lives is kicked off the blades (`ImpaleKick`). A Sentinel is heaved overhead on
  both claws (`ImpaleHeavy`) and shocks him for `Config.Wolverine.ImpaleShock` (7%) of his health;
  Sentinels spark (`Electric` Fx) when impaled or torn apart.
- Pounce is a scripted dive arc (`Effects.Leap`): Height 7.6, AirTime 0.92, Forward 78 (~72 studs).
- Running does not break walls; M1, pounce, impale and Sentinel punches do. Wall cores carry a
  `Surface` attribute (`Facility.lua`) that picks the clash effect (`Combat.StoneClash` etc).
- Sentinels: linked (within 30 studs of each other) hit at 1.25x, apart 0.6x, a lone suit 1x.
  Pursuit thrusters (`Config.Sentinel.Pursuit`, `Movement.lua`): once Wolverine is 70+ studs
  away a suit gets +14 speed until it's back within 30 studs. Death ray: 32.4 DPS, range 260,
  x1.5 (390) while he's 70+ studs from that suit.
  Inhibitor Blast (`Config.Sentinel.Pulse`): radius 30, shatters his i-frames, and during its
  stun a punch grants i-frames only every 2nd hit (`pulseStun` in `Sentinel.lua`).
- Sentinel moves run one at a time (`perform`/`acting` in `Sentinel.lua`, `Acting` attribute).
  Ground Slam (`Config.Sentinel.Slam`, right mouse / L2): 1.75x punch damage within 30 studs;
  floor cracks are client-side (`SlashFX.GroundSlam`) and heal after `Config.WallRegen`.
- Sentinels see Wolverine's outline through walls while they're 50+ studs from him
  (`src/client/SentinelTracker.lua`). A fart while sprinting skips the sprint build-up
  (`Movement.MaxOut`). Death ray colours live in the `BEAM` table in `SlashFX.lua`.
- Client Highlights/adornments are parented in the workspace, not `CurrentCamera` (suspected cause
  of Sniff ghosts not drawing live; ghosts now go in a local `ScentGhosts` folder).
- Minimap (`src/client/Minimap.lua`, top left; M shows/hides it, tap/click enlarges): short room names
  (`SHORT`), the Sentinel docks as two heads (`Pod` in the JSON), rooms + floor-standing
  wall pieces published by `publishMinimap` in `Facility.lua` (ReplicatedStorage attribute
  `Minimap`, JSON). It shows only the local player - never other players or Wolverine.
- Terminal ambience (`src/client/TerminalSounds.lua`): beeps now; the hum needs
  `assets/sfx/TerminalHum.ogg` uploaded and its ID in `Config.UploadedSounds.TerminalHum`.
- Survivor upgrades (`Config.Upgrades`, `PlayerData.BuyUpgrade`/`HasUpgrade`, saved as `Upgrades`,
  UI `src/client/Upgrades.lua` on the lobby dock). Turbo Fart (300): a sprinting fart also gives
  `FartBoost` (+8 speed, 2.5s) and a gas trail that fades after 2s (`Fart.Trail`).
- Sentinel suit skins: palettes in `Costumes.SentinelSkins`, shop data in `Skins.Sentinels`
  (Armory SENTINEL tab, `PlayerData.BuySentinel`/`EquipSentinel`, saved `OwnedSentinels`/
  `SentinelSkin`). Verity (3000): black/yellow suit with the grin (`Costumes.Smiley`) on its face;
  Verity claws (3000) are black with a yellow edge and a grin badge on each forearm.
- Survivors see a white glow on the 6 nearest hiding spots (`src/client/HideGlow.lua`); keep the
  client's Highlight count low (Roblox caps it at 31), which is why Sniff ghosts also draw boxes.
- Sentinel pilot exit: destroyed by Wolverine → Hits = 2 (one from death); timed out → full health.
- Currency is shown as "Berserker Coins" (`Config.CoinName`); saves still use the key `Coins`.
- Lighting (`MapBuilder.SetupLighting`): gentle grade (contrast 0.15, saturation 0.08), bloom
  0.55/40/1.35 (client arena zone matches), low blue-grey ambient so lamps shape the rooms.
  Foundry: cool work floods, forged-steel crucibles (one pouring into a mould).
- Sky: `Config.SkyAssetId` loads via InsertService at server start unless a Sky is placed in
  Lighting in Studio.

## Monetization (IDs in `src/shared/Config.lua`)

The user is re-creating these on a new experience; the IDs need replacing once made.

| Item | Price | Config |
| --- | --- | --- |
| 2x Wolverine Chance (Game Pass) | R$250 | `DoubleChanceGamepassId` |
| Become Wolverine | R$80 | `GuaranteedWolverineProductId` |
| Handful of Berserker Coins (500) | R$49 | `CoinPacks[1].ProductId` |
| Pouch of Berserker Coins (1,200) | R$99 | `CoinPacks[2].ProductId` |
| Crate of Berserker Coins (3,000) | R$199 | `CoinPacks[3].ProductId` |
| Weapon X Vault (7,000) | R$399 | `CoinPacks[4].ProductId` |
