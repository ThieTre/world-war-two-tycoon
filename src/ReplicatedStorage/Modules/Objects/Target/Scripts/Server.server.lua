local CollectionService = game:GetService("CollectionService")

local scripts = game.ReplicatedStorage.Modules.Objects.Target.Cloned

for _, model: Model in CollectionService:GetTagged("world-target") do
	local serverScript = scripts.Server:Clone()
	serverScript.Parent = model
	serverScript.Enabled = true
end
