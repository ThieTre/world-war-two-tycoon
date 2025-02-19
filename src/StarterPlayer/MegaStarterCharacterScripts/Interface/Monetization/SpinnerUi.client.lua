local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketService = game:GetService("MarketplaceService")

local Modules = ReplicatedStorage.Modules
local Logging = require(Modules.Mega.Logging)
local Interface = require(Modules.Mega.Interface)
local Spinner = require(Modules.Monetization.DailySpinner)
local PrizeUtils = require(Modules.Prizes.Utils)
local TyUtils = require(Modules.Tycoons.Utils)
local MiscUtils = require(Modules.Mega.Utils.Misc)

local LOG = Logging:new("Monetization.Spinner")
local SETTINGS = require(ReplicatedStorage.Settings.Monetization.DailySpinner)

local LocalPlayer = game.Players.LocalPlayer

local canvas = LocalPlayer.PlayerGui:WaitForChild("Monetization").Spinner
local content = canvas.Content
local button = content.MainButton
local badge = LocalPlayer.PlayerGui.Main.SideButtons.SideButtons.Spinner.Badge
local selection = content.Replicated.Selection
local sounds = canvas.Sounds
local prizeSounds =
	LocalPlayer.PlayerGui.Monetization:WaitForChild("ChestOpen"):WaitForChild("Sounds")
local prizeTiles = content.Tiles:GetChildren()
local connections = {}
local context = Interface.Context.Manager:GetContext("fullscreen")
local isSpinning = false
local sideButton = LocalPlayer.PlayerGui.Main.SideButtons.SideButtons.Spinner

local Ui = {} -- module

local currentTileMap = {}
local availableSpins, previousPrizes, prizeMap, remainingCooldown
local function updateSpinData()
	availableSpins, remainingCooldown = Spinner.clientGetAvailableSpins()
	previousPrizes = Spinner.getClientPreviousPrizes()
	prizeMap = Spinner.clientGetPrizeMap()
end

local function formatTime(seconds)
	local hours = math.floor(seconds / 3600)
	seconds = seconds % 3600
	local minutes = math.floor(seconds / 60)
	seconds = seconds % 60
	local formattedTime = string.format("%02d:%02d:%02d", hours, minutes, seconds)
	return formattedTime
end

updateSpinData()

if availableSpins > 0 then
	badge.Visible = true
	if not LocalPlayer:GetAttribute("ForceDisplayed") then
		task.spawn(function()
			TyUtils.waitForTycoon(LocalPlayer)
			Spinner.clientDisplayUi()
		end)
		LocalPlayer:SetAttribute("ForceDisplayed", true)
	end
end

local mainConn: RBXScriptConnection
local isUpdating = false

local function waitForAvailableSpinsChange(prevValue)
	-- Wait for spins to be added
	for i in MiscUtils.count() do
		updateSpinData()
		if not canvas.Visible then
			return
		end
		if availableSpins > prevValue then
			break
		end
		if i > 5 / 0.01 then
			break
		end
		task.wait(0.01)
	end
end

local function promptProduct(id)
	local prevAvailableSpins = availableSpins
	MarketService:PromptProductPurchase(LocalPlayer, id)
	local promptConn: RBXScriptConnection
	promptConn = MarketService.PromptProductPurchaseFinished:Connect(
		function(userId, productId, isPurchased)
			if productId ~= id or LocalPlayer.UserId ~= LocalPlayer.UserId then
				return
			end
			promptConn:Disconnect()
			if not isPurchased then
				return
			end
			if mainConn then
				mainConn:Disconnect()
			end
			button.TextLabel.Text = `ADDING SPINS...`
			isUpdating = true
			sounds.Purchase:Play()
			waitForAvailableSpinsChange(prevAvailableSpins)
			isUpdating = false
			Ui.update()
		end
	)
end

local function exit()
	context:Hide(canvas, { ExitStyle = "Fade", EnterStyle = "Fade" })
end

local lastUpdate = time()
function Ui.update()
	if isSpinning then
		return
	end
	if isUpdating then
		return
	end
	isUpdating = true
	updateSpinData()
	selection.Parent = nil
	if mainConn then
		mainConn:Disconnect()
	end
	for _, connection: RBXScriptConnection in connections do
		connection:Disconnect()
	end

	-- Update cooldown
	local thisUpdate = time()
	lastUpdate = thisUpdate
	if remainingCooldown > 0 then
		task.spawn(function()
			local prevAvailableSpins = availableSpins
			for i = 1, remainingCooldown do
				if thisUpdate ~= lastUpdate then
					return
				end
				if not canvas.Visible then
					return
				end
				content.Duration.Text = `Free Spin: {formatTime(remainingCooldown - i)}`
				task.wait(1)
			end

			-- Timer ended
			waitForAvailableSpinsChange(prevAvailableSpins)
			Ui.update()
		end)
	else
		content.Duration.Text = "Free Spin: NOW!"
	end

	-- Setup small tiles
	local index = 1
	for name, prizeSettings in prizeMap do
		if prizeSettings.IsLarge then
			continue
		end
		local prizeInfo = table.clone(PrizeUtils.getPrizeInfo(name, prizeSettings.Type))
		for k, v in prizeSettings do
			prizeInfo[k] = v
		end
		Ui.setPrizeTile(name, prizeInfo, content.Tiles["Small" .. index])
		index += 1
	end

	-- Setup large tiles
	index = 1
	for name, prizeSettings in prizeMap do
		if not prizeSettings.IsLarge then
			continue
		end
		local prizeInfo = table.clone(PrizeUtils.getPrizeInfo(name, prizeSettings.Type))
		for k, v in prizeSettings do
			prizeInfo[k] = v
		end
		Ui.setPrizeTile(name, prizeInfo, content.Tiles["Large" .. index])
		index += 1
	end

	-- Setup button
	button.TextLabel.Text = `SPIN ({availableSpins}X)`
	if availableSpins > 0 then
		mainConn = button.MouseButton1Click:Once(function()
			button.TextLabel.Text = `SPIN ({availableSpins - 1}X)`
			mainConn:Disconnect()
			local selectedPrize = Ui.spin()
			Ui.update()
		end)
	else
		mainConn = button.MouseButton1Click:Connect(function()
			promptProduct(SETTINGS.EmptyProductId)
		end)
	end
	isUpdating = false
