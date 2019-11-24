local assets = require("assets")

return {
	diameter = 0.1, height = 0.5,
	model = {
		mesh = assets.entities.shotgun.mesh,
		surfaceMap = assets.entities.shotgun.surfaceMap,
		diffuseMap = assets.entities.shotgun.diffuseMap,
		materialMap = assets.entities.shotgun.materialMap
	}
}
