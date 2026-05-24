--!strict
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SharedApp = ReplicatedStorage:WaitForChild("App")
local ServerApp = ServerScriptService:WaitForChild("App")
local Cfg = require(SharedApp.Config.MovementConfig)
local Types = require(SharedApp.Types.MovementTypes)
local Log = require(ServerApp.Debug.Logger)

type Hook = (plr: Player, v: Types.Violation) -> ()

local V = {}
local cb: Hook? = nil
local coolMap: { [string]: number } = {}

function V.onTriggered(fn: Hook?)
	cb = fn
end

local function noisy(plr: Player, v: Types.Violation): boolean
	if v.sev < Cfg.logMinSev then return false end
	local k = plr.UserId .. ":" .. v.kind
	local now = workspace:GetServerTimeNow()
	local last = coolMap[k]
	if last ~= nil and now - last < Cfg.logCooldown then return false end
	coolMap[k] = now
	return true
end

function V.report(plr: Player, v: Types.Violation)
	if noisy(plr, v) then
		Log.warn(string.format("%s: %s (sev %.1f)", plr.Name, v.msg, v.sev))
	end
	if cb ~= nil then
		task.spawn(cb, plr, v)
	end
end

function V.forget(plr: Player)
	local p = plr.UserId .. ":"
	for k in pairs(coolMap) do
		if string.sub(k, 1, #p) == p then
			coolMap[k] = nil
		end
	end
end

return table.freeze(V)
