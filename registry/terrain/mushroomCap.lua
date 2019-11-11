local sideBits = {
	px = 0,
	nx = 1,
	py = 2,
	ny = 3,
	pz = 4,
	nz = 5
}

return {
	textures = {"skin", "flesh"},
	getTextureAtlasOffset = function(face, selfState, nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn)
		return math.floor(selfState / 2 ^ sideBits[face]) % 2
	end
}
