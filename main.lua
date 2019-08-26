local constants, assets, settings, registry =
	require("constants"),
	require("assets"),
	require("settings"),
	require("registry")

local suit, bump, list, detmath, cpml =
	require("lib.suit"),
	require("lib.bump-3dpd"),
	require("lib.list"),
	require("lib.detmath"),
	require("lib.cpml")

local think, getWill, move, newChunk, scene, input, ui, takeScreenshot, newEntity =
	require("systems.think"),
	require("systems.getWill"),
	require("systems.move"),
	require("systems.newChunk"),
	require("systems.scene"),
	require("systems.input"),
	require("systems.ui"),
	require("systems.takeScreenshot"),
	require("systems.newEntity")

local outlineShader
local infoCanvas, contentCanvas
local world

-- Used for mouse movement
local mdx, mdy

function love.load(args)
	love.graphics.setMeshCullMode("back")
	love.graphics.setDefaultFilter("nearest", "nearest")
	love.graphics.setLineStyle("rough")
	love.graphics.setDepthMode("lequal", true)
	
	infoCanvas = love.graphics.newCanvas(constants.infoWidth, constants.infoHeight)
	contentCanvas = love.graphics.newCanvas(constants.width, constants.height)
	outlineShader = love.graphics.newShader("shaders/outline.glsl")
	outlineShader:send("windowSize", {constants.infoWidth, constants.infoHeight})
	
	input.clearRawCommands()
	settings("load")
	assets("load")
	
	scene.init()
	
	love.graphics.setFont(assets.ui.font.value)
	
	if not args[1] or args[1] == "new" then
		local seed = args[2] or love.math.random(1000) -- TODO: seed safety?
		world = {
			seed = seed,
			rng = love.math.newRandomGenerator(seed),
			bumpWorld = bump.newWorld(constants.bumpCellSize),
			entities = list.new(),
			chunks = {},
			lights = list.new():add({isDirectional = true, angle={0.4, 0.8, 0.6}, colour={1, 1, 1}, strength = 3}),
			gravityAmount = 9.8,
			gravityMaxFallSpeed = 50
		}
		local testmanPlayer = newEntity(world, "testman", 4, 9, 4, 1)
		-- scene.entitiesToDraw:add(testmanPlayer)
		local testmanCreep = newEntity(world, "testman", 4, 9, 5, "creep")
		scene.entitiesToDraw:add(testmanCreep)
		scene.cameraEntity = testmanPlayer
		worldWidth, worldHeight, worldDepth = 25, 1, 25 -- TODO: HELLO I AM A GLOBAL NO NO NO BAD REEEE
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
					scene.chunksToDraw:add(chunk)
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
	move.initialise(world.bumpWorld)
end

