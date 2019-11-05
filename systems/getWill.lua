local input = require("systems.input")

local function getWill(mdx, mdy)
	-- Player version of "think", ie obeys commands
	local will = {}
	
	local sneak, run = input.didFixedCommand("sneak"), input.didFixedCommand("run")
	local advance, backpedal = input.didFixedCommand("advance"), input.didFixedCommand("backpedal")
	local strafeLeft, strafeRight = input.didFixedCommand("strafeLeft"), input.didFixedCommand("strafeRight")
	local tvx, tvz = 0, 0
	if advance then tvz = tvz - 1 end
	if backpedal then tvz = tvz + 1 end
	if strafeLeft then tvx = tvx - 1 end
	if strafeRight then tvx = tvx + 1 end
	will.targetVelocityXMultiplier, will.targetVelocityZMultiplier =
	tvx * (sneak and not run and 0.1 or run and not sneak and 1 or 0.5),
	tvz * (sneak and not run and 0.1 or run and not sneak and 1 or 0.5)
	
	-- Sneak and walk has half the jump height of run
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
