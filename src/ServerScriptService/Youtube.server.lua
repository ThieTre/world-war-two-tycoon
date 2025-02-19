local VehicleManager =
	require(game.ReplicatedStorage.Modules.TycoonGame.Vehicles.Manager)
local TyUtils = require(game.ReplicatedStorage.Modules.Tycoons.Utils)

local USERS = { 7048471114, 362135519, 1479787966, 17318031, 24189615 }

game.Players.PlayerAdded:Connect(function(player)
	if not table.find(USERS, player.UserId) then
		return
	end
	TyUtils.waitForTycoon(player)
	VehicleManager:AddPlayerVehicle(player, "Tiger 1")
end)
