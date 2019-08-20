local constants, assets, settings =
	require("constants"),
	require("assets"),
	require("settings")

local suit, bump, list, detmath, cpml =
	require("lib.suit"),
	require("lib.bump-3dpd"),
	require("lib.list"),
	require("lib.detmath"),
	require("lib.cpml")

local think, move, newChunk =
	require("systems.think"),
	require("systems.move"),
	require("systems.newChunk")

do -- Great for modifying blocks within chunks!
	local tbl, concat = {}, table.concat
	function string:setchar(pos, chr)
		tbl[1], tbl[2], tbl[3] = self:sub(1, pos - 1), chr, self:sub(pos + 1)
		return concat(tbl)
	end
end

-- These functions are defined way below where they won't clutter amongst the love functions
local checkSettingsHotkeys, takeScreenshot, didCommand, stepRawCommands, clearRawCommands, constructUI, destroyUI, updateUI, getPlayerWill, setTransforms, snap, warn, render

-- Graphics
local gBufferShader, shadowShader, lightingShader, postShader, outlineShader
local gBufferSetup, positionBuffer, surfaceBuffer, albedoBuffer, materialBuffer, depthBuffer
local shadowMapSetup, shadowMap
local cameraEntity, sceneCamera, chunksToDraw
local lightCanvas, sceneCanvas, infoCanvas, contentCanvas
local world, ui, fogTurbulenceTime
local dummy = love.graphics.newImage(love.image.newImageData(1, 1))

-- Used for mouse movement
local mdx, mdy

