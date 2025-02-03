local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Modules = ReplicatedStorage.Modules

local Logging = require(Modules.Mega.Logging)
local Table = require(Modules.Mega.DataStructures.Table)
local InstModify = require(Modules.Mega.Instances.Modify)
local VehicleManager = require(Modules.TycoonGame.Vehicles.Manager)
local GameVehicleUtils = require(Modules.TycoonGame.Vehicles.Utils)
local TyUtils = require(Modules.Tycoons.Utils)
local Interface = require(Modules.Mega.Interface)

local SETTINGS = require(ReplicatedStorage.Settings.TycoonGame.Vehicles)
local PASS_VEHICLES =
	require(ReplicatedStorage.Settings.Monetization).GamePasses.Vehicles
local LOG = Logging:new("Vehicles UI")

local LocalPlayer = game.Players.LocalPlayer

local context = Interface.Context.Manager:GetContext("fullscreen")

-- Data
local tycoonName = TyUtils.waitForSystemName()
local tycoonMap = VehicleManager.Data.tycoonMap[tycoonName] -- mapping of tycoon vehicles
local infoMap = VehicleManager.Data.infoMap -- mapping of vehicles and settings
local variantMap = VehicleManager.Data.variantMap
local playerVehicles = VehicleManager.clientGetTycoonVehicles() -- array of the player's vehicles
local includeTypes = nil

-- Ui instances
local canvas = LocalPlayer.PlayerGui:WaitForChild("Stores").Vehicles
local frame = canvas.Frame
local infoFrame = frame.Info
local content = frame.Content
local variantsFrame = frame.Variants
local replicated = canvas.Replicated
local selectionBox = replicated.SelectionBox:Clone()
local varSelectionBox = replicated.SelectionBox:Clone()
local typSelectionBox = replicated.TypeSelectionBox

-- Other instances
local sounds = canvas.Sounds
local spawnerVal = InstModify.create("ObjectValue", canvas, { Name = "CurrentSpawner" })

local Ui = {}

-- =============== Functions ==============

-- --------- Misc -----------

local function getControlStat(info)
	if info.Type == "Car" then
		return math.round(
			(info.MaxAcceleration + info.TurnAngle) * (1 / info.WheelTurnTime)
		)
	else
		return math.round(info.RotationSpeed / 10)
	end
end

-- --------- Data -----------

local function updatePlayerVehicles()
	playerVehicles = VehicleManager.clientGetTycoonVehicles()
end

-- --------- Selection Box -----------

local function selectBasic(tile)
	if not tile then
		selectionBox.Parent = nil
		return
	end
	if not tile.Parent then
		return
	end
	if not varSelectionBox.Visible then
		varSelectionBox.Visible = true
	end
	selectionBox.Parent = tile
end

local function selectVariant(tile)
	if not tile then
		varSelectionBox.Parent = nil
		return
	end
	if not tile.Parent then
		return
	end
	if not selectionBox.Visible then
		selectionBox.Visible = true
	end
	varSelectionBox.Parent = tile
end

-- --------- Info -----------

