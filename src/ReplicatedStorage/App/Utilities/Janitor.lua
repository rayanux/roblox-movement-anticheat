--!strict
--!optimize 2

local Janitor = {}
Janitor.__index = Janitor

export type Janitor = typeof(setmetatable({} :: {
	_links: { RBXScriptConnection },
}, Janitor))

function Janitor.new(): Janitor
	return setmetatable({ _links = table.create(8) }, Janitor) :: Janitor
end

function Janitor.hook(self: Janitor, link: RBXScriptConnection): RBXScriptConnection
	local links = self._links
	links[#links + 1] = link
	return link
end

function Janitor.clear(self: Janitor)
	local links = self._links
	for i = #links, 1, -1 do
		local link = links[i]
		if link.Connected then
			link:Disconnect()
		end
		links[i] = nil
	end
end

return Janitor
