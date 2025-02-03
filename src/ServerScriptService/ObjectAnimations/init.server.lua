local CollectionService = game:GetService("CollectionService")

local template = script.Client

for _, o in CollectionService:GetTagged("animated-object") do
	local clone = template:Clone()
	clone.Parent = o
	clone.Enabled = true
end
