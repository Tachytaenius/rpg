local constants = require("constants")
local bw, bh, bd = constants.blockWidth, constants.blockHeight, constants.blockDepth
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth

local terrainMetatable = {
	__call = function(t, x, y, z)
		x, y, z = x % cw, y % ch, z % cd
		return string.sub(t[x][z], y + 1)
	end
}

local smoothRandom, chaoticRandom

local function generate(x, y, z, bumpWorld, seed)
	local ox, oy, oz = cw * x, ch * y, cd * z
	
	local features = {}
	local numFeatures = math.floor(constants.maxChunkFeatures - constants.minChunkFeatures + 1) * chaoticRandom(seed, x, y, z) + constants.minChunkFeatures
	-- multiplied by, idk, if it's a jungle or something? TODO
	for i = 1, numFeatures do
		
	end
	
	local terrain = {}
	
	for x = 0, cw - 1 do
		local terrainX = {}
		
		for z = 0, cd - 1 do
			local tempColumn = {}
			local boxes = {}
			
			local blockX = bw * (ox + x)
			local blockZ = bd * (oz + z)
			local terrainHeight = bh * (smoothRandom(--[[seed, -- > 2 args turns love.math.noise perlin, do not want]] blockX/16, blockZ/16)*4+10)
			for y = 0, ch - 1 do
				local blockY = bh * (oy + y)
				if blockY >= terrainHeight then
					local block
					if blockY - bh < terrainHeight then
						block = 2
					elseif blockY - terrainHeight <= 2 then
						block = 1
					else
						block = 3
					end
					tempColumn[y + 1] = string.char(block)
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

-- chaos (the world's seed in most cases) will make the input values create an entirely different world... provided it remains constant as the others change
function smoothRandom(chaos, ...)
	-- TODO
	return love.math.noise(chaos, ...)
end

-- it's *all* chaos here, but the world's seed will usually be put in to completely change what the other values do
function chaoticRandom(...)
	-- TODO
	return love.math.random()
end

return generate
