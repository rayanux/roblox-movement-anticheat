--!strict
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SharedApp = ReplicatedStorage:WaitForChild("App")
local ServerApp = ServerScriptService:WaitForChild("App")
local Cfg = require(SharedApp.Config.MovementConfig)
local Geom = require(SharedApp.Utilities.MovementMath)
local Types = require(SharedApp.Types.MovementTypes)
local Reason = require(SharedApp.Enums.Reason)

local Physics = require(ServerApp.SubServices.PhysicsChecks)
local SessionMod = require(ServerApp.SubServices.PlayerSession)

type Session = SessionMod.Session
type ServerSample = Types.ServerSample
type Violation = Types.Violation

local MovementChecks = {}

local function violation(kind: number, sev: number, msg: string, correct: boolean): Violation
	return { kind = kind, sev = sev, msg = msg, correct = correct }
end

local OK: Violation = { kind = Reason.None, sev = 0, msg = "ok", correct = false }

local function worse(a: Violation, b: Violation?): Violation
	if b ~= nil and b.sev > a.sev then return b end
	return a
end

local function wasClimbing(p: ServerSample?): boolean
	return p ~= nil and p.state == Enum.HumanoidStateType.Climbing
end

local function checkSpeed(s: Session, prev: ServerSample?, cur: ServerSample): Violation?
	if prev == nil then return nil end

	if cur.reportedSpeed > Cfg.maxSpeed + 0.5 then
		return violation(Reason.WalkSpeed, 6, "ws too high", true)
	end

	if wasClimbing(prev) or cur.state == Enum.HumanoidStateType.Climbing then
		s.speedStreak = 0
		s.speedWin:wipe()
		return nil
	end

	local dt = math.max(Cfg.minCheckDt, cur.dt)
	local disp = cur.pos - prev.pos

	if Cfg.checks.teleport and disp.Magnitude > Cfg.maxTeleport then
		s.speedStreak = 0
		return violation(Reason.Teleport, 8, "tp delta", true)
	end

	local fromDisp = Geom.flatMag(disp) / dt
	local fromVel = Geom.flatMag(cur.vel)
	local now = math.max(fromDisp, fromVel)
	s.speedWin:push(now)
	local avg = s.speedWin:avg()

	local cap = cur.walkSpeed * Cfg.speedMult + Cfg.speedMargin

	local fudge = 0
	if cur.t - s.lastLanded < Cfg.landingGrace then
		fudge = cur.walkSpeed * 0.5
	end
	if cur.onFloor and not prev.onFloor then
		fudge = math.max(fudge, cur.walkSpeed * 0.6)
	end
	if cur.floor ~= prev.floor then
		fudge = math.max(fudge, 4)
	end

	if not Cfg.checks.speed or avg <= cap + fudge then
		s.speedStreak = math.max(0, s.speedStreak - 1)
		return nil
	end

	s.speedStreak += 1
	if s.speedStreak < Cfg.speedStreak then return nil end

	local bad = avg > cap * 1.45
	return violation(Reason.Speed, if bad then 6 else 4, "speed over", bad)
end

local function checkAccel(s: Session, prev: ServerSample?, cur: ServerSample): Violation?
	if prev == nil or not Cfg.checks.accel then return nil end
	local dt = math.max(Cfg.minCheckDt, cur.dt)
	local dvx = cur.vel.X - prev.vel.X
	local dvz = cur.vel.Z - prev.vel.Z
	local a = math.sqrt(dvx * dvx + dvz * dvz) / dt
	if a <= Cfg.maxAccel then
		s.accelStreak = math.max(0, s.accelStreak - 1)
		return nil
	end
	s.accelStreak += 1
	if s.accelStreak < Cfg.accelStreak then return nil end
	return violation(Reason.Accel, 3, "accel spike", false)
end

-- Airtime used to be one flat limit. Splitting hover from big falls keeps
-- normal drops from looking like flight.
local function checkAir(s: Session, cur: ServerSample): Violation?
	if cur.onFloor then
		s.airTime = 0
		s.hoverFrames = 0
		s.lastLanded = cur.t
		return nil
	end

	if cur.state == Enum.HumanoidStateType.Jumping then
		s.lastJump = cur.t
	end

	s.airTime += cur.dt
	if not Cfg.checks.airTime or s.airTime <= Cfg.maxAirTime then
		return nil
	end

	if cur.vel.Y <= Cfg.fastFallY then
		s.hoverFrames = 0
		return nil
	end

	local h = Geom.flatMag(cur.vel)
	local lowVy = math.abs(cur.vel.Y) <= Cfg.hoverTopY
	local stuck = lowVy and h <= Cfg.hoverHoldHorizSpeed

	if stuck then
		s.hoverFrames += 1
		if s.hoverFrames >= Cfg.hoverHoldFrames then
			return violation(Reason.Fly, 5, "hover", true)
		end
		return nil
	end

	s.hoverFrames = math.max(0, s.hoverFrames - 1)

	-- Keep this softer than hover; one slow fall frame should not mean flying.
	if lowVy and s.airTime > Cfg.maxAirTime + 0.5 then
		return violation(Reason.Fly, 4, "slow-fall", true)
	end

	return nil
end

local function checkDrift(s: Session, cur: ServerSample): Violation?
	if s.lastClientPos == nil or not Cfg.checks.desync then
		return nil
	end
	local last = s.lastClientPos :: Vector3
	if (last - cur.pos).Magnitude <= Cfg.maxDesync then return nil end
	return violation(Reason.Desync, 2, "client desync", false)
end

function MovementChecks.run(plr: Player, s: Session, sample: ServerSample): Violation
	if s.exempt or sample.t < s.safeUntil or sample.t < s.pauseUntil then
		s.airTime = 0
		s.hoverFrames = 0
		s.speedStreak = 0
		return OK
	end

	if Geom.lenientState(sample.state) then
		s.airTime = 0
		s.hoverFrames = 0
		s.speedStreak = 0
		return OK
	end

	local prev = s.buf:head() :: ServerSample?
	local v: Violation = OK

	v = worse(v, checkSpeed(s, prev, sample))
	v = worse(v, checkAccel(s, prev, sample))
	v = worse(v, checkAir(s, sample))
	v = worse(v, checkDrift(s, sample))
	v = worse(v, Physics.verticalVel(sample))
	v = worse(v, Physics.ownership(plr, s.root))
	v = worse(v, Physics.slope(sample, s.rayParams))
	if not wasClimbing(prev) then
		v = worse(v, Physics.noclip(prev, sample, s.rayParams))
	end

	return v
end

return table.freeze(MovementChecks)
