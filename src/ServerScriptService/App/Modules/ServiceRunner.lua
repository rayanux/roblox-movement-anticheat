--!strict

local ServerTypes = require(script.Parent.Parent.Types.ServerTypes)

type Service = ServerTypes.Service

local Runner = {}

local function call(svc: Service, name: "Init" | "Start")
	local fn = svc[name]
	if fn == nil then return end
	local ok, err = pcall(fn, svc)
	if not ok then
		error(string.format("%s.%s failed: %s", svc.Name, name, tostring(err)), 2)
	end
end

function Runner.boot(services: { Service })
	for _, svc in ipairs(services) do
		call(svc, "Init")
	end
	for _, svc in ipairs(services) do
		call(svc, "Start")
	end
end

return table.freeze(Runner)
