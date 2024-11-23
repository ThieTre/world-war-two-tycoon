local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketService = game:GetService("MarketplaceService")
local Modules = ReplicatedStorage.Modules

local Logging = require(Modules.Mega.Logging)
local Table = require(Modules.Mega.DataStructures.Table)
local MiscUtils = require(Modules.Mega.Utils.Misc)
local InterfaceUtils = require(Modules.Mega.Interface.Utils)
local BoostManager = require(Modules.Monetization.CashBoosts.Manager)
local Cash = require(Modules.Monetization.Cash)
local TyUtils = require(Modules.Tycoons.Utils)

local LocalPlayer = game.Players.LocalPlayer

local SETTINGS = require(ReplicatedStorage.Settings.Monetization)
local LOG = Logging:new('Monetization.Cash')
local BOOST_DESC = 'Activate a cash boost to earn additional income in your tycoon while you play!'
local CASH_DESC = 'Purchase cash to immediately add to your current tycoon balance!'

-- Ui elements
local frame = LocalPlayer.PlayerGui.Monetization:WaitForChild('Store').Frame.Cash.Cash
local replicated = frame.Parent.Replicated
local boostsButton = frame.BoostButton
local cashButton = frame.CashButton
local mainButton = frame.Description.MainButton
local scroller = frame.ScrollingFrame
local activeScroller = frame.Parent["Active Boosts"].ScrollingFrame
local itemImage = frame.ItemImage
local description = frame.Description.TextLabel
local boostsFrame = frame.Boosts
local cashFrame = frame.Cash

local sounds = frame.Parent.Parent.Parent.Sounds
local event = frame.Parent.Parent.Parent.Event
local pageLayout = frame.Parent.Parent.UIPageLayout

local choiceSelection = replicated.Selection:Clone()
local tileSelection = replicated.Selection:Clone()

-- Data
local cashInfo = Cash.getCashInfo()
local boostInfo = BoostManager.getBoostInfo()
local playerBoosts = BoostManager.getClientInventory()

-- Sorting reference for cash info
local cashSortRef = Table.Keys(cashInfo)
table.sort(cashSortRef, function(a, b)
	local aInfo = cashInfo[a]
	local bInfo = cashInfo[b]
	local aSortRef = aInfo.RobuxPrice
	local bSortRef = bInfo.RobuxPrice
	return aSortRef < bSortRef
end)



choiceSelection.Visible = true
tileSelection.Visible = true

local function updatePlayerBoosts()
	playerBoosts = BoostManager.getClientInventory()
end


local function formatDuration(minutes, useAbv)
	if minutes == 60 then
		return (useAbv and '1 hr') or '1 Hour'
	elseif minutes > 60 then
		local hours = math.round(minutes*100/60)/100 
		return hours .. ((useAbv and ' hr') or ' Hours')
	else
		return minutes .. ((useAbv and ' min') or ' Minutes')
	end
end

local Ui = {}


-- =============== Display ==============

