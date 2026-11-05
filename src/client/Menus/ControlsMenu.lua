--[[
	Controls reference for PC, gamepad and touch. Keep this in step with
	client/Input.lua when bindings change.
]]

local Theme = require(script.Parent.Theme)

local ControlsMenu = {}

local C = Theme.colors
local frame, backButton

local COLUMNS = {
	{
		title = "Keyboard and mouse",
		rows = {
			{ "Steer", "Move mouse from centre" },
			{ "Thrust", "W / S" },
			{ "Strafe", "A / D" },
			{ "Up / down", "Space / Ctrl" },
			{ "Roll", "Q / E" },
			{ "Boost", "Shift" },
			{ "Lock target ahead", "T" },
			{ "Next target", "Tab" },
			{ "Aim at part", "G" },
			{ "Drop lock", "X" },
			{ "Fire missile", "R" },
			{ "Flight assist", "F" },
			{ "Menu", "P or M" },
		},
	},
	{
		title = "Gamepad",
		rows = {
			{ "Thrust and strafe", "Left stick" },
			{ "Steer", "Right stick" },
			{ "Roll", "LB / RB" },
			{ "Down / up", "LT / RT" },
			{ "Boost", "B" },
			{ "Lock target", "Y" },
			{ "Next target", "D-pad right" },
			{ "Aim at part", "X" },
			{ "Drop lock", "D-pad down" },
			{ "Fire missile", "A" },
			{ "Flight assist", "D-pad up" },
			{ "Menu", "View / Select" },
		},
	},
	{
		title = "Touch",
		rows = {
			{ "Thrust and strafe", "Drag on left half" },
			{ "Steer", "Drag on right half" },
			{ "Roll, up, down", "Buttons, right side" },
			{ "Boost, assist", "Buttons, left side" },
			{ "Lock, next, part, missile", "Buttons, top right" },
			{ "Menu", "Menu button, top left" },
		},
	},
}

function ControlsMenu.build(canvas: Frame, Menus)
	frame = Theme.screen("Controls", canvas)

	Theme.title("Controls", frame, { Position = UDim2.fromOffset(40, 20), Size = UDim2.fromOffset(400, 44) })
	Theme.label("Guns fire on their own once a target is locked and inside their arc and range.", {
		TextColor3 = C.dim,
		Position = UDim2.fromOffset(40, 62),
		Size = UDim2.fromOffset(1000, 22),
	}, frame)

	for index, column in COLUMNS do
		local box = Theme.panel({
			Position = UDim2.fromOffset(40 + (index - 1) * 345, 100),
			Size = UDim2.fromOffset(330, 430),
		}, frame)
		Theme.padding(box, 16)
		Theme.list(box, 6)
		Theme.label(column.title, { Font = Theme.fonts.heading, TextSize = 18, LayoutOrder = 0 }, box)
		for rowIndex, row in column.rows do
			local holder = Theme.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = rowIndex }, box)
			Theme.label(row[1], { TextSize = 14, TextColor3 = C.dim, Size = UDim2.new(0.5, 0, 1, 0) }, holder)
			Theme.label(row[2], {
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.fromScale(0.4, 0),
				Size = UDim2.new(0.6, 0, 1, 0),
			}, holder)
		end
	end

	backButton = Theme.button("Back", "secondary", function()
		Menus.back()
	end, { Position = UDim2.fromOffset(40, 550), Size = UDim2.fromOffset(160, 50) }, frame)

	return frame
end

function ControlsMenu.open()
	return backButton
end

return ControlsMenu
