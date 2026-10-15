# Comparable space games: research for the Roblox space PvP game

**Concept being researched (MAtthew's words):** an open-world, large-multiplayer PvP space game. Players fly to planets, mine resources and sell them, destroy other players' ships, and customize their own ships with modular parts.

**How to read this file.** Each claim is tagged with where it came from:
- **[src]** means I checked it in a linked source while researching (October 2026).
- **[known]** means it's well-established public knowledge about a long-running game (EVE, Elite, No Man's Sky and so on). I didn't re-check it this session.
- **[inferred]** means it's my design judgement, not something a source says.

The design thread should treat **[inferred]** items as proposals, not facts.

**Decided since this research (Oct 15).** Where this file suggests otherwise, these win; details are in the files under design/:
- Only trade hubs are safe zones; PvP is on everywhere else, and deep systems have no hubs (instead of the four-tier zone model below).
- Cargo and about 1 in 4 fitted modules drop only when a ship is fully destroyed, and attackers earn a Credit reward for the kill.
- Combat is full six-axis flight with target lock and guns that fire on their own; there are two weapon classes, Energy (plasma) and Kinetic.

---

## 1. TL;DR for the design doc

1. **Use risk tiers, not "PvP everywhere."** Every successful open-world PvP game zones its world by risk: EVE (high/low/null sec), Albion (blue/yellow/red/black), and Starscape on Roblox (secure / unsecure / wild). Safe zones keep new and casual players around, and dangerous zones hold the best loot. On Roblox this matters even more, because the audience skews young and casual and will leave if they get ganked in their first 10 minutes. [src][inferred]
2. **Losing a ship should hurt, but never reset a player to zero.** Give players a free starter hull, insurance, or a cheap respawn ship. Wild-space deaths can drop the *cargo* (the ore you mined) and maybe some modules, but the player keeps progression and blueprints. Starbase got community pushback both on free replacements (they "kill the reason to recover ships") and on new players being unable to bootstrap from nothing. That points to a middle path. [src][inferred]
3. **One giant seamless server isn't realistic on Roblox. Build a universe of places.** Treat each star system, or each cluster of systems, as its own Roblox place or server, and travel between them by teleport ("warp/jump gate" loading screen). Keep shared state in DataStores/MemoryStore. Design for roughly 30 to 60 players per server, not hundreds. [src][inferred]
4. **Modular ships are the strongest hook, and the biggest technical risk.** Space Engineers players praise building above everything else, and complain most about performance and onboarding. Snap-to-grid modules (hull pieces, weapon hardpoints, engines, cargo pods) are far cheaper than free-form physics building, and they fit Roblox well. [src][inferred]
5. **Monetize cosmetics, not power.** Starscape's shop sells skins, trails and symbols only, and states it "will never sell any items that give a pay-to-win advantage." In a PvP game, paid power poisons trust fast. [src]

---

## 2. Comparable games on Roblox

