--[[
	One entry per ship class, straight from design/ship-types.md. This is the
	single place to read or tune what a hull is: its flight and health stats,
	what it is for, what it can fit, and its stock loadout.

	Config.Hulls points at ShipClasses.classes, so anything that reads
	Config.Hulls[name].topSpeed keeps working. Stock loadouts are copied into
	Config.Loadouts as "Player" .. name (PlayerScout, PlayerFighter, ...).

	Weapon mount positions and kinds are part of the model, so they live in
	ShipBuilder's layouts; mount i is attachment "Gun" .. i and loadout gun i.

	Anything marked "placeholder" is not in the docs and is a first guess.
]]

local ShipClasses = {}

-- Display and selection order.
ShipClasses.order = { "Scout", "Fighter", "Hauler", "Frigate", "Industrial", "Carrier" }

--[[
	Stat fields read by the game:
	  size          Small | Medium | Large | Capital (hit chance, module HP, armor HP)
	  hullHP        hull structure points
	  topSpeed      studs per second with stock engines
	  strafeSpeed   studs per second sideways and up/down (placeholder from the doc's words)
	  accel         studs per second squared (placeholder)
	  turnRate      pitch and yaw, degrees per second
	  rollRate      degrees per second (placeholder)
	  lockTime      seconds to complete a lock
	  radius        rough size for effects and the chase camera

	Info fields (shown in menus, used by later systems):
	  typicalShield, seats, cargo, hyperdrive, carrierFit, hangarBays,
	  warpDisruptor, miningSlots, refinery, engineMounts, maxModules, unlock
]]
ShipClasses.classes = {
	Scout = {
		displayName = "Scout",
		role = "Explorer",
		blurb = "Fastest hull with the longest-range hyperdrive. Weak in a straight fight; wins by escaping.",
		unlock = "Start",
		size = "Small",

		hullHP = 700,
		typicalShield = 400,
		topSpeed = 220,
		strafeSpeed = 140,
		accel = 160,
		turnRate = 90,
		rollRate = 150,
		lockTime = 1.6, -- Scouts lock faster than the 2 s small-ship default
		radius = 6,

		seats = 1,
		cargo = 10, -- placeholder cargo units
		engineMounts = 2,
		maxModules = 15,
		hyperdrive = { range = 2, spool = 6 },
		carrierFit = true,
		scanBonus = true,

		color = Color3.fromRGB(90, 200, 160),
		stock = {
			guns = {
				{ weapon = "PulseBlaster", slot = "Gimbal", tier = 1 },
				{ weapon = "Autocannon", slot = "Gimbal", tier = 1 },
			},
			shield = "ShieldS_Scout",
			engines = { "StandardS", "StandardS" },
			armorPlates = 0,
		},
	},

	Fighter = {
		displayName = "Fighter",
		role = "Dogfighter",
		blurb = "Most guns for its size plus a torpedo rack. No hyperdrive; travels by gate or carrier.",
		unlock = "Early",
		size = "Small",

		hullHP = 1400,
		typicalShield = 800,
		topSpeed = 180,
		strafeSpeed = 120,
		accel = 130,
		turnRate = 80,
		rollRate = 140,
		lockTime = 2,
		radius = 7,

		seats = 1,
		cargo = 2,
		engineMounts = 2,
		maxModules = 15,
		hyperdrive = nil,
		carrierFit = true,
		warpDisruptor = true,

		color = Color3.fromRGB(70, 140, 220),
		stock = {
			guns = {
				{ weapon = "PulseBlaster", slot = "Gimbal", tier = 1 },
				{ weapon = "PulseBlaster", slot = "Gimbal", tier = 1 },
				{ weapon = "Autocannon", slot = "Gimbal", tier = 1 },
				{ weapon = "Autocannon", slot = "Gimbal", tier = 1 },
			},
			missile = { weapon = "PlasmaTorpedo", tier = 1 },
			shield = "ShieldS_Fighter",
			engines = { "StandardS", "StandardS" },
			armorPlates = 0,
		},
	},

	Hauler = {
		displayName = "Hauler",
		role = "Miner and trader",
		blurb = "Big hold and one automatic point-defense turret. Its short-range hyperdrive is the escape plan.",
		unlock = "Early",
		size = "Medium",

		hullHP = 2600,
		typicalShield = 1200,
		topSpeed = 120,
		strafeSpeed = 50, -- "slow"
		accel = 70,
		turnRate = 40,
		rollRate = 60,
		lockTime = 1.5, -- between the small 2 s and large 1 s (placeholder)
		radius = 12,

		seats = 2,
		cargo = 200,
		engineMounts = 3,
		maxModules = 25,
		miningSlots = 2,
		hyperdrive = { range = 1, spool = 12 },
		carrierFit = false,

		color = Color3.fromRGB(210, 170, 60),
		stock = {
			guns = {
				{ weapon = "PointDefense", slot = "Turret", tier = 1 },
			},
			shield = "Shield_Hauler",
			engines = { "StandardM", "StandardM", "StandardM" },
			armorPlates = 0,
		},
	},

	Frigate = {
		displayName = "Frigate",
		role = "Crew warship",
		blurb = "Two heavy forward guns and four turrets. Beats a lone Fighter; a pack with torpedoes beats it.",
		unlock = "Mid",
		size = "Large",

		hullHP = 6000,
		typicalShield = 3000,
		topSpeed = 110,
		strafeSpeed = 60, -- "medium"
		accel = 50,
		turnRate = 30,
		rollRate = 40,
		lockTime = 1,
		radius = 22,

		seats = 4,
		cargo = 60,
		engineMounts = 4,
		maxModules = 40,
		hyperdrive = { range = 1, spool = 12 },
		carrierFit = false,

		color = Color3.fromRGB(120, 130, 150),
		stock = {
			guns = {
				{ weapon = "PlasmaCannon", slot = "Fixed", tier = 1 },
				{ weapon = "Railgun", slot = "Fixed", tier = 1 },
				{ weapon = "FlakTurret", slot = "Turret", tier = 1 },
				{ weapon = "BeamTurret", slot = "Turret", tier = 1 },
				{ weapon = "FlakTurret", slot = "Turret", tier = 1 },
				{ weapon = "PointDefense", slot = "Turret", tier = 1 },
			},
			shield = "Shield_Frigate",
			engines = { "StandardL", "StandardL", "StandardL", "StandardL" },
			armorPlates = 0,
		},
	},

	Industrial = {
		displayName = "Industrial",
		role = "Bulk miner",
		blurb = "Biggest hold in the game and the only field refinery. Light defenses; needs an escort.",
		unlock = "Mid",
		size = "Large",

		hullHP = 7500,
		typicalShield = 2500,
		topSpeed = 90,
		strafeSpeed = 35, -- "slow"
		accel = 40,
		turnRate = 22,
		rollRate = 30,
		lockTime = 1,
		radius = 24,

		seats = 3,
		cargo = 800,
		engineMounts = 4,
		maxModules = 40,
		miningSlots = 4,
		refinery = true,
		hyperdrive = { range = 1, spool = 12 },
		carrierFit = false,

		color = Color3.fromRGB(200, 110, 50),
		stock = {
			guns = {
				{ weapon = "FlakTurret", slot = "Turret", tier = 1 },
				{ weapon = "PointDefense", slot = "Turret", tier = 1 },
			},
			shield = "Shield_Industrial",
			engines = { "StandardL", "StandardL", "StandardL", "StandardL" },
			armorPlates = 0,
		},
	},

	Carrier = {
		displayName = "Carrier",
		role = "Fleet ship",
		blurb = "Holds four Scouts or Fighters and repairs them while docked. Mostly point defense on its own.",
		unlock = "Late",
		size = "Capital",

		hullHP = 20000,
		typicalShield = 8000,
		topSpeed = 70,
		strafeSpeed = 20, -- "very slow"
		accel = 25,
		turnRate = 12,
		rollRate = 15,
		lockTime = 0.5,
		radius = 45,

		seats = 6,
		cargo = 300,
		engineMounts = 6,
		maxModules = 60,
		hyperdrive = { range = 3, spool = 25, carriesDocked = true },
		carrierFit = false,
		hangarBays = 4,

		color = Color3.fromRGB(80, 90, 120),
		stock = {
			guns = {
				{ weapon = "FlakTurret", slot = "Turret", tier = 1 },
				{ weapon = "FlakTurret", slot = "Turret", tier = 1 },
				{ weapon = "PointDefense", slot = "Turret", tier = 1 },
				{ weapon = "PointDefense", slot = "Turret", tier = 1 },
				{ weapon = "PointDefense", slot = "Turret", tier = 1 },
				{ weapon = "PointDefense", slot = "Turret", tier = 1 },
			},
			shield = "Shield_Carrier",
			engines = { "StandardC", "StandardC", "StandardC", "StandardC", "StandardC", "StandardC" },
			armorPlates = 0,
		},
	},
}

-- A fresh copy of a class's stock loadout, ready for Ships.spawn or for the
-- shipyard to edit.
function ShipClasses.stockLoadout(name: string)
	local class = ShipClasses.classes[name]
	assert(class, "Unknown ship class " .. tostring(name))
	local stock = class.stock
	local guns = {}
	for i, fit in stock.guns do
		guns[i] = table.clone(fit)
	end
	return {
		hull = name,
		displayName = class.displayName,
		guns = guns,
		missile = if stock.missile then table.clone(stock.missile) else nil,
		shield = stock.shield,
		engines = table.clone(stock.engines),
		armorPlates = stock.armorPlates or 0,
		color = class.color,
	}
end

return ShipClasses
