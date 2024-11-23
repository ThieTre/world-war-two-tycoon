local CollectionService = game:GetService("CollectionService")

for _, templateScript in script:GetChildren() do
	local name = templateScript.Name
	local tagName = name:lower() .. "-billboard"
	for _, model in CollectionService:GetTagged(tagName) do
		local boardScript = templateScript:Clone()
		boardScript.Parent = model
		boardScript.Enabled = true
	end
end
