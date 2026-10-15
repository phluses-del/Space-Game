# Ship Types (Draft 1)

Oct 15, 2026 · for MAtthew · builds on [game-design-doc.md](game-design-doc.md) and [comparable-space-games.md](../research/comparable-space-games.md)

This file answers: how much health each ship has, what each is good at, how many weapons and engines it fits, whether it has a hyperdrive, whether it fits in a carrier, and whether it has shields. All numbers are starting points for playtests, kept in one stats table in code so they can be tuned without touching models.

It follows the decisions in the revised design doc: full six-axis flight with target lock and guns that fire automatically within their arcs, PvP everywhere except trade hub safe zones, cargo plus about 1 in 4 fitted modules dropped only when a ship is fully destroyed, with a Credit reward to the attacker and insurance returning the hull, low poly art, and a solo developer with long playtests.

## The answers at a glance

| Hull | Size | Hull HP | Shield (typical fit) | Weapon slots | Engines | Hyperdrive | Fits in a carrier | Seats | Unlocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Scout | Small | 700 | 400 | 2 small | 2 | Yes, long range, fast spool | Yes | 1 | Start |
| Fighter | Small | 1,400 | 800 | 4 small + 1 missile rack | 2 | No | Yes | 1 | Early |
| Hauler | Medium | 2,600 | 1,200 | 1 turret (point defense in the MVP) | 3 | Yes, short range | No | 2 | Early |
| Frigate | Large | 6,000 | 3,000 | 2 medium fixed + 4 turrets | 4 | Yes, short range | No | 4 | Mid |
| Industrial | Large | 7,500 | 2,500 | 2 turrets | 4 | Yes, short range | No | 3 | Mid |
| Carrier | Capital | 20,000 | 8,000 | 6 turrets (4 point defense) | 6 | Yes, carries docked ships | Is one (4 bays) | 6 | Late |

**Yes, every ship has shields.** Each hull has at least one shield slot, and the shield is a module, so a player can fit a bigger one or skip it for more cargo.

## How health works

Every ship has three layers, which keeps fights readable and gives weapons different jobs.

1. **Shields** come from the shield generator module and absorb Energy (plasma) damage only. They recharge after 4 seconds without taking Energy damage. Kinetic hits pass through to the hull. If the shield generator is knocked out, the shield collapses and can't recharge until it is repaired.
2. **Hull HP** is the ship's structure. It does not recharge in flight; it is repaired at a station, by a repair module, or while docked in a carrier. Armor plates add to it and reduce Kinetic damage. The ship is destroyed at 0 hull HP.
3. **Modules** each have their own small health pool. Every hit that reaches the hull also damages a module (an engine, a gun, the shield generator, the cargo hold), and a module at 0 is knocked out until repaired. Kinetic guns do extra module damage. A destroyed cockpit also destroys the ship.

The full damage rules are in [weapons-and-damage.md](weapons-and-damage.md).

**Armor plates** are modules that each add hull HP (about 200 on small hulls, 300 on medium, 400 on large) and 12.5% Kinetic damage reduction (capped at 50%) but add mass, so an armored ship turns and accelerates slower.

**Target fight length:** two similar ships of the same hull should take about 45 to 60 seconds to finish each other off, which leaves time to react, call for help or escape. The numbers above are set from a Mk I small gun doing about 20 damage per second, with roughly 60 percent of shots landing in a dogfight.

## What each ship is for

**Scout (Small).** The starter ship and the explorer. It is the fastest and most agile hull, has the fastest-spooling, longest-range hyperdrive, and gets a bonus to scanning and target lock. It is weak in a straight fight, carries little cargo, and wins by escaping. It is the only small hull with a hyperdrive, which makes it the ship for finding derelicts and rare ore in deep systems.

**Fighter (Small).** The dogfighter and escort. It has the most guns for its size, a missile rack and the best turning, and it is the only small hull that can fit a **warp disruptor**, which stops a target's hyperdrive from spooling. It has no hyperdrive and almost no cargo, so it travels by jump gate or rides in a carrier. It beats Scouts and Haulers and loses to Frigates when alone.

**Hauler (Medium).** The miner and trader. It has big cargo and mining slots, one automatic defensive turret, and a short-range hyperdrive as its escape tool, which the research flagged as essential for miners. It is slow and an easy target. A second seat lets a friend run the turret and countermeasures.

**Frigate (Large).** The crew warship. Its turrets track small ships well, so it beats lone Fighters; a group of Fighters with torpedoes beats it. Turrets fire on their own at the nearest threat when no crewmate is in the seat, so it is playable solo but much stronger with a crew of 2 to 4.

**Industrial (Large).** The bulk miner. It has the biggest hold in the game, several mining laser slots, and the only refinery slot on a ship, so it can refine ore in the field. It has light defenses and needs an escort, which makes it the prize target pirates hunt.

**Carrier (Capital).** The fleet ship for crews. It holds up to 4 small ships (Scouts or Fighters) in hangar bays, repairs and recharges them while docked, and takes them along when it hyperdrives. It is slow, has a large hit area, and needs a crew to be dangerous; its own guns are mostly point defense against missiles and small ships.

