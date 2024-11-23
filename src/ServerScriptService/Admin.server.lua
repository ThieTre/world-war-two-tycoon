local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Modules

local Listener = require(Modules.Mega.Command.Listener)
local LiveConfig = require(Modules.Mega.Data.LiveConfig)
local BetterStore = require(Modules.Mega.Data.BetterStore)
local Notification = require(Modules.Mega.Interface.Notification)
local ServRep = require(Modules.Mega.Replication.Server)
local Instances = require(Modules.Mega.Instances)
local InstanceAPI = require(Modules.Mega.Data.InstanceAPI)
local PlayerUtils = require(Modules.Mega.Utils.Player)
local TyUtils = require(Modules.Tycoons.Utils)
local GunUtils = require(Modules.Guns.Utils)
local GameTycoons = require(Modules.TycoonGame.Tycoons)
local VehicleManager = require(Modules.TycoonGame.Vehicles.Manager)
local ToolManager = require(Modules.TycoonGame.Tools.Manager)
local VehicleUtils = require(Modules.Vehicles.Utils)
local Chests = require(Modules.Monetization.Chests)
local CashBoosts = require(Modules.Monetization.CashBoosts)
local Spinner = require(Modules.Monetization.DailySpinner)
local PlayerData = require(Modules.PlayerData)

local PlayerStore = BetterStore:new("Players")

local admin = Listener:new("!")
admin:AddPlayer(24189615, 100, "Owner")
admin:AddPlayer(23038649, 100, "Owner")
admin:AddPlayer(17318031, 100, "Owner")
admin:AddPlayer(1949546822, 1, "Tester")

-- =============== General Commands ==============

local super =
	admin:AddCommand("super", 50, "Max player health and increase speed")
super:AddPositional("walkspeed", "Value to set the player's walkspeed to", 100)

super.Action = function(_self, args)
	local targets = args[".targets"] or { args[".caller"] }
	for _, target: Player in targets do
		local character = target.Character
		local humanoid = character:WaitForChild("Humanoid")
		if not humanoid then
			error("Player does not have a humanoid")
		end
		humanoid.WalkSpeed = args["walkspeed"]
		Instances.Modify.findOrCreateChild(
			character,
			"SuperForceField",
			"ForceField"
		)
	end
end

local gameVersion =
	admin:AddCommand("version", 0, "Print the game version in the chat")

gameVersion.Action = function(_self, args)
	local v = require(ReplicatedStorage.Settings.Game).__version or "N/A"
	return `Game version is: {v}`
end

----------------------------------------

local teamset = admin:AddCommand("teamset", 50, "Set player(s) team")
teamset:AddPositional("name", "Name of the team to set")

teamset.Action = function(_self, args)
	local targets = args[".targets"] or { args[".caller"] }
	for _, target: Player in targets do
		target.Team = game.Teams[args["name"]]
	end
end

----------------------------------------

local health =
	admin:AddCommand("health", 50, "Max player health and increase speed")
health:AddPositional("value", "Value to set the player's health to", 100)

health.Action = function(_self, args)
	local targets = args[".targets"] or { args[".caller"] }
	for _, target: Player in targets do
		local character = target.Character
		local humanoid: Humanoid = PlayerUtils.getObjects(target, "Humanoid")
		if not humanoid then
			error("Player does not have a humanoid")
		end
		humanoid.Health = args["value"]
	end
end

----------------------------------------

local unsuper =
	admin:AddCommand("unsuper", 50, "Return a supered player to normal")

unsuper.Action = function(_self, args)
	local targets = args[".targets"] or { args[".caller"] }
	for _, target: Player in targets do
		local character = target.Character
		local humanoid = character:WaitForChild("Humanoid")
		if not humanoid then
			error("Player does not have a humanoid")
		end
		humanoid.WalkSpeed = game.StarterPlayer.CharacterWalkSpeed
		Instances.Modify.destroyExistingChild(character, "SuperForceField")
	end
end

----------------------------------------

local spectate = admin:AddCommand("welcome", 50, "Spectate another player")
spectate:AddPositional("observee", "Player to spectate")
spectate:AddPositional("mode", "Camera type name to use", "Follow")

spectate.Action = function(_self, args)
	local observer = args[".caller"]
	local observee = game.Players[args["observee"]]
	local observeeHumanoid = PlayerUtils.getObjects(observee, "Humanoid")
	if not observeeHumanoid then
		error(observee.Name .. " does not have a character")
	end
	observer:RequestStreamAroundAsync(observeeHumanoid.RootPart.Position)
	local properties = {
		CameraSubject = observeeHumanoid,
		CameraType = Enum.CameraType[args["mode"]],
	}
	ServRep.clientUpdateProperty(
		observer,
		`{workspace:GetFullName()}.Camera`,
		properties
	)
end

----------------------------------------

local unspectate = admin:AddCommand("done", 50, "Stop spectating")

