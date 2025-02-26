local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Modules

local InstModify = require(Modules.Mega.Instances.Modify)
local ServerTurret = require(Modules.Turrets.ServerTurret)
local PlayerUtils = require(Modules.Mega.Utils.Player)
local TyUtils = require(Modules.Tycoons.Utils)

local parent = script.Parent

local turret = ServerTurret:new(parent.Turret, parent.Base.Attachment)

local prompt = InstModify.findOrCreateChild(parent.PromptPart, "ProximityPrompt")
local seat: Seat = InstModify.findOrCreateChild(parent.Base, "Seat", nil, {
	Anchored = true,
	Transparency = 1,
	CFrame = parent.Base.CFrame,
})

local function disconnect()
	local player = turret.player
	if not player then
		return
	end
	turret:DisconnectClient()
end

local function connect(player: Player)
	local tycoon = TyUtils.getAncestorTycoon(parent)
	if not tycoon or tycoon.Owner.Value ~= player then
		return
	end
	local humanoid = PlayerUtils.getObjects(player, "Humanoid")
	turret:ConnectClient(player)
	seat:Sit(humanoid)
	humanoid:UnequipTools()
end

seat:GetPropertyChangedSignal("Occupant"):Connect(function()
	local player = turret.player
	if seat.Occupant or not player then
		return
	end
	disconnect()
	local humanoid = PlayerUtils.getObjects(player, "Humanoid")
	humanoid.Parent:PivotTo(CFrame.new(parent.Base.Exit.WorldPosition))
end)

prompt.Triggered:Connect(connect)
