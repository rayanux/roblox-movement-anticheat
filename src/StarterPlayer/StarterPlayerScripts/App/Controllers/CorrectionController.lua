--!strict
--!optimize 2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SharedApp = ReplicatedStorage:WaitForChild("App")
local Config = require(SharedApp.Config.MovementConfig)
local Wire = require(SharedApp.Networking.MovementPackets)
local Names = require(SharedApp.Networking.MovementRemotes)
local Janitor = require(SharedApp.Utilities.Janitor)
local Geom = require(SharedApp.Utilities.MovementMath)
local Trail = require(SharedApp.Utilities.Trail)

local CorrectionController = {
	Name = "CorrectionController",
}

local bin = Janitor.new()
local fixLog = Trail.new(Config.fixBufSize)
local me = Players.LocalPlayer
local tweenInFlight: Tween? = nil
local char: Model? = nil
local root: BasePart? = nil
local humanoid: Humanoid? = nil

local function findFixRemote(): RemoteEvent
	local remotes = SharedApp:WaitForChild("Remotes")
	local box = remotes:WaitForChild(Names.folder)
	return box:WaitForChild(Names.correction) :: RemoteEvent
end

local function bindCharacter(newChar: Model?)
	char = newChar
	root, humanoid = Geom.rigOf(char)
	if tweenInFlight ~= nil then
		tweenInFlight:Cancel()
		tweenInFlight = nil
	end
	if humanoid ~= nil then
		humanoid.CameraOffset = Vector3.zero
	end
end

local function smooth(payload: any)
	local snap = Wire.unpackFix(payload)
	if snap == nil then return end

	fixLog:push(snap)
	if root == nil or humanoid == nil or not root:IsDescendantOf(workspace) then
		root, humanoid = Geom.rigOf(char)
	end
	if root == nil or humanoid == nil then return end

	local offset = root.Position - snap.pos
	if offset.Magnitude < Config.minVizOffset then return end

	if tweenInFlight ~= nil then
		tweenInFlight:Cancel()
	end
	humanoid.CameraOffset = root.CFrame:VectorToObjectSpace(offset)
	tweenInFlight = TweenService:Create(
		humanoid,
		TweenInfo.new(Config.fixSmooth, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CameraOffset = Vector3.zero }
	)
	local tw = tweenInFlight :: Tween
	tw:Play()
end

function CorrectionController:Start()
	if me == nil then return end
	local fixRemote = findFixRemote()
	bin:hook(fixRemote.OnClientEvent:Connect(smooth))
	bin:hook(me.CharacterAdded:Connect(bindCharacter))
	bin:hook(me.CharacterRemoving:Connect(function()
		bindCharacter(nil)
	end))
	bindCharacter(me.Character)
end

return CorrectionController
