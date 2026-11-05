--[[
	Pause menu while flying. The server keeps running (it's multiplayer), so
	the ship holds still with flight assist on and drifts with it off.
	Hangar and Main menu dock the ship first, which the server refuses for a
	few seconds after taking damage.
]]

local Theme = require(script.Parent.Theme)

local PauseMenu = {}

local C = Theme.colors
local frame, resumeButton, status

function PauseMenu.build(canvas: Frame, Menus)
	frame = Theme.screen("Pause", canvas)

	local box = Theme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 470),
	}, frame)
	Theme.padding(box, 24)
	Theme.list(box, 12)

	Theme.title("Paused", box, { LayoutOrder = 0, TextXAlignment = Enum.TextXAlignment.Center })
	Theme.label("The game keeps running while this menu is open.", {
		LayoutOrder = 1,
		TextSize = 14,
		TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 34),
	}, box)

	resumeButton = Theme.button("Resume", "primary", function()
		Menus.closeAll()
	end, { LayoutOrder = 2 }, box)
	Theme.button("Hangar (change ship)", "secondary", function()
		status.Text = "Docking..."
		Menus.dock("Hangar")
	end, { LayoutOrder = 3 }, box)
	Theme.button("Settings", "secondary", function()
		Menus.open("Settings")
	end, { LayoutOrder = 4 }, box)
	Theme.button("Controls", "secondary", function()
		Menus.open("Controls")
	end, { LayoutOrder = 5 }, box)
	Theme.button("Main menu", "danger", function()
		status.Text = "Docking..."
		Menus.dock("MainMenu")
	end, { LayoutOrder = 6 }, box)

	status = Theme.label("", {
		LayoutOrder = 7,
		TextSize = 14,
		TextColor3 = C.highlight,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 36),
	}, box)

	return frame
end

function PauseMenu.open()
	status.Text = ""
	return resumeButton
end

function PauseMenu.onNotice(text: string)
	if frame.Visible then
		status.Text = text
	end
end

return PauseMenu
