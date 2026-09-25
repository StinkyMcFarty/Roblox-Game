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
- Pounce is a scripted dive arc (`Effects.Leap`): Height 7.6, AirTime 0.92, Forward 78 (~72 studs).
- Running does not break walls; M1, pounce, impale and Sentinel punches do. Wall cores carry a
  `Surface` attribute (`Facility.lua`) that picks the clash effect (`Combat.StoneClash` etc).
- Sentinels: linked (within 30 studs of each other) hit at 1.25x, apart 0.6x, a lone suit 1x.
  Pursuit thrusters (`Config.Sentinel.Pursuit`, `Movement.lua`): once Wolverine is 70+ studs
  away a suit gets +14 speed until it's back within 30 studs. Death ray: 32.4 DPS, range 260,
  x1.5 (390) while he's 70+ studs from that suit.
  Inhibitor Blast (`Config.Sentinel.Pulse`): radius 30, shatters his i-frames, and during its
  stun a punch grants i-frames only every 2nd hit (`pulseStun` in `Sentinel.lua`).
- Sentinels see Wolverine's outline through walls while they're 50+ studs from him
  (`src/client/SentinelTracker.lua`). A fart while sprinting skips the sprint build-up
  (`Movement.MaxOut`). Death ray colours live in the `BEAM` table in `SlashFX.lua`.
- Client Highlights/adornments are parented in the workspace, not `CurrentCamera` (suspected cause
  of Sniff ghosts not drawing live; ghosts now go in a local `ScentGhosts` folder).
- Survivors see a white glow on the 6 nearest hiding spots (`src/client/HideGlow.lua`); keep the
  client's Highlight count low (Roblox caps it at 31), which is why Sniff ghosts also draw boxes.
- Sentinel pilot exit: destroyed by Wolverine → Hits = 2 (one from death); timed out → full health.
- Currency is shown as "Berserker Coins" (`Config.CoinName`); saves still use the key `Coins`.
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
