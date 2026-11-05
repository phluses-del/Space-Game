--[[
	Loads and saves each player's menu settings (Shared/Settings) in a
	DataStore. Saves are batched: a change marks the player dirty and the
	save happens at most every SAVE_INTERVAL seconds, and when they leave.

	In Studio without "Enable Studio Access to API Services", DataStore calls
	fail; settings then live only for the session and a warning is printed
	once.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)

local PlayerSettings = {}

local STORE_NAME = "PlayerSettings_v1"
local SAVE_INTERVAL = 30

local store = nil
local storeOk, storeResult = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)
if storeOk then
	store = storeResult
end

local values = {} -- [Player] = settings table
local loaded = {} -- [Player] = true once the load finished (even if it failed)
local dirty = {} -- [Player] = true when there is something to save
local warned = false

local function warnOnce(message)
	if not warned then
		warned = true
		warn("[PlayerSettings] " .. message .. " Settings will not be saved this session.")
	end
end

local function key(player: Player)
	return "settings_" .. player.UserId
end

local function load(player: Player)
	local data = nil
	if store then
		local ok, result = pcall(function()
			return store:GetAsync(key(player))
		end)
		if ok then
			data = result
		else
			warnOnce(tostring(result))
		end
	else
		warnOnce("No DataStore.")
	end
	if player.Parent then
		values[player] = Settings.sanitize(data)
		loaded[player] = true
	end
end

local function save(player: Player)
	if not dirty[player] or not values[player] or not store then
		return
	end
	dirty[player] = nil
	local data = values[player]
	local ok, result = pcall(function()
		store:SetAsync(key(player), data, { player.UserId })
	end)
	if not ok then
		warnOnce(tostring(result))
	end
end

-- Waits for the player's settings to load and returns them.
function PlayerSettings.get(player: Player)
	local started = os.clock()
	while not loaded[player] and player.Parent and os.clock() - started < 10 do
		task.wait(0.1)
	end
	return values[player] or Settings.defaults()
end

function PlayerSettings.set(player: Player, input: any)
	if not loaded[player] then
		return
	end
	values[player] = Settings.sanitize(input)
	dirty[player] = true
end

function PlayerSettings.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		values[player] = nil
		loaded[player] = nil
		dirty[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(SAVE_INTERVAL)
			for player in dirty do
				task.spawn(save, player)
			end
		end
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)
end

return PlayerSettings
