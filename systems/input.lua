local constants, settings =
	require("constants"),
	require("systems.settings")

local input = {}

local previousFrameRawCommands, thisFrameRawCommands, fixedCommandsList

local function didCommandBase(name, constantsTable, settingsTable)
	assert(constantsTable[name], name .. " is not a valid command")
	
	local assignee = settingsTable[name]
	if (type(assignee) == "string" and (settings.useScancodes and love.keyboard.isScancodeDown or lov.keyboard.isDown)(assignee)) or (type(assignee) == "number" and love.mouse.isGrabbed() and love.mouse.isDown(assignee)) then
		thisFrameRawCommands[name] = true
	end
	
	local deltaPolicy = constantsTable[name]
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

function input.didFrameCommand(name)
	return didCommandBase(name, constants.frameCommands, settings.frameCommands)
end

function input.didFixedCommand(name)
	return fixedCommandsList[name]
end

function input.stepRawCommands(paused)
	if not paused then
		for name, deltaPolicy in pairs(constants.fixedCommands) do
			local didCommandThisFrame = didCommandBase(name, constants.fixedCommands, settings.fixedCommands)
			fixedCommandsList[name] = fixedCommandsList[name] or didCommandThisFrame
		end
	end
	
	previousFrameRawCommands, thisFrameRawCommands = thisFrameRawCommands, {}
end

function input.clearRawCommands()
	previousFrameRawCommands, thisFrameRawCommands = {}, {}
end

function input.clearFixedCommandsList()
	fixedCommandsList = {}
end

return input
