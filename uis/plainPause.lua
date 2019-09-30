local suit = require("lib.suit")
local constants = require("constants")
local assets = require("assets")

local plainPause = {}

function plainPause.construct(state)
	state.causesPause = true
end

function plainPause.update(state)
	suit.layout:reset(constants.width / 3, constants.height / 3, 4)
	if suit.Button("Resume", suit.layout:row(constants.width / 3, assets.ui.font.value:getHeight() + 3)).hit then
		return true -- Destroy UI
	end
	if suit.Button("Quit", suit.layout:row()).hit then
		love.event.quit()
	end
end

return plainPause
