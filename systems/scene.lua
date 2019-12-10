local constants, assets, settings =
	require("constants"),
	require("assets"),
	require("systems.settings")
local list, cpml =
	require("lib.list"),
	require("lib.cpml")

local scene = {}

local gBufferShader, shadowShader, lightingShader, postShader, blockCursorShader
local gBufferSetup, positionBuffer, surfaceBuffer, diffuseBuffer, materialBuffer, depthBuffer
local shadowMapSetup, shadowMap
local lightCanvas
local dummy -- For using light shader

function scene.init()
	dummy = love.graphics.newImage(love.image.newImageData(1, 1))
	
	positionBuffer = love.graphics.newCanvas(constants.width, constants.height, {format = "rgba16f"})
	surfaceBuffer = love.graphics.newCanvas(constants.width, constants.height, {format = "rgba16f"})
	diffuseBuffer = love.graphics.newCanvas(constants.width, constants.height)
	materialBuffer = love.graphics.newCanvas(constants.width, constants.height)
	depthBuffer = love.graphics.newCanvas(constants.width, constants.height, {format = "depth32f"})
	gBufferSetup = {
		positionBuffer, surfaceBuffer, diffuseBuffer, materialBuffer,
		depthstencil = depthBuffer
	}
	
	shadowMap = love.graphics.newCanvas(constants.shadowMapSize, constants.shadowMapSize, {format = "depth32f", readable = true})
	shadowMapSetup = {
		depthstencil = shadowMap
	}
	
	lightCanvas = love.graphics.newCanvas(constants.width, constants.height)
	scene.outputCanvas = love.graphics.newCanvas(constants.width, constants.height)
	
	gBufferShader = love.graphics.newShader("shaders/gBuffer.glsl")
	shadowShader = love.graphics.newShader("shaders/shadow.glsl")
	lightingShader = love.graphics.newShader("shaders/lighting.glsl")
	postShader = love.graphics.newShader("shaders/post.glsl")
	blockCursorShader = love.graphics.newShader("shaders/blockCursor.glsl")
	
	gBufferShader:send("damageOverlayVLength", 1 / assets.terrain.constants.numTextures)
	lightingShader:send("nearPlane", constants.lightNearPlane) -- For getting values out of the shadow map depth buffer
	lightingShader:send("windowSize", {constants.width, constants.height})
	lightingShader:send("maximumBias", constants.maxShadowBias)
	lightingShader:send("minimumBias", constants.minShadowBias)
	-- TEMP: The magic numbers won't stay, I promise (solution: weather system)
	postShader:send("skyColour", {0.3, 0.4, 0.5})
	postShader:send("fogRadius", 25)
	postShader:send("fogStart", 0.6)
	
	scene.chunksToDraw = list.new()
	scene.entitiesToDraw = list.new()
	scene.camera = {near = 0.0001, far = 30}
end

local getCameraTransform, renderGBuffer, sendGBufferToLightingShader, finishingTouches

function scene.render(world)
	renderGBuffer(world)
	sendGBufferToLightingShader()
	renderLights(world)
	finishingTouches() -- reset blend mode, draw lightCanvas to scene.outputCanvas with post shader, and finally unset shader and canvas
end

function getCameraTransform(camera, isLight)
	local ret = cpml.mat4.new()
	
	ret:scale(ret, cpml.vec3(1, -1, 1)) -- +y = up (best for visualising world) --> +y = down (what love does)
	
	ret:rotate(ret, camera.angle.x, cpml.vec3.unit_x)
	ret:rotate(ret, camera.angle.y, cpml.vec3.unit_y)
	ret:rotate(ret, camera.angle.z, cpml.vec3.unit_z)
	ret:translate(ret, -camera.pos)
	
	local perspective = cpml.mat4.from_perspective(camera.fov, isLight and 1 or constants.width / constants.height, camera.near, camera.far)
	
	
	return perspective:transpose(perspective) * ret:transpose(ret)
end

local renderObjects

function renderGBuffer(world)
	love.graphics.setBlendMode("replace", "premultiplied")
	love.graphics.setShader(gBufferShader)
	gBufferShader:send("view", getCameraTransform(scene.camera))
	gBufferShader:send("viewPosition", {scene.camera.pos:unpack()})
	love.graphics.setCanvas(gBufferSetup)
	love.graphics.clear()
	renderObjects(world)
end

function sendGBufferToLightingShader()
	lightingShader:send("positionBuffer", positionBuffer)
	lightingShader:send("surfaceBuffer", surfaceBuffer)
	lightingShader:send("diffuseBuffer", diffuseBuffer)
	lightingShader:send("materialBuffer", materialBuffer)
	lightingShader:send("viewPosition", {scene.camera.pos:unpack()})
end

