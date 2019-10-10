local assets = require("assets")
local detmath = require("lib.detmath")

return {
	diameter = 0.48, height = 1.65, mass = 60,
	fov = 90, eyeHeight = 1.58,
	model = {
		mesh = assets.entities.testman.mesh,
		surfaceMap = assets.entities.testman.surfaceMap,
		albedoMap = assets.entities.testman.albedoMap,
		materialMap = assets.entities.testman.materialMap
	},
	abilities = {
		mobility = {
			ungroundedXChangeMultiplier = 0.2,
			ungroundedYChangeMultiplier = 0, -- No jumping in mid-air
			ungroundedZChangeMultiplier = 0.2,
			
			maximumTargetVelocity = {
				x = {
					negative = 6.3,
					positive = 6.3
				},
				y = {
					negative = 0,
					positive = 5.2
				},
				z = {
					negative = 6.6,
					positive = 5.8
				},
				theta = {
					negative = detmath.tau * 2,
					positive = detmath.tau * 2
				},
				phi = {
					negative = detmath.tau * 2,
					positive = detmath.tau * 2
				}
			},
			maximumAcceleration = {
				x = {
					negative = 6.3*2,
					positive = 6.3*2
				},
				y = {
					negative = 0,
					positive = math.huge
				},
				z = {
					negative = 6.6*2,
					positive = 5.8*2
				},
				theta = {
					negative = detmath.tau * 40,
					positive = detmath.tau * 40
				},
				phi = {
					negative = detmath.tau * 40,
					positive = detmath.tau * 40
				}
			},
			maximumDeceleration = {
				x = {
					negative = 6.3*2,
					positive = 6.3*2
				},
				y = {
					negative = 0,
					positive = 0,
				},
				z = {
					negative = 6.6*2,
					positive = 5.8*2
				},
				theta = {
					negative = detmath.tau * 40,
					positive = detmath.tau * 40
				},
				phi = {
					negative = detmath.tau * 40,
					positive = detmath.tau * 40
				}
			}
		},
		
		move = true,
		turn = true,
		
		stepUpRange = 0.5, -- TODO
		
		inventoryCapacity = {
			wield = true,
			general = 3,
		},
		
		reach = 2 -- metres
	}
}
