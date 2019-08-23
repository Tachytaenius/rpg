local detmath = require("lib.detmath")

local registry = {}

local terrainNames = {
	"soil"
}

registry.terrainByIndex = {}
registry.terrainByName = {}
for index, name in ipairs(terrainNames) do
	local newBlock = {index = index, name = name}
	for line in love.filesystem.lines("registry/terrain/" .. name) do
		if line[1] ~= "'" then -- Minimal comment functionality
			for word in line:gmatch("%S+") do
				
			end
		end
	end
	registry.terrainByIndex[index] = newBlock
	registry.terrainByName[name] = newBlock
end

registry.terrainCount = #registry.terrainByIndex




local entities = {}
registry.entities = entities

entities.testman = {
	diameter = 0.48, height = 1.65, mass = 60,
	fov = 90, eyeHeight = 1.58,
	abilities = {
		mobility = {
			ungroundedXChangeMultiplier = 0.2,
			ungroundedYChangeMultiplier = 0,
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
		
		stepUpRange = 0.5 -- TODO
	}
}



return registry
