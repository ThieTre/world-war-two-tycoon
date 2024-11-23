local BoostManager = require(
	game.ReplicatedStorage:WaitForChild("Modules").Monetization.CashBoosts.Manager
)

local LocalPlayer = game.Players.LocalPlayer

local model = script.Parent
local main = model.Main

local clickDetecor = Instance.new("ClickDetector")
clickDetecor.MaxActivationDistance = 100
clickDetecor.Parent = main

if not model:HasTag("IgnorePrompt") then
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = ""
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = main

	prompt.Triggered:Connect(function()
		BoostManager.clientDisplayUi("Cash", { Choice = "Cash" })
	end)
end

clickDetecor.MouseClick:Connect(function()
	BoostManager.clientDisplayUi("Cash", { Choice = "Cash" })
end)
