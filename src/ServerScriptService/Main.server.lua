local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Modules = ReplicatedStorage.Modules
local Mega = Modules.Mega

local Logging = require(Mega.Logging)
local LiveConfig = require(Mega.Data.LiveConfig)
local Instances = require(Mega.Instances)
local TutorialPopups = require(Mega.Tutorial.Popup)
local Loader = require(Mega.Interface.Loader)
local PlayerUtils = require(Modules.Mega.Utils.Player)
local GunUtils = require(Modules.Guns.Utils)
local TycoonManager = require(Modules.TycoonGame.Tycoons.Manager)
local MusicManager = require(Modules.Mega.Game.Music)
local MoneyUtils = require(Modules.Monetization.Utils)
local Notification = require(Modules.Mega.Interface.Notification)
local Badges = require(Modules.Mega.Game.Badges)
local LeaderBoard = require(Modules.Mega.Game.Leaderboard)
local PlayerData = require(Modules.PlayerData)
local Strafer = require(Modules.Strafer)

local LOG = Logging:new("Server-Main")
local GAME_SETTINGS = require(ReplicatedStorage.Settings.Game)

local tycoons = TycoonManager:new(workspace["Tycoon Systems"].Factory)

local function onCharacterAdded(player: Player, character: Model)
	local humanoid: Humanoid = PlayerUtils.waitForObjects(player, "Humanoid")

	character.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- Do we need this?

	Strafer.serverMethod(player, "SetEnabled", false)

	character:AddTag("Damageable")

	if
		MoneyUtils.safeUserOwnsGamePass(
			player,
			MoneyUtils.passMap.Other["2X Health"][1]
		)
	then
		humanoid.MaxHealth *= 2
		humanoid.Health *= 2
		local highlight = game.ServerStorage.Assets.Misc.ShieldHighlight:Clone()
		highlight.Parent = character
		Notification.clientCoreNotification(player, {
			Title = "2X Health",
			Text = "Active",
			Icon = "rbxassetid://7123299346",
			Sound = "Basic",
		})
	end

	PlayerUtils.onDeath(player, function()
		humanoid:UnequipTools()

		local previousTools = {}
		for _, t in player.Backpack:GetChildren() do
			if table.find(previousTools, t.Name) then
				-- No duplicates
				continue
			end
			table.insert(previousTools, t.Name)
		end

		task.wait(Players.RespawnTime)
		player:LoadCharacter()

		for _, tName in previousTools do
			GunUtils.giveGun(player, tName)
		end
	end)

	-- Add starter gun
	if player.Team ~= game.Teams.Choosing then
		task.wait(1)
		local playerTool = player.Backpack:FindFirstChildWhichIsA("Tool")
		local characterTool = character:FindFirstChildWhichIsA("Tool")
		if not playerTool and not characterTool then
			GunUtils.giveGun(player, "1911")
		end
	end

	-- Set character collision group
	for _, part in Instances.Search.getDescendantsOfType(character, "BasePart") do
		part.CollisionGroup = "Player"
	end

	-- Clean accessories
	for _, accessory in Instances.Search.getDescendantsOfType(character, "Accessory") do
		for _, part in Instances.Search.getDescendantsOfType(accessory, "BasePart") do
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

local function onPlayerAdded(player: Player)
	-- Loader.playerStartLoad(player)

	player.Team = game.Teams.Choosing

	Badges.awardBadge(player, "Welcome")

	-- Setup player config and leaderbaord
	local configsFolder =
		Instances.Modify.create("Folder", player, { Name = "Configs" })
	LiveConfig.create(configsFolder, { name = "Tycoon", data = { Balance = 0 } })
	LeaderBoard.setStat(player, "Rebirths", PlayerData:Lookup(player, "Rebirths", 0))

	-- Setup character
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	-- Read join data
	local joinInfo = {}
	local success, err = pcall(function()
		local joinData = player:GetJoinData()
		local rawLaunchData = joinData.LaunchData
		local teleportData = joinData.TeleportData

		if rawLaunchData and rawLaunchData ~= "" then
			local launchData = HttpService:JSONDecode(rawLaunchData)
			joinInfo.sendingUser = launchData.sendingUser
		end

		if teleportData then
			local systemMap = teleportData.teamMap or {}
			joinInfo.previousTeam = systemMap[tostring(player.UserId)]
		end
	end)
	if not success then
		LOG:Error("Failed to process join data for %s: %s ", player.UserId, err)
	end

	-- Try to load player into previous tycoon if possible
	if joinInfo.previousTeam then
		LOG:Debug(joinInfo)
		LOG:Debug(
			"Load %s into previous tycoon %s",
			player.UserId,
			joinInfo.previousTeam
		)
		local targetPlot = tycoons.plots:Search(function(plot: BasePart)
			return plot.Name == joinInfo.previousTeam
		end)
		local added = tycoons:RequestOwnerAdd(player, targetPlot)
		if added then
			player:RequestStreamAroundAsync(targetPlot.Position, 10)
			player:LoadCharacter()
			Loader.playerStopLoad(player)
			MusicManager.serverMethod(player, "SetPlaylist", "Basic")
			return
		end
	end

	player:RequestStreamAroundAsync(
		workspace:WaitForChild("Selection Map"):GetPivot().Position,
		10
	)
	player:LoadCharacter()
	local elapsed = 0
	local min, max = unpack(GAME_SETTINGS.LoadTimeRange)
	while (elapsed < min or not player:HasAppearanceLoaded()) and elapsed < max do
		task.wait(1)
		elapsed += 1
	end

	player.Character:WaitForChild("HumanoidRootPart")

	tycoons:GuidePlayerToOpenSpawn(player)

	Loader.playerStopLoad(player)

	MusicManager.serverMethod(player, "SetPlaylist", "Basic")

	TutorialPopups.conditionalClientFullscreen(player, "PlanesUpdate", 1)

	if RunService:IsStudio() then
		tycoons:RequestOwnerAdd(player, tycoons.plots:RandomChoice())
	end
end

PlayerUtils.inclusivePlayerAdded(onPlayerAdded)
