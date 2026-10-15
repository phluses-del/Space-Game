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
	"CombatEffects", -- server -> clients: list of shots this frame, for tracers
	"ShipEvent", -- server -> clients: (kind, ...) shield down, knock-outs, destruction
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
	folder.Parent = ReplicatedStorage
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in NAMES do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
