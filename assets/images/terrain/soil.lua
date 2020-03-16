local noice = require("lib.noice")
local assets = require("assets")
local perliner = noice.newNoiser("Perlin")

local soil = {}

local abs = math.abs
local function nzsgn(x) -- "no zero"
	return x < 0 and -1 or 1
end

function soil.diffuse(x, y, z)
	local v = perliner:noise3D(x*8, y*8, z*8, 8, 8, 8)
	-- v = (1 - (1 - abs(v) ^ 2)) * nzsgn(v)
	v = v / 16
	v = v / 2 + 0.5
	
	return v*0.8, v*0.6, v*0.4, 1
end

function soil.normal(x, y, z)
	return 0.5, 0.5, 1
end

function soil.ambientIllumination(x, y, z)
	return 1
end

function soil.metalness(x, y, z)
	return 0
end

function soil.roughness(x, y, z)
	return 0.85
end

function soil.fresnel(x, y, z)
	return 0.5
end

return soil
