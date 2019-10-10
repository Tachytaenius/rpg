local detmath = require("lib.detmath")

local modifyChunk = {}

local function tilesOnlyFilter(item)
	return not item.isEntity
end

function modifyChunk.interactBlocks(entity, will, world)
	if not will then return end
	if will.destroy then
		-- TODO: Iteration order mustn't matter-- ie only destroy a block after all potential hits are done. (NOTE: Achievable by passing out a table of blocks that got destroyed etc. Just cba atm. I will, though.)
		local x, y, z, w, h, d = world.bumpWorld:getCube(entity)
		local cx, cy, cz = x + w / 2, y + entity.eyeHeight, z + d / 2
		local dx, dy, dz =
			entity.abilities.reach * detmath.cos(entity.theta - detmath.tau / 4) * detmath.cos(entity.phi),
			-entity.abilities.reach * detmath.sin(entity.phi),
			entity.abilities.reach * detmath.sin(entity.theta - detmath.tau / 4) * detmath.cos(entity.phi)
		local tiles, len = world.bumpWorld:querySegment(cx, cy, cz, cx + dx, cy + dy, cz + dz, tilesOnlyFilter)
		
		if len > 0 then
			 -- TODO why the what the what who why what how ugh? remake the hacky and disgusting chunk format
			local chunk = world.chunks[tiles[1].cx][tiles[1].cy][tiles[1].cz]
			local column = chunk.terrain[tiles[1].x][tiles[1].z]
			column.columnTable[tiles[1].y + 1] = string.char(0) -- air
			world.bumpWorld:remove(column.boxes[tiles[1].y])
			column:updateString()
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
