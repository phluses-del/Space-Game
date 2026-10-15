--[[
	Every balance number for the flight and combat prototype lives here, so a
	playtest change is a one-line edit. Values come from design/ship-types.md
	and design/weapons-and-damage.md; anything marked "placeholder" was not
	given in the docs and is a first guess.
]]

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

-- size feeds the hit-chance size ratio and module HP lookups.
-- turnRate is pitch and yaw in degrees per second; rollRate is placeholder.
-- strafeSpeed and accel are placeholders (studs per second, studs per second squared).
Config.Hulls = {
	Scout = {
		size = "Small",
		hullHP = 700,
		topSpeed = 220,
		strafeSpeed = 140,
		accel = 160,
		turnRate = 90,
		rollRate = 150,
		lockTime = 1.6, -- Scouts lock faster than the 2 s small-ship default
		radius = 6, -- rough size for line-of-sight and effects
	},
	Fighter = {
		size = "Small",
		hullHP = 1400,
		topSpeed = 180,
		strafeSpeed = 120,
		accel = 130,
		turnRate = 80,
		rollRate = 140,
		lockTime = 2,
		radius = 7,
	},
}

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
-- shots (placeholder), so damage per shot is dps * interval.
-- Energy: optimal is where full damage ends, falling to 50% at range.
-- Kinetic: flat damage to range, ammoSeconds of fire per magazine cell.
Config.Weapons = {
	PulseBlaster = {
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
		class = "Kinetic",
		size = "Small",
		dps = 12,
		interval = 0.2,
		range = 700,
		tracking = "Fast",
		magazineCells = 1,
		ammoSeconds = 90,
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
	armorHPPerPlate = { Small = 200, Medium = 300, Large = 400 },

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
	ShieldS_Scout = { shieldHP = 400 },
	ShieldS_Fighter = { shieldHP = 800 },
}

-- Engines: output is power units for plasma fire rate.
Config.Engines = {
	StandardS = { output = 100 },
}

--------------------------------------------------------------------------------
-- Loadouts used in the test system
--------------------------------------------------------------------------------

-- guns map to the hull's weapon mounts in order (see ShipBuilder).
-- magazineFor lists, per magazine cell, which gun index it feeds.
Config.Loadouts = {
	PlayerFighter = {
		hull = "Fighter",
		displayName = "Fighter",
		guns = {
			{ weapon = "PulseBlaster", slot = "Gimbal", tier = 1 },
			{ weapon = "PulseBlaster", slot = "Gimbal", tier = 1 },
			{ weapon = "Autocannon", slot = "Gimbal", tier = 1 },
			{ weapon = "Autocannon", slot = "Gimbal", tier = 1 },
		},
		shield = "ShieldS_Fighter",
		engines = { "StandardS", "StandardS" },
		armorPlates = 0,
		magazineFor = { 3, 4 },
		color = Color3.fromRGB(70, 140, 220),
	},

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

	-- Does not move or shoot; for checking damage numbers.
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

--------------------------------------------------------------------------------
-- Test system
--------------------------------------------------------------------------------

Config.TestSystem = {
	seed = 42,
	asteroidCount = 70,
	asteroidFieldRadius = 1400,
	asteroidSize = { 20, 90 },
	playerSpawn = Vector3.new(0, 0, 600),
	respawnDelay = 5,

	-- Drones: loadout, where they start, and how they behave.
	drones = {
		{ loadout = "TargetDummy", position = Vector3.new(0, 0, 350), ai = "Idle" },
		{ loadout = "DroneScout", position = Vector3.new(300, 80, -200), ai = "Hunt" },
		{ loadout = "DroneScout", position = Vector3.new(-350, -60, -300), ai = "Hunt" },
		{ loadout = "DroneArmored", position = Vector3.new(0, 150, -700), ai = "Hunt" },
	},

	droneAggroRange = 700, -- spawn is just outside this, so you get a moment before drones engage
	droneOrbitDistance = 220, -- inside Pulse Blaster range so they actually shoot back
	droneSpeedScale = 0.7, -- drones fly slower than the hull's top speed so they're beatable
	droneDamageScale = 0.5, -- drones hit half as hard as players for now
}

return Config