**Counters, kept simple (rock-paper-scissors):** Fighter beats Hauler and Scout. Frigate beats a lone Fighter. A group of Fighters with torpedoes beats a Frigate. Scouts and Haulers escape by hyperdrive unless a Fighter is disrupting them. An escort Fighter beats the disrupting Fighter.

## Weapons, target tracking and auto-fire

Players do not aim guns. They lock a target and fly to keep it in their weapons' firing arcs, while staying out of the enemy's. Skill comes from six-axis maneuvering, positioning, picking targets and managing shields and modules.

**Locking:** the pilot taps or presses to lock the nearest target in view, or cycles targets. Lock takes about 2 seconds on a small ship, 1 second on a large one and half a second on a carrier. Scouts lock faster.

**Weapon slot types**

| Slot | Firing arc | Who has it |
| --- | --- | --- |
| Fixed | Narrow cone straight ahead (about 10 degrees), highest damage | Scout, Fighter, Frigate |
| Gimbal | Wider cone ahead (about 30 degrees), a bit less damage | Upgrade for fixed slots |
| Turret | Most of a half sphere, slower turning, fires at its own target | Hauler, Frigate, Industrial, Carrier |
| Missile rack | Fires on lock, limited ammo, can be shot down | Fighter |

**Auto-fire:** a weapon fires on its own whenever the locked target is inside its arc, in range, and in line of sight. Missiles are the exception: the pilot fires them, since they are limited.

**Hit chance from tracking:** each weapon has a tracking speed. If the target moves across the gun's view faster than the gun can turn, more shots miss; big guns also miss small targets more often. A Fighter circling close to a Frigate is hard for its big turrets to hit, which is why Frigates carry small point-defense turrets too.

**Why this suits a solo developer:** the server works out each volley's hit chance from positions and speeds and applies damage, and clients only draw tracers and impacts. That is simpler and cheaper than checking every aimed shot with raycasts, and harder to cheat. It matches the server-decides-every-shot plan in the design doc's technical section.

**Crew seats:** because guns fire themselves, a crewmate in a turret seat chooses what that turret shoots at, fires missiles, and runs countermeasures and repairs. An empty turret seat falls back to shooting the nearest threat.

## Engines and handling

**Engines** sit on fixed engine mounts at the back of the hull, so the mount count and positions never change and every hull keeps its look. The engine on each mount is a module the player can swap at any shipyard, and its thrust can be tuned, so two ships of the same hull can fly very differently.

- **Mount size:** each mount is Small, Medium or Large to match the hull, and only engines of that size fit it.
- **Engine types:** every type comes in tiers Mk I to Mk IV, and each tier adds thrust.

| Engine type | Thrust | Power draw | Mass | Good for |
| --- | --- | --- | --- | --- |
| Standard | Medium | Medium | Medium | Any build, the stock engine |
| Sprint | High | High | Light | Fighters chasing and escaping |
| Heavy lift | High, slow to ramp up | Medium | Heavy | Haulers and Industrials with a full hold |
| Efficient | Low | Low | Light | Freeing power for shields, guns or mining |

**Engine output (power units for plasma weapons).** Besides thrust, every engine has an output in power units. A ship's total output is the sum of its working engines, and Energy weapons fire faster the more output the ship has (the fire-rate formula is in "Ammo and power" in [weapons-and-damage.md](weapons-and-damage.md)). Firing never changes the ship's speed. The engine's power draw in the table above is separate and comes from the reactor.

| Engine type | Thrust (x Standard) | Output (x Standard) | Small Mk I | Medium Mk I | Large Mk I | Capital Mk I |
| --- | --- | --- | --- | --- | --- | --- |
| Standard | 1.0 | 1.0 | 100 | 200 | 350 | 600 |
| Sprint | 1.3 | 0.8 | 80 | 160 | 280 | 480 |
| Heavy lift | 1.3 | 1.0 | 100 | 200 | 350 | 600 |
| Efficient | 0.7 | 1.3 | 130 | 260 | 455 | 780 |

- **Tiers:** thrust and output both scale by tier: Mk I x1.0, Mk II x1.2, Mk III x1.45, Mk IV x1.75, so a better engine makes plasma guns fire faster.
- **Thrust setting does not change output:** the thrust slider below only changes thrust and heat, never the output plasma uses.
- **Builds this creates:** Sprint engines make fast ships whose plasma fires slowly, which suits Kinetic guns; Efficient engines make slower ships with fast-firing plasma; Standard sits between. Losing an engine in a fight lowers output, so plasma fires slower.

- **Thrust tuning:** in the shipyard each engine has a thrust slider from 60 to 120 percent. Below 100 saves power for other modules; above 100 draws extra power and builds engine heat, and an overheated engine cuts out for a few seconds. The setting is saved with the loadout.
- **How speed is worked out:** acceleration and top speed come from total engine thrust divided by the ship's mass, so heavy armor or a full hold slows a ship unless it carries stronger engines.
- **Mixing:** mounts on one ship can hold different engines. Fitting fewer than the maximum, or leaving one empty, saves power, and losing one in a fight slows the ship.

