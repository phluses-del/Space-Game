# Space Game

Design and research for an open-world, large-multiplayer PvP space game on Roblox. Players fly to planets, mine and sell resources, fight other players' ships, and customize their own ships with modular parts.

The project is in the design phase, with a first flight and combat prototype in `src/`.

## Running the prototype

The code lives in this repo as Luau files and syncs into Roblox Studio with [Rojo](https://rojo.space). Rojo's version is pinned in `rokit.toml`.

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then reopen your terminal.
2. In this folder, run `rokit install` to get Rojo, then `rojo plugin install` to add the Rojo plugin to Studio.
3. Run `rojo serve`.
4. In Studio, open a new Baseplate, click **Rojo** in the Plugins tab, then **Connect**.
5. Press **Play**. The server removes the baseplate, builds the test system and puts you in a Fighter.

**Controls on PC:** the mouse steers (move it away from the centre to pitch and yaw), W/S thrust, A/D strafe, Space/Ctrl up and down, Q/E roll, Shift boost, T lock the target ahead, Tab next target, G pick a subsystem to aim at, X drop the lock, R fire a missile, F toggle flight assist. In Studio, keys 1 to 6 swap you into the Scout, Fighter, Hauler, Frigate, Industrial or Carrier (a stand-in until the hangar menu lands). Gamepad and touch controls are mapped too (see `src/client/Input.lua`).

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

## Contents

| File | What it covers |
| --- | --- |
| [design/game-design-doc.md](design/game-design-doc.md) | Overall game design (Draft 1) |
| [design/ship-types.md](design/ship-types.md) | Ship classes: health, roles, slots, hyperdrive, carriers, shields |
| [design/weapons-and-damage.md](design/weapons-and-damage.md) | Weapon classes and how damage flows through shields, armor, hull and modules |
| [research/comparable-space-games.md](research/comparable-space-games.md) | Research on comparable space games and what to borrow |

All numbers in the design docs are playtest starting points.
