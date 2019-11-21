local constants = require("constants")
local registry = require("registry")
local blockHash = require("systems.blockHash")
local bhEncodeForBump = blockHash.encodeForBump
local bhEncodeForTerrainString = blockHash.encodeForTerrainString
local bw, bh, bd = constants.blockWidth, constants.blockHeight, constants.blockDepth
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth

local smoothRandom, chaoticRandom, updateString
local generateTree

local function terrainHeight(blockX, blockZ)
	 return bh * (10+8*smoothRandom(--[[seed, but => 2 args turns love.math.noise perlin, do not want]] blockX/16, blockZ/16) + 4*smoothRandom(--[[seed,]] blockX/8, blockZ/8))
end

local tmpTerrainTable, tmpMetadataTable = {}, {}
local function generate(cx, cy, cz, chunkId, bumpWorld, seed)
	local ox, oy, oz = cw * cx, ch * cy, cd * cz
	
	for x = 0, cw - 1 do
		for z = 0, cd - 1 do
			local blockX = bw * (ox + x)
			local blockZ = bd * (oz + z)
			local terrainHeight = terrainHeight(blockX, blockZ)
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
					bumpWorld:add(hash, blockX, blockY, blockZ, bw, bh, bd)
				else
					tmpTerrainTable[hash] = string.char(0) -- air
				end
				tmpMetadataTable[hash] = string.char(0)
			end
		end
	end
	
	if cx % 3 == 1 and cz % 3 == 1 then -- arbitrary tree-generating pattern
		generateTree(tmpTerrainTable, tmpMetadataTable, ox, oy, oz, cw / 2, cd / 2, chunkId, bumpWorld)
	end
	 
	return table.concat(tmpTerrainTable), table.concat(tmpMetadataTable)
end

function updateString(self)
	self.columnString = table.concat(self.columnTable)
end

function generateTree(terrainTable, metadataTable, ox, oy, oz, trunkX, trunkZ, chunkId, bumpWorld)
	-- TODO
	local treeDiameter = 1
	local treeHeight = 4

	local blockX = bw * (ox + trunkX)
	local blockZ = bd * (oz + trunkZ)
	local terrainHeightInMetresAtTrunk = terrainHeight(blockX, blockZ)

	-- TODO: abort if obstructed (requires not to write to table unless sure not gonna abort, also other chunks need to be generated? can that chain? how does minecraft do it?)
	for x = math.max(trunkX, 0), math.min(trunkX + treeDiameter, cw) - 1 do
		for z = math.max(trunkZ, 0), math.min(trunkZ + treeDiameter, cd) - 1 do
			for y = 0, ch - 1 do
				local blockYInMetres = bh * (oy + y)
				if blockYInMetres >= terrainHeightInMetresAtTrunk and blockYInMetres - terrainHeightInMetresAtTrunk <= treeHeight then
					local stringHash = bhEncodeForTerrainString(x, y, z)
					if tmpTerrainTable[stringHash] == string.char(0) then -- air
						tmpTerrainTable[stringHash] = string.char(registry.terrainByName.mushroomCap.index)
						local bumpHash = bhEncodeForBump(x, y, z, chunkId)
						bumpWorld:add(bumpHash, math.floor(blockX / bh) * bh, blockYInMetres, math.floor(blockZ / bd) * bd, bw, bh, bd)
						metadataTable[stringHash] = string.char((2^constants.sideBits.py + 2^constants.sideBits.ny)*4)
					end
				end
			end
		end
	end
end

function smoothRandom(chaotic, ...)
	-- TODO
	return love.math.noise(chaotic, ...)
end

-- it's *all* chaos here, but the world's seed will usually be put in to completely change what the other values do
function chaoticRandom(...)
	-- TODO
	return love.math.random()
end

return generate
