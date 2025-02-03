local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local InstSearch = require(game.ReplicatedStorage.Modules.Mega.Instances.Search)
local PlayerUtils = require(game.ReplicatedStorage.Modules.Mega.Utils.Player)

local waterPart = workspace:WaitForChild("WATER").Part
local attachments = InstSearch.getChildrenOfType(waterPart, "Attachment")

task.spawn(function()
	while true do
		task.wait(1)
		local players = Players:GetPlayers()
		for _, player in players do
			local humanoid, hrp =
				PlayerUtils.getObjects(player, "Humanoid", "HumanoidRootPart")
			if not hrp or not humanoid then
				continue
			end
			if humanoid.Health <= 0 then
				continue
			end
			if hrp.Position.Y > waterPart.Position.Y then
				continue
			end
			humanoid.Health -= 15
		end
	end
end)

while true do
	task.wait(2)
	local vehicles = CollectionService:GetTagged("Vehicle")
	for _, vehicle in vehicles do
		pcall(function()
			if vehicle:GetAttribute("Health") <= 0 then
				return
			end
			local main = vehicle.Body.Main
			if main.Position.Y > waterPart.Position.Y then
				return
			end
			local nearestAttach = nil
			local smallestDistance = math.huge
			for _, a: Attachment in attachments do
				local distance = (main.Position - a.WorldPosition).Magnitude
				if distance < smallestDistance then
					smallestDistance = distance
					nearestAttach = a
				end
			end
			vehicle:SetPrimaryPartCFrame(
				CFrame.new(nearestAttach.WorldPosition) + Vector3.new(0, 80, 0)
			)
			vehicle:SetAttribute("Health", 0)
		end)
	end
end