**Maneuvering thrusters** (rotating and strafing in all six axes) are built into the hull rather than placed one by one, which keeps module counts and part budgets low. A thruster upgrade module improves them.

**Handling (placeholder values, stock Mk I Standard engines at 100 percent thrust)**

| Hull | Top speed (studs per second) | Turn rate (degrees per second) | Strafe |
| --- | --- | --- | --- |
| Scout | 220 | 90 | Fast |
| Fighter | 180 | 80 | Fast |
| Hauler | 120 | 40 | Slow |
| Frigate | 110 | 30 | Medium |
| Industrial | 90 | 22 | Slow |
| Carrier | 70 | 12 | Very slow |

All ships also have a boost drive that roughly triples speed for crossing a system, and it switches off while the ship is taking damage.

**Mobile note:** full six-axis flight is the hardest thing in this design to make work on a phone. Target lock plus auto-fire helps a lot, since touch players only steer. The design doc's controls (left stick for thrust, drag to steer, buttons for roll, lock and boost, with flight assist on by default) cover all six hulls; the slower turn rates of big hulls need checking on a phone in the first prototype.

## Hyperdrives and travel

**Jump gates** link neighbouring star systems and anyone can use them, so ships without a hyperdrive can still travel. Gates are also where pirates wait.

**A hyperdrive** lets a ship jump from anywhere in a system to another system without flying to a gate. It is the escape tool for non-combat ships.

| Hull | Range | Spool time |
| --- | --- | --- |
| Scout | Up to 2 systems | 6 seconds |
| Hauler, Frigate, Industrial | 1 system | 12 seconds |
| Carrier | Up to 3 systems, with docked ships | 25 seconds |

**Rules:** the hyperdrive cannot spool within 10 seconds of taking hull damage, and a Fighter's warp disruptor stops it while the disruptor is in range. Each jump uses fuel bought at stations, which adds a money sink. Jumping into deep systems is only by gate, so the gate toll and gate fights stay meaningful; a hyperdrive can always jump out of one.

On Roblox, a hyperdrive jump is a teleport to the destination system's server. A carrier jump teleports the carrier's crew and the pilots docked in it together as one group.

## Carriers and docking

Only Small hulls (Scout and Fighter) fit in a carrier, one per hangar bay, 4 bays per carrier.

- **Docking:** fly into the bay's marked entrance and the ship snaps in. Docked ships are hidden and not simulated, which costs nothing in physics, so carriers do not add lag.
- **While docked:** shields and hull HP refill slowly, and missiles reload.
- **Launching:** one button, with 3 seconds of launch protection.
- **If the carrier is destroyed:** docked ships are thrown out with 5 seconds of protection rather than destroyed with it.
- **Owning one:** the carrier belongs to one player and bays are shared with their crew. It is the most expensive hull in the game, and losing it outside a hub follows the same module-loss rules as any ship.

## Losing a ship

Ship loss follows the design doc: nothing inside a trade hub safe zone. Everywhere else, drops happen only when the whole ship is destroyed (a module being knocked out drops nothing): the ship drops all its cargo and about 1 in 4 fitted modules as salvage. The attacker who destroys it also earns a Credit reward based on the destroyed ship's value, on top of whatever cargo and salvage they pick up. Insurance returns the hull and surviving modules, and the saved design is never lost, so the player refits from the same layout. Insurance cost scales with hull size, so carriers are expensive to lose. A Fighter's power rating stays low next to a Hauler's, so the doc's bounty for killing much weaker ships needs tuning so it does not fire on every normal pirate kill.

## Art and build budgets (low poly)

Each hull is a low poly model with flat colors and paintable panels, built from MeshParts. Modules are small low poly pieces that snap to the hull's grid. Weapon and engine mounts sit in fixed spots on each hull so every ship still looks good, and everything else goes in the free grid cells.

| Size | Rough triangle budget for a fully fitted ship | Max modules |
| --- | --- | --- |
| Small | 1,500 to 2,500 | 15 |
| Medium | 3,000 to 5,000 | 25 |
| Large | 8,000 to 12,000 | 40 |
| Capital | about 20,000 | 60 |

These keep a server with 30 to 50 ships workable on phones; they should be checked on a low-end device during the first playtests.

## Build order for a solo developer

1. **Prototype:** Scout only, with six-axis flight, target lock and one auto-firing gun.
2. **Vertical slice and MVP:** add Fighter and Hauler, shields, hull HP, module damage, the hyperdrive and the warp disruptor. This matches the three MVP hulls in the design doc.
3. **After launch:** Frigate and Industrial with crew seats and turrets.
4. **Later:** Carrier, once crews exist and the player count supports it.

## Open questions for MAtthew

- Keep the six hulls above, or add a dedicated pirate or bomber hull later?
- Should Haulers fit in carriers too (would need bigger bays and a bigger carrier model)?
- Is a Fighter-only warp disruptor right, or should Frigates get one too?
