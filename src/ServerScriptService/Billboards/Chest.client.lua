if not script.Parent.Parent then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Table = require(Modules.Mega.DataStructures.Table)
local InstSearch = require(Modules.Mega.Instances.Search)
local Chests = require(Modules.Monetization.Chests)
local PrizeUtils = require(Modules.Prizes.Utils)

local GAME_SETTINGS = require(ReplicatedStorage.Settings.Game)

local LocalPlayer = game.Players.LocalPlayer

local model = script.Parent
local main = model:WaitForChild("Main")
local imageLabel = model:WaitForChild("ImagePart").SurfaceGui.ImageLabel
local titleLabel = model:WaitForChild("Title").SurfaceGui.TextLabel
local tiles = InstSearch.getChildrenOfType(model.TilePart.SurfaceGui, "Frame")

local chestsInfo = Chests.getChestInfo()
local chestsNames = Table.Keys(chestsInfo)
local tinfo = TweenInfo.new(1)

local clickDetecor = Instance.new("ClickDetector")
clickDetecor.MaxActivationDistance = 100
clickDetecor.Parent = main

local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = ""
prompt.MaxActivationDistance = 15
prompt.RequiresLineOfSight = false
prompt.Parent = main

local currentTarget = chestsNames[1]
local function setupBoard()
	currentTarget = chestsNames[math.random(#chestsNames)]
	local chestInfo = chestsInfo[currentTarget]
	titleLabel.Text = currentTarget .. " Chest"
	imageLabel.Image = chestInfo.Image

	local color: Color3 = GAME_SETTINGS.TierMap[chestInfo.Tier][3]
	local h, s, v = color:ToHSV()
	TweenService:Create(model.Outline, tinfo, { Color = color }):Play()
	TweenService
		:Create(model.Main, tinfo, { Color = Color3.fromHSV(h, s, v / 1.5) })
		:Play()
	--model.Outline.Color = Color3.fromHSV(h, s, v)
	--model.Main.Color = Color3.fromHSV(h, s, v/1.5)

	-- Get top prizes
	local prizes = table.clone(chestInfo.Prizes)
	table.sort(prizes, function(a, b)
		local _, _, aProb = unpack(a)
		local _, _, bProb = unpack(b)
		return aProb < bProb
	end)

	for i, prizeTile in tiles do
		local prizeName, prizeType, _ = unpack(prizes[i])
		local prizeInfo = PrizeUtils.getPrizeInfo(prizeName, prizeType)

		prizeTile.Hex.Visible = false
		prizeTile.Chest.Visible = false

		if prizeType == "Vehicle" then
			prizeTile.Image.Image = prizeInfo.Image
			prizeTile.BackgroundColor3 =
				GAME_SETTINGS.TierMap[prizeInfo.Tier][2]
			prizeTile.UIStroke.Color = GAME_SETTINGS.TierMap[prizeInfo.Tier][3]
			prizeTile.Image.ScaleType = Enum.ScaleType.Fit
			prizeTile.Glow.Visible = true
		elseif prizeType == "Boost" then
			prizeTile.Image.Image = prizeInfo.Image
			prizeTile.BackgroundColor3 = prizeInfo.TileColor
			local h, s, v = prizeInfo.TileColor:ToHSV()
			prizeTile.UIStroke.Color = Color3.fromHSV(h, s, v / 1.5)
			prizeTile.Hex.Visible = true
		elseif prizeType == "Chest" then
			prizeTile.Image.Image = prizeInfo.Image
			prizeTile.BackgroundColor3 =
				GAME_SETTINGS.TierMap[prizeInfo.Tier][2]
			prizeTile.UIStroke.Color = GAME_SETTINGS.TierMap[prizeInfo.Tier][3]
			prizeTile.Chest.Visible = true
		elseif prizeType == "Cash" then
			prizeTile.Image.Image = prizeInfo.Image
			prizeTile.BackgroundColor3 = prizeInfo.TileColor
			local h, s, v = prizeInfo.TileColor:ToHSV()
			prizeTile.UIStroke.Color = Color3.fromHSV(h, s, v / 1.5)
		elseif table.find({ "Gun", "Throwable" }, prizeType) then
			prizeTile.Image.ScaleType = Enum.ScaleType.Fit
			prizeTile.Image.Image = prizeInfo.Image
			prizeTile.BackgroundColor3 =
				GAME_SETTINGS.TierMap[prizeInfo.Tier][2]
			prizeTile.UIStroke.Color = GAME_SETTINGS.TierMap[prizeInfo.Tier][3]
		end
	end
end

prompt.Triggered:Connect(function()
	Chests.clientDisplayUi("Chests", { TargetItem = currentTarget })
end)

clickDetecor.MouseClick:Connect(function()
	Chests.clientDisplayUi("Chests", { TargetItem = currentTarget })
end)

while true do
	setupBoard()
	task.wait(12)
end
