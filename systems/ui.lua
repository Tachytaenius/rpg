local suit = require("lib.suit")
local input = require("systems.input")
local constants, settings, assets =
	require("constants"),
	require("settings"),
	require("assets")

local ui = {}

function ui.construct(type)
	suit.enterFrame()
	
	ui.current = {
		type = type,
		mouseX = constants.width / 2,
		mouseY = constants.height / 2
	}
	
	if type == "plainPause" then
		ui.current.causesPause = true
	end
end

function ui.destroy()
	ui.current = nil
	suit.updateMouse(nil, nil, false)
	suit.exitFrame()
end

function ui.update()
	assert(ui.current, "Can't update UI without a UI")
	
	suit.updateMouse(ui.current.mouseX, ui.current.mouseY, input.didCommand("uiPrimary"))
	
	if ui.current.type == "plainPause" then
		suit.layout:reset(constants.width / 3, constants.height / 3, 4)
		if suit.Button("Resume", suit.layout:row(constants.width / 3, assets.ui.font.value:getHeight() + 3)).hit then
			ui.destroy()
		end
		if suit.Button("Quit", suit.layout:row()).hit then
			love.event.quit()
		end
	end
end

function ui.mouse(dx, dy)
	local div = settings.mouse.divideByScale and settings.graphics.scale or 1
	ui.current.mouseX = math.min(math.max(0, ui.current.mouseX + (dx * settings.mouse.xSensitivity) / div), constants.width)
	ui.current.mouseY = math.min(math.max(0, ui.current.mouseY + (dy * settings.mouse.ySensitivity) / div), constants.height)
end

return ui
