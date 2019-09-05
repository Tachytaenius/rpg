local constants = require("constants")
local detmath = require("lib.detmath")
local bw, bh, bd = constants.blockWidth, constants.blockHeight, constants.blockDepth
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth

local terrainMetatable = {
	__call = function(t, x, y, z)
		x, y, z = x % cw, y % ch, z % cd
		return string.sub(t[x][z], y + 1)
	end
}

local smoothRandom2D, smoothRandom3D, chaoticRandom, updateString
local generateTree

local function generate(cx, cy, cz, bumpWorld, seed)
	local ox, oy, oz = cw * cx, ch * cy, cd * cz
	
	local terrain = {}
	
	for x = 0, cw - 1 do
		local terrainX = {}
		terrain[x] = terrainX
		
		for z = 0, cd - 1 do
			local columnTable = {} -- contains block ids (as strings)
			terrainX[z] = {columnTable = columnTable, updateString = updateString}
			local boxes = {}
			
			local blockX = bw * (ox + x)
			local blockZ = bd * (oz + z)
			local noise = smoothRandom2D(seed, blockX, blockZ, 20, 20) * 8
			noise = noise + smoothRandom2D(seed, blockX, blockZ, 15, 15) * 4
			noise = noise + smoothRandom2D(seed, blockX, blockZ, 10, 10) * 2
			noise = noise + smoothRandom2D(seed, blockX, blockZ, 5, 5)
			local terrainHeight = bh * (10+4*noise)
			for y = 0, ch - 1 do
				local blockY = bh * (oy + y)
				if blockY <= terrainHeight then
					local block
					if blockY + bh > terrainHeight then
						block = 2
					elseif blockY + terrainHeight >= 2 then
						block = 1
					else
						block = 3
					end
					columnTable[y + 1] = string.char(block)
					local box = {}
					boxes[y] = box
					bumpWorld:add(box, blockX, blockY, blockZ, bw, bh, bd)
				else
					columnTable[y + 1] = string.char(0)
				end
			end
		end
	end
	
	if cx % 3 == 1 and cz % 3 == 1 then
		generateTree(terrain, ox, oy, oz, cw / 2, cd / 2)
	end
	
	for x = 0, cw - 1 do
		local terrainX = terrain[x]
		for z = 0, cd - 1 do
			terrainX[z]:updateString()
		end
	end
	
	return setmetatable(terrain, terrainMetatable)
end

function smoothRandom2D(chaotic, x, z, w, d)
	local dx, dz = worldWidthMetres / w, worldDepthMetres / d
	local s, t = (x / w) / dx, (z / d) / dz
	local nx = detmath.cos(s*detmath.tau)*dx/detmath.tau
	local ny = detmath.cos(t*detmath.tau)*dz/detmath.tau
	local nz = detmath.sin(s*detmath.tau)*dx/detmath.tau
	local nw = detmath.sin(t*detmath.tau)*dz/detmath.tau
	return love.math.noise(nx, ny, nz, nw)
end

-- it's *all* chaos here, but the world's seed will usually be put in to completely change what the other values do
function chaoticRandom(...)
	-- TODO
	return love.math.random()
end

function updateString(self)
	self.columnString = table.concat(self.columnTable)
end

function generateTree(terrain, ox, oy, oz, trunkX, trunkZ)
	-- TODO
	local treeDiameter = 1
	local treeHeight = 4
	
	local blockX = bw * (ox + trunkX)
	local blockZ = bd * (oz + trunkZ)
	local terrainHeightInMetresAtTrunk = bh * (10+4*smoothRandom2D(seed, blockX, blockZ, 8, 8)) -- TODO: From cached information?
	
	-- TODO: abort if obstructed (requires not to write to table unless sure not gonna abort)
	for x = math.max(trunkX, 0), math.min(trunkX + treeDiameter, cw) - 1 do
		local terrainX = terrain[x]
		for z = math.max(trunkZ, 0), math.min(trunkZ + treeDiameter, cd) - 1 do
			local columnTable = terrainX[z].columnTable
			for y = 0, ch - 1 do
				local blockYInMetres = bh * (oy + y)
				if blockYInMetres >= terrainHeightInMetresAtTrunk and blockYInMetres - terrainHeightInMetresAtTrunk <= treeHeight then
					columnTable[y + 1] = string.char(4)
				end
			end
		end
	end
end

return generate

--[=[
-- "Spare iterator"
for x = 0, cw - 1 do
	local terrainX = terrain[x]
	for z = 0, cd - 1 do
		local columnTable = terrainX[z]
		for y = 0, ch - 1 do
			
		end
	end
end
]=]
