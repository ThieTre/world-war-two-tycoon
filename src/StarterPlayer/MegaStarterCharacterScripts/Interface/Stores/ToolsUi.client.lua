local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Modules = ReplicatedStorage.Modules

local Logging = require(Modules.Mega.Logging)
local Table = require(Modules.Mega.DataStructures.Table)
local Interface = require(Modules.Mega.Interface)
local InstModify = require(Modules.Mega.Instances.Modify)
local TyUtils = require(Modules.Tycoons.Utils)
local ToolManager = require(Modules.TycoonGame.Tools.Manager)
local Backpack = require(Modules.Backpack)
local GameToolUtils = require(Modules.TycoonGame.Tools.Utils)

local SETTINGS = require(ReplicatedStorage.Settings.TycoonGame.Tools)
local PASS_TOOLS = require(ReplicatedStorage.Settings.Monetization).GamePasses.Tools
local LOG = Logging:new("Tools UI")

local LocalPlayer = game.Players.LocalPlayer
local context = Interface.Context.Manager:GetContext("fullscreen")

-- Data
local tycoonName = TyUtils.waitForSystemName()
local tycoonMap = ToolManager.Data.tycoonMap[tycoonName] -- mapping of tycoon tools
local infoMap = ToolManager.Data.infoMap -- mapping of tools and settings
local variantMap = ToolManager.Data.variantMap
local playerTools = ToolManager.clientGetTycoonTools() -- array of the player's tools

-- Ui instances
local canvas = LocalPlayer.PlayerGui:WaitForChild("Stores").Guns
local frame = canvas.Frame
local infoFrame = frame.Info
local content = frame.Content
local variantsFrame = frame.Variants
local replicated = canvas.Replicated
local selectionBox = replicated.SelectionBox
local varSelectionBox = selectionBox:Clone()
local typSelectionBox = replicated.TypeSelectionBox
local toolTypeSelectionBox = selectionBox:Clone()
toolTypeSelectionBox.UICorner.CornerRadius = UDim.new(0.2, 0)

-- Other instances
local sounds = canvas.Sounds
local currentClass = "Rifle"

local spawnerVal = InstModify.create("ObjectValue", canvas, { Name = "CurrentSpawner" })

local Ui = {}

-- =============== Functions ==============

-- --------- Misc -----------

local function getControlStat(info)
	return math.round(
		(
			(
				info.Caster.MaxSpread
				+ info.Gun.HorizontalRecoil
				+ info.Gun.VerticalRecoil
			) * info.Gun.RecoilRecoverTime
		) * 10
	)
end

local function isToolOrVariantEquipped(name)
	local isVariantParent = false
	local isEquipped = false
	for slot, info in Backpack.slotMap do
		local equippedToolInfo = infoMap[info.name]
		if equippedToolInfo.VariantOf == name then
			isVariantParent = true
		elseif name == info.name then
			isEquipped = true
		end
	end
	return isVariantParent or isEquipped
end

-- --------- Data -----------

local function updatePlayerTools()
	playerTools = ToolManager.clientGetTycoonTools()
end

-- --------- Selection box -----------

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
	sounds.Select:Play()
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
	sounds.VariantSelect:Play()
	varSelectionBox.Parent = tile
end

