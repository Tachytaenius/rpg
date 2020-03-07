local zimblegz = {
	name = "Zimblegz",
	description = "OpenSimplex in Lua",
	credits = "A port of https://github.com/lmas/opensimplex/",
	author = "Tachytaenius"
}

local ffi = require("ffi")
local uint64 = ffi.typeof("uint64_t")

local floor, sqrt = math.floor, math.sqrt

local stretchConstant2D = (1/sqrt(2+1)-1)/2
local squishConstant2D = (sqrt(2+1)-1)/2
local stretchConstant3D = (1/sqrt(3+1)-1)/3
local squishConstant3D = (sqrt(3+1)-1)/3
local stretchConstant3D = (1/sqrt(4+1)-1)/4
local squishConstant3D = (sqrt(4+1)-1)/4

local normConstant2D = 47
local normConstant3D = 103
local normConstant4D = 30

local defaultSeed = 0

local gradients2D = { [0]=
     5,  2,    2,  5,
    -5,  2,   -2,  5,
     5, -2,    2, -5,
    -5, -2,   -2, -5
}

local gradients3D = { [0]=
    -11,  4,  4,   -4,  11,  4,   -4,  4,  11,
     11,  4,  4,    4,  11,  4,    4,  4,  11,
    -11, -4,  4,   -4, -11,  4,   -4, -4,  11,
     11, -4,  4,    4, -11,  4,    4, -4,  11,
    -11,  4, -4,   -4,  11, -4,   -4,  4, -11,
     11,  4, -4,    4,  11, -4,    4,  4, -11,
    -11, -4, -4,   -4, -11, -4,   -4, -4, -11,
     11, -4, -4,    4, -11, -4,    4, -4, -11
}
local lenGradients3D = #gradients3D+1

local gradients4D = { [0]=
     3,  1,  1,  1,    1,  3,  1,  1,    1,  1,  3,  1,    1,  1,  1,  3,
    -3,  1,  1,  1,   -1,  3,  1,  1,   -1,  1,  3,  1,   -1,  1,  1,  3,
     3, -1,  1,  1,    1, -3,  1,  1,    1, -1,  3,  1,    1, -1,  1,  3,
    -3, -1,  1,  1,   -1, -3,  1,  1,   -1, -1,  3,  1,   -1, -1,  1,  3,
     3,  1, -1,  1,    1,  3, -1,  1,    1,  1, -3,  1,    1,  1, -1,  3,
    -3,  1, -1,  1,   -1,  3, -1,  1,   -1,  1, -3,  1,   -1,  1, -1,  3,
     3, -1, -1,  1,    1, -3, -1,  1,    1, -1, -3,  1,    1, -1, -1,  3,
    -3, -1, -1,  1,   -1, -3, -1,  1,   -1, -1, -3,  1,   -1, -1, -1,  3,
     3,  1,  1, -1,    1,  3,  1, -1,    1,  1,  3, -1,    1,  1,  1, -3,
    -3,  1,  1, -1,   -1,  3,  1, -1,   -1,  1,  3, -1,   -1,  1,  1, -3,
     3, -1,  1, -1,    1, -3,  1, -1,    1, -1,  3, -1,    1, -1,  1, -3,
    -3, -1,  1, -1,   -1, -3,  1, -1,   -1, -1,  3, -1,   -1, -1,  1, -3,
     3,  1, -1, -1,    1,  3, -1, -1,    1,  1, -3, -1,    1,  1, -1, -3,
    -3,  1, -1, -1,   -1,  3, -1, -1,   -1,  1, -3, -1,   -1,  1, -1, -3,
     3, -1, -1, -1,    1, -3, -1, -1,    1, -1, -3, -1,    1, -1, -1, -3,
    -3, -1, -1, -1,   -1, -3, -1, -1,   -1, -1, -3, -1,   -1, -1, -1, -3
}

local simplexerMethods = {}

function simplexerMethods:init(seed)
	seed = seed or 0
	self.seed = seed
	self.perm, self.permGradIndex3D, self.source = {}, {}, {}
	for i = 0, 255 do
		self.perm[i] = 0
		self.permGradIndex3D[i] = 0
		self.source[i] = i
	end
	seed = uint64(seed)
	seed = seed * 6364136223846793005ULL + 1442695040888963407ULL
	seed = seed * 6364136223846793005ULL + 1442695040888963407ULL
	seed = seed * 6364136223846793005ULL + 1442695040888963407ULL
	for i = 255, 0, -1 do
		seed = seed * 6364136223846793005ULL + 1442695040888963407ULL
		local r = tonumber((seed + 31) % (i + 1))
		if r < 0 then
			r = r + i + 1
		end
		self.perm[i] = self.source[r]
		self.permGradIndex3D[i] = (self.perm[i] % (lenGradients3D / 3)) * 3
		self.source[r] = self.source[i]
	end
