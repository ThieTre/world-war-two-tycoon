local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local PolicyService = game:GetService("PolicyService")
local Modules = ReplicatedStorage.Modules

local Interface = require(Modules.Mega.Interface)
local Logging = require(Modules.Mega.Logging)
local Table = require(Modules.Mega.DataStructures.Table)
local MiscUtils = require(Modules.Mega.Utils.Misc)
local Chests = require(Modules.Monetization.Chests)
local Cash = require(Modules.Monetization.Cash)
local BoostManager = require(Modules.Monetization.CashBoosts.Manager)
local MoneyUtils = require(Modules.Monetization.Utils)
local Prizes = require(Modules.Prizes.Utils)

local TIER_MAP = require(ReplicatedStorage.Settings.Game).TierMap
local LOG = Logging:new("Monetization.Chests")

local LocalPlayer = game.Players.LocalPlayer

-- Data
local chestInfo = Chests.getChestInfo()
local playerChests = Chests.getClientInventory()
local previousPrizes = Chests.getClientPreviousRewards()

local prizeIcons = {
	Vehicle = "rbxassetid://12623584303",
	Chest = "rbxassetid://17652185117",
	Gun = "rbxassetid://12403104094",
	Throwable = "rbxassetid://12403104094",
	Boost = "rbxassetid://17516102514",
	Cash = "rbxassetid://17652556933",
}

-- Ui elements
local frame = LocalPlayer.PlayerGui.Monetization:WaitForChild("Store").Frame.Chests
local openCanvas = frame.Parent.Parent.Parent.ChestOpen
local replicated = frame.Replicated
local mainButton = frame.Description.MainButton
local scroller = frame.ScrollingFrame
local prizeScroller = frame.Description.ScrollingFrame
local itemImage = frame.ItemImage
local tileSelection = replicated.Selection:Clone()

local pageLayout = frame.Parent.UIPageLayout
local event = frame.Parent.Parent.Event
local sounds = frame.Parent.Parent.Sounds

local playerPolicy = PolicyService:GetPolicyInfoForPlayerAsync(LocalPlayer)
--local canParticipate = not playerPolicy.ArePaidRandomItemsRestricted
local canParticipate = true -- TODO: revert this after testing

tileSelection.Visible = true

local function evaluateIconBadge()
	local totalCount = 0
	for _name, count in playerChests do
		totalCount += count
	end
	MoneyUtils.clientSetIconBadge("Chests", totalCount)
end

local function updatePlayerChests()
	playerChests = Chests.getClientInventory()
	previousPrizes = Chests.getClientPreviousRewards()
end

local Ui = {}

