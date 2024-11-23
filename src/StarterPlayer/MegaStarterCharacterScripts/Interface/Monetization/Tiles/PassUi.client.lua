local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local MarketService = game:GetService('MarketplaceService')

local LocalPlayer = game.Players.LocalPlayer

local PASS_MAP = require(ReplicatedStorage.Settings.Monetization.GamePasses)

local frame = LocalPlayer.PlayerGui:WaitForChild('Monetization').Store.Frame["Game Pass"]
local event = frame.Parent.Parent.Event
local pageLayout = frame.Parent.UIPageLayout

local rows = {}
for _, item in frame.Frame:GetChildren() do
	if not item:IsA('Frame') then
		continue
	end
	local scroller = item.ScrollingFrame
	
	for _name, passInfo in PASS_MAP[item.Name] do
		local passId, image = unpack(passInfo)
		local tile = Instance.new('ImageButton')
		local aspectConstraint = Instance.new('UIAspectRatioConstraint')
		local corner = Instance.new('UICorner')
		aspectConstraint.AspectType = Enum.AspectType.ScaleWithParentSize
		aspectConstraint.AspectRatio = 1
		aspectConstraint.Parent = tile
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = tile
		tile.BackgroundTransparency = 1
		tile.Size = UDim2.fromScale(0.15, 0)
		tile.Image = image
		tile.Parent = scroller
		tile.MouseButton1Click:Connect(function()
			MarketService:PromptGamePassPurchase(game.Players.LocalPlayer, passId)
		end)
	end
end



event.Event:Connect(function(typ, content)
	if typ == 'DisplayPage' then
		if content['Frame'] == frame then
			pageLayout:JumpTo(frame)
		end
	end
end)
