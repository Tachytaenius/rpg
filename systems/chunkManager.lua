local registry = require("registry")
local assets = require("assets")
local constants = require("constants")

local bw, bh, bd = constants.blockWidth, constants.blockHeight, constants.blockDepth
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth

local terrainByIndex = registry.terrainByIndex

local vertexFormat = {
	{"VertexPosition", "float", 3},
	{"VertexTexCoord", "float", 2},
	{"VertexNormal", "float", 3},
	
	{"vertexDamage", "float", 1}
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

-- In certain "camera conditions" block sides would show some pixels from their neighbouring textures in the terrain texture atlasses
-- Saves more memory than padding each texture in the the terrain texture atlasses, and is probably a lot faster than using min/max etc. for Texel's arguments...
local shift = textureVLength * 0.001
function addRect(verts, lenVerts, side, x, y, z, a, b, u1, v1, u2, v2, damage)
	v1 = v1 + shift
	v2 = v2 - shift
	
	local vv, vV, Vv, VV
	if side == "nyz" then
		vv = {x, y, z, u1, v2, -1, 0, 0, damage}
		vV = {x, y, z + b, u2, v2, -1, 0, 0, damage}
		Vv = {x, y + a, z, u1, v1, -1, 0, 0, damage}
		VV = {x, y + a, z + b, u2, v1, -1, 0, 0, damage}
	elseif side == "pyz" then
		vv = {x, y, z, u2, v2, 1, 0, 0, damage}
		vV = {x, y + a, z, u2, v1, 1, 0, 0, damage}
		Vv = {x, y, z + b, u1, v2, 1, 0, 0, damage}
		VV = {x, y + a, z + b, u1, v1, 1, 0, 0, damage}
	elseif side == "nxz" then
		vv = {x, y, z, u1, v2, 0, -1, 0, damage}
		vV = {x + a, y, z, u2, v2, 0, -1, 0, damage}
		Vv = {x, y, z + b, u1, v1, 0, -1, 0, damage}
		VV = {x + a, y, z + b, u2, v1, 0, -1, 0, damage}
	elseif side == "pxz" then
		vv = {x, y, z, u1, v1, 0, 1, 0, damage}
		vV = {x, y, z + b, u1, v2, 0, 1, 0, damage}
		Vv = {x + a, y, z, u2, v1, 0, 1, 0, damage}
		VV = {x + a, y, z + b, u2, v2, 0, 1, 0, damage}
	elseif side == "nxy" then
		vv = {x, y, z, u2, v2, 0, 0, -1, damage}
		vV = {x, y + b, z, u2, v1, 0, 0, -1, damage}
		Vv = {x + a, y, z, u1, v2, 0, 0, -1, damage}
		VV = {x + a, y + b, z, u1, v1, 0, 0, -1, damage}
	elseif side == "pxy" then
		vv = {x, y, z, u1, v2, 0, 0, 1, damage}
		vV = {x + a, y, z, u2, v2, 0, 0, 1, damage}
		Vv = {x, y + b, z, u1, v1, 0, 0, 1, damage}
		VV = {x + a, y + b, z, u2, v1, 0, 0, 1, damage}
	end
	
	verts[lenVerts + 1], verts[lenVerts + 2], verts[lenVerts + 3] = vv, vV, Vv
	verts[lenVerts + 4], verts[lenVerts + 5], verts[lenVerts + 6] = Vv, vV, VV
end

local scene = require("systems.scene")
local emptyBlocks = string.char(0):rep(cw*ch*cd)
function chunkManager.doUpdates(world, list)
	if not list then
		list = {}
		for _, chunk in pairs(world.chunksById) do
			list[chunk] = true
		end
	end
	
	for chunk in pairs(list) do
		if chunk.terrain == emptyBlocks then
			chunkManager.remove(world, chunk)
			if scene.chunksToDraw:has(chunk) then
				scene.chunksToDraw:remove(chunk)
			end
			list[chunk] = nil
		end
	end
	for chunk in pairs(list) do
		chunkManager.update(chunk, world)
	end
end

function chunkManager.update(self, world)
	local chunks = world.chunks
	local selfX, selfY, selfZ = self.x, self.y, self.z
	local verts, lenVerts = {}, 0
	
	local unsmoothed = true
	if unsmoothed then
		for x = 0, cw - 1 do
			for y = 0, ch - 1 do
				for z = 0, cd - 1 do
					-- tb means "this block"
					local tb, tbstate, tbdmg = chunkManager.getBlock(self, x, y, z)
					local tbx, tby, tbz = selfX * cw + x, selfY * ch + y, selfZ * cd + z
					if canDraw(tb) then
						local block = terrainByIndex[tb]
						local name = block.name
						local getTextureAtlasOffset = block.getTextureAtlasOffset
						local u1, v1, u2, v2 = u1s[name], v1s[name], u2s[name], v2s[name]
						
						local nzz, nzzstate = getBlockFromSelfOrNeighbours(chunks, self, x - 1, y, z)
						local pzz, pzzstate = getBlockFromSelfOrNeighbours(chunks, self, x + 1, y, z)
						local znz, znzstate = getBlockFromSelfOrNeighbours(chunks, self, x, y - 1, z)
						local zpz, zpzstate = getBlockFromSelfOrNeighbours(chunks, self, x, y + 1, z)
						local zzn, zznstate = getBlockFromSelfOrNeighbours(chunks, self, x, y, z - 1)
						local zzp, zzpstate = getBlockFromSelfOrNeighbours(chunks, self, x, y, z + 1)
						local nnz, nnzstate = getBlockFromSelfOrNeighbours(chunks, self, x - 1, y - 1, z)
						local pnz, pnzstate = getBlockFromSelfOrNeighbours(chunks, self, x + 1, y - 1, z)
						local npz, npzstate = getBlockFromSelfOrNeighbours(chunks, self, x - 1, y + 1, z)
						local ppz, ppzstate = getBlockFromSelfOrNeighbours(chunks, self, x + 1, y + 1, z)
						local nzn, nznstate = getBlockFromSelfOrNeighbours(chunks, self, x - 1, y, z - 1)
						local pzn, pznstate = getBlockFromSelfOrNeighbours(chunks, self, x + 1, y, z - 1)
						local nzp, nzpstate = getBlockFromSelfOrNeighbours(chunks, self, x - 1, y, z + 1)
						local pzp, pzpstate = getBlockFromSelfOrNeighbours(chunks, self, x + 1, y, z + 1)
						local zpp, zppstate = getBlockFromSelfOrNeighbours(chunks, self, x, y + 1, z + 1)
						local zpn, zpnstate = getBlockFromSelfOrNeighbours(chunks, self, x, y + 1, z - 1)
						local znp, znpstate = getBlockFromSelfOrNeighbours(chunks, self, x, y - 1, z + 1)
						local znn, znnstate = getBlockFromSelfOrNeighbours(chunks, self, x, y - 1, z - 1)
						
						if canDraw(tb, nzz) then
							local textureIndex = getTextureAtlasOffset and getTextureAtlasOffset("nx", tbstate, nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn, nzzstate, pzzstate, znzstate, zpzstate, zznstate, zzpstate, nnzstate, pnzstate, npzstate, ppzstate, nznstate, pznstate, nzpstate, pzpstate, zppstate, zpnstate, znpstate, znnstate) or 0
							local vOffset = textureVLength * textureIndex
							addRect(verts, lenVerts, "nyz", tbx * bw, tby * bh, tbz * bd, bh, bd, u1, v1 + vOffset, u2, v2 + vOffset, tbdmg)
							lenVerts = lenVerts + 6
						end
						if canDraw(tb, pzz) then
							local textureIndex = getTextureAtlasOffset and getTextureAtlasOffset("px", tbstate, nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn, nzzstate, pzzstate, znzstate, zpzstate, zznstate, zzpstate, nnzstate, pnzstate, npzstate, ppzstate, nznstate, pznstate, nzpstate, pzpstate, zppstate, zpnstate, znpstate, znnstate) or 0
							local vOffset = textureVLength * textureIndex
							addRect(verts, lenVerts, "pyz", (tbx + 1) * bw, tby * bh, tbz * bd, bh, bd, u1, v1 + vOffset, u2, v2 + vOffset, tbdmg)
							lenVerts = lenVerts + 6
						end
						if canDraw(tb, zzn) then
							local textureIndex = getTextureAtlasOffset and getTextureAtlasOffset("nz", tbstate, nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn, nzzstate, pzzstate, znzstate, zpzstate, zznstate, zzpstate, nnzstate, pnzstate, npzstate, ppzstate, nznstate, pznstate, nzpstate, pzpstate, zppstate, zpnstate, znpstate, znnstate) or 0
							local vOffset = textureVLength * textureIndex
							addRect(verts, lenVerts, "nxy", tbx * bw, tby * bh, tbz * bd, bw, bh, u1, v1 + vOffset, u2, v2 + vOffset, tbdmg)
							lenVerts = lenVerts + 6
						end
						if canDraw(tb, zzp) then
							local textureIndex = getTextureAtlasOffset and getTextureAtlasOffset("pz", tbstate, nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn, nzzstate, pzzstate, znzstate, zpzstate, zznstate, zzpstate, nnzstate, pnzstate, npzstate, ppzstate, nznstate, pznstate, nzpstate, pzpstate, zppstate, zpnstate, znpstate, znnstate) or 0
							local vOffset = textureVLength * textureIndex
							addRect(verts, lenVerts, "pxy", tbx * bw, tby * bh, (tbz + 1) * bd, bw, bh, u1, v1 + vOffset, u2, v2 + vOffset, tbdmg)
							lenVerts = lenVerts + 6
						end
						if canDraw(tb, znz) then
							local textureIndex = getTextureAtlasOffset and getTextureAtlasOffset("ny", tbstate, nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn, nzzstate, pzzstate, znzstate, zpzstate, zznstate, zzpstate, nnzstate, pnzstate, npzstate, ppzstate, nznstate, pznstate, nzpstate, pzpstate, zppstate, zpnstate, znpstate, znnstate) or 0
							local vOffset = textureVLength * textureIndex
							addRect(verts, lenVerts, "nxz", tbx * bw, tby * bh, tbz * bd, bw, bd, u1, v1 + vOffset, u2, v2 + vOffset, tbdmg)
							lenVerts = lenVerts + 6
						end
						if canDraw(tb, zpz) then
							local textureIndex = getTextureAtlasOffset and getTextureAtlasOffset("py", tbstate, nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn, nzzstate, pzzstate, znzstate, zpzstate, zznstate, zzpstate, nnzstate, pnzstate, npzstate, ppzstate, nznstate, pznstate, nzpstate, pzpstate, zppstate, zpnstate, znpstate, znnstate) or 0
							local vOffset = textureVLength * textureIndex
							addRect(verts, lenVerts, "pxz", tbx * bw, (tby + 1) * bh, tbz * bd, bw, bd, u1, v1 + vOffset, u2, v2 + vOffset, tbdmg)
							lenVerts = lenVerts + 6
						end
					end
				end
			end
		end
	else
		local function doPos(x, y, z)
			local vnnn = canDraw(getBlockFromSelfOrNeighbours(chunks, self, x-1, y-1, z-1)) and 0x1  or 0
			local vpnn = canDraw(getBlockFromSelfOrNeighbours(chunks, self, x,   y-1, z-1)) and 0x2  or 0
			local vpnp = canDraw(getBlockFromSelfOrNeighbours(chunks, self, x,   y-1, z  )) and 0x4  or 0
			local vnnp = canDraw(getBlockFromSelfOrNeighbours(chunks, self, x-1, y-1, z  )) and 0x8  or 0
			local vnpn = canDraw(getBlockFromSelfOrNeighbours(chunks, self, x-1, y,   z-1)) and 0x10 or 0
			local vppn = canDraw(getBlockFromSelfOrNeighbours(chunks, self, x,   y,   z-1)) and 0x20 or 0
			local vppp = canDraw(getBlockFromSelfOrNeighbours(chunks, self, x,   y,   z  )) and 0x40 or 0
			local vnpp = canDraw(getBlockFromSelfOrNeighbours(chunks, self, x-1, y,   z  )) and 0x80 or 0
			
			local triangles = constants.triTable[vnnn+vnnp+vnpn+vnpp+vpnn+vpnp+vppn+vppp+1]
			local x1, y1, z1 = bw * (x + cw * selfX - 0.5), bh * (y + ch * selfY - 0.5), bd * (z + cd * selfZ - 0.5)
			local x2, y2, z2 = x1 + bw / 2, y1 + bh / 2, z1 + bd / 2
			local x3, y3, z3 = x1 + bw, y1 + bh, z1 + bd
			for _, edge in ipairs(triangles) do
				lenVerts = lenVerts + 1
				if edge == 0 then      verts[lenVerts] = {x2, y1, z1}
				elseif edge == 1 then  verts[lenVerts] = {x3, y1, z2}
				elseif edge == 2 then  verts[lenVerts] = {x2, y1, z3}
				elseif edge == 3 then  verts[lenVerts] = {x1, y1, z2}
				elseif edge == 4 then  verts[lenVerts] = {x2, y3, z1}
				elseif edge == 5 then  verts[lenVerts] = {x3, y3, z2}
				elseif edge == 6 then  verts[lenVerts] = {x2, y3, z3}
				elseif edge == 7 then  verts[lenVerts] = {x1, y3, z2}
				elseif edge == 8 then  verts[lenVerts] = {x1, y2, z1}
				elseif edge == 9 then  verts[lenVerts] = {x3, y2, z1}
				elseif edge == 10 then verts[lenVerts] = {x3, y2, z3}
				elseif edge == 11 then verts[lenVerts] = {x1, y2, z3}
				end
			end
		end
		for x = 0, cw - 1 do
			for y = 0, ch - 1 do
				for z = 0, cd - 1 do
					doPos(x, y, z)
				end
			end
		end
		if not get(get(get(world.chunks, selfX + 1), selfY), selfZ) then
			for y = 0, ch - 1 do
				for z = 0, cd - 1 do
					doPos(cw, y, z)
				end
			end
		end
		if not get(get(get(world.chunks, selfX), selfY + 1), selfZ) then
			for x = 0, cw - 1 do
				for z = 0, cd - 1 do
					doPos(x, ch, z)
				end
			end
		end
		if not get(get(get(world.chunks, selfX + 1), selfY + 1), selfZ) then
			for z = 0, cd - 1 do
				doPos(cw, ch, z)
			end
		end
		if not get(get(get(world.chunks, selfX), selfY), selfZ + 1) then
			for x = 0, cw - 1 do
				for y = 0, ch - 1 do
					doPos(x, y, cd)
				end
			end
		end
		if not get(get(get(world.chunks, selfX + 1), selfY), selfZ + 1) then
			for y = 0, ch - 1 do
				doPos(cw, y, cd)
			end
		end
		if not get(get(get(world.chunks, selfX), selfY + 1), selfZ + 1) then
			for x = 0, cd - 1 do
				doPos(x, ch, cd)
			end
		end
		if not get(get(get(world.chunks, selfX + 1), selfY + 1), selfZ + 1) then
			doPos(cw, ch, cd)
		end
	end
	
	if self.mesh then
		self.mesh:release()
	end
	if lenVerts == 0 then
		self.mesh = nil
	else
		self.mesh = love.graphics.newMesh(vertexFormat, verts, "triangles")
	end
end

return chunkManager
