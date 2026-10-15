# Weapons and Damage Model (Draft 1)

Oct 15, 2026 · for MAtthew · builds on [game-design-doc.md](game-design-doc.md) and [ship-types.md](ship-types.md)

This file answers: what the two weapon classes are, how each one interacts with shields, armor, hull and modules, and how the server turns an auto-fired volley into damage. All numbers are starting points for playtests and live in one stats table in code.

It follows the confirmed decisions: full six-axis flight, target lock with guns that track and fire on their own, about 1 in 4 fitted modules dropped on death outside safe zones, low-poly art, and a solo developer with long playtests.

**Settled with MAtthew:** ionic and Energy (plasma) are the same class, so there are exactly two. Shields stop Energy; Kinetic goes through shields with a 20% reduction and does less damage, so Kinetic is the tool for knocking out a shield generator and Energy finishes the job once the shield is gone. Ship speed never changes when firing; instead plasma fire rate depends on engine power. Attackers are paid for kills, and modules drop only when a ship is fully destroyed.

## The two classes at a glance

| | Energy (plasma) | Kinetic |
| --- | --- | --- |
| Damage | Full (baseline 100%) | About 60% of Energy at the same size and tier |
| Against shields | Absorbed by the shield; the only class that drains it | Passes through at 80% damage (shields stop 20%); shield pool untouched |
| Against armor | Ignores armor reduction | Reduced by armor plates |
| Against modules | Only once the shield is down | Always, with a 1.5x bonus to module damage |
| Range | Short: 300 to 500 studs, full damage to half range, 50% at max range | Long: 700 to 1,800 studs, holds damage to max range |
| Cost to run | No ammo; fire rate depends on engine power, speed never changes | Needs ammo carried onboard in a magazine module; almost no power draw |
| Looks like | Glowing cyan and magenta bolts and beams; shield ripples on hit | Yellow tracers, sparks, hull scorch decals; a small ripple as it passes the shield |

**Why the split works:** a shield-heavy ship is countered by Kinetic, an armor-heavy ship is countered by Energy, and a mixed loadout wins against a balanced ship by using Kinetic to kill the shield generator, then pouring Energy into the bare hull.

## Defense layers

A ship has four things that can absorb damage. Only Energy touches the first.

1. **Shield.** A bubble projected by the **shield generator** module. It absorbs Energy damage until its pool is empty and recharges after 4 seconds without taking Energy damage. While it is up, it takes 20% off every Kinetic hit that passes through, but Kinetic hits never drain it or pause its recharge.
2. **Armor plates.** Each plate adds hull HP (200 small, 300 medium, 400 large, as in ship-types.md) and **12.5% Kinetic damage reduction**, capped at 50% (4 plates). Energy ignores the reduction. Plates add mass, so armored ships turn slower.
3. **Hull HP.** The ship's structure. Every hit that gets past the shield lands here. It does not recharge in flight. The ship is destroyed at 0.
4. **Modules.** Each module has its own small HP pool. Every hit that reaches the hull also damages one module (see the damage pipeline). A module at 0 HP is **knocked out**: it stops working until repaired.

**The shield generator is the key module.** When it is knocked out, the shield drops to 0 at once (a low-poly "shatter" effect so everyone sees it happen) and cannot recharge until the generator is repaired. A repair module brings it back online at 25% HP after 10 seconds out of combat; a station or carrier repairs it fully.

**What knocking out each module does**

| Module | Effect when knocked out |
| --- | --- |
| Shield generator | Shield drops to 0 and stops recharging |
| Reactor | Power drops to 25%; shields recharge slowly and other modules may switch off |
| Engine | Top speed falls by that engine's share, and plasma fire rate drops with the lost output; boost drive off if all are out |
| Magazine | The guns it feeds stop, and it cooks off for 150 damage to the hull and neighbouring modules |
| Weapon | That gun stops firing |
| Cargo hold | Spills a share of its ore into space as pickups |
| Hyperdrive | Cannot spool |
| Cockpit | Ship destroyed |
| Connector | Modules beyond it lose power (existing grid rule) |

