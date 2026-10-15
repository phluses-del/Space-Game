--[[
	Server entry point for the flight and combat prototype: builds the test
	system, spawns drones, gives each player a Fighter, and runs combat.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ships = require(script.Ships)
local Combat = require(script.Combat)
local Drones = require(script.Drones)
local TestSystem = require(script.TestSystem)

workspace.Gravity = 0
TestSystem.build()

for _, spec in Config.TestSystem.drones do
	Drones.spawn(spec)
end

local playerShips = {} -- [Player] = ship

local function spawnPlayer(player: Player)
	if not player.Parent then
		return
	end
	-- Spread pilots out a little so they don't spawn inside each other.
	local offset = Vector3.new((#Players:GetPlayers() - 1) * 25, 0, 0)
	local spawnAt = Config.TestSystem.playerSpawn + offset
	local ship = Ships.spawn("PlayerFighter", CFrame.lookAt(spawnAt, spawnAt + Vector3.new(0, 0, -1)), player)
	playerShips[player] = ship

	local pointer = player:FindFirstChild("Ship") or Instance.new("ObjectValue")
	pointer.Name = "Ship"
	pointer.Value = ship.model
	pointer.Parent = player
	player.ReplicationFocus = ship.root
end

Ships.onDestroyed(function(ship)
	local player = ship.owner
	if player and playerShips[player] == ship then
		playerShips[player] = nil
		task.wait(Config.TestSystem.respawnDelay)
		spawnPlayer(player)
	end
end)

Players.PlayerAdded:Connect(spawnPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(spawnPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	local ship = playerShips[player]
	playerShips[player] = nil
	if ship then
		Ships.destroy(ship)
	end
end)

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
	Ships.update(dt)
	checkSpeeds(dt)
end)
