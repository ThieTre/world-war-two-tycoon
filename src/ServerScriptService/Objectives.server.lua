local CapturePoint =
	require(game.ReplicatedStorage.Modules.Objects.CustomPointCapture)

for _, objective in workspace.Objectives:GetChildren() do
	CapturePoint:new(objective)
end
