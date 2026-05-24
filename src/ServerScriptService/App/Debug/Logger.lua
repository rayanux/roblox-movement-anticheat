--!strict

local TAG = "[anticheat]"

local Log = {}
local enabled = true

function Log.enable(state: boolean)
	enabled = state
end

function Log.isOn(): boolean
	return enabled
end

function Log.info(msg: string)
	if enabled then
		print(TAG, msg)
	end
end

function Log.warn(msg: string)
	warn(TAG, msg)
end

return table.freeze(Log)
