if not script.Parent.Parent then
	return
end

local MarketService = game:GetService("MarketplaceService")

local LocalPlayer = game.Players.LocalPlayer

local model = script.Parent
local id = model:GetAttribute("PassId")
local main = model:FindFirstChild("Main")

local clickDetecor = Instance.new("ClickDetector")
clickDetecor.MaxActivationDistance = 100
clickDetecor.Parent = main or model

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
