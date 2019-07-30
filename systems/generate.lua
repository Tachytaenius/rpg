local constants = require("constants")
local bw, bh, bd = constants.blockWidth, constants.blockHeight, constants.blockDepth
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth

local terrainMetatable = {
	__call = function(t, x, y, z)
		x, y, z = x % cw, y % ch, z % cd
		return string.sub(t[x][z], y + 1)
	end
}

local function generate(x, y, z, bumpWorld, seed)
	local ox, oy, oz = cw * x, ch * y, cd * z
	
	local features = {}
	
	for i = 1, love.math.random(constants.minChunkFeatures, constants.maxChunkFeatures) do -- oh i sure do hope (TODO) something about determinism or lack thereof AAAAAAAAAAAAAAAAAAAAAAAAAUUUUUUUUUUGGGGHHHHHHHHHHHHHHHHHHHHHHHH
		-- message from alicia, josie, romula, rema, arthur, and rodrick: dw we love you. you can do it :-)
		
	end
	
	local terrain = {}
	
	for x = 0, cw - 1 do
		local terrainX = {}
		
		for z = 0, cd - 1 do
			local tempColumn = {}
			local boxes = {}
			
			local blockX = bw * (ox + x)
			local blockZ = bd * (oz + z)
			local terrainHeight = bh * (love.math.noise(blockX / 16, blockZ / 16) * 4 + 10)
			for y = 0, ch - 1 do
				local blockY = bh * (oy + y)
				if blockY >= terrainHeight then
					tempColumn[y + 1] = string.char(1)
					local box = {}
					boxes[y] = box
					bumpWorld:add(box, blockX, blockY, blockZ, bw, bh, bd)
				else
					tempColumn[y + 1] = string.char(0)
				end
			end
			
			terrainX[z] = {string = table.concat(tempColumn)}
		end
		
		terrain[x] = terrainX
	end
	
	return setmetatable(terrain, terrainMetatable)
end

return generate

-- for relBlockX = 0, cw - 1 do
-- 	local blockX = x * cw + relBlockX
-- 	local slice = {}
-- 	ret[relBlockX] = slice
-- 	for relBlockY = 0, ch - 1 do
-- 		local blockY = y * ch + relBlockY
-- 		local tempAisle = {}
-- 		local bumpBoxes = {}
-- 		local aisle = {bumpBoxes = bumpBoxes}
-- 		for relBlockZ = 0, cd - 1 do
-- 			local blockZ = z * cd + relBlockZ
-- 			local terrainHeight = math.floor(love.math.noise(blockX / 16, blockZ / 16) * 8)
-- 			local b = blockY - terrainHeight
-- 			if b > 0 then
-- 				if b == 1 then
-- 					b = 2
-- 				elseif b < 7 then
-- 					b = 1
-- 				else
-- 					b = 3
-- 				end
-- 			else
-- 				b = 0
-- 			end
-- 			tempAisle[relBlockZ + 1] = string.char(b)
-- 			if b ~= 0 and b ~= 3 then
-- 				local dummy = {}
-- 				bumpBoxes[relBlockZ] = dummy
-- 				bumpWorld:add({}, blockX * bw, blockY * bh, blockZ * bd, bw, bh, bd)
-- 			end
-- 		end
-- 		aisle.string = table.concat(tempAisle)
-- 		slice[relBlockY] = aisle
-- 	end
-- end