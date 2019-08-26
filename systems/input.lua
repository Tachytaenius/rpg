local constants, settings =
	require("constants"),
	require("systems.settings")

local input = {}

local previousFrameRawCommands, thisFrameRawCommands

-- This function does two things, unfortunately
-- It sets a command's raw usage and gets its actual "was it used" usage.
-- TODO: Be good about this function. Maybe call it checkCommand or useCommand or... idk
-- (Yeah, just split it into two things)
-- Also there's gonna be a total rewrite of the input system anyway so meh use it for now
function input.didCommand(name)
	assert(constants.commands[name], name .. " is not a valid command")
	
	local assignee = settings.commands[name]
	if (type(assignee) == "string" and (settings.useScancodes and love.keyboard.isScancodeDown or lov.keyboard.isDown)(assignee)) or (type(assignee) == "number" and love.mouse.isGrabbed() and love.mouse.isDown(assignee)) then
		thisFrameRawCommands[name] = true
	end
	
	local deltaPolicy = constants.commands[name]
	if deltaPolicy == "onPress" then
		return thisFrameRawCommands[name] and not previousFrameRawCommands[name]
	elseif deltaPolicy == "onRelease" then
		return not thisFrameRawCommands[name] and previousFrameRawCommands[name]
	elseif deltaPolicy == "whileDown" then
		return thisFrameRawCommands[name]
	else
		error(deltaPolicy .. " is not a valid delta policy")
	end
end

function input.stepRawCommands()
	previousFrameRawCommands, thisFrameRawCommands = thisFrameRawCommands, {}
end

function input.clearRawCommands()
	previousFrameRawCommands, thisFrameRawCommands = {}, {}
end

return input
