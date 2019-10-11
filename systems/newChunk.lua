local registry = require("registry")
local assets = require("assets")
local constants = require("constants")
local generate = require("systems.generate")

local bw, bh, bd = constants.blockWidth, constants.blockHeight, constants.blockDepth
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth

local terrainByIndex = registry.terrainByIndex

local vertexFormat = constants.vertexFormat

local updateMesh

local function get(t, k)
	if t then
		return t[k]
	end
end

local function set(t, k, v)
	if t then
		t[k] = v
	end
end

local blockHash = require("systems.blockHash")
local bhEncodeForTerrainString = blockHash.encodeForTerrainString
local function getBlock(self, x, y, z)
	local hash = bhEncodeForTerrainString(x, y, z)
	local char = string.sub(self.terrain, hash, hash)
	return string.byte(char)
end

local function canDraw(thisBlockId, neighbourBlockId)
	local thisBlock, neighbourBlock = terrainByIndex[thisBlockId], terrainByIndex[neighbourBlockId]
	return not thisBlock.invisible and (neighbourBlock == nil or neighbourBlock.invisible)
end

local function newChunk(x, y, z, chunks, bumpWorld, seed, id)
	local ret = {
		id = id,
		x = x, y = y, z = z,
		
		-- Methods:
		updateMesh = updateMesh,
		getBlock = getBlock
	}
	
	local pxNeighbour = get(get(get(chunks, x + 1), y), z)
	local nxNeighbour = get(get(get(chunks, x - 1), y), z)
	local pyNeighbour = get(get(get(chunks, x), y + 1), z)
	local nyNeighbour = get(get(get(chunks, x), y - 1), z)
	local pzNeighbour = get(get(get(chunks, x), y), z + 1)
	local nzNeighbour = get(get(get(chunks, x), y), z - 1)
	
	ret.pxNeighbour = pxNeighbour
	ret.nxNeighbour = nxNeighbour
	ret.pyNeighbour = pyNeighbour
	ret.nyNeighbour = nyNeighbour
	ret.pzNeighbour = pzNeighbour
	ret.nzNeighbour = nzNeighbour
	
	set(pxNeighbour, "nxNeighbour", ret)
	set(nxNeighbour, "pxNeighbour", ret)
	set(pyNeighbour, "nyNeighbour", ret)
	set(nyNeighbour, "pyNeighbour", ret)
	set(pzNeighbour, "nzNeighbour", ret)
	set(nzNeighbour, "pzNeighbour", ret)
	
	ret.terrain = generate(x, y, z, id, bumpWorld, seed)
	
	return ret
end

local addRect

-- Neighbouring chunks also influence face visibility
local function getBlockFromSelfOrNeighbours(chunk, x, y, z)
	local chunkToCheck = chunk
	 
	if x == -1 then
		chunkToCheck = chunk.nxNeighbour
	elseif x == cw then
		chunkToCheck = chunk.pxNeighbour
	elseif y == -1 then
		chunkToCheck = chunk.nyNeighbour
	elseif y == ch then
		chunkToCheck = chunk.pyNeighbour
	elseif z == -1 then
		chunkToCheck = chunk.nzNeighbour
	elseif z == cd then
		chunkToCheck = chunk.pzNeighbour
	end
	
	if chunkToCheck then
		x, y, z = x % cw, y % ch, z % cd
		return chunkToCheck:getBlock(x, y, z)
	end
	
	return 0 -- air
end

local textureVLength = 1 / assets.terrain.constants.numTextures
local u1s, v1s, u2s, v2s = assets.terrain.u1s, assets.terrain.v1s, assets.terrain.u2s, assets.terrain.v2s

