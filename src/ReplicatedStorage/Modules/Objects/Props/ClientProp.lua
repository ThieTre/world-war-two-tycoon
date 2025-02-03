local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Modules = ReplicatedStorage.Modules

local LiveConfig = require(Modules.Mega.Data.LiveConfig)
local InstSearch = require(Modules.Mega.Instances.Search)
local InstModify = require(Modules.Mega.Instances.Modify)
local InstPhysics = require(Modules.Mega.Instances.Physics)
local EffectsManager = require(Modules.Mega.Utils.EffectsManager)

local SETTINGS = require(ReplicatedStorage.Settings.Objects.Props)

-----------------------------------------------------------
------------------------ Client Prop ----------------------
-----------------------------------------------------------

local ClientProp = {}
ClientProp.__index = ClientProp
export type ClientProp = typeof(setmetatable({}, ClientProp))

function ClientProp:new(model: Model): ClientProp
	self = self ~= ClientProp and self or setmetatable({}, ClientProp)
	self.model = model
	self.base = model:WaitForChild("Base")
	self.effectsManager = EffectsManager:new(model:GetDescendants())
	self.config = LiveConfig:new(model, {
		IsBroken = false,
	})

	self:_Setup()
end

function ClientProp:_Setup()
	self:_SetupModel()
	self:_SetupHealth()
	self:_SetupTouch()
end

function ClientProp:_SetupModel()
	-- Setup model
	self.model.PrimaryPart = self.base
	for _, part in InstSearch.getChildrenOfType(self.model, "BasePart") do
		if part.Transparency == 0 then
			continue
		end
		part:SetAttribute("TargetTransparency", part.Transparency)
	end

	-- Setup clone
	self.clone = self.model:Clone()
	self.mass = 0
	for _, d in self.clone:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
		if d:IsA("BasePart") then
			self.mass += d.Mass
		end
	end
	self.setModelVisbility(self.clone, false, false)
	self.clone.Parent = self.model.Parent
	self.clone.PrimaryPart = self.clone.Base
	for _, v in InstSearch.getChildrenOfType(self.clone, "BasePart") do
		for _, k in self.clone:GetChildren() do
			if k ~= v and k:IsA("BasePart") and v:IsA("BasePart") then
				local weld = Instance.new("WeldConstraint")
				weld.Parent = v
				weld.Part0 = v
				weld.Part1 = k
			end
		end
	end

	-- Get sounds
	self.breakSounds = {}
	for _, sound in InstSearch.getChildrenOfType(self.base, "Sound") do
		if not string.find(sound.Name, "Break") then
			continue
		end
		table.insert(self.breakSounds, sound)
	end
end

function ClientProp:_SetupTouch()
	self.base.Touched:Connect(function(hit: Instance)
		if self.config.IsBroken then
			return
		end

		local hitVelocity = hit.AssemblyLinearVelocity
		local hitForce = hitVelocity.Magnitude * hit.AssemblyMass

		local slope = SETTINGS.ThresholdSlope or 525
		local intercept = SETTINGS.ThresholdIntercept or 0
		local threshold = (slope * self.mass) + intercept

		if hitForce < threshold then
			return
		end

		self:Break(hitVelocity)
	end)
end

function ClientProp:_SetupHealth()
	self.config:Watch("Health", function(new)
		if new > 0 then
			return
		end
		if self.config.IsBroken then
			return
		end
		local yForce = math.clamp(50 * self.mass, 0, 500)
		self:Break(Vector3.new(5, yForce, 0))
	end)
end

function ClientProp:Respawn()
	self.setModelVisbility(self.model, true, true)
	self.config.IsBroken = false
end

function ClientProp:Break(force: Vector3)
	if self.config.IsBroken then
		return
	end
	self.config.IsBroken = true

	self.setModelVisbility(self.clone, true, false)
	for _, part in InstSearch.getDescendantsOfType(self.clone, "BasePart") do
		part.Anchored = false
	end
	self.clone:SetPrimaryPartCFrame(self.base.CFrame)
	self.clone.Base:ApplyImpulse(force)

	self.setModelVisbility(self.model, false, false)

	-- Effects
	self.effectsManager:RunAll("Break")
	if #self.breakSounds > 0 then
		local sound = self.breakSounds[#self.breakSounds]
		sound.PlaybackSpeed = math.random(80, 120) / 100
		sound:Play()
	end

	task.delay(SETTINGS.CloneFadeDelay, function()
		self.setModelVisbility(self.clone, false, true)
		self.clone.Base.Anchored = true
	end)
	task.delay(SETTINGS.RespawnTime, self.Respawn, self)
end

function ClientProp.setModelVisbility(model: Model, isVisible: boolean, fade: boolean)
	local parts = InstSearch.getDescendantsOfType(model, "BasePart")
	local transparency = if isVisible then 0 else 1
	local fadeTime = SETTINGS.FadeTime or 1
	for _, part in parts do
		if part:GetAttribute("_IsAutoGenerated") then
			continue
		end

		for _, c in part:GetChildren() do
			if not c:IsA("Decal") then
				continue
			end
			c.Transparency = transparency
		end

		local thisTransparency = transparency
		if transparency == 0 then
			thisTransparency = part:GetAttribute("TargetTransparency") or 0
		end

		if fade then
			local tween = TweenService:Create(
				part,
				TweenInfo.new(fadeTime),
				{ Transparency = thisTransparency }
			)
			tween:Play()
		else
			part.Transparency = thisTransparency
		end
	end
	if fade then
		task.wait(fadeTime)
	end
	for _, part in parts do
		if part:GetAttribute("_IsAutoGenerated") then
			continue
		end
		part.CanCollide = isVisible
		part.CanQuery = isVisible
		part.CanTouch = isVisible
	end
end

return ClientProp
