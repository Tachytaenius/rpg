-- TODO: Observer pattern instead of boxing

local constants = require("constants")
local registryTerrain = require("registry.terrainClone")

local loadObj
local function newMeshLoader(location)
	local path = "assets/meshes/" .. location .. ".obj"
	
	local asset = {}
	function asset:load()
		self.value = loadObj(path)
	end
	
	return asset
end

local function blankImage(r, g, b, a, w, h)
	local w = w or 1
	local h = w or h
	local ret = love.image.newImageData(w, h)
	ret:mapPixel(function()
		return r, g, b, a
	end)
	return love.graphics.newImage(ret)
end

local makeSurfaceMap, makeMaterialMap
local function entity(name, untextured)
	if untextured then
		return {
			mesh = {load = function(self)
				self.value, self.groups = loadObj("assets/meshes/entities/" .. name .. ".obj", true)
			end},
			diffuseMap = {load = function(self)
				self.value = blankImage(love.math.random()*0.5+0.25,love.math.random()*0.5+0.25,love.math.random()*0.5+0.25,1)
			end},
			surfaceMap = {load = function(self)
				self.value = blankImage(0.5, 0.5, 1, 1)
			end},
			materialMap = {load = function(self)
				self.value = blankImage(love.math.random(0,1),love.math.random(),love.math.random(),1)
			end}
		}
	else
		return {
			mesh = {load = function(self)
				self.value, self.groups = loadObj("assets/meshes/entities/" .. name .. ".obj")
			end},
			diffuseMap = {load = function(self)
				self.value = love.graphics.newImage("assets/images/entities/" .. name .. "/diffuse.png")
			end},
			surfaceMap = {load = function(self)
				self.value = makeSurfaceMap("assets/images/entities/" .. name .. "/normal.png", "assets/images/entities/" .. name .. "/ambientIllumination.png")
			end},
			materialMap = {load = function(self)
				self.value = makeMaterialMap("assets/images/entities/" .. name .. "/metalness.png", "assets/images/entities/" .. name .. "/roughness.png", "assets/images/entities/" .. name .. "/fresnel.png")
			end}
		}
	end
end

