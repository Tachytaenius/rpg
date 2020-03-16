local constants = require("constants")
local bw, bh, bd = constants.blockWidth, constants.blockHeight, constants.blockDepth
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth
local list, bump =
	require("lib.list"),
	require("lib.bump-3dpd")
local scene, chunkManager, newChunk, newEntity =
	require("systems.scene"),
	require("systems.chunkManager"),
	require("systems.newChunk"),
	require("systems.newEntity")
local blockHash = require("systems.blockHash")
local bhEncodeForBump = blockHash.encodeForBump
local bhEncodeForTerrainString = blockHash.encodeForTerrainString
local terrainByIndex = require("registry").terrainByIndex

return function(path)
	local world = {
		bumpWorld = bump.newWorld(constants.bumpCellSize),
		entities = list.new(),
		chunks = {},
		chunksById = {},
		freeChunkIdsToUse = {len = 0},
		nextIdAfterChunkIdListEnd = 0, -- TODO: max chunk ID from cw, ch, cd and maximum integer
		lights = list.new():add({isDirectional = true, angle={0.4, 0.8, 0.6}, colour={1, 1, 1}, strength = 3}),
		gravityAmount = 9.8,
		gravityMaxFallSpeed = 50
	}
	local testmanPlayer = newEntity(world, "testman", 4, 9, 4, 1)
	scene.cameraEntity = testmanPlayer
	local data, message = love.filesystem.read("saves/" .. path .. "/chunks.bin")
	if not data then error(message) end
	local terrainSize = cw * ch * cd
	local lenChunk = 3 + terrainSize * 2
	local numChunks = #data / lenChunk
	assert(numChunks % 1 == 0)
	for i = 0, numChunks - 1 do
		local offset = i * lenChunk
		local x, y, z =
			string.byte(string.sub(data, offset + 1, offset + 1)),
			string.byte(string.sub(data, offset + 2, offset + 2)),
			string.byte(string.sub(data, offset + 3, offset + 3))
		local chunk = newChunk(x, y, z, world)
		chunk.terrain = string.sub(data, offset + 4, offset + 4 + terrainSize - 1)
		chunk.metadata = string.sub(data, offset + 4 + terrainSize, offset + 4 + terrainSize * 2 - 1)
		local chunkId, bumpWorld = chunk.id, world.bumpWorld
		local ox, oy, oz = cw * x, ch * y, cd * z
		
		for x = 0, cw - 1 do
			local blockX = bw * (ox + x)
			for z = 0, cd - 1 do
				local blockZ = bd * (oz + z)
				for y = 0, ch - 1 do
					local hash = bhEncodeForTerrainString(x, y, z)
					local blockY = bh * (oy + y)
					local block = terrainByIndex[string.byte(string.sub(chunk.terrain, hash, hash))]
					if not block.nonSolid then
						local hash = bhEncodeForBump(x, y, z, chunkId)
						-- bumpWorld:add(hash, blockX, blockY, blockZ, bw, bh, bd)
					end
				end
			end
		end
		assert(#chunk.terrain == terrainSize and #chunk.metadata == terrainSize)
	end
	
	-- There's no point iterating the coords way if you're not going to use them.
	for _, chunk in pairs(world.chunksById) do
		local removed = chunkManager.update(chunk, world)
		if not removed then
			scene.chunksToDraw:add(chunk)
		end
	end
	
	return world
end
