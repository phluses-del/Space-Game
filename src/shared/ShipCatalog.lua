--[[
	The ships a pilot can pick in the Hangar, one entry per class in
	Shared/ShipClasses (in ShipClasses.order). Names, roles, blurbs and
	unlock stages come from there, so the menu stays in step with the
	ship classes. The menus read this list; the server checks it before
	spawning.

	An entry is launchable once its hull is in Config.Hulls and its player
	loadout ("Player" .. hull) is in Config.Loadouts. Until then the Hangar
	shows it as "Coming soon".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ShipClasses = require(ReplicatedStorage.Shared.ShipClasses)

local ShipCatalog = {}

ShipCatalog.entries = {}
ShipCatalog.byId = {}

for index, hullName in ShipClasses.order do
	local class = ShipClasses.classes[hullName]
	local entry = {
		id = hullName,
		hull = hullName,
		loadout = "Player" .. hullName,
		order = index,
		name = class.displayName or hullName,
		size = class.size,
		role = class.role or "",
		blurb = class.blurb or "",
		unlock = class.unlock or "Start",
	}
	table.insert(ShipCatalog.entries, entry)
	ShipCatalog.byId[entry.id] = entry
end

ShipCatalog.defaultId = Config.TestSystem.playerHull or "Fighter"

function ShipCatalog.get(id: any)
	return if type(id) == "string" then ShipCatalog.byId[id] else nil
end

-- True when Config has what it takes to spawn this ship.
function ShipCatalog.isAvailable(id: any): boolean
	local entry = ShipCatalog.get(id)
	return entry ~= nil and Config.Hulls[entry.hull] ~= nil and Config.Loadouts[entry.loadout] ~= nil
end

-- Numbers for the Hangar's stat panel, all read from Config.
function ShipCatalog.stats(id: any)
	local entry = ShipCatalog.get(id)
	local hull = entry and Config.Hulls[entry.hull]
	local loadout = entry and Config.Loadouts[entry.loadout]
	if not (hull and loadout) then
		return nil
	end

	local plates = loadout.armorPlates or 0
	local plateHP = Config.Defense.armorHPPerPlate[hull.size] or 0
	local generator = loadout.shield and Config.ShieldGenerators[loadout.shield]

	local guns = {}
	for _, gun in loadout.guns or {} do
		table.insert(guns, gun)
	end

	return {
		hullHP = hull.hullHP + plates * plateHP,
		shieldHP = if generator then generator.shieldHP else 0,
		topSpeed = hull.topSpeed,
		turnRate = hull.turnRate,
		lockTime = hull.lockTime,
		armorPlates = plates,
		engines = #(loadout.engines or {}),
		guns = guns,
		missile = loadout.missile, -- { weapon, tier } or nil
		color = loadout.color,
	}
end

return ShipCatalog
