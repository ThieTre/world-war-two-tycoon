local CollectionService = game:GetService("CollectionService")

for _, model: Model in CollectionService:GetTagged("tycoon-sentry") do
	local clone = script.TycoonSentry:Clone()
	clone.Parent = model
	clone.Enabled = true
end
