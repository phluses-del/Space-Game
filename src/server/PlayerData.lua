--[[
	Saves each player's profile (Credits, owned hulls, items and cosmetics,
	and saved loadouts) with DataStoreService.

	A profile is session-locked: the server that loads it writes its JobId
	into the record, and another server won't load it until that lock is
	released on leave or goes stale. That stops the classic Roblox
	duplication bug where a player hops servers before the old one saved.

	Saves happen at checkpoints (loadout saved, purchase, leaving) and on a
	slow autosave, never every frame, to stay inside DataStore budgets.

	In Studio without "Enable Studio Access to API Services", or if Roblox's
	DataStores are down, the player gets a fresh profile that is not saved,
	and the server says so in the output.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Outfitting = require(ReplicatedStorage.Shared.Outfitting)

local PlayerData = {}

local STORE_NAME = "PlayerProfiles_v1"
local SCHEMA_VERSION = 1
local AUTOSAVE_INTERVAL = 180 -- seconds; also refreshes the session lock
local LOCK_STALE_AFTER = 600 -- a lock this old belongs to a crashed server
local LOAD_ATTEMPTS = 6
local LOAD_RETRY_DELAY = 5

local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStores unavailable, progress will not be saved: " .. tostring(result))
	end
end

local profiles = {} -- [Player] = { data, persistent, dirty, loaded }
local loadedCallbacks = {}
local changedCallbacks = {}

--------------------------------------------------------------------------------
-- Defaults and migration
--------------------------------------------------------------------------------

-- Adds a hull and its stock fit's items to a profile.
local function grantHull(data, hull)
	if data.hulls[hull] then
		return
	end
	data.hulls[hull] = true
	if Outfitting.Hulls[hull] then
		local stock = Outfitting.stockDesign(hull)
		for key, count in Outfitting.itemsUsed(stock) do
			data.items[key] = (data.items[key] or 0) + count
		end
	end
end
PlayerData.grantHull = grantHull

local function newProfile()
	local data = {
		version = SCHEMA_VERSION,
		credits = Outfitting.Settings.startingCredits,
		hulls = {},
		items = {},
		cosmetics = {},
		loadouts = {}, -- list of designs (see Outfitting)
		active = {}, -- [hull] = design id that hull launches with
		lastHull = Outfitting.Settings.starterHulls[1],
		nextId = 1,
		createdAt = os.time(),
	}
	for _, hull in Outfitting.Settings.starterHulls do
		grantHull(data, hull)
	end
	return data
end

-- Brings old or damaged save data up to the current shape. Loadouts are
-- re-sanitized so balance changes (a removed weapon, fewer slots) degrade
-- to empty slots instead of breaking the save.
local function reconcile(data)
	if type(data) ~= "table" then
		return newProfile()
	end
	local fresh = newProfile()
	for key, value in fresh do
		if type(data[key]) ~= type(value) then
			data[key] = value
		end
	end

	local loadouts = {}
	local seen = {}
	for _, raw in data.loadouts do
		local design = Outfitting.sanitize(raw)
		if design and design.id ~= "" and not seen[design.id] then
			seen[design.id] = true
			table.insert(loadouts, design)
		end
	end
	data.loadouts = loadouts

	for hull, id in data.active do
		if not seen[id] then
			data.active[hull] = nil
		end
	end
	for key, count in data.items do
		if type(key) ~= "string" or type(count) ~= "number" or count <= 0 then
			data.items[key] = nil
		end
	end
	data.version = SCHEMA_VERSION
	return data
end

--------------------------------------------------------------------------------
-- DataStore access
--------------------------------------------------------------------------------

local function keyFor(player)
	return "Player_" .. player.UserId
end

local function isLockedElsewhere(record)
	local lock = type(record) == "table" and record.lock
	return type(lock) == "table" and lock.job ~= jobId and os.time() - (lock.at or 0) < LOCK_STALE_AFTER
end

-- Returns data, persistent. persistent = false means "don't save this".
local function loadRecord(player)
	if not store then
		return newProfile(), false
	end
	for attempt = 1, LOAD_ATTEMPTS do
		local locked = false
		local ok, result = pcall(function()
			return store:UpdateAsync(keyFor(player), function(record)
				if isLockedElsewhere(record) then
					locked = true
					return nil -- leave it alone
				end
				record = if type(record) == "table" then record else { data = newProfile() }
				record.lock = { job = jobId, at = os.time() }
				return record
			end)
		end)
		if not player.Parent then
			return nil, false
		end
		if ok and not locked and type(result) == "table" then
			return reconcile(result.data), true
		elseif not ok then
			local message = tostring(result)
			if string.find(message, "Studio", 1, true) or string.find(message, "API", 1, true) then
				warn("[PlayerData] Studio has no DataStore access; " .. player.Name .. "'s progress won't save")
				return newProfile(), false
			end
			warn(string.format("[PlayerData] Load attempt %d for %s failed: %s", attempt, player.Name, message))
		end
		task.wait(LOAD_RETRY_DELAY)
	end
	return nil, false
end

local function writeRecord(player, profile, release)
	if not (store and profile.persistent) then
		return true
	end
	local lost = false
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function(record)
			if isLockedElsewhere(record) then
				lost = true
				return nil
			end
			return {
				data = profile.data,
				lock = if release then nil else { job = jobId, at = os.time() },
				savedAt = os.time(),
			}
		end)
	end)
	if not ok then
		warn("[PlayerData] Save failed for " .. player.Name .. ": " .. tostring(err))
		return false
	end
	if lost then
		-- Another server took over the profile; never overwrite its newer data.
		warn("[PlayerData] " .. player.Name .. "'s profile is open in another server; not saving here")
		profile.persistent = false
		return false
	end
	profile.dirty = false
	return true
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function PlayerData.get(player: Player)
	local profile = profiles[player]
	return if profile and profile.loaded then profile.data else nil
