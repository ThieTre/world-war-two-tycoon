local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Modules = ReplicatedStorage.Modules

local Logging = require(ReplicatedStorage.Modules.Mega.Logging)
local PlayerData = require(Modules.PlayerData)
local Monetization = require(Modules.Monetization)
local TyUtils = require(Modules.Tycoons.Utils)
local RemoteConfig = require(ReplicatedStorage.Modules.Mega.Data.RemoteConfig)

local OCUserNotification =
	require(ServerStorage.Modules.OpenCloud.V2.UserNotification)

local SETTINGS = require(ServerStorage.Settings.ExperienceNotifications)
local LOG = Logging:new("ExperienceNotifications")

local userQueue = {}
local userQueueSize = 0

local function resolveUserData(player: Player): {}?
	--[[
		Determine what notificaiton should be sent to the player
		given their current cash boost/chest status
	]]

	-- Resolve message
	local messageType, parameters
	local unopenedChests = Monetization.Chests.getClientUnopenedCount(player)
	local unactivatedBoosts =
		Monetization.CashBoosts.Manager.getClientAvailableCount(player)
	if unopenedChests > 0 then
		if unopenedChests > 1 then
			messageType = "Multiple Chests"
		else
			messageType = "Single Chest"
		end
		parameters = {
			["count"] = { int64Value = unopenedChests },
		}
	elseif unactivatedBoosts > 0 then
		if unactivatedBoosts > 1 then
			messageType = "Multiple Boosts"
		else
			messageType = "Single Boost"
		end
		parameters = {
			["count"] = { int64Value = unactivatedBoosts },
		}
	elseif
		RemoteConfig:Lookup("TycoonExperienceNotificationsEnabled", true)
	then
		messageType = "Tycoon"
	end

	-- Return infomration
	if not messageType then
		LOG:Debug("No message will be sent for player " .. player.UserId)
		return
	else
		LOG:Debug(
			"Using message type " .. messageType .. " for " .. player.UserId
		)
		return {
			messageType = messageType,
			parameters = parameters,
		}
	end
end

local function addToQueue(player: Player)
	LOG:Debug(
		"Adding " .. player.UserId .. " to the queue of size " .. userQueueSize
	)
	if userQueueSize > SETTINGS.MaxQueueSize then
		LOG:Warning(
			"Max user queue has been reached - no more users will be added until queue size decreases"
		)
		return
	end
	local userData = resolveUserData(player)
	if not userData then
		return
	end
	userData["logoffTime"] = time()
	userQueue[player.UserId] = userData
	userQueueSize += 1
end

local function removeFromQueue(uid: number, userData: {})
	LOG:Debug("Sending notification to user " .. uid)

	-- Draft notification
	local userNotification = {
		payload = {
			type = "MOMENT",
			messageId = SETTINGS.IdMap[userData.messageType],
			parameters = userData.parameters,
		},
	}
	LOG:Debug(userNotification)
	-- Send and verify
	local result =
		OCUserNotification.createUserNotification(uid, userNotification)
	if result.statusCode ~= 200 then
		LOG:Debug(
			`Failed to send user notification for user {uid} ({result.statusCode}): {result.error.message}`
		)
	end

	-- Adjust queue
	userQueue[uid] = nil
	userQueueSize -= 1
end

game.Players.PlayerRemoving:Connect(function(player: Player)
	PlayerData:AddRemovalLock(player)
	addToQueue(player)
	PlayerData:ReleaseRemovalLock(player)
end)

while true do
	task.wait(SETTINGS.PollInterval)
	LOG:Debug("Evaulting queue")
	for uid, userData in userQueue do
		local logoffMinutes = (time() - userData.logoffTime) / 60
		if logoffMinutes < SETTINGS.ExitMinutesWait then
			LOG:Debug(
				`User {uid} has not been logged off long enough" {logoffMinutes}/{SETTINGS.ExitMinutesWait}`
			)
			continue
		end
		task.spawn(removeFromQueue, uid, userData)
	end
end