local isInTransaction = false
local displayConn: RBXScriptConnection = nil
function Ui.updateDisplay(name, info, owned, isVariant, force)
	if name == frame.VehicleImage.Title.Text and not force then
		-- Already displaying
		return
	end
	if displayConn then
		displayConn:Disconnect()
	end
	local mainBtn = content.MainButton
	if not isVariant then
		Ui.updateVariantScroller(name)
	end
	if not name then
		-- Clear display and return
		frame.VehicleImage.Image = ""
		frame.VehicleImage.Title.Text = "N/A"
		frame.VehicleImage.BackgroundColor3 = SETTINGS.TierMap[1][2]
		frame.VehicleImage.UIStroke.Color = SETTINGS.TierMap[1][3]
		return
	end

	-- Tween background color
	TweenService:Create(
		canvas.UnderGlow,
		TweenInfo.new(0.3),
		{ ImageColor3 = SETTINGS.TierMap[info.Tier][3] }
	):Play()

	-- Update info
	frame.VehicleImage.Image = info.Image or ""
	frame.VehicleImage.Title.Text = name
	frame.VehicleImage.BackgroundColor3 = SETTINGS.TierMap[info.Tier][2]
	frame.VehicleImage.UIStroke.Color = SETTINGS.TierMap[info.Tier][3]
	infoFrame.Health.Value.Text = info.Health
	infoFrame.Speed.Value.Text = info.MaxSpeed
	infoFrame.Control.Value.Text = getControlStat(info)
	if not owned then
		local costFrame = infoFrame.Cost
		if info.IsRebirth then
			costFrame.UIStroke.Color = SETTINGS.RebirthColor
			costFrame.Value.TextColor3 = SETTINGS.RebirthColor
			costFrame.Value.Text = info.RebirthPrice .. " Rebirths"
		else
			costFrame.Value.TextColor3 = SETTINGS.CashColor
			costFrame.UIStroke.Color = SETTINGS.CashColor
			costFrame.Value.Text = "$" .. TyUtils.formatNumber(info.CashPrice)
		end
		costFrame.Visible = true
		mainBtn.BackgroundColor3 = Color3.new(0, 0.741176, 0)
		mainBtn.Text = "Purchase"
		displayConn = mainBtn.MouseButton1Click:Connect(function()
			if isInTransaction then
				return
			end
			isInTransaction = true
			local success = VehicleManager.clientRequestVehicleAdd(name)
			if success then
				sounds.Purchase:Play()
				updatePlayerVehicles()
				Ui.updateVehicleScroller()
				Ui.updateDisplay(name, info, true, isVariant, true)
			else
				mainBtn.BackgroundColor3 = Color3.new(0.776471, 0, 0)
				sounds.Error:Play()
				task.delay(1, function()
					mainBtn.BackgroundColor3 = Color3.new(0, 0.741176, 0)
				end)
			end
			isInTransaction = false
		end)
	else
		infoFrame.Cost.Visible = false
		mainBtn.BackgroundColor3 = Color3.new(0.941176, 0.721569, 0.00392157)
		mainBtn.Text = "Spawn"
		displayConn = mainBtn.MouseButton1Click:Connect(function()
			if isInTransaction then
				return
			end
			isInTransaction = true
			local spawner = spawnerVal.Value
			local success = VehicleManager.clientRequestVehicleSpawn(name, spawner)
			if success then
				sounds.Spawn:Play()
			end
			isInTransaction = false
		end)
	end
end

-- --------- Tiles -----------

function Ui.addVehicleTile(name, info, owned, locked)
	local tile = replicated.VehicleTile:Clone()
	if owned then
	else
		if locked then
			tile.Locked.Visible = true
		elseif info.IsRebirth then
			tile.Rebirth.Visible = true
		else
			tile.Purchase.Visible = true
		end
	end
	tile.ImageButton.Image = info.Image
	tile.BackgroundColor3 = SETTINGS.TierMap[info.Tier][2]
	tile.UIStroke.Color = SETTINGS.TierMap[info.Tier][3]
	if not locked then
		tile.ImageButton.MouseButton1Click:Connect(function()
			Ui.updateDisplay(name, info, owned)
			selectBasic(tile)
			sounds.Select:Play()
		end)
	end
	tile.Visible = true
	tile.Parent = content.ScrollingFrame
	return tile
end

function Ui.addVariantTile(name, info, owned)
	local tile = replicated.VariantTile:Clone()
	if owned then
	else
		if info.IsRebirth then
			tile.Rebirth.Visible = true
		else
			tile.Purchase.Visible = true
		end
	end
	tile.VehicleName.Text = name
	tile.ImageButton.Image = info.Image
	tile.BackgroundColor3 = SETTINGS.TierMap[info.Tier][2]
	tile.UIStroke.Color = SETTINGS.TierMap[info.Tier][3]
	tile.TextButton.MouseButton1Click:Connect(function()
		Ui.updateDisplay(name, info, owned, true)
		selectVariant(tile)
		sounds.VariantSelect:Play()
	end)
	tile.Visible = true
	tile.Parent = variantsFrame.ScrollingFrame
	return tile
end

-- --------- Scrollers -----------

function Ui.updateVehicleScrollerSpecial(typFilter: table?)
	-- Load the vehicles scroller with the special vehicles
	selectBasic(nil)
	content.Chest.Visible = false
	Interface.Utils.clearUiChildren(content.ScrollingFrame)
	local count = 0
	for _, vName in pairs(playerVehicles) do
		local vInfo = infoMap[vName]
		local isGamePass = PASS_VEHICLES[vName] ~= nil
		-- Conditions
		if not vInfo or not (vInfo.IsSpecial or isGamePass) then
			continue
		end
		if vInfo.VariantOf then
			continue
		end
		if typFilter and not table.find(typFilter, vInfo.Type) then
			continue
		end

		-- Add tile
		local tile = Ui.addVehicleTile(vName, vInfo, true, false)
		if count == 0 then
			Ui.updateDisplay(vName, vInfo, true)
			selectBasic(tile)
		end
		count += 1
	end
	if count == 0 then
		-- Nothing was displayed, clear display
		Ui.updateDisplay(nil)
		content.Chest.Visible = true
	end
