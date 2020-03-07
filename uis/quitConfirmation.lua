local suit = require("lib.suit")
local constants = require("constants")
local assets = require("assets")
local warn = require("systems.warn")

local quitConfirmation = {}

function quitConfirmation.construct(state)
	state.causesPause = true
end

function quitConfirmation.update(state)
	suit.layout:reset(constants.width / 3, constants.height / 3, 4)
	if suit.Button("Save and quit", suit.layout:row(constants.width / 3, assets.ui.font.value:getHeight() + 3)).hit then
		love.event.push("save")
		love.event.quit()
	end
	if suit.Button("Quit without saving", suit.layout:row()).hit then
		love.event.quit()
	end
	if suit.Button("Don't quit", suit.layout:row()).hit then
		return true
	end
end

return quitConfirmation
