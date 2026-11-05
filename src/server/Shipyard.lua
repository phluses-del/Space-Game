--[[
	Server side of ship customization: answers the shipyard screen's requests
	(save, delete and pick loadouts; buy hulls, items and paint; refit a
	loadout in one click) and turns a player's active loadout into the table
	Ships.spawn takes.

	Every request is re-checked here with Outfitting; the client's copy of
	the rules is only for showing stats and errors.

	Requests come through the ShipyardRequest RemoteFunction as
	(action, payload) and always return { ok = bool, error = string?, ... }.
	After any change the server fires ProfileUpdated with the new profile.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Outfitting = require(ReplicatedStorage.Shared.Outfitting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local Shipyard = {}

local REQUEST_COOLDOWN = 0.15 -- seconds between requests per player
local MAX_BUY_COUNT = 20

local lastRequest = {} -- [Player] = os.clock()
local launchHandler = nil -- function(player, hull) -> ok, error
local combatCheck = nil -- function(player) -> seconds since last damage

local function settings()
	return Outfitting.Settings
end

local function findDesign(data, id)
	for index, design in data.loadouts do
		if design.id == id then
			return design, index
		end
	end
	return nil
end

local function designsForHull(data, hull)
	local count = 0
	for _, design in data.loadouts do
		if design.hull == hull then
			count += 1
		end
	end
	return count
end

local function canAfford(data, cost)
	return settings().freeMode or data.credits >= cost
end

local function spend(data, cost)
	if not settings().freeMode then
		data.credits -= cost
	end
end

-- What the client is sent: the whole profile is small, so send it as is,
-- plus the flags the screen needs.
function Shipyard.summary(player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end
	return {
		credits = data.credits,
		hulls = data.hulls,
		items = data.items,
		cosmetics = data.cosmetics,
		loadouts = data.loadouts,
		active = data.active,
		lastHull = data.lastHull,
		freeMode = settings().freeMode,
		persistent = PlayerData.isPersistent(player),
		loadoutsPerHull = settings().loadoutsPerHull,
	}
end

local function push(player)
	local summary = Shipyard.summary(player)
	if summary then
		Remotes.ProfileUpdated:FireClient(player, summary)
	end
end

-- The design a hull launches with: the player's active saved loadout, or the
-- stock fit when they haven't saved one.
function Shipyard.activeDesign(player, hull)
	local data = PlayerData.get(player)
	if data then
		local design = findDesign(data, data.active[hull])
		if design then
			return design
		end
	end
	return Outfitting.stockDesign(hull)
end

--[[
	The Ships.spawn loadout table for a player's ship. hull defaults to the
	last hull they picked. Returns loadout, note. If the saved loadout can't
	launch (missing items or broken by a balance change), the stock fit is
	used instead and note says why.
]]
function Shipyard.loadoutFor(player, hull: string?)
	local data = PlayerData.get(player)
	hull = hull or (data and data.lastHull) or settings().starterHulls[1]
	if not Outfitting.hullAvailable(hull) then
		hull = settings().starterHulls[1]
	end

	local design = Shipyard.activeDesign(player, hull)
	local note = nil
	if data then
		local problems = Outfitting.problems(design)
		local missing = Outfitting.missingItems(design, data.items)
		if not settings().freeMode and next(missing) ~= nil then
			note = "Your " .. design.name .. " loadout is missing parts, so you launched with the stock fit"
			design = Outfitting.stockDesign(hull)
		elseif #problems > 0 then
			note = "Your " .. design.name .. " loadout can't fly (" .. problems[1] .. "), so you launched with the stock fit"
			design = Outfitting.stockDesign(hull)
		end
	end
	return Outfitting.toSpawnLoadout(design, player.DisplayName), note
end

-- init.server.lua decides how a ship is (re)spawned; the shipyard just asks.
function Shipyard.setLaunchHandler(handler)
	launchHandler = handler
end

-- Returns seconds since the player's ship last took damage (math.huge if none).
function Shipyard.setCombatCheck(check)
	combatCheck = check
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

local actions = {}

-- Returns the profile both as result.profile and spread at the top level,
-- so callers can read result.hulls directly.
function actions.GetProfile(player, data)
	local result = Shipyard.summary(player) or {}
	result.ok = true
	return result
end

-- payload: a design. A new design has id "" or nil. Returns the saved id.
function actions.SaveDesign(player, data, payload)
	local design, err = Outfitting.sanitize(payload)
	if not design then
		return { ok = false, error = err }
	end
	if not data.hulls[design.hull] then
		return { ok = false, error = "You don't own this hull" }
	end

	local existing, index = findDesign(data, design.id)
	if existing and existing.hull ~= design.hull then
		existing = nil
	end
	if not existing then
		if designsForHull(data, design.hull) >= settings().loadoutsPerHull then
			return { ok = false, error = "All " .. settings().loadoutsPerHull .. " loadout slots for this hull are full" }
		end
		design.id = "L" .. data.nextId
		data.nextId += 1
		table.insert(data.loadouts, design)
	else
		data.loadouts[index] = design
	end
	-- A hull's first saved loadout becomes the one it launches with.
	if not data.active[design.hull] then
		data.active[design.hull] = design.id
	end
	PlayerData.changed(player, true)
	return { ok = true, id = design.id }
end

function actions.DeleteDesign(player, data, payload)
	local design, index = findDesign(data, payload)
	if not design then
		return { ok = false, error = "No such loadout" }
	end
	table.remove(data.loadouts, index)
	if data.active[design.hull] == design.id then
		data.active[design.hull] = nil
		for _, other in data.loadouts do
			if other.hull == design.hull then
				data.active[design.hull] = other.id
				break
			end
		end
	end
	PlayerData.changed(player, true)
	return { ok = true }
end

-- payload: design id. Makes it the loadout its hull launches with.
function actions.SetActive(player, data, payload)
	local design = findDesign(data, payload)
	if not design then
		return { ok = false, error = "No such loadout" }
	end
	data.active[design.hull] = design.id
	data.lastHull = design.hull
	PlayerData.changed(player, true)
	return { ok = true }
end

-- payload: hull name. Picks which hull to fly next without changing loadouts.
function actions.SelectHull(player, data, payload)
	if type(payload) ~= "string" or not data.hulls[payload] or not Outfitting.hullAvailable(payload) then
		return { ok = false, error = "You don't own this hull" }
	end
	data.lastHull = payload
	PlayerData.changed(player, false)
	return { ok = true }
end

-- payload: hull name. Comes with its stock fit.
function actions.BuyHull(player, data, payload)
	local def = type(payload) == "string" and Outfitting.Hulls[payload]
	if not def or not Outfitting.hullAvailable(payload) then
		return { ok = false, error = "That hull isn't for sale yet" }
	end
	if data.hulls[payload] then
		return { ok = false, error = "You already own this hull" }
	end
	if not canAfford(data, def.price) then
		return { ok = false, error = "Not enough Credits" }
	end
	spend(data, def.price)
	PlayerData.grantHull(data, payload)
	PlayerData.changed(player, true)
	return { ok = true }
end

-- payload: { id, size, tier, count }
function actions.BuyItem(player, data, payload)
	if type(payload) ~= "table" then
		return { ok = false, error = "Bad request" }
	end
	local id, size, tier = payload.id, payload.size, payload.tier
	local count = if type(payload.count) == "number" then math.floor(payload.count) else 1
	if type(id) ~= "string" or type(size) ~= "string" or type(tier) ~= "number" then
		return { ok = false, error = "Bad request" }
	end
	if count < 1 or count > MAX_BUY_COUNT or not Outfitting.isBuyable(id, size, tier) then
		return { ok = false, error = "That item isn't for sale" }
	end
	local cost = Outfitting.price(id, size, tier) * count
	if not canAfford(data, cost) then
		return { ok = false, error = "Not enough Credits" }
	end
	spend(data, cost)
	local key = Outfitting.key(id, size, tier)
	data.items[key] = (data.items[key] or 0) + count
	PlayerData.changed(player, true)
	return { ok = true }
end

-- payload: { slot, id }
function actions.BuyCosmetic(player, data, payload)
	if type(payload) ~= "table" or type(payload.slot) ~= "string" or type(payload.id) ~= "string" then
		return { ok = false, error = "Bad request" }
	end
	local entry = Outfitting.cosmetic(payload.slot, payload.id)
	if not entry then
		return { ok = false, error = "That cosmetic isn't for sale" }
	end
	local key = Outfitting.cosmeticKey(payload.slot, payload.id)
	if entry.price <= 0 or data.cosmetics[key] then
		return { ok = false, error = "You already own this" }
	end
	if not canAfford(data, entry.price) then
		return { ok = false, error = "Not enough Credits" }
	end
	spend(data, entry.price)
	data.cosmetics[key] = true
	PlayerData.changed(player, true)
	return { ok = true }
end

-- payload: design (saved or unsaved). Buys every missing part and cosmetic
-- in one go, or nothing if the player can't afford all of it.
function actions.Refit(player, data, payload)
	local design, err = Outfitting.sanitize(payload)
	if not design then
		return { ok = false, error = err }
	end
	if not data.hulls[design.hull] then
		return { ok = false, error = "You don't own this hull" }
	end
	local missing, itemCost = Outfitting.missingItems(design, data.items)
	local missingCosmetics, cosmeticCost = Outfitting.missingCosmetics(design, data.cosmetics)
	local cost = itemCost + cosmeticCost
	if cost == 0 then
		return { ok = true, cost = 0 }
	end
	if not canAfford(data, cost) then
		return { ok = false, error = string.format("Refit costs %d Credits", cost) }
	end
	spend(data, cost)
	for key, count in missing do
		data.items[key] = (data.items[key] or 0) + count
	end
	for key in missingCosmetics do
		data.cosmetics[key] = true
	end
	PlayerData.changed(player, true)
	return { ok = true, cost = cost }
end

-- payload: hull name (optional). Respawns the player's ship with that hull's
-- active loadout. Blocked during combat.
function actions.Launch(player, data, payload)
	local hull = if type(payload) == "string" then payload else data.lastHull
	if not data.hulls[hull] or not Outfitting.hullAvailable(hull) then
		return { ok = false, error = "You don't own this hull" }
	end
	if combatCheck then
		local since = combatCheck(player)
		if since < settings().swapCombatLockout then
			return {
				ok = false,
				error = string.format("In combat: wait %d s to change ship", math.ceil(settings().swapCombatLockout - since)),
			}
		end
	end
	if not launchHandler then
		return { ok = false, error = "Launching isn't set up on this server" }
	end
	data.lastHull = hull
	PlayerData.changed(player, false)
	local ok, launchError = launchHandler(player, hull)
	return { ok = ok ~= false, error = launchError }
end

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------

function Shipyard.start()
	Remotes.ShipyardRequest.OnServerInvoke = function(player, action, payload)
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
			return { ok = false, error = "Slow down" }
		end
		lastRequest[player] = now

		local handler = type(action) == "string" and actions[action]
		if not handler then
			return { ok = false, error = "Unknown request" }
		end
		local data = PlayerData.waitFor(player)
		if not data then
			return { ok = false, error = "Your profile hasn't loaded" }
		end

		local ok, result = pcall(handler, player, data, payload)
		if not ok then
			warn("[Shipyard] " .. action .. " failed for " .. player.Name .. ": " .. tostring(result))
			return { ok = false, error = "Something went wrong" }
		end
		result.profile = Shipyard.summary(player)
		return result
	end

	PlayerData.onChanged(push)
	PlayerData.onLoaded(push)

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return Shipyard
