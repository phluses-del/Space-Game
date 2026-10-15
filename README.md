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

**Controls on PC:** the mouse steers (move it away from the centre to pitch and yaw), W/S thrust, A/D strafe, Space/Ctrl up and down, Q/E roll, Shift boost, T lock the target ahead, Tab next target, G pick a subsystem to aim at, X drop the lock, F toggle flight assist. Gamepad and touch controls are mapped too (see `src/client/Input.lua`).

**What's in the test system:** an asteroid field, a grey target dummy straight ahead of the spawn, two red pirate drones with Pulse Blasters and an orange armored drone with an Autocannon. Your Fighter has two Pulse Blasters (Energy) and two Autocannons (Kinetic) on gimbal mounts. Once a lock completes, each gun fires on its own while the target is inside its arc and range.

**Tuning:** every balance number is in `src/shared/Config.lua`.

## Code layout

| Path | What it does |
| --- | --- |
| `src/shared/Config.lua` | All balance numbers: hulls, weapons, slots, shields, armor, modules, loadouts, test system |
| `src/shared/Remotes.lua` | The RemoteEvents between client and server |
| `src/server/Ships.lua` | Spawning ships, shields, hull, modules and where each hit's damage goes |
| `src/server/Combat.lua` | Target lock and auto-fire: arcs, range, line of sight, hit chance from tracking |
| `src/server/Drones.lua` | NPC drone behaviour |
| `src/server/ShipBuilder.lua` | Builds low-poly ship models from parts |
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
