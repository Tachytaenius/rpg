local constants = require("constants")

function love.conf(t)
	t.identity = constants.identity
	t.version = constants.loveVersion
	t.accelorometerjoystick = false
	t.appendidentity = true
	
	t.window.title = constants.title
	-- TODO: Icon
	
	t.window.width = constants.width
	t.window.height = constants.height
end