local displayConn: RBXScriptConnection = nil
function Ui.displayBoost(name, id)
	if displayConn then
		displayConn:Disconnect()
	end

	local info = boostInfo[name]

	-- Tile selection
	local tile = scroller[name]
	tileSelection.Parent = tile
	sounds.Select:Play()

	-- Style
	boostsFrame.Percent.Text = (1 + info.BoostRatio)..'X'
	boostsFrame.Duration.Text = formatDuration(info.BoostDuration)
	itemImage.Image = info.Image
	itemImage.Title.Text = name
	mainButton.Price.Robux.Text = info.RobuxPrice

	if id then

		-- Count active boosts
		local activeCount = 0
		for _id, info in playerBoosts do
			if info.IsActive then
				activeCount += 1
			end
		end

		mainButton.Activate.Visible = true
		mainButton.Price.Visible = false
		mainButton.Locked.Visible = false

		if activeCount >= SETTINGS.CashBoosts.MaxActiveBoosts then
			-- Format main button
			mainButton.BackgroundColor3 = Color3.new(0.584314, 0.584314, 0.584314)
			mainButton.Locked.Visible = true
			mainButton.Activate.Text = 'MAX ACTIVATED'
		else
			-- Format main button
			mainButton.BackgroundColor3 = Color3.new(1, 0.741176, 0.298039)
			mainButton.Activate.Text = 'ACTIVATE'
			displayConn =  mainButton.MouseButton1Click:Connect(function()
				displayConn:Disconnect()
				local success = BoostManager.clientRequestActivation(id)
				Ui.updateBoostScroller(name)
			end)
		end
	else

		-- Format main button
		mainButton.BackgroundColor3 = Color3.new(1, 0.47451, 0.482353)
		mainButton.Activate.Visible = false
		mainButton.Price.Visible = true

		displayConn = mainButton.MouseButton1Click:Connect(function()
			sounds.Purchase:Play()
			MarketService:PromptProductPurchase(LocalPlayer, info.Id)
			-- Wait for transaction to complete
			local purchaseConn
			purchaseConn = MarketService.PromptProductPurchaseFinished:Connect(function(_uid, productId, isPurchased)
				if productId ~= info.Id or not isPurchased then
					return
				end
				sounds.Buy:Play()
				purchaseConn:Disconnect()
				-- Wait until the boost id shows up in the player's data
				for i in MiscUtils.count() do
					updatePlayerBoosts()
					local found = false
					for id, info in playerBoosts do
						if info.Name == name then
							-- Boost found
							found = true
							break
						end
					end
					if found then
						break
					end
					if i > 5/0.1 then
						LOG:Error('Failed to find purchased boost for user ' .. LocalPlayer.UserId)
						break
					end
					task.wait(0.1)
				end
				Ui.updateBoostScroller()
			end)
		end)
	end
end

function Ui.displayCash(name)
	if displayConn then
		displayConn:Disconnect()
	end

	local info = cashInfo[name]

	-- Tile selection
	local tile = scroller[name]
	tileSelection.Parent = tile
	sounds.Select:Play()

	-- Style
	cashFrame.Cash.Text = '$'..TyUtils.formatNumber(info.Value)
	itemImage.Image = info.Image
	itemImage.Title.Text = name
	mainButton.Price.Robux.Text = info.RobuxPrice

	displayConn = mainButton.MouseButton1Click:Connect(function()
		sounds.Purchase:Play()
		MarketService:PromptProductPurchase(LocalPlayer, info.Id)
	end)
end

-- =============== Tile ==============

function Ui.addBoostTile(name)
	local id = nil
	local ownedCount = 0
	local info = boostInfo[name]
	for ownedId, ownedInfo in playerBoosts do
		-- Check to see if a player owns an inactive boost of this type,
		-- if so, allow its activation by passing its id
		if not ownedInfo.IsActive and ownedInfo.Name == name then
			ownedCount += 1
			if not id then
				id = ownedId
			end
		end
	end

	local owned = ownedCount > 0

	local tile = replicated.Tile:Clone()

	-- Style
	tile.Name = name
	tile.Owned.Visible = owned 
	tile.Image.Image = info.Image
	tile.Icon.Visible = true
	tile.Hex.LocalScript.Enabled = not owned
	tile.BackgroundColor3 = info.TileColor
	local h, s, v = info.TileColor:ToHSV()
	tile.UIStroke.Color = Color3.fromHSV(h, s, v*1.5)
	tile.Visible = true
	if ownedCount > 0 then
		tile.Count.Visible = true
		tile.Count.Text = ownedCount
	end

	tile.Image.MouseButton1Click:Connect(function()
		Ui.displayBoost(name, id)
	end)

	tile.Parent = scroller

	return tile, id
end

function Ui.addCashTile(name)
	local info = cashInfo[name]

	local tile = replicated.Tile:Clone()

	-- Style
	tile.Icon.Visible = false
	tile.Name = name
	tile.Image.Image = info.Image
	tile.BackgroundColor3 = info.TileColor
	local h, s, v = info.TileColor:ToHSV()
	tile.UIStroke.Color = Color3.fromHSV(h, s, v*1.5)
	tile.Visible = true

	tile.Image.MouseButton1Click:Connect(function()
		Ui.displayCash(name)
	end)

	tile.Parent = scroller

	return tile
end

