--!strict
--!optimize 2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SharedApp = ReplicatedStorage:WaitForChild("App")
local Config = require(SharedApp.Config.MovementConfig)
local Wire = require(SharedApp.Networking.MovementPackets)
local Names = require(SharedApp.Networking.MovementRemotes)
local Janitor = require(SharedApp.Utilities.Janitor)
local Geom = require(SharedApp.Utilities.MovementMath)

local PUSH_INTERVAL = 1 / Config.clientHz

local PredictionController = {
	Name = "PredictionController",
}

local bin = Janitor.new()
local me = Players.LocalPlayer
local sampleRemote: RemoteEvent? = nil
local char: Model? = nil
local root: BasePart? = nil
local humanoid: Humanoid? = nil
local seq = 0
local clock = 0

local function findSampleRemote(): RemoteEvent
	local remotes = SharedApp:WaitForChild("Remotes")
	local box = remotes:WaitForChild(Names.folder)
	return box:WaitForChild(Names.sample) :: RemoteEvent
end

local function bindCharacter(newChar: Model?)
	char = newChar
	root, humanoid = Geom.rigOf(char)
end

local function pushSample()
	if sampleRemote == nil then return end
	if root == nil or humanoid == nil or not root:IsDescendantOf(workspace) then
		root, humanoid = Geom.rigOf(char)
	end
	if root == nil or humanoid == nil then return end

	seq += 1
	local payload = Wire.packSample(
		seq,
		workspace:GetServerTimeNow(),
		root.Position,
		root.AssemblyLinearVelocity,
		humanoid:GetState(),
		humanoid.FloorMaterial
	)
	sampleRemote:FireServer(payload)
end

function PredictionController:Start()
	if me == nil then return end

	sampleRemote = findSampleRemote()
	bin:hook(me.CharacterAdded:Connect(bindCharacter))
	bin:hook(me.CharacterRemoving:Connect(function()
		bindCharacter(nil)
	end))
	bin:hook(RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		if clock < PUSH_INTERVAL then return end
		clock = 0
		pushSample()
	end))

	bindCharacter(me.Character)
end

return PredictionController