**Module HP (placeholder):** shield generator 150 on small hulls, 250 medium, 400 large, 800 capital. Other modules scale similarly; the cockpit has double.

## Weapon list

Small guns fit fixed or gimbal slots on Scouts and Fighters, medium guns fit Frigate fixed slots, and turrets fit any turret mount. Every class has a gun for each slot type, so any hull can run either class or a mix. Numbers are Mk I.

**Energy**

| Weapon | Slot | DPS | Optimal / max range (studs) | Tracking | Power draw (units) | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Pulse Blaster | Small fixed or gimbal | 20 | 150 / 300 | Fast | 60 | The all-rounder; replaces "Blasters" in the design doc |
| Plasma Cannon | Medium fixed | 45 (68 per bolt, 1 every 1.5 s) | 250 / 500 | Slow | 120 | Big bolts, misses small fast targets often |
| Beam Turret | Turret | 30 | 200 / 400 | Medium | 90 | Continuous beam, overheats after 8 s of firing |
| Plasma Torpedo | Missile rack | 400 per hit, 4 per rack | 600 max | Homing | 90 | Pilot-fired; erases a shield in one hit; rack recharges from the engine, 20 s per torpedo at full fire rate |

"Optimal" is where full damage ends; damage then falls to 50% at max range.

**Kinetic**

| Weapon | Slot | DPS | Range (studs) | Tracking | Ammo per magazine slot | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Autocannon | Small fixed or gimbal | 12 | 700 | Fast | 90 s of fire | The generator-killer on small ships |
| Railgun | Medium fixed | 30 (120 per shot, 1 every 4 s) | 1,800 | Very slow | 20 shots | Long-range hull and module sniper |
| Flak Turret | Turret | 18 | 800 | Fast | 90 s of fire | Covers blind spots, good against small ships |
| Hull-Cracker Missile | Missile rack | 250 per hit, 4 per rack | 1,200 | Homing | The rack holds its own 4 | Pilot-fired; 2x module damage instead of 1.5x |
| Point Defense | Turret | 0 to ships | 300 | Very fast | Unlimited | Shoots down missiles and torpedoes only |

## Ranges

Kinetic outranges Energy by roughly 2 to 4 times, so every fight is a question of distance: Kinetic ships want to hold range, Energy ships want to close in.

| Band | Distance (studs) | Who can hit |
| --- | --- | --- |
| Close | 0 to 300 | Everything; Energy at full or near-full damage |
| Mid | 300 to 500 | Plasma Cannon (falling off) and all Kinetic |
| Long | 500 to 800 | Kinetic only, plus Plasma Torpedoes |
| Extreme | 800 to 1,800 | Railgun and Hull-Cracker Missiles only |

At Fighter speed (180 studs per second) crossing from 700 to 300 studs takes about 2 seconds, so an Energy Fighter can close on an Autocannon Fighter fast. The Railgun's 1,800 is the one range that really lets a ship kite, and its very slow tracking means it mostly hits big, slow or straight-flying targets. Missiles and torpedoes can be shot down at any range by point defense.

**Roblox note:** streaming may not load ships 1,800 studs away on a phone. Combat runs on the server, so hits still count, but the client should draw a lock marker and tracer for distant targets even when the ship model isn't loaded. Test this in the first prototype.

## Ammo and power

**Kinetic ammo is carried onboard.** Every Kinetic gun needs a **magazine** module somewhere on the grid. One magazine cell feeds one small gun for the times in the table (two cells for a Railgun or turret). That means Kinetic builds trade grid space for range, and magazines share the cargo and module budget.

- Ammo refills free at any hub or carrier, and costs a few Credits per reload at other stations (a small money sink).
- A gun with no ammo left stops firing; the HUD shows rounds left per gun.
- A magazine is a module like any other: if it is knocked out, the guns it feeds stop, and it **cooks off**, dealing 150 damage to the hull and to the modules next to it. Burying magazines in interior cells is the counter.
- Dropped magazines (from the 1 in 4 module drop) leave their remaining ammo as a salvage pickup.

