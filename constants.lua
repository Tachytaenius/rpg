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

constants.blockCursorPadding = 0.01 -- metres

constants.chunkWidth = 8 -- blocks
constants.chunkHeight = 8
constants.chunkDepth = 8

constants.velocitySnap = 0.001
constants.bumpCellSize = 4 -- metres

constants.minShadowBias = 0.005
constants.maxShadowBias = 0.05
constants.lightNearPlane = 0.001 -- metres
constants.shadowMapSize = 1024 -- pixels

constants.vertexFormat = {
	{"VertexPosition", "float", 3},
	{"VertexTexCoord", "float", 2},
	{"VertexNormal", "float", 3},
	{"vertexGroup", "float", 1}
}

-- TEMP location
constants.dirtLayerHeight = 2.5 -- metres

-- For things like mushroom cap flesh/skin
constants.sideBits = {
	px = 0,
	nx = 1,
	py = 2,
	ny = 3,
	pz = 4,
	nz = 5
}

-- In certain "camera conditions" block sides would show some pixels from their neighbouring textures in the terrain texture atlasses
-- Saves more memory than padding each texture in the the terrain texture atlasses, and is probably a lot faster than using min/max etc. for Texel's arguments...
constants.textureBleedMargin = 0.001

return constants
