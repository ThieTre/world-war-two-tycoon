local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Modules = ReplicatedStorage.Modules
local TyUtils = require(Modules.Tycoons.Utils)
local GameTycoonUtils = require(Modules.TycoonGame.Tycoons.Utils)

local LocalPlayer = game.Players.LocalPlayer

local tycoonVal = TyUtils.waitForTycoon(LocalPlayer)
local connection = TyUtils.getConnection(LocalPlayer)

tycoonVal:GetPropertyChangedSignal('Value'):Connect(function()
	if tycoonVal.Value then
		connection = TyUtils.getConnection(LocalPlayer)
	end
end)

local frame = LocalPlayer.PlayerGui:WaitForChild('Main').Rebirth
local progressBar = frame.Progress.Bar
local button = frame.Content.Button

local ratio = connection:Call('GetRebirthRatio')

local function updateUi()
	ratio = connection:Call('GetRebirthRatio')
	progressBar.Size = UDim2.fromScale(ratio, 1)
	if ratio >= 1 then
		button.BackgroundColor3 = Color3.new(1, 0.345098, 0.792157)
		progressBar.BackgroundColor3 = Color3.new(1, 0.345098, 0.792157)
		button.Text = 'REBIRTH'
	else
		button.BackgroundColor3 = Color3.new(0.505882, 0.505882, 0.505882)
		progressBar.BackgroundColor3 = Color3.new(0.145098, 0.85098, 0.298039)
		button.Text = 'LOCKED'
	end
end

updateUi()

local rebirthConn: RBXScriptConnection
rebirthConn = button.MouseButton1Click:Connect(function()
	if ratio >= 1 then
		local success = GameTycoonUtils.clientRequestRebirth(LocalPlayer)
		if success then
			frame.Visible = false
			rebirthConn:Disconnect()
		end
	end
end)

frame:GetPropertyChangedSignal('Visible'):Connect(function()
	if frame.Visible then
		updateUi()
	end
end)
