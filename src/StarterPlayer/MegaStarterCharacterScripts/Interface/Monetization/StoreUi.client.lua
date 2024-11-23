local ReplicatedStorage = game:GetService('ReplicatedStorage')
local MarketService = game:GetService("MarketplaceService")
local Modules = ReplicatedStorage.Modules

local ContextManager = require(Modules.Mega.Interface.Context).Manager
local MoneyUtils = require(game.ReplicatedStorage.Modules.Monetization.Utils)

local LocalPlayer = game.Players.LocalPlayer

local canvas = LocalPlayer.PlayerGui:WaitForChild('Monetization').Store
local frame = canvas.Frame
local shopButton = LocalPlayer.PlayerGui.Main.SideButtons.Z.Shop
local pageLayout = frame.UIPageLayout
local whooshSound = frame.Parent.Sounds.Whoosh

local context = ContextManager:GetContext('fullscreen')
local event = canvas.Event


local function exit()
	if pageLayout.CurrentPage == frame.Home then
		context:Hide(canvas, {ExitStyle='Fade', EnterStyle='Fade'})
	else
		pageLayout:JumpTo(frame.Home)
	end
end

for _, tile: Frame in frame.Home:GetChildren() do
	if not tile:IsA('Frame') then
		continue
	end
	local button: TextButton = tile:FindFirstChild('Button')
	if not button then
		continue
	end
	if frame:FindFirstChild(tile.Name) then 
		-- Click to change screen
		button.MouseButton1Click:Connect(function()
			local targetFrame = frame[tile.Name]
			event:Fire('DisplayPage', {Frame=targetFrame})
		end)
	elseif tile:GetAttribute('PassId') then
		-- Pass tile
		button.MouseButton1Click:Connect(function()
			MarketService:PromptGamePassPurchase(LocalPlayer, tile:GetAttribute('PassId'))
		end)
	end

end

pageLayout:GetPropertyChangedSignal('CurrentPage'):Connect(function()
	whooshSound.PlaybackSpeed = math.random(85, 110)/100
	whooshSound:Play()
end)



canvas.BackgroundButton.MouseButton1Click:Connect(exit)
canvas.Frame.Home.Exit.MouseButton1Click:Connect(exit)
shopButton.MouseButton1Click:Connect(function()
	MoneyUtils.clientDisplayUi()
end)





