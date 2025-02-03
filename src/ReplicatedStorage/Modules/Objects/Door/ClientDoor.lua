local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Modules

local LiveConfig = require(Modules.Mega.Data.LiveConfig)

local ClientDoor = {}
ClientDoor.__index = ClientDoor
export type ClientDoor = typeof(setmetatable({}, ClientDoor))

function ClientDoor:new(model: Model): ClientDoor
	self = self ~= ClientDoor and self or setmetatable({}, ClientDoor)

	self.model = model
	self.hinge = model:WaitForChild("Hinge")
	self.status = "Closed"
	self.config = LiveConfig:new(model.Parent.Parent)
	self.lastStatusChange = tick()

	self.direction = 1
	if self.model.Name == "Right" then
		self.direction = -1
	end

	while not self.config.Status do
		task.wait()
	end

	self.model.PrimaryPart = self.hinge

	self:SyncToStatus(self.config.Status)

	self:_Setup()

	return self
end

function ClientDoor:_Setup()
	self.config:Watch("Status", function(status)
		self:SyncToStatus(status)
	end)
end

function ClientDoor:SyncToStatus(status: string)
	-- Track status changes
	local thisStatusChange = tick()
	self.lastStatusChange = thisStatusChange

	-- Evaluate new status
	if status == "Closed" then
		if self.status == "Closing" then
			return
		end

		-- Wait for open animation to complete
		while self.status == "Opening" do
			task.wait()
		end
		if thisStatusChange ~= self.lastStatusChange then
			-- Status change will be tracked by another call
			return
		end
		self:Close()
	else
		if self.status == "Opening" then
			return
		end

		-- Wait for close animation to complete
		while self.status == "Closing" do
			task.wait()
		end
		if thisStatusChange ~= self.lastStatusChange then
			-- Status change will be tracked by another call
			return
		end
		self:Open()
	end
end

function ClientDoor:Open()
	if self.status == "Open" or self.status == "Opening" then
		return
	end
	self.status = "Opening"
	for i = 1, 18 do
		self.model:SetPrimaryPartCFrame(
			self.hinge.CFrame
				* CFrame.Angles(0, math.rad(5 * self.direction), 0)
		)
		task.wait()
	end
	self.status = "Open"
end

function ClientDoor:Close()
	if self.status == "Closed" or self.status == "Closing" then
		return
	end
	self.status = "Closing"
	for i = 1, 18 do
		self.model:SetPrimaryPartCFrame(
			self.hinge.CFrame
				* CFrame.Angles(0, math.rad(-5 * self.direction), 0)
		)
		task.wait()
	end
	self.status = "Closed"
end

return ClientDoor
