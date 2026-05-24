--!strict
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedApp = ReplicatedStorage:WaitForChild("App")
local Cfg = require(SharedApp.Config.MovementConfig)
local Geom = require(SharedApp.Utilities.MovementMath)
local Types = require(SharedApp.Types.MovementTypes)
local Reason = require(SharedApp.Enums.Reason)

type Sample = Types.ServerSample
type Violation = Types.Violation

local Physics = {}

local function violation(kind: number, sev: number, msg: string, correct: boolean): Violation
	return { kind = kind, sev = sev, msg = msg, correct = correct }
end

-- Cast only through the actual movement delta. Padding this ray caused false
-- positives beside trusses and thin wall trim.
local function crossed(from: Vector3, d: Vector3, rp: RaycastParams?): boolean
	local hit = workspace:Raycast(from, d, rp)
	if hit == nil then return false end
	local inst = hit.Instance
	if inst.CanCollide == false then return false end
	if inst:IsA("TrussPart") then return false end
	if hit.Normal.Y > Cfg.wallNormalY then return false end
	return hit.Distance < d.Magnitude - 0.05
end

function Physics.ownership(plr: Player, hrp: BasePart?): Violation?
	if hrp == nil or not Cfg.checks.ownership then return nil end
	local ok, owner = pcall(function() return hrp:GetNetworkOwner() end)
	if not ok then return nil end
	if owner ~= nil and owner ~= plr then
		return violation(Reason.NetworkOwnership, 4, "owner mismatch", true)
	end
	return nil
end

function Physics.verticalVel(s: Sample): Violation?
	if not Cfg.checks.physics then return nil end
	local vy = s.vel.Y
	if vy > Cfg.maxVyUp then
		return violation(Reason.Physics, 4, "vy too high", true)
	end
	if vy < -Cfg.maxVyDown then
		return violation(Reason.Physics, 4, "falling too fast", true)
	end
	return nil
end

function Physics.noclip(prev: Sample?, cur: Sample, rp: RaycastParams?): Violation?
	if prev == nil or not Cfg.checks.noclip then return nil end
	-- Climbing can push the root through truss bars for a frame.
	if prev.state == Enum.HumanoidStateType.Climbing or cur.state == Enum.HumanoidStateType.Climbing then
		return nil
	end
	local d = cur.pos - prev.pos
	if d.Magnitude < Cfg.noclipMinCast then return nil end
	if not crossed(prev.pos, d, rp) then return nil end
	return violation(Reason.Noclip, 6, "noclip", true)
end

function Physics.slope(s: Sample, rp: RaycastParams?): Violation?
	if not s.onFloor then return nil end
	local hit = workspace:Raycast(s.pos, Vector3.new(0, -Cfg.groundRay, 0), rp)
	if hit == nil then
		return violation(Reason.BadGround, 2, "no floor under", false)
	end
	if hit.Distance > Cfg.maxGroundDist then
		return violation(Reason.BadGround, 3, "floating", false)
	end
	if Geom.slopeDeg(hit.Normal) > Cfg.maxSlope then
		return violation(Reason.BadGround, 3, "slope too steep", false)
	end
	return nil
end

return table.freeze(Physics)
