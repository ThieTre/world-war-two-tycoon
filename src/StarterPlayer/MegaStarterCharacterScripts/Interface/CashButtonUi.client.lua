local PlayerGui = game.Players.LocalPlayer.PlayerGui

local MoneyUtils = require(game.ReplicatedStorage.Modules.Monetization.Utils)

local button = PlayerGui:WaitForChild('Cash').Cash.TextButton

button.MouseButton1Click:Connect(function()
	MoneyUtils.clientDisplayUi('Cash')
end)