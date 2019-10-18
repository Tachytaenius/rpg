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

local makeSurfaceMap, makeMaterialMap
local function newContent(name, category)
	return {
		mesh = {load = function(self)
			self.value = loadObj("assets/meshes/" .. category .. "/" .. name .. ".obj")
		end},
		albedoMap = {load = function(self)
			self.value = love.graphics.newImage("assets/images/" .. category .. "/" .. name .. "/albedo.png")
		end},
		surfaceMap = {load = function(self)
			self.value = makeSurfaceMap("assets/images/" .. category .. "/" .. name .. "/normal.png", "assets/images/" .. category .. "/" .. name .. "/ambientIllumination.png")
		end},
		materialMap = {load = function(self)
			self.value = makeMaterialMap("assets/images/" .. category .. "/" .. name .. "/metalness.png", "assets/images/" .. category .. "/" .. name .. "/roughness.png", "assets/images/" .. category .. "/" .. name .. "/fresnel.png")
		end}
	}
end

local numTextures = 4 -- For terrain. Starts at 4 to take damage steps into account
for _, block in ipairs(registryTerrain.terrainByIndex) do
	numTextures = numTextures + (block.textures and #block.textures or (block.invisible and 0 or 1))
end

local assets = {
	terrain = {
		-- load is set at the bottom. it's too big
		u1s = {}, v1s = {}, u2s = {}, v2s = {}, albedoMap = {}, surfaceMap = {}, materialMap = {},
		constants = {
			blockTextureSize = 16, -- pixels
			numTextures = numTextures
		}
	},
	
	entities = {
		testman = newContent("testman", "entities")
	},
	
	items = {
		sword = newContent("sword", "items")
	},
	
	ui = {
		cursor = {load = function(self) self.value = love.graphics.newImage("assets/images/ui/cursor.png") end},
		font = {load = function(self) self.value = love.graphics.newImageFont("assets/images/ui/font.png", constants.fontString) end},
		crosshairs = {load = function(self) self.value = love.graphics.newImage("assets/images/ui/crosshairs.png") end}
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
	
	local geometry = {}
	local uv = not untextured and {}
	local normal = {}
	local outVerts = {}
	
	for line in love.filesystem.lines(path) do
		local item
		local isTri = false
		for word in line:gmatch("%S+") do
			if item then
				if isTri then
					local iterator = word:gmatch("%x+")
					local v = geometry[tonumber(iterator())]
					local vt1, vt2
					if untextured then
						vt1, vt2 = 0, 0
					else
						local vt = uv[tonumber(iterator())]
						vt1, vt2 = vt[1], vt[2]
					end
					local vn = normal[tonumber(iterator())]
					local vert = { -- see constants.vertexFormat
						v[1], v[2], v[3],
						vt1, 1 - vt2, -- Love --> OpenGL
						vn[1], vn[2], vn[3]
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
			else
				error("idk what \"" .. word .. "\" in \"" .. line .. "\" is, sry")
			end
		end
	end
	
	return love.graphics.newMesh(constants.vertexFormat, outVerts, "triangles")
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
local u1s, v1s, u2s, v2s, materialMap, surfaceMap, albedoMap = assets.terrain.u1s, assets.terrain.v1s, assets.terrain.u2s, assets.terrain.v2s, assets.terrain.materialMap, assets.terrain.surfaceMap, assets.terrain.albedoMap

function assets.terrain.load()
	local atlasWidth, atlasHeight = assets.terrain.constants.blockTextureSize, assets.terrain.constants.blockTextureSize * numTextures
	
	local metalnessAtlas = love.graphics.newCanvas(atlasWidth, atlasHeight)
	local roughnessAtlas = love.graphics.newCanvas(atlasWidth, atlasHeight)
	local fresnelAtlas = love.graphics.newCanvas(atlasWidth, atlasHeight)
	local normalAtlas = love.graphics.newCanvas(atlasWidth, atlasHeight)
	local ambientIlluminationAtlas = love.graphics.newCanvas(atlasWidth, atlasHeight)
	local albedoAtlas = love.graphics.newCanvas(atlasWidth, atlasHeight)
	
	local texturesSeen = 0
	for i = 0, 3 do -- 4 damage steps because 2 bits for damage in block metadata
		-- no need for local i = i
		local x, y = 0, (i - 1) * assets.terrain.constants.blockTextureSize
		texturesSeen = texturesSeen + 1
		drawTextureToAtlasses("damage/" .. i, metalnessAtlas, roughnessAtlas, fresnelAtlas, normalAtlas, ambientIlluminationAtlas, albedoAtlas, x, y)
	end
	for i, block in ipairs(registryTerrain.terrainByIndex) do
		-- no need for local i = i
		i = i + texturesSeen
		local blockName = block.name
		local x, y = 0, (i - 1) * assets.terrain.constants.blockTextureSize
		u1s[blockName] = x / atlasWidth
		v1s[blockName] = y / atlasHeight
		u2s[blockName] = (x + assets.terrain.constants.blockTextureSize) / atlasWidth
		v2s[blockName] = (y + assets.terrain.constants.blockTextureSize) / atlasHeight
		
		if block.textures then
			texturesSeen = texturesSeen + #block.textures
			for j, texture in ipairs(block.textures) do
				drawTextureToAtlasses(blockName .. "/" .. texture, metalnessAtlas, roughnessAtlas, fresnelAtlas, normalAtlas, ambientIlluminationAtlas, albedoAtlas, x, y + assets.terrain.constants.blockTextureSize * (j - 1))
			end
		else
			drawTextureToAtlasses(blockName, metalnessAtlas, roughnessAtlas, fresnelAtlas, normalAtlas, ambientIlluminationAtlas, albedoAtlas, x, y)
		end
	end
	love.graphics.setCanvas()
	
	local metalnessAtlas = metalnessAtlas:newImageData()
	local roughnessAtlas = roughnessAtlas:newImageData()
	local fresnelAtlas = fresnelAtlas:newImageData()
	local normalAtlas = normalAtlas:newImageData()
	local ambientIlluminationAtlas = ambientIlluminationAtlas:newImageData()
	local albedoAtlas = albedoAtlas:newImageData()
	
	materialMap.value = makeMaterialMap(metalnessAtlas, roughnessAtlas, fresnelAtlas, true)
	surfaceMap.value = makeSurfaceMap(normalAtlas, ambientIlluminationAtlas, true)
	albedoMap.value = love.graphics.newImage(albedoAtlas)
end

function drawTextureToAtlasses(location, ma, ra, fa, na, aia, aa, x, y)
	-- TODO: assert correct dimensions of each image
	love.graphics.setCanvas(ma)
	love.graphics.draw(love.graphics.newImage("assets/images/terrain/" .. location .. "/metalness.png"), x, y)
	love.graphics.setCanvas(ra)
	love.graphics.draw(love.graphics.newImage("assets/images/terrain/" .. location .. "/roughness.png"), x, y)
	love.graphics.setCanvas(fa)
	love.graphics.draw(love.graphics.newImage("assets/images/terrain/" .. location .. "/fresnel.png"), x, y)
	love.graphics.setCanvas(na)
	love.graphics.draw(love.graphics.newImage("assets/images/terrain/" .. location .. "/normal.png"), x, y)
	love.graphics.setCanvas(aia)
	love.graphics.draw(love.graphics.newImage("assets/images/terrain/" .. location .. "/ambientIllumination.png"), x, y)
	love.graphics.setCanvas(aa)
	love.graphics.draw(love.graphics.newImage("assets/images/terrain/" .. location .. "/albedo.png"), x, y)
end

return assets
