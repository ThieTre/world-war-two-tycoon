local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Modules = ReplicatedStorage.Modules

local Set = require(Modules.Mega.DataStructures.Set)
local LiveConfig = require(Modules.Mega.Data.LiveConfig)
local InstModify = require(Modules.Mega.Instances.Modify)
local InstSearch = require(Modules.Mega.Instances.Search)
local ConnManager = require(Modules.Mega.Utils.ConnManager)
local Damage = require(Modules.Damage.Damage)
local EffectsManager = require(Modules.Mega.Utils.EffectsManager)
local Notification = require(Modules.Mega.Interface.Notification)

local cloned = script.Parent.Cloned

local ServerDoor = {}
ServerDoor.__index = ServerDoor
export type ServerDoor = typeof(setmetatable({}, ServerDoor))

local function canDamage(dealer: Player, taker: Player): boolean
	if not dealer then
		return false
	end
	return Damage.canDamage({
		Dealer = dealer,
		Taker = taker,
		Metadata = {
			IgnoreState = true,
		},
	})
end

function ServerDoor:new(model: Model): ServerDoor
	self = self ~= ServerDoor and self or setmetatable({}, ServerDoor)

	self.model = model
	self.effectsManager = EffectsManager:new(model:GetDescendants())
	self.settings = (model:FindFirstChild("Settings") and require(model.Settings)) or {}
	self.owner = nil
	self.enabled = true

	self:_Setup()

	return self
end

function ServerDoor:_Setup()
	-- General setup
	self.config = LiveConfig:new(self.model)
	if not self.config.Status then
		self.config.Status = "Closed"
	end
	InstModify.destroyExistingChild(self.model, "ConeHandleAdornment")

	-- Setup interaction
	if self.settings.InteractionType == "Prompt" then
		self:_SetupPrompt()
	else
		self:_SetupRegion()
	end

	-- Setup health
	if self.settings.Health then
		self:_SetupHealth()
	end

	-- Setup clients
	for _, door in self.model.Doors:GetChildren() do
		if door:FindFirstChild("Client") then
			break
		end
		local clientScript = cloned.Client:Clone()
		clientScript.Parent = door
		clientScript.Enabled = true
		door:AddTag("DamagePassthrough")
	end
end

function ServerDoor:_SetupRegion()
	-- Get region part
	self.region = self.model:FindFirstChild("Region") :: BasePart
	if not self.region then
		local doorSize = self.model:GetExtentsSize()
		local targetSize = Vector3.new(
			doorSize.X * doorSize.Z,
			doorSize.Y * 1,
			doorSize.Z * doorSize.X * 1.5
		)
		self.region = InstModify.create("Part", self.model, {
			Anchored = true,
			CanTouch = true,
			CanCollide = false,
			CanQuery = false,
			Transparency = 1,
			Size = targetSize * (self.settings.RegionSizeAdj or 1),
			CFrame = self.model:GetPivot(),
			Name = "Region",
		})
	end

	-- Connect touch
	local deathConns = ConnManager:new()
	local nearbyOwners = Set:new()

	local function insertNearby(player)
		nearbyOwners:Insert(player)
		self:Open()
	end

	local function removeNearby(player)
		nearbyOwners:Remove(player)
		if #nearbyOwners == 0 then
			self:Close()
		end
		deathConns:Remove(player.UserId)
	end

	self.region.Touched:Connect(function(part)
		if part.Name ~= "HumanoidRootPart" then
			return
		end
		local player = Players:GetPlayerFromCharacter(part.Parent)
		if not player then
			return
		end
		if canDamage(self.owner, player) then
			return
		end
		insertNearby(player)
		deathConns:Add(
			player.UserId,
			Damage.onDeath(player, function()
				removeNearby(player)
			end)
		)
	end)

	self.region.TouchEnded:Connect(function(part)
		if part.Name ~= "HumanoidRootPart" then
			return
		end
		local player = Players:GetPlayerFromCharacter(part.Parent)
		if not player then
			return
		end
		if not nearbyOwners:Find(player) then
			return
		end
		removeNearby(player)
	end)
end

function ServerDoor:_SetupPrompt()
	self.prompt = self.model.FindFirstChild("ProximityPrompt")
	if not self.prompt then
		local doorSize = self.model:GetExtentsSize()
		self.prompt = InstModify.create("ProximityPrompt", self.model, {
			MaxActivationDistance = doorSize.X * doorSize.Z,
		})
	end

	self.prompt.Triggered:Connect(function(player)
		if canDamage(self.owner, player) then
			self.effectsManager:RunAll("Locked")
			return
		end
		if self.config.Status == "Open" then
			self:Open()
		else
			self:Close()
		end
	end)
end

function ServerDoor:_SetupHealth()
	self.config.Health = self.settings.Health
	self.model:AddTag("Damageable")

	self.config:Watch("Health", function(new)
		if not self.enabled then
			return
		end
		if new <= 0 then
			self.model:RemoveTag("Damageable")
			self.enabled = false
			self:Open()
			self.effectsManager:RunAll("Destroy")

			local message = self.settings.BreakMessage
			if self.settings.BreakMessage then
				Notification.notify(self.owner, message, {
					Title = "Warning",
					Sound = "Warning",
					Color = Color3.new(0.921569, 0.298039, 0.298039),
				})
			end

			task.delay(self.settings.ReviveTime or 60, function()
				self.model:AddTag("Damageable")
				self.config.Health = self.settings.Health
				self.enabled = true
				self:Close()
			end)
		end
	end)
end

function ServerDoor:Open()
	if self.Status == "Open" then
		return
	end
	self.config.Status = "Open"
	local parts = InstSearch.getDescendantsOfType(self.model.Doors, "BasePart")
	for _, part in parts do
		part.CanQuery = false
		part.CanTouch = false
		part.CanCollide = false
	end
	self.effectsManager:RunAll("Open")
end

function ServerDoor:Close()
	if self.Status == "Closed" then
		return
	end
	if not self.enabled then
		return
	end
	self.config.Status = "Closed"
	local parts = InstSearch.getDescendantsOfType(self.model.Doors, "BasePart")
	for _, part in parts do
		part.CanQuery = true
		part.CanTouch = true
		part.CanCollide = true
	end
	self.effectsManager:RunAll("Close")
end

return ServerDoor
