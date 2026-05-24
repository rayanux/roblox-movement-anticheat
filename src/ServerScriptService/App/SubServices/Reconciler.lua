--!strict
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SharedApp = ReplicatedStorage:WaitForChild("App")
local ServerApp = ServerScriptService:WaitForChild("App")
local Cfg = require(SharedApp.Config.MovementConfig)
local Wire = require(SharedApp.Networking.MovementPackets)
local Types = require(SharedApp.Types.MovementTypes)
local Reason = require(SharedApp.Enums.Reason)

local SessionMod = require(ServerApp.SubServices.PlayerSession)

type Session = SessionMod.Session
type ServerSample = Types.ServerSample
type Violation = Types.Violation
type FixSnap = Types.FixSnap

local ZERO = Vector3.zero

local Reconciler = {}

local function canReconcile(session: Session, sample: ServerSample, v: Violation): boolean
	if not v.correct then return false end
	if sample.t - session.lastFix < Cfg.fixCooldown then return false end
	if v.sev < Cfg.hardSev and session.score < Cfg.fixScore then
		return false
	end
	if session.lastSafeCf == nil then return false end
	if v.sev >= Cfg.hardSev then return true end
	local safeCf = session.lastSafeCf :: CFrame
	return (sample.pos - safeCf.Position).Magnitude >= Cfg.fixDist
end

function Reconciler.apply(session: Session, sample: ServerSample, v: Violation, remote: RemoteEvent): boolean
	if not canReconcile(session, sample, v) then return false end

	local root = session.root
	local char = session.char
	local safeCf = session.lastSafeCf
	if root == nil or char == nil or safeCf == nil then return false end

	if session.humanoid ~= nil and v.kind == Reason.WalkSpeed then
		session.humanoid.WalkSpeed = Cfg.defaultSpeed
	end

	char:PivotTo(safeCf)
	root.AssemblyLinearVelocity = ZERO
	root.AssemblyAngularVelocity = ZERO
	session.lastFix = sample.t

	local snap: FixSnap = {
		seq = session.lastSeq,
		t = sample.t,
		pos = safeCf.Position,
		vel = ZERO,
		reason = v.kind,
		sev = v.sev,
	}
	remote:FireClient(session.player, Wire.packFix(snap))
	return true
end

return table.freeze(Reconciler)
