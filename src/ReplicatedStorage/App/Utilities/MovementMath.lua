--!strict

local Cfg = require(script.Parent.Parent.Config.MovementConfig)

local UP = Vector3.yAxis

local Geom = {}

function Geom.clampDt(dt: number): number
	return math.clamp(dt, Cfg.minDt, Cfg.maxDt)
end

function Geom.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Geom.flatMag(v: Vector3): number
	return math.sqrt(v.X * v.X + v.Z * v.Z)
end

function Geom.slopeDeg(n: Vector3): number
	if n.Magnitude < 1e-4 then return 0 end
	local d = math.clamp(n.Unit:Dot(UP), -1, 1)
	return math.deg(math.acos(d))
end

function Geom.onFloor(floor: Enum.Material, state: Enum.HumanoidStateType): boolean
	if floor == Enum.Material.Air then return false end
	return state ~= Enum.HumanoidStateType.Freefall
		and state ~= Enum.HumanoidStateType.Jumping
		and state ~= Enum.HumanoidStateType.Flying
		and state ~= Enum.HumanoidStateType.PlatformStanding
end

local LENIENT = {
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Dead] = true,
	[Enum.HumanoidStateType.GettingUp] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
}

function Geom.lenientState(s: Enum.HumanoidStateType): boolean
	return LENIENT[s] == true
end

function Geom.rigOf(char: Model?): (BasePart?, Humanoid?)
	if char == nil then return nil, nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hrp == nil or not hrp:IsA("BasePart") then
		return nil, hum
	end
	return hrp, hum
end

return table.freeze(Geom)
