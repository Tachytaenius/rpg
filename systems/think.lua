local detmath = require("lib.detmath")

return function(entity, world)
	local player = world.entities:get(1)
	
	local x, y, z, w, h, d = world.bumpWorld:getCube(entity)
	local ex, ey, ez = x+w/2, y+entity.eyeHeight, z+d/2
	
	local x, y, z, w, h, d = world.bumpWorld:getCube(player)
	local px, py, pz = x+w/2, y+player.eyeHeight, z+d/2
	
	-- TODO: Abstract entity getters et cetera
	
	local pxn, pxp = px - worldWidthMetres, px + worldWidthMetres
	if ex < worldWidthMetres / 2 and math.abs(ex - pxn) < math.abs(ex - px) then
		px = pxn
	elseif ex > worldWidthMetres / 2 and math.abs(ex - pxp) < math.abs(ex - px) then
		px = pxp
	end
	
	local pzn, pzp = pz - worldDepthMetres, pz + worldDepthMetres
	if ez < worldDepthMetres / 2 and math.abs(ez - pzn) < math.abs(ez - pz) then
		pz = pzn
	elseif ez > worldDepthMetres / 2 and math.abs(ez - pzp) < math.abs(ez - pz) then
		pz = pzp
	end
	
	local angleBetween = detmath.angle(px - ex, pz - ez)
	local dtheta = angleBetween == angleBetween and angleBetween - entity.theta or 0
	
	-- TEMP: find the better way to get shortest turn route (no internet)
	dtheta = dtheta % detmath.tau -- is this even needed?
	if dtheta > detmath.tau/2 then
		dtheta = dtheta - detmath.tau
	end
	
	local will = {}
	
	dtheta = dtheta + detmath.tau / 4 -- Forward facing direction
	will.targetVelocityThetaMultiplier = dtheta
	will.targetVelocityPhiMultiplier = mdy
	
	return will
end
