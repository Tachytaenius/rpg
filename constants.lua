local constants = {}

constants.width = 480
constants.height = 270

constants.title = "Ruh Puh Guh"
constants.identity = "rpg"
constants.loveVersion = "11.2"
constants.tickWorth = 1 / 24 -- seconds

constants.fontString = " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.!?$,#@~:;-{}&()<>'%/*0123456789"
constants.fontSpecials = {
	{from = "?!", to = "$"}, -- interrobang
	{from = "$,", to = "~"}, -- interrobang comma
	{from = "!,", to = "#"}, -- exclamation comma
	{from = "?,", to = "@"}, -- question comma
	-- {from = "\"[", to = "<"}, -- open quote
	-- {from = "\"]", to = ">"}, -- close quote
	{from = "--", to = "{"}, -- en dash
	{from = "---", to = "}"} -- em dash
}

constants.frameCommands = {
	pause = "onRelease",
	
	toggleMouseGrab = "onRelease",
	takeScreenshot = "onRelease",
	toggleInfo = "onRelease",
	previousDisplay = "onRelease",
	nextDisplay = "onRelease",
	scaleDown = "onRelease",
	scaleUp = "onRelease",
	toggleFullscreen = "onRelease",
	
	uiPrimary = "whileDown",
	uiSecondary = "whileDown",
	uiModifier = "whileDown"
}

constants.fixedCommands = {
	advance = "whileDown",
	strafeLeft = "whileDown",
	backpedal = "whileDown",
	strafeRight = "whileDown",
	jump = "whileDown",
	run = "whileDown",
	crouch = "whileDown",
	
	destroy = "onPress",
	build = "onPress"
}

for name in pairs(constants.frameCommands) do
	assert(not constants.fixedCommands[name], name .. " is a duplicate command name")
end
for name in pairs(constants.fixedCommands) do
	assert(not constants.frameCommands[name], name .. " is a duplicate command name")
end

constants.infoWidth = 200
constants.infoHeight = 100

constants.blockWidth = 0.5 -- metres
constants.blockHeight = 0.5
constants.blockDepth = 0.5

constants.chunkWidth = 16 -- blocks
constants.chunkHeight = 16
constants.chunkDepth = 16

constants.velocitySnap = 0.001
constants.bumpCellSize = 4 -- metres

constants.minShadowBias = 0.005
constants.maxShadowBias = 0.05
constants.lightNearPlane = 0.001
constants.shadowMapSize = 1024

constants.vertexFormat = {
	{"VertexPosition", "float", 3},
	{"VertexTexCoord", "float", 2},
	{"VertexNormal", "float", 3}
}

return constants