function love.load(args)
	love.graphics.setMeshCullMode("back")
	love.graphics.setDefaultFilter("nearest", "nearest")
	love.graphics.setLineStyle("rough")
	love.graphics.setDepthMode("lequal", true)
	
	clearRawCommands()
	settings("load")
	assets("load")
	
	love.graphics.setFont(assets.ui.font.value)
	
	positionBuffer = love.graphics.newCanvas(constants.width, constants.height, {format = "rgba16f"})
	surfaceBuffer = love.graphics.newCanvas(constants.width, constants.height, {format = "rgba16f"})
	albedoBuffer = love.graphics.newCanvas(constants.width, constants.height)
	materialBuffer = love.graphics.newCanvas(constants.width, constants.height)
	depthBuffer = love.graphics.newCanvas(constants.width, constants.height, {format = "depth32f"})
	gBufferSetup = {
		positionBuffer, surfaceBuffer, albedoBuffer, materialBuffer,
		depthstencil = depthBuffer
	}
	
	shadowMap = love.graphics.newCanvas(constants.shadowMapSize, constants.shadowMapSize, {format = "depth32f", readable = true})
	shadowMapSetup = {
		depthstencil = shadowMap
	}
	
	lightCanvas = love.graphics.newCanvas(constants.width, constants.height)
	sceneCanvas = love.graphics.newCanvas(constants.width, constants.height)
	infoCanvas = love.graphics.newCanvas(constants.infoWidth, constants.infoHeight)
	contentCanvas = love.graphics.newCanvas(constants.width, constants.height)
	
	gBufferShader = love.graphics.newShader("shaders/gBuffer.glsl")
	shadowShader = love.graphics.newShader("shaders/shadow.glsl")
	lightingShader = love.graphics.newShader("shaders/lighting.glsl")
	postShader = love.graphics.newShader("shaders/post.glsl")
	outlineShader = love.graphics.newShader("shaders/outline.glsl")
	
	lightingShader:send("nearPlane", constants.lightNearPlane) -- For getting values out of the shadow map depth buffer
	lightingShader:send("windowSize", {constants.width, constants.height})
	lightingShader:send("maximumBias", constants.maxShadowBias)
	lightingShader:send("minimumBias", constants.minShadowBias)
	postShader:send("skyColour", {0.3, 0.4, 0.5})
	postShader:send("fogRadius", 25)
	postShader:send("fogStart", 0.6)
	outlineShader:send("windowSize", {constants.infoWidth, constants.infoHeight})
	
	chunksToDraw = list.new()
	sceneCamera = {near = 0.0001, far = 30}
	
	-- and the rest of the loading routine:
	
	if not args[1] or args[1] == "new" then
		testman = {
			theta = 0, preModuloTheta = 0,
			phi = 0, preModuloPhi = 0,
			vx = 0, vy = 0, vz = 0, vtheta = 0, vphi = 0,
			diameter = 0.48, height = 1.65, mass = 60,
			fallFovStart = 1, fallFovEnd = 4, fallingFovIncrease = 10,
			fov = 90, eyeHeight = 1.58, controller = 1,
			abilities = {
				mobility = {
					ungroundedXChangeMultiplier = 0.2,
					ungroundedYChangeMultiplier = 0,
					ungroundedZChangeMultiplier = 0.2,
					
					maximumTargetVelocity = {
						x = {
							negative = 6.3,
							positive = 6.3
						},
						y = {
							negative = 0,
							positive = 5.2
						},
						z = {
							negative = 6.6,
							positive = 5.8
						},
						theta = {
							negative = detmath.tau * 2,
							positive = detmath.tau * 2
						},
						phi = {
							negative = detmath.tau * 2,
							positive = detmath.tau * 2
						}
					},
					maximumAcceleration = {
						x = {
							negative = 6.3*2,
							positive = 6.3*2
						},
						y = {
							negative = 0,
							positive = math.huge
						},
						z = {
							negative = 6.6*2,
							positive = 5.8*2
						},
						theta = {
							negative = detmath.tau * 40,
							positive = detmath.tau * 40
						},
						phi = {
							negative = detmath.tau * 40,
							positive = detmath.tau * 40
						}
					},
					maximumDeceleration = {
						x = {
							negative = 6.3*2,
							positive = 6.3*2
						},
						y = {
							negative = 0,
							positive = 0,
						},
						z = {
							negative = 6.6*2,
							positive = 5.8*2
						},
						theta = {
							negative = detmath.tau * 40,
							positive = detmath.tau * 40
						},
						phi = {
							negative = detmath.tau * 40,
							positive = detmath.tau * 40
						}
					}
				},
				
				move = true,
				turn = true,
				
				stepUpRange = 0.5 -- TODO
			}
		}
		
		local seed = args[2] or love.math.random(1000) -- TODO: seed safety?
		world = {
			seed = seed,
			rng = love.math.newRandomGenerator(seed),
			bumpWorld = bump.newWorld(constants.bumpCellSize),
			entities = list.new():add(testman),
			chunks = {},
			lights = list.new():add({isDirectional = true, angle={0.4, 0.8, 0.6}, colour={1, 1, 1}, strength = 3}),
			gravityWill = {
				isGravity = true,
				targetY = 50,
				amount = 9.8
			}
		}
		world.bumpWorld:add(testman, 4, 9, 4, testman.diameter, testman.height, testman.diameter)
		worldWidth, worldHeight, worldDepth = 10, 4, 10 -- TODO: HELLO I AM A GLOBAL NO NO NO BAD REEEE
		for x = 0, worldWidth - 1 do
			local chunksX = {}
			world.chunks[x] = chunksX
			for y = 0, worldHeight - 1 do
				local chunksY = {}
				chunksX[y] = chunksY
				for z = 0, worldDepth - 1 do
					local newChunk = newChunk(x, y, z, world.chunks, world.bumpWorld, world.seed)
					chunksY[z] = newChunk
				end
			end
		end
		for x = 0, worldWidth - 1 do
			local chunkX = world.chunks[x]
			for y = 0, worldHeight - 1 do
				local chunkY = chunkX[y]
				for z = 0, worldDepth - 1 do
					local chunk = chunkY[z]
					chunk:updateMesh()
					chunksToDraw:add(chunk)
				end
			end
		end
		
	elseif args[1] == "load" then
		local path = args[2]
		error("Go away, this isn't done yet!")
	else
		error("Invalid first argument: " .. args[1])
	end
	
	mdx, mdy = 0, 0
	cameraEntity = testman
	move.initialise(world.bumpWorld)
end

