--[[
	Settings screen, drawn from Shared/Settings.list: toggles, sliders (drag,
	or the - and + buttons on a gamepad) and choices. Changes apply at once
	and are saved to the player's profile by ClientSettings.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Settings = require(ReplicatedStorage.Shared.Settings)

local ClientSettings = require(script.Parent.Parent.ClientSettings)
local Theme = require(script.Parent.Theme)

local SettingsMenu = {}

local C = Theme.colors
local frame, backButton, firstControl
local refreshers = {} -- [key] = function() redraws that row from ClientSettings

local function formatValue(item, value): string
	if item.step and item.step < 1 then
		if item.max <= 1 and item.key ~= "mouseDeadzone" then
			return string.format("%d%%", math.floor(value * 100 + 0.5))
		end
		return string.format("%.2f", value)
	end
	return string.format("%d", value)
end

local function rowFrame(parent, item, order)
	local row = Theme.make("Frame", {
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(1, -12, 0, if item.hint then 64 else 50),
	}, parent)
	Theme.corner(row, 8)
	Theme.label(item.label, {
		TextSize = 17,
		Position = UDim2.fromOffset(16, if item.hint then 8 else 13),
		Size = UDim2.new(0.5, -16, 0, 24),
	}, row)
	if item.hint then
		Theme.label(item.hint, {
			TextSize = 13,
			TextColor3 = C.faint,
			Position = UDim2.fromOffset(16, 32),
			Size = UDim2.new(0.55, -16, 0, 28),
			TextYAlignment = Enum.TextYAlignment.Top,
		}, row)
	end
	local controls = Theme.make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(330, 38),
	}, row)
	return row, controls
end

local function buildToggle(item, controls)
	local button
	button = Theme.button("", "secondary", function()
		ClientSettings.set(item.key, not ClientSettings.get(item.key))
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(110, 38),
		TextSize = 17,
	}, controls)
	refreshers[item.key] = function()
		local on = ClientSettings.get(item.key)
		button.Text = if on then "On" else "Off"
		button.TextColor3 = if on then C.good else C.dim
	end
	return button
end

local function buildSlider(item, controls)
	local function nudge(direction)
		ClientSettings.set(item.key, ClientSettings.get(item.key) + direction * item.step)
	end
	local minus = Theme.button("-", "secondary", function()
		nudge(-1)
	end, { Size = UDim2.fromOffset(38, 38), TextSize = 22 }, controls)
	local plus = Theme.button("+", "secondary", function()
		nudge(1)
	end, { Position = UDim2.fromOffset(250, 0), Size = UDim2.fromOffset(38, 38), TextSize = 22 }, controls)
	local valueLabel = Theme.label("", {
		Position = UDim2.fromOffset(292, 0),
		Size = UDim2.fromOffset(40, 38),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, controls)

	local track = Theme.make("TextButton", {
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = C.panelLight,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(50, 14),
		Size = UDim2.fromOffset(190, 10),
		Selectable = false,
	}, controls)
	Theme.corner(track, 5)
	local fill = Theme.make("Frame", { BackgroundColor3 = C.accent, BorderSizePixel = 0, Size = UDim2.fromScale(0.5, 1) }, track)
	Theme.corner(fill, 5)
	local knob = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.text,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
	}, track)
	Theme.corner(knob, 9)

	local dragging = nil
	local function setFromX(x)
		local fraction = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		ClientSettings.set(item.key, item.min + fraction * (item.max - item.min))
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = input
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		local isMouseMove = input.UserInputType == Enum.UserInputType.MouseMovement
			and dragging.UserInputType == Enum.UserInputType.MouseButton1
		if isMouseMove or input == dragging then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = nil
		end
	end)

	refreshers[item.key] = function()
		local value = ClientSettings.get(item.key)
		local fraction = (value - item.min) / (item.max - item.min)
		fill.Size = UDim2.fromScale(fraction, 1)
		knob.Position = UDim2.fromScale(fraction, 0.5)
		valueLabel.Text = formatValue(item, value)
	end
	return minus, plus
end

local function buildChoice(item, controls)
	local valueLabel = Theme.label("", {
		Position = UDim2.fromOffset(170, 0),
		Size = UDim2.fromOffset(110, 38),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, controls)
	local function step(direction)
		local index = table.find(item.options, ClientSettings.get(item.key)) or 1
		index = (index - 1 + direction) % #item.options + 1
		ClientSettings.set(item.key, item.options[index])
	end
	local left = Theme.button("<", "secondary", function()
		step(-1)
	end, { Position = UDim2.fromOffset(128, 0), Size = UDim2.fromOffset(38, 38), TextSize = 20 }, controls)
	Theme.button(">", "secondary", function()
		step(1)
	end, { Position = UDim2.fromOffset(284, 0), Size = UDim2.fromOffset(38, 38), TextSize = 20 }, controls)
	refreshers[item.key] = function()
		valueLabel.Text = ClientSettings.get(item.key)
	end
	return left
end

local function refreshAll()
	for _, refresh in refreshers do
		refresh()
	end
end

function SettingsMenu.build(canvas: Frame, Menus)
	frame = Theme.screen("Settings", canvas)

	Theme.title("Settings", frame, { Position = UDim2.fromOffset(40, 20), Size = UDim2.fromOffset(400, 44) })
	Theme.label("Changes apply right away and are saved to your account.", {
		TextColor3 = C.dim,
		Position = UDim2.fromOffset(40, 62),
		Size = UDim2.fromOffset(700, 22),
	}, frame)

	local scroller = Theme.make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(820, 430),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.stroke,
		Selectable = false,
	}, frame)
	Theme.list(scroller, 8)

	for order, item in Settings.list do
		if item.section then
			Theme.label(item.section, {
				Font = Theme.fonts.heading,
				TextSize = 15,
				TextColor3 = C.accent,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 30),
				TextYAlignment = Enum.TextYAlignment.Bottom,
			}, scroller)
		else
			local _, controls = rowFrame(scroller, item, order)
			local control
			if item.kind == "toggle" then
				control = buildToggle(item, controls)
			elseif item.kind == "slider" then
				control = buildSlider(item, controls)
			elseif item.kind == "choice" then
				control = buildChoice(item, controls)
			end
			firstControl = firstControl or control
		end
	end

	backButton = Theme.button("Back", "secondary", function()
		Menus.back()
	end, { Position = UDim2.fromOffset(40, 550), Size = UDim2.fromOffset(160, 50) }, frame)
	Theme.button("Reset to defaults", "danger", function()
		ClientSettings.resetAll()
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(1060, 550),
		Size = UDim2.fromOffset(220, 50),
		TextSize = 18,
	}, frame)

	ClientSettings.onChanged(function(key)
		if key and refreshers[key] then
			refreshers[key]()
		else
			refreshAll()
		end
	end)
	refreshAll()
	return frame
end

function SettingsMenu.open()
	refreshAll()
	return firstControl or backButton
end

return SettingsMenu
