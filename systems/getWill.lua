local input = require("systems.input")

local function getWill(entity, mdx, mdy)
	-- Player version of "think", ie obeys commands
	local will = {}
	
	local crouch, run = input.didFixedCommand("crouch"), input.didFixedCommand("run")
	local advance, backpedal = input.didFixedCommand("advance"), input.didFixedCommand("backpedal")
	local strafeLeft, strafeRight = input.didFixedCommand("strafeLeft"), input.didFixedCommand("strafeRight")
	will.crouch = crouch
	local tvx, tvz = 0, 0
	if advance then tvz = tvz - 1 end
	if backpedal then tvz = tvz + 1 end
	if strafeLeft then tvx = tvx - 1 end
	if strafeRight then tvx = tvx + 1 end
	crouch = crouch or entity.isCrouched
	if crouch then
		tvx, tvz = tvx / 5, tvz / 5
	end
	if not run then
		tvx, tvz = tvx / 2, tvz / 2
	end
	will.targetVelocityXMultiplier, will.targetVelocityZMultiplier = tvx, tvz
	
	-- crouch has the same jump height as walk. TODO maybe leap forwards instead?
	will.targetVelocityYMultiplier = input.didFixedCommand("jump") and math.sqrt(run and 1 or 0.5) or 0
	will.targetVelocityThetaMultiplier = mdx
	will.targetVelocityPhiMultiplier = mdy
	
	if input.didFixedCommand("destroy") then
		will.destroy = true
	end
	
	if input.didFixedCommand("build") then
		will.build = true
	end
	
	return will
end

return getWill
