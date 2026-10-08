# Race the Sun (Roblox) — flight prototype

A solar glider that skims forward over an endless plain, steering left and
right to dodge blocks. This first build is all about how flying feels; the
engine overheat mechanic keeps you racing for shade and rain (see "Test it").

## Put the scripts into Roblox Studio

Open a new **Baseplate** place, then create these objects in the Explorer and
paste each file's contents into it. The object name must match exactly.

| Explorer location | Object type | Name | File |
|---|---|---|---|
| ReplicatedStorage | **Folder** | `RaceTheSun` | — |
| ReplicatedStorage › RaceTheSun | ModuleScript | `FlightConfig` | `src/ReplicatedStorage/RaceTheSun/FlightConfig.luau` |
| ReplicatedStorage › RaceTheSun | ModuleScript | `ShipBuilder` | `src/ReplicatedStorage/RaceTheSun/ShipBuilder.luau` |
| ReplicatedStorage › RaceTheSun | ModuleScript | `Glider` | `src/ReplicatedStorage/RaceTheSun/Glider.luau` |
| ReplicatedStorage › RaceTheSun | ModuleScript | `FlightInput` | `src/ReplicatedStorage/RaceTheSun/FlightInput.luau` |
| ReplicatedStorage › RaceTheSun | ModuleScript | `FollowCamera` | `src/ReplicatedStorage/RaceTheSun/FollowCamera.luau` |
| ReplicatedStorage › RaceTheSun | ModuleScript | `TestTrack` | `src/ReplicatedStorage/RaceTheSun/TestTrack.luau` |
| ReplicatedStorage › RaceTheSun | ModuleScript | `Heat` | `src/ReplicatedStorage/RaceTheSun/Heat.luau` |
| ReplicatedStorage › RaceTheSun | ModuleScript | `HeatHud` | `src/ReplicatedStorage/RaceTheSun/HeatHud.luau` |
| ReplicatedStorage › RaceTheSun | ModuleScript | `Orbs` | `src/ReplicatedStorage/RaceTheSun/Orbs.luau` |
| ReplicatedStorage › RaceTheSun | ModuleScript | `OrbHud` | `src/ReplicatedStorage/RaceTheSun/OrbHud.luau` |
| ReplicatedStorage › RaceTheSun | ModuleScript | `Sun` | `src/ReplicatedStorage/RaceTheSun/Sun.luau` |
| ReplicatedStorage › RaceTheSun | ModuleScript | `MainMenu` | `src/ReplicatedStorage/RaceTheSun/MainMenu.luau` |
| ReplicatedStorage › RaceTheSun | ModuleScript | `MenuCamera` | `src/ReplicatedStorage/RaceTheSun/MenuCamera.luau` |
| StarterPlayer › StarterPlayerScripts | **LocalScript** | `FlightClient` | `src/StarterPlayer/StarterPlayerScripts/FlightClient.client.luau` |
| ServerScriptService | **Script** | `GameSetup` | `src/ServerScriptService/GameSetup.server.luau` |
| ServerScriptService | **Script** | `CurrencyService` | `src/ServerScriptService/CurrencyService.server.luau` |

Tip: to add one, hover the parent in Explorer, click **+**, pick the type,
then rename it (F2).

If you use Rojo, `default.project.json` maps the `src` folder the same way.

## Test it

1. Press **Play** (F5). The **main menu** opens: the camera cuts between
   slow cinematic shots of the plane. Customize and Options show a
   "coming soon" panel for now.
2. Click **Fly**. The menu slides away and the camera swoops in behind the
   plane, then a 3-2-1 countdown runs and the glider launches forward.
3. Jump with **Space**, **W**, **↑**, gamepad **A** or the on-screen
   **JUMP** button on touch devices. The run speeds up the further you fly.
4. Steer:
   - **Keyboard:** A / D or ← / →
   - **Gamepad:** left stick or D-pad
   - **Phone/tablet:** hold the left or right half of the screen
     (in Studio, use the Device Emulator in the Test tab to try this)
5. Watch the **engine heat** meter at the bottom. It fills while you fly in
   open sun. Fly **under arches** (shade) or **through rain clouds** to cool
   down. Past 70% you get an OVERHEATING warning, past 90% a flashing CRITICAL
   alarm, and at 100% the engine explodes. The **sun** ahead reacts too: it
   swells and turns red as heat rises, the glare grows, and it throbs at
   critical heat.
6. Fly through **orbs** to collect currency: cyan orbs are worth 1, rare gold
   orbs are worth 10 (some float at jump height). The layout is new every run.
   The top-right shows orbs this run and your saved total.
7. Hit a block and you crash. Press **R**, **Space**, **Enter**, gamepad
   **A**, or tap to fly again.

The number at the top is distance travelled in studs.

### Saving orbs

The orb total is kept on the server and saved with DataStores. To make it
save while testing in Studio, the place must be published (File › Publish to
Roblox) and **Game Settings › Security › Enable Studio Access to API Services**
must be on. Otherwise the total only lasts for the session (you'll see one
warning in Output).

