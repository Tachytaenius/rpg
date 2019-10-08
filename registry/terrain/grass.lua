local registryTerrain = require("registry.terrainClone")

return {
	textures = {"top", "bottom", "sides"},
	getTextureAtlasOffset = function(face, neighbourAbove, neighbourBelow, neighbourLeft, neighbourRight, neighbourOutAbove, neighbourOutBelow, neighbourOutLeft, neighbourOutRight)
		if face == "py" or registryTerrain.terrainByIndex[neighbourOutBelow].name == "grass" then
			return 0 -- top
		elseif face == "ny" then
			return 1 -- bottom
		else
			return 2 -- sides
		end
	end
}
