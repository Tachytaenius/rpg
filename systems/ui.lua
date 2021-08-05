local suit = require("lib.suit")
local input = require("systems.input")
local constants, settings, assets =
	require("constants"),
	require("systems.settings"),
	require("assets")

local uiNames = [[
	plainPause settings
	quitConfirmation
]]

local uis = require("fornamein")("uis.", uiNames)

local ui = {}

function ui.construct(type)
	suit.enterFrame()
	
	ui.current = {
		type = type,
		mouseX = ui.current and ui.current.mouseX or constants.width / 2,
		mouseY = ui.current and ui.current.mouseY or constants.height / 2
	}
	
	uis[type].construct(ui.current)
end

function ui.destroy()
	ui.current = nil
	suit.updateMouse(nil, nil, false)
	suit.exitFrame()
end

-- destroy followed by construct resets cursor position. This doesn't
function ui.replace(type)
	assert(ui.current, "Can't replace UI without a UI")
	local mx, my = ui.current.mouseX, ui.current.mouseY
	ui.construct(type)
	ui.current.mouseX, ui.current.mouseY = mx, my
	suit.exitFrame()
	suit.enterFrame()
end

function ui.update()
	assert(ui.current, "Can't update UI without a UI")
	if love.mouse.getRelativeMode() then
		suit.updateMouse(ui.current.mouseX, ui.current.mouseY, input.didFrameCommand("uiPrimary"))
	else
		suit.updateMouse(ui.current.mouseX, ui.current.mouseY, nil)
	end
	
	local destroy, typeToTransitionTo = uis[ui.current.type].update(ui.current)
	if destroy then
		if typeToTransitionTo then
			ui.replace(typeToTransitionTo)
		else
			ui.destroy()
		end
	end
end

function ui.mouse(dx, dy)
	local div = settings.mouse.divideByScale and settings.graphics.scale or 1
	ui.current.mouseX = math.min(math.max(0, ui.current.mouseX + (dx * settings.mouse.xSensitivity) / div), constants.width)
	ui.current.mouseY = math.min(math.max(0, ui.current.mouseY + (dy * settings.mouse.ySensitivity) / div), constants.height)
end

return ui