function updateMesh(self)
	local selfX, selfY, selfZ = self.x, self.y, self.z
	
	local verts, lenVerts = {}, 0
	
	for x = 0, cw - 1 do
		for y = 0, ch - 1 do
			for z = 0, cd - 1 do
				-- tb means "this block"
				local tb = self:getBlock(x, y, z)
				local tbx, tby, tbz = selfX * cw + x, selfY * ch + y, selfZ * cd + z
				if canDraw(tb) then
					local block = terrainByIndex[tb]
					local name = block.name
					local getTextureAtlasOffset = block.getTextureAtlasOffset
					local u1, v1, u2, v2 = u1s[name], v1s[name], u2s[name], v2s[name]
					
					local nzz = getBlockFromSelfOrNeighbours(self, x - 1, y, z)
					local pzz = getBlockFromSelfOrNeighbours(self, x + 1, y, z)
					local znz = getBlockFromSelfOrNeighbours(self, x, y - 1, z)
					local zpz = getBlockFromSelfOrNeighbours(self, x, y + 1, z)
					local zzn = getBlockFromSelfOrNeighbours(self, x, y, z - 1)
					local zzp = getBlockFromSelfOrNeighbours(self, x, y, z + 1)
					local nnz = getBlockFromSelfOrNeighbours(self, x - 1, y - 1, z)
					local pnz = getBlockFromSelfOrNeighbours(self, x + 1, y - 1, z)
					local npz = getBlockFromSelfOrNeighbours(self, x - 1, y + 1, z)
					local ppz = getBlockFromSelfOrNeighbours(self, x + 1, y + 1, z)
					local nzn = getBlockFromSelfOrNeighbours(self, x - 1, y, z - 1)
					local pzn = getBlockFromSelfOrNeighbours(self, x + 1, y, z - 1)
					local nzp = getBlockFromSelfOrNeighbours(self, x - 1, y, z + 1)
					local pzp = getBlockFromSelfOrNeighbours(self, x + 1, y, z + 1)
					local zpp = getBlockFromSelfOrNeighbours(self, x, y + 1, z + 1)
					local zpn = getBlockFromSelfOrNeighbours(self, x, y + 1, z - 1)
					local znp = getBlockFromSelfOrNeighbours(self, x, y - 1, z + 1)
					local znn = getBlockFromSelfOrNeighbours(self, x, y - 1, z - 1)
					
					if canDraw(tb, nzz) then
						local textureIndex = getTextureAtlasOffset and getTextureAtlasOffset("nx", nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn) or 0
						local vOffset = textureVLength * textureIndex
						addRect(verts, lenVerts, "nyz", tbx * bw, tby * bh, tbz * bd, bh, bd, u1, v1 + vOffset, u2, v2 + vOffset)
						lenVerts = lenVerts + 6
					end
					if canDraw(tb, pzz) then
						local textureIndex = getTextureAtlasOffset and getTextureAtlasOffset("px", nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn) or 0
						local vOffset = textureVLength * textureIndex
						addRect(verts, lenVerts, "pyz", (tbx + 1) * bw, tby * bh, tbz * bd, bh, bd, u1, v1 + vOffset, u2, v2 + vOffset)
						lenVerts = lenVerts + 6
					end
					if canDraw(tb, zzn) then
						local textureIndex = getTextureAtlasOffset and getTextureAtlasOffset("nz", nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn) or 0
						local vOffset = textureVLength * textureIndex
						addRect(verts, lenVerts, "nxy", tbx * bw, tby * bh, tbz * bd, bw, bh, u1, v1 + vOffset, u2, v2 + vOffset)
						lenVerts = lenVerts + 6
					end
					if canDraw(tb, zzp) then
						local textureIndex = getTextureAtlasOffset and getTextureAtlasOffset("pz", nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn) or 0
						local vOffset = textureVLength * textureIndex
						addRect(verts, lenVerts, "pxy", tbx * bw, tby * bh, (tbz + 1) * bd, bw, bh, u1, v1 + vOffset, u2, v2 + vOffset)
						lenVerts = lenVerts + 6
					end
					if canDraw(tb, znz) then
						local textureIndex = getTextureAtlasOffset and getTextureAtlasOffset("ny", nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn) or 0
						local vOffset = textureVLength * textureIndex
						addRect(verts, lenVerts, "nxz", tbx * bw, tby * bh, tbz * bd, bw, bd, u1, v1 + vOffset, u2, v2 + vOffset)
						lenVerts = lenVerts + 6
					end
					if canDraw(tb, zpz) then
						local textureIndex = getTextureAtlasOffset and getTextureAtlasOffset("py", nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn) or 0
						local vOffset = textureVLength * textureIndex
						addRect(verts, lenVerts, "pxz", tbx * bw, (tby + 1) * bh, tbz * bd, bw, bd, u1, v1 + vOffset, u2, v2 + vOffset)
						lenVerts = lenVerts + 6
					end
				end
			end
		end
	end
	
	if self.mesh then self.mesh:release() end
	if lenVerts == 0 then return end
	self.mesh = love.graphics.newMesh(vertexFormat, verts, "triangles")
end

function addRect(verts, lenVerts, side, x, y, z, a, b, u1, v1, u2, v2)
	local vv, vV, Vv, VV
	if side == "nyz" then
		vv = {x, y, z, u1, v2, -1, 0, 0}
		vV = {x, y, z + b, u2, v2, -1, 0, 0}
		Vv = {x, y + a, z, u1, v1, -1, 0, 0}
		VV = {x, y + a, z + b, u2, v1, -1, 0, 0}
	elseif side == "pyz" then
		vv = {x, y, z, u2, v2, 1, 0, 0}
		vV = {x, y + a, z, u2, v1, 1, 0, 0}
		Vv = {x, y, z + b, u1, v2, 1, 0, 0}
		VV = {x, y + a, z + b, u1, v1, 1, 0, 0}
	elseif side == "nxz" then
		vv = {x, y, z, u1, v2, 0, -1, 0}
		vV = {x + a, y, z, u2, v2, 0, -1, 0}
		Vv = {x, y, z + b, u1, v1, 0, -1, 0}
		VV = {x + a, y, z + b, u2, v1, 0, -1, 0}
	elseif side == "pxz" then
		vv = {x, y, z, u1, v1, 0, 1, 0}
		vV = {x, y, z + b, u1, v2, 0, 1, 0}
		Vv = {x + a, y, z, u2, v1, 0, 1, 0}
		VV = {x + a, y, z + b, u2, v2, 0, 1, 0}
	elseif side == "nxy" then
		vv = {x, y, z, u2, v2, 0, 0, -1}
		vV = {x, y + b, z, u2, v1, 0, 0, -1}
		Vv = {x + a, y, z, u1, v2, 0, 0, -1}
		VV = {x + a, y + b, z, u1, v1, 0, 0, -1}
	elseif side == "pxy" then
		vv = {x, y, z, u1, v2, 0, 0, 1}
		vV = {x + a, y, z, u2, v2, 0, 0, 1}
		Vv = {x, y + b, z, u1, v1, 0, 0, 1}
		VV = {x + a, y + b, z, u2, v1, 0, 0, 1}
	end
	
	verts[lenVerts + 1], verts[lenVerts + 2], verts[lenVerts + 3] = vv, vV, Vv
	verts[lenVerts + 4], verts[lenVerts + 5], verts[lenVerts + 6] = Vv, vV, VV
end

return newChunk
