local ReplicatedStorage = game:GetService('ReplicatedStorage')
local CollectionService = game:GetService('CollectionService')
local HttpService = game:GetService('HttpService')
local SocialService = game:GetService('SocialService')
local Teams = game:GetService('Teams')
local Players = game:GetService('Players')
local Modules = ReplicatedStorage.Modules

local MegaUtils = require(Modules.Mega.Utils)
local InterfaceUtils = require(Modules.Mega.Interface.Utils)
local PartyUtils = require(Modules.Parties.Utils)
local ConnManager = require(Modules.Mega.Utils.ConnManager)

local LocalPlayer = game.Players.LocalPlayer

local frame = LocalPlayer.PlayerGui:WaitForChild('Main').Party
local replicated = frame.Replicated
local inviteScroller = frame.Invite.ScrollingFrame
local partyScroller = frame.Party.ScrollingFrame
local sounds = frame.Sounds

local remote = Modules.Parties.RemoteEvent
local currentParty = PartyUtils.playerGetMemebers()
local labelConns = ConnManager:new()


local function canSendGameInvite(sendingPlayer)
	local success, canSend = pcall(function()
		return SocialService:CanSendGameInviteAsync(sendingPlayer)
	end)
	return success and canSend
end


local function evaluatePartyLabels(removedMembers)
	
	if not removedMembers then
		local currentMembers = currentParty or {}
		-- Evaluate current members labels
		for _, player: Player in currentMembers do
			if player == LocalPlayer then
				continue
			end
			local humanoid, hrp = MegaUtils.Player.getObjects(player, 'Humanoid', 'HumanoidRootPart')
			if not humanoid or not hrp then
				continue
			end
			if hrp:FindFirstChild('PartyLabel') then
				continue
			end
			local label = frame.PartyLabel:Clone()
			label.Enabled = true
			label.ImageLabel.Image = Players:GetUserThumbnailAsync(player.UserId, 
				Enum.ThumbnailType.HeadShot, 
				Enum.ThumbnailSize.Size420x420
			)
			label.Parent = hrp
			humanoid.Died:Once(function()
				label:Destroy()
				player.CharacterAdded:Once(function()
					evaluatePartyLabels()
				end)
			end)
		end
	else
		-- Evaluate removed members
		for _, player: Player in removedMembers do
			local hrp: BasePart = MegaUtils.Player.getObjects(player, 'HumanoidRootPart')
			if not hrp then
				continue
			end
			local existingLabel = hrp:FindFirstChild('PartyLabel')
			if existingLabel then
				existingLabel:Destroy()
			end
		end
	end
end

while LocalPlayer.Team == Teams.Choosing do
	task.wait(1)
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
		tile.ImageLabel.Image = Players:GetUserThumbnailAsync(player.UserId, 
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

frame.Party.LeaveButton.MouseButton1Click:Connect(function()
	if currentParty then
		local isRemoved = PartyUtils.playerLeaveParty()
	end
end)


if canSendGameInvite(LocalPlayer) then
	local inviteOptions = Instance.new('ExperienceInviteOptions')
	inviteOptions.PromptMessage = "Get your friends to join your game for a free prize!"
	inviteOptions.LaunchData = HttpService:JSONEncode({sendingUser=LocalPlayer.UserId})
	frame.Friends.TextButton.MouseButton1Click:Connect(function()
		SocialService:PromptGameInvite(LocalPlayer, inviteOptions)
	end)
else
	frame.Friends.Visible = false
end


remote.OnClientEvent:Connect(function(typ, content)
	if typ == 'MemberAdding' then
		if content['Player'] == LocalPlayer then
			-- Local player was added to a new party
			currentParty = PartyUtils.playerGetMemebers()
		else
			if not currentParty then
				currentParty = {content['Player']}
			else
				table.insert(currentParty, content['Player'])
			end
		end
		evaluatePartyLabels()
		sounds.Added:Play()
	elseif typ == 'MemberRemoving' then
		if content['Player'] == LocalPlayer then
			evaluatePartyLabels(currentParty)
			currentParty = nil 
		else
			table.remove(currentParty, table.find(currentParty, content['Player']))
			evaluatePartyLabels({content['Player']})
		end
		sounds.Removed:Play()
	end
	updateFrame()
end)

frame:GetPropertyChangedSignal('Visible'):Connect(function()
	if frame.Visible then
		updateFrame()
	end
end)

CollectionService:GetInstanceAddedSignal('Player'):Connect(function()
	-- Player additions or deaths
	evaluatePartyLabels()
end)

