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

local function updateNeighbours(chunk, chunkUpdates)
	if chunk.pxNeighbour then chunkUpdates[chunk.pxNeighbour] = chunkUpdates[chunk.pxNeighbour] or chunk.pxNeighbour.terrain end
	if chunk.nxNeighbour then chunkUpdates[chunk.nxNeighbour] = chunkUpdates[chunk.nxNeighbour] or chunk.nxNeighbour.terrain end
	if chunk.pyNeighbour then chunkUpdates[chunk.pyNeighbour] = chunkUpdates[chunk.pyNeighbour] or chunk.pyNeighbour.terrain end
	if chunk.nyNeighbour then chunkUpdates[chunk.nyNeighbour] = chunkUpdates[chunk.nyNeighbour] or chunk.nyNeighbour.terrain end
	if chunk.pzNeighbour then chunkUpdates[chunk.pzNeighbour] = chunkUpdates[chunk.pzNeighbour] or chunk.pzNeighbour.terrain end
	if chunk.nzNeighbour then chunkUpdates[chunk.nzNeighbour] = chunkUpdates[chunk.nzNeighbour] or chunk.nzNeighbour.terrain end
end

function modifyChunk.interactBlocks(entity, will, world, chunkUpdates)
	if not will then return end
	if will.destroy then
		local tiles, len = world.bumpWorld:querySegment(getRayParameters(entity, will, world))
		if len > 0 then
			local hash = tiles[1] -- Ie tiles is a sequence of hashes of tiles and, uh, yeah. We're breaking the first one.
			local x, y, z, chunkId = bhDecode(hash)
			local chunk = world.chunksById[chunkId]
			local index = bhEncodeForTerrainString(x, y, z)
			chunkUpdates[chunk] = replaceChar(chunkUpdates[chunk] or chunk.terrain, index, string.char(0))
			world.bumpWorld:remove(hash)
			updateNeighbours(chunk, chunkUpdates)
		end
	end
end

return modifyChunk