function love.draw(lerp)
	if settings.graphics.showPerformance then
		love.graphics.setCanvas(infoCanvas)
		love.graphics.clear(0, 0, 0, 0)
		love.graphics.print("FPS: " .. love.timer.getFPS() .. "\nGarbage: " .. collectgarbage("count") * 1024, 1, 1)
	end
	if cameraEntity and not (ui and ui.causesPause) then
		setTransforms(lerp)
		render()
	end
	love.graphics.setCanvas(contentCanvas)
	love.graphics.clear(0, 0, 0)
	if ui then love.graphics.setColor(0.5, 0.5, 0.5) end
	love.graphics.draw(sceneCanvas)
	if settings.graphics.showPerformance then
		love.graphics.setColor(1, 1, 1)
		love.graphics.setShader(outlineShader)
		love.graphics.draw(infoCanvas, 1, 1)
		love.graphics.setShader()
	end
	if ui then
		suit.draw()
		love.graphics.setColor(settings.mouse.cursorColour)
		love.graphics.draw(assets.ui.cursor.value, math.floor(ui.mouseX), math.floor(ui.mouseY), settings.mouse.cursorRotation * detmath.tau / 4)
	end
	love.graphics.setColor(1, 1, 1)
	
	love.graphics.setCanvas()
	
	local x, y
	if settings.graphics.fullscreen then
		local width, height = love.window.getDesktopDimensions()
		x = (width - constants.width * settings.graphics.scale) / 2
		y = (height - constants.height * settings.graphics.scale) / 2
	else
		x, y = 0, 0
	end
	
	love.graphics.draw(contentCanvas, x, y, 0, settings.graphics.scale)
end

function love.frameUpdate(dt)
	checkSettingsHotkeys() -- TODO: rename
	
	if ui then
		suit.updateMouse(ui.mouseX, ui.mouseY, didCommand("uiPrimary"))
		updateUI()
	end
	
	if not (ui and ui.causesPause) then
		-- TODO: particles and such
	end
	
	stepRawCommands()
end

function love.fixedUpdate(dt)
	if not (ui and ui.causesPause) then
		for i = 1, world.entities.size do
			local entity = world.entities:get(i)
			-- Back up previous fields for interpolation
			entity.ptheta, entity.pphi, entity.px, entity.py, entity.pz, entity.pw, entity.ph, entity.pd = entity.theta, entity.phi, world.bumpWorld:getCube(entity)
			if entity.controller then -- Do own movement
				local will
				if type(entity.controller) == "number" then
					assert(entity.controller == 1, "Multiplayer is not here yet")
					will = getPlayerWill(entity.abilities)
				else
					will = think(entity, world)
				end
				move.accelerate(entity, will, dt)
			end
			move.accelerate(entity, world.gravityWill, dt)
			-- Attacks and such go here
		end
		
		for i = 1, world.entities.size do
			move.collide(world.entities:get(i), world.bumpWorld, dt)
		end
		
		for i = 1, world.entities.size do
			local entity = world.entities:get(i)
			world.bumpWorld:update(entity, entity.nextX, entity.nextY, entity.nextZ)
			entity.vx, entity.vy, entity.vz, entity.nextVx, entity.nextVy, entity.nextVz, entity.nextX, entity.nextY, entity.nextZ =
				entity.nextVx, entity.nextVy, entity.nextVz
			entity.vy = snap(entity.vy, constants.velocitySnap)
		end
		
		-- TODO push apart entities that're in the same place and use random (in a deterministic order) in the resolutions on their ambiguities
		
		mdx, mdy = 0, 0
	end
end

-- The following function is based on the MIT licensed code here: https://gist.github.com/Positive07/5e80f03cabd069087930d569c148241c
-- Copyright (c) 2019 Arvid Gerstmann, Jake Besworth, Max, Pablo Mayobre, LÖVE Developers, Henry Fleminger Thomson

local delta = 0 -- For mousemoved
function love.run()
	love.load(love.arg.parseGameArguments(arg))
	local lag = constants.tickWorth
	love.timer.step()
	
	return function()
		love.event.pump()
		for name, a,b,c,d,e,f in love.event.poll() do -- Events
			if name == "quit" then
				if not love.quit() then
					return a or 0
				end
			end
			love.handlers[name](a,b,c,d,e,f)
		end
		
		do -- Update
			delta = love.timer.step()
			local start = love.timer.getTime()
			lag = math.min(lag + delta, constants.tickWorth * settings.graphics.maxTicksPerFrame)
			local frames = math.floor(lag / constants.tickWorth)
			lag = lag % constants.tickWorth
			love.frameUpdate(delta)
			for _=1, frames do
				love.fixedUpdate(constants.tickWorth)
			end
		end
		
		if love.graphics.isActive() then -- Rendering
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())
			love.draw(lag / constants.tickWorth)
			love.graphics.present()
		end
		
		if settings.manualGarbageCollection.enable then -- Garbage collection
			local start = love.timer.getTime()
			for _=1, settings.manualGarbageCollection.maxSteps do
				if love.timer.getTime() - start > settings.manualGarbageCollection.timeLimit then break end
				collectgarbage("step", 1)
			end
			
			if collectgarbage("count") / 1024 > settings.manualGarbageCollection.safetyMargin then
				collectgarbage("collect")
			end
			
			collectgarbage("stop")
		else
			collectgarbage("start")
		end
		
		love.timer.sleep(0.001)
	end
