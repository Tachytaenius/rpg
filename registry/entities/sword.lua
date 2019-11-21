local assets = require("assets")

return {
	diameter = 0.025, height = 0.05,
	model = {
		mesh = assets.entities.sword.mesh,
		surfaceMap = assets.entities.sword.surfaceMap,
		diffuseMap = assets.entities.sword.diffuseMap,
		materialMap = assets.entities.sword.materialMap
	}
}
