--!strict
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SharedApp = ReplicatedStorage:WaitForChild("App")
local ServerApp = ServerScriptService:WaitForChild("App")
local Cfg = require(SharedApp.Config.MovementConfig)
local Geom = require(SharedApp.Utilities.MovementMath)
local Types = require(SharedApp.Types.MovementTypes)
local SessionMod = require(ServerApp.SubServices.PlayerSession)

type Session = SessionMod.Session
type ServerSample = Types.ServerSample

local Sampler = {}

function Sampler.snap(session: Session, now: number, dt: number): ServerSample?
	local root = session.root
	local humanoid = session.humanoid

	if root == nil or humanoid == nil or not root:IsDescendantOf(workspace) then
		root, humanoid = Geom.rigOf(session.char)
		session.root = root
		session.humanoid = humanoid
	end

	if root == nil or humanoid == nil then
		return nil
	end

	local state = humanoid:GetState()
	local floor = humanoid.FloorMaterial
	local onFloor = Geom.onFloor(floor, state)
	local reported = humanoid.WalkSpeed
	local trusted = math.min(math.max(Cfg.defaultSpeed, reported), Cfg.maxSpeed)

	return {
		t = now,
		dt = Geom.clampDt(dt),
		pos = root.Position,
		vel = root.AssemblyLinearVelocity,
		cf = root.CFrame,
		state = state,
		floor = floor,
		onFloor = onFloor,
		walkSpeed = trusted,
		reportedSpeed = reported,
	}
end

return table.freeze(Sampler)
