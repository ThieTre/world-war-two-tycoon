local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Modules

local Logging = require(Modules.Mega.Logging)
local InstModify = require(Modules.Mega.Instances.Modify)
local LiveConfig = require(Modules.Mega.Data.LiveConfig)
local ConnManager = require(Modules.Mega.Utils.ConnManager)
local TyUtils = require(Modules.Tycoons.Utils)
local EffectsManager = require(Modules.Mega.Utils.EffectsManager)
local Notification = require(Modules.Mega.Interface.Notification)
local Damage = require(Modules.Damage.Damage)
local LootBag = require(Modules.Objects.LootBag)
local Badges = require(Modules.Mega.Game.Badges)

local LOG = Logging:new("TycoonVault")
local SETTINGS = require(ReplicatedStorage.Settings.Objects.TycoonVault)
local STATUSES = {
	Cooldown = 1,
	Secured = 2,
	Exposed = 3,
	Breaching = 4,
}

local Vault = {}
Vault.__index = Vault
export type Vault = typeof(setmetatable({}, Vault))

function Vault:new(model: Model)
	self = self ~= Vault and self or setmetatable({}, Vault)
	self.model = model
	self.tycoon = TyUtils.getAncestorTycoon(model)
	if not self.tycoon then
		return
	end
	self.icon = self.model.Main.Icon
	self.config = LiveConfig:new(model)
	self.connections = ConnManager:new()
	self.effectsManager = EffectsManager:new(model:GetDescendants())
	self.lastBreachStart = 0

	self:_Setup()

	self:Secure()
	self.effectsManager:RunAll("Secure")
end

-- =============== Setup =============

function Vault:_Setup()
	-- Proximity prompt
	local prompt: ProximityPrompt = InstModify.findOrCreateChild(
		self.model.PromptPart,
		"ProximityPrompt",
		"ProximityPrompt",
		{
			Enabled = false,
			RequiresLineOfSight = false,
			MaxActivationDistance = SETTINGS.ActivationDistance,
			HoldDuration = SETTINGS.HoldDuration,
		}
	)
	self.prompt = prompt

	prompt.PromptButtonHoldBegan:Connect(function(player: Player)
		self:StartBreach(player)
	end)

	prompt.PromptButtonHoldEnded:Connect(function()
		self:EndBreach()
	end)

	prompt.Triggered:Connect(function(player: Player)
		self:Breach(player)
	end)

	-- Health
	self.config:Watch("Health", function(new)
		if new <= 0 then
			self:Expose()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(SETTINGS.ValuePollRate)
			if self.config.Status == STATUSES.Cooldown then
				continue
			end
			local owner = self:GetOwner()
			if not owner then
				continue
			end
			local wealthInfo = TyUtils.getPlayerWealthInfo(owner)
			local totalBalance = wealthInfo.collected + wealthInfo.uncollected
			self:SetBalance(totalBalance)
		end
	end)
end

-- =============== General =============

function Vault:SetBalance(totalBalance: number)
	local balance = totalBalance * SETTINGS.BalanceRatio
	self.config.Balance = balance

	local valueLabel = self.model.Sign.Value.SurfaceGui.TextLabel
	valueLabel.Text = TyUtils.formatNumber(balance, "$")
end

function Vault:GetOwner()
	if not self.tycoon then
		-- Probably not parented
		return
	end
	return self.tycoon:WaitForChild("Owner").Value
end

-- =============== Defense =============

function Vault:Expose()
	if self.config.Status == STATUSES.Exposed then
		return
	end
	LOG:Debug("Vault exposed")

	self.model:RemoveTag("Damageable")
	self.prompt.Enabled = true
	self.config.Status = STATUSES.Exposed

	-- Shield
	local shield = self.model.Shield
	shield:SetAttribute("BaseTransparency", shield.Transparency)
	shield.CanCollide = false
	shield.Transparency = 1
	shield.CanQuery = false
	if shield:FindFirstChild("SurfaceGui") then
		shield.SurfaceGui.Enabled = false
	end

	-- Effects
	self.effectsManager:RunAll("Expose")

	task.spawn(function()
		for i = 1, SETTINGS.ReviveTime do
			if self.config.Status ~= STATUSES.Exposed then
				return
			end
			self.icon.Enabled = not self.icon.Enabled
			task.wait(1)
		end

		-- Max exposed time elapsed, secure vault
		self:Secure()
	end)

	-- Notification
	Notification.notify(
		self:GetOwner(),
		"You tycoon's vault is under attack. Protect it!",
		{
			Title = "Warning",
			Sound = "Warning",
			Color = Color3.new(0.921569, 0.298039, 0.298039),
		}
	)
