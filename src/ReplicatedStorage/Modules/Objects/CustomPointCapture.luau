local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Modules

local PointCapture = require(Modules.PointCapture)
local SETTINGS = require(ReplicatedStorage.Settings.PointCapture)

local announcements = SETTINGS.Announcements

local CustomPointCapture = setmetatable({}, { __index = PointCapture })
CustomPointCapture.__index = CustomPointCapture
export type CustomPointCapture = typeof(setmetatable({}, CustomPointCapture))

function CustomPointCapture:new(...): CustomPointCapture
	self = self ~= CustomPointCapture and self
		or setmetatable({}, CustomPointCapture)
	PointCapture.new(self, ...)
	return self
end

function CustomPointCapture:SetController(team: Team)
	PointCapture.SetController(self, team)
	if not team then
		return
	end

	announcements[self.name][team.Name]:Play()
end

return CustomPointCapture