end

function PlayerData.isPersistent(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.persistent
end

-- Yields until the player's profile is loaded. Returns nil if they left or
-- loading failed.
function PlayerData.waitFor(player: Player)
	while player.Parent do
		local profile = profiles[player]
		if profile and profile.loaded then
			return profile.data
		elseif profile and profile.failed then
			return nil
		end
		task.wait(0.1)
	end
	return nil
end

function PlayerData.onLoaded(callback)
	table.insert(loadedCallbacks, callback)
end

function PlayerData.onChanged(callback)
	table.insert(changedCallbacks, callback)
end

-- Call after changing a profile. save = true writes it now (a checkpoint).
function PlayerData.changed(player: Player, save: boolean?)
	local profile = profiles[player]
	if not (profile and profile.loaded) then
		return
	end
	profile.dirty = true
	for _, callback in changedCallbacks do
		task.spawn(callback, player, profile.data)
	end
	if save and not profile.saving then
		profile.saving = true
		task.spawn(function()
			writeRecord(player, profile, false)
			profile.saving = false
		end)
	end
end

local function onPlayerAdded(player: Player)
	local profile = { loaded = false, persistent = false, dirty = false }
	profiles[player] = profile

	local data, persistent = loadRecord(player)
	if not player.Parent then
		if data and persistent then
			-- They left while loading: release the lock we just took.
			profile.data, profile.persistent = data, true
			writeRecord(player, profile, true)
		end
		profiles[player] = nil
		return
	end
	if not data then
		profile.failed = true
		player:Kick("Your ship data is still open in another server. Please rejoin in a minute.")
		return
	end

	if Outfitting.Settings.freeMode then
		for _, hull in Outfitting.availableHulls() do
			grantHull(data, hull)
		end
	end

	profile.data = data
	profile.persistent = persistent
	profile.loaded = true
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil
	if profile.loaded then
		writeRecord(player, profile, true)
	end
end

function PlayerData.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				if profile.loaded and profile.persistent then
					-- Always write, even when clean, to keep the session lock fresh.
					task.spawn(writeRecord, player, profile, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player, profile in profiles do
			if profile.loaded then
				pending += 1
				task.spawn(function()
					writeRecord(player, profile, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerData
