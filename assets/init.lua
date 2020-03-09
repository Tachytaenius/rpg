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

local numTextures = 4 -- For terrain. Starts at 4 to take damage steps into account
for _, block in ipairs(registryTerrain.terrainByIndex) do
	numTextures = numTextures + (block.textures and #block.textures or (block.invisible and 0 or 1))
end

local assets = {
	terrain = {
		-- load is set at the bottom. it's too big
		u1s = {}, v1s = {}, u2s = {}, v2s = {}, diffuseMap = {}, surfaceMap = {}, materialMap = {},
		constants = {
			blockTextureSize = 16, -- pixels
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
	
	return love.graphics.newImage(surfaceMapData)
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
	
	return love.graphics.newImage(materialMapData)
end

local drawTextureToAtlasses
local u1s, v1s, u2s, v2s, materialMap, surfaceMap, diffuseMap = assets.terrain.u1s, assets.terrain.v1s, assets.terrain.u2s, assets.terrain.v2s, assets.terrain.materialMap, assets.terrain.surfaceMap, assets.terrain.diffuseMap

function assets.terrain.load()
	local atlasWidth, atlasHeight = assets.terrain.constants.blockTextureSize, assets.terrain.constants.blockTextureSize * numTextures
	
	local metalnessAtlas = love.graphics.newCanvas(atlasWidth, atlasHeight)
	local roughnessAtlas = love.graphics.newCanvas(atlasWidth, atlasHeight)
	local fresnelAtlas = love.graphics.newCanvas(atlasWidth, atlasHeight)
	local normalAtlas = love.graphics.newCanvas(atlasWidth, atlasHeight)
	local ambientIlluminationAtlas = love.graphics.newCanvas(atlasWidth, atlasHeight)
	local diffuseAtlas = love.graphics.newCanvas(atlasWidth, atlasHeight)
	
	for i = 1, 3 do -- 4 damage steps because 2 bits for damage in block metadata
		local x, y = 0, i * assets.terrain.constants.blockTextureSize
		drawTextureToAtlasses(x, y, "damage/" .. i, true, normalAtlas, ambientIlluminationAtlas, diffuseAtlas, metalnessAtlas, roughnessAtlas, fresnelAtlas)
	end
	local extraTexturesSeen = 0
	for i, block in ipairs(registryTerrain.terrainByIndex) do
		-- no need for local i = i
		i = i + extraTexturesSeen + 4 -- damage steps
		local blockName = block.name
		local x, y = 0, (i - 1) * assets.terrain.constants.blockTextureSize
		u1s[blockName] = x / atlasWidth
		v1s[blockName] = y / atlasHeight
		u2s[blockName] = (x + assets.terrain.constants.blockTextureSize) / atlasWidth
		v2s[blockName] = (y + assets.terrain.constants.blockTextureSize) / atlasHeight
		
		if block.textures then
			extraTexturesSeen = extraTexturesSeen + #block.textures - 1
			for j, texture in ipairs(block.textures) do
				drawTextureToAtlasses(x, y + assets.terrain.constants.blockTextureSize * (j - 1), blockName .. "/" .. texture, false, normalAtlas, ambientIlluminationAtlas, diffuseAtlas, metalnessAtlas, roughnessAtlas, fresnelAtlas)
			end
		else
			drawTextureToAtlasses(x, y, blockName, false, normalAtlas, ambientIlluminationAtlas, diffuseAtlas, metalnessAtlas, roughnessAtlas, fresnelAtlas)
		end
	end
	love.graphics.setCanvas()
	
	local metalnessAtlas = metalnessAtlas:newImageData()
	local roughnessAtlas = roughnessAtlas:newImageData()
	local fresnelAtlas = fresnelAtlas:newImageData()
	local normalAtlas = normalAtlas:newImageData()
	local ambientIlluminationAtlas = ambientIlluminationAtlas:newImageData()
	local diffuseAtlas = diffuseAtlas:newImageData()
	
	materialMap.value = makeMaterialMap(metalnessAtlas, roughnessAtlas, fresnelAtlas, true)
	surfaceMap.value = makeSurfaceMap(normalAtlas, ambientIlluminationAtlas, true)
	diffuseMap.value = love.graphics.newImage(diffuseAtlas)
	
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

local drawAlphaShader = love.graphics.newShader[[
	vec4 effect(vec4 colour, Image image, vec2 textureCoords, vec2 windowCoords) {
		return vec4(vec3(Texel(image, textureCoords).a), 1);
	}
]]

function drawTextureToAtlasses(x, y, location, isDamage, na, aia, aa, ma, ra, fa)
	-- TODO: assert correct dimensions of each image
	local ni = love.graphics.newImage("assets/images/terrain/" .. location .. "/normal.png")
	local aii = love.graphics.newImage("assets/images/terrain/" .. location .. "/ambientIllumination.png")
	local ai = love.graphics.newImage("assets/images/terrain/" .. location .. "/diffuse.png")
	
	love.graphics.setCanvas(na)
	love.graphics.draw(ni, x, y)
	love.graphics.setCanvas(aia)
	love.graphics.draw(aii, x, y)
	love.graphics.setCanvas(aa)
	love.graphics.draw(ai, x, y)
	
	if isDamage then
		love.graphics.setShader(drawAlphaShader)
		love.graphics.setCanvas(ma)
		love.graphics.draw(ni, x, y)
		love.graphics.setCanvas(ra)
		love.graphics.draw(aii, x, y)
		love.graphics.setShader()
	else
		love.graphics.setCanvas(ma)
		love.graphics.draw(love.graphics.newImage("assets/images/terrain/" .. location .. "/metalness.png"), x, y)
		love.graphics.setCanvas(ra)
		love.graphics.draw(love.graphics.newImage("assets/images/terrain/" .. location .. "/roughness.png"), x, y)
		love.graphics.setCanvas(fa)
		love.graphics.draw(love.graphics.newImage("assets/images/terrain/" .. location .. "/fresnel.png"), x, y)
	end
end

return assets
