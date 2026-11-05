--[[
	Studio-only: number keys 1 to 6 swap your ship to each class, in
	ShipClasses.order. Talks to src/server/DevShipSwitch.lua. Delete both
	once the hangar menu is merged.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ShipClasses = require(ReplicatedStorage.Shared.ShipClasses)

local DevShipPicker = {}

local KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
}

DevShipPicker.enabled = false

function DevShipPicker.start(onSwitch: ((string) -> ())?)
	if not RunService:IsStudio() then
		return
	end
	local remote = ReplicatedStorage:WaitForChild("DevSwitchShip", 10)
	if not remote then
		return
	end
	DevShipPicker.enabled = true

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local index = table.find(KEYS, input.KeyCode)
		local hullName = index and ShipClasses.order[index]
		if hullName then
			remote:FireServer(hullName)
			if onSwitch then
				onSwitch(hullName)
			end
		end
	end)
end

return DevShipPicker
