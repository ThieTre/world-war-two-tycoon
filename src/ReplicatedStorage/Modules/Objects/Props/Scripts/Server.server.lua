local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local cloned = ReplicatedStorage.Modules.Objects.Props.Cloned

local props = CollectionService:GetTagged("prop")
for _, prop in props do
	for _, propScript in cloned:GetChildren() do
		local clone = propScript:Clone()
		clone.Enabled = true
		clone.Parent = prop
	end
end
