local CollectionService = game:GetService("CollectionService")
local templateScript = script.TycoonTurret

local staticTurrets = CollectionService:GetTagged("tycoon-turret")
for _, turret in staticTurrets do
	local serverScript = templateScript:Clone()
	serverScript.Parent = turret
	serverScript.Enabled = true
end
