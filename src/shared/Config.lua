--[[
	Every balance number for the flight and combat prototype lives here, so a
	playtest change is a one-line edit. Values come from design/ship-types.md
	and design/weapons-and-damage.md; anything marked "placeholder" was not
	given in the docs and is a first guess.
]]

local ShipClasses = require(script.Parent.ShipClasses)

local Config = {}

--------------------------------------------------------------------------------
-- Flight
--------------------------------------------------------------------------------

Config.Flight = {
	-- Flight assist damps drift so the ship stops when you let go. Off gives
	-- Newtonian drift. The design doc's open question is which is the default.
	assistDefault = true,

	boostMultiplier = 3, -- boost drive roughly triples speed
	boostDamageLockout = 3, -- seconds after taking damage before boost works again (placeholder)

	mouseDeadzone = 0.06, -- fraction of half the screen where mouse steering does nothing
	angularResponse = 8, -- how quickly rotation follows input, higher is snappier (placeholder)
	minSpeedScale = 0.15, -- maneuvering thrusters keep a ship moving with every engine out (placeholder)

	-- Server-side sanity check on client-owned ships: warn when a ship moves
	-- faster than its top boosted speed times this.
	speedCheckTolerance = 1.25,
}

--------------------------------------------------------------------------------
-- Hulls (ship-types.md)
--------------------------------------------------------------------------------

-- Every hull's stats live in ShipClasses (one entry per class from
-- ship-types.md). Config.Hulls is the same table, so Config.Hulls.Frigate.topSpeed
-- and ShipClasses.classes.Frigate.topSpeed are one value.
Config.Hulls = ShipClasses.classes

Config.SizeRank = {
	Small = 1,
	Medium = 2,
	Large = 3,
	Capital = 4,
}

Config.LockRange = 2000 -- studs; a lock breaks beyond this (placeholder)
Config.LockConeDegrees = 35 -- client picks the nearest target within this angle of the nose (placeholder)

--------------------------------------------------------------------------------
-- Slots (ship-types.md, "Weapon slot types")
--------------------------------------------------------------------------------

-- arc is the half-angle of the firing cone in degrees. The docs give 10 and 30
-- degree cones without saying whether that is the full cone or the half-angle;
-- half-angle is used here because a 5 degree half-angle is very hard to hold
-- with auto-fire. Tune after the first playtest.
Config.Slots = {
	Fixed = { arc = 10, damageScale = 1.0 },
	Gimbal = { arc = 30, damageScale = 0.9 }, -- "a bit less damage" (placeholder 10%)
	Turret = { arc = 85, damageScale = 1.0 }, -- "most of a half sphere"
}

--------------------------------------------------------------------------------
-- Weapons (weapons-and-damage.md, Mk I)
--------------------------------------------------------------------------------