| Game | What it is | Relevance |
|---|---|---|
| **Starscape [Beta]** (ZolarKeth) | "Open-universe space exploration and combat" with "thousands of dynamic, persistent star systems." Players compete for positions and resources, mine/refine/craft (Industry skill tree), trade on a player market, join NPC factions or create player factions, build ships, and fight a drone threat at the galaxy edge. [src: [Roblox page](https://roblox.com/games/679715583), [wiki](https://starscape-roblox.fandom.com/wiki/Interface), [Sportskeeda](https://www.sportskeeda.com/roblox-news/best-sci-fi-games-roblox)] | **The closest existing match to this concept.** It proves the genre works on Roblox. Notable details: system security levels (the settings warn before warping into "unsecure" and "wild" systems), duel and trade requests that can be limited to friends, faction warfare and standings, and a cosmetics-only Robux shop ("Stardust"). Our differentiation has to come from somewhere: planets you actually land on, deeper modular building, or faster/more accessible combat. [inferred] |
| **Galaxy** | Open-world space action game. Rotrends lists 2.6M visits, 81% rating, a peak of 554 concurrent players, and about 20 average concurrent over the last 7 days. [src: [rotrends](https://rotrends.com/game/4371550953)] | Shows the niche can attract players but also lose them. Its low current player count is a warning: open-world space games need enough players per server to feel alive. [inferred] |
| **Project Stardust** | Team PvP ship combat inspired by Star Wars/Halo. Earn money, buy damage/health upgrades, launch and dock multiple ships. Reviewers praise how the combat feels. [src: [Sportskeeda](https://www.sportskeeda.com/roblox-news/5-best-space-games-roblox)] | A reference for combat feel and arena pacing. A good model if we want a session-based PvP mode alongside the open world. [inferred] |
| **Deep Space Tycoon** | Strategy game: pick planets for bases, build large ships, missions. [src: Sportskeeda] | A reference for base building and the tycoon progression loop. |
| **Space Mining Tycoon** | Relaxed planet-hopping mining with bases. [src: Sportskeeda] | Shows a casual, mining-only audience exists. Useful for the safe-zone loop. |
| **Space Sailors** | Laid-back realistic travel to the Moon, Mars and the ISS, with a rover. [src: Sportskeeda] | A reference for landing on planets and exploring. |
| **Project Superstellar** (Stellar Secrets) | Genre not stated. 10.9M visits, all-time peak 2K concurrent in Oct 2026. [src: [rowatcher](https://rowatcher.com/games/9216313546/project-superstellar)] | Worth a manual look on Roblox, since it's a recent space-titled hit. I couldn't confirm its gameplay. |

Search results for Roblox space games are thin and noisy. A human should spend 30 minutes playing Starscape and browsing Roblox's search for "space" to catch newer titles. [inferred]

---

## 3. Comparable games outside Roblox (lessons, not features to copy)

### EVE Online: the open-world PvP and economy benchmark [known]
- **Loved:** a fully player-driven economy (players mine, build and sell almost everything), meaningful losses (ships blow up and drop part of their loot), territory wars, and emergent stories.
- **Security tiers:** high-sec (NPC police punish aggressors after the fact, so ganking is possible but costly), low-sec (no police response), and null-sec (no rules, player-owned territory, best resources).
- **Complaints:** a brutal new-player experience, "ganking" of miners and haulers in high-sec, a steep learning curve, and spreadsheet-like gameplay. Long-running EVE forum threads on new-player retention keep coming back to new players being killed before they understand the game. [src: [EVE forums](https://forums.eveonline.com/t/how-to-retain-players-in-eve/488137)]
- **Insurance:** ships can be insured, so losing one refunds part of its cost.
- **Lesson:** keep the tiers, insurance and risk-reward gradient. Cut the complexity and the high-sec ganking.

### Albion Online: the clearest risk-zone model [src: [albionmarket.gg](https://www.albionmarket.gg/guides/zones-and-flagging)]
| Zone | PvP | Lost on death |
|---|---|---|
| Blue | None | Nothing |
| Yellow | Only flagged players can attack. Victims are knocked down, not killed. | Nothing looted, just durability damage |
| Red | Anyone can be attacked. Attacking unflagged players costs reputation. | All equipped gear and inventory |
| Black | Free-for-all outside your guild | All equipped gear and inventory |
- **Lesson:** this maps almost one-to-one onto star systems, for example *Core → Frontier → Contested → Void*. The "yellow zone" idea (opt-in PvP, light penalties) is a great on-ramp for Roblox players. [inferred]

### Elite Dangerous [known]
- **Loved:** a 1:1 galaxy, flight feel, mining (laser and core mining with asteroid cracking is fun on its own), and exploration.
- **Complaints:** "mile wide, inch deep," with lots of empty travel time. Open-play griefing pushed many players into Solo or Private modes, which split the community.
- **Lesson:** give players a way to opt out of or reduce PvP, or they'll quit. Make mining an activity with skill in it, not just holding a button. Keep travel short.

### No Man's Sky [known]
- **Loved:** landing on planets seamlessly, a sense of discovery, base building, and generous updates after launch.
- **Complaints at launch:** overpromising, plus repetitive procedural planets.
- **Lesson:** a few handcrafted planets with distinct biomes and resources beat thousands of samey ones, especially on Roblox. [inferred]

### Space Engineers [src: [vaporlens review summary](https://vaporlens.app/app/244850/space_engineers)]
- **Loved most:** modular, physics-driven building of ships and stations, creative freedom, and the community and mods.
- **Disliked most:** performance (especially in multiplayer), crashes, a poor tutorial and UI, and a steep learning curve that sends players to wikis and YouTube.
- **Lesson:** the building fantasy is the hook. Constrain it (grid snapping, a part budget, prebuilt templates) so it stays performant and a 10-year-old can make a cool ship in 2 minutes.

### Starbase (Frozenbyte) [src: [forum thread](https://forum.starbasegame.com/goto/post?id=25572)]
- **Complaints:** new players couldn't "begin from nothing," because the mining backpack was too small to craft the first needed parts. Players called this jarring enough to make people quit. PvP balance issues came up too: tiny laser ships beat max-size miners, and a lone boarder could steal a ship from its owner. Players also argued that free replacement ships remove the incentive to recover or protect ships.
- **Lesson:** test the "zero to first upgrade" path ruthlessly. Make sure miners and haulers have defensive options or escape tools. Balance ship classes as rock-paper-scissors, not "smallest DPS boat wins." [inferred]

### Star Citizen [known]
- **Loved:** the vision of multi-crew ships, landing on planets, and physical cargo.
- **Complaints:** monetizing ship sales for real money (pay-to-win perception), performance, and server meshing that was promised for years.
- **Lesson:** don't sell ships for Robux, and don't promise seamless scale you can't deliver.

---

## 4. Cross-cutting themes: what players love and hate

**Players love** [known/src]
- Building and showing off a ship they designed.
- Taking risks for a big payoff ("I hauled a full load out of the Void and made it back").
- Group play: squads, factions, defending your miners.
- Visible progression: better hulls, modules, cosmetics.
- Emergent stories and rivalries.

**Players hate** [known/src]
- Being killed by a vastly stronger player with no chance to fight back or escape (ganking or spawn camping).
- Losing hours of progress at once.
- Long, empty travel.
- Grind with no variety, like holding mouse1 on rocks.
- Pay-to-win.
- Lag, especially in big fights.
- Being confused in the first 5 minutes.

---

## 5. Implications for each core system [inferred unless tagged]

### 5.1 Open-world PvP
- **Four zone tiers** by star system: Safe (no PvP, NPC police), Low-risk (opt-in or flagged PvP; losers drop a share of cargo but keep the ship), High-risk (open PvP; the ship is destroyed and drops cargo plus a chance of modules), and Lawless (rare resources, faction territory).
- **Anti-gank tools:** a short spawn shield, a warp-out channel with a counter-play window, NPC response in safe space, bounties on players who attack in low-risk space, and power-rating matchmaking for which systems you can enter (for example, a capped "rookie" sector).
- **Rewards scale with danger.** The best ores exist only in high-risk and lawless systems, so PvP happens because of the economy, not as a separate mode.
- **An optional arena mode** like Project Stardust for players who want PvP without risking their ship.

### 5.2 Mining and the selling economy
- Make mining a mini-game (heat or overheat management, weak spots, cracking big asteroids) so it isn't idle.
- **Cargo is the risk object.** Mined ore sits in your hold until you sell it at a station, which creates hauling tension and targets for PvP.
- **Prices:** start with NPC-set prices that vary per station and drift with supply and demand (buy low here, sell high there). Add a player market later, once there are enough players. A fully player-driven EVE-style economy needs high player density that a new Roblox game won't have.
- **Money sinks** keep inflation down: repairs, insurance premiums, module crafting costs, fuel, and market taxes.

### 5.3 Modular ships
- **Snap-to-grid parts** on hardpoints: hull frames (small/medium/large), engines, thrusters, weapons, shields, cargo pods, mining lasers, and utility parts (scanner, cloak, warp drive).
- **Budgets** keep it balanced and performant: power, mass and part-count caps per hull class. Mass affects speed, so cargo and guns become a trade-off.
- **Saved blueprints** let players rebuild after losing a ship (cost = materials). Losing the ship never deletes the design.
- **Rock-paper-scissors classes:** fighter > miner/hauler, frigate > fighter, and an escort role protects miners.
- **Performance:** weld each ship into a few assemblies. Do visuals on the client and keep server collision simple (one or a few hit boxes per ship).

---

## 6. Roblox platform limits and what they imply

| Limit / fact | Source | Implication |
|---|---|---|
| **Instance streaming** (`StreamingEnabled`, on by default) loads and unloads Workspace content by distance from the player. Defaults: `StreamingMinRadius` 64 studs, `StreamingTargetRadius` 1024 studs. Physics only simulates in streamed-in areas on the client. Too many replication foci or persistent models hurt performance, and large moving assemblies cause network spikes when they stream in. | [src: Roblox docs, instance streaming](https://create.roblox.com/docs/en-us/workspace/streaming.md) | Space is mostly empty, which helps. Keep planets and stations as streamable models and ships as compact assemblies. Mark only critical models (the player's own ship) persistent. Client scripts must handle ships popping in and out of view. |
| **Floating-point precision:** physics gets less stable far from the world origin. No official distance threshold or fix exists. Community workarounds are chunking, relative grids, and recentering. | [src: DevForum](https://devforum.roblox.com/t/physics-grids-for-large-maps/2969029) | Don't build one huge coordinate space. Keep each system within a modest radius, roughly tens of thousands of studs (an inferred safe range that needs testing), and use **separate places per system** to get "vastness." |
| **Teleporting between places** in one universe uses `TeleportService:TeleportAsync()`. Reserved servers are available for instanced content. Teleports can fail, so wrap them in pcall and retry. Teleport data is client-visible, so store inventory and currency in DataStores, not teleport data. | [src: Roblox docs, teleport](https://create.roblox.com/docs/en-us/projects/teleport.md) | Use a **galaxy = universe, star system = place** architecture. Jump gates or warp = a teleport with a themed loading screen. Use reserved servers for faction bases, private arenas, and events. |
| **DataStore budgets** per server per minute: 60 + 40 × players for both reads and writes. Ordered writes are 30 + 5 × players. Each key holds at most about 4 MB, and each key can take at most 4 MB of writes per minute across all servers. | [src: Roblox docs, DataStore limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits.md) | Save player data on intervals and at checkpoints (sell, dock, leave), not on every ore pickup. Ship blueprints fit easily under 4 MB. A **global market** can't be one hot DataStore key: use MemoryStore and MessagingService for live prices and order books, and batch writes. |
| **Players per server:** I couldn't confirm the current official maximum from Roblox docs this session (the docs page failed to load). Community figures conflict: 100, and up to 700 in a few cases. Voice chat works in servers up to 100. | [src: DevForum, unverified](https://devforum.roblox.com/t/2232016); [creation.dev](https://www.creation.dev/learn/roblox-voice-chat-100-player-servers-update) | **Design for roughly 30 to 60 players per system server.** That's enough for fights, and it stays in budget on phones. "Large multiplayer" comes from many connected servers plus shared economy and faction state, not one 500-player server. A designer should check the slider in Game Settings → Places. |
| **Audience and devices:** a large share of Roblox players are on mobile and are younger. [known] | — | Use simple touch controls for flight (auto-throttle, aim assist), small UI, and low-part ships. Rely on Roblox's text chat filtering, and avoid mechanics that reward harassment. |
| **Monetization norms:** game passes, developer products, and Premium payouts. Starscape's cosmetics-only shop is the genre precedent. | [src: Starscape wiki](https://starscape-roblox.fandom.com/wiki/Interface) | Sell skins, trails, decals, hangar slots, and convenience items that aren't power (for example, extra blueprint slots). Avoid selling stat modules or ships. |

---

## 7. Open questions for MAtthew / the design thread
1. How harsh should death be in the most dangerous zones: lose cargo only, or cargo plus the ship (rebuilt from a blueprint)?
2. Planets: land on and walk around (on foot and in rovers), or orbit and mine from space only? Landing is a differentiator from Starscape, but it costs a lot more to build.
3. Is there a PvE threat (NPC pirates, alien drones) to fill servers when player counts are low?
4. Is a player-run market planned for launch, or NPC prices first?

## Sources
- Starscape on Roblox: https://roblox.com/games/679715583
- Starscape wiki (Interface): https://starscape-roblox.fandom.com/wiki/Interface
- Sportskeeda, best sci-fi Roblox games: https://www.sportskeeda.com/roblox-news/best-sci-fi-games-roblox
- Sportskeeda, best space Roblox games: https://www.sportskeeda.com/roblox-news/5-best-space-games-roblox
- Rotrends, Galaxy: https://rotrends.com/game/4371550953
- Rowatcher, Project Superstellar: https://rowatcher.com/games/9216313546/project-superstellar
- Roblox docs, instance streaming: https://create.roblox.com/docs/en-us/workspace/streaming.md
- Roblox docs, teleporting: https://create.roblox.com/docs/en-us/projects/teleport.md
- Roblox docs, DataStore limits: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits.md
- DevForum, physics grids for large maps: https://devforum.roblox.com/t/physics-grids-for-large-maps/2969029
- DevForum, server size discussion: https://devforum.roblox.com/t/2232016
- creation.dev, voice chat in 100-player servers: https://www.creation.dev/learn/roblox-voice-chat-100-player-servers-update
- Albion zones and flagging: https://www.albionmarket.gg/guides/zones-and-flagging
- EVE forums, new-player retention: https://forums.eveonline.com/t/how-to-retain-players-in-eve/488137
- Starbase forum, top issues: https://forum.starbasegame.com/goto/post?id=25572
- Space Engineers review summary: https://vaporlens.app/app/244850/space_engineers
