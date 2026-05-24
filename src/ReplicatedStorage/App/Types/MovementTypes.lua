--!strict

export type ClientPacket = {
	seq: number,
	clientTime: number,
	pos: Vector3,
	vel: Vector3,
	state: number,
	floor: number,
}

export type ServerSample = {
	t: number,
	dt: number,
	pos: Vector3,
	vel: Vector3,
	cf: CFrame,
	state: Enum.HumanoidStateType,
	floor: Enum.Material,
	onFloor: boolean,
	walkSpeed: number,
	reportedSpeed: number,
}

export type Violation = {
	kind: number,
	sev: number,
	msg: string,
	correct: boolean,
}

export type FixSnap = {
	seq: number,
	t: number,
	pos: Vector3,
	vel: Vector3,
	reason: number,
	sev: number,
}

return table.freeze({})
