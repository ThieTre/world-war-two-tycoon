local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local SocialService = game:GetService("SocialService")
local Teams = game:GetService("Teams")
local Players = game:GetService("Players")
local Modules = ReplicatedStorage.Modules

local PlayerUtils = require(Modules.Mega.Utils.Player)
local InterfaceUtils = require(Modules.Mega.Interface.Utils)
local InstModify = require(Modules.Mega.Instances.Modify)
local PartyUtils = require(Modules.Parties.Utils)

local LocalPlayer = game.Players.LocalPlayer

local frame = LocalPlayer.PlayerGui:WaitForChild("Main").Party
local replicated = frame.Replicated
local inviteScroller = frame.Invite.ScrollingFrame
local partyScroller = frame.Party.ScrollingFrame
local sounds = frame.Sounds

local remote = Modules.Parties.RemoteEvent
local currentParty = nil

local function canSendGameInvite(sendingPlayer)
	local success, canSend = pcall(function()
		return SocialService:CanSendGameInviteAsync(sendingPlayer)
	end)
	return success and canSend
end

local function updateMemebers()
	currentParty = PartyUtils.playerGetMemebers() or {}
end

-- Added to party, removed from party, character added

local function evaluatePartyLabels()
	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then
			continue
		end
		local hrp = PlayerUtils.getObjects(player, "HumanoidRootPart")
		if not hrp then
			continue
		end
		if table.find(currentParty, player) then
			if hrp:FindFirstChild("PartyLabel") then
				continue
			end
			local humanoid = hrp.Parent.Humanoid
			local label = frame.PartyLabel:Clone()
			label.Enabled = true
			label.ImageLabel.Image = Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size420x420
			)
			label.Parent = hrp

			humanoid.Died:Once(function()
				label:Destroy()
			end)
		else
			InstModify.destroyExistingChild(hrp, "PartyLabel")
		end
	end
end

local inTransaction = false
local function updateFrame()
	while inTransaction do
		task.wait()
	end
	inTransaction = true
	InterfaceUtils.clearUiChildren(partyScroller, inviteScroller)
	local members = currentParty or {}
	for _, player: Player in Players:GetPlayers() do
		if player == LocalPlayer then
			continue
		end
		if player.Team == Teams.Choosing then
			continue
		end

		-- Create tile
		local tile = replicated.UserTile:Clone()
		tile.TextButton.Text = player.Name
		tile.ImageLabel.Image = Players:GetUserThumbnailAsync(
			player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size420x420
		)
		tile.Visible = true

		-- Assign location
		if table.find(members, player) then
			tile.BackgroundColor3 = Color3.new(0, 1, 0.498039)
			tile.Parent = partyScroller
		else
			tile.Parent = inviteScroller
			tile.TextButton.MouseButton1Click:Once(function()
				tile.BackgroundColor3 = Color3.new(1, 0.784314, 0.352941)
				sounds.Invite:Play()
				PartyUtils.playerSendInvite(player)
			end)
		end
	end
	inTransaction = false
end

while LocalPlayer.Team == Teams.Choosing do
	task.wait(1)
end

if canSendGameInvite(LocalPlayer) then
	local inviteOptions = Instance.new("ExperienceInviteOptions")
	inviteOptions.PromptMessage = "Get your friends to join your game for a free prize!"
	inviteOptions.LaunchData =
		HttpService:JSONEncode({ sendingUser = LocalPlayer.UserId })
	frame.Friends.TextButton.MouseButton1Click:Connect(function()
		SocialService:PromptGameInvite(LocalPlayer, inviteOptions)
	end)
else
	frame.Friends.Visible = false
end

updateMemebers()
evaluatePartyLabels()
updateFrame()

frame.Party.LeaveButton.MouseButton1Click:Connect(function()
	if currentParty then
		PartyUtils.playerLeaveParty()
	end
end)

remote.OnClientEvent:Connect(function(typ)
	if typ == "MemberAdding" then
		sounds.Added:Play()
	elseif typ == "MemberRemoving" then
		sounds.Removed:Play()
	end
	updateMemebers()
	updateFrame()
	evaluatePartyLabels()
end)

frame:GetPropertyChangedSignal("Visible"):Connect(function()
	if frame.Visible then
		updateFrame()
	end
end)

PlayerUtils.inclusivePlayerAdded(function(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart")
		evaluatePartyLabels()
	end)
end)
