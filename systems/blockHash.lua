local constants = require("constants")
local w = constants.chunkWidth
local h = constants.chunkHeight
local d = constants.chunkDepth

local floor = math.floor

local blockHash = {}

function blockHash.encodeForBump(x, y, z, chunkId)
	local hash =
		x +
		y * w +
		z * h * w +
		chunkId * d * h * w
	return hash
end

function blockHash.encodeForTerrainString(x, y, z)
	local hash =
		x +
		y * w +
		z * h * w
	return hash + 1
end

function blockHash.decode(hash)
	local x = hash % w
	
	hash = floor(hash / w)
	local y = hash % h
	
	hash = floor(hash / h)
	local z = hash % d
	
	hash = floor(hash / d)
	local chunkId = hash
	
	return x, y, z, chunkId
end

return blockHash
