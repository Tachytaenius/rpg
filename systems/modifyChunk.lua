local constants = require("constants")
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth
local detmath = require("lib.detmath")
local blockHash = require("systems.blockHash")
local bhDecode = blockHash.decode
local bhEncodeForTerrainString = blockHash.encodeForTerrainString
local segmentCast = require("systems.segmentCast")

local modifyChunk = {}

local function get(t, k)
	if t then
		return t[k]
	end
end

-- local function replaceChar(s, i, chr)
-- 	return string.format("%s%s%s", s:sub(1, i - 1), chr, s:sub(i + 1))
-- end
-- %s cuts out all embedded zeros, so air is destroyed! %q doesn't, but it *totally* screws up everything else. Including how they are used, and cleaning that up would be even less efficient than what is in use, so... meh. it's not like it's called every frame, anyway
local replaceChar
do
	local tbl, concat, sub = {}, table.concat, string.sub
	function replaceChar(str, index, chr)
		tbl[1], tbl[2], tbl[3] = sub(str, 1, index - 1), chr, sub(str, index + 1)
		return concat(tbl)
	end
end

local chunksToUpdate, lenChunksToUpdate = {}, 0
function modifyChunk.updateChunkMeshes(chunks)
	for i = 1, lenChunksToUpdate do
		chunksToUpdate[i]:updateMesh(chunks)
	end
	chunksToUpdate, lenChunksToUpdate = {}, 0
end

local function blocksOnlyFilter(item)
	return type(item) == "number"
end

function modifyChunk.damageBlocks(entity, will, world, blockDamages)
	if will and will.destroy then
		segmentCast(entity, world.bumpWorld,
			function(hash)
				if blockDamages[hash] then
					blockDamages[hash] = blockDamages[hash] + 1
				else
					blockDamages[hash] = 1 -- damage _being dealt_
				end
			end,
			blocksOnlyFilter
		)
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
		
		local chunks = world.chunks
		local cx, cy, cz = chunk.x, chunk.y, chunk.z
		
		local xn, xp, yn, yp, zn, zp =
			x == 0, x == cw - 1,
			y == 0, y == ch - 1,
			z == 0, z == cd - 1
		
		if xn then local chunkToAdd = get(get(get(chunks, cx-1), cy), cz) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if xn and yn then local chunkToAdd = get(get(get(chunks, cx-1), cy-1), cz) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if xn and yp then local chunkToAdd = get(get(get(chunks, cx-1), cy+1), cz) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if xn and zn then local chunkToAdd = get(get(get(chunks, cx-1), cy), cz-1) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if xn and zp then local chunkToAdd = get(get(get(chunks, cx-1), cy), cz+1) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if yn and zn then local chunkToAdd = get(get(get(chunks, cx), cy-1), cz-1) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if yn then local chunkToAdd = get(get(get(chunks, cx), cy-1), cz) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if yn and zp then local chunkToAdd = get(get(get(chunks, cx), cy-1), cz+1) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if zn then local chunkToAdd = get(get(get(chunks, cx), cy), cz-1) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if zp then local chunkToAdd = get(get(get(chunks, cx), cy), cz+1) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if yp and zn then local chunkToAdd = get(get(get(chunks, cx), cy+1), cz-1) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if yp then local chunkToAdd = get(get(get(chunks, cx), cy+1), cz) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if yp and zp then local chunkToAdd = get(get(get(chunks, cx), cy+1), cz+1) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if xp then local chunkToAdd = get(get(get(chunks, cx+1), cy), cz) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if xp and yn then local chunkToAdd = get(get(get(chunks, cx+1), cy-1), cz) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if xp and yp then local chunkToAdd = get(get(get(chunks, cx+1), cy+1), cz) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if xp and zn then local chunkToAdd = get(get(get(chunks, cx+1), cy), cz-1) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
		if xp and zp then local chunkToAdd = get(get(get(chunks, cx+1), cy), cz+1) if chunkToAdd then lenChunksToUpdate = lenChunksToUpdate + 1 chunksToUpdate[lenChunksToUpdate] = chunkToAdd end end
	end
end

function modifyChunk.buildBlocks()
	
end

function modifyChunk.doBuildings()
	
end

return modifyChunk