function Ui.addActiveBoostTile(image, remaingDuration)
	local tile = replicated.ActiveTile:Clone()
	tile.Duration.Text = formatDuration(remaingDuration, true)
	tile.Image.Image = image
	tile.Visible = true
	tile.Parent = activeScroller

	task.spawn(function()
		while tile.Parent and remaingDuration > 0 do
			task.wait(60)
			remaingDuration -= 1
			if tile.Parent then
				tile.Duration.Text = formatDuration(remaingDuration, true)
			end
		end
		tile:Destroy()
	end)
end



-- =============== Scroller ==============

local updatingBoostScroller = false
function Ui.updateBoostScroller(targetItem)
	if updatingBoostScroller then
		return
	end
	updatingBoostScroller = true
	Ui.clearScroller()
	updatePlayerBoosts()
	Ui.updateActiveBoostsScroller()

	-- Sorting reference for boost info
	local sortRef = Table.Keys(boostInfo)
	table.sort(sortRef, function(a, b)

		-- Compare price
		local aInfo = boostInfo[a]
		local bInfo = boostInfo[b]
		local aSortRef = aInfo.RobuxPrice
		local bSortRef = bInfo.RobuxPrice
		return aSortRef < bSortRef

	end)

	-- Add tiles
	for i, name in sortRef do
		local _tile, id = Ui.addBoostTile(name)
		if targetItem then
			if name == targetItem then
				Ui.displayBoost(name, id)
			end
		elseif i == 1 then
			Ui.displayBoost(name, id)
		end
	end
	updatingBoostScroller = false
end

function Ui.updateCashScroller(targetItem)
	Ui.clearScroller()
	for i, name in cashSortRef do
		Ui.addCashTile(name)
		if targetItem then
			if name == targetItem then
				Ui.displayCash(name)
			end
		elseif i == 1 then
			Ui.displayCash(name)
		end
	end
end

function Ui.updateActiveBoostsScroller()
	InterfaceUtils.clearUiChildren(activeScroller)
	for _id, info in playerBoosts do
		if not info.IsActive then
			continue
		end
		Ui.addActiveBoostTile(boostInfo[info.Name].Image, info.RemainingDuration)
	end
end

function Ui.clearScroller()
	tileSelection.Parent = nil
	InterfaceUtils.clearUiChildren(scroller)
end

-- =============== Choice ==============

function Ui.selectBoosts()
	if displayConn then
		displayConn:Disconnect()
	end
	scroller.CanvasPosition = Vector2.new(0, 0)
	sounds.Toggle:Play()
	cashButton.ZIndex = 10
	boostsButton.ZIndex = 11
	choiceSelection.Parent = boostsButton
	description.Text = BOOST_DESC
	boostsFrame.Visible = true
	cashFrame.Visible = false
	Ui.updateBoostScroller()
end

function Ui.selectCash()
	scroller.CanvasPosition = Vector2.new(0, 0)
	if displayConn then
		displayConn:Disconnect()
	end
	sounds.Toggle:Play()
	cashButton.ZIndex = 11
	boostsButton.ZIndex = 10
	choiceSelection.Parent = cashButton
	description.Text = CASH_DESC
	mainButton.Locked.Visible = false
	mainButton.Activate.Visible = false
	mainButton.Price.Visible = true
	mainButton.BackgroundColor3 = Color3.new(1, 0.47451, 0.482353)
	boostsFrame.Visible = false
	cashFrame.Visible = true
	Ui.updateCashScroller()

end

-- =============== Connections ==============

boostsButton.MouseButton1Click:Connect(Ui.selectBoosts)

cashButton.MouseButton1Click:Connect(Ui.selectCash)

BoostManager.evaluateIconBadge(playerBoosts)

event.Event:Connect(function(typ, content)
	if typ == 'DisplayPage' then
		if content['Frame'] == frame.Parent then
			pageLayout:JumpTo(frame.Parent)
			local choice = content['Choice'] or 'Boosts'
			local item = content['TargetItem']
			Ui['select'..choice](item)
		end
	end
end)

mainButton.MouseButton1Click:Connect(function()
	sounds.Purchase:Play()
end)