-- --------- Info -----------
local lastEquip = 0
local isInTransaction = false
local displayConn: RBXScriptConnection = nil
function Ui.updateDisplay(name, info, owned, force, ignoreVariants)
	if name == frame.ToolImage.Title.Text and not force then
		-- Already displaying
		return
	end
	if displayConn then
		displayConn:Disconnect()
	end
	local mainBtn = content.MainButton

	if not name then
		-- Clear display and return
		frame.ToolImage.Image = ""
		frame.ToolImage.Title.Text = "N/A"
		frame.ToolImage.BackgroundColor3 = SETTINGS.TierMap[1][2]
		frame.ToolImage.UIStroke.Color = SETTINGS.TierMap[1][3]
		return
	end

	if not ignoreVariants then
		-- Update variants scroller
		local parentName = info.VariantOf or name
		Ui.updateVariantScroller(parentName, table.find(playerTools, parentName))
	end

	-- Tween background color
	TweenService:Create(
		canvas.UnderGlow,
		TweenInfo.new(0.3),
		{ ImageColor3 = SETTINGS.TierMap[info.Game.Tier][3] }
	):Play()

	-- Update info
	frame.ToolImage.Image = info.Image or ""
	frame.ToolImage.Title.Text = name
	frame.ToolImage.BackgroundColor3 = SETTINGS.TierMap[info.Game.Tier][2]
	frame.ToolImage.UIStroke.Color = SETTINGS.TierMap[info.Game.Tier][3]

	local hitMults = info.Damage.HitMultipliers
	infoFrame.Damage.Value.Text =
		math.round(info.Damage.Damage * (hitMults and (hitMults.Player or 1)) or 1)
	infoFrame.Rate.Value.Text = info.Gun.FireRate
	infoFrame.Control.Value.Text = getControlStat(info)

	if not owned then
		local costFrame = infoFrame.Cost
		if info.Game.IsRebirth then
			costFrame.UIStroke.Color = SETTINGS.RebirthColor
			costFrame.Value.TextColor3 = SETTINGS.RebirthColor
			costFrame.Value.Text = info.Game.RebirthPrice .. " Rebirths"
		else
			costFrame.Value.TextColor3 = SETTINGS.CashColor
			costFrame.UIStroke.Color = SETTINGS.CashColor
			costFrame.Value.Text = "$" .. TyUtils.formatNumber(info.Game.CashPrice)
		end
		costFrame.Visible = true
		mainBtn.BackgroundColor3 = Color3.new(0, 0.741176, 0)
		mainBtn.Text = "Purchase"
		displayConn = mainBtn.MouseButton1Click:Connect(function()
			if isInTransaction then
				return
			end
			isInTransaction = true
			local success = ToolManager.clientRequestToolAdd(name)
			if success then
				sounds.Purchase:Play()
				updatePlayerTools()
				Ui.updateToolScroller(name)
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
		mainBtn.Text = "EQUIP"
		if Backpack:GetSlot(name) then
			-- Already equipped
			mainBtn.BackgroundColor3 = Color3.new(0.223529, 0.32549, 1)
			mainBtn.Text = "EQUIPPED"
			return
		end
		displayConn = mainBtn.MouseButton1Click:Connect(function()
			if os.clock() - lastEquip < 0.5 then
				return
			end
			lastEquip = os.clock()
			local success = ToolManager.clientRequestToolEquip(name, spawnerVal.Value)
			if success then
				sounds.Spawn:Play()
				sounds.Equip:Play()
				while not Backpack:GetSlot(name) do
					task.wait()
				end
				Ui.updateToolScroller(name)
			end
		end)
	end
end

-- --------- Tiles -----------

function Ui.addToolTile(name, info, owned, locked)
	local tile = replicated.ToolTile:Clone()
	if not owned then
		if locked then
			tile.Locked.Visible = true
		elseif info.Game.IsRebirth then
			tile.Rebirth.Visible = true
		else
			tile.Purchase.Visible = true
		end
	end
	tile.ImageButton.Image = info.Game.Image
	tile.BackgroundColor3 = SETTINGS.TierMap[info.Game.Tier][2]
	tile.UIStroke.Color = SETTINGS.TierMap[info.Game.Tier][3]
	if not locked then
		tile.ImageButton.MouseButton1Click:Connect(function()
			Ui.updateDisplay(name, info, owned)
			selectionBox.Visible = true
			selectBasic(tile)
		end)
	end

	-- Determine if tool or variant is equipped
	local isEquipped = isToolOrVariantEquipped(name)

	if isEquipped then
		tile.Equipped.Visible = true
	else
		tile.Equipped.Visible = false
	end

	tile.Visible = true
	tile.Parent = content.ScrollingFrame

	return tile
end

function Ui.addVariantTile(name, info, owned, parentOwned)
	local tile = replicated.VariantTile:Clone()
	if not parentOwned then
		tile.Locked.Visible = true
	elseif not owned then
		if info.Game.IsRebirth then
			tile.Rebirth.Visible = true
		else
			tile.Purchase.Visible = true
		end
	end

	if Backpack:GetSlot(name) then
		tile.Equipped.Visible = true
		tile.ToolName.Visible = false
	end

	tile.ToolName.Text = name
	tile.ImageButton.Image = info.Game.Image
	tile.BackgroundColor3 = SETTINGS.TierMap[info.Game.Tier][2]
	tile.UIStroke.Color = SETTINGS.TierMap[info.Game.Tier][3]
	tile.TextButton.MouseButton1Click:Connect(function()
		Ui.updateDisplay(name, info, owned, false, true)
		selectVariant(tile)
	end)
	tile.Visible = true
	tile.Parent = variantsFrame.ScrollingFrame
	return tile
end

-- --------- Scrollers -----------

function Ui.updateToolScrollerSpecial()
	-- Load the tools scroller with the special tools
	typSelectionBox.Parent = content.SpecialButton
	content.Chest.Visible = false
	selectBasic(nil)
	Interface.Utils.clearUiChildren(content.ScrollingFrame)
	local count = 0
	for _, tName in pairs(playerTools) do
		local tInfo = infoMap[tName]
		local isGamePass = PASS_TOOLS[tName] ~= nil

		-- Conditions
		if not tInfo or not (tInfo.Game.IsSpecial or isGamePass) then
			continue
		end
		if tInfo.Game.VariantOf then
			continue
		end
		--if tInfo.Game.Class ~= currentClass then
		--	continue
		--end

		-- Add tile
		local tile = Ui.addToolTile(tName, tInfo, true, false)
		if count == 0 then
			Ui.updateDisplay(tName, tInfo, true, true)
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

function Ui.updateToolScroller(target)
	-- Load the tools scroller with the tycoon tools
	content.Chest.Visible = false
	selectBasic(nil)
	typSelectionBox.Parent = content.TycoonButton
	Interface.Utils.clearUiChildren(content.ScrollingFrame)
	local sortRef = Table.Keys(tycoonMap)
	table.sort(sortRef, function(a, b)
		local aInfo = infoMap[a].Game
		local bInfo = infoMap[b].Game
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
	for _, tName in pairs(sortRef) do
		local tInfo = infoMap[tName]
		local tTycoonInfo = tycoonMap[tName]
		-- Conditions
		if not tInfo or tInfo.Game.VariantOf then
			continue
		end
		if tInfo.Game.Class ~= currentClass then
			continue
		end
		-- Add tile
		local owned = table.find(playerTools, tName)
		local missingValues = Table.Difference(tTycoonInfo or {}, playerTools)
		local locked = not owned and next(missingValues)
		local tile = Ui.addToolTile(tName, tInfo, owned, locked)

		-- Find out if this tool or any of it variants are equipped
		local isEquipped = isToolOrVariantEquipped(tName)

		if isEquipped then
			-- Display equipped tool/variant
			Ui.updateDisplay(tName, infoMap[tName], true, true)
			selectBasic(tile)
		end

		-- Select first option if needed
		if count == 0 and not isEquipped then
			Ui.updateDisplay(tName, tInfo, owned, true)
			selectBasic(tile)
		end
		count += 1
	end
	if count == 0 then
		-- Nothing was displayed, clear display
		Ui.updateDisplay(nil)
	end
end

function Ui.updateVariantScroller(tName, parentOwned)
	selectVariant(nil)
	Interface.Utils.clearUiChildren(variantsFrame.ScrollingFrame)
	if not tName then
		return
	end

	local sortRef = table.clone(variantMap[tName])
	table.insert(sortRef, tName) -- add the general tool as first variant
	table.sort(sortRef, function(a, b)
		local aInfo = infoMap[a].Game
		local bInfo = infoMap[b].Game
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

	for i, varName in pairs(sortRef) do
		local owned = table.find(playerTools, varName)
		local vInfo = infoMap[varName]
		local varTile = Ui.addVariantTile(varName, vInfo, owned, parentOwned)
	end
end

-- --------- Canvas -----------

local function hideUi()
	context:Hide(canvas, { ExitStyle = "Fade", EnterStyle = "Fade" })
end

local function showUi()
	updatePlayerTools()
	content.ScrollingFrame.CanvasPosition = Vector2.new(0, 0)
	typSelectionBox.Parent = content.TycoonButton
	typSelectionBox.Visible = true
	context:Show(canvas, 1, { EnterStyle = "Fade" })
	Ui.updateToolScroller()

	while canvas.Visible and spawnerVal.Value do
		local distance =
			LocalPlayer:DistanceFromCharacter(spawnerVal.Value.PromptPart.Position)
		if distance > SETTINGS.MaxSpawnPointDistance then
			GameToolUtils.clientSetUiDisplay(false)
			break
		end
		task.wait(0.5)
	end
end

-- =============== Connections ==============

-- Tool ownership type
content.TycoonButton.MouseButton1Click:Connect(function()
	content.ScrollingFrame.CanvasPosition = Vector2.new(0, 0)
	Ui.updateToolScroller()
	sounds.TypeSelect:Play()
	--typSelectionBox.Parent = content.TycoonButton
end)

content.SpecialButton.MouseButton1Click:Connect(function()
	content.ScrollingFrame.CanvasPosition = Vector2.new(0, 0)
	Ui.updateToolScrollerSpecial()
	sounds.TypeSelect:Play()
	--typSelectionBox.Parent = content.SpecialButton
end)

frame.Variants.ExitButton.MouseButton1Click:Connect(function()
	GameToolUtils.clientSetUiDisplay(false)
end)

for _, btn in pairs(frame.Class.ScrollingFrame:GetChildren()) do
	if not btn:IsA("GuiButton") then
		continue
	end
	btn.MouseButton1Click:Connect(function()
		content.ScrollingFrame.CanvasPosition = Vector2.new(0, 0)
		currentClass = btn.Name
		toolTypeSelectionBox.Parent = btn
		if not toolTypeSelectionBox.Visible then
			toolTypeSelectionBox.Visible = true
		end
		sounds.GunTypeSelect:Play()
		Ui.updateToolScroller()
	end)
end

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
