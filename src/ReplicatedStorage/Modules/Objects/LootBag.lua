local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Modules = ReplicatedStorage.Modules

local Logging = require(Modules.Mega.Logging)
local TyUtils = require(Modules.Tycoons.Utils)
local LiveConfig = require(Modules.Mega.Data.LiveConfig)
local InstModify = require(Modules.Mega.Instances.Modify)
local PlayerUtils = require(Modules.Mega.Utils.Player)
local ConnManager = require(Modules.Mega.Utils.ConnManager)
local Interface = require(Modules.Mega.Interface)

local SETTINGS = require(ReplicatedStorage.Settings.Objects.LootBag)
local LOG = Logging:new("Objects.LootBag")

-----------------------------------------------------------
--------------------------- Loot Bag ----------------------
-----------------------------------------------------------
--[[

	Module to define the variouse programmable objects used 
	throughout the game

]]

local LootBag = {}
LootBag.__index = LootBag
export type LootBag = typeof(setmetatable({}, LootBag))

function LootBag:new(value: number, sourcePlayer: Player): LootBag
	self = self ~= LootBag and self or setmetatable({}, LootBag)

	self.part = ServerStorage.Assets.Objects.LootBag:Clone()
	self.source = sourcePlayer
	self.config = LiveConfig:new(self.part, { Value = value })
	self.prompt = InstModify.create("ProximityPrompt", self.part)
	self.rigid = InstModify.create(
		"RigidConstraint",
		self.part,
		{ Attachment0 = self.part.Attachment }
	)
	self.remote = InstModify.create("RemoteEvent", self.part)
	self.connections = ConnManager:new()
	self.currentBagVal = nil

	self:SetOwner(nil)
	self:_Setup()

	return self
end

function LootBag:_Setup()
	-- Prox prompt
	local prompt: ProximityPrompt = self.prompt
	local lastTrigger = time()
	prompt.Triggered:Connect(function(player)
		if os.time() - lastTrigger < 1 then
			return
		end
		lastTrigger = os.time()
		self:Attach(player)
	end)

	-- Value change
	self.defaultPos = self.part.Attachment.CFrame.Position -- default position for scaling
	self.defaultSize = self.part.Size
	self.connections:Add(
		"Size",
		self.config:Watch("Value", function()
			self:ReSize()
		end)
	)

	-- Remote event
	self.connections:Add(
		"Remote",
		self.remote.OnServerEvent:Connect(function(player, typ, content)
			if typ == "Drop" and self.owner == player then
				self:Drop()
			end
		end)
	)

	-- Removed players
	self.connections:Add(
		"PlayerRemoving",
		game.Players.PlayerRemoving:Connect(function(player)
			if self and player == self.owner then
				self:Drop()
			end
		end)
	)

	-- Collect on server shutdown
	game:BindToClose(function()
		if self.owner then
			self:Collect(self.owner)
		end
	end)
end

function LootBag:Destroy()
	self:SetOwner(nil)
	if self.currentBagVal then
		self.currentBagVal.Value = nil
	end
	self.part:Destroy()
	self.connections:RemoveAll()
	self = nil
end

function LootBag:Attach(player: Player)
	--[[
		Attach a loot bag to a character. If the character
		already has a bag, then combine them
	]]

	local character, humanoid =
		PlayerUtils.getObjects(player, "Character", "Humanoid")
	if not character or humanoid.Health <= 0 then
		return
	end

	-- Collect cash if recovered by source
	if player == self.source then
		self:Collect(player)
		return
	end

	-- Evaluate player's current bag status
	local bagValue = character:FindFirstChild("BagValue")
	if not bagValue then
		bagValue =
			InstModify.create("ObjectValue", character, { Name = "BagValue" })
	elseif bagValue.Value then
		-- The character already has a bag
		local currentBag: BasePart = bagValue.Value
		local currentConfig = LiveConfig:new(currentBag)
		currentConfig.Value += self.config.Value
		self:Destroy()
		return
	end
	bagValue.Value = self.part
	self.currentBagVal = bagValue
	self:SetOwner(player)

	-- Attach the bag and configure
	local rigid: RigidConstraint = self.rigid
	if rigid.Attachment1 then
		self:Drop()
	end
	local bag: BasePart = self.part
	local charAttach: Attachment = character.UpperTorso.BodyBackAttachment
	if not bag.Parent then
		bag.Parent = workspace
	end
	bag.Highlight.Enabled = false
	bag.Attach:Play()
	bag.Anchored = false
	bag.CanCollide = false
	bag.CanQuery = false
	rigid.Attachment1 = charAttach
	self.prompt.Enabled = false
