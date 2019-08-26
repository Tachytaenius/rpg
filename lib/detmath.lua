-- Deterministic maths functions for Lua
-- By Tachytaenius

-- For determinism they rely on IEEE-754 compliance (very rarely missing) and consistent rounding modes (always present under LÖVE, if memory serves (TODO: Does it?))

local tau = 6.28318530717958647692 -- Pi is also provided, of course :-)
local e = 2.71828182845904523536
local abs, floor, sqrt, modf, huge = math.abs, math.floor, math.sqrt, math.modf, math.huge

local function exp(x)
	local xint, xfract = modf(x)
	local exint = e ^ xint -- x raised to an integer is deterministic (TODO: is it?!)
	local exfract = 1 + xfract + (xfract ^ 2 / 2) + (xfract ^ 3 / 6) + (xfract ^ 4 / 24)
	return exint * exfract -- e ^ (xint + xfract)
end

local function todo() error("Not done yet.") end
local function log(x)
	todo()
end
local function pow(x, y)
	todo()
	local logx = log(x) -- FIXME: no overhead
	local power = y * logx
	
	local pint, pfract = modf(power)
	local epint = e ^ pint
	local epfract = 1 + pfract + (pfract ^ 2 / 2) + (pfract ^ 3 / 6) + (pfract ^ 4 / 24)
	return epint * epfract
end

local function sin(x)
	local over = floor(x / (tau / 2)) % 2 == 0 -- Get sign of sin(x)
	x = tau/4 - x % (tau/2) -- Shift x into domain of approximation
	local absolute = 1 - (20 * x^2) / (4 * x^2 + tau^2) -- https://www.desmos.com/calculator/o6gy67kqpg (should help to visualise what's going on)
	return over and absolute or -absolute
end

local function cos(x)
	local over = floor((tau/4 - x) / (tau / 2)) % 2 == 0
	x = tau/4 - (tau/4 - x) % (tau/2)
	local absolute = 1 - (20 * x^2) / (4 * x^2 + tau^2)
	return over and absolute or -absolute
end

local function tan(x)
	-- return sin(x)/cos(x)
	local s, c
	do
		local over = floor(x / (tau / 2)) % 2 == 0
		local x = tau/4 - x % (tau/2)
		local absolute = 1 - (20 * x^2) / (4 * x^2 + tau^2)
		s = over and absolute or -absolute
	end
	-- TODO: Optimise it further than just copy-pasting the two functions into one
	do
		local over = floor((tau/4 - x) / (tau / 2)) % 2 == 0
		local x = tau/4 - (tau/4 - x) % (tau/2)
		local absolute = 1 - (20 * x^2) / (4 * x^2 + tau^2)
		c = over and absolute or -absolute
	end
	return s/c
end

local function asin(x)
	local positiveX, x = x > 0, abs(x)
	local resultForAbsoluteX = tau/4 - sqrt(tau^2 * (1 - x)) / (2 * sqrt(x + 4))
	return positiveX and resultForAbsoluteX or -resultForAbsoluteX
end

local function acos(x)
	local positiveX, x = x > 0, abs(x)
	local resultForAbsoluteX = sqrt(tau^2 * (1 - x)) / (2 * sqrt(x + 4)) -- Only approximates acos(x) when x > 0
	return positiveX and resultForAbsoluteX or -resultForAbsoluteX + tau/2
end

local function atan(x)
	x = x / sqrt(1 + x^2)
	local positiveX, x = x > 0, abs(x)
	local resultForAbsoluteX = tau/4 - sqrt(tau^2 * (1 - x)) / (2 * sqrt(x + 4))
	return positiveX and resultForAbsoluteX or -resultForAbsoluteX
end

-- TODO: Find a better name
local function angle(x, y)
	local theta = atan(y/x)
	theta = x == 0 and tau/4 * y / abs(y) or x < 0 and theta + tau/2 or theta
	return theta % tau
end

-- Personally discouraged as I believe that, though the transition from atan to atan2 makes sense, the definition of the arctangent doesn't accomodate two arguments
local function atan2(y, x)
	-- return angle(x, y)
	local theta = atan(y/x)
	theta = x == 0 and tau/4 * y / abs(y) or x < 0 and theta + tau/2 or theta
	return theta % tau
end

local function sinh(x)
	local ex = exp(x)
	return (ex - 1/ex) / 2
end

local function cosh(x)
	local ex = exp(x)
	return (ex + 1/ex) / 2
end

local function tanh(x)
	local ex = exp(x)
	return (ex - 1/ex) / (ex + 1/ex)
end

return {
	tau = tau,
	pi = tau / 2, -- Choose whichever you find personally gratifying. I use tau in this library but it's up to you
	e = e,
	exp = exp,
	pow = pow,
	log = log,
	log10 = log10,
	sin = sin,
	cos = cos,
	tan = tan,
	asin = asin,
	acos = acos,
	atan = atan,
	angle = angle,
	atan2 = atan2,
	sinh = sinh,
	cosh = cosh,
	tanh = tanh
}

-- Thanks!