function love.draw(lerp)
	if settings.graphics.showPerformance then
		love.graphics.setCanvas(infoCanvas)
		love.graphics.clear(0, 0, 0, 0)
		love.graphics.print("FPS: " .. love.timer.getFPS() .. "\nGarbage: " .. collectgarbage("count") * 1024, 1, 1)
	end
	if scene.cameraEntity and not (ui.current and ui.current.causesPause) then
		if not settings.graphics.interpolation then
			lerp = nil
		end
		scene.setTransforms(world, lerp)
		scene.render(world)
	end
	love.graphics.setCanvas(contentCanvas)
	love.graphics.clear(0, 0, 0)
	if ui.current then love.graphics.setColor(0.5, 0.5, 0.5) end
	love.graphics.draw(scene.outputCanvas)
	if settings.graphics.showPerformance then
		love.graphics.setColor(1, 1, 1)
		love.graphics.setShader(outlineShader)
		love.graphics.draw(infoCanvas, 1, 1)
		love.graphics.setShader()
	end
	if ui.current then
		suit.draw()
		love.graphics.setColor(settings.mouse.cursorColour)
		love.graphics.draw(assets.ui.cursor.value, math.floor(ui.current.mouseX), math.floor(ui.current.mouseY), settings.mouse.cursorRotation * detmath.tau / 4)
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
	do -- Check hotkeys for settings and screenshots etc
		if input.didCommand("pause") then
			if ui.current then
				ui.destroy()
			else
				ui.construct("plainPause")
			end
		end
		
		if input.didCommand("toggleMouseGrab") then
			love.mouse.setRelativeMode(not love.mouse.getRelativeMode())
		end
		
		if input.didCommand("takeScreenshot") then
			takeScreenshot(input.didCommand("uiModifier") and contentCanvas or scene.outputCanvas)
		end
		
		if input.didCommand("toggleInfo") then
			settings.graphics.showPerformance = not settings.graphics.showPerformance
			settings("save")
		end
		
		if input.didCommand("previousDisplay") and love.window.getDisplayCount() > 1 then
			settings.graphics.display = (settings.graphics.display - 2) % love.window.getDisplayCount() + 1
			settings("apply") -- TODO: test thingy... y'know, "press enter to save or wait 5 seconds to revert"
			settings("save")
		end
		
		if input.didCommand("nextDisplay") and love.window.getDisplayCount() > 1 then
			settings.graphics.display = (settings.graphics.display) % love.window.getDisplayCount() + 1
			settings("apply")
			settings("save")
		end
		
		if input.didCommand("scaleDown") and settings.graphics.scale > 1 then
			settings.graphics.scale = settings.graphics.scale - 1
			settings("apply")
			settings("save")
		end
		
		if input.didCommand("scaleUp") then
			settings.graphics.scale = settings.graphics.scale + 1
			settings("apply")
			settings("save")
		end
		
		if input.didCommand("toggleFullscreen") then
			settings.graphics.fullscreen = not settings.graphics.fullscreen
			settings("apply")
			settings("save")
		end
	end
	
	if ui.current then
		ui.update()
	end
	
	if not (ui.current and ui.current.causesPause) then
		-- TODO: particles and such
	end
	
	input.stepRawCommands()
end

function love.fixedUpdate(dt)
	if not (ui.current and ui.current.causesPause) then
		for i = 1, world.entities.size do
			local entity = world.entities:get(i)
			-- Back up previous fields for interpolation
			entity.ptheta, entity.pphi, entity.px, entity.py, entity.pz, entity.pw, entity.ph, entity.pd = entity.theta, entity.phi, world.bumpWorld:getCube(entity)
			if entity.controller then -- Do own movement
				local will
				if type(entity.controller) == "number" then
					assert(entity.controller == 1, "Multiplayer is not here yet")
					will = getWill(mdx, mdy)
				else
					will = think(entity, world)
				end
				move.selfAccelerate(entity, will, dt)
			end
			move.gravitate(entity, world.gravityAmount, world.gravityMaxFallSpeed, dt)
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
			-- snap y velocity
			entity.vy = math.abs(entity.vy) > constants.velocitySnap and entity.vy or 0
		end
		
		-- TODO push apart entities that're in the same place and use random (in a deterministic order) in the resolutions on their ambiguities
		
		mdx, mdy = 0, 0
	end
end

-- The following function is based on the MIT licensed code here: https://gist.github.com/Positive07/5e80f03cabd069087930d569c148241c
-- Copyright (c) 2019 Arvid Gerstmann, Jake Besworth, Max, Pablo Mayobre, LÖVE Developers, Henry Fleminger Thomson

require("timedebugger")
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
			
			-- TODO
			-- FIXME: collectgarbage("count") returns all memory in use, not just garbage?
			-- if collectgarbage("count") / 1024 > settings.manualGarbageCollection.safetyMargin then
				-- collectgarbage("collect")
			-- end
			
			collectgarbage("stop")
		else
			collectgarbage("restart")
		end
		
		love.timer.sleep(0.001)
	end
end

function love.mousemoved(x, y, dx, dy)
	if love.window.hasFocus() and love.window.hasMouseFocus() and love.mouse.getRelativeMode() then
		if ui.current then
			ui.mouse(dx, dy)
		elseif scene.cameraEntity then -- TODO: not just else? (reason being, what if demo replay had its own, separate camera)
			mdx, mdy = mdx + dx * delta, mdy + dy * delta
		end
	end
end

function love.quit()
	
end

-- TEMP
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
