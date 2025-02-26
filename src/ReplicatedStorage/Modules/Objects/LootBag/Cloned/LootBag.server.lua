local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LootBag = require(ReplicatedStorage.Modules.Objects.LootBag)

local part = script.Parent
local owner = Players:GetPlayerByUserId(part:GetAttribute("Owner"))
local source = Players:GetPlayerByUserId(part:GetAttribute("Source") or -1)

local bag = LootBag:new(part, source)
bag:Attach(owner)
