--[[
	Shown when the pilot's ship is destroyed: a countdown while insurance
	rebuilds it (the server's RespawnAt attribute), then Relaunch the same
	ship or go to the Hangar to pick another.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShipCatalog = require(ReplicatedStorage.Shared.ShipCatalog)

local Theme = require(script.Parent.Theme)

local DestroyedScreen = {}

local C = Theme.colors
local player = Players.LocalPlayer
local menus
local frame, countdown, relaunchButton, hangarButton
local requested = false

local function secondsLeft(): number
	return math.max(0, (player:GetAttribute("RespawnAt") or 0) - workspace:GetServerTimeNow())
end

function DestroyedScreen.build(canvas: Frame, Menus)
	menus = Menus
	frame = Theme.screen("Destroyed", canvas)

	Theme.label("SHIP DESTROYED", {
		Font = Theme.fonts.title,
		TextSize = 56,
		TextColor3 = C.danger,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 170),
		Size = UDim2.fromOffset(800, 64),
		TextStrokeTransparency = 0.5,
	}, frame)
	countdown = Theme.label("", {
		TextSize = 20,
		TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 245),
		Size = UDim2.fromOffset(800, 28),
	}, frame)

	local row = Theme.make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 320),
		Size = UDim2.fromOffset(500, 56),
	}, frame)
	local layout = Theme.list(row, 16, true)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	relaunchButton = Theme.button("Relaunch", "primary", function()
		requested = true
		Theme.setEnabled(relaunchButton, false)
		relaunchButton.Text = "Launching..."
		Menus.launch(Menus.selectedShip)
		task.delay(6, function()
			requested = false
		end)
	end, { LayoutOrder = 1, Size = UDim2.fromOffset(240, 56), TextSize = 22 }, row)
	hangarButton = Theme.button("Change ship", "secondary", function()
		Menus.switch("Hangar")
	end, { LayoutOrder = 2, Size = UDim2.fromOffset(200, 56) }, row)

	return frame
end

function DestroyedScreen.open()
	requested = false
	DestroyedScreen.update(0)
	return relaunchButton
end

function DestroyedScreen.onNotice()
	requested = false
end

function DestroyedScreen.update(_dt: number)
	local left = secondsLeft()
	local entry = ShipCatalog.get(menus.selectedShip)
	local shipName = if entry then entry.name else "ship"
	if left > 0 then
		countdown.Text = string.format("Insurance is rebuilding your %s... %d", shipName, math.ceil(left))
	else
		countdown.Text = string.format("Your %s is ready.", shipName)
	end
	if not requested then
		relaunchButton.Text = if left > 0 then string.format("Relaunch (%d)", math.ceil(left)) else "Relaunch"
		Theme.setEnabled(relaunchButton, left <= 0 and ShipCatalog.isAvailable(menus.selectedShip))
	end
end

return DestroyedScreen
