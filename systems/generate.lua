local constants = require("constants")
local registry = require("registry")
local blockHash = require("systems.blockHash")
local bhEncodeForBump = blockHash.encodeForBump
local bhEncodeForTerrainString = blockHash.encodeForTerrainString
local bw, bh, bd = constants.blockWidth, constants.blockHeight, constants.blockDepth
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth

local chaoticRandom, updateString

local function terrainHeight(world, blockX, blockZ)
	 return 8+2*world.simplexer:noise2D(blockX/7, blockZ/8)
end

local tmpTerrainTable, tmpMetadataTable = {}, {}
local function generate(cx, cy, cz, chunkId, world)
	local ox, oy, oz = cw * cx, ch * cy, cd * cz
	
	for x = 0, cw - 1 do
		local blockX = bw * (ox + x)
		for z = 0, cd - 1 do
			local blockZ = bd * (oz + z)
			local terrainHeight = terrainHeight(world, blockX, blockZ)
			for y = 0, ch - 1 do
				local hash = bhEncodeForTerrainString(x, y, z)
				local blockY = bh * (oy + y)
				if blockY <= terrainHeight then
					local block
					if blockY + bh > terrainHeight then
						block = registry.terrainByName.grass
					elseif blockY > terrainHeight - constants.dirtLayerHeight then
						block = registry.terrainByName.soil
					else
						block = registry.terrainByName.stone
					end
					tmpTerrainTable[hash] = string.char(block.index)
					
					local hash = bhEncodeForBump(x, y, z, chunkId)
					world.bumpWorld:add(hash, blockX, blockY, blockZ, bw, bh, bd)
				else
					tmpTerrainTable[hash] = string.char(0) -- air
				end
				tmpMetadataTable[hash] = string.char(0)
			end
		end
	end
	
	return table.concat(tmpTerrainTable), table.concat(tmpMetadataTable)
end

function updateString(self)
	self.columnString = table.concat(self.columnTable)
end

-- it's *all* chaos here, but the world's seed will usually be put in to completely change what the other values do
function chaoticRandom(...)
	-- TODO
	return love.math.random()
end

return generate