end

function simplexerMethods:extrapolate2D(xsb, ysb, dx, dy)
	local perm = self.perm
	local index = floor((perm[(perm[xsb % 256] + ysb) % 256]) / 2) % 8 * 2
	local g1, g2 = gradients2D[index], gradients2D[index+1]
	return g1*dx+g2*dy
end

function simplexerMethods:noise2D(x, y)
	local stretchOffset = (x + y) * stretchConstant2D
	local xs = x + stretchOffset
	local ys = y + stretchOffset
	
	local xsb = floor(xs)
	local ysb = floor(ys)
	
	local squishOffset = (xsb + ysb) * squishConstant2D
	local xb = xsb + squishOffset
	local yb = ysb + squishOffset
	
	local xins = xs - xsb
	local yins = ys - ysb
	
	local inSum = xins + yins
	
	local dx0 = x - xb
	local dy0 = y - yb
	
	local value = 0
	
	local dx1 = dx0 - 1 - squishConstant2D
	local dy1 = dy0 - 0 - squishConstant2D
	local attn1 = 2 - dx1 * dx1 - dy1 * dy1
	if attn1 > 0 then
		attn1 = attn1 * attn1
		value = value + attn1 * attn1 * self:extrapolate2D(xsb + 1, ysb + 0, dx1, dy1)
	end
	
	local dx2 = dx0 - 0 - squishConstant2D
	local dy2 = dy0 - 1 - squishConstant2D
	local attn2 = 2 - dx2 * dx2 - dy2 * dy2
	if attn2 > 0 then
		attn2 = attn2 * attn2
		value = value + attn2 * attn2 * self:extrapolate2D(xsb + 0, ysb + 1, dx2, dy2)
	end
	
	local xsvExt, ysvExt, dxExt, dyExt
	if inSum <= 1 then
		zins = 1 - inSum
		if zins > xins or zins > yins then
			if xins > yins then
				xsvExt = xsb + 1
				ysvExt = ysb - 1
				dxExt = dx0 - 1
				dyExt = dy0 + 1
			else
				xsvExt = xsb - 1
				ysvExt = ysb + 1
				dxExt = dx0 + 1
				dyExt = dy0 - 1
			end
		else
			xsvExt = xsb + 1
			ysvExt = ysb + 1
			dxExt = dx0 - 1 - 2 * squishConstant2D
			dyExt = dy0 - 1 - 2 * squishConstant2D
		end
	else
		zins = 2 - inSum
		if zins < xins or zins < yins then
			if xins > yins then
				xsvExt = xsb + 2
				ysvExt = ysb + 0
				dxExt = dx0 - 2 - 2 * squishConstant2D
				dyExt = dy0 + 0 - 2 * squishConstant2D
			else
				xsvExt = xsb + 0
				ysvExt = ysb + 2
				dxExt = dx0 + 0 - 2 * squishConstant2D
				dyExt = dy0 - 2 - 2 * squishConstant2D
			end
		else
			dxExt = dx0
			dyExt = dy0
			xsvExt = xsb
			ysvExt = ysb
		end
		xsb = xsb + 1
		ysb = ysb + 1
		dx0 = dx0 - 1 - 2 * squishConstant2D
		dy0 = dy0 - 1 - 2 * squishConstant2D
	end
	
	local attn0 = 2 - dx0 * dx0 - dy0 * dy0
	if attn0 > 0 then
		attn0 = attn0 * attn0
		value = value + attn0 * attn0 * self:extrapolate2D(xsb, ysb, dx0, dy0)
	end
	
	local attnExt = 2 - dxExt * dxExt - dyExt * dyExt
	if attnExt > 0 then
		attnExt = attnExt * attnExt
		value = value + attnExt * attnExt * self:extrapolate2D(xsvExt, ysvExt, dxExt, dyExt)
	end
	
	return value / normConstant2D
end

function simplexerMethods:noise3D(x, y, z)
	error("NYI!")
end

function simplexerMethods:noise4D(x, y, z, w)
	error("NYI!")
end

local simplexerMetatable = {__index = simplexerMethods}
function zimblegz.newSimplexer(...)
	local new = setmetatable({}, simplexerMetatable)
	new:init(...)
	return new
end

return zimblegz
