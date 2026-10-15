# Space Game Design Doc (Draft 1)

> Copy of the Claude Doc https://claude.ai/code/artifact/5a28ab86-d7f7-4ca4-aa32-20b624b7390a for other threads to read. The Doc is the live version; diagrams appear only there.

Oct 15, 2026 · @MAtthew

## Overview

**Outer Reach** (working title) is an open-world multiplayer space game on Roblox where players fly modular ships between planets, mine and sell resources, and fight other players for cargo and territory. Danger and reward rise together the farther a player flies from the safe trade hubs.

**Design pillars**

1. **Your ship is yours.** Every ship is built from modules the player chose and placed, so a ship's look tells others what it does.
2. **Risk equals reward.** The best ore sits in deep space, where other players can take it from you.
3. **Always something to do in five minutes.** A short run (mine, sell, upgrade) pays off in one Roblox session, including on mobile.
4. **Crews beat loners, but loners can play.** Group play is stronger, while solo players have safe, slower income.

**Audience:** Roblox players roughly 10 to 18 who like grind-and-upgrade games and PvP, on PC, mobile and console. Controls are designed for touch first, then refined for mouse and gamepad. Art is low-poly and stylized: cheap to build alone, quick to load on phones, and readable in a fight.

**Design decisions so far.** MAtthew confirmed these on Oct 15; each is explained in its section below.

| Decision | Chosen | Status |
| --- | --- | --- |
| PvP rules | Safe zones only around trade hubs; PvP everywhere else | Confirmed |
| Losing a fight | When a ship is fully destroyed outside safe zones, it drops its cargo and a share of its fitted modules, and the attacker earns a kill reward | Confirmed |
| Flight and combat | Full six-axis flight, target lock and tracking, guns fire automatically | Confirmed |
| Art style | Low-poly stylized | Confirmed |
| Team and pace | Solo developer, long playtest phases before launch | Confirmed |
| Title | Working title Outer Reach; shortlist below | Open |
| Planets | Land at a pad, then a separate surface map | Default, not yet confirmed |
| Server size | About 30 to 50 players per star system server | Default, not yet confirmed |
| Money | Cosmetics and convenience only, no paid power | Default, not yet confirmed |