## Tuning the feel

Everything is in **FlightConfig**. The ones worth playing with first:

- `ForwardSpeed` — how fast you fly at the start (160)
- `SpeedGainPer1000Studs` / `MaxSpeedRamp` — how quickly the run speeds up (5% per 1000, max 1.8×)
- `MaxStrafeSpeed` — how fast you slide sideways (120)
- `SteerResponsiveness` — lower feels floatier, higher feels twitchier (6.5)
- `SteerReleaseResponsiveness` — how fast you straighten out when you let go (9.5)
- `JumpVelocity` / `Gravity` — jump height and how floaty the air time is (75 / 180)
- `MaxBankAngle` — how hard the glider leans into turns (40°)
- `HoverHeight` — how low you skim (6)
- `Camera.Distance` / `Camera.Height` — chase camera position
- `Track.ObstaclesPerChunk` — how crowded the test track is (22)
- `Track.ArchesPerChunk` / `Track.RainCloudChance` — how often cooling spots appear
- `Heat.HeatPerSecond` — how fast the engine heats in open sun (5, so ~20s to explode)
- `Heat.ShadeCoolPerSecond` / `Heat.RainCoolPerSecond` — cooling strength (35 / 50)
- `Heat.WarningFraction` / `Heat.CriticalFraction` — when the warnings start (0.7 / 0.9)
- `Sun.Size` / `Sun.Elevation` — how big and how high the sun sits (380 / 14°)
- `Sun.CoolColor` / `Sun.HotColor` / `Sun.HotGrowth` — how the sun changes with heat
- `Menu.Shots` — the menu camera shots (where each starts, ends, looks and how long it lasts)
- `Menu.FlyTransitionTime` — how long the swoop from the menu into the game takes (2.4s)
- `Menu.Title` — the game name on the menu (placeholder)
- `Orbs.Kinds` — value, colour and size of regular and special orbs (1 / 10)
- `Orbs.SpecialChance` — how rare special orbs are (0.04, about 1 in 25)
- `Orbs.GroupSpacing` / `Orbs.OrbsPerGroup` — how often orb groups appear and how big they are

Edit while stopped, then press Play again.

## How it fits together

- **GameSetup** turns off avatar spawning; the player *is* the glider.
- **FlightClient** runs the loop on the player's device: countdown → fly →
  crash → restart, plus the HUD.
- **Glider** is the flight model: constant forward speed along −Z, smoothed
  sideways slide, banking, terrain-following hover, and a swept-box
  collision check every frame. Anything steeper than `CrashSlope` is a wall.
- **FlightInput** merges keyboard, gamepad and touch into one steer value.
- **FollowCamera** is the chase camera.
- **ShipBuilder** makes the glider out of plain parts (swap for a mesh later).
- **TestTrack** is a placeholder endless plain with random blocks, shaded
  arches and rain clouds, built in 512-stud chunks around the glider and
  seeded so the layout repeats.
- **Heat** is the overheat mechanic: heats in sun, cools in shade or rain,
  and ends the run with `glider:End("Overheat")` at max.
- **HeatHud** draws the heat meter and the overheating/critical warnings.
- **Sun** is a giant glowing ball with halos that stays fixed in the sky ahead
  (it moves with the camera) and reacts to heat. It lines up Roblox's real
  sun with it so shadows and sun rays match, and adds glare, sun rays and a
  warm tint to Lighting.
- **MainMenu** draws the menu (black bars, title, Fly / Customize / Options)
  and **MenuCamera** plays the looping shots and the swoop into the chase view.
- **Orbs** places glowing orb groups ahead of the glider (a new random layout
  every run) and collects them as you fly through.
- **OrbHud** shows orbs this run, the saved total and the "+10" popups.
- **CurrencyService** (server) adds up collected orbs, checks them, and saves
  the total with DataStores.

Flying runs on the client because Race the Sun is single-player; this
keeps steering lag-free and avoids StreamingEnabled hiding far-off blocks.
Only the orb total goes through the server, so it can be saved and trusted
for purchases later.

## Hooks for the next features

- **More cooling sources:** give any part the attribute `Cooling = "Rain"`
  and put it in `track.CoolingZones`, or put anything solid overhead for shade.
  Read `glider.Distance` for score.
- **Speed boosts / faster regions:** set `glider.SpeedMultiplier` (the camera
  widens its FOV automatically).
- **Procedural obstacles:** replace `TestTrack` with a module that has the
  same `new(settings)`, `Update(position)` and `Destroy()` functions.
- **Shop / cosmetics:** read the player's `OrbTotal` attribute; do any
  spending inside `CurrencyService` on the server.
- **Orb visuals:** swap the ball in `Orbs:_spawnOrb`; the pop effect is in
  `Orbs:_collect`.
- **Customize / Options screens:** replace `MainMenu:_openPanel`; the
  buttons are made in `MainMenu.new`. `menu:Show()` brings the menu back.
- **Per-frame logic** (pickups, sun drain): connect to `glider.Stepped`.