local displayConn: RBXScriptConnection = nil
function Ui.displayChest(name)
	if displayConn then
		displayConn:Disconnect()
	end

	-- Update item info
	local info = chestInfo[name]
	itemImage.Title.Text = name .. " Chest"
	itemImage.Image = info.Image

	-- Show tile selection
	tileSelection.Parent = scroller[name]
	sounds.Select:Play()

	-- Display prizes
	local alreadyWon = previousPrizes[name] or {}
	Interface.Utils.clearUiChildren(prizeScroller)
	prizeScroller.CanvasPosition = Vector2.new(0, 0)
	for _, prizeInfo in info.Prizes do
		local prizeName, prizeType, probability = unpack(prizeInfo)

		if table.find(alreadyWon, prizeName) then
			continue
		end

		local prizeTile = replicated.Tile:Clone()
		prizeTile.Icon.Visible = true
		prizeTile.Icon.Image = prizeIcons[prizeType]

		prizeTile.Probability.Text = "<" .. (math.ceil(probability / 0.05) * 5) .. "%"

		--prizeTile.Probability.Text = (probability * 100)..'%'
		prizeTile.Probability.Visible = true
		prizeTile.Name = prizeName

		-- Configure tile according to type
		local itemSettings = Prizes.getPrizeInfo(prizeName, prizeType)
		if prizeType == "Vehicle" then
			prizeTile.Image.Image = itemSettings.Image
			prizeTile.Image.ScaleType = Enum.ScaleType.Fit
			prizeTile.Glow.Visible = true
			prizeTile.BackgroundColor3 = TIER_MAP[itemSettings.Tier][2]
			prizeTile.UIStroke.Color = TIER_MAP[itemSettings.Tier][3]
		elseif prizeType == "Boost" then
			prizeTile.Image.Image = itemSettings.Image
			prizeTile.BackgroundColor3 = itemSettings.TileColor
			local h, s, v = itemSettings.TileColor:ToHSV()
			prizeTile.UIStroke.Color = Color3.fromHSV(h, s, v / 1.5)
			prizeTile.Hex.Visible = true
		elseif prizeType == "Chest" then
			prizeTile.Image.Image = itemSettings.Image
			prizeTile.BackgroundColor3 = TIER_MAP[itemSettings.Tier][2]
			prizeTile.UIStroke.Color = TIER_MAP[itemSettings.Tier][3]
			prizeTile.Chest.Visible = true
		elseif prizeType == "Cash" then
			prizeTile.Image.Image = itemSettings.Image
			prizeTile.BackgroundColor3 = itemSettings.TileColor
			local h, s, v = itemSettings.TileColor:ToHSV()
			prizeTile.UIStroke.Color = Color3.fromHSV(h, s, v / 1.5)
		elseif table.find({ "Gun", "Throwable" }, prizeType) then
			prizeTile.Image.ScaleType = Enum.ScaleType.Fit
			prizeTile.Image.Image = itemSettings.Game.Image
			prizeTile.BackgroundColor3 = TIER_MAP[itemSettings.Game.Tier][2]
			prizeTile.UIStroke.Color = TIER_MAP[itemSettings.Game.Tier][3]
		end
		prizeTile.Parent = prizeScroller
		prizeTile.Visible = true
	end

	-- Configure main button
	local ownCount = playerChests[name] or 0
	if ownCount > 0 then
		mainButton.Activate.Text = "OPEN"
		mainButton.BackgroundColor3 = Color3.new(1, 0.741176, 0.298039)
		displayConn = mainButton.MouseButton1Click:Connect(function()
			Ui.openChest(name)
		end)
	else
		mainButton.Activate.Text = "PURCHASE"
		mainButton.BackgroundColor3 = Color3.new(0, 0.741176, 0)
		displayConn = mainButton.MouseButton1Click:Connect(function()
			sounds.Purchase:Play()
			MarketService:PromptProductPurchase(LocalPlayer, info.Id)

			-- Wait for transaction to complete
			local purchaseConn
			purchaseConn = MarketService.PromptProductPurchaseFinished:Connect(
				function(_uid, productId, isPurchased)
					if not isPurchased then
						return
					end
					if productId == info.Id then
						sounds.Buy:Play()
						purchaseConn:Disconnect()
						-- Wait until the chest shows up in the player's data
						for i in MiscUtils.count() do
							updatePlayerChests()
							if not frame.Visible then
								return
							end
							if (playerChests[name] or 0) > 0 then
								break
							end
							if i > 5 / 0.01 then
								LOG:Error(
									"Failed to find purchased chest for user"
										.. LocalPlayer.UserId
								)
								break
							end
							task.wait(0.01)
						end
						Ui.updateScroller()
					end
				end
			)
		end)
	end
end

function Ui.addChestTile(name)
	local info = chestInfo[name]
	local tile = replicated.Tile:Clone()
	local ownedCount = playerChests[name] or 0

	-- Style
	tile.Name = name
	tile.Image.Image = info.Image
	tile.BackgroundColor3 = TIER_MAP[info.Tier][2]
	tile.UIStroke.Color = TIER_MAP[info.Tier][3]
	tile.Visible = true
	tile.Glow.Visible = true
	tile.Glow.LocalScript.Enabled = true
	tile.Chest.Visible = true

	if ownedCount > 0 then
		tile.Owned.Visible = true
		tile.Count.Text = ownedCount
		tile.Count.Visible = true
	end

	tile.Image.MouseButton1Click:Connect(function()
		Ui.displayChest(name)
	end)

	tile.Parent = scroller
end

function Ui.updateScroller(targetItem)
	--if not canParticipate then
	--	Interface.Notification.Notify(
	--		LocalPlayer,
	--		'Your account is not allowed to interact with paid random items.',
	--		{Sound='Error', Color=Color3.new(1, 0, 0), Title='Error'}
	--	)

	--	return
	--end

	Ui.clearScroller()
	updatePlayerChests()
	-- Sorting reference for chests
	local sortRef = Table.Keys(chestInfo)
	table.sort(sortRef, function(a, b)
		-- Compare price
		local aInfo = chestInfo[a]
		local bInfo = chestInfo[b]
		local aSortRef = aInfo.RobuxPrice
		local bSortRef = bInfo.RobuxPrice
		return aSortRef < bSortRef
	end)

	for i, name in sortRef do
		Ui.addChestTile(name)
		if targetItem then
			if name == targetItem then
				Ui.displayChest(name)
			end
		elseif i == 1 then
			Ui.displayChest(name)
		end
	end
end

