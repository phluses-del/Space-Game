--[[
	Studio-only shortcut for trying every ship class before the hangar menu
	lands: press 1 to 6 to swap to Scout, Fighter, Hauler, Frigate, Industrial
	or Carrier (see src/client/DevShipPicker.lua). It makes its own
	RemoteEvent so the whole thing can be deleted in one go once the hangar's
	RequestSpawn is merged.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local DevShipSwitch = {}

local COOLDOWN = 2 -- seconds between swaps, so a held key doesn't spam spawns

function DevShipSwitch.start(switchShip: (Player, string) -> ())
	if not RunService:IsStudio() then
		return
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = "DevSwitchShip"
	remote.Parent = ReplicatedStorage

	local lastSwitch = {}
	remote.OnServerEvent:Connect(function(player, hullName)
		if type(hullName) ~= "string" or not Config.Hulls[hullName] or not Config.Loadouts["Player" .. hullName] then
			return
		end
		local now = os.clock()
		if lastSwitch[player] and now - lastSwitch[player] < COOLDOWN then
			return
		end
		lastSwitch[player] = now
		switchShip(player, hullName)
	end)
end

return DevShipSwitch
