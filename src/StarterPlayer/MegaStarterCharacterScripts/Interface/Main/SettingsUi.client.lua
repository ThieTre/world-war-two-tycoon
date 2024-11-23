local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UIS = game:GetService('UserInputService')
local Modules = ReplicatedStorage.Modules

local PlayerSettings = require(Modules.Mega.Data.PlayerSettings)
local MiscUtils = require(Modules.Mega.Utils.Misc)

local LocalPlayer = game.Players.LocalPlayer

local frame = LocalPlayer.PlayerGui:WaitForChild("Main").Settings
local replicated = frame.Replicated
local scroller = frame.ScrollingFrame

local isMobile = MiscUtils.getClientPlatform() == "Mobile"

while not PlayerSettings.isLoaded do
	task.wait()
end

local function setOption(setting, tile, enabled)
	assert(enabled ~= nil)
	PlayerSettings:Update(setting, enabled)
	if enabled then
		tile.TextButton.BackgroundColor3 = Color3.new(0.333333, 0.666667, 0)
		tile.TextButton.Text = 'ON'
	else
		tile.TextButton.BackgroundColor3 = Color3.new(1, 0, 0)
		tile.TextButton.Text = 'OFF'
	end
end

-- Fill settings scroller
for setting, info in pairs(PlayerSettings.gameSettings) do
	local displayName, default = unpack(info)
	if not isMobile and  table.find({'Gyro Driving', 'Inverted Gyro', 'Auto Sprint', 'Joystick Driving'}, displayName) then
		continue
	end
	local tile = replicated.SettingTile:Clone()
	tile.TextLabel.Text = displayName
	setOption(setting, tile, PlayerSettings:Lookup(setting, default))
	tile.Parent = scroller
	tile.Visible = true
	tile.TextButton.MouseButton1Click:Connect(function()
		 local enabled = not (tile.TextButton.Text == 'ON')
		 setOption(setting, tile, enabled)
		 ReplicatedStorage.Settings.Mega.Interface.Sounds.Action.Click:Play()
	end)
end



frame:GetPropertyChangedSignal('Visible'):Connect(function()
	if frame.Visible then
		
	else
		PlayerSettings:RefreshServer()
	end
end)