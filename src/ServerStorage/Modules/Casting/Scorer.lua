local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logging = require(ReplicatedStorage.Modules.Mega.Logging)

local LOG = Logging:new("Casting.Scorer")
local SETTINGS = require(game.ReplicatedStorage.Settings.Casting).Scorer

-----------------------------------------------------------
------------------------ Cast Scorer ----------------------
-----------------------------------------------------------
--[[
	Casting anit-cheat module
]]

local Scorer = {}
Scorer.__index = Scorer
export type CastScorer = typeof(setmetatable({}, Scorer))

function Scorer:new(): CastScorer
	self = self ~= Scorer and self or setmetatable({}, { __index = Scorer })
	self.serverCasts = {}
	self.violations = 0

	task.spawn(function()
		while true do
			task.wait(SETTINGS.BucketInterval)
			self.violations = 0
		end
	end)
	return self
end

function Scorer:RequestHit(castInfo: {}): boolean
	local valid, addViolation = self:ValidateHit(castInfo, castInfo.Id)
	if not valid and addViolation then
		self.violations += 1
		if self.violations < SETTINGS.MaxBucketViolations then
			valid = true
		else
			LOG:Warning("Max cast violations reached for interval")
		end
	end
	return valid
end

function Scorer:ValidateHit(
	clientCastInfo: {},
	id: number
): (boolean, boolean?)
	-- Validate a projectile hit

	-- Wait for the server to complete the matching
	-- client cast
	if not self.serverCasts[id] then
		for i = 1, 6 do
			-- Wait for id
			task.wait(0.5)
		end
	end
	local serverCast: RaycastResult = self.serverCasts[id]
	if serverCast then
		-- Difference metrics
		local clientInstance = clientCastInfo.Instance
		local serverInstance = serverCast.Instance
		local serverPos = serverCast.Position
		local serverDist = serverCast.Distance
		local clientPos = clientCastInfo.Position
		local clientDist = clientCastInfo.Distance
		local clientInstVolume = 100
		if clientInstance then
			clientInstVolume = clientInstance.Size.X
				* clientInstance.Size.Y
				* clientInstance.Size.Z
		end

		-- Lets see if we get lucky and the two hit
		-- postions are really close to eachother
		if serverCast.Instance then
			local hitDistDelta = (clientPos - serverPos).Magnitude
			if clientInstance == serverInstance then
				-- Same instances have been hit
				return true
			end
			if hitDistDelta <= (SETTINGS.AllowableHitDeviation or 10) then
				-- Hit locations are close enough
				return true
			end
		end

		-- We need more evidence to verify
		--  1. Check if hit target is actually nearby
		--  2. Check for server obstructions
		local isObstructed = true
		local isNearby = false
		local rayLengthDelta = (clientDist - serverDist) -- how much longer was the client's ray?
		if rayLengthDelta <= (SETTINGS.AllowableDistanceDeviation or 10) then
			-- Likely no obstructions
			isObstructed = false
		end
		local nearLeniance = (SETTINGS.AllowableInstancePosDeviation or 10)
			+ clientInstVolume / 3 -- scale with volume
		if
			clientInstance
			and (clientInstance.Position - clientPos).Magnitude
				< nearLeniance
		then
			-- Instance is likely nearby
			isNearby = true
		end
		local allowed = isNearby and not isObstructed
		if not allowed then
			LOG:Debug("Obstructed cast: " .. tostring(isObstructed))
			LOG:Debug("Hit instance nearby: " .. tostring(isNearby))
		end
		return allowed, true
	else
		-- Never receive a projectile from the server
		LOG:Debug("Never received a server cast for id " .. id)
		return false, false -- don't allow but also dont add violation
	end
end

return Scorer