end

function Ui.updateVehicleScroller()
	-- Load the vehicles scroller with the tycoon vehicles
	selectBasic(nil)
	content.Chest.Visible = false
	Interface.Utils.clearUiChildren(content.ScrollingFrame)
	local sortRef = Table.Keys(tycoonMap)
	table.sort(sortRef, function(a, b)
		local aInfo = infoMap[a]
		local bInfo = infoMap[b]
		local aSortRef = aInfo.CashPrice
		local bSortRef = bInfo.CashPrice
		if aInfo.IsRebirth then
			aSortRef = aInfo.RebirthPrice * 1e15
		end
		if bInfo.IsRebirth then
			bSortRef = bInfo.RebirthPrice * 1e15
		end
		return aSortRef < bSortRef
	end)
	local count = 0
	for _, vName in pairs(sortRef) do
		local vInfo = infoMap[vName]
		local vTycoonInfo = tycoonMap[vName]

		-- Conditions
		if not vInfo or vInfo.VariantOf then
			continue
		end
		if includeTypes and not table.find(includeTypes, vInfo.Type) then
			continue
		end

		-- Add tile
		local owned = table.find(playerVehicles, vName)
		local missingValues = Table.Difference(vTycoonInfo or {}, playerVehicles)
		local locked = not owned and next(missingValues)
		local tile = Ui.addVehicleTile(vName, vInfo, owned, locked)
		if count == 0 then
			Ui.updateDisplay(vName, vInfo, owned, false, true)
			selectBasic(tile)
		end
		count += 1
	end
	if count == 0 then
		-- Nothing was displayed, clear display
		Ui.updateDisplay(nil)
	end
end

function Ui.updateVariantScroller(vName)
	selectVariant(nil)
	Interface.Utils.clearUiChildren(variantsFrame.ScrollingFrame)
	if not vName then
		-- Clear the scroller
		return
	end
	-- Add tile for selected vehicle
	local firstTile = Ui.addVariantTile(vName, infoMap[vName], true)
	selectVariant(firstTile)
	-- Add other variants
	local variants = variantMap[vName]
	for i, varName in pairs(variants) do
		local owned = table.find(playerVehicles, varName)
		local vInfo = infoMap[varName]
		Ui.addVariantTile(varName, vInfo, owned)
	end
end

-- --------- Canvas -----------

local function hideUi()
	context:Hide(canvas, { ExitStyle = "Fade", EnterStyle = "Fade" })
end

local function showUi()
	updatePlayerVehicles()
	content.ScrollingFrame.CanvasPosition = Vector2.new(0, 0)
	typSelectionBox.Parent = content.TycoonButton
	typSelectionBox.Visible = true
	context:Show(canvas, 1, { EnterStyle = "Fade" })
	Ui.updateVehicleScroller()
	while canvas.Visible and spawnerVal.Value do
		local spawner = spawnerVal.Value
		local distance = LocalPlayer:DistanceFromCharacter(spawner.PromptPart.Position)
		if distance > SETTINGS.MaxSpawnPointDistance then
			GameVehicleUtils.clientSetUiDisplay(false)
			break
		end
		task.wait(0.5)
	end
end

-- =============== Connections ==============

-- Vehicle ownership type
content.TycoonButton.MouseButton1Click:Connect(function()
	content.ScrollingFrame.CanvasPosition = Vector2.new(0, 0)
	Ui.updateVehicleScroller()
	sounds.TypeSelect:Play()
	typSelectionBox.Parent = content.TycoonButton
end)

content.SpecialButton.MouseButton1Click:Connect(function()
	content.ScrollingFrame.CanvasPosition = Vector2.new(0, 0)
	Ui.updateVehicleScrollerSpecial()
	sounds.TypeSelect:Play()
	typSelectionBox.Parent = content.SpecialButton
end)

frame.Variants.ExitButton.MouseButton1Click:Connect(function()
	GameVehicleUtils.clientSetUiDisplay(false)
end)

canvas:SetAttribute("Display", false)

canvas:GetAttributeChangedSignal("Display"):Connect(function()
	local enabled = canvas:GetAttribute("Display")
	if enabled then
		LocalPlayer.Character.Humanoid:UnequipTools()
		showUi()
	else
		hideUi()
	end
end)
