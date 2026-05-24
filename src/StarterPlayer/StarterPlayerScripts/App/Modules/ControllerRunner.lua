--!strict

local ClientTypes = require(script.Parent.Parent.Types.ClientTypes)

type Controller = ClientTypes.Controller

local Runner = {}

local function call(c: Controller, name: "Init" | "Start")
	local fn = c[name]
	if fn == nil then return end
	local ok, err = pcall(fn, c)
	if not ok then
		error(string.format("%s.%s failed: %s", c.Name, name, tostring(err)), 2)
	end
end

function Runner.boot(controllers: { Controller })
	for _, c in ipairs(controllers) do
		call(c, "Init")
	end
	for _, c in ipairs(controllers) do
		call(c, "Start")
	end
end

return table.freeze(Runner)
