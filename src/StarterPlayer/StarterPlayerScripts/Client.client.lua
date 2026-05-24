--!strict

local StarterPlayerScripts = script.Parent
local ClientApp = StarterPlayerScripts:WaitForChild("App")

local Runner = require(ClientApp.Modules.ControllerRunner)

local controllers = {
	require(ClientApp.Controllers.PredictionController),
	require(ClientApp.Controllers.CorrectionController),
}

Runner.boot(controllers)