unspectate.Action = function(_self, args)
	local targets = args[".targets"] or { args[".caller"] }
	for _, observer: Player in targets do
		local humanoid = PlayerUtils.getObjects(observer, "Humanoid")
		local properties =
			{ CameraSubject = humanoid, CameraType = Enum.CameraType.Follow }
		ServRep.clientUpdateProperty(
			observer,
			`{workspace:GetFullName()}.Camera`,
			properties,
			{ useWait = false }
		)
	end
end

----------------------------------------

local tp = admin:AddCommand("tp", 50, "Teleport to another player")
tp:AddPositional("player", "Name of the player to teleport to")

tp.Action = function(_self, args)
	local toPlayer: Player = game.Players[args["player"]]
	if not toPlayer then
		error("Player was not found in game")
	end
	local toCharacter = toPlayer.Character
	if not toCharacter then
		error("Player does not have a character to teleport to")
	end
	local targets = args[".targets"] or { args[".caller"] }
	for _, target: Player in targets do
		local character = target.Character
		if not character then
			continue
		end
		character:PivotTo(toCharacter:GetPivot() + Vector3.new(0, 3, 0))
	end
end

----------------------------------------

local warp = admin:AddCommand("warp", 50, "Teleport to a specified location")
warp:AddPositional("location", "Name of the location to teleport to")

warp.Action = function(_self, args)
	local location: BasePart =
		workspace["Map Locations"]:FindFirstChild(args["location"])
	if not location then
		error("Location does not exist: " .. args["location"])
	end
	local targets = args[".targets"] or { args[".caller"] }
	for _, target: Player in targets do
		local character = target.Character
		if not character then
			continue
		end
		character:PivotTo(location.CFrame + Vector3.new(0, 3, 0))
	end
end

-- =============== Tycoon Commands ==============

local cash = admin:AddCommand("cash", 50, "Perfrom balance related activity")
cash:AddPositional("action", "Balance related action to execute (add or set)")
cash:AddPositional("amt", "Balance to add or set")

cash.Action = function(_self, args)
	local targets = args[".targets"] or { args[".caller"] }
	for _, target: Player in targets do
		local config = LiveConfig:new(target.Configs.Tycoon)
		local amt = args["amt"]
		if not config.Balance then
			error("Player does not have a balance")
		end
		if args["action"] == "add" then
			config.Balance += tonumber(amt)
		elseif args["action"] == "set" then
			config.Balance = tonumber(amt)
		else
			error("Invalid action input!")
		end
	end
end

----------------------------------------

local rebirth = admin:AddCommand("rebirth", 49, "Force a player to rebirth")

rebirth.Action = function(_self, args)
	local targets = args[".targets"] or { args[".caller"] }
	for _, target in targets do
		GameTycoons.Utils.rebirthPlayer(target, true)
	end
end

-- =============== Gun Commands ==============

local gbuild =
	admin:AddCommand("gbuild", 10, "Give a gun to the specified player(s)")
gbuild:AddPositional("name", "Name of gun to give")

gbuild.Action = function(_self, args)
	local targets = args[".targets"] or { args[".caller"] }
	local name = args["name"]
	for _, target in targets do
		GunUtils.giveGun(target, name)
	end
end

----------------------------------------

local grand = admin:AddCommand(
	"grand",
	10,
	"Give a random gun to the specified player(s)"
)

grand.Action = function(_self, args)
	local targets = args[".targets"] or { args[".caller"] }
	for _, target in targets do
		GunUtils.giveRandomGun(target)
	end
end

-- =============== Tool Commands ==============

local addTool = admin:AddCommand("tadd", 50, "Add a tool to player(s) data")
addTool:AddPositional("tool", "Tool to add")
addTool.Action = function(_self, args)
	local targets = args[".targets"] or { args[".caller"] }
	local tName = args["tool"]
	for _, target in targets do
		local success = ToolManager:AddPlayerTool(target, tName)
		if not success then
			error("Failed to add tool for player " .. target.Name)
		end
	end
	return "Added " .. tName .. " to specified player(s)"
end

----------------------------------------

local clearTools =
	admin:AddCommand("tclear", 99, "Clear a single player's tools")
clearTools.Action = function(_self, args)
	local target = (args[".targets"] and args[".targets"][1])
		or args[".caller"]
	-- Clear from data store
	local key = string.format("U%s/Tools", target.UserId)
	PlayerStore:Set(key, {})
	-- Clear from manager cache
	ToolManager.playerMap[target] = {}
	return "Cleared tools for player " .. target.Name
end

----------------------------------------

local tgive =
	admin:AddCommand("tgive", 5, "Add any tool to a player's inventory")
tgive:AddPositional("name", "Name of the tool to give")
tgive.Action = function(_self, args)
	local toolName = args["name"]
	local toolInfo = ToolManager.Data.infoMap[toolName]
	assert(toolInfo, `Tool of name {toolName} does not exists`)
	local targets = args[".targets"] or { args[".caller"] }
	for _, target in targets do
		if toolInfo.Type == "Gun" then
			GunUtils.giveGun(target, toolName)
		else
			error("Giving tools other than guns is no implemented")
		end
	end
