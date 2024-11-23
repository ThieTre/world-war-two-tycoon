local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Modules = ReplicatedStorage.Modules

local Notify = require(Modules.Mega.Interface.Notification)
local TyUtils = require(Modules.Tycoons.Utils)
local TutUtils = require(Modules.Mega.Tutorial)


local LocalPlayer = game.Players.LocalPlayer
local tycoonConfig = LocalPlayer:WaitForChild('Configs'):WaitForChild('Tycoon')

local button = LocalPlayer.PlayerGui:WaitForChild('Main').SideButtons.SideButtons.Home
local message = 'Follow the arrow back to your tycoon. Click again to cancel.'
local lastClick = os.time()
local isActive = false

local tycoonObj: Model = TyUtils.waitForTycoon(LocalPlayer).Value


button.MouseButton1Click:Connect(function()
	
	if (os.time() - lastClick) < 1 then
		return
	end
	lastClick = os.time()
	if not isActive then
		if tycoonConfig:GetAttribute('IsNearTycoon') then
			Notify.notify(
				'Cannot guide you to your tycoon; you are already there!', 
				{Sound='Error', Color=Color3.new(1, 0, 0), Duration=5}
			)
			return
		end	
		local position = tycoonObj:GetPivot().Position
		Notify.notify( 
			message, 
			{Sound='Basic', Color=Color3.new(0, 0.333333, 1)}
		)
		task.spawn(function()
			TutUtils.Notification.guidanceNotify(
				nil,
				position, 
				{Force=true, Name='HomeGuidance', ArrivalDistance=200})
		end)
	else
		TutUtils.Beam.clientRemoveBeam('HomeGuidance')
	end
	isActive = not isActive
end)