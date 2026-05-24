--!strict
--!optimize 2

local Names = {
	folder = "Movement",
	sample = "MovementSample",
	correction = "MovementCorrection",
}

export type RemoteName = "MovementSample" | "MovementCorrection"

return table.freeze(Names)
