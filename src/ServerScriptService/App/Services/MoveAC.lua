--!strict
--!optimize 2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local SharedApp = ReplicatedStorage:WaitForChild("App")
local ServerApp = ServerScriptService:WaitForChild("App")
local Cfg = require(SharedApp.Config.MovementConfig)
local Wire = require(SharedApp.Networking.MovementPackets)
local Janitor = require(SharedApp.Utilities.Janitor)
local Types = require(SharedApp.Types.MovementTypes)
local Reason = require(SharedApp.Enums.Reason)

local Log = require(ServerApp.Debug.Logger)
local Endpoints = require(ServerApp.SubServices.MovementRemotes)
local SessionMod = require(ServerApp.SubServices.PlayerSession)
local MovementChecks = require(ServerApp.SubServices.MovementChecks)
local Sampler = require(ServerApp.SubServices.MoveSampler)
local Reconciler = require(ServerApp.SubServices.Reconciler)
local Violations = require(ServerApp.SubServices.ViolationHandler)

type Session = SessionMod.Session
type Violation = Types.Violation
type EndpointBundle = Endpoints.Endpoints

local TICK = 1 / Cfg.serverHz
local PACKET_SEV = 4

local MoveAC = {}
MoveAC.__index = MoveAC

export type MoveAC = typeof(setmetatable({} :: {
	Name: string,
	_sessions: { [Player]: Session },
	_bin: Janitor.Janitor,
	_endpoints: EndpointBundle?,
	_clock: number,
}, MoveAC))
export type Guard = MoveAC

local function violation(kind: number, sev: number, msg: string, correct: boolean): Violation
	return { kind = kind, sev = sev, msg = msg, correct = correct }
end

function MoveAC.new(): MoveAC
	return setmetatable({
		Name = "MoveAC",
		_sessions = {},
		_bin = Janitor.new(),
		_endpoints = nil,
		_clock = 0,
	}, MoveAC) :: MoveAC
end

function MoveAC.attach(self: MoveAC, player: Player)
	if self._sessions[player] ~= nil then return end
	self._sessions[player] = SessionMod.new(player)
end

function MoveAC.detach(self: MoveAC, player: Player)
	Violations.forget(player)
	local session = self._sessions[player]
	if session ~= nil then
		session:destroy()
		self._sessions[player] = nil
	end
end

function MoveAC.flagPacket(_: MoveAC, player: Player, msg: string, sev: number?)
	Violations.report(player, violation(Reason.SpoofedPacket, sev or PACKET_SEV, msg, false))
end

function MoveAC.onClientPacket(self: MoveAC, player: Player, payload: any)
	local session = self._sessions[player]
	if session == nil then return end

	local now = workspace:GetServerTimeNow()
	if not session.throttle:take(tostring(player.UserId), now) then
		self:flagPacket(player, "packet rate limit exceeded", 2)
		return
	end

	local packet, err = Wire.unpackSample(payload)
	if packet == nil then
		self:flagPacket(player, err or "packet decode failed")
		return
	end
	if packet.seq <= session.lastSeq then
		self:flagPacket(player, "packet replayed or out of order")
		return
	end

	local age = now - packet.clientTime
	if age > Cfg.pkMaxAge or age < -Cfg.pkFutureGrace then
		self:flagPacket(player, "packet timestamp outside window")
		return
	end

	session.lastSeq = packet.seq
	session.lastClientTime = packet.clientTime
	if now >= session.pauseUntil then
		session.lastClientPos = packet.pos
		session.lastClientVel = packet.vel
	end
end

local function countsForPunish(v: Violation): boolean
	if v.sev < Cfg.minKickSev then return false end
	return (not Cfg.requireFix) or v.correct
end

local function pastKick(session: Session, now: number): boolean
	return Cfg.kickEnabled
		and now >= session.pauseUntil
		and session.punish >= Cfg.kickScore
end

function MoveAC.tick(self: MoveAC, dt: number)
	local now = workspace:GetServerTimeNow()
	local fixRemote = if self._endpoints ~= nil then self._endpoints.fix else nil

	for player, session in pairs(self._sessions) do
		local sample = Sampler.snap(session, now, dt)
		if sample == nil then continue end

		local v = MovementChecks.run(player, session, sample)
		if v.sev > 0 then
			session.score += v.sev
			if countsForPunish(v) then
				session.punish += v.sev
			end
			Violations.report(player, v)

			if pastKick(session, now) then
				player:Kick(Cfg.kickMessage)
				continue
			end

			if fixRemote ~= nil and Reconciler.apply(session, sample, v, fixRemote) then
				session.buf:wipe()
				session.speedWin:wipe()
				session.score = 0
				session.airTime = 0
				session.hoverFrames = 0
				session.speedStreak = 0
				continue
			end
		else
			session.score = math.max(0, session.score - Cfg.scoreDecay * dt)
			session.punish = math.max(0, session.punish - Cfg.punishDecay * dt)
			session.lastSafeCf = sample.cf
		end

		session.buf:push(sample)
	end
end

function MoveAC.Init(self: MoveAC)
	self._endpoints = Endpoints.build()
	Log.enable(Cfg.logEnabled)
end

function MoveAC.Start(self: MoveAC)
	local eps = self._endpoints
	assert(eps ~= nil, "MoveAC.Init must run before Start")
	local bundle = eps :: EndpointBundle

	self._bin:hook(bundle.sample.OnServerEvent:Connect(function(player: Player, payload: any)
		self:onClientPacket(player, payload)
	end))
	self._bin:hook(Players.PlayerAdded:Connect(function(player: Player)
		self:attach(player)
	end))
	self._bin:hook(Players.PlayerRemoving:Connect(function(player: Player)
		self:detach(player)
	end))
	self._bin:hook(RunService.Heartbeat:Connect(function(dt: number)
		self._clock += dt
		if self._clock < TICK then return end
		local elapsed = self._clock
		self._clock = 0
		self:tick(elapsed)
	end))

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:attach(player)
		end)
	end
end

function MoveAC.SetExempt(self: MoveAC, player: Player, exempt: boolean)
	local session = self._sessions[player]
	if session ~= nil then
		session.exempt = exempt
	end
end

function MoveAC.NoteSafeTeleport(self: MoveAC, player: Player, cf: CFrame, reason: string?)
	local session = self._sessions[player]
	if session == nil then return end
	local now = workspace:GetServerTimeNow()
	session.safeUntil = now + Cfg.fixGrace
	session.pauseUntil = session.safeUntil
	session.lastSafeCf = cf
	Log.info(string.format("safe teleport registered for %s (%s)", player.Name, reason or "unspecified"))
end

function MoveAC.SetDebug(_: MoveAC, state: boolean)
	Log.enable(state)
end

return MoveAC.new()
