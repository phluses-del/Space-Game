--[[
	Builds one display model per launchable ship into
	ReplicatedStorage.ShipPreviews, named by ShipCatalog id, for the Hangar's
	3D preview. Ships that can't be built yet are skipped and show as
	"Coming soon".

	The customization thread can call ShipPreviews.rebuild(id, color) after a
	paint change, or add its own previews to the same folder.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ShipCatalog = require(ReplicatedStorage.Shared.ShipCatalog)
local ShipBuilder = require(script.Parent.ShipBuilder)

local ShipPreviews = {}

local folder = Instance.new("Folder")
folder.Name = "ShipPreviews"
folder.Parent = ReplicatedStorage

-- Physics bits from ShipBuilder that a display model doesn't need.
local STRIP = { LinearVelocity = true, AngularVelocity = true }

function ShipPreviews.rebuild(id: string, color: Color3?)
	local entry = ShipCatalog.get(id)
	if not entry or not ShipCatalog.isAvailable(id) then
		return nil
	end
	local loadout = Config.Loadouts[entry.loadout]
	local ok, model = pcall(ShipBuilder.build, entry.hull, color or loadout.color, id)
	if not ok then
		warn(string.format("[ShipPreviews] Could not build %s: %s", id, tostring(model)))
		return nil
	end
	for _, item in model:GetDescendants() do
		if STRIP[item.ClassName] then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	model:PivotTo(CFrame.identity)

	local old = folder:FindFirstChild(id)
	if old then
		old:Destroy()
	end
	model.Parent = folder
	return model
end

function ShipPreviews.buildAll()
	for _, entry in ShipCatalog.entries do
		ShipPreviews.rebuild(entry.id)
	end
end

-- A ship can launch only if its preview built, which proves ShipBuilder has a
-- layout for the hull.
function ShipPreviews.has(id: string): boolean
	return folder:FindFirstChild(id) ~= nil
end

return ShipPreviews
