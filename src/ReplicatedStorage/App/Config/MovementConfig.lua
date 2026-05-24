--!strict
--!optimize 2

local Config = {}

-- Tick rates / buffers
Config.serverHz = 20
Config.clientHz = 14
Config.bufSize = 32
Config.fixBufSize = 20

-- Humanoid limits
Config.defaultSpeed = 16
Config.maxSpeed = 24

-- Timing grace
Config.minDt = 1 / 120
Config.maxDt = 0.5
Config.minCheckDt = 1 / 90

Config.spawnGrace = 3.0
Config.landingGrace = 0.45

-- Client packet window
Config.pkRateLimit = 48
Config.pkBurst = 24
Config.pkMaxAge = 1.5
Config.pkFutureGrace = 0.25
Config.posDigits = 100
Config.velDigits = 10

-- Movement checks
Config.maxDesync = 12
Config.maxTeleport = 22
Config.speedMult = 1.30
Config.speedMargin = 5.0
Config.speedStreak = 4
Config.maxAccel = 320
Config.accelStreak = 3

-- Air / hover checks
Config.maxAirTime = 2.5
Config.hoverTopY = 16
Config.hoverHoldFrames = 8
Config.hoverHoldHorizSpeed = 4
Config.fastFallY = -28

-- World physics checks
Config.maxVyUp = 90
Config.maxVyDown = 320
Config.maxSlope = 65
Config.groundRay = 8
Config.maxGroundDist = 4.5
Config.noclipMinCast = 0.25
Config.wallNormalY = 0.45

-- Correction / punishment
Config.fixGrace = 1.2
Config.fixDist = 3
Config.fixCooldown = 0.18
Config.fixSmooth = 0.12
Config.scoreDecay = 2
Config.punishDecay = 1.5
Config.fixScore = 4
Config.hardSev = 7
Config.minVizOffset = 0.1

-- Logging
Config.logEnabled = true
Config.logMinSev = 4
Config.logCooldown = 1.5

-- Final action
Config.kickEnabled = true
Config.kickScore = 18
Config.minKickSev = 6
Config.requireFix = true
Config.kickMessage = "Movement exploit detected."

Config.checks = table.freeze({
	speed = true,
	teleport = true,
	accel = true,
	airTime = true,
	noclip = true,
	physics = true,
	ownership = true,
	desync = true,
})

export type Config = typeof(Config)

return table.freeze(Config)
