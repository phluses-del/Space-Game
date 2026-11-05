--[[
	Server entry point for the flight and combat prototype: builds the test
	system, spawns drones, launches each player's chosen ship when they ask
	from the Hangar, and runs combat and missiles.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Outfitting = require(ReplicatedStorage.Shared.Outfitting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ships = require(script.Ships)
local Combat = require(script.Combat)
local Drones = require(script.Drones)
local Missiles = require(script.Missiles)
local DevShipSwitch = require(script.DevShipSwitch)
local TestSystem = require(script.TestSystem)
local PlayerSettings = require(script.PlayerSettings)
local ShipPreviews = require(script.ShipPreviews)
local ShipCatalog = require(ReplicatedStorage.Shared.ShipCatalog)
local PlayerData = require(script.PlayerData)
local Shipyard = require(script.Shipyard)

workspace.Gravity = 0
TestSystem.build()
ShipPreviews.buildAll()
PlayerSettings.start()
PlayerData.start()
Shipyard.start()

for _, spec in Config.TestSystem.drones do
	Drones.spawn(spec)
end

local playerShips = {} -- [Player] = ship
local chosenShip = {} -- [Player] = ShipCatalog id they last launched, used for respawn
local lastSpawnRequest = {} -- [Player] = os.clock() of their last RequestSpawn

-- Players start in the menus with no ship. ShipState tells the client which
-- screen fits: "None" (in the Hangar or main menu), "Flying" or "Destroyed".
-- RespawnAt is the server time when a destroyed pilot may launch again.
local function setShipState(player: Player, state: string)
	player:SetAttribute("ShipState", state)
end

local function setPointer(player: Player, model: Model?)
	local pointer = player:FindFirstChild("Ship") or Instance.new("ObjectValue")
	pointer.Name = "Ship"
	pointer.Value = model
	pointer.Parent = player
end

-- What to spawn when a player launches shipId (a ShipCatalog id, which is
-- the hull name): the active saved loadout for that hull from the shipyard,
-- or the Config loadout for hulls the shipyard doesn't fit yet.
local function resolveLoadout(player: Player, shipId: string)
	local entry = ShipCatalog.get(shipId)
	if Outfitting.hullAvailable(entry.hull) then
		local loadout, note = Shipyard.loadoutFor(player, entry.hull)
		if note then
			Remotes.Notice:FireClient(player, note)
		end
		return loadout
	end
	return entry.loadout
end

local function spawnPlayer(player: Player, shipId: string)
	if not player.Parent then
		return
	end
	local hull = Config.Hulls[ShipCatalog.get(shipId).hull]
	-- Spread pilots out so they don't spawn inside each other; big hulls
	-- start further out to the side.
	local slot = #Players:GetPlayers() - 1
	local offset = Vector3.new(slot * 25 + (if hull.radius > 10 then hull.radius * 2 + 20 else 0), 0, 0)
	local spawnAt = Config.TestSystem.playerSpawn + offset
	local ok, ship = pcall(Ships.spawn, resolveLoadout(player, shipId), CFrame.lookAt(spawnAt, spawnAt + Vector3.new(0, 0, -1)), player)
	if not ok then
		warn(string.format("Could not spawn %s for %s: %s", shipId, player.Name, tostring(ship)))
		Remotes.Notice:FireClient(player, "That ship couldn't launch. Pick another.")
		return
	end
	playerShips[player] = ship
	chosenShip[player] = shipId
	setPointer(player, ship.model)
	player.ReplicationFocus = ship.root
	setShipState(player, "Flying")
end

local function onPlayerAdded(player: Player)
	setPointer(player, nil)
	player:SetAttribute("RespawnAt", 0)
	setShipState(player, "None")
end

Ships.onDestroyed(function(ship)
	local player = ship.owner
	if player and playerShips[player] == ship then
		playerShips[player] = nil
		player:SetAttribute("RespawnAt", workspace:GetServerTimeNow() + Config.TestSystem.respawnDelay)
		setPointer(player, nil)
		setShipState(player, "Destroyed")
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Studio-only 1-6 keys: swap the current ship for another class right away.
-- The Hangar is the real way to change ship.
local function switchShip(player: Player, hullName: string)
	if not ShipCatalog.isAvailable(hullName) or player:GetAttribute("ShipState") == "Destroyed" then
		return
	end
	local ship = playerShips[player]
	playerShips[player] = nil
	if ship then
		Ships.remove(ship)
	end
	spawnPlayer(player, hullName)
end
DevShipSwitch.start(switchShip)

Players.PlayerRemoving:Connect(function(player)
	local ship = playerShips[player]
	playerShips[player] = nil
	chosenShip[player] = nil
	lastSpawnRequest[player] = nil
	if ship then
		Ships.destroy(ship)
	end
end)

-- Launch checks shared by the Hangar's RequestSpawn and the shipyard's
-- Launch button. Returns ok, reason.
local function tryLaunch(player: Player, shipId: any): (boolean, string?)
	if playerShips[player] then
		return false, "You're already flying" -- already flying
	end
	if not (ShipCatalog.isAvailable(shipId) and ShipPreviews.has(shipId)) then
		return false, "That ship isn't available yet."
	end
	local data = PlayerData.waitFor(player)
	if not data then
		return false, "Your profile hasn't loaded yet."
	end
	local hull = ShipCatalog.get(shipId).hull
	if Outfitting.hullAvailable(hull) and not data.hulls[hull] then
		return false, "Buy the " .. hull .. " in the shipyard first."
	end
	if workspace:GetServerTimeNow() < (player:GetAttribute("RespawnAt") or 0) then
		return false, "Your ship is still being rebuilt."
	end
	data.lastHull = hull
	spawnPlayer(player, shipId)
	if not playerShips[player] then
		return false, "That ship couldn't launch."
	end
	return true
end

Remotes.RequestSpawn.OnServerEvent:Connect(function(player, shipId)
	local now = os.clock()
	if now - (lastSpawnRequest[player] or 0) < Config.Menus.spawnRequestCooldown then
		return
	end
	lastSpawnRequest[player] = now

	local ok, reason = tryLaunch(player, shipId)
	if not ok and reason and not playerShips[player] then
		Remotes.Notice:FireClient(player, reason)
	end
end)

-- The shipyard opens from the Hangar, so its Launch button takes the same path.
Shipyard.setLaunchHandler(tryLaunch)

Remotes.ReturnToHangar.OnServerEvent:Connect(function(player)
	local ship = playerShips[player]
	if not ship then
		return
	end
	local sinceHit = workspace:GetServerTimeNow() - (ship.lastDamagedAt or 0)
	if ship.lastDamagedAt and ship.lastDamagedAt > 0 and sinceHit < Config.Menus.hangarCombatLockout then
		Remotes.Notice:FireClient(
			player,
			string.format("Can't dock in combat. Wait %d s without taking damage.", math.ceil(Config.Menus.hangarCombatLockout - sinceHit))
		)
		return
	end
	playerShips[player] = nil
	setPointer(player, nil)
	setShipState(player, "None")
	Ships.remove(ship) -- quiet removal: no explosion, no respawn timer
end)

Remotes.SaveSettings.OnServerEvent:Connect(PlayerSettings.set)
Remotes.GetSettings.OnServerInvoke = PlayerSettings.get

Remotes.RequestLock.OnServerEvent:Connect(function(player, targetModel)
	local ship = playerShips[player]
	local target = typeof(targetModel) == "Instance" and Ships.byModel[targetModel]
	if ship and target then
		Combat.requestLock(ship, target)
	end
end)

Remotes.ClearLock.OnServerEvent:Connect(function(player)
	local ship = playerShips[player]
	if ship then
		Combat.clearLock(ship)
	end
end)

Remotes.FireMissile.OnServerEvent:Connect(function(player)
	local ship = playerShips[player]
	if ship then
		local ok, reason = Missiles.fire(ship)
		if not ok and reason then
			Remotes.ShipEvent:FireClient(player, "Notice", reason)
		end
	end
end)

Remotes.CycleSubsystem.OnServerEvent:Connect(function(player)
	local ship = playerShips[player]
	if ship then
		Combat.cycleSubsystem(ship)
	end
end)

-- Pilots fly their own ships, so check they aren't going impossibly fast.
local speedCheckTimer = 0
local function checkSpeeds(dt)
	speedCheckTimer += dt
	if speedCheckTimer < 1 then
		return
	end
	speedCheckTimer = 0
	for player, ship in playerShips do
		local limit = ship.hull.topSpeed * Config.Flight.boostMultiplier * Config.Flight.speedCheckTolerance
		local speed = ship.root.AssemblyLinearVelocity.Magnitude
		if speed > limit then
			warn(string.format("%s's ship is moving at %.0f studs/s (limit %.0f)", player.Name, speed, limit))
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	Drones.update(dt)
	Combat.update(dt)
	Missiles.update(dt)
	Ships.update(dt)
	checkSpeeds(dt)
end)
