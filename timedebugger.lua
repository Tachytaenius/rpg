-- Used for debugging only

local getTime, insert, remove = love.timer.getTime, table.insert, table.remove
local timerStackValues, timerStackNames = {}, {}

function s(name)
	insert(timerStackValues, getTime())
	insert(timerStackNames, name)
end
function e(name)
	local stackName = remove(nameFromStack)
	assert(name == stackName, name .. " ~= " .. nameFromStack)
	print(name .. ": " .. getTime() - remove(timerStackValues))
end
