local registry = require("registry")
local assets = require("assets")
local constants = require("constants")

local bw, bh, bd = constants.blockWidth, constants.blockHeight, constants.blockDepth
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth

local terrainByIndex = registry.terrainByIndex

local vertexFormat = {
	{"VertexPosition", "float", 3},
	{"VertexNormal", "float", 3},
	{"vertexTextureIndex", "float", 1}
}

local chunkManager = {}

function chunkManager.add(world, chunk)
	local xTable = world.chunks[chunk.x]
	if not xTable then
		xTable = {len=0}
		world.chunks[chunk.x] = xTable
	end
	
	local yTable = xTable[chunk.y]
	if not yTable then
		yTable = {len=0}
		xTable[chunk.y] = yTable
	end
	yTable[chunk.z] = chunk
	
	local id
	if world.freeChunkIdsToUse.len ~= 0 then
		id = world.freeChunkIdsToUse[world.freeChunkIdsToUse.len]
		world.freeChunkIdsToUse.len = world.freeChunkIdsToUse.len - 1
	else
		id = world.nextIdAfterChunkIdListEnd
		world.nextIdAfterChunkIdListEnd = world.nextIdAfterChunkIdListEnd + 1
	end
	chunk.id = id
	world.chunksById[id] = chunk
end

function chunkManager.remove(world, chunk)
	local xTable = world.chunks[chunk.x]
	local yTable = xTable[chunk.y]
	yTable[chunk.z] = nil
	yTable.len = yTable.len - 1
	if yTable.len == 0 then
		xTable[chunk.y] = nil
		xTable.len = xTable.len - 1
		if xTable.len == 0 then
			world.chunks[chunk.x] = nil
		end
	end
	
	local id = chunk.id
	world.chunksById[id] = nil
	if id ~= world.nextIdAfterChunkIdListEnd - 1 then
		world.freeChunkIdsToUse[world.freeChunkIdsToUse.len + 1] = id
		world.freeChunkIdsToUse.len = world.freeChunkIdsToUse.len + 1
	end
end

local floor = math.floor
local blockHash = require("systems.blockHash")
local bhEncodeForTerrainString = blockHash.encodeForTerrainString
function chunkManager.getBlock(self, x, y, z)
	local hash = bhEncodeForTerrainString(x, y, z)
	local terrainChar = string.sub(self.terrain, hash, hash)
	local metadata = string.byte(string.sub(self.metadata, hash, hash))
	-- metadata byte:
	-- ssssssdd
	local state, damage = floor(metadata / 4), metadata % 4
	return string.byte(terrainChar), state, damage
end

local function canDraw(thisBlockId, neighbourBlockId)
	local thisBlock, neighbourBlock = terrainByIndex[thisBlockId], terrainByIndex[neighbourBlockId]
	return not thisBlock.invisible and (neighbourBlock == nil or neighbourBlock.invisible)
end

local function get(t, k)
	if t then
		return t[k]
	end
end

local addRect

local function getBlockFromSelfOrNeighbours(chunks, chunk, x, y, z)
	local cx, cy, cz = chunk.x, chunk.y, chunk.z
	
	if x == -1 then cx = cx - 1 end
	if x == cw then cx = cx + 1 end
	if y == -1 then cy = cy - 1 end
	if y == ch then cy = cy + 1 end
	if z == -1 then cz = cz - 1 end
	if z == cd then cz = cz + 1 end
	
	local chunkToCheck = get(get(get(chunks, cx), cy), cz)
	
	if chunkToCheck then
		x, y, z = x % cw, y % ch, z % cd
		return chunkManager.getBlock(chunkToCheck, x, y, z)
	end
	
	return 0 -- air
end

local textureVLength = 1 / assets.terrain.constants.numTextures
local u1s, v1s, u2s, v2s = assets.terrain.u1s, assets.terrain.v1s, assets.terrain.u2s, assets.terrain.v2s

