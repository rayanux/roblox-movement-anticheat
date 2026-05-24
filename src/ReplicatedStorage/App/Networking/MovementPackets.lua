--!strict
--!optimize 2

local App = script.Parent.Parent
local Cfg = require(App.Config.MovementConfig)
local Types = require(App.Types.MovementTypes)

type ClientPacket = Types.ClientPacket
type FixSnap = Types.FixSnap

local Wire = {}

local function snapNum(value: number, scale: number): number
	return math.round(value * scale) / scale
end

local function snapVec(v: Vector3, scale: number): Vector3
	return Vector3.new(snapNum(v.X, scale), snapNum(v.Y, scale), snapNum(v.Z, scale))
end

function Wire.packSample(seq: number, clientTime: number, pos: Vector3, vel: Vector3, state: Enum.HumanoidStateType, floor: Enum.Material): { any }
	return {
		math.max(0, math.floor(seq)),
		snapNum(clientTime, 1000),
		snapVec(pos, Cfg.posDigits),
		snapVec(vel, Cfg.velDigits),
		state.Value,
		floor.Value,
	}
end

function Wire.unpackSample(payload: any): (ClientPacket?, string?)
	if typeof(payload) ~= "table" then
		return nil, "payload not a table"
	end

	local seq = payload[1]
	local t = payload[2]
	local pos = payload[3]
	local vel = payload[4]
	local state = payload[5]
	local floor = payload[6]

	if typeof(seq) ~= "number" or seq < 0 then
		return nil, "bad seq"
	end
	if typeof(t) ~= "number" then
		return nil, "bad time"
	end
	if typeof(pos) ~= "Vector3" or typeof(vel) ~= "Vector3" then
		return nil, "bad vectors"
	end
	if typeof(state) ~= "number" or typeof(floor) ~= "number" then
		return nil, "bad enums"
	end

	return {
		seq = math.floor(seq),
		clientTime = t,
		pos = pos,
		vel = vel,
		state = math.floor(state),
		floor = math.floor(floor),
	}, nil
end

function Wire.packFix(snap: FixSnap): { any }
	return {
		snap.seq,
		snapNum(snap.t, 1000),
		snapVec(snap.pos, Cfg.posDigits),
		snapVec(snap.vel, Cfg.velDigits),
		snap.reason,
		snap.sev,
	}
end

function Wire.unpackFix(payload: any): FixSnap?
	if typeof(payload) ~= "table" then return nil end
	if typeof(payload[3]) ~= "Vector3" or typeof(payload[4]) ~= "Vector3" then
		return nil
	end
	return {
		seq = tonumber(payload[1]) or 0,
		t = tonumber(payload[2]) or 0,
		pos = payload[3],
		vel = payload[4],
		reason = tonumber(payload[5]) or 0,
		sev = tonumber(payload[6]) or 0,
	}
end

return table.freeze(Wire)
