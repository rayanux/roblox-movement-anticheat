--!strict
--!optimize 2

local Reason = table.freeze({
	None = 0,
	Speed = 1,
	Fly = 2,
	Noclip = 3,
	Teleport = 4,
	Physics = 5,
	Accel = 6,
	Desync = 7,
	SpoofedPacket = 8,
	NetworkOwnership = 9,
	BadGround = 10,
	WalkSpeed = 11,
})

export type Reason = number

return Reason
