local TyUtils =
	require(game.ReplicatedStorage:WaitForChild("Modules").Tycoons.Utils)
local MiscUtils =
	require(game.ReplicatedStorage:WaitForChild("Modules").Mega.Utils.Misc)

local LocalPlayer = game.Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

PlayerGui:WaitForChild("Main").Enabled = false
PlayerGui:WaitForChild("Cash").Enabled = false

TyUtils.waitForTycoon(LocalPlayer)

PlayerGui.Main.Enabled = true
PlayerGui.Cash.Enabled = true

-- Mobile jump button
if MiscUtils.getClientPlatform() == "Mobile" then
	task.spawn(function()
		local mobileUi = LocalPlayer.PlayerGui:FindFirstChild("Mobile")
		while not mobileUi do
			mobileUi = LocalPlayer.PlayerGui:FindFirstChild("Mobile")
			task.wait(0.5)
		end
		mobileUi.Enabled = true

		-- Align jumnp button accordingly
		local jumpButton: ImageButton =
			LocalPlayer.PlayerGui.TouchGui.TouchControlFrame:WaitForChild(
				"JumpButton"
			)
		local template = mobileUi.Gun.Jump
		local function updateJumpButton()
			local abSize = { template.AbsoluteSize.X, template.AbsoluteSize.Y }
			local abPos =
				{ template.AbsolutePosition.X, template.AbsolutePosition.Y }
			jumpButton.Size = UDim2.fromOffset(unpack(abSize))
			jumpButton.Position = UDim2.fromOffset(unpack(abPos))
		end
		updateJumpButton()
		jumpButton.Changed:Connect(updateJumpButton)
	end)
end

-- Ensure touch controls are enabled
game.GuiService.TouchControlsEnabled = true
