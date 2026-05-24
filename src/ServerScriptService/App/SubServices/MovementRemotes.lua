--!strict
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedApp = ReplicatedStorage:WaitForChild("App")
local Names = require(SharedApp.Networking.MovementRemotes)

export type Endpoints = {
	sample: RemoteEvent,
	fix: RemoteEvent,
}

local Endpoints = {}

local function pickFolder(parent: Instance, name: string): Folder
	local got = parent:FindFirstChild(name)
	if got and got:IsA("Folder") then
		return got
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function pickRemote(parent: Instance, name: string): RemoteEvent
	local got = parent:FindFirstChild(name)
	if got and got:IsA("RemoteEvent") then
		return got
	end
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = parent
	return r
end

function Endpoints.build(): Endpoints
	local remotes = pickFolder(SharedApp, "Remotes")
	local box = pickFolder(remotes, Names.folder)
	return {
		sample = pickRemote(box, Names.sample),
		fix = pickRemote(box, Names.correction),
	}
end

return table.freeze(Endpoints)
