-- Used for debugging only

local getTime, insert, remove = love.timer.getTime, table.insert, table.remove
local timerStack = {}
function s()
	insert(timerStack, getTime())
end
function e()
	print(getTime() - remove(timerStack))
end
