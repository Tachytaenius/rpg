local assets = require("assets")
local cpml = require("lib.cpml")

return {
	diameter = 0.025, height = 0.05,
	model = {
		mesh = assets.entities.pistol.mesh,
		surfaceMap = assets.entities.pistol.surfaceMap,
		diffuseMap = assets.entities.pistol.diffuseMap,
		materialMap = assets.entities.pistol.materialMap,
		
		getTransform = function(entity, group, transform, x, y, z, w, h, d, theta, phi)
			if group == "main" then
				transform:translate(transform, cpml.vec3(x+w/2, y, z+d/2))
				transform:rotate(transform, -theta - math.pi, cpml.vec3.unit_y)
				transform:rotate(transform, phi, cpml.vec3.unit_x)
			elseif group == "slide" then
				transform:translate(transform, cpml.vec3(x+w/2, y, z+d/2 + math.random() * 0.06))
				transform:rotate(transform, -theta - math.pi, cpml.vec3.unit_y)
				transform:rotate(transform, phi, cpml.vec3.unit_x)
			end
		end
	}
}