end

function LootBag:Drop()
	local bag: BasePart = self.part
	self.rigid.Attachment1 = nil
	self.currentBagVal.Value = nil
	self.prompt.Enabled = true
	bag.Highlight.Enabled = true
	self:SetOwner(nil)
	-- Physics
	bag.CanCollide = true
	bag.Drop:Play()
	task.wait(1)
	local speed = 10
	while speed > 0.6 do
		task.wait(0.5)
		speed = bag.AssemblyLinearVelocity.Magnitude
	end
	if self.rigid.Attachment1 then
		-- Reattached
		return
	end
	bag.Anchored = true
end

function LootBag:Collect(player: Player)
	LOG:Debug("Collecting loot bag for player " .. player.Name)
	TyUtils.updatePlayerCash(
		player,
		self.config.Value,
		{ notification = true }
	)
	--Badges.awardBadge(player, Badges.badges.LootBag)
	self:Destroy()
end

function LootBag:SetOwner(player: Player?)
	if not player then
		self.owner = nil
		self.connections:Remove("OwnerDeath", "OwnerNearby")
	else
		self.owner = player
		self:ReSize()
		local character = player.Character
		self.connections:Add(
			"OwnerDeath",
			character.Humanoid.Died:Once(function()
				self:Drop()
			end)
		)
		-- Collect if player is near their tycoon
		local ownerConfig = LiveConfig:new(player.Configs.Tycoon)
		self.connections:Add(
			"OwnerNearby",
			ownerConfig:Watch("IsNearTycoon", function()
				LOG:Debug("Bag detected near owner's tycoon")
				self:Collect(player)
			end)
		)
	end
end

function LootBag:ReSize()
	local bag = self.part
	--local cashValue = self:GetCashValue()
	local minMult, maxMult = unpack(SETTINGS.BagSizeMultBounds)
	local mult = math.clamp(
		1 + (maxMult - 1) * (self.config.Value / SETTINGS.MaxSizeValue),
		minMult,
		maxMult
	)
	bag.Size = self.defaultSize * mult
	bag.Attachment.Position =
		Vector3.new(bag.Size.X / 4, bag.Size.Y / -2, self.defaultPos.Z)
	bag.Add.PlaybackSpeed = math.random(85, 115) / 100
	bag.Add:Play()
end

function LootBag.addValue(player: Player, value: number, sourcePlayer: Player?)
	--[[
		Add value to a player's loot bag or create a new one 
		if it doesn't exist. Value is stored as total income per
		minute for a player.
	]]

	local character = player.Character
	if not character then
		return
	end

	local bagPart = character:FindFirstChild("BagValue")
		and character.BagValue.Value
	if bagPart then
		local config = LiveConfig:new(bagPart)
		config.Value += value
	else
		local bag = LootBag:new(value, sourcePlayer)
		bag:Attach(player)
	end

	-- Send notificaiton
	Interface.Notification.clientCoreNotification(player, {
		Title = "Loot Bag",
		Text = "$" .. TyUtils.formatNumber(math.clamp(value, 1, math.huge)),
		Icon = "rbxassetid://17027550910",
	})
end

return LootBag