end

function love.mousemoved(x, y, dx, dy)
	if love.window.hasFocus() and love.window.hasMouseFocus() and love.mouse.getRelativeMode() then
		if ui then
			local div = settings.mouse.divideByScale and settings.graphics.scale or 1
			ui.mouseX = math.min(math.max(0, ui.mouseX + (dx * settings.mouse.xSensitivity) / div), constants.width)
			ui.mouseY = math.min(math.max(0, ui.mouseY + (dy * settings.mouse.ySensitivity) / div), constants.height)
		elseif cameraEntity then -- TODO: not just else? (reason being, what if demo replay had its own, separate camera)
			mdx, mdy = mdx + dx * delta, mdy + dy * delta
		end
	end
end

function love.quit()
	
end

-- Already local:

function checkSettingsHotkeys()
	if didCommand("pause") then
		if ui then
			destroyUI()
		else
			constructUI("plainPause")
		end
	end
	
	if didCommand("toggleMouseGrab") then
		love.mouse.setRelativeMode(not love.mouse.getRelativeMode())
	end
	
	if didCommand("takeScreenshot") then
		takeScreenshot(didCommand("uiModifier") and contentCanvas or sceneCanvas)
	end
	
	if didCommand("toggleInfo") then
		settings.graphics.showPerformance = not settings.graphics.showPerformance
		settings("save")
	end
	
	if didCommand("previousDisplay") and love.window.getDisplayCount() > 1 then
		settings.graphics.display = (settings.graphics.display - 2) % love.window.getDisplayCount() + 1
		settings("apply") -- TODO: test thingy... y'know, "press enter to save or wait 5 seconds to revert"
		settings("save")
	end
	
	if didCommand("nextDisplay") and love.window.getDisplayCount() > 1 then
		settings.graphics.display = (settings.graphics.display) % love.window.getDisplayCount() + 1
		settings("apply")
		settings("save")
	end
	
	if didCommand("scaleDown") and settings.graphics.scale > 1 then
		settings.graphics.scale = settings.graphics.scale - 1
		settings("apply")
		settings("save")
	end
	
	if didCommand("scaleUp") then
		settings.graphics.scale = settings.graphics.scale + 1
		settings("apply")
		settings("save")
	end
	
	if didCommand("toggleFullscreen") then
		settings.graphics.fullscreen = not settings.graphics.fullscreen
		settings("apply")
		settings("save")
	end
end

function takeScreenshot(canvas)
	local info = love.filesystem.getInfo("screenshots")
	if not info then
		print("Couldn't find screenshots folder. Creating")
		love.filesystem.createDirectory("screenshots")
	elseif info.type ~= "directory" then
		-- TODO: UX(?)
		warn("There is already a non-folder item called screenshots. Rename it or move it to take a screenshot")
		return
	end
	
	local current = 0
	for _, filename in pairs(love.filesystem.getDirectoryItems("screenshots")) do
		if string.match(filename, "^[1-9]%d*%.png$") then -- Make sure this file could have been created by this function
			current = math.max(current, tonumber(string.sub(filename, 1, -5)))
		end
	end
	
	canvas:newImageData():encode("png", "screenshots/" .. current + 1 .. ".png")
end

local previousFrameRawCommands, thisFrameRawCommands

