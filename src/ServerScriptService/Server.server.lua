--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ServerApp = ServerScriptService:WaitForChild("App")

local Runner = require(ServerApp.Modules.ServiceRunner)

local services = {
	require(ServerApp.Services.MoveAC),
}

Runner.boot(services)
