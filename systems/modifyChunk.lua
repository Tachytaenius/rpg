local constants = require("constants")
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth
local bw, bh, bd = constants.blockWidth, constants.blockHeight, constants.blockDepth
local detmath = require("lib.detmath")
local blockHash = require("systems.blockHash")
local bhDecode = blockHash.decode
local bhEncodeForTerrainString = blockHash.encodeForTerrainString
local bhEncodeForBump = blockHash.encodeForBump
local segmentCast = require("systems.segmentCast")
local blockTypes = require("registry").terrainByIndex
local chunkManager = require("systems.chunkManager")
local newChunk = require("systems.newChunk")

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

function modifyChunk.doDamages(world, blockDamages, chunksToUpdate)
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
		
		chunksToUpdate[chunk] = true
		
		local chunks = world.chunks
		local cx, cy, cz = chunk.x, chunk.y, chunk.z
		
		local xn, xp, yn, yp, zn, zp =
			x == 0, x == cw - 1,
			y == 0, y == ch - 1,
			z == 0, z == cd - 1
		
		if xn then        local chunkToAdd = get(get(get(chunks, cx-1), cy),   cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if xn and yn then local chunkToAdd = get(get(get(chunks, cx-1), cy-1), cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if xn and yp then local chunkToAdd = get(get(get(chunks, cx-1), cy+1), cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if xn and zn then local chunkToAdd = get(get(get(chunks, cx-1), cy),   cz-1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if xn and zp then local chunkToAdd = get(get(get(chunks, cx-1), cy),   cz+1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if yn and zn then local chunkToAdd = get(get(get(chunks, cx),   cy-1), cz-1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if yn then        local chunkToAdd = get(get(get(chunks, cx),   cy-1), cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if yn and zp then local chunkToAdd = get(get(get(chunks, cx),   cy-1), cz+1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if zn then        local chunkToAdd = get(get(get(chunks, cx),   cy),   cz-1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if zp then        local chunkToAdd = get(get(get(chunks, cx),   cy),   cz+1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if yp and zn then local chunkToAdd = get(get(get(chunks, cx),   cy+1), cz-1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if yp then        local chunkToAdd = get(get(get(chunks, cx),   cy+1), cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if yp and zp then local chunkToAdd = get(get(get(chunks, cx),   cy+1), cz+1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if xp then        local chunkToAdd = get(get(get(chunks, cx+1), cy),   cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if xp and yn then local chunkToAdd = get(get(get(chunks, cx+1), cy-1), cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if xp and yp then local chunkToAdd = get(get(get(chunks, cx+1), cy+1), cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if xp and zn then local chunkToAdd = get(get(get(chunks, cx+1), cy),   cz-1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		if xp and zp then local chunkToAdd = get(get(get(chunks, cx+1), cy),   cz+1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
	end
end

local floor = math.floor
function modifyChunk.buildBlocks(entity, will, world, blockBuildings, blockMetadataBuildings)
	if will and will.build then
		segmentCast(entity, world.bumpWorld,
			function(hashOfBlockBuildingOn, info)
				local x, y, z, chunkId = bhDecode(hashOfBlockBuildingOn)
				x, y, z =
					x + info.normalX,
					y + info.normalY,
					z + info.normalZ
				local dx, dy, dz =
					x == -1 and -1 or x == cw and 1 or 0,
					y == -1 and -1 or y == ch and 1 or 0,
					z == -1 and -1 or z == cd and 1 or 0
				x, y, z =
					x % cw,
					y % ch,
					z % cd
				local chunk = world.chunksById[chunkId]
				-- If chunk is different, account for it ("x, y, and z refer to the location of the chunk in there")
				if dx + dy + dz ~= 0 then -- only one can be non-zero
					local x, y, z = chunk.x, chunk.y, chunk.z
					chunk = get(get(get(world.chunks, x + dx), y + dy), z + dz) or newChunk(x+dx, y+dy, z+dz, world)
					-- TEMP
					require("systems.scene").chunksToDraw:add(chunk)
					chunkManager.add(world, chunk)
					chunkId = chunk.id
				end
				
				local localHashOfBlockToBuildInto = bhEncodeForTerrainString(x, y, z)
				
				-- local blockType = blockTypes[string.byte(string.sub(chunk.terrain, localHashOfBlockToBuildInto, localHashOfBlockToBuildInto))]
				-- if not blockType.replaceable then
				if string.sub(chunk.terrain, localHashOfBlockToBuildInto, localHashOfBlockToBuildInto) ~= string.char(0) then
					return
				end
				
				local hashOfBlockToBuildInto = bhEncodeForBump(x, y, z, chunkId)
				if blockBuildings[hashOfBlockToBuildInto] then
					blockBuildings[hashOfBlockToBuildInto] = "conflict"
				else
					blockBuildings[hashOfBlockToBuildInto] = --entity.blockToBuild.id
					1
					blockMetadataBuildings[hashOfBlockToBuildInto] = entity.metadataOfBlockToBuild or 0
				end
			end,
			blocksOnlyFilter
		)
	end
end

function modifyChunk.doBuildings(world, blockBuildings, blockMetadataBuildings, chunksToUpdate)
	for hash, block in pairs(blockBuildings) do
		if block ~= "conflict" then
			local x, y, z, chunkId = bhDecode(hash)
			local chunk = world.chunksById[chunkId]
			local localHash = bhEncodeForTerrainString(x, y, z)
			
			chunk.terrain = replaceChar(chunk.terrain, localHash, string.char(block))
			chunk.metadata = replaceChar(chunk.metadata, localHash, string.char(blockMetadataBuildings[hash]))
			local cx, cy, cz = chunk.x, chunk.y, chunk.z
			world.bumpWorld:add(hash,
				(x + cx * cw) * bw,
				(y + cy * ch) * bh,
				(z + cz * cd) * bd,
				bw, bh, bd
			)
			
			chunksToUpdate[chunk] = true
			local chunks = world.chunks
			local xn, xp, yn, yp, zn, zp =
				x == 0, x == cw - 1,
				y == 0, y == ch - 1,
				z == 0, z == cd - 1
			
				if xn then        local chunkToAdd = get(get(get(chunks, cx-1), cy),   cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if xn and yn then local chunkToAdd = get(get(get(chunks, cx-1), cy-1), cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if xn and yp then local chunkToAdd = get(get(get(chunks, cx-1), cy+1), cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if xn and zn then local chunkToAdd = get(get(get(chunks, cx-1), cy),   cz-1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if xn and zp then local chunkToAdd = get(get(get(chunks, cx-1), cy),   cz+1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if yn and zn then local chunkToAdd = get(get(get(chunks, cx),   cy-1), cz-1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if yn then        local chunkToAdd = get(get(get(chunks, cx),   cy-1), cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if yn and zp then local chunkToAdd = get(get(get(chunks, cx),   cy-1), cz+1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if zn then        local chunkToAdd = get(get(get(chunks, cx),   cy),   cz-1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if zp then        local chunkToAdd = get(get(get(chunks, cx),   cy),   cz+1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if yp and zn then local chunkToAdd = get(get(get(chunks, cx),   cy+1), cz-1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if yp then        local chunkToAdd = get(get(get(chunks, cx),   cy+1), cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if yp and zp then local chunkToAdd = get(get(get(chunks, cx),   cy+1), cz+1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if xp then        local chunkToAdd = get(get(get(chunks, cx+1), cy),   cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if xp and yn then local chunkToAdd = get(get(get(chunks, cx+1), cy-1), cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if xp and yp then local chunkToAdd = get(get(get(chunks, cx+1), cy+1), cz)   if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if xp and zn then local chunkToAdd = get(get(get(chunks, cx+1), cy),   cz-1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
				if xp and zp then local chunkToAdd = get(get(get(chunks, cx+1), cy),   cz+1) if chunkToAdd then chunksToUpdate[chunkToAdd] = true end end
		end
	end
end

return modifyChunk
