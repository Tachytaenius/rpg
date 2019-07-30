local detmath = require("lib.detmath")

-- These are defined below as here it's less confusing to read the returned functions first
local getChange, useTargetAndChange, clamp, response, filter

local move = {} -- The return value

function move.initialise(bumpWorld)
	bumpWorld:addResponse("proper", response)
end

function move.accelerate(entity, will, dt)
	if will.isGravity then
		entity.vy = useTargetAndChange(entity.vy, will.targetY, entity.vy > will.targetY and -will.amount or will.amount, dt)
		return
	end
	
	local abilities = entity.abilities
	local mobility = abilities.mobility
	
	local targetX = will.targetVelocityXMultiplier
	targetX = targetX * mobility.maximumTargetVelocity.x[targetX > 0 and "positive" or "negative"]
	
	local targetY = will.targetVelocityYMultiplier
	targetY = targetY * mobility.maximumTargetVelocity.y[targetY > 0 and "positive" or "negative"]
	
	local targetZ = will.targetVelocityZMultiplier
	targetZ = targetZ * mobility.maximumTargetVelocity.z[targetZ > 0 and "positive" or "negative"]
	
	local targetTheta = will.targetVelocityThetaMultiplier
	targetTheta = targetTheta * mobility.maximumTargetVelocity.theta[targetTheta > 0 and "positive" or "negative"]
	
	local targetPhi = will.targetVelocityPhiMultiplier
	targetPhi = targetPhi * mobility.maximumTargetVelocity.phi[targetPhi > 0 and "positive" or "negative"]
	
	if abilities.turn then
		entity.vtheta = useTargetAndChange(entity.vtheta, targetTheta, getChange(entity.vtheta, targetTheta, "theta", mobility), dt)
		entity.preModuloTheta = (entity.theta + entity.vtheta * dt)
		entity.theta = entity.preModuloTheta % detmath.tau
		
		entity.vphi = useTargetAndChange(entity.vphi, targetPhi, getChange(entity.vphi, targetPhi, "phi", mobility), dt)
		entity.phi = math.min(math.max(entity.phi + entity.vphi * dt, -detmath.tau / 4), detmath.tau / 4)
		if entity.phi == -detmath.tau / 4 or entity.phi == detmath.tau / 4 then
			entity.vphi = 0
		end
	end
	
	if abilities.move then
		local cosine, sine = detmath.cos(entity.theta), detmath.sin(entity.theta)
		
		local relativeVelocityX = entity.vx * cosine + entity.vz * sine
		local relativeVelocityZ = entity.vz * cosine - entity.vx * sine
		
		local relativeVelocityChangeX = getChange(relativeVelocityX, targetX, "x", mobility)
		local relativeVelocityChangeZ = getChange(relativeVelocityZ, targetZ, "z", mobility)
		if not entity.grounded then
			relativeVelocityChangeX = mobility.ungroundedXChangeMultiplier * relativeVelocityChangeX
			relativeVelocityChangeZ = mobility.ungroundedZChangeMultiplier * relativeVelocityChangeZ
		end
		
		targetX, targetZ = clamp(targetX, targetZ)
		relativeVelocityChangeX, relativeVelocityChangeZ = clamp(relativeVelocityChangeX, relativeVelocityChangeZ)
		
		relativeVelocityX = useTargetAndChange(relativeVelocityX, targetX, relativeVelocityChangeX, dt)
		relativeVelocityZ = useTargetAndChange(relativeVelocityZ, targetZ, relativeVelocityChangeZ, dt)
		
		entity.vx = relativeVelocityX * cosine - relativeVelocityZ * sine
		entity.vz = relativeVelocityZ * cosine + relativeVelocityX * sine
		
		local yChange = getChange(entity.vy, targetY, "y", mobility)
		if not entity.grounded then
			yChange = yChange * mobility.ungroundedYChangeMultiplier
		end
		entity.vy = useTargetAndChange(entity.vy, targetY, yChange, dt)
	end
end

function move.collide(entity, bumpWorld, dt)
	entity.grounded = false
	entity.nextVx, entity.nextVy, entity.nextVz = entity.vx, entity.vy, entity.vz
	local x, y, z = bumpWorld:getCube(entity)
	local goalX = x + entity.vx * dt
	local goalY = y + entity.vy * dt
	local goalZ = z + entity.vz * dt
	entity.nextX, entity.nextY, entity.nextZ = bumpWorld:check(entity, goalX, goalY, goalZ, filter)
end

-- Abstractions and the like

-- Gets which of the many values in the mobility table to use
function getChange(current, target, axis, mobility)
	if current == target then return 0 end
	
	if current == 0 then
		-- Distinguishes between acceleration and deceleration, *not* the direction thereof
		signDistinction = 1
	elseif target == 0 then
		signDistinction = -1
	else
		signDistinction = math.abs(current) / current * math.abs(target) / target
	end
	
	local actualSign = current < target and 1 or -1
	
	local type = signDistinction == 1 and "maximumAcceleration" or "maximumDeceleration"
	local direction = actualSign == 1 and "positive" or "negative"
	
	return mobility[type][axis][direction] * actualSign
end

-- Applies accel/decel to a velocity and correctly handles clamping within maximum target
function useTargetAndChange(current, target, change, dt)
	if change > 0 then
		return math.min(target, current + change * dt)
	elseif change < 0 then
		return math.max(target, current + change * dt)
	end
	
	return current
end

function clamp(x, y)
	if x ~= 0 and y ~= 0 then
		local currentMag = math.sqrt(x^2 + y^2)
		local xSize, ySize = math.abs(x), math.abs(y)
		local maxMag = math.min(xSize, ySize)
		x, y = x / currentMag * maxMag, y / currentMag * maxMag
		x = x * math.max(xSize / ySize, 1)
		y = y * math.max(ySize / xSize, 1)
	end
	return x, y
end

function response(world, col, x,y,z, w,h,d, goalX, goalY, goalZ, filter)
	goalX = goalX or x
	goalY = goalY or y
	goalZ = goalZ or z
	
	local tch, mov = col.touch, col.move
	local bounciness = 0.25 -- TODO
	local entity = col.item
	
	if col.normal.x ~= 0 then
		entity.nextVx = -entity.nextVx * bounciness
		goalX = tch.x
	end
	if col.normal.y ~= 0 then
		if col.normal.y < 0 then
			entity.grounded = true
		end
		entity.nextVy = -entity.nextVy * bounciness
		goalY = tch.y
	end
	if col.normal.z ~= 0 then
		entity.nextVz = -entity.nextVz * bounciness
		goalZ = tch.z
	end
	
	col.proper = {x = goalX, y = goalY, z = goalZ}
	
	x, y, z = tch.x, tch.y, tch.z
	local cols, len = world:project(entity, x,y,z, w,h,d, goalX, goalY, goalZ, filter)
	
	return goalX, goalY, goalZ, cols, len
end

function filter(item, other)
	return "proper"
end

return move
