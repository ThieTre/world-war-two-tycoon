if not script.Parent.Parent then
	return
end

local Modules = game:GetService("ReplicatedStorage").Modules

local BoostManager = require(Modules.Monetization.CashBoosts.Manager)
local Table = require(Modules.Mega.DataStructures.Table)
local InstSearch = require(Modules.Mega.Instances.Search)

local LocalPlayer = game.Players.LocalPlayer

local model = script.Parent
local main = model
local tiles = InstSearch.getChildrenOfType(model.TilePart.SurfaceGui, 'Frame') 
local boostsInfo = BoostManager.getBoostInfo()

local clickDetecor = Instance.new('ClickDetector')
clickDetecor.MaxActivationDistance = 100
clickDetecor.Parent = main


local sortRef = Table.Keys(boostsInfo)
table.sort(sortRef, function(a, b)

	-- Compare price
	local aInfo = boostsInfo[a]
	local bInfo = boostsInfo[b]
	local aSortRef = aInfo.RobuxPrice
	local bSortRef = bInfo.RobuxPrice
	return aSortRef < bSortRef
end)

for i, tile in tiles do

	local name = sortRef[(#sortRef - #tiles) + i]
	if not name then
		continue
	end
	local boostInfo = boostsInfo[name]
	tile.Image.Image = boostInfo.Image
	tile.Percentage.Text = (1 + boostInfo.BoostRatio)..'X'
	
	tile.BackgroundColor3 = boostInfo.TileColor
	local h, s, v = boostInfo.TileColor:ToHSV()
	tile.UIStroke.Color = Color3.fromHSV(h, s, v/1.5)
	
end

if not model:GetAttribute('IgnorePrompt') then
	local prompt = Instance.new('ProximityPrompt')
	prompt.ActionText = ''
	prompt.MaxActivationDistance = 15
	prompt.RequiresLineOfSight = false
	prompt.Parent = main
	prompt.Triggered:Connect(function()
		BoostManager.clientDisplayUi('Cash')
	end)
end


clickDetecor.MouseClick:Connect(function()
	BoostManager.clientDisplayUi('Cash')
end)
