local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PSCache = require(ReplicatedStorage.Modules.Mega.Data.PSCache)

return PSCache:new(
	"Data",
	"Players",
	{ setup = ReplicatedStorage.Settings.PlayerData }
)
