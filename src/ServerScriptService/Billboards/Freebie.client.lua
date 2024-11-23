local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AvatarService = game:GetService("AvatarEditorService")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Notify = require(Modules.Mega.Interface.Notification)
local Freebies = require(Modules.Prizes.Freebies)
local PrizeUtils = require(Modules.Prizes.Utils)

local LocalPlayer = game.Players.LocalPlayer

local SETTINGS = require(ReplicatedStorage.Settings.Prizes.Freebies)

local model = script.Parent
local main = model.Main

local clickDetecor = Instance.new("ClickDetector")
clickDetecor.MaxActivationDistance = 50
clickDetecor.Parent = main

local prompt = Instance.new("ProximityPrompt")
prompt.RequiresLineOfSight = false
prompt.MaxActivationDistance = 10
prompt.Parent = main

local function setInteraction(canInteract)
	if canInteract then
		clickDetecor.MaxActivationDistance = 50
		prompt.Enabled = true
	else
		clickDetecor.MaxActivationDistance = 0
		prompt.Enabled = false
	end
end

if not LocalPlayer.Character then
	LocalPlayer.CharacterAdded:Wait()
end

local hasClaimed = Freebies.checkInteractionClaimed()

if hasClaimed then
	model:Destroy()
	return
end

local prizeInfo =
	PrizeUtils.getPrizeInfo(SETTINGS.PrizeName, SETTINGS.PrizeType)
model.ImagePart.SurfaceGui.ImageLabel.Image = prizeInfo.Image

local function requestClaim()
	setInteraction(false)
	local claimed, details = Freebies.requestInteractionPrize()

	if claimed then
		Notify.clientCoreNotification({
			Title = SETTINGS.PrizeName .. " Added",
			Text = "Prize claimed!",
			Icon = prizeInfo.Image,
		})

		local attachment = main.Attachment
		LocalPlayer.PlayerGui.Monetization.Store.Sounds.Claim:Play()
		attachment.Parent = workspace.Terrain
		attachment.WorldPosition = main.Position
		game.Debris:AddItem(attachment, attachment.SmokePuff.Lifetime.Max)
		attachment.SmokePuff:Emit(10)
		model:Destroy()
		return
	end

	if details.accessBlocked then
		Notify.notify(
			"Unable to check favorite status. Please allow access to proceed.",
			{ Sound = "Error", Color = Color3.new(0.870588, 0, 0) }
		)
		setInteraction(true)
		return
	end

	if not details.hasFavorited then
		AvatarService:PromptSetFavorite(
			workspace.Parent.PlaceId,
			Enum.AvatarItemType.Asset,
			true
		)
		AvatarService.PromptSetFavoriteCompleted:Once(function(result)
			--if result ~= Enum.AvatarPromptResult.Success then
			--	setInteraction(true)
			--	return
			--end
			if details.isInGroup then
				requestClaim()
			else
				Notify.notify(
					"Please join the Mega Studios group (game owner) before claiming your prize!",
					{
						Sound = "Basic",
						Color = Color3.new(0.305882, 0.572549, 1),
					}
				)
			end
		end)
	else
		Notify.notify(
			"Please join the Mega Games group (game owner) before claiming your prize!",
			{ Sound = "Basic", Color = Color3.new(0.305882, 0.572549, 1) }
		)
	end
	setInteraction(true)
end

prompt.Triggered:Connect(requestClaim)
clickDetecor.MouseClick:Connect(requestClaim)
