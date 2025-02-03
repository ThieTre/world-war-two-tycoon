local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Modules = ReplicatedStorage.Modules

local EffectsManager = require(Modules.Mega.Utils.EffectsManager)
local LiveConfig = require(Modules.Mega.Data.LiveConfig)

local SETTINGS = require(ReplicatedStorage.Settings.Objects.Target)

-----------------------------------------------------------
--------------------------- Target ------------------------
-----------------------------------------------------------

local Target = {}
Target.__index = Target
export type Target = typeof(setmetatable({}, Target))

function Target:new(model: Model): Target
	self = self ~= Target and self or setmetatable({}, Target)

	self.model = model
	self.part = model.Main
	self.icon = self.part.Icon
	self.effectsManager = EffectsManager:new(self.part.Effects)
	self.spawnTween =
		TweenService:Create(self.part, TweenInfo.new(1), { Transparency = 0 })
	self.config = LiveConfig:new(model)
	self.startPose = self.part.CFrame

	self:_Setup()

	self:Spawn()
end

function Target:_Setup()
	self.config:Watch("Health", function(new, prev)
		prev = prev or 0
		if not self.model:HasTag("Damageable") then
			return
		end
		local change = new - prev
		if change >= 0 then
			return
		end

		if new <= 0 then
			self:Explode()
		end
	end)
end

function Target:Spawn()
	self.icon.Enabled = true

	self.part.CFrame = self.startPose
	self.part.Anchored = true
	self.part.CanCollide = true
	self.part.CanQuery = true
	self.spawnTween:Play()

	self.config.Health = self.model:GetAttribute("MaxHealth")
		or SETTINGS.Health
	self.model:AddTag("Damageable")
end

function Target:Explode()
	self.icon.Enabled = false

	self.part.Transparency = 1
	self.part.CanCollide = false
	self.part.CanQuery = false

	self.model:RemoveTag("Damageable")
	self.effectsManager:RunAll()

	task.delay(SETTINGS.RespawnTime, Target.Spawn, self)
end

return Target
