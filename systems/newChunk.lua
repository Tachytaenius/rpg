local assets = require("assets")
local constants = require("constants")

local bw, bh, bd = constants.blockWidth, constants.blockHeight, constants.blockDepth
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth

local generate = require("systems.generate")
local chunkManager = require("systems.chunkManager")

local emptyBlocks = string.char(0):rep(cw*ch*cd)
return function(x, y, z, world, notEmpty)
	local ret = {x = x, y = y, z = z}
	
	chunkManager.add(world, ret)
	
	if notEmpty then
		ret.terrain, ret.metadata = generate(x, y, z, ret.id, world.bumpWorld, world.seed)
	else
		ret.terrain, ret.metadata = emptyBlocks, emptyBlocks
	end
	
	return ret
end
