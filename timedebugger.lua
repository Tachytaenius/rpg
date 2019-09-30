-- Used for debugging only

local getTime, insert, remove = love.timer.getTime, table.insert, table.remove
local timerStackValues, timerStackNames = {}, {}
local nil_ = {}
function s(name)
	name = name or nil_
	insert(timerStackValues, getTime())
	insert(timerStackNames, name)
end
function e(name)
	name = name or nil_
	local stackName = remove(nameFromStack)
	assert(name == stackName, name .. " ~= " .. nameFromStack)
	print(name .. ": " .. getTime() - remove(timerStackValues))
end
