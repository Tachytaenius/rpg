local assets = require("assets")
local constants = require("constants")

local generate = require("systems.generate")

local terrain = assets.terrain
local bw, bh, bd = constants.blockWidth, constants.blockHeight, constants.blockDepth
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth

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

local function canDraw(thisBlock, neighbourBlock)
	return thisBlock ~= 0 and (neighbourBlock ~= thisBlock or neighbourBlock == nil)
end

local function newChunk(x, y, z, chunks, bumpWorld, seed)
	local ret = {
		x = x, y = y, z = z,
		updateMesh = updateMesh
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
	
	ret.terrain = generate(x, y, z, bumpWorld, seed)
	
	return ret
end

local addRect

function updateMesh(chunk)
	-- Neighbouring chunks also influence face visibility
	local function getBlock(x, y, z)
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
			return string.byte(chunkToCheck.terrain[x][z].string, y + 1)
		end
	end
	
	local chunkX, chunkY, chunkZ = chunk.x, chunk.y, chunk.z
	
	local verts, lenVerts = {}, 0
	
	for x = 0, cw - 1 do
		for y = 0, ch - 1 do
			for z = 0, cd - 1 do
				-- tb means "this block"
				local tb = string.byte(chunk.terrain[x][z].string, y + 1)
				local tbx, tby, tbz = chunkX * cw + x, chunkY * ch + y, chunkZ * cd + z
				if canDraw(tb) then
					local us, vs = 1/16, 1/16
					
					local texx, texy
					if tb == 2 then
						texx, texy = 0, 1
					elseif tb == 1 then
						texx, texy = 0, 2
					elseif tb == 3 then
						texx, texy = 1, 0
					end
					texx, texy = texx + 1, texy + 1
					
					local u1, v1 = texx * us, texy * vs
					local u2, v2 = u1 - us, v1 - vs
					if canDraw(tb, getBlock(x - 1, y, z)) then
						addRect(verts, lenVerts, "nyz", tbx * bw, tby * bh, tbz * bd, bh, bd, u1, v1, u2, v2)
						lenVerts = lenVerts + 6
					end
					if canDraw(tb, getBlock(x + 1, y, z)) then
						addRect(verts, lenVerts, "pyz", (tbx + 1) * bw, tby * bh, tbz * bd, bh, bd, u1, v1, u2, v2)
						lenVerts = lenVerts + 6
					end
					if canDraw(tb, getBlock(x, y, z - 1)) then
						addRect(verts, lenVerts, "nxy", tbx * bw, tby * bh, tbz * bd, bw, bh, u1, v1, u2, v2)
						lenVerts = lenVerts + 6
					end
					if canDraw(tb, getBlock(x, y, z + 1)) then
						addRect(verts, lenVerts, "pxy", tbx * bw, tby * bh, (tbz + 1) * bd, bw, bh, u1, v1, u2, v2)
						lenVerts = lenVerts + 6
					end
					
					if tb == 2 then
						texx, texy = 0, 0
						texx, texy = texx + 1, texy + 1
						u1, v1 = texx * us, texy * vs
						u2, v2 = u1 - us, v1 - vs
					end
					if canDraw(tb, getBlock(x, y - 1, z)) then
						addRect(verts, lenVerts, "nxz", tbx * bw, tby * bh, tbz * bd, bw, bd, u1, v1, u2, v2)
						lenVerts = lenVerts + 6
					end
					
					if tb == 2 then
						texx, texy = 2, 0
						texx, texy = texx + 1, texy + 1
						u1, v1 = texx * us, texy * vs
						u2, v2 = u1 - us, v1 - vs
					end
					if canDraw(tb, getBlock(x, y + 1, z)) then
						addRect(verts, lenVerts, "pxz", tbx * bw, (tby + 1) * bh, tbz * bd, bw, bd, u1, v1, u2, v2)
						lenVerts = lenVerts + 6
					end
				end
			end
		end
	end
	
	if chunk.mesh then chunk.mesh:destroy() end
	if lenVerts == 0 then return end
	chunk.mesh = love.graphics.newMesh(vertexFormat, verts, "triangles")
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
	
	verts[lenVerts + 1], verts[lenVerts + 2], verts[lenVerts + 3] = vv, Vv, vV
	verts[lenVerts + 4], verts[lenVerts + 5], verts[lenVerts + 6] = Vv, VV, vV
end

return newChunk
