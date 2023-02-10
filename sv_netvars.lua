-- This code is taken from NutScript.
-- NutScript and code license are found here:
-- https://github.com/Chessnut/NutScript

--if (netvars) then return end

netvars = netvars or {}

local stored = netvars.stored or {}
netvars.stored = stored

local globals = netvars.globals or {}
netvars.globals = globals

local _R = debug.getregistry()
local entityMeta = _R.Entity
local playerMeta = _R.Player

-- Check if there is an attempt to send a function. Can't send those.
local function checkBadType(name, object)
	local objectType = type(object)

	if (objectType == "function") then
		ErrorNoHalt("Net var '"..name.."' contains a bad object type!\n")

		return true
	end
end

function netvars.SetNetVar(key, value, receiver)
	if (checkBadType(key, value)) then return end
	if (globals[key] == value) then return end

	globals[key] = value
	netstream.Start(receiver, "gVar", key, value)
end

function playerMeta:SyncVars()
	netstream.Start(self, "sync_nVars", stored, globals)
end

function entityMeta:SendNetVar(key, receiver)
	local index = self:EntIndex()
	local stored_index = stored[index]

	netstream.Start(receiver, "nVar", index, key, stored_index and stored_index[key])
end

function entityMeta:ClearNetVars(receiver)
	local index = self:EntIndex()
	if stored[index] then
		stored[index] = nil
		netstream.Start(receiver, "nDel", index)
	end
end

function entityMeta:SetNetVar(key, value, receiver)
	if (checkBadType(key, value)) then return end
	if (not istable(value) and value == self:GetNetVar(key)) then return end

	local index = self:EntIndex()
	local stored_index = stored[index] or {}

	stored_index[key] = value
	stored[index] = stored_index

	self:SendNetVar(key, receiver)
end

function entityMeta:GetNetVar(key, default)
	local index = self:EntIndex()
	local value = stored[index]


	if value and value[key] ~= nil then
		return value[key]
	end

	return default
end

function playerMeta:SetLocalVar(key, value)
	if (checkBadType(key, value)) then return end
	if (not istable(value) and value == self:GetNetVar(key)) then return end

	local index = self:EntIndex()
	local stored_index = stored[index] or {}

	stored_index[key] = value
	stored[index] = stored_index

	netstream.Start(self, "nLcl", index, key, value)
end

playerMeta.GetLocalVar = entityMeta.GetNetVar

function netvars.GetNetVar(key, default)
	local value = globals[key]

	if value ~= nil then
		return value
	end

	return default
end

hook.Add("EntityRemoved", "nCleanUp", function(entity)
	entity:ClearNetVars()
end)

hook.Add("PlayerInitialized", "nSync", function(client)
	client:SyncVars()
end)

netstream.Hook("PlayerInitialized", function(ply)
	if ply:GetNetVar("IsLoaded", false) then return end

	ply:SetNetVar("IsLoaded", true)
	return hook.Run("PlayerInitialized", ply)
end)