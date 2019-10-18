local registryTerrain = require("registry.terrainClone")

return {
	textures = {"top", "bottom", "sides"},
	getTextureAtlasOffset = function(face, selfState, nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn)
		if face == "py" then
			return 0 -- top
		elseif face == "ny" then
			return 1 -- bottom
		else
			if face == "px" and registryTerrain.terrainByIndex[pnz].name == "grass" or
				face == "nx" and registryTerrain.terrainByIndex[nnz].name == "grass" or
				face == "pz" and registryTerrain.terrainByIndex[znp].name == "grass" or
				face == "nz" and registryTerrain.terrainByIndex[znn].name == "grass" then
					return 0
			else
				return 2 -- sides
			end
		end
	end
}