**Energy fire rate comes from the engine.** Plasma weapons need no ammo and never change the ship's speed. Instead, how fast they fire depends on how much engine power the ship has for them:

- Every engine module has an **output** in power units (placeholder: 100 per Mk I small engine, scaling with size and tier). A ship's total output is the sum of its working engines. Thrust values stay separate and adjustable, as decided in the ship classes thread.
- Each plasma gun has a **power draw** (see the Energy table). Total draw is the sum over every plasma gun fitted.
- **Plasma fire rate = total output ÷ total draw**, capped at 100%. Every plasma gun on the ship fires at that rate.

**Example:** a Fighter with two Mk I engines has 200 output. Four Pulse Blasters draw 240, so they fire at 83%. Two Pulse Blasters plus two Autocannons draw only 120, so the blasters fire at 100%. Swapping in Mk II engines (120 each, 240 total, using the engine tiers in ship-types.md) brings four blasters to full rate.

- This is the Energy cost that matches Kinetic's range and ammo: stacking plasma means investing in engines, and a pure-plasma build on stock engines fires slower.
- Every knocked-out engine removes its output, so engines are a target for both classes: lose one of two engines and four blasters drop to 42%.
- Mixing in Kinetic guns frees engine power, so the mixed loadout keeps its plasma at full rate.
- The rate is worked out when the loadout changes or an engine is knocked out or repaired, so the server does almost no extra work.

**Tiers:** each Mk step multiplies damage by about 1.35 (Mk I 1.0, Mk II 1.35, Mk III 1.8, Mk IV 2.4) and power draw by about 1.1 for Energy, so higher tiers hit harder but need better engines to fire at full rate; Kinetic tiers instead raise ammo per magazine by about 15%.

## Damage pipeline (server, per volley)

Because guns fire on their own, the server decides every shot, as the design doc's technical plan says. Each weapon runs this every time its fire timer ticks:

1. **Can it fire?** The target is locked, inside this gun's arc, within range and in line of sight, and the gun has ammo (Kinetic) or the ship has a working engine (Energy). If not, skip. Energy guns tick at their base rate times the ship's plasma fire rate.
2. **Did it hit?** Roll against the hit chance:
   `hitChance = baseAccuracy × min(1, trackingSpeed ÷ targetAngularSpeed) × min(1, targetSize ÷ weaponSize)`
   Base accuracy is about 0.85. Fast circling targets and small targets against big guns lower the chance.
3. **How much?** `damage = baseDamage × tierMultiplier × rangeFalloff` (Energy only falls off; Kinetic is flat).
4. **Energy and the shield is up:** subtract from the shield pool and reset its 4 second recharge timer. If the hit empties the shield, the leftover carries on to step 5. Otherwise stop here.
5. **Reaching the hull:** for Kinetic, multiply by 0.8 if the shield is up, then by `(1 − armorReduction)`. Subtract from hull HP.
6. **Module damage:** the same hit also damages one module: the locked subsystem if the pilot picked one, otherwise a random module on the side facing the shooter. Kinetic deals 1.5x to modules (Hull-Cracker 2x). Modules in interior grid cells, fully surrounded by other modules, take half module damage, so careful builders can bury their generator.
7. **Results:** knock out any module at 0 HP and apply its effect; destroy the ship at 0 hull HP and apply the loss and reward rules below. Knocked-out modules drop nothing on their own. Send one event to clients to draw tracers, impacts and any shatter or knock-out effect.

No raycasts per bullet are needed, and clients never report damage.

## How fights play out (checked numbers)

These are times to kill one Fighter (800 shield, 1,400 hull) with 4 small Mk I guns at a 60% hit rate, assuming the attacker keeps the target in arc and inside each gun's range the whole time. Real fights run longer because of maneuvering and shield recharge, which lands them in the 45 to 60 second target.

