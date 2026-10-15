--[[
	Picks which ship to lock. "Lock" takes the target nearest the centre of
	the view; "Next" cycles through ships in lock range by distance. The
	server does the actual lock and checks range itself.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Targeting = {}

-- Ships other than our own that are loaded and within lock range.
function Targeting.candidates(own: Model?)
	local list = {}
	local camera = workspace.CurrentCamera
	local origin = if own and own.PrimaryPart then own.PrimaryPart.Position else camera.CFrame.Position
	for _, model in CollectionService:GetTagged("Ship") do
		if model ~= own and model:IsA("Model") and model.PrimaryPart and model:IsDescendantOf(workspace) then
			local offset = model.PrimaryPart.Position - origin
			local distance = offset.Magnitude
			if distance <= Config.LockRange then
				local angle = math.deg(math.acos(math.clamp(camera.CFrame.LookVector:Dot(offset.Unit), -1, 1)))
				table.insert(list, { model = model, distance = distance, angle = angle })
			end
		end
	end
	return list
end

function Targeting.lockNearestInView(own: Model?)
	local best
	for _, candidate in Targeting.candidates(own) do
		local inCone = candidate.angle <= Config.LockConeDegrees
		if inCone and (not best or candidate.distance < best.distance) then
			best = candidate
		end
	end
	if not best then
		-- Nothing ahead: take whatever is closest to the centre of the view.
		for _, candidate in Targeting.candidates(own) do
			if not best or candidate.angle < best.angle then
				best = candidate
			end
		end
	end
	if best then
		Remotes.RequestLock:FireServer(best.model)
	end
end

function Targeting.nextTarget(own: Model?, current: Model?)
	local list = Targeting.candidates(own)
	if #list == 0 then
		return
	end
	table.sort(list, function(a, b)
		return a.distance < b.distance
	end)
	local index = 0
	for i, candidate in list do
		if candidate.model == current then
			index = i
			break
		end
	end
	Remotes.RequestLock:FireServer(list[index % #list + 1].model)
end

function Targeting.clear()
	Remotes.ClearLock:FireServer()
end

function Targeting.cycleSubsystem()
	Remotes.CycleSubsystem:FireServer()
end

return Targeting
