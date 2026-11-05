# Space Game

Design and research for an open-world, large-multiplayer PvP space game on Roblox. Players fly to planets, mine and sell resources, fight other players' ships, and customize their own ships with modular parts.

The project is in the design phase, with a first flight and combat prototype in `src/`.

## Running the prototype

The code lives in this repo as Luau files and syncs into Roblox Studio with [Rojo](https://rojo.space). Rojo's version is pinned in `rokit.toml`.

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then reopen your terminal.
2. In this folder, run `rokit install` to get Rojo, then `rojo plugin install` to add the Rojo plugin to Studio.
3. Run `rojo serve`.
4. In Studio, open a new Baseplate, click **Rojo** in the Plugins tab, then **Connect**.
5. Press **Play**. The server removes the baseplate and builds the test system, and you land on the main menu. **Play** opens the Hangar, where you pick a ship and **Launch**.

To keep settings between Studio sessions, turn on **Game Settings > Security > Enable Studio Access to API Services**; without it settings still work but reset each session.

**Controls on PC:** the mouse steers (move it away from the centre to pitch and yaw), W/S thrust, A/D strafe, Space/Ctrl up and down, Q/E roll, Shift boost, T lock the target ahead, Tab next target, G pick a subsystem to aim at, X drop the lock, R fire a missile, F toggle flight assist, P or M open the pause menu (Esc is Roblox's own menu). In Studio, keys 1 to 6 also swap you straight into the Scout, Fighter, Hauler, Frigate, Industrial or Carrier while flying. Gamepad and touch controls are mapped too (see `src/client/Input.lua`).

**What's in the test system:** an asteroid field, a grey target dummy straight ahead of the spawn, a grey Frigate hulk off to the left for trying big guns, two red pirate drones with Pulse Blasters and an orange armored drone with an Autocannon. Once a lock completes, each gun fires on its own while the target is inside its arc and range. Turrets also fire on their own at the nearest ship that is locking onto you.

**Ship classes:** all six hulls from `design/ship-types.md` are in, each with its own model and stock loadout:

| Hull | Hull HP | Shield | Stock weapons |
| --- | --- | --- | --- |
| Scout | 700 | 400 | Pulse Blaster, Autocannon |
| Fighter | 1,400 | 800 | 2 Pulse Blasters, 2 Autocannons, Plasma Torpedo rack |
| Hauler | 2,600 | 1,200 | Point-defense turret |
| Frigate | 6,000 | 3,000 | Plasma Cannon, Railgun, 2 Flak turrets, Beam turret, point-defense turret |
| Industrial | 7,500 | 2,500 | Flak turret, point-defense turret |
| Carrier | 20,000 | 8,000 | 2 Flak turrets, 4 point-defense turrets |

Missiles are fired with R once the lock completes; point-defense turrets shoot down missiles aimed at their ship. Hyperdrives, carrier docking, cargo, mining and crew seats are described in each class's data but not playable yet.

**Tuning:** hull stats and stock loadouts are in `src/shared/ShipClasses.lua`; every other balance number is in `src/shared/Config.lua`.

**Ship customization (Shipyard):** in the Hangar, **Customize** opens the Shipyard. Pick a hull on the left (unowned hulls open as a preview with a Buy button), then fit it across four tabs: **Weapons** (each slot takes a gun and a Fixed or Gimbal mount, or a turret, in Mk I to Mk IV), **Systems** (shield generator, the engine on each mount and its thrust from 60 to 120%), **Modules** (armor plates and ammo magazines in the hull's module cells) and **Paint** (hull paint, trim, engine glow, engine trail and finish). The right panel shows reactor load, damage per second, plasma fire rate, shield, hull, armor and handling as you change things, plus anything stopping the ship from flying (reactor overloaded, Kinetic guns without magazines, no engines). Each hull holds 3 saved loadouts; the starred one is what that hull launches with. **Buy missing parts** buys everything the loadout needs that you don't own in one go, and **Launch** saves, sets it active and flies. New pilots start with 25,000 Credits and the Scout and Fighter with their stock fits.

Profiles (Credits, hulls, parts, paint and loadouts) save to a DataStore with session locking, so the same API-access setting above is needed for them to persist in Studio. Without it you still get a working profile that resets each session, and the Shipyard says so. Set `Outfitting.Settings.freeMode = true` in `src/shared/Outfitting.lua` to make everything free for a playtest. Prices, reactor budgets, module cells, shield sizes, engine types and paints are all in that file.

## Code layout

| Path | What it does |
| --- | --- |
| `src/shared/ShipClasses.lua` | One entry per ship class: stats, role, what it can fit, stock loadout |
| `src/shared/Config.lua` | Other balance numbers: weapons, slots, shields, engines, armor, modules, drone loadouts, test system |
| `src/shared/Remotes.lua` | The RemoteEvents between client and server |
| `src/server/Ships.lua` | Spawning ships, shields, hull, modules and where each hit's damage goes |
| `src/server/Combat.lua` | Target lock and auto-fire: arcs, range, line of sight, hit chance from tracking, turret targeting |
| `src/server/Missiles.lua` | Missile racks, homing missiles and point defense |
| `src/server/Drones.lua` | NPC drone behaviour |
| `src/server/ShipBuilder.lua` | Builds low-poly ship models from parts, and each hull's weapon mounts |
| `src/server/DevShipSwitch.lua`, `src/client/DevShipPicker.lua` | Studio-only 1 to 6 ship swap, to delete once the hangar menu lands |
| `src/server/TestSystem.lua` | Builds the asteroid field, spawn ring, planet and sun |
| `src/client/Flight.lua` | Six-axis flight with flight assist on or off |
| `src/client/Input.lua` | Keyboard and mouse, gamepad and touch controls |
| `src/client/Hud.lua`, `Effects.lua`, `ChaseCamera.lua`, `Targeting.lua` | HUD, tracers and shield effects, camera, choosing what to lock |
| `src/client/Menus/` | Main menu, Hangar (ship select), pause, settings, controls and destroyed screens; `init.lua` runs the flow and `Theme.lua` holds the look |
| `src/client/ClientSettings.lua` | Applies the player's settings (sensitivity, FOV, HUD size, volume) and saves changes |
| `src/shared/ShipCatalog.lua` | The ships listed in the Hangar; a hull appears as launchable once Config has its hull and `Player<Hull>` loadout |
| `src/shared/Settings.lua` | The settings list, defaults and validation |
| `src/server/PlayerSettings.lua`, `ShipPreviews.lua` | Saves settings in a DataStore; builds the Hangar's 3D ship previews |
| `src/shared/Outfitting.lua` | Ship customization rules and data: each hull's slots, reactor and module cells, shields, engines, modules, paints, prices, and turning a saved loadout into stats and a spawnable ship |
| `src/server/PlayerData.lua` | Saves each player's profile (Credits, hulls, parts, paint, loadouts) in a session-locked DataStore |
| `src/server/Shipyard.lua` | Server side of the Shipyard: saving loadouts, buying, refitting, launching; every request re-checked |
| `src/client/Shipyard.lua` | The Shipyard screen, opened from the Hangar's Customize button |

## Contents

| File | What it covers |
| --- | --- |
| [design/game-design-doc.md](design/game-design-doc.md) | Overall game design (Draft 1) |
| [design/ship-types.md](design/ship-types.md) | Ship classes: health, roles, slots, hyperdrive, carriers, shields |
| [design/weapons-and-damage.md](design/weapons-and-damage.md) | Weapon classes and how damage flows through shields, armor, hull and modules |
| [research/comparable-space-games.md](research/comparable-space-games.md) | Research on comparable space games and what to borrow |

All numbers in the design docs are playtest starting points.
