local constants = require("constants")
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth
local detmath = require("lib.detmath")
local blockHash = require("systems.blockHash")
local bhDecode = blockHash.decode
local bhEncodeForTerrainString = blockHash.encodeForTerrainString

local modifyChunk = {}

-- %s cuts out all embedded zeros, so air is destroyed! %q doesn't, but it *totally* screws up everything else. Including how they are used, and cleaning that up would be even less efficient than what is in use, so... meh.
-- local function replaceChar(s, i, chr)
-- 	return string.format("%s%s%s", s:sub(1, i - 1), chr, s:sub(i + 1))
-- end

local replaceChar
do
	local tbl, concat, sub = {}, table.concat, string.sub
	function replaceChar(str, index, chr)
		tbl[1], tbl[2], tbl[3] = sub(str, 1, index - 1), chr, sub(str, index + 1)
		return concat(tbl)
	end
end

local function tilesOnlyFilter(item)
	return type(item) == "number"
end

local function getRayParameters(entity, will, world)
	local x, y, z, w, h, d = world.bumpWorld:getCube(entity)
	local cx, cy, cz = x + w / 2, y + entity.eyeHeight, z + d / 2
	local dx, dy, dz =
		entity.abilities.reach * detmath.cos(entity.theta - detmath.tau / 4) * detmath.cos(entity.phi),
		-entity.abilities.reach * detmath.sin(entity.phi),
		entity.abilities.reach * detmath.sin(entity.theta - detmath.tau / 4) * detmath.cos(entity.phi)
	return cx, cy, cz, cx + dx, cy + dy, cz + dz, tilesOnlyFilter
end

local chunksToUpdate, lenChunksToUpdate = {}, 0
function modifyChunk.updateChunkMeshes()
	for i = 1, lenChunksToUpdate do
		chunksToUpdate[i]:updateMesh()
	end
	chunksToUpdate, lenChunksToUpdate = {}, 0
end

function modifyChunk.damageBlocks(entity, will, world, blockDamages)
	if will and will.destroy then
		local blocks, len = world.bumpWorld:querySegment(getRayParameters(entity, will, world))
		if len > 0 then
			local hash = blocks[1] -- Ie blocks is a sequence of hashes of blocks and, uh, yeah. We're damaging the first one.
			
			if blockDamages[hash] then
				blockDamages[hash] = blockDamages[hash] + 1
			else
				-- local x, y, z, chunkId = bhDecode(hash)
				-- local chunk = world.chunksById[chunkId]
				-- local blockId, state, damage = chunk:getBlock(x, y, z)
				blockDamages[hash] = 1
			end
		end
	end
end


function modifyChunk.doDamages(world, blockDamages)
	for hash, damageDealt in pairs(blockDamages) do
		local x, y, z, chunkId = bhDecode(hash)
		local chunk = world.chunksById[chunkId]
		local index = bhEncodeForTerrainString(x, y, z)
		
		local currentMetadata = string.byte(string.sub(chunk.metadata, index, index))
		
		if currentMetadata % 4 + damageDealt >= 4 then
			chunk.metadata = replaceChar(chunk.metadata, index, string.char(0))
			chunk.terrain = replaceChar(chunk.terrain, index, string.char(0))
			world.bumpWorld:remove(hash)
		else
			chunk.metadata = replaceChar(chunk.metadata, index, string.char(currentMetadata + damageDealt))
		end
		
		lenChunksToUpdate = lenChunksToUpdate + 1
		chunksToUpdate[lenChunksToUpdate] = chunk
		
		if x == cw - 1 and chunk.pxNeighbour then
			lenChunksToUpdate = lenChunksToUpdate + 1
			chunksToUpdate[lenChunksToUpdate] = chunk.pxNeighbour
		elseif x == 0 and chunk.nxNeighbour then
			lenChunksToUpdate = lenChunksToUpdate + 1
			chunksToUpdate[lenChunksToUpdate] = chunk.pxNeighbour
		end
		if y == ch - 1 and chunk.pyNeighbour then
			lenChunksToUpdate = lenChunksToUpdate + 1
			chunksToUpdate[lenChunksToUpdate] = chunk.pyNeighbour
		elseif y == 0 and chunk.nyNeighbour then
			lenChunksToUpdate = lenChunksToUpdate + 1
			chunksToUpdate[lenChunksToUpdate] = chunk.nyNeighbour
		end
		if z == cd - 1 and chunk.pzNeighbour then
			lenChunksToUpdate = lenChunksToUpdate + 1
			chunksToUpdate[lenChunksToUpdate] = chunk.pzNeighbour
		elseif z == 0 and chunk.nzNeighbour then
			lenChunksToUpdate = lenChunksToUpdate + 1
			chunksToUpdate[lenChunksToUpdate] = chunk.nzNeighbour
		end
	end
end

function modifyChunk.buildBlocks()
	
end

function modifyChunk.doBuildings()
	
end

return modifyChunk
