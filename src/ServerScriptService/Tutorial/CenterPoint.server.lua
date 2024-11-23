local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Modules = ReplicatedStorage.Modules

local TutorialPopup = require(Modules.Mega.Tutorial.Popup)
local PlayerData = require(Modules.PlayerData)

local POPUP_NAME = "Center Point"
local CENTER_POS = workspace.PointCapture.Zone.Position

Players.PlayerAdded:Connect(function(player: Player)
	PlayerData:WaitForPlayer(player)

	-- Check if player
	local historyCount = TutorialPopup.getPopupHistoryCount(player, POPUP_NAME)
	if historyCount >= 1 then
		-- Player has already gotten this popup
		return
	end

	while player.Parent do
		task.wait(2)

		local distance = player:DistanceFromCharacter(CENTER_POS)

		if distance > 0 and distance < 270 then
			TutorialPopup.conditionalClientFullscreen(player, POPUP_NAME)
			break
		end
	end
end)
