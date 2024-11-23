local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Modules

local UiManager = require(Modules.Mega.Interface.Context).Manager


local LocalPlayer = game.Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

local context = UiManager:GetContext('popup-main')
local frame = PlayerGui:WaitForChild('Main').SideButtons.SideButtons
local currentFrame = nil 


local function setupButton(btn: GuiButton)
	local targetFrame = PlayerGui.Main:WaitForChild(btn.Name)
	btn.MouseButton1Click:Connect(function()
		if context.currentFrame == targetFrame then 
			context:Hide(targetFrame)
			currentFrame = nil
		else
			if currentFrame and currentFrame.Visible then
				context:Hide(currentFrame)
			end
			context:Show(targetFrame, 1)
			currentFrame = targetFrame
		end
	end)
end

local buttons = frame:GetChildren()
table.insert(buttons, PlayerGui:WaitForChild('Topbar').Settings.Settings) -- append the settings topbar

for _, btn in buttons do
	if btn:IsA('GuiButton') and btn.Visible and not btn:GetAttribute('IgnoreButton') then
		setupButton(btn)
	end
end

