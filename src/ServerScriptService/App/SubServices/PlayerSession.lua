--!strict
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedApp = ReplicatedStorage:WaitForChild("App")
local Cfg = require(SharedApp.Config.MovementConfig)
local Geom = require(SharedApp.Utilities.MovementMath)
local Janitor = require(SharedApp.Utilities.Janitor)
local Throttle = require(SharedApp.Utilities.RateLimiter)
local Trail = require(SharedApp.Utilities.Trail)

local START_SEQ = -1
local SPEED_WIN = 6

local Session = {}
Session.__index = Session

export type Session = typeof(setmetatable({} :: {
	player: Player,
	char: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	buf: Trail.Trail,
	speedWin: Trail.Trail,
	bin: Janitor.Janitor,
	charBin: Janitor.Janitor,
	throttle: Throttle.Throttle,
	rayParams: RaycastParams,
	lastSafeCf: CFrame?,
	lastClientPos: Vector3?,
	lastClientVel: Vector3?,
	lastClientTime: number,
	lastSeq: number,
	score: number,
	punish: number,
	exempt: boolean,
	safeUntil: number,
	pauseUntil: number,
	lastFix: number,
	airTime: number,
	hoverFrames: number,
	speedStreak: number,
	accelStreak: number,
	lastLanded: number,
	lastJump: number,
}, Session))

local function makeRayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = false
	params.FilterDescendantsInstances = {}
	return params
end

function Session.new(player: Player): Session
	local self = setmetatable({
		player = player,
		char = nil,
		humanoid = nil,
		root = nil,
		buf = Trail.new(Cfg.bufSize),
		speedWin = Trail.new(SPEED_WIN),
		bin = Janitor.new(),
		charBin = Janitor.new(),
		throttle = Throttle.new(Cfg.pkRateLimit, Cfg.pkBurst),
		rayParams = makeRayParams(),
		lastSafeCf = nil,
		lastClientPos = nil,
		lastClientVel = nil,
		lastClientTime = 0,
		lastSeq = START_SEQ,
		score = 0,
		punish = 0,
		exempt = false,
		safeUntil = 0,
		pauseUntil = 0,
		lastFix = 0,
		airTime = 0,
		hoverFrames = 0,
		speedStreak = 0,
		accelStreak = 0,
		lastLanded = 0,
		lastJump = 0,
	}, Session) :: Session

	self.bin:hook(player.CharacterAdded:Connect(function(char: Model)
		self:bindCharacter(char)
	end))
	self.bin:hook(player.CharacterRemoving:Connect(function(char: Model)
		if self.char == char then
			self:bindCharacter(nil)
		end
	end))

	if player.Character ~= nil then
		task.spawn(function()
			self:bindCharacter(player.Character)
		end)
	end

	return self
end

function Session.bindCharacter(self: Session, char: Model?)
	self.charBin:clear()
	self.char = char

	local root, humanoid = Geom.rigOf(char)
	self.root = root
	self.humanoid = humanoid
	self.rayParams.FilterDescendantsInstances = if char ~= nil then { char } else {}

	self.buf:wipe()
	self.speedWin:wipe()
	self.pauseUntil = workspace:GetServerTimeNow() + Cfg.spawnGrace
	self.score = 0
	self.punish = 0
	self.airTime = 0
	self.hoverFrames = 0
	self.speedStreak = 0
	self.accelStreak = 0

	if root ~= nil then
		self.lastSafeCf = root.CFrame
	end

	if humanoid ~= nil then
		self.charBin:hook(humanoid.Died:Connect(function()
			self.buf:wipe()
			self.score = 0
			self.punish = 0
			self.airTime = 0
			self.hoverFrames = 0
			self.speedStreak = 0
		end))
	end
end

function Session.destroy(self: Session)
	self.bin:clear()
	self.charBin:clear()
	self.throttle:forget(tostring(self.player.UserId))
end

return Session
