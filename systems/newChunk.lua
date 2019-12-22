local registry = require("registry")
local assets = require("assets")
local constants = require("constants")
local generate = require("systems.generate")

local bw, bh, bd = constants.blockWidth, constants.blockHeight, constants.blockDepth
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth

local terrainByIndex = registry.terrainByIndex

local vertexFormat = {
	{"VertexPosition", "float", 3},
	{"VertexTexCoord", "float", 2},
	{"VertexNormal", "float", 3},
	
	{"vertexDamage", "float", 1}
}

local updateMesh

local function get(t, k)
	if t then
		return t[k]
	end
end

local floor = math.floor
local blockHash = require("systems.blockHash")
local bhEncodeForTerrainString = blockHash.encodeForTerrainString
local function getBlock(self, x, y, z)
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

local function newChunk(x, y, z, chunks, bumpWorld, seed, id)
	local ret = {
		id = id,
		x = x, y = y, z = z,
		
		-- Methods:
		updateMesh = updateMesh,
		getBlock = getBlock
	}
	
	ret.terrain, ret.metadata = generate(x, y, z, id, bumpWorld, seed)
	
	return ret
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
		return chunkToCheck:getBlock(x, y, z)
	end
	
	return 0 -- air
end

local textureVLength = 1 / assets.terrain.constants.numTextures
local u1s, v1s, u2s, v2s = assets.terrain.u1s, assets.terrain.v1s, assets.terrain.u2s, assets.terrain.v2s

function updateMesh(self, chunks)
	local selfX, selfY, selfZ = self.x, self.y, self.z
	
	local verts, lenVerts = {}, 0
	
	for x = 0, cw - 1 do
		for y = 0, ch - 1 do
			for z = 0, cd - 1 do
				-- tb means "this block"
				local tb, tbstate, tbdmg = self:getBlock(x, y, z)
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
	
	if self.mesh then
		self.mesh:release()
	end
	if lenVerts == 0 then
		self.mesh = nil
	else
		self.mesh = love.graphics.newMesh(vertexFormat, verts, "triangles")
	end
end

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

return newChunk
