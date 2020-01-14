local sideBits = require("constants").sideBits
local floor = math.floor

local t = {[0]=1,2,4,8,16,32,64,128,256} --FUD FUD FUD FUD TODO
local function twoToThe(x) --- FUD FUD FUD FUD FUD FUD FUD TEMP
	return t[x] -- FUD FUD FUD FUD FUD FUD FUD FUD FUD FUD NOTE: FUD
end -- FUD FUD FUD FUD FUD FUD FUD FUD FUD FUD FUD FUD FUD FIXME

return {
	textures = {"skin", "flesh"},
	getTextureAtlasOffset = function(face, selfState, nzz, pzz, znz, zpz, zzn, zzp, nnz, pnz, npz, ppz, nzn, pzn, nzp, pzp, zpp, zpn, znp, znn)
		return floor(selfState / twoToThe(sideBits[face])) % 2
	end
}