local sqrt = math.sqrt
local scene = require("systems.scene")
local emptyBlocks = string.char(0):rep(cw*ch*cd)
function chunkManager.doUpdates(world, list)
	-- TEMP
	if not list then
		list = {}
		for _, chunk in pairs(world.chunksById) do
			list[chunk] = true
		end
	end
	-- /TEMP
	
	local chunks = world.chunks
	
	local listX, listY, listZ, listX2, listY2, listZ2 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	for chunk in pairs(list) do
		if chunk.terrain == emptyBlocks then
			chunkManager.remove(world, chunk)
			if scene.chunksToDraw:has(chunk) then
				scene.chunksToDraw:remove(chunk)
			end
			list[chunk] = nil
		else
			listX, listY, listZ = math.min(chunk.x, listX), math.min(chunk.y, listY), math.min(chunk.z, listZ)
			listX2, listY2, listZ2 = math.max(chunk.x, listX2), math.max(chunk.y, listY2), math.max(chunk.z, listZ2)
		end
	end
	listX2, listY2, listZ2 = listX2 + 1, listY2 + 1, listZ2 + 1
	
	local triTable = constants.triTable
	-- local maxSameEdgesPerCube = triTable.maxSameEdgesPerCube
	-- local triangleNormals, lenTriangleNormals = {}, 0
	-- local overallVerts = {}
	-- local encodeX, encodeY, encodeZ = listX * cw - 1, listY * ch - 1, listZ * cd - 1
	-- local encodeW, encodeH, encodeD = (listX2 - listX) * cw + 2, (listY2 - listY) * ch + 2, (listZ2 - listZ) * cd + 2
	-- local chunkVerts = {}
	for chunk in pairs(list) do
		local chunkX, chunkY, chunkZ = chunk.x, chunk.y, chunk.z
		local verts, lenVerts = {}, 0
		-- chunkVerts[chunk] = verts
		
		local function doPos(x, y, z)
			local vnnn = canDraw(getBlockFromSelfOrNeighbours(chunks, chunk, x-1, y-1, z-1)) and 0x1  or 0
			local vpnn = canDraw(getBlockFromSelfOrNeighbours(chunks, chunk, x,   y-1, z-1)) and 0x2  or 0
			local vpnp = canDraw(getBlockFromSelfOrNeighbours(chunks, chunk, x,   y-1, z  )) and 0x4  or 0
			local vnnp = canDraw(getBlockFromSelfOrNeighbours(chunks, chunk, x-1, y-1, z  )) and 0x8  or 0
			local vnpn = canDraw(getBlockFromSelfOrNeighbours(chunks, chunk, x-1, y,   z-1)) and 0x10 or 0
			local vppn = canDraw(getBlockFromSelfOrNeighbours(chunks, chunk, x,   y,   z-1)) and 0x20 or 0
			local vppp = canDraw(getBlockFromSelfOrNeighbours(chunks, chunk, x,   y,   z  )) and 0x40 or 0
			local vnpp = canDraw(getBlockFromSelfOrNeighbours(chunks, chunk, x-1, y,   z  )) and 0x80 or 0
			
			local triangles = triTable[vnnn+vnnp+vnpn+vnpp+vpnn+vpnp+vppn+vppp]
			local x1, y1, z1 = bw * (x + cw * chunkX - 0.5), bh * (y + ch * chunkY - 0.5), bd * (z + cd * chunkZ - 0.5)
			local x2, y2, z2 = x1 + bw / 2, y1 + bh / 2, z1 + bd / 2
			local x3, y3, z3 = x1 + bw, y1 + bh, z1 + bd
			
			local function getVertexPosition(edge)
				if edge == 0 then      return x2, y1, z1
				elseif edge == 1 then  return x3, y1, z2
				elseif edge == 2 then  return x2, y1, z3
				elseif edge == 3 then  return x1, y1, z2
				elseif edge == 4 then  return x2, y3, z1
				elseif edge == 5 then  return x3, y3, z2
				elseif edge == 6 then  return x2, y3, z3
				elseif edge == 7 then  return x1, y3, z2
				elseif edge == 8 then  return x1, y2, z1
				elseif edge == 9 then  return x3, y2, z1
				elseif edge == 10 then return x3, y2, z3
				elseif edge == 11 then return x1, y2, z3
				end
			end
			
			-- local function storeVertex(vertex, edge, i)
			-- 	local x, y, z = x+chunkX*cw, y+chunkY*ch, z+chunkZ*cd
			-- 	-- "Destination edges" are 8, 3, and 0
			-- 	local edgeSharingIndex
			-- 	if edge == 0 then
			-- 		edgeSharingIndex = 0
			-- 	elseif edge == 1 then
			-- 		edge = 3
			-- 		x = x + 1
			-- 		edgeSharingIndex = 1
			-- 	elseif edge == 2 then
			-- 		edge = 0
			-- 		z = z + 1
			-- 		edgeSharingIndex = 1
			-- 	elseif edge == 3 then
			-- 		edgeSharingIndex = 0
			-- 	elseif edge == 4 then
			-- 		edge = 0
			-- 		y = y + 1
			-- 		edgeSharingIndex = 1
			-- 	elseif edge == 5 then
			-- 		edge = 3
			-- 		x = x + 1
			-- 		y = y + 1
			-- 		edgeSharingIndex = 2
			-- 	elseif edge == 6 then
			-- 		edge = 0
			-- 		y = y - 1
			-- 		z = z - 1
			-- 		edgeSharingIndex = 2
			-- 	elseif edge == 7 then
			-- 		edge = 3
			-- 		y = y + 1
			-- 		edgeSharingIndex = 1
			-- 	elseif edge == 8 then
			-- 		edgeSharingIndex = 0
			-- 	elseif edge == 9 then
			-- 		edge = 8
			-- 		x = x + 1
			-- 		edgeSharingIndex = 1
			-- 	elseif edge == 10 then
			-- 		edge = 8
			-- 		x = x + 1
			-- 		z = z + 1
			-- 		edgeSharingIndex = 2
			-- 	elseif edge == 11 then
			-- 		edge = 8
			-- 		z = z + 1
			-- 		edgeSharingIndex = 1
			-- 	end
			-- 	-- if edge == 0 then
			-- 	-- 	edge = 0
			-- 	--[=[else]=]if edge == 3 then
			-- 		edge = 1
			-- 	elseif edge == 8 then
			-- 		edge = 2
			-- 	end
			-- 	local index =
			-- 		i +
			-- 		edge * maxSameEdgesPerCube +
			-- 		edgeSharingIndex * 3 * maxSameEdgesPerCube +
			-- 		(x - encodeX) * 4 * 3 * maxSameEdgesPerCube +
			-- 		(y - encodeY) * encodeW * 4 * 3 * maxSameEdgesPerCube +
			-- 		(z - encodeZ) * encodeH * encodeW * 4 * 3 * maxSameEdgesPerCube
			-- 	vertex.info = {x, y, z, edge, edgeSharingIndex}
			-- 	overallVerts[index] = vertex
			-- end
			
			local i = 0
			while i < #triangles/3 do
				local v1e = triangles[i*3+1]
				local v2e = triangles[i*3+2]
				local v3e = triangles[i*3+3]
				
				local v1x, v1y, v1z = getVertexPosition(v1e)
				local v2x, v2y, v2z = getVertexPosition(v2e)
				local v3x, v3y, v3z = getVertexPosition(v3e)
				local e1x, e1y, e1z = v1x-v2x, v1y-v2y, v1z-v2z
				local e2x, e2y, e2z = v1x-v3x, v1y-v3y, v1z-v3z
				local normalX, normalY, normalZ = 
					e1y * e2z - e1z * e2y,
					e1z * e2x - e1x * e2z,
					e1x * e2y - e1y * e2x
				
				-- Normalise
				local magnitude = sqrt(normalX^2+normalY^2+normalZ^2)
				normalX, normalY, normalZ =
					normalX / magnitude,
					normalY / magnitude,
					normalZ / magnitude
				
				-- triangleNormals[lenTriangleNormals*3+1], triangleNormals[lenTriangleNormals*3+2], triangleNormals[lenTriangleNormals*3+3] = normalX, normalY, normalZ
				
				local v1 = {v1x, v1y, v1z, --[=[normalId = lenTriangleNormals}]=] normalX, normalY, normalZ, }
				local v2 = {v2x, v2y, v2z, --[=[normalId = lenTriangleNormals}]=] normalX, normalY, normalZ, }
				local v3 = {v3x, v3y, v3z, --[=[normalId = lenTriangleNormals}]=] normalX, normalY, normalZ, }
				
				verts[lenVerts + 1] = v1
				verts[lenVerts + 2] = v2
				verts[lenVerts + 3] = v3
				
				-- storeVertex(v1, v1e, i)
				-- storeVertex(v2, v2e, i)
				-- storeVertex(v3, v3e, i)
				
				-- lenTriangleNormals = lenTriangleNormals + 1
				lenVerts = lenVerts + 3
				i = i + 1
			end
		end
		for x = 0, cw - 1 do
			for y = 0, ch - 1 do
				for z = 0, cd - 1 do
					doPos(x, y, z)
				end
			end
		end
		if not get(get(get(chunks, chunkX + 1), chunkY), chunkZ) then
			for y = 0, ch - 1 do
				for z = 0, cd - 1 do
					doPos(cw, y, z)
				end
			end
		end
		if not get(get(get(chunks, chunkX), chunkY + 1), chunkZ) then
			for x = 0, cw - 1 do
				for z = 0, cd - 1 do
					doPos(x, ch, z)
				end
			end
		end
		if not get(get(get(chunks, chunkX + 1), chunkY + 1), chunkZ) then
			for z = 0, cd - 1 do
				doPos(cw, ch, z)
			end
		end
		if not get(get(get(chunks, chunkX), chunkY), chunkZ + 1) then
			for x = 0, cw - 1 do
				for y = 0, ch - 1 do
					doPos(x, y, cd)
				end
			end
		end
		if not get(get(get(chunks, chunkX + 1), chunkY), chunkZ + 1) then
			for y = 0, ch - 1 do
				doPos(cw, y, cd)
			end
		end
		if not get(get(get(chunks, chunkX), chunkY + 1), chunkZ + 1) then
			for x = 0, cd - 1 do
				doPos(x, ch, cd)
			end
		end
		if not get(get(get(chunks, chunkX + 1), chunkY + 1), chunkZ + 1) then
			doPos(cw, ch, cd)
		end
	-- end
	-- 
	-- for x = encodeX+1, encodeX+encodeW-1 do
	-- 	for y = encodeY+1, encodeY+encodeH-1 do
	-- 		for z = encodeZ+1, encodeZ+encodeD-1 do
	-- 			local baseIndex =
	-- 				-- 0 +
	-- 				-- edge * maxSameEdgesPerCube +
	-- 				-- 0 * 3  * maxSameEdgesPerCube +
	-- 				(x - encodeX) * 4 * 3  * maxSameEdgesPerCube +
	-- 				(y - encodeY) * encodeW * 4 * 3  * maxSameEdgesPerCube +
	-- 				(z - encodeZ) * encodeH * encodeW * 4 * 3 * maxSameEdgesPerCube
	-- 			for edge = 0, 2 do -- 0 = 0, 1 = 3, 2 = 8
	-- 				local v1 = overallVerts[baseIndex+0*maxSameEdgesPerCube]
	-- 				local v2 = overallVerts[baseIndex+3*maxSameEdgesPerCube]
	-- 				local v3 = overallVerts[baseIndex+6*maxSameEdgesPerCube]
	-- 				local v4 = overallVerts[baseIndex+9*maxSameEdgesPerCube]
	-- 				local n = 0
	-- 				local normalX, normalY, normalZ = 0, 0, 0
	-- 				if v1 then
	-- 					local triangleNormalId = v1.normalId
	-- 					normalX = triangleNormals[triangleNormalId*3+1]
	-- 					normalY = triangleNormals[triangleNormalId*3+2]
	-- 					normalZ = triangleNormals[triangleNormalId*3+3]
	-- 					n = 1
	-- 				end
	-- 				if v2 then
	-- 					local triangleNormalId = v2.normalId
	-- 					normalX = normalX + triangleNormals[triangleNormalId*3+1]
	-- 					normalY = normalY + triangleNormals[triangleNormalId*3+2]
	-- 					normalZ = normalZ + triangleNormals[triangleNormalId*3+3]
	-- 					n = n + 1
	-- 				end
	-- 				if v3 then
	-- 					local triangleNormalId = v3.normalId
	-- 					normalX = normalX + triangleNormals[triangleNormalId*3+1]
	-- 					normalY = normalY + triangleNormals[triangleNormalId*3+2]
	-- 					normalZ = normalZ + triangleNormals[triangleNormalId*3+3]
	-- 					n = n + 1
	-- 				end
	-- 				if v4 then
	-- 					local triangleNormalId = v4.normalId
	-- 					normalX = normalX + triangleNormals[triangleNormalId*3+1]
	-- 					normalY = normalY + triangleNormals[triangleNormalId*3+2]
	-- 					normalZ = normalZ + triangleNormals[triangleNormalId*3+3]
	-- 					n = n + 1
	-- 				end
	-- 				local normalX, normalY, normalZ =
	-- 					normalX / n,
	-- 					normalY / n,
	-- 					normalZ / n
	-- 				if v1 then
	-- 					v1[4], v1[5], v1[6] = normalX, normalY, normalZ
	-- 				end
	-- 				if v2 then
	-- 					v2[4], v2[5], v2[6] = normalX, normalY, normalZ
	-- 				end
	-- 				if v3 then
	-- 					v3[4], v3[5], v3[6] = normalX, normalY, normalZ
	-- 				end
	-- 				if v4 then
	-- 					v4[4], v4[5], v4[6] = normalX, normalY, normalZ
	-- 				end
	-- 			end
	-- 		end
	-- 	end
	-- end
	-- 
	-- for chunk in pairs(list) do
	-- 	local verts = chunkVerts[chunk]
		if chunk.mesh then
			chunk.mesh:release()
		end
		if not verts[1] then
			-- lenVerts == 0
			chunk.mesh = nil
		else
			chunk.mesh = love.graphics.newMesh(vertexFormat, verts, "triangles")
		end
	end
end

return chunkManager