end

function Ui.setPrizeTile(name: string, prizeInfo: {}, tile: GuiObject)
	tile.ImageLabel.Image = prizeInfo.Image or prizeInfo.Game.Image
	local displayName = name
	if prizeInfo.Type == "Minutes Reward" then
		displayName = "$"
			.. TyUtils.formatNumber(
				Spinner.getRoundedMinutesReward(LocalPlayer, prizeInfo.Value)
			)
	end
	tile.TextLabel.Text = displayName

	currentTileMap[name] = tile

	if table.find(previousPrizes, name) then
		tile.Claimed.Visible = true
		return
	end

	table.insert(
		connections,
		tile.Button.MouseButton1Click:Connect(function()
			tile.TextLabel.Text = (prizeInfo.Probability * 100) .. "%"
			task.wait(2)
			tile.TextLabel.Text = displayName
		end)
	)
end

function Ui.spin(): string
	if isSpinning then
		return
	end
	isSpinning = true

	selection.Visible = true

	-- Spin effects
	local indexes = {}
	for i = 1, #prizeTiles do
		table.insert(indexes, i)
	end

	sounds.Open:Play()
	sounds.Intense:Play()

	local currentIndex, previousIndex = nil, nil
	for i = 5, 25 do
		-- Index selection
		local currentIndex = table.remove(indexes, math.random(#indexes))
		if previousIndex then
			table.insert(indexes, previousIndex)
		end
		previousIndex = currentIndex

		-- Higlight tile
		selection.Parent = prizeTiles[currentIndex]
		sounds.Select:Play()
		local pause = ((i - 15) / 15) ^ 2 + 0.05
		task.wait(pause)
	end

	local prize, typ = nil, nil
	local success, err = pcall(function()
		prize, typ = Spinner.clientRequestSpin()
		assert(prize, "A prize was not selected")
		sounds.Select:Play()
		sounds.Claim:Play()

		local awardSounds = prizeSounds.Types:FindFirstChild(typ)
		if awardSounds then
			for _, sound in awardSounds:GetChildren() do
				sound:Play()
			end
		end

		local flashTween = TweenService:Create(
			content.Flash,
			TweenInfo.new(0.3),
			{ BackgroundTransparency = 0.6 }
		)
		flashTween:Play()
		flashTween.Completed:Connect(function()
			TweenService
				:Create(
					content.Flash,
					TweenInfo.new(0.3),
					{ BackgroundTransparency = 1 }
				)
				:Play()
		end)

		-- Handle selected tile
		local selectedTile: Frame = currentTileMap[prize]
		selectedTile.ZIndex += 1
		selection.Parent = selectedTile
		local origionalSize = selectedTile.Size
		local scaledSize =
			UDim2.fromScale(origionalSize.X.Scale * 1.3, origionalSize.Y.Scale * 1.3)
		local sizeTween1 =
			TweenService:Create(selectedTile, TweenInfo.new(0.3), { Size = scaledSize })
		local sizeTween2 = TweenService:Create(
			selectedTile,
			TweenInfo.new(0.3),
			{ Size = origionalSize }
		)

		sizeTween1:Play()
		sizeTween1.Completed:Wait()
		sizeTween2:Play()
		sizeTween2.Completed:Wait()

		selectedTile.ZIndex -= 1
	end)

	isSpinning = false
	if not success then
		LOG:Warning(err)
		Interface.Notification.notify(
			"Failed to select a prize. Please try again.",
			{ Sound = "Error", Color = Color3.new(1, 0, 0), Title = "Error" }
		)
	end
	return prize
end

Ui.update()

canvas:GetPropertyChangedSignal("Visible"):Connect(function()
	if canvas.Visible then
		Ui.update()
	else
		badge.Visible = availableSpins > 0
	end
end)

for _, btn: ImageButton in content.Products:GetChildren() do
	btn.MouseButton1Click:Connect(function()
		promptProduct(tonumber(btn.Name))
	end)
end

content.Exit.MouseButton1Click:Connect(exit)
canvas.BackgroundButton.MouseButton1Click:Connect(exit)

sideButton.MouseButton1Click:Connect(function()
	Spinner.clientDisplayUi()
end)
