local suit = require("lib.suit")
local input = require("systems.input")
local constants, settings, assets =
	require("constants"),
	require("systems.settings"),
	require("assets")
local uis = require("fornamein")("uis.", "plainPause")

local ui = {}

function ui.construct(type)
	suit.enterFrame()
	
	ui.current = {
		type = type,
		mouseX = constants.width / 2,
		mouseY = constants.height / 2
	}
	
	uis[type].construct(ui.current)
end

function ui.destroy()
	ui.current = nil
	suit.updateMouse(nil, nil, false)
	suit.exitFrame()
end

function ui.update()
	assert(ui.current, "Can't update UI without a UI")
	
	suit.updateMouse(ui.current.mouseX, ui.current.mouseY, input.didCommand("uiPrimary"))
	
	local destroy = uis[ui.current.type].update(ui.current)
	if destroy then ui.destroy() end
end

function ui.mouse(dx, dy)
	local div = settings.mouse.divideByScale and settings.graphics.scale or 1
	ui.current.mouseX = math.min(math.max(0, ui.current.mouseX + (dx * settings.mouse.xSensitivity) / div), constants.width)
	ui.current.mouseY = math.min(math.max(0, ui.current.mouseY + (dy * settings.mouse.ySensitivity) / div), constants.height)
end

return ui