function renderObjects(world)
	local cx, cy
	if love.graphics.getShader() == shadowShader then
		cx, cy = constants.shadowMapSize / 2, constants.shadowMapSize / 2
	else
		cx, cy = constants.width/2, constants.height/2
	end
	
	local currentShader = love.graphics.getShader()
	local chunkTransform = cpml.mat4.identity()
	currentShader:send("modelMatrices", chunkTransform) -- or lack thereof
	
	-- Chunks
	if currentShader == gBufferShader then
		gBufferShader:send("modelMatrixInverses", chunkTransform)
		gBufferShader:send("damageOverlays", true)
		gBufferShader:send("surfaceMap", assets.terrain.surfaceMap.value)
		gBufferShader:send("diffuseMap", assets.terrain.diffuseMap.value)
		gBufferShader:send("materialMap", assets.terrain.materialMap.value)
	end
	for i = 1, scene.chunksToDraw.size do
		local mesh = scene.chunksToDraw:get(i).mesh
		if mesh then
			love.graphics.draw(mesh, cx, cy)
		end
	end
	
	if currentShader == gBufferShader then
		gBufferShader:send("damageOverlays", false)
	end
	
	-- Entities
	for i = 1, scene.entitiesToDraw.size do
		local entity = scene.entitiesToDraw:get(i)
		local model = entity.model
		if model then
			currentShader:send("modelMatrices", unpack(model.transforms))
			
			if currentShader == gBufferShader then
				gBufferShader:send("modelMatrixInverses", unpack(model.inverseTransforms))
				gBufferShader:send("surfaceMap", model.surfaceMap.value)
				gBufferShader:send("diffuseMap", model.diffuseMap.value)
				gBufferShader:send("materialMap", model.materialMap.value)
			end
			
			love.graphics.draw(model.mesh.value, cx, cy)
		end
	end
end

function renderLights(world)
	lightingShader:send("ambience", 0.25) -- TODO: not out of *closed environments* though, surely
	love.graphics.setBlendMode("add")
	love.graphics.setCanvas(lightCanvas)
	love.graphics.clear(0, 0, 0, 1)
	
	for i = 1, world.lights.size do
		local light = world.lights:get(i)
		
		local viewMatrix
		
		if light.isDirectional then
			lightingShader:send("pointLight", false)
			lightingShader:send("lightPosition", light.angle)
		else
			-- viewMatrix = getCameraTransform(idk, true)
			lightingShader:send("pointLight", true)
			lightingShader:send("lightPosition", light.position)
		end
		
		lightingShader:send("lightColour", light.colour)
		lightingShader:send("lightStrength", light.strength)
		lightingShader:send("viewPosition", {scene.camera.pos:unpack()})
		
		-- shadowShader:send("view", viewMatrix)
		-- love.graphics.setCanvas(shadowMapSetup)
		-- love.graphics.clear()
		-- love.graphics.setShader(shadowShader)
		-- renderObjects()
		-- 
		-- lightingShader:send("lightView", viewMatrix)
		-- lightingShader:send("shadowMap", shadowMap)
		love.graphics.setShader(lightingShader)
		love.graphics.setCanvas(lightCanvas)
		
		-- TODO
		local lightInfluenceX, lightInfluenceY, lightInfluenceW, lightInfluenceH = 0, 0, constants.width, constants.height
		love.graphics.draw(dummy, lightInfluenceX, lightInfluenceY, 0, lightInfluenceW, lightInfluenceH)
	end
end

function finishingTouches()
	love.graphics.setBlendMode("alpha", "alphamultiply")
	love.graphics.setCanvas(scene.outputCanvas)
	love.graphics.setShader(postShader)
	postShader:send("positionBuffer", positionBuffer)
	postShader:send("viewPosition", {scene.camera.pos:unpack()})
	love.graphics.draw(lightCanvas)
	love.graphics.setCanvas()
	love.graphics.setShader()
end

-- "Spatials" is a stupid (TODO) way to say position, size, rotation, et cetera
local function getEntitySpatials(bumpWorld, entity, lerp)
	local x, y, z, w, h, d, theta, phi
	
	x, y, z, w, h, d = bumpWorld:getCube(entity)
	if lerp then
		x, y, z, w, h, d, theta, phi =
			(1 - lerp) * entity.px + lerp * x,
			(1 - lerp) * entity.py + lerp * y,
			(1 - lerp) * entity.pz + lerp * z,
			(1 - lerp) * entity.pw + lerp * w,
			(1 - lerp) * entity.ph + lerp * h,
			(1 - lerp) * entity.pd + lerp * d,
			(1 - lerp) * entity.ptheta + lerp * entity.preModuloTheta,
			(1 - lerp) * entity.pphi + lerp * entity.phi
	else
		theta, phi =
			entity.preModuloTheta,
			entity.phi
	end
	return x, y, z, w, h, d, theta, phi