end

function Vault:Secure()
	if self.config.Status == STATUSES.Secured then
		return
	end
	LOG:Debug("Vault secured")

	self.model:AddTag("Damageable")
	self.config.Status = STATUSES.Secured
	self.prompt.Enabled = false

	-- Shield
	self.config.Health = SETTINGS.Health
	local shield = self.model.Shield
	shield.CanCollide = true
	shield.Transparency = shield:GetAttribute("BaseTransparency") or shield.Transparency
	shield.CanQuery = true
	if shield:FindFirstChild("SurfaceGui") then
		shield.SurfaceGui.Enabled = true
	end

	-- Sign
	local sign = self.model.Sign
	local titleText = sign.Title.SurfaceGui.TextLabel
	local valueText = sign.Value.SurfaceGui.TextLabel
	titleText.Text = "BALANCE"
	valueText.TextColor3 = Color3.new(0.517647, 1, 0)
	sign.Screen.Color = Color3.new(0.0509804, 0.411765, 0.67451)

	-- Effects
	self.effectsManager:RunAll("Secure")
	self.effectsManager:RunAll("StopAlarms")
	self.icon.Enabled = true
end

-- =============== Raiding =============

function Vault:StartBreach(player: Player)
	local owner = self:GetOwner()
	if
		not Damage.canDamage({
			Dealer = player,
			Taker = owner,
			Metadata = { IgnoreState = true },
		})
	then
		return
	end
	if os.time() - self.lastBreachStart < 1 and self.prompt.Enabled then
		self.prompt.Enabled = false
		task.delay(1, function()
			local isbreached = self.config.Status == "Breaching"
			local isOnCooldown = self.config.Status == "Cooldown"
			if isbreached or isOnCooldown then
				return
			end
			self.prompt.Enabled = true
		end)

		return
	end
	self.lastBreachStart = os.time()

	-- Record value at start
	self.breachValue = self.config.Balance

	-- Watcha for combat log
	local ownerVal = self.tycoon.Owner
	local connection = ownerVal:GetPropertyChangedSignal("Value"):Once(function()
		self:Breach(player)
	end)
	self.connections:Add("CombatLog", connection)

	-- Effects
	--self.effectsManager:RunAll('StartBreach')
	self.effectsManager:RunAll("StartAlarms")
end

function Vault:EndBreach()
	self.connections:Remove("CombatLog")

	task.delay(0.5, function()
		local breachedStatuses = { STATUSES.Breaching, STATUSES.Cooldown }
		if table.find(breachedStatuses, self.config.Status) then
			return
		end

		-- Effects
		self.effectsManager:RunAll("StopAlarms")
	end)
end

function Vault:Breach(player: Player)
	local owner = self:GetOwner()
	if
		not Damage.canDamage({
			Dealer = player,
			Taker = owner,
			Metadata = { IgnoreState = true },
		})
	then
		return
	end
	LOG:Debug("Vault breached by %s", player.Name)

	self.config.Status = STATUSES.Breaching

	-- Give loot bag
	local value = self.breachValue
	LootBag.addValue(player, value, self:GetOwner())

	-- Remove value from owner
	task.spawn(function()
		local tycoonConfig = LiveConfig:new(self.tycoon.Configs.Tycoon)
		local ownerConfig = LiveConfig:new(owner.Configs.Tycoon)
		local uncollectedReduction = math.clamp(value, 0, tycoonConfig.Balance)
		tycoonConfig.Balance -= uncollectedReduction
		ownerConfig.Balance -= value - uncollectedReduction
	end)

	-- Effects
	self.prompt.Enabled = false
	self.icon.Enabled = false
	self.effectsManager:RunAll("Breach")
	task.delay(10, function()
		self.effectsManager:RunAll("StopAlarms")
	end)

	Badges.awardBadge(player, "Thief")

	self:StartCooldown()
end

function Vault:StartCooldown()
	self.config.Status = STATUSES.Cooldown

	local sign = self.model.Sign
	local titleText = sign.Title.SurfaceGui.TextLabel
	local valueText = sign.Value.SurfaceGui.TextLabel

	titleText.Text = "COOLDOWN"
	valueText.TextColor3 = Color3.new(1, 1, 1)
	sign.Screen.Color = Color3.new(1, 0.215686, 0.227451)

	for i = 1, SETTINGS.CooldownTime do
		local remaining = SETTINGS.CooldownTime - i
		valueText.Text = remaining
		task.wait(1)
	end

	self:Secure()
end

return Vault