**Closest competitor:** [Starscape](https://roblox.com/games/679715583) already offers open-universe mining, trading and PvP on Roblox with secure and wild systems and a cosmetics-only shop. Outer Reach stands apart through planets you land on and walk, and a deeper snap-to-grid ship builder. The full comparison is in the research thread's comparable games notes.

**Title shortlist.** My pick is **Hullbreakers**: it says modular ships and PvP in one word, and it matches losing modules when you're beaten. None of these has been checked against existing Roblox games yet, so search Roblox before committing.

| Title | Why it fits | Watch out |
| --- | --- | --- |
| Hullbreakers | Ships get broken apart and looted | Sounds combat-only, less about mining |
| Outer Reach | Exploration and pushing outward | Generic; similar names likely exist |
| Void Haulers | Mining and hauling under threat | Undersells PvP |
| Starwake | Short, memorable, sci-fi feel | Says little about the gameplay |
| Deep Haul | Risky cargo runs into deep space | Could read as a fishing game |
| Salvage Run | Looting wrecks and fleeing with cargo | Feels smaller than an open world |

## Core gameplay loop

The loop is fly out, gather, sell, upgrade, then fly farther. Every pass makes the ship stronger and pulls the player into riskier space, where PvP happens.

&#91;embedded content: core loop · 6 steps, one loop back\]

The haul home is where PvP happens: a full hold is worth stealing, and the loop back sends players into riskier space each time.

1. **Launch** from a home station at a safe trade hub.
2. **Travel** to an asteroid field or planet, choosing how far into danger to go.
3. **Gather** ore by mining asteroids from the ship or landing and drilling on foot.
4. **Haul back** with a full hold, the moment other players can intercept you.
5. **Sell** at a station market, where prices differ by station and demand.
6. **Upgrade** by buying or crafting modules and refitting the ship.
7. **Go farther** to tougher zones with richer ore, or hunt haulers for their cargo.

**Three ways to play the same loop**

| Role | How they earn | Where they spend time |
| --- | --- | --- |
| Miner / hauler | Selling ore and refined goods | Asteroid fields, planets, trade routes |
| Pirate / hunter | Kill rewards, salvage from destroyed ships, bounties | Open space and deep systems |
| Escort / crew | Shared payouts from a crew run | Wherever their crew flies |

**A typical 20 minute session:** spawn at a station, run two or three mining trips in open space, sell, fit one new module, and join a crew fight if one breaks out nearby.

## World structure

The galaxy is a set of star systems linked by jump gates. Each system has one or two trade hubs wrapped in a safe zone, and everywhere else is open PvP. A star system is one Roblox server; jumping through a gate moves the player to another server in the same game.

| Area | PvP | What's there | Loss on death |
| --- | --- | --- | --- |
| Trade hub safe zone | Off; weapons can't fire inside, hub turrets shoot anyone who tries | Market, shipyard, refinery, respawn point | None |
| Open space (starter systems) | On | Tier 1 and 2 ore, most planets, trade routes between hubs | Cargo and a share of fitted modules |
| Open space (deep systems) | On | Tier 3 and 4 ore, derelicts, player outposts later; few or no hubs | Cargo and a share of fitted modules |

The penalty is the same everywhere outside a hub; what changes with distance is the reward and how far you are from safety.

**Inside a star system:** a central star, 2 to 5 planets, 1 to 3 asteroid belts, 1 or 2 stations and the jump gates. Ships fly freely in space with a boost drive for crossing the system quickly.

**Planets:** a ship lands at a landing pad or open site, which teleports the crew to a smaller surface map with ore deposits, hazards (heat, storms, creatures later) and sometimes an outpost. Taking off returns them to orbit above that planet.

**Launch map (suggested):** 3 starter systems with two hubs each, 4 middle systems with one hub each, and 2 deep systems with no hub at all. More systems are added as player count grows.

Why hub safe zones: new and younger players need somewhere to sell, refit and respawn without being camped, but the rest of space stays dangerous. Hubs in starter systems sit close to each other, so a beginner's trade route is short; deep systems have none, so a full hold there is a real gamble.

## Mining and resources

Players mine in two ways: a mining laser on the ship for asteroids, and a handheld drill on planet surfaces. Both fill the ship's cargo hold, which is the thing pirates want.

**Ship mining (asteroids):** lock on to an asteroid and hold the laser on it; the asteroid shrinks and drops ore chunks that a tractor module pulls in. Better lasers mine faster and can crack harder rock.

**On-foot mining (planets):** land, walk to glowing deposits and drill them, carrying ore back to the ship in a backpack with limited space. This gives planets a reason to exist and lets crewmates help each other.

**Resource tiers**

| Tier | Example ores | Found in | Needs |
| --- | --- | --- | --- |
| 1 | Iron, Copper, Ice | Starter systems | Starter laser |
| 2 | Titanium, Cobalt, Silicon | Starter and middle systems | Mk II laser or drill |
| 3 | Iridium, Plasma crystal | Middle-system planets with hazards | Mk III laser, hazard suit |
| 4 | Voidstone, Dark matter | Deep systems only | Mk IV laser, heavy hold |

**Refining:** raw ore sells for little. A refinery module (or station refinery for a fee) turns ore into ingots and components worth more and needed for crafting modules.

**Respawning:** asteroids and deposits regrow on a timer per server, so busy servers compete for the same rocks. That competition is a deliberate source of PvP.

**Make mining skillful:** a heat bar that overheats the laser if held too long, and weak spots on big asteroids that crack them faster. Players of Elite Dangerous and other games call hold-a-button mining the dullest grind.

## Economy

One currency, Credits, is earned mainly by selling at NPC station markets, whose prices move with what players sell, and also from kill rewards for destroying ships. Player-to-player trading comes after launch.

**Selling:** each station buys every ore but pays more for what its system lacks. Prices drop as players flood a station with one ore and recover over time, so haulers who check prices and travel earn more than those who sell at home.

**Price sharing:** station prices are shared across all servers of the game, so a station in system A shows the same price no matter which server you are in.

**Where Credits go (money sinks)**

- Buying modules, blueprints and ship hulls
- Repair bills and insurance after a loss
- Refining and docking fees at stations
- Jump gate tolls into deep systems
- Crafting costs on top of materials

Sinks matter because without them Credits pile up and prices lose meaning within weeks. Insurance is the main one: a player pays a fee to get a destroyed ship back at a percentage of its value.

**Later:** a player auction house at hub stations, crew-owned outposts that charge their own fees, and contracts ("deliver 200 titanium to station X") posted by players or NPCs.

## Modular ship design

A ship is a hull with a grid of slots; players snap modules onto the grid in a shipyard editor, and the modules decide everything the ship can do. Stats come only from what is fitted, so two ships of the same hull can play very differently.

**Hulls** set the grid size, the power budget, base armor and handling.

| Hull class | Grid | Role | Unlocked |
| --- | --- | --- | --- |
| Scout | Small | Fast explorer, light miner | Start |
| Hauler | Medium, cargo-heavy | Mining and trade | Early |
| Fighter | Small, weapon-heavy | PvP and escort; fits in a carrier | Early |
| Frigate | Large | Crew ship with turrets for 2 to 4 players | Mid |
| Industrial | Large, cargo-heavy | Bulk mining with a crew | Mid |

A sixth hull, the **Carrier** (capital class, unlocked late), holds up to 4 Scouts or Fighters in hangar bays. Hit points, slots, hyperdrive ranges and carrier rules for every hull are in [ship-types.md](ship-types.md).

**Module types**

- **Core:** reactor (power), cockpit, engines, boost drive, hyperdrive
- **Utility:** cargo hold, mining laser, tractor beam, refinery, scanner, warp disruptor (Fighter only), cloak
- **Combat:** guns, missiles, turrets crewed by other players, shield generators, armor plates, ammo magazines for Kinetic guns
- **Cosmetic:** paint, decals, lights, engine trails, wings and fins

**Rules that keep builds balanced**

- Every module draws power, and the reactor sets the limit, so a ship can't be full of everything.
- Mass from modules slows acceleration and turning, so heavy haulers are easy targets.
- Modules have tiers (Mk I to Mk IV) bought with Credits or crafted from refined materials.
- Modules must connect to the cockpit through the grid, so a shot-off connector can disable modules beyond it.

**Damage:** modules take damage individually. Losing an engine slows you and makes plasma guns fire slower; losing the shield generator drops your shield; losing a weapon silences it. This makes aiming at parts matter and makes fights readable.

**Saving designs:** players can save several loadouts per hull and swap at any station shipyard.

## Combat and PvP

Combat is full six-axis flight with target lock, and guns fire on their own. The pilot locks a target, then flies to keep it inside the guns' firing arcs; each gun tracks the target within its arc and fires automatically while the target is in range. A fight between two similar ships should last 45 to 60 seconds so both players can react.

**Six-axis flight:** pitch, yaw and roll, plus thrust forward, back, up, down, left and right. **Flight assist** is on by default and damps drift so the ship stops when you let go; turning it off gives Newtonian drift for skilled pilots who want to slide while turning.

**Where the skill is, since aiming is automatic**

- Positioning: keeping the enemy in your arcs while staying out of theirs.
- Range: closing inside 300 studs for plasma, or holding 500 to 1,800 studs for Kinetic guns and railguns.
- Engines: plasma fire rate comes from engine output, so pilots balance engines against guns in the shipyard and protect their engines in a fight.
- Subsystem targeting: locking a specific module, such as engines to stop an escape or the shield generator to drop its shield.
- Evasion: boosting, rolling and breaking lock with countermeasures.

**Controls:** PC uses mouse to steer, WASD plus Q/E for roll and Space/Ctrl for up and down. Mobile uses a left stick for thrust, dragging to steer, and buttons for roll, lock and boost. Gamepad maps the same way. Auto-fire is what makes six-axis combat workable on a phone.

**Weapons**

There are two weapon classes, and a ship can mix both. Exact guns, numbers and the damage rules are in [weapons-and-damage.md](weapons-and-damage.md).

| Class | Against shields | Strength | Cost to run |
| --- | --- | --- | --- |
| Energy (plasma) | Drains them; the only class that does | Full damage, ignores armor, short range (300 to 500 studs) | No ammo; fire rate scales with engine output, and firing never slows the ship |
| Kinetic | Passes straight through | Long range (700 to 1,800 studs), 1.5x damage to modules; reduced by armor plates | Needs ammo from an onboard magazine module; does less damage than Energy |

The signature move is to lock the enemy's shield generator with Kinetic guns, knock it out so the shield collapses, then finish the bare hull with plasma.

**Guns:** Energy has the Pulse Blaster, Plasma Cannon, Beam Turret and Plasma Torpedo. Kinetic has the Autocannon, Railgun, Flak Turret, Hull-Cracker Missile and Point Defense.

Missiles and torpedoes are the only weapons the pilot fires by hand. Point defense shoots them down.

**Losing a fight**

- **Inside a trade hub:** weapons can't fire, so there is no loss.
- **Damaged but not destroyed:** knocked-out modules stop working until repaired, but nothing drops. Cargo and modules only drop when the whole ship is destroyed.
- **Destroyed anywhere else:** the ship drops all its cargo and a random share of its fitted modules (suggested 1 in 4) as salvage the winner can pick up. The player respawns at their last hub; insurance returns the hull and the modules that survived. Lost modules must be bought or crafted again.
- **Kill reward:** the attackers also earn Credits based on the value of the ship they destroyed (suggested 10% of its hull and modules plus 5% of its cargo), split by damage dealt and reduced for repeat kills of the same player, on top of any salvage they collect.
- **Saved loadouts** show which slots are empty after a loss and let the player refit in one click if they can afford it.

**Fair-fight rules**

- New players get a 30 minute protection timer in starter systems, lost if they attack someone.
- A ship leaving a hub gets 20 seconds of protection so hub exits can't be camped.
- Killing a ship far weaker than yours (by a power rating from its modules) puts a Credit bounty on you.
- Leaving the game mid-fight keeps the ship in space for 30 seconds so players can't escape by quitting.

**NPC threats:** pirate drones in open space, tougher in deep systems, give solo players practice and keep empty servers dangerous.

## Progression, social and monetization

Progression is mostly gear: players get stronger by unlocking hulls and module tiers, not by levelling up stats. A pilot rank adds unlocks and status on top.

**Progression tracks**

- **Pilot rank:** XP from every activity unlocks hulls, zones and blueprint slots.
- **Blueprints:** found in derelicts or bought, they let players craft higher-tier modules from refined materials.
- **Reputation:** per station faction; high rep lowers fees and unlocks faction-only cosmetics.
- **Collections:** a log of ores, planets and wrecks discovered, with badges.

**Social**

- **Crews:** parties of up to 6 who share a channel, map markers and a payout split.
- **Crew ships:** frigates and industrials have extra seats and turrets for crewmates.
- **Fleets (later):** larger player organizations that can claim deep-system outposts and tax them.
- **Leaderboards:** richest pilots, top bounty hunters, most ore mined, per week.

**Monetization (suggested)**

| Product | Type | Price idea | Why it's fair |
| --- | --- | --- | --- |
| Paints, decals, engine trails | Developer product / Robux shop | 25 to 150 Robux | Looks only |
| Extra loadout and hangar slots | Game pass | 99 to 199 Robux | Convenience |
| VIP (private server perks, name tag) | Game pass | 249 Robux | Status |
| Season pass with cosmetic rewards | Developer product | 399 Robux | Cosmetic track |
| Private servers | Roblox private servers | Low monthly price | Group play |

No paid weapons, modules or Credits: in a PvP game, paying for power drives away the free players who make up most of the audience. Prices here are placeholders for MAtthew to tune.

## Roblox technical plan

The game is one Roblox experience with several places: a lobby, one place per star system and one per planet surface, linked with TeleportService. The server owns all money, cargo and damage; the client only flies its own ship and draws effects.

&#91;embedded content: server layout · 3 place types, 3 shared services\]

Players move between places by teleport; anything that must survive the move or match across servers lives in the shared services.

**Key systems**

| System | Roblox approach |
| --- | --- |
| Travel between systems and planets | TeleportService between places, carrying the player's ship data with them |
| Ship flight | Six-axis flight runs on the pilot's client, which has network ownership of their ship for smooth controls; the server checks speed and position for cheating |
| Ship building | Modules are models snapped to grid attachment points and welded together on the server from a saved list |
| Saving | DataStoreService with session locking (the community ProfileStore library is the usual pick) storing Credits, cargo, hulls and loadouts as module lists, not models |
| Shared station prices | MemoryStoreService so every server sees the same market |
| Cross-server events | MessagingService for bounties, world events and crew invites |
| Large maps | StreamingEnabled so phones only load what is near them |
| Combat | Because guns fire automatically, the server decides every shot: each volley it checks lock, firing arc, range and line of sight, works out a hit chance from the gun's tracking speed against the target's movement, then applies damage. No per-shot raycasts are needed. Clients only draw the effects, which removes most aim and damage cheats |

**Constraints to design around**

- **Distance:** physics and rendering get jittery far from the map's origin, so each star system should stay compact, and big distances are faked with boost drives and skyboxes rather than built to scale (inferred from common Roblox practice; test early).
- **Server size:** many physics-driven ships per server is expensive, so the plan targets about 30 to 50 players per system server and adds servers rather than packing them.
- **Mobile:** most Roblox players are on phones, so module count per ship and particle effects need budgets, and every control needs a touch version.
- **Exploits:** never trust the client for Credits, cargo, damage or module stats. All purchases and sales are server calls with checks and rate limits.

**Working solo:** keep every stat in data tables so tuning after a playtest is an edit, not a rebuild. Build low-poly modules from a small kit of shared parts and colours. Lean on Roblox built-ins (streaming, text chat, private servers) and well-known community libraries rather than writing them.

**Suggested code layout:** Rojo for working in files with Git, a shared Modules folder for ship and economy data (stats in tables, not baked into models) and one server service per system: Economy, Ships, Combat, Mining, Travel, Data.

**Platform limits checked by the research thread:** DataStore writes are budgeted per server per minute and each key holds about 4 MB, so saves happen at checkpoints (sell, dock, leave), not on every ore pickup ([DataStore limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits.md)). Teleport data is visible to the client, so Credits and cargo must never travel in it, and teleports need retry handling ([teleporting](https://create.roblox.com/docs/en-us/projects/teleport.md)). The current maximum players per server could not be confirmed, so check the slider in Game Settings before fixing the 30 to 50 target.

## MVP scope and roadmap

The first playable version proves one thing: flying out, mining, getting robbed or getting home, and upgrading is fun. Everything else waits until that loop holds players.

| Area | In the MVP | Later |
| --- | --- | --- |
| World | 1 starter system with a hub, 1 deep system with none, 1 landable planet | More systems, gate network, events |
| Ships | 3 hulls (Scout, Hauler, Fighter), about 12 modules, grid editor | Frigates with crew seats, crafting, cloak |
| Mining | Asteroid laser and on-foot drill, tiers 1 to 3 | Tier 4, hazards, refining chains |
| Economy | 1 hub market with shared dynamic prices, insurance | More hubs, auction house, contracts, outposts |
| Combat | Six-axis flight, lock and auto-fire, Pulse Blaster and Autocannon, shield generator and magazines, missiles, point defense, module drop | Railguns, Plasma Cannons, turrets, bounty board |
| Social | Parties and a party chat | Crews with payout split, fleets, leaderboards |
| Money | Paints only | Loadout slots, season pass, VIP |

**Roadmap phases**

1. **Flight and combat prototype:** six-axis flight, target lock and auto-fire against NPC drones. Playtest with friends on phone and PC, and repeat until a fight is fun on its own.
2. **Loop prototype:** mining, selling at one hub, saving. Playtest gate: testers do a second trip without being asked.
3. **Ships and PvP:** grid editor, PvP with cargo and module drop. A small closed group plays over several weeks to tune the drop rate and protection timers.
4. **Closed beta:** the full MVP scope on private servers for a long test period, watching next-day return rates and how fast Credits pile up.
5. **Public launch:** open the MVP once the beta keeps players coming back.
6. **Live updates:** more systems, crews, crafting and crew ships, each added and tested one at a time.

**Open questions for MAtthew**

- [ ] Pick a title from the shortlist in the Overview, or suggest another.
- [ ] Keep one landable planet in the MVP, or go space-only to reach playtests sooner?
- [ ] Is 1 in 4 fitted modules dropped on death the right amount, or should it be higher?
- [ ] Flight assist on by default (easier) or off (more skill)?
- [ ] Is the cosmetics-only money plan OK?

## Sources

- [Starscape on Roblox](https://roblox.com/games/679715583)
- [Roblox docs: DataStore limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits.md)
- [Roblox docs: teleporting](https://create.roblox.com/docs/en-us/projects/teleport.md)
- [Roblox docs: instance streaming](https://create.roblox.com/docs/en-us/workspace/streaming.md)
- [Albion Online zones and flagging](https://www.albionmarket.gg/guides/zones-and-flagging)
- Other figures in this doc are design proposals, not sourced facts.
