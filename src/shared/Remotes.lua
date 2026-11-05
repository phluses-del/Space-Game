--[[
	The RemoteEvents client and server talk through. The server creates them;
	clients wait for them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"RequestLock", -- client -> server: (targetModel) start locking a ship
	"ClearLock", -- client -> server: drop the current lock
	"CycleSubsystem", -- client -> server: hull, shield generator, engines, weapons
	"FireMissile", -- client -> server: launch a missile at the locked target
	"CombatEffects", -- server -> clients: list of shots this frame, for tracers
	"ShipEvent", -- server -> clients: (kind, ...) shield down, knock-outs, destruction, missile bursts, notices
	"RequestSpawn", -- client -> server: (shipId) launch from the Hangar or respawn
	"ReturnToHangar", -- client -> server: dock and leave your ship (refused in combat)
	"SaveSettings", -- client -> server: (settings table) save menu settings
	"Notice", -- server -> client: (text) short message for the menus, e.g. why a request was refused
}

-- RemoteFunctions, for requests that need an answer.
local FUNCTION_NAMES = {
	"GetSettings", -- client -> server: returns the player's saved settings
}

local Remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	for _, name in FUNCTION_NAMES do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in NAMES do
		Remotes[name] = folder:WaitForChild(name)
	end
	for _, name in FUNCTION_NAMES do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
