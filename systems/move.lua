local constants = require("constants")
local detmath = require("lib.detmath")

-- These are defined below as here it's less confusing to read the returned functions first
local getChange, useTargetAndChange, clamp, response, filter

local move = {} -- The return value

function move.initialise(bumpWorld)
	bumpWorld:addResponse("proper", response)
end

function move.gravitate(entity, amount, maxFallSpeed, dt)
	entity.vy = useTargetAndChange(entity.vy, -maxFallSpeed, entity.vy > -maxFallSpeed and -amount or amount, dt)
end

function move.selfAccelerate(entity, will, dt)
	local abilities = entity.abilities
	local mobility = abilities.mobility
	
	local targetX = will.targetVelocityXMultiplier or 0
	targetX = targetX * mobility.maximumTargetVelocity.x[targetX > 0 and "positive" or "negative"]
	
	local targetY = will.targetVelocityYMultiplier or 0
	targetY = targetY * mobility.maximumTargetVelocity.y[targetY > 0 and "positive" or "negative"]
	
	local targetZ = will.targetVelocityZMultiplier or 0
	targetZ = targetZ * mobility.maximumTargetVelocity.z[targetZ > 0 and "positive" or "negative"]
	
	local targetTheta = will.targetVelocityThetaMultiplier or 0
	targetTheta = targetTheta * mobility.maximumTargetVelocity.theta[targetTheta > 0 and "positive" or "negative"]
	
	local targetPhi = will.targetVelocityPhiMultiplier or 0
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

local queryFilter, getObjects, moveObjects
local activeCube, activeWorld
local queryBaseX, queryBaseY, queryBaseZ, queryBaseW, queryBaseH, queryBaseD
function move.collide(entity, bumpWorld, dt)
	-- These things are handled in the collision response
	entity.grounded = false
	entity.nextVx, entity.nextVy, entity.nextVz = entity.vx, entity.vy, entity.vz
	
	
	local x, y, z, w, h, d = bumpWorld:getCube(entity)
	
	local entityMoveX = entity.vx * dt
	local entityMoveY = entity.vy * dt
	local entityMoveZ = entity.vz * dt
	
	local goalX = x + entityMoveX
	local goalY = y + entityMoveY
	local goalZ = z + entityMoveZ
	
	-- Query for world wrap
	queryBaseX, queryBaseY, queryBaseZ = x+math.min(entityMoveX,0), y+math.min(entityMoveY,0), z+math.min(entityMoveZ,0)
	queryBaseW, queryBaseH, queryBaseD = w+math.abs(entityMoveX), h+math.abs(entityMoveY), d+math.abs(entityMoveZ)
	
	activeCube = entity -- For the filter
	activeWorld = bumpWorld -- For the get/move functions
	
	local queryPX, lenQueryPX = getObjects(1, 0)
	local queryNX, lenQueryNX = getObjects(-1, 0)
	local queryPZ, lenQueryPZ = getObjects(0, 1)
	local queryNZ, lenQueryNZ = getObjects(0, -1)
	local queryPXZ, lenQueryPXZ = getObjects(1, 1)
	local queryNXZ, lenQueryNXZ = getObjects(-1, -1)
	
	if queryPX then moveObjects(queryPX, lenQueryPX, -1, 0) end
	if queryNX then moveObjects(queryNX, lenQueryNX, 1, 0) end
	if queryPZ then moveObjects(queryPZ, lenQueryPZ, 0, -1) end
	if queryNZ then moveObjects(queryNZ, lenQueryNZ, 0, 1) end
	if queryPXZ then moveObjects(queryPXZ, lenQueryPXZ, -1, -1) end
	if queryNXZ then moveObjects(queryNXZ, lenQueryNXZ, 1, 1) end
	
	local nextX, nextY, nextZ = bumpWorld:check(entity, goalX, goalY, goalZ, filter)
	entity.preModuloX, entity.preModuloZ = nextX, nextZ
	entity.nextX, entity.nextY, entity.nextZ = nextX % worldWidthMetres, nextY, nextZ % worldDepthMetres
	
	if queryPX then moveObjects(queryPX, lenQueryPX, 1, 0) end
	if queryNX then moveObjects(queryNX, lenQueryNX, -1, 0) end
	if queryPZ then moveObjects(queryPZ, lenQueryPZ, 0, 1) end
	if queryNZ then moveObjects(queryNZ, lenQueryNZ, 0, -1) end
	if queryPXZ then moveObjects(queryPXZ, lenQueryPXZ, 1, 1) end
	if queryNXZ then moveObjects(queryNXZ, lenQueryNXZ, -1, -1) end
end

function queryFilter(item)
	return item ~= activeCube
end
function getObjects(xdir, zdir)
	local xo, zo = xdir * worldWidthMetres, zdir * worldDepthMetres
	local queryX, queryY, queryZ, queryW, queryH, queryD =
		queryBaseX+xo, queryBaseY, queryBaseZ+zo, queryBaseW, queryBaseH, queryBaseD
	if queryX < worldWidthMetres and 0 < queryX + queryW and queryZ < worldDepthMetres and 0 < queryZ + queryD then
		queryW, queryD = math.min(queryW, worldWidthMetres - queryX), math.min(queryD, worldDepthMetres - queryZ)
		queryX, queryZ = math.max(queryX, 0), math.max(queryZ, 0)
		return activeWorld:queryCube(queryX, queryY, queryZ, queryW, queryH, queryD, queryFilter)
	end
end
function moveObjects(items, len, xdir, zdir)
	-- assert(len == #items)
	local xo, zo = xdir * worldWidthMetres, zdir * worldDepthMetres
	for i = 1, len do
		local item = items[i]
		local itemX, itemY, itemZ = activeWorld:getCube(item)
		activeWorld:update(item, itemX+xo, itemY, itemZ+zo)
	end
end

function move.finalise(bumpWorld, entity)
	bumpWorld:update(entity, entity.nextX, entity.nextY, entity.nextZ)
	local nextVx, nextVy, nextVz = entity.nextVx, entity.nextVy, entity.nextVz
	if entity.grounded then
		nextVy = math.abs(nextVy) > constants.velocitySnap and nextVy or 0 -- snap y velocity to avoid excessive bouncing
	end
	local speed = math.sqrt(nextVx ^ 2 + nextVy ^ 2 + nextVz ^ 2)
	if speed > constants.maxSpeed then
		nextVx, nextVy, nextVz =
			nextVx / speed * constants.maxSpeed,
			nextVy / speed * constants.maxSpeed,
			nextVz / speed * constants.maxSpeed
	end
	entity.vx, entity.vy, entity.vz = nextVx, nextVy, nextVz
	
	entity.nextX, entity.nextY, entity.nextZ, entity.nextVx, entity.nextVy, entity.nextVz = nil
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
		if col.normal.y > 0 then
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
