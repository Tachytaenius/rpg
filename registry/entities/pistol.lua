local assets = require("assets")

return {
	diameter = 0.025, height = 0.05,
	model = {
		mesh = assets.entities.pistol.mesh,
		surfaceMap = assets.entities.pistol.surfaceMap,
		diffuseMap = assets.entities.pistol.diffuseMap,
		materialMap = assets.entities.pistol.materialMap
	}
}
