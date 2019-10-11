local detmath = require("lib.detmath")
local blockHash = require("systems.blockHash")
local bhDecode = blockHash.decode
local bhEncodeForTerrainString = blockHash.encodeForTerrainString

local modifyChunk = {}

local function tilesOnlyFilter(item)
	return type(item) == "number"
end

local replaceChar
do
	local tbl, concat, sub = {}, table.concat, string.sub
	function replaceChar(str, index, chr)
		tbl[1], tbl[2], tbl[3] = sub(str, 1, index - 1), chr, sub(str, index + 1)
		return concat(tbl)
	end
end

function modifyChunk.interactBlocks(entity, will, world)
	if not will then return end
	if will.destroy then
		-- TODO: Iteration order mustn't matter-- ie only destroy a block after all potential hits are done. (NOTE: Achievable by passing out a table of blocks that got destroyed etc. Just cba atm. I will, though. In doing this I can also optimise some of the changes and remeshings.)
		local x, y, z, w, h, d = world.bumpWorld:getCube(entity)
		local cx, cy, cz = x + w / 2, y + entity.eyeHeight, z + d / 2
		local dx, dy, dz =
			entity.abilities.reach * detmath.cos(entity.theta - detmath.tau / 4) * detmath.cos(entity.phi),
			-entity.abilities.reach * detmath.sin(entity.phi),
			entity.abilities.reach * detmath.sin(entity.theta - detmath.tau / 4) * detmath.cos(entity.phi)
		local tiles, len = world.bumpWorld:querySegment(cx, cy, cz, cx + dx, cy + dy, cz + dz, tilesOnlyFilter)
		
		if len > 0 then
			local hash = tiles[1] -- Ie tiles is a sequence of hashes of tiles and, uh, yeah. We're breaking the first one.
			local x, y, z, chunkId = bhDecode(hash)
			local chunk = world.chunksById[chunkId]
			local index = bhEncodeForTerrainString(x, y, z)
			chunk.terrain = replaceChar(chunk.terrain, index, string.char(0)) -- air
			world.bumpWorld:remove(hash)
			chunk:updateMesh()
			
			if chunk.pxNeighbour then chunk.pxNeighbour:updateMesh() end
			if chunk.nxNeighbour then chunk.nxNeighbour:updateMesh() end
			if chunk.pyNeighbour then chunk.pyNeighbour:updateMesh() end
			if chunk.nyNeighbour then chunk.nyNeighbour:updateMesh() end
			if chunk.pzNeighbour then chunk.pzNeighbour:updateMesh() end
			if chunk.nzNeighbour then chunk.nzNeighbour:updateMesh() end
		end
	end
end

return modifyChunk
