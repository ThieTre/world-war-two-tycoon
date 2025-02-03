local CollectionService = game:GetService("CollectionService")

for _, model: Model in CollectionService:GetTagged("tycoon-door") do
	local clone = script.TycoonDoor:Clone()
	clone.Parent = model
	clone.Enabled = true
end