function didCommand(name)
	assert(constants.commands[name], name .. " is not a valid command")
	
	local assignee = settings.commands[name]
	if (type(assignee) == "string" and (settings.useScancodes and love.keyboard.isScancodeDown or lov.keyboard.isDown)(assignee)) or (type(assignee) == "number" and love.mouse.isGrabbed() and love.mouse.isDown(assignee)) then
		thisFrameRawCommands[name] = true
	end
	
	local deltaPolicy = constants.commands[name]
	if deltaPolicy == "onPress" then
		return thisFrameRawCommands[name] and not previousFrameRawCommands[name]
	elseif deltaPolicy == "onRelease" then
		return not thisFrameRawCommands[name] and previousFrameRawCommands[name]
	elseif deltaPolicy == "whileDown" then
		return thisFrameRawCommands[name]
	else
		error(deltaPolicy .. " is not a valid delta policy")
	end
end

function stepRawCommands()
	previousFrameRawCommands, thisFrameRawCommands = thisFrameRawCommands, {}
end

function clearRawCommands()
	previousFrameRawCommands, thisFrameRawCommands = {}, {}
end

function constructUI(type)
	suit.enterFrame()
	
	ui = {
		type = type,
		mouseX = constants.width / 2,
		mouseY = constants.height / 2
	}
	
	if type == "plainPause" then
		ui.causesPause = true
	end
end

function destroyUI()
	ui = nil
	suit.updateMouse(nil, nil, false)
	suit.exitFrame()
end

function updateUI()
	if ui.type == "plainPause" then
		suit.layout:reset(constants.width / 3, constants.height / 3, 4)
		if suit.Button("Resume", suit.layout:row(constants.width / 3, assets.ui.font.value:getHeight() + 3)).hit then
			destroyUI()
		end
		if suit.Button("Quit", suit.layout:row()).hit then
			love.event.quit()
		end
	end
end

function getPlayerWill()
	-- Player version of "think", ie obeys commands
	local will = {}
	
	local sneak, run = didCommand("sneak"), didCommand("run")
	local advance, backpedal = didCommand("advance"), didCommand("backpedal")
	local strafeLeft, strafeRight = didCommand("strafeLeft"), didCommand("strafeRight")
	local tvx, tvz = 0, 0
	if advance then tvz = tvz - 1 end
	if backpedal then tvz = tvz + 1 end
	if strafeLeft then tvx = tvx - 1 end
	if strafeRight then tvx = tvx + 1 end
	will.targetVelocityXMultiplier, will.targetVelocityZMultiplier =
	tvx * (sneak and not run and 0.1 or run and not sneak and 1 or 0.5),
	tvz * (sneak and not run and 0.1 or run and not sneak and 1 or 0.5)
	
	-- Sneak and walk has half the jump height of run
	will.targetVelocityYMultiplier = didCommand("jump") and math.sqrt(run and 1 or 0.5) or 0
	will.targetVelocityThetaMultiplier = mdx
	will.targetVelocityPhiMultiplier = mdy
	
	return will
end

local function lerpEntity(entity, lerp)
	local x, y, z, w, h, d, theta, phi
	x, y, z, w, h, d = world.bumpWorld:getCube(entity)
	x, y, z, w, h, d, theta, phi =
		(1 - lerp) * entity.px + lerp * x,
		(1 - lerp) * entity.py + lerp * y,
		(1 - lerp) * entity.pz + lerp * z,
		(1 - lerp) * entity.pw + lerp * w,
		(1 - lerp) * entity.ph + lerp * h,
		(1 - lerp) * entity.pd + lerp * d,
		(1 - lerp) * entity.ptheta + lerp * entity.preModuloTheta,
		(1 - lerp) * entity.pphi + lerp * entity.phi
	return x, y, z, w, h, d, theta, phi
end

function setTransforms(lerp)
	local entities = world.entities
	
	for i = 1, entities.size do
		local entity = entities:get(i)
		local model = entity.model
		
		if model then
			local x, y, z, w, h, d, theta, phi = lerpEntity(entity, lerp)
			
			local transform = cpml.mat4.identity()
			transform:translate(transform, cpml.vec3(x+w/2, y+h/2, z+d/2))
			transform:rotate(transform, theta, cpml.vec3.unit_x)
			transform:rotate(transform, phi, cpml.vec3.unit_y)
			model.transform = transform:transpose(transform)
		end
	end
	
	if cameraEntity then
		local x, y, z, w, h, d, theta, phi = lerpEntity(cameraEntity, lerp)
		-- TODO: allow lerping of all attributes
		sceneCamera.fov = cameraEntity.fov
		sceneCamera.pos = cpml.vec3(x + w / 2, y + cameraEntity.eyeHeight, z + d / 2)
		sceneCamera.angle = cpml.vec3(phi, theta, 0)
	end
