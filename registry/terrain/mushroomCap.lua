local sideBits = require("constants").sideBits
local floor, ldexp = math.floor, math.ldexp

return {
	textures = {"skin", "flesh"},
	getTextureAtlasOffset = function(face, selfState, nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn)
		return floor(selfState / ldexp(0.5, -sideBits[face])) % 2
	end
}