| Attacker loadout | vs plain Fighter | vs Fighter with 2 armor plates (1,800 hull, 25% Kinetic reduction) |
| --- | --- | --- |
| 4 Pulse Blasters (all Energy, 83% fire rate on stock engines) | 55 s | 65 s |
| 4 Autocannons (all Kinetic) | 50 s | 85 s |
| 2 Autocannons on the generator + 2 Pulse Blasters (full fire rate) | **43 s** | 60 s |

The mixed loadout kills the generator in about 9 seconds, then both classes hit bare hull at full damage. All-Energy catches up with better engines (46 s on Mk II engines). Against a Frigate (3,000 shield, 6,000 hull, 400 HP generator) the same lone Fighter takes 225 s all-Energy, 211 s all-Kinetic and **173 s** mixed, which is why a group of Fighters is the Frigate counter in ship-types.md.

The pattern to aim for in playtests: no single class is best against everything, the combo wins against balanced fits, and the defender can counter-build (more armor against Kinetic, bigger shield against Energy, a buried generator against the combo).

## Where the skill is

- **Loadout choice:** what you bring decides who you can beat, and the loadout screen should show a simple "good against shields / good against armor" tag on every gun.
- **Subsystem targeting:** locking the shield generator with Kinetic, then switching back to the hull, is the signature move. On mobile this is one button that cycles hull, generator, engines and cargo.
- **Range:** Energy pilots want to close inside 300 studs; Kinetic pilots want to hold 500 to 800, and Railgun pilots stay far out.
- **Engines as a weapon stat:** Energy pilots balance engines against guns in the shipyard, and protecting engines in a fight keeps their guns firing.
- **Ammo:** Kinetic pilots manage magazines across a long trip and can be starved out by a long chase.

## For a solo developer

- Every number above sits in one `WeaponStats` table plus a `Defense` table, so a playtest change is a one-line edit:

```lua
-- ReplicatedStorage/Shared/WeaponStats.lua (sketch)
return {
    PulseBlaster = { class = "Energy",  slot = "Small",  dps = 20, optimal = 150, range = 300,  tracking = 1.0, drawUnits = 60 },
    Autocannon   = { class = "Kinetic", slot = "Small",  dps = 12, range = 700,  tracking = 1.0, magazineCells = 1, ammoSeconds = 90 },
    Railgun      = { class = "Kinetic", slot = "Medium", dps = 30, range = 1800, tracking = 0.3, magazineCells = 2, shots = 20, shotDamage = 120 },
    -- ...
}
```

- One server `Combat` service runs the pipeline for all ships, ticking each gun on its own fire timer.
- Low-poly effects are cheap: a neon part for bolts, a beam object for beams, a shared tracer, one shield sphere mesh with a ripple texture and a shatter of a few wedges. Two classes means two colour sets players learn in one fight.
- **Build order:** the flight prototype gets Pulse Blaster and Autocannon only, shield generator, hull HP and module knock-out. Railgun, Plasma Cannon, turrets and missiles come with the ship hulls that use them.

## Kill rewards and drops

Modules and cargo drop **only when a ship is fully destroyed**. Knocking out a module mid-fight disables it but drops nothing.

When a ship is destroyed outside a safe zone, the attackers get:

- **Salvage:** all of the destroyed ship's cargo and about 1 in 4 of its fitted modules, dropped as pickups (the existing loss rule).
- **A destruction payout in Credits,** paid straight to the attackers and based on the destroyed ship: about 10% of the value of its hull and fitted modules, plus 5% of its cargo value. It is split by damage dealt between everyone who hit the ship in the last 30 seconds, so crews share it.
- **Anti-farming:** the payout shrinks for repeat kills of the same player within an hour, and is zero for crewmates or very cheap ships. The existing bounty for killing much weaker ships still applies.

The payout means a pirate who blows up a ship with an empty hold still earns something, while haulers with full holds stay the richest targets.

## Open questions for MAtthew

- Is about 10% of the destroyed ship's value the right size for the kill payout?
- Should the Credits payout come from the game (new money) or out of the victim's insurance (no new money)?