end

-- =============== Vehicle Commands ==============

local vbuild =
	admin:AddCommand("vbuild", 10, "Spawn the specified vehicle on the player")
vbuild:AddPositional("name", "Name of vehicle to spawn")

vbuild.Action = function(_self, args)
	local targets = args[".targets"] or { args[".caller"] }
	for _, target in targets do
		local name = args["name"]
		local hrp = target.Character.HumanoidRootPart
		local cframe = hrp.CFrame * CFrame.new(0, 20, -15)
		VehicleUtils.spawnVehicle(name, cframe)
	end
end

----------------------------------------

local clearVehicles =
	admin:AddCommand("vclear", 99, "Clear a single player's vehicles")
clearVehicles.Action = function(_self, args)
	local target = (args[".targets"] and args[".targets"][1])
		or args[".caller"]
	-- Clear from data store
	local key = string.format("U%s/Vehicles", target.UserId)
	PlayerStore:Set(key, {})
	-- Clear from manager cache
	VehicleManager.playerMap[target] = {}
	return "Cleared vehicles for player " .. target.Name
end

----------------------------------------

local addVehicle =
	admin:AddCommand("vadd", 50, "Add a vehicle to player(s) data")
addVehicle:AddPositional("vehicle", "Vehicle to add")
addVehicle.Action = function(_self, args)
	local targets = args[".targets"] or { args[".caller"] }
	local vName = args["vehicle"]
	for _, target in targets do
		local success = VehicleManager:AddPlayerVehicle(target, vName)
		if not success then
			error("Failed to add vehicle for player " .. target.Name)
		end
	end
	return "Added " .. vName .. " to specified player(s)"
end

-- =============== Cash Boosts ============

local boost =
	admin:AddCommand("boosts", 90, "Perform cash boost related actions")
boost:AddPositional("action", "Cash boost related action to perform")
boost:AddPositional(
	"name",
	"Cash boost name or id to interact with",
	Listener.Optional
)

boost.Action = function(_self, args)
	local action = args["action"]
	local boostRef = args["name"] -- name or id depending on action
	local targets = args[".targets"] or { args[".caller"] }
	for _, target in targets do
		if action == "add" then
			local id = CashBoosts.Manager.addCashBoost(target, boostRef)
			return "Added boost id " .. id
		elseif action == "activate" then
			CashBoosts.Manager.activateCashBoost(target, boostRef)
		elseif action == "clear" then
			PlayerData:Set(target, "CashBoostInventory", {})
		else
			error("Invalid cash boost action: " .. action)
		end
	end
end

-- =============== Chests ============

local chest = admin:AddCommand("chests", 51, "Perform chest related actions")
chest:AddPositional("action", "Chest related action to perform")
chest:AddPositional("name", "Chest name to interact with", Listener.Optional)
chest:AddPositional(
	"count",
	"Potential chest count to include",
	Listener.Optional
)

chest.Action = function(_self, args)
	local action = args["action"]
	local name = args["name"]
	local targets = args[".targets"] or { args[".caller"] }
	for _, target in targets do
		if action == "add" then
			local succes =
				Chests.addChest(target, name, tonumber(args["count"]))
			assert(succes, "Failed to add chest")
			return "Added chest " .. name
		elseif action == "clear" then
			PlayerData:Set(target, "ChestInventory", {})
		else
			error("Invalid chest action: " .. action)
		end
	end
end

-- =============== Spinner ============

local spinner =
	admin:AddCommand("spinner", 99, "Perform spinner related actions")
spinner:AddPositional("action", "Action to perform")
spinner:AddPositional("count", "Number of spins", 1)

spinner.Action = function(_self, args)
	local action = args["action"]
	local name = args["name"]
	local count = tonumber(args["count"])
	local targets = args[".targets"] or { args[".caller"] }
	for _, target in targets do
		if action == "add" then
			Spinner.addSpins(target, count)
		elseif action == "set" then
			PlayerData:Set(target, "AvailableSpins", count)
		elseif action == "clear" then
			PlayerData:Set(target, "AvailableSpins", 0)
			PlayerData:Set(target, "PreviousSpinnerRewards", {})
		else
			error("Invalid spinner action: " .. action)
		end
	end
end

-- =============== Data ============

local wipe = admin:AddCommand("wipe", 99, "Clear a single player's data")

wipe.Action = function(_self, args)
	local target = args[".caller"]
	if args[".targets"] then
		target = args[".targets"][1]
	end
	local prefix = string.format("U%s/", target.UserId)
	local keys = PlayerStore:ListKeys(prefix)
	for _, key in pairs(keys) do
		PlayerStore:Remove(key)
	end
	PlayerData.playerMap[target] = {}
	VehicleManager.playerMap[target] = {}
	ToolManager.playerMap[target] = {}
	PlayerData:Set(target, "LastLogin", os.time())
end

admin:Start()
