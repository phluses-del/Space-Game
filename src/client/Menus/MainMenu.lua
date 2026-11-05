--[[
	Title screen shown on join: game title, Play (to the Hangar), Settings
	and Controls, over a slow camera orbit of the system.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Theme = require(script.Parent.Theme)

local MainMenu = {}

local C = Theme.colors
local frame, playButton

function MainMenu.build(canvas: Frame, Menus)
	frame = Theme.screen("MainMenu", canvas)

	local column = Theme.make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(70, 0),
		Size = UDim2.new(0, 420, 1, 0),
	}, frame)

	Theme.label(Config.Menus.gameTitle, {
		Font = Theme.fonts.title,
		TextSize = 64,
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 0, 70),
		TextStrokeTransparency = 0.6,
	}, column)
	Theme.make("Frame", {
		BackgroundColor3 = C.highlight,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(2, 196),
		Size = UDim2.fromOffset(120, 4),
	}, column)
	Theme.label("Fly out, mine, fight. Keep what you carry.", {
		TextColor3 = C.dim,
		TextSize = 20,
		Position = UDim2.fromOffset(0, 210),
		Size = UDim2.new(1, 0, 0, 28),
	}, column)

	local buttons = Theme.make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 280),
		Size = UDim2.fromOffset(300, 220),
	}, column)
	Theme.list(buttons, 12)

	playButton = Theme.button("Play", "primary", function()
		Menus.open("Hangar")
	end, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 56), TextSize = 24 }, buttons)
	Theme.button("Settings", "secondary", function()
		Menus.open("Settings")
	end, { LayoutOrder = 2 }, buttons)
	Theme.button("Controls", "secondary", function()
		Menus.open("Controls")
	end, { LayoutOrder = 3 }, buttons)

	Theme.label(Config.Menus.buildLabel, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 70, 1, -20),
		Size = UDim2.fromOffset(400, 20),
		TextSize = 14,
		TextColor3 = C.faint,
	}, frame)

	return frame
end

function MainMenu.open()
	return playButton
end

return MainMenu