end

function scene.setTransforms(world, lerp)
	local bumpWorld = world.bumpWorld
	local entitiesToDraw = scene.entitiesToDraw
	
	for i = 1, entitiesToDraw.size do
		local entity = entitiesToDraw:get(i)
		local model = entity.model
		model.transforms = model.transforms or {}
		model.inverseTransforms = model.inverseTransforms or {}
		
		if model then
			local x, y, z, w, h, d, theta, phi = getEntitySpatials(bumpWorld, entity, lerp)
			for group, id in pairs(model.mesh.groups) do
				local transform = cpml.mat4.identity()
				
				if model.getTransform then
					model.getTransform(entity, group, transform, x, y, z, w, h, d, theta, phi)
				else
					-- local verticalHeight = entity.eyeHeight and (h + entity.eyeHeight - entity.height) or d/2
					transform:translate(transform, cpml.vec3(x+w/2, y, z+d/2))
					transform:rotate(transform, -theta - math.pi, cpml.vec3.unit_y)
					transform:rotate(transform, phi, cpml.vec3.unit_x)
				end
				
				transform = transform:transpose(transform)
				model.transforms[id + 1] = transform
				
				local inverse = cpml.mat4.invert(cpml.mat4.new(), transform)
				model.inverseTransforms[id + 1] = inverse:transpose(inverse)
			end
		end
	end
	
	if scene.cameraEntity then
		local x, y, z, w, h, d, theta, phi = getEntitySpatials(bumpWorld, scene.cameraEntity, lerp)
		-- TODO: allow lerping of all attributes
		
		local eyeToTopOfBox = scene.cameraEntity.height - scene.cameraEntity.eyeHeight
		local lerpdEyeHeight = h - eyeToTopOfBox
		
		scene.camera.fov = scene.cameraEntity.fov
		scene.camera.pos = cpml.vec3(x + w / 2, y + lerpdEyeHeight, z + d / 2)
		scene.camera.angle = cpml.vec3(phi, theta, 0)
	end
end

local bhDecode = require("systems.blockHash").decode
local bw, bh, bd = constants.blockWidth, constants.blockHeight, constants.blockDepth
local cw, ch, cd = constants.chunkWidth, constants.chunkHeight, constants.chunkDepth

local function notCameraEntityFilter(item)
	return item ~= scene.cameraEntity
end

function scene.drawBlockCursor(world, lerp)
	if not scene.cameraEntity then return end
	
	local x, y, z, w, h, d, theta, phi = getEntitySpatials(world.bumpWorld, scene.cameraEntity, lerp)
	
	local eyeToTopOfBox = scene.cameraEntity.height - scene.cameraEntity.eyeHeight
	local lerpdEyeHeight = h - eyeToTopOfBox
	
	local x1, y1, z1 = x + w / 2, y + lerpdEyeHeight, z + d / 2
	local dx, dy, dz =
		scene.cameraEntity.abilities.reach * math.cos(theta - math.tau / 4) * math.cos(phi),
		-scene.cameraEntity.abilities.reach * math.sin(phi),
		scene.cameraEntity.abilities.reach * math.sin(theta - math.tau / 4) * math.cos(phi)
	local x2, y2, z2 = x1 + dx, y1 + dy, z1 + dz
	
	
	local infos, len = world.bumpWorld:querySegmentWithCoords(x1, y1, z1, x2, y2, z2, notCameraEntityFilter)
	
	if len == 0 then return end
	if type(infos[1].item) ~= "number" then return end
	if len > 1 then
		local a, b = infos[1], infos[2]
		if a.ti1 == b.ti1 then
			return -- Abort in "tied" cases
		end
	end
	
	local hash = infos[1].item
	local x, y, z, chunkId = bhDecode(hash)
	local chunk = world.chunksById[chunkId]
	local tx, ty, tz =
		bw * (chunk.x * cw + x),
		bh * (chunk.y * ch + y),
		bd * (chunk.z * cd + z)
	
	local transform = cpml.mat4.identity()
	transform:translate(transform, cpml.vec3(tx, ty, tz))
	transform = transform:transpose(transform)
	
	blockCursorShader:send("modelMatrix", transform)
	blockCursorShader:send("view", getCameraTransform(scene.camera))
	love.graphics.push("all")
	love.graphics.setColor(settings.graphics.blockCursorColour)
	love.graphics.setShader(blockCursorShader)
	love.graphics.setMeshCullMode("none")
	love.graphics.setCanvas({love.graphics.getCanvas(), depthstencil = depthBuffer})
	love.graphics.setWireframe(true)
	love.graphics.draw(assets.terrain.blockCursor.value, constants.width/2, constants.height/2)
	love.graphics.pop()
end

return scene