-- Tracking speeds in degrees per second that the target may cross the gun's
-- view before shots start missing (placeholder values for the doc's words).
Config.Tracking = {
	VerySlow = 8,
	Slow = 15,
	Medium = 25,
	Fast = 40,
	VeryFast = 80,
}

-- dps is damage per second at full fire rate; interval is seconds between
-- shots, so damage per shot is dps * interval.
-- Energy: optimal is where full damage ends, falling to 50% at range.
-- Kinetic: flat damage to range. Ammo is ammoSeconds of fire or ammoShots,
-- carried in a magazine module the ship gets for each Kinetic gun.
-- size feeds the hit-chance size ratio (big guns miss small ships).
-- mountsOn lists the slot types a weapon fits; default is { "Fixed", "Gimbal" }.
-- Small guns fit Small mounts and medium guns fit Medium mounts (ShipBuilder).
Config.Weapons = {
	-- Small fixed or gimbal
	PulseBlaster = {
		displayName = "Pulse Blaster",
		class = "Energy",
		size = "Small",
		dps = 20,
		interval = 0.25,
		optimal = 150,
		range = 300,
		tracking = "Fast",
		powerDraw = 60,
	},
	Autocannon = {
		displayName = "Autocannon",
		class = "Kinetic",
		size = "Small",
		dps = 12,
		interval = 0.2,
		range = 700,
		tracking = "Fast",
		ammoSeconds = 90,
	},

	-- Medium fixed (Frigate)
	PlasmaCannon = {
		displayName = "Plasma Cannon",
		class = "Energy",
		size = "Medium",
		dps = 45,
		interval = 1.5, -- 68 per bolt
		optimal = 250,
		range = 500,
		tracking = "Slow",
		powerDraw = 120,
	},
	Railgun = {
		displayName = "Railgun",
		class = "Kinetic",
		size = "Medium",
		dps = 30,
		interval = 4, -- 120 per shot
		range = 1800,
		tracking = "VerySlow",
		ammoShots = 20,
	},

	-- Turrets
	BeamTurret = {
		displayName = "Beam Turret",
		class = "Energy",
		size = "Medium",
		mountsOn = { "Turret" },
		dps = 30,
		interval = 0.2,
		optimal = 200,
		range = 400,
		tracking = "Medium",
		powerDraw = 90,
		overheatAfter = 8, -- seconds of continuous fire
		cooldown = 4, -- seconds locked out once overheated (placeholder)
	},
	FlakTurret = {
		displayName = "Flak Turret",
		class = "Kinetic",
		size = "Small", -- "good against small ships", so no size penalty
		mountsOn = { "Turret" },
		dps = 18,
		interval = 0.15,
		range = 800,
		tracking = "Fast",
		ammoSeconds = 90,
	},
	PointDefense = {
		displayName = "Point Defense",
		class = "Kinetic",
		size = "Small",
		mountsOn = { "Turret" },
		antiMissile = true, -- never shoots ships, only missiles and torpedoes
		dps = 0,
		interval = 0.1,
		range = 300,
		tracking = "VeryFast",
		missileHitChance = 0.12, -- per shot (placeholder)
	},

	-- Missile racks: pilot-fired with the Missile button, limited ammo,
	-- can be shot down by point defense.
	PlasmaTorpedo = {
		displayName = "Plasma Torpedo",
		class = "Energy",
		size = "Small",
		mountsOn = { "MissileRack" },
		damage = 400,
		count = 4,
		range = 600,
		speed = 200, -- studs per second (placeholder)
		turnRate = 120, -- homing, degrees per second (placeholder)
		rechargeTime = 20, -- seconds per torpedo, slower when plasma fire rate is below 100%
	},
	HullCracker = {
		displayName = "Hull-Cracker Missile",
		class = "Kinetic",
		size = "Small",
		mountsOn = { "MissileRack" },
		damage = 250,
		count = 4,
		range = 1200,
		speed = 280, -- placeholder
		turnRate = 150, -- placeholder
		moduleMultiplier = 2,
	},
}

Config.TierMultiplier = { 1.0, 1.35, 1.8, 2.4 } -- Mk I to Mk IV damage

--------------------------------------------------------------------------------
-- Damage pipeline (weapons-and-damage.md, "Damage pipeline")
--------------------------------------------------------------------------------

Config.Combat = {
	baseAccuracy = 0.85,
	energyFalloffAtMax = 0.5, -- Energy does 50% at max range

	-- Kinetic damage that passes a raised shield. The docs say "a 20% reduction";
	-- what exactly that means is still an open question, so it is one number here.
	kineticShieldPassThrough = 0.8,

	kineticModuleMultiplier = 1.5,
	energyModuleMultiplier = 1.0,
}

Config.Defense = {
	shieldRechargeDelay = 4, -- seconds without Energy damage before the shield recharges
	shieldRechargeFraction = 0.1, -- share of max shield regained per second (placeholder)

	armorReductionPerPlate = 0.125,
	armorReductionCap = 0.5,
	armorHPPerPlate = { Small = 200, Medium = 300, Large = 400, Capital = 400 }, -- Capital not in the docs

	magazineCookoffDamage = 150, -- to the hull and to one other module
}

--------------------------------------------------------------------------------
-- Modules
--------------------------------------------------------------------------------

-- Module HP by hull size. The docs give the shield generator; the rest
-- "scale similarly" and the cockpit has double.
Config.ModuleHP = {
	ShieldGenerator = { Small = 150, Medium = 250, Large = 400, Capital = 800 },
	Engine = { Small = 150, Medium = 250, Large = 400, Capital = 800 },
	Weapon = { Small = 120, Medium = 200, Large = 320, Capital = 640 },
	Magazine = { Small = 120, Medium = 200, Large = 320, Capital = 640 },
	Cockpit = { Small = 300, Medium = 500, Large = 800, Capital = 1600 },
}

-- Shield generators: pool size is the "typical fit" shield from ship-types.md.
Config.ShieldGenerators = {
	ShieldS_Scout = { size = "Small", shieldHP = 400 },
	ShieldS_Fighter = { size = "Small", shieldHP = 800 },
	Shield_Hauler = { size = "Medium", shieldHP = 1200 },
	Shield_Frigate = { size = "Large", shieldHP = 3000 },
	Shield_Industrial = { size = "Large", shieldHP = 2500 },
	Shield_Carrier = { size = "Capital", shieldHP = 8000 },
}

-- Engines: output is power units for plasma fire rate.
-- Mk I Standard output by mount size (ship-types.md, "Engine output").
Config.Engines = {
	StandardS = { size = "Small", output = 100 },
	StandardM = { size = "Medium", output = 200 },
	StandardL = { size = "Large", output = 350 },
	StandardC = { size = "Capital", output = 600 },
}

--------------------------------------------------------------------------------
-- Loadouts used in the test system
--------------------------------------------------------------------------------

-- guns map to the hull's weapon mounts in order (see ShipBuilder).
-- missile is { weapon, tier } for hulls with a missile rack.
-- Kinetic guns get one magazine module each unless magazineFor lists, per
-- magazine cell, which gun index it feeds.
-- Player<Hull> stock loadouts for every class are added from ShipClasses below.
Config.Loadouts = {
	DroneScout = {
		hull = "Scout",
		displayName = "Pirate Drone",
		guns = {
			{ weapon = "PulseBlaster", slot = "Gimbal", tier = 1 },
		},
		shield = "ShieldS_Scout",
		engines = { "StandardS", "StandardS" },
		armorPlates = 0,
		magazineFor = {},
		color = Color3.fromRGB(200, 70, 60),
	},

	DroneArmored = {
		hull = "Fighter",
		displayName = "Armored Drone",
		guns = {
			{ weapon = "Autocannon", slot = "Gimbal", tier = 1 },
		},
		shield = "ShieldS_Fighter",
		engines = { "StandardS", "StandardS" },
		armorPlates = 2,
		magazineFor = { 1 },
		color = Color3.fromRGB(200, 140, 50),
	},

	-- Do not move or shoot; for checking damage numbers.
	FrigateDummy = {
		hull = "Frigate",
		displayName = "Frigate Hulk",
		guns = {},
		shield = "Shield_Frigate",
		engines = { "StandardL", "StandardL", "StandardL", "StandardL" },
		armorPlates = 0,
		magazineFor = {},
		color = Color3.fromRGB(110, 110, 110),
	},

	TargetDummy = {
		hull = "Fighter",
		displayName = "Target Dummy",
		guns = {},
		shield = "ShieldS_Fighter",
		engines = { "StandardS", "StandardS" },
		armorPlates = 0,
		magazineFor = {},
		color = Color3.fromRGB(150, 150, 150),
	},
}

for _, hullName in ShipClasses.order do
	Config.Loadouts["Player" .. hullName] = ShipClasses.stockLoadout(hullName)
end

--------------------------------------------------------------------------------
-- Test system
--------------------------------------------------------------------------------

Config.TestSystem = {
	seed = 42,
	asteroidCount = 70,
	asteroidFieldRadius = 1400,
	asteroidSize = { 20, 90 },
	playerSpawn = Vector3.new(0, 0, 600),
	playerHull = "Fighter", -- what a new player spawns in until they pick another
	respawnDelay = 5,

	-- Drones: loadout, where they start, and how they behave.
	drones = {
		{ loadout = "TargetDummy", position = Vector3.new(0, 0, 350), ai = "Idle" },
		{ loadout = "DroneScout", position = Vector3.new(300, 80, -200), ai = "Hunt" },
		{ loadout = "DroneScout", position = Vector3.new(-350, -60, -300), ai = "Hunt" },
		{ loadout = "DroneArmored", position = Vector3.new(0, 150, -700), ai = "Hunt" },
		{ loadout = "FrigateDummy", position = Vector3.new(-500, 40, 450), ai = "Idle" },
	},

	droneAggroRange = 700, -- spawn is just outside this, so you get a moment before drones engage
	droneOrbitDistance = 220, -- inside Pulse Blaster range so they actually shoot back
	droneSpeedScale = 0.7, -- drones fly slower than the hull's top speed so they're beatable
	droneDamageScale = 0.5, -- drones hit half as hard as players for now
}

--------------------------------------------------------------------------------
-- Menus
--------------------------------------------------------------------------------

Config.Menus = {
	gameTitle = "OUTER REACH", -- working title; the design doc's shortlist is still open
	buildLabel = "Prototype build",

	-- Seconds after taking damage before a pilot may dock back to the Hangar,
	-- so the menu can't be used to escape a fight (placeholder).
	hangarCombatLockout = 10,
	spawnRequestCooldown = 1, -- seconds between spawn requests from one player
}

return Config
