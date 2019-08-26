local constants = require("constants")

local loadObj
local function newMeshLoader(location)
	local path = "assets/meshes/" .. location .. ".obj"
	
	local asset = {}
	function asset:load()
		self.value = loadObj(path)
	end
	
	return asset
end

local makeSurfaceMap

local assets = {
	terrain = {
		albedoMap = {load = function(self)
			self.value = love.graphics.newImage("assets/images/terrain/tmpdifatlas.png")
		end},
		surfaceMap = {load = function(self)
			self.value = love.graphics.newImage("assets/images/terrain/tmpnrmatlas.png")
		end},
		materialMap = {load = function(self)
			self.value = love.graphics.newImage("assets/images/terrain/tmppbratlas.png")
		end}
	},
	
	
	
	entities = {
		testman = {
			mesh = {load = function(self)
				self.value = loadObj("assets/meshes/entities/testman.obj")
			end},
			albedoMap = {load = function(self)
				self.value = love.graphics.newImage("assets/images/entities/testman/albedo.png")
			end},
			surfaceMap = {load = function(self)
				self.value = makeSurfaceMap("assets/images/entities/testman/normal.png", "assets/images/entities/testman/ambientIllumination.png")
			end},
			materialMap = {load = function(self)
				self.value = makeMaterialMap("assets/images/entities/testman/metalness.png", "assets/images/entities/testman/roughness.png", "assets/images/entities/testman/fresnel.png")
			end}
		}
	},
	
	
	
	ui = {
		cursor = {load = function(self) self.value = love.graphics.newImage("assets/images/ui/cursor.png") end},
		font = {load = function(self) self.value = love.graphics.newImageFont("assets/images/ui/font.png", constants.fontString) end}
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

function makeSurfaceMap(normalPath, ambientIlluminationPath)
	local normalData = love.image.newImageData(normalPath)
	local ambientIlluminationData = love.image.newImageData(ambientIlluminationPath)
	assert(normalData:getWidth() == ambientIlluminationData:getWidth() and normalData:getHeight() == ambientIlluminationData:getHeight(), normalPath .. "'s' dimensions =/= " .. ambientIlluminationPath .. "'s, can't make surface map")
	
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

function makeMaterialMap(metalnessPath, roughnessPath, fresnelPath)
	local metalnessData = love.image.newImageData(metalnessPath)
	local roughnessData = love.image.newImageData(roughnessPath)
	local fresnelData = love.image.newImageData(fresnelPath)
	
	assert(metalnessData:getWidth() == roughnessData:getWidth() and roughnessData:getWidth() == fresnelData:getWidth() and metalnessData:getHeight() == roughnessData:getHeight() and roughnessData:getHeight() == fresnelData:getHeight(), metalnessPath .. "'s, " .. roughnessPath .. "'s, and " .. fresnelPath .. "'s dimensions aren't equal, can't make material map")
	
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

return assets
