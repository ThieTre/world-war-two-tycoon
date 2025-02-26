if not script.Parent.Parent then
	return
end

local Table = require(game.ReplicatedStorage.Modules.Mega.DataStructures.Table)

local PASS_IDS =
	Table.GetFlattened(require(game.ReplicatedStorage.Settings.Monetization.GamePasses))
require(game.ReplicatedStorage.Settings.Monetization.GamePasses)

local MarketService = game:GetService("MarketplaceService")

local LocalPlayer = game.Players.LocalPlayer

local instance = script.Parent
local name = instance.Name:gsub(" Board", "")
local id = PASS_IDS[name][1]
local main = instance:FindFirstChild("Main")

local clickDetecor = Instance.new("ClickDetector")
clickDetecor.MaxActivationDistance = 100
clickDetecor.Parent = main or instance

if main then
	local prompt = Instance.new("ProximityPrompt")
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = main

	prompt.Triggered:Connect(function()
		MarketService:PromptGamePassPurchase(LocalPlayer, id)
	end)
end

clickDetecor.MouseClick:Connect(function()
	MarketService:PromptGamePassPurchase(LocalPlayer, id)
end)
