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

function chunkManager.getBlockInWorld(chunks, x, y, z)
	local cx, cy, cz = math.floor(x / cw), math.floor(y / ch), math.floor(z / cd)
	local chunk = get(get(get(chunks, cx), cy), cz)
	if chunk then
		return chunkManager.getBlock(chunk, x % cw, y % ch, z % cd)
	else
		return 0
	end
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
	
	if listX == math.huge then return end -- No chunks to update
	
	-- Slightly expanded cube to see neighbouring blocks at boundary
	local encodeX, encodeY, encodeZ, encodeW, encodeH, encodeD =
		listX * cw - 2, listY * ch - 2, listZ * cd - 2,
		(listX2 + 1 - listX) * cw + 4, (listY2 + 1 - listY) * ch + 4, (listZ2 + 1 - listZ) * cd + 4
	
	local cubeVertices = {}
	for x = encodeX, encodeX + encodeW - 1 do
		for y = encodeY, encodeY + encodeH - 1 do
			for z = encodeZ, encodeZ + encodeD - 1 do
				local gx, gy, gz = -- Technically these should be divided by two to be the actual gradient, but it doesn't affect the end result in this case
					(chunkManager.getBlockInWorld(chunks, x - 1, y, z) ~= 0 and 1 or 0) - (chunkManager.getBlockInWorld(chunks, x + 1, y, z) ~= 0 and 1 or 0),
					(chunkManager.getBlockInWorld(chunks, x, y - 1, z) ~= 0 and 1 or 0) - (chunkManager.getBlockInWorld(chunks, x, y + 1, z) ~= 0 and 1 or 0),
					(chunkManager.getBlockInWorld(chunks, x, y, z - 1) ~= 0 and 1 or 0) - (chunkManager.getBlockInWorld(chunks, x, y, z + 1) ~= 0 and 1 or 0)
				local baseIndex =
					-- 0 +
					(x - encodeX) * 4 +
					(y - encodeY) * encodeW * 4 +
					(z - encodeZ) * encodeH * encodeW * 4
				cubeVertices[baseIndex+0] = chunkManager.getBlockInWorld(chunks, x, y, z) ~= 0 and 1 or 0
				cubeVertices[baseIndex+1] = gx
				cubeVertices[baseIndex+2] = gy
				cubeVertices[baseIndex+3] = gz
			end
		end
	end
	
	local function getCubeVertex(x, y, z)
		local baseIndex =
			-- 0 +
			(x - encodeX) * 4 +
			(y - encodeY) * encodeW * 4 +
			(z - encodeZ) * encodeH * encodeW * 4
		-- value, gradientX, gradientY, gradientZ
		return cubeVertices[baseIndex+0], cubeVertices[baseIndex+1], cubeVertices[baseIndex+2], cubeVertices[baseIndex+3]
	end
	
	local triTable = constants.triTable
	for chunk in pairs(list) do
		local chunkX, chunkY, chunkZ = chunk.x, chunk.y, chunk.z
		local verts, lenVerts = {}, 0
		
		local function doPos(x, y, z)
			local worldX, worldY, worldZ = chunkX * cw + x, chunkY * ch + y, chunkZ * cd + z
			
			local nnnv, nnngx, nnngy, nnngz = getCubeVertex(worldX-1, worldY-1, worldZ-1)
			local pnnv, pnngx, pnngy, pnngz = getCubeVertex(worldX,   worldY-1, worldZ-1)
			local pnpv, pnpgx, pnpgy, pnpgz = getCubeVertex(worldX,   worldY-1, worldZ  )
			local nnpv, nnpgx, nnpgy, nnpgz = getCubeVertex(worldX-1, worldY-1, worldZ  )
			local npnv, npngx, npngy, npngz = getCubeVertex(worldX-1, worldY,   worldZ-1)
			local ppnv, ppngx, ppngy, ppngz = getCubeVertex(worldX,   worldY,   worldZ-1)
			local pppv, pppgx, pppgy, pppgz = getCubeVertex(worldX,   worldY,   worldZ  )
			local nppv, nppgx, nppgy, nppgz = getCubeVertex(worldX-1, worldY,   worldZ  )
			
			local nnnv = nnnv ~= 0 and 0x1  or 0
			local pnnv = pnnv ~= 0 and 0x2  or 0
			local pnpv = pnpv ~= 0 and 0x4  or 0
			local nnpv = nnpv ~= 0 and 0x8  or 0
			local npnv = npnv ~= 0 and 0x10 or 0
			local ppnv = ppnv ~= 0 and 0x20 or 0
			local pppv = pppv ~= 0 and 0x40 or 0
			local nppv = nppv ~= 0 and 0x80 or 0
			
			local triangles = triTable[nnnv+nnpv+npnv+nppv+pnnv+pnpv+ppnv+pppv]
			local x1, y1, z1 = bw * (x + cw * chunkX - 0.5), bh * (y + ch * chunkY - 0.5), bd * (z + cd * chunkZ - 0.5)
			local x2, y2, z2 = x1 + bw / 2, y1 + bh / 2, z1 + bd / 2
			local x3, y3, z3 = x1 + bw, y1 + bh, z1 + bd
			
			local function getVertex(edge)
				local x, y, z, gx, gy, gz
				if edge == 0 then
					gx, gy, gz =
						nnngx * 0.5 + pnngx * 0.5,
						nnngy * 0.5 + pnngy * 0.5,
						nnngz * 0.5 + pnngz * 0.5
					x, y, z = x2, y1, z1
				elseif edge == 1 then
					gx, gy, gz =
						pnngx * 0.5 + pnpgx * 0.5,
						pnngy * 0.5 + pnpgy * 0.5,
						pnngz * 0.5 + pnpgz * 0.5
					x, y, z = x3, y1, z2
				elseif edge == 2 then
					gx, gy, gz =
						nnpgx * 0.5 + pnpgx * 0.5,
						nnpgy * 0.5 + pnpgy * 0.5,
						nnpgz * 0.5 + pnpgz * 0.5
					x, y, z = x2, y1, z3
				elseif edge == 3 then
					gx, gy, gz =
						nnngx * 0.5 + nnpgx * 0.5,
						nnngy * 0.5 + nnpgy * 0.5,
						nnngz * 0.5 + nnpgz * 0.5
					x, y, z = x1, y1, z2
				elseif edge == 4 then
					gx, gy, gz =
						npngx * 0.5 + ppngx * 0.5,
						npngy * 0.5 + ppngy * 0.5,
						npngz * 0.5 + ppngz * 0.5
					x, y, z = x2, y3, z1
				elseif edge == 5 then
					gx, gy, gz =
						ppngx * 0.5 + pppgx * 0.5,
						ppngy * 0.5 + pppgy * 0.5,
						ppngz * 0.5 + pppgz * 0.5
					x, y, z = x3, y3, z2
				elseif edge == 6 then
					gx, gy, gz =
						nppgx * 0.5 + pppgx * 0.5,
						nppgy * 0.5 + pppgy * 0.5,
						nppgz * 0.5 + pppgz * 0.5
					x, y, z = x2, y3, z3
				elseif edge == 7 then
					gx, gy, gz =
						npngx * 0.5 + nppgx * 0.5,
						npngy * 0.5 + nppgy * 0.5,
						npngz * 0.5 + nppgz * 0.5
					x, y, z = x1, y3, z2
				elseif edge == 8 then
					gx, gy, gz =
						nnngx * 0.5 + npngx * 0.5,
						nnngy * 0.5 + npngy * 0.5,
						nnngz * 0.5 + npngz * 0.5
					x, y, z = x1, y2, z1
				elseif edge == 9 then
					gx, gy, gz =
						pnngx * 0.5 + ppngx * 0.5,
						pnngy * 0.5 + ppngy * 0.5,
						pnngz * 0.5 + ppngz * 0.5
					x, y, z = x3, y2, z1
				elseif edge == 10 then
					gx, gy, gz =
						pnpgx * 0.5 + pppgx * 0.5,
						pnpgy * 0.5 + pppgy * 0.5,
						pnpgz * 0.5 + pppgz * 0.5
					x, y, z = x3, y2, z3
				elseif edge == 11 then
					gx, gy, gz =
						nnpgx * 0.5 + nppgx * 0.5,
						nnpgy * 0.5 + nppgy * 0.5,
						nnpgz * 0.5 + nppgz * 0.5
					x, y, z = x1, y2, z3
				end
				
				local magnitude = sqrt(gx^2+gy^2+gz^2)
				local nx, ny, nz =
					gx / magnitude,
					gy / magnitude,
					gz / magnitude
				
				return {x, y, z, nx, ny, nz}
			end
			
			local i = 0
			while i < #triangles/3 do
				local v1 = getVertex(triangles[i*3+1])
				local v2 = getVertex(triangles[i*3+2])
				local v3 = getVertex(triangles[i*3+3])
			
				verts[lenVerts + 1] = v1
				verts[lenVerts + 2] = v2
				verts[lenVerts + 3] = v3
				
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
		
		if chunk.mesh then chunk.mesh:release() end
		chunk.mesh = lenVerts > 0 and love.graphics.newMesh(vertexFormat, verts, "triangles")
	end
end

return chunkManager
