local function addRect(verts, lenVerts, side, x, y, z, a, b, u1, v1, u2, v2)
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

-- Neighbouring chunks also influence face visibility
local function getBlock(chunk, x, y, z)
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
		return string.byte(chunkToCheck.terrain[x][z].columnString, y + 1)
	end
end

local ret = [[
	
	
	local lenVerts, chunk, x, y, z, 
]]

local function add(line)
	ret = ret .. line
end

return loadstring(ret)
