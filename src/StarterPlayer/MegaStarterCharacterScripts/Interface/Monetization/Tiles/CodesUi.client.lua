local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local Notification = require(Modules.Mega.Interface.Notification)
local PrizeUtils = require(Modules.Prizes.Utils)
local CodeManager = require(Modules.Prizes.Codes)

local LocalPlayer = game.Players.LocalPlayer

local sounds = ReplicatedStorage.Settings.Mega.Interface.Sounds.Notification
local chestSounds = LocalPlayer.PlayerGui.Monetization.ChestOpen.Sounds

local frame = LocalPlayer.PlayerGui
	:WaitForChild("Monetization")
	:WaitForChild("Store").Frame.Home.Codes
local inputBox = frame.TextBox
local button = frame.Redeem

local lastSubmit = os.time()
button.MouseButton1Click:Connect(function()
	if os.time() - lastSubmit < 1 then
		return
	end
	lastSubmit = os.time()
	if not inputBox.Text or inputBox.Text == "" then
		return
	end

	local name, typ = CodeManager.playerInputCode(inputBox.Text)
	if name then
		if typ ~= "MinutesReward" then
			local prizeInfo = PrizeUtils.getPrizeInfo(name, typ)
			Notification.clientCoreNotification({
				Title = name .. " Added",
				Text = "Prize claimed!",
				Icon = prizeInfo.Image,
			})
			local prizeSounds = chestSounds.Types:FindFirstChild(typ)
			if prizeSounds then
				for _, sound in prizeSounds:GetChildren() do
					sound:Play()
				end
			end
		end

		sounds.Success:Play()
		button.BackgroundColor3 = Color3.new(0.333333, 0.666667, 0)
	else
		sounds.Error:Play()
		button.BackgroundColor3 = Color3.new(1, 0, 0)
	end
	task.wait(1)
	inputBox.Text = ""
end)

inputBox:GetPropertyChangedSignal("Text"):Connect(function()
	if inputBox.Text and inputBox.Text ~= "" then
		button.BackgroundColor3 = Color3.new(1, 0.666667, 0)
	else
		button.BackgroundColor3 = Color3.new(0.380392, 0.380392, 0.380392)
	end
end)