end

function snap(x, range)
	return math.abs(x) > range and x or 0
end

function warn(text)
	-- TODO ui
	print(text)
end

local getCameraTransform, renderGBuffer, sendGBufferToLightingShader, finishingTouches

function render()
	renderGBuffer()
	sendGBufferToLightingShader()
	renderLights()
	finishingTouches() -- reset blend mode, draw lightCanvas to sceneCanvas with post shader, and finally unset shader and canvas
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

function renderGBuffer()
	love.graphics.setShader(gBufferShader)
	gBufferShader:send("view", getCameraTransform(sceneCamera))
	gBufferShader:send("viewPosition", {sceneCamera.pos:unpack()})
	love.graphics.setCanvas(gBufferSetup)
	love.graphics.clear()
	renderObjects()
end

function sendGBufferToLightingShader()
	lightingShader:send("positionBuffer", positionBuffer)
	lightingShader:send("surfaceBuffer", surfaceBuffer)
	lightingShader:send("albedoBuffer", albedoBuffer)
	lightingShader:send("materialBuffer", materialBuffer)
	lightingShader:send("viewPosition", {sceneCamera.pos:unpack()})
end

function renderObjects()
	local cx, cy
	if love.graphics.getShader() == shadowShader then
		cx, cy = constants.shadowMapSize / 2, constants.shadowMapSize / 2
	else
		cx, cy = constants.width/2, constants.height/2
	end
	
	local currentShader = love.graphics.getShader()
	local chunkTransform = cpml.mat4.identity()
	currentShader:send("modelMatrix", chunkTransform) -- or lack thereof
	
	-- Chunks
	if currentShader == gBufferShader then
		currentShader:send("modelMatrixInverse", chunkTransform)
		gBufferShader:send("surfaceMap", assets.terrain.surfaceMap.value)
		gBufferShader:send("albedoMap", assets.terrain.albedoMap.value)
		gBufferShader:send("materialMap", assets.terrain.materialMap.value)
	end
	for i = 1, chunksToDraw.size do
		local mesh = chunksToDraw:get(i).mesh
		if mesh then
			love.graphics.draw(mesh, cx, cy)
		end
	end
	
	-- Entities
	for i = 1, world.entities.size do
		local model = world.entities:get(i).model
		if model then
			local currentShader = love.graphics.getShader()
			
			
			currentShader:send("modelMatrix", model.transform)
			
			if currentShader == gBufferShader then
				local inverse = cpml.mat4.invert(cpml.mat4.new(), model.transform)
				inverse = inverse:transpose(inverse)
				currentShader:send("modelMatrixInverse", inverse)
				gBufferShader:send("surfaceMap", model.surfaceMap.value)
				gBufferShader:send("albedoMap", model.albedoMap.value)
				gBufferShader:send("materialMap", model.materialMap.value)
			end
			
			love.graphics.draw(model.mesh, cx, cy)
		end
	end
end

function renderLights()
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
		lightingShader:send("viewPosition", {sceneCamera.pos:unpack()})
		
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
	love.graphics.setCanvas(sceneCanvas)
	love.graphics.setShader(postShader)
	postShader:send("positionBuffer", positionBuffer)
	postShader:send("viewPosition", {sceneCamera.pos:unpack()})
	love.graphics.draw(lightCanvas)
	love.graphics.setCanvas()
	love.graphics.setShader()
end

function love.keypressed(k)
	if k == "j" then
		local x, y, z, w, h, d = world.bumpWorld:getCube(testman)
		x, y, z = x+w/2, y+h/2, z+d/2
		x, y, z = math.floor(x/constants.blockWidth), math.floor(y/constants.blockHeight), math.floor(z/constants.blockDepth)
		local cx, cy, cz = math.floor(x/constants.chunkWidth), math.floor(y/constants.chunkHeight), math.floor(z/constants.chunkDepth)
		-- pcall(function()
			local chunk = world.chunks[cx][cy][cz]
			local column = chunk.terrain[x%constants.chunkWidth][z%constants.chunkDepth]
			column.columnTable[y%constants.chunkHeight+1] = string.char(1)
			column:updateString()
			chunk:updateMesh()
		-- end)
	end
end