function Ui.openChest(name)
	local sounds = openCanvas.Sounds
	local tile = scroller[name]
	local context = Interface.Context.Manager:GetContext("fullscreen")
	local image = openCanvas.Image

	local function exit()
		context:Hide(openCanvas, { EnterStyle = "Fade", ExitStyle = "Fade" })
		MoneyUtils.clientDisplayUi("Chests", { TargetItem = name })
	end

	-- Map the existing prize information
	local prizeInfo = {}
	for _, prizeTile in prizeScroller:GetChildren() do
		if not prizeTile:IsA("Frame") then
			continue
		end
		prizeInfo[prizeTile.Name] = {}
		prizeInfo[prizeTile.Name].Image = prizeTile.Image.Image
		prizeInfo[prizeTile.Name].Color = prizeTile.BackgroundColor3
	end

	-- Display
	openCanvas.Image.Image = chestInfo[name].Image
	openCanvas.BackgroundColor3 = tile.BackgroundColor3
	openCanvas["Under Glow"].UIGradient.Color = ColorSequence.new(tile.BackgroundColor3)
	openCanvas.Glow.ImageColor3 = tile.BackgroundColor3
	openCanvas.Radial.Visible = false
	openCanvas.Glow.Visible = true
	openCanvas.Button.Visible = false
	openCanvas.Duplicate.Visible = false
	openCanvas.Title.Text = name .. " Chest"
	openCanvas.Button.Visible = false
	openCanvas.Title.TextColor3 = tile.BackgroundColor3

	context:Show(openCanvas, 1, { EnterStyle = "Fade", ExitStyle = "Fade" })
	task.wait(0.2)

	-- Open chest effects
	sounds.Open1:Play()
	sounds.Open2:Play()
	local origionalSize = image.Size
	local scaledSize =
		UDim2.fromScale(origionalSize.X.Scale * 1.3, origionalSize.Y.Scale * 1.3)
	local sizeTween =
		TweenService:Create(image, TweenInfo.new(1.8), { Size = scaledSize })
	sizeTween:Play()
	local rotationDirection = 1
	local rotationAmount = 1
	local rotationSpeed = 0.05
	while sizeTween.PlaybackState == Enum.PlaybackState.Playing do
		image.Rotation = rotationAmount * rotationDirection
		task.wait(rotationSpeed)
		rotationDirection = -rotationDirection
	end
	image.Rotation = 0
	sounds.Complete:Play()
	image.Size = origionalSize

	-- Request server opening
	local prizeName, prizeType, isDuplicate = Chests.clientRequestChestOpen(name)
	if not prizeName then
		Interface.Notification.notify(
			"There was an error opening your chest. Please try again.",
			{ Sound = "Error", Color = Color3.new(1, 0, 0), Title = "Error" }
		)
		exit()
		return
	end

	-- Display
	if isDuplicate then
		openCanvas.Duplicate.Visible = true
	end
	image.Image = prizeInfo[prizeName].Image

	openCanvas.Title.Text = prizeName
	openCanvas.Glow.ImageColor3 = prizeInfo[prizeName].Color
	openCanvas.Glow.Visible = true
	openCanvas.Radial.Visible = true

	Color3.new(0, 0.533333, 0)

	local ftInfo = TweenInfo.new(0.2)
	openCanvas.Flash.BackgroundColor3 = tile.BackgroundColor3
	local flashTween =
		TweenService:Create(openCanvas.Flash, ftInfo, { BackgroundTransparency = 0.6 })
	flashTween:Play()
	flashTween.Completed:Connect(function()
		TweenService:Create(openCanvas.Flash, ftInfo, { BackgroundTransparency = 1 })
			:Play()
	end)

	if table.find({ "Gun", "Throwable" }, prizeType) then
		prizeType = "Tool"
	end
	local prizeSounds = sounds.Types:FindFirstChild(prizeType)
	if prizeSounds then
		for _, sound in prizeSounds:GetChildren() do
			sound:Play()
		end
	end

	-- Exit
	openCanvas.Button.Visible = true
	local exitConn = openCanvas.Button.MouseButton1Click:Once(function()
		exit()
	end)
	openCanvas:GetPropertyChangedSignal("Visible"):Connect(function()
		if exitConn.Connected then
			exitConn:Disconnect()
		end
	end)
end

function Ui.clearScroller()
	tileSelection.Parent = nil
	Interface.Utils.clearUiChildren(scroller)
end

-- =============== Connections ==============

evaluateIconBadge()

event.Event:Connect(function(typ, content)
	if typ == "DisplayPage" then
		if content["Frame"] == frame then
			pageLayout:JumpTo(frame)
			Ui.updateScroller(content["TargetItem"])
		end
	end
end)
