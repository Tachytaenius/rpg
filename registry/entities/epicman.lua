local assets = require("assets")
local detmath = require("lib.detmath")

return {
	diameter = 1, height = 1, mass = 60,
	fov = 90, eyeHeight = 0.5, crouchLength = 0,
	model = {
		mesh = assets.entities.testman.mesh,
		surfaceMap = assets.entities.testman.surfaceMap,
		diffuseMap = assets.entities.testman.diffuseMap,
		materialMap = assets.entities.testman.materialMap
	},
	abilities = {
		mobility = {
			ungroundedXChangeMultiplier = 1,
			ungroundedYChangeMultiplier = 1,
			ungroundedZChangeMultiplier = 1,
			
			maximumTargetVelocity = {
				x = {
					negative = 6.3,
					positive = 6.3
				},
				y = {
					negative = 6.3,
					positive = 6.3
				},
				z = {
					negative = 6.3,
					positive = 6.3
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
					negative = 6.3*2,
					positive = 6.3*2
				},
				z = {
					negative = 6.3*2,
					positive = 6.3*2
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
					negative = 6.3*2,
					positive = 6.3*2,
				},
				z = {
					negative = 6.3*2,
					positive = 6.3*2
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
		
		crouch = true,
		
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
