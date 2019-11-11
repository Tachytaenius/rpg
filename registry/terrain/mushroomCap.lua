local sideBits = require("constants").sideBits

return {
	textures = {"skin", "flesh"},
	getTextureAtlasOffset = function(face, selfState, nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn)
		return math.floor(selfState / 2 ^ sideBits[face]) % 2
	end
}
