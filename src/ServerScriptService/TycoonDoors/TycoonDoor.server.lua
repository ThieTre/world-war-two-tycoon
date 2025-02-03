local ServerDoor =
	require(game.ReplicatedStorage.Modules.Objects.Door.ServerDoor)
local TyUtils = require(game.ReplicatedStorage.Modules.Tycoons.Utils)
local InstSearch =
	require(game.ReplicatedStorage.Modules.Mega.Instances.Search)

if not script.Parent then
	return
end

local tycoon = TyUtils.getAncestorTycoon(script.Parent)
if not tycoon then
	return
end

local ownerVal = InstSearch.quietWaitForChild(tycoon, "Owner")
while not ownerVal.Value do
	task.wait()
end

local door = ServerDoor:new(script.Parent)

local function evaluateTeam()
	door.owner = ownerVal.Value
end

evaluateTeam()

ownerVal:GetPropertyChangedSignal("Value"):Connect(evaluateTeam)
