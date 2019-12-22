local detmath = require("lib.detmath")

local segmentCaster
local function notSelfFilter(item)
	return item ~= segmentCaster
end

return function(entity, bumpWorld, action, filter)
	local x, y, z, w, h, d = bumpWorld:getCube(entity)
	local cx, cy, cz = x + w / 2, y + entity.eyeHeight, z + d / 2
	local dx, dy, dz =
		entity.abilities.reach * detmath.cos(entity.theta - detmath.tau / 4) * detmath.cos(entity.phi),
		-entity.abilities.reach * detmath.sin(entity.phi),
		entity.abilities.reach * detmath.sin(entity.theta - detmath.tau / 4) * detmath.cos(entity.phi)
	
	segmentCaster = entity
	local infos, len = bumpWorld:querySegmentWithCoords(cx, cy, cz, cx + dx, cy + dy, cz + dz, notSelfFilter)
	if len > 0 then
		local firstItem = infos[1].item
		
		if filter and not filter(firstItem) then return end
		
		if len > 1 then
			local a, b = infos[1], infos[2]
			if a.ti1 == b.ti1 then
				return -- Abort in "tied" cases
			end
		end
		
		return action(firstItem, infos[1])
	end
end