local numTextures = 0 -- For terrain.
for _, block in ipairs(registryTerrain.terrainByIndex) do
	numTextures = numTextures + (block.textures and #block.textures or (block.invisible and 0 or 1))
end

local assets = {
	terrain = {
		-- load is set at the bottom. it's too big
		diffuseMap = {}, surfaceMap = {}, materialMap = {},
		constants = {
			textureWidthMetres = 2,
			textureHeightMetres = 2,
			textureDepthMetres = 2,
			textureWidthPixels = 64,
			textureHeightPixels = 64,
			textureDepthPixels = 64,
			numTextures = numTextures
		},
		blockCursor = {}
	},
	
	entities = {
		testman = entity("testman")
	},
	
	ui = {
		cursor = {load = function(self) self.value = love.graphics.newImage("assets/images/ui/cursor.png") end},
		font = {load = function(self) self.value = love.graphics.newImageFont("assets/images/ui/font.png", constants.fontString) end},
		crosshairs = {load = function(self) self.value = love.graphics.newImage("assets/images/ui/crosshairs.png") end},
		trueButton = {load = function(self) self.value = blankImage(0.2, 0.8, 0.2, 1, 18) end},
		falseButton = {load = function(self) self.value = blankImage(0.8, 0.2, 0.2, 1, 18) end}
	}
}

local function traverse(start)
	for _, v in pairs(start) do
		if v.load then
			v:load()
		else
			traverse(v)
		end
	end
end

setmetatable(assets, {
	__call = function(assets, action)
		if action == "load" then
			traverse(assets)
		elseif action == "save" then
			-- TODO (make sure we can specify particular assets)
		else
			error("Assets is to be called with \"load\" or \"save\"")
		end
	end
})

function loadObj(path, untextured)
	-- TODO: Better
	
	local groups = {} -- Unhandled behaviour for going back to a group already defined
	local currentGroup
	local geometry = {}
	local uv = {}
	local normal = {}
	local outVerts = {}
	
	for line in love.filesystem.lines(path) do
		local item
		local isTri = false
		for word in line:gmatch("%S+") do
			if item then
				if item == "changingGroup" then
					currentGroup = currentGroup and currentGroup + 1 or 0
					groups[word] = currentGroup
				elseif isTri then
					local iterator = word:gmatch("%d+")
					local v = geometry[tonumber(iterator())]
					local vt1, vt2
					if untextured then
						vt1, vt2 = math.random(), 0
						iterator()
					else
						local vt = uv[tonumber(iterator())]
						vt1, vt2 = vt[1], vt[2]
					end
					local vn = normal[tonumber(iterator())]
					local vert = { -- see constants.vertexFormat
						v[1], v[2], v[3],
						vt1, 1 - vt2, -- Love --> OpenGL
						vn[1], vn[2], vn[3],
						currentGroup or 0
					}
					table.insert(outVerts, vert)
				else
					table.insert(item, tonumber(word))
				end
			elseif word == "#" then
				break
			elseif word == "s" then
				-- TODO
				break
			elseif word == "v" then
				item = {}
				table.insert(geometry, item)
			elseif word == "vt" then
				item = {}
				table.insert(uv, item)
			elseif word == "vn" then
				item = {}
				table.insert(normal, item)
			elseif word == "f" then
				item = {}
				isTri = true
			elseif word == "o" then
				item = "changingGroup"
			else
				error("idk what \"" .. word .. "\" in \"" .. line .. "\" is, sry")
			end
		end
	end
	if not currentGroup then
		groups.default = 0
	end
	return love.graphics.newMesh(constants.vertexFormat, outVerts, "triangles"), groups
end

function makeSurfaceMap(normalPath, ambientIlluminationPath, alreadyData)
	local normalData = alreadyData and normalPath or love.image.newImageData(normalPath)
	local ambientIlluminationData = alreadyData and ambientIlluminationPath or love.image.newImageData(ambientIlluminationPath)
	assert(normalData:getWidth() == ambientIlluminationData:getWidth() and normalData:getHeight() == ambientIlluminationData:getHeight(), (alreadyData and "normal's dimensions =/= ambient illumination" or (normalPath .. "'s dimensions =/= " .. ambientIlluminationPath)) .. "'s, can't make surface map")
	
	local surfaceMapData = love.image.newImageData(normalData:getDimensions())
	surfaceMapData:mapPixel(
		function(x, y)
			local normalX, normalY, normalZ = normalData:getPixel(x, y)
			local ambientIllumination = ambientIlluminationData:getPixel(x, y)
			
			return normalX, normalY, normalZ, ambientIllumination
		end
	)
	
	return surfaceMapData
end

function makeMaterialMap(metalnessPath, roughnessPath, fresnelPath, alreadyData)
	local metalnessData = alreadyData and metalnessPath or love.image.newImageData(metalnessPath)
	local roughnessData = alreadyData and roughnessPath or love.image.newImageData(roughnessPath)
	local fresnelData = alreadyData and fresnelPath or love.image.newImageData(fresnelPath)
	
	assert(metalnessData:getWidth() == roughnessData:getWidth() and roughnessData:getWidth() == fresnelData:getWidth() and metalnessData:getHeight() == roughnessData:getHeight() and roughnessData:getHeight() == fresnelData:getHeight(), (alreadyData and "metalness', roughness', and fresnel" or (metalnessPath .. "'s, " .. roughnessPath .. "'s, and " .. fresnelPath)) .. "'s dimensions aren't equal, can't make material map")
	
	local materialMapData = love.image.newImageData(metalnessData:getDimensions())
	materialMapData:mapPixel(
		function(x, y)
			local metalness = metalnessData:getPixel(x, y)
			local roughness = roughnessData:getPixel(x, y)
			local fresnel = fresnelData:getPixel(x, y)
			
			return metalness, roughness, fresnel, 1
		end
	)
	
	return materialMapData
end

local drawTextureToAtlasses
local materialMap, surfaceMap, diffuseMap = assets.terrain.materialMap, assets.terrain.surfaceMap, assets.terrain.diffuseMap

local function makeCanvasses()
	local ret = {}
	for z = 0, assets.terrain.constants.textureDepthPixels - 1 do
		ret[z+1] = love.graphics.newCanvas(assets.terrain.constants.textureWidthPixels, assets.terrain.constants.textureHeightPixels * numTextures)
	end
	return ret
end

function assets.terrain.load()
	local metalnessAtlasSlices = makeCanvasses()
	local roughnessAtlasSlices = makeCanvasses()
	local fresnelAtlasSlices = makeCanvasses()
	local normalAtlasSlices = makeCanvasses()
	local ambientIlluminationAtlasSlices = makeCanvasses()
	local diffuseAtlasSlices = makeCanvasses()
	
	for i, block in ipairs(registryTerrain.terrainByIndex) do
		local blockName = block.name
		local x, y = 0, (i - 1) * assets.terrain.constants.textureHeightPixels
		for z = 0, assets.terrain.constants.textureDepthPixels - 1 do
			drawTextureToAtlasses(x, y, z, blockName, normalAtlasSlices[z+1], ambientIlluminationAtlasSlices[z+1], diffuseAtlasSlices[z+1], metalnessAtlasSlices[z+1], roughnessAtlasSlices[z+1], fresnelAtlasSlices[z+1])
		end
		break
	end
	love.graphics.setCanvas()
	
	for z = 0, assets.terrain.constants.textureDepthPixels - 1 do
		metalnessAtlasSlices[z+1] = metalnessAtlasSlices[z+1]:newImageData()
		roughnessAtlasSlices[z+1] = roughnessAtlasSlices[z+1]:newImageData()
		fresnelAtlasSlices[z+1] = fresnelAtlasSlices[z+1]:newImageData()
		normalAtlasSlices[z+1] = normalAtlasSlices[z+1]:newImageData()
		ambientIlluminationAtlasSlices[z+1] = ambientIlluminationAtlasSlices[z+1]:newImageData()
		diffuseAtlasSlices[z+1] = diffuseAtlasSlices[z+1]:newImageData()
	end
	
	local materialAtlasSlices = {}
	local surfaceMapAtlasSlices = {}
	for z = 0, assets.terrain.constants.textureDepthPixels - 1 do
		materialAtlasSlices[z+1] = makeMaterialMap(metalnessAtlasSlices[z+1], roughnessAtlasSlices[z+1], fresnelAtlasSlices[z+1], true)
		surfaceMapAtlasSlices[z+1] = makeSurfaceMap(normalAtlasSlices[z+1], ambientIlluminationAtlasSlices[z+1], true)
	end
	materialMap.value = love.graphics.newVolumeImage(materialAtlasSlices)
	surfaceMap.value = love.graphics.newVolumeImage(surfaceMapAtlasSlices)
	diffuseMap.value = love.graphics.newVolumeImage(diffuseAtlasSlices)
	
	local format = {
		{"VertexPosition", "float", 3}
	}
	
	local w, h, d, pad = constants.blockWidth, constants.blockHeight, constants.blockDepth, constants.blockCursorPadding
	local vertices = {
		{-pad, -pad, -pad}, {-pad, -pad, -pad}, {w+pad, -pad, -pad},
		{w+pad, -pad, -pad}, {w+pad, -pad, -pad}, {w+pad, -pad, d+pad},
		{w+pad, -pad, d+pad}, {w+pad, -pad, d+pad}, {-pad, -pad, d+pad},
		{-pad, -pad, d+pad}, {-pad, -pad, d+pad}, {-pad, -pad, -pad},
		
		{-pad, h+pad, -pad}, {-pad, h+pad, -pad}, {w+pad, h+pad, -pad},
		{w+pad, h+pad, -pad}, {w+pad, h+pad, -pad}, {w+pad, h+pad, d+pad},
		{w+pad, h+pad, d+pad},{w+pad, h+pad, d+pad}, {-pad, h+pad, d+pad},
		{-pad, h+pad, d+pad}, {-pad, h+pad, d+pad}, {-pad, h+pad, -pad},
		
		{-pad, -pad, -pad}, {-pad, -pad, -pad}, {-pad, h+pad, -pad},
		{-pad, -pad, d+pad}, {-pad, -pad, d+pad}, {-pad, h+pad, d+pad},
		{w+pad, -pad, -pad}, {w+pad, -pad, -pad}, {w+pad, h+pad, -pad},
		{w+pad, -pad, d+pad}, {w+pad, -pad, d+pad}, {w+pad, h+pad, d+pad}
	}
	
	assets.terrain.blockCursor.value = love.graphics.newMesh(format, vertices, "triangles")
end

function drawTextureToAtlasses(x, y, z, name, na, aia, da, ma, ra, fa)
	local ni, aii, di, mi, ri, fi
	if love.filesystem.getInfo("assets/images/terrain/" .. name .. ".lua") then
		local blockTextureGenerators = require("assets.images.terrain." .. name)
		
		-- To make them easier to program
		blockTextureGenerators.wp = assets.terrain.constants.textureWidthPixels
		blockTextureGenerators.hp = assets.terrain.constants.textureHeightPixels
		blockTextureGenerators.dp = assets.terrain.constants.textureDepthPixels
		blockTextureGenerators.wm = assets.terrain.constants.textureWidthMetres
		blockTextureGenerators.hm = assets.terrain.constants.textureHeightMetres
		blockTextureGenerators.dm = assets.terrain.constants.textureDepthMetres
		
		local nid = love.image.newImageData(assets.terrain.constants.textureWidthPixels, assets.terrain.constants.textureHeightPixels)
		local aiid = love.image.newImageData(assets.terrain.constants.textureWidthPixels, assets.terrain.constants.textureHeightPixels)
		local did = love.image.newImageData(assets.terrain.constants.textureWidthPixels, assets.terrain.constants.textureHeightPixels)
		local mid = love.image.newImageData(assets.terrain.constants.textureWidthPixels, assets.terrain.constants.textureHeightPixels)
		local rid = love.image.newImageData(assets.terrain.constants.textureWidthPixels, assets.terrain.constants.textureHeightPixels)
		local fid = love.image.newImageData(assets.terrain.constants.textureWidthPixels, assets.terrain.constants.textureHeightPixels)
		
		nid:mapPixel(
			function(x, y)
				local x, y, z = blockTextureGenerators.normal(x / assets.terrain.constants.textureWidthPixels, y / assets.terrain.constants.textureHeightPixels, z / assets.terrain.constants.textureDepthPixels)
				return x, y, z, 1
			end
		)
		aiid:mapPixel(
			function(x, y)
				local ai = blockTextureGenerators.ambientIllumination(x / assets.terrain.constants.textureWidthPixels, y / assets.terrain.constants.textureHeightPixels, z / assets.terrain.constants.textureDepthPixels)
				return ai, ai, ai, 1
			end
		)
		did:mapPixel(
			function(x, y)
				local r, g, b = blockTextureGenerators.diffuse(x / assets.terrain.constants.textureWidthPixels, y / assets.terrain.constants.textureHeightPixels, z / assets.terrain.constants.textureDepthPixels)
				return r, g, b, 1
			end
		)
		mid:mapPixel(
			function(x, y)
				local m = blockTextureGenerators.metalness(x / assets.terrain.constants.textureWidthPixels, y / assets.terrain.constants.textureHeightPixels, z / assets.terrain.constants.textureDepthPixels)
				return m, m, m, 1
			end
		)
		rid:mapPixel(
			function(x, y)
				local r = blockTextureGenerators.roughness(x / assets.terrain.constants.textureWidthPixels, y / assets.terrain.constants.textureHeightPixels, z / assets.terrain.constants.textureDepthPixels)
				return r, r, r, 1
			end
		)
		fid:mapPixel(
			function(x, y)
				local f = blockTextureGenerators.fresnel(x / assets.terrain.constants.textureWidthPixels, y / assets.terrain.constants.textureHeightPixels, z / assets.terrain.constants.textureDepthPixels)
				return f, f, f, 1
			end
		)
		
		ni = love.graphics.newImage(nid)
		aii = love.graphics.newImage(aiid)
		di = love.graphics.newImage(did)
		mi = love.graphics.newImage(mid)
		ri = love.graphics.newImage(rid)
		fi = love.graphics.newImage(fid)
	else
		ni = love.graphics.newImage("assets/images/terrain/" .. name .. "/" .. z .. "/normal.png")
		aii = love.graphics.newImage("assets/images/terrain/" .. name .. "/" .. z .. "/ambientIllumination.png")
		di = love.graphics.newImage("assets/images/terrain/" .. name .. "/" .. z .. "/diffuse.png")
		mi = love.graphics.newImage("assets/images/terrain/" .. name .. "/" .. z .. "/metalness.png")
		ri = love.graphics.newImage("assets/images/terrain/" .. name .. "/" .. z .. "/roughness.png")
		fi = love.graphics.newImage("assets/images/terrain/" .. name .. "/" .. z .. "/fresnel.png")
	end
	
	love.graphics.setCanvas(na)
	love.graphics.draw(ni, x, y)
	love.graphics.setCanvas(aia)
	love.graphics.draw(aii, x, y)
	love.graphics.setCanvas(da)
	love.graphics.draw(di, x, y)
	love.graphics.setCanvas(ma)
	love.graphics.draw(mi, x, y)
	love.graphics.setCanvas(ra)
	love.graphics.draw(ri, x, y)
	love.graphics.setCanvas(fa)
	love.graphics.draw(fi, x, y)
end

return assets
