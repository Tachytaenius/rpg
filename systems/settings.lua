local constants = require("constants")
local json = require("lib.json")

local uiLayout = {
	"Graphics",
	{name = "Fullscreen", "graphics","fullscreen"},
	{name = "Interpolation", "graphics","interpolation"}
}

local types = {}
local typeInstanceOrigins = {}

function types.boolean(default)
	assert(type(default) == "boolean", "Non-boolean default for boolean setting") -- The phrase "practise what you preach" comes to mind. Amusing!
	local instance = function(try)
		if type(try) == "boolean" then
			return try
		else
			return default
		end
	end
	typeInstanceOrigins[instance] = types.boolean
	return instance
end

local function validComponent(x)
	return type(x) == "number" and 0 <= x and x <= 1
end
function types.rgba(dr, dg, db, da)
	for i = 1, select("#", dr,dg,db,da) do
		assert(validComponent(select(i, dr,dg,db,da)), "Invalid component as default for component " .. i .. " in a colour setting")
	end
	
	local instance = function(try)
		if type(try) ~= "table" then return {dr,dg,db,da} end
		local result = {}
		for i = 1, select("#", dr,dg,db,da) do
			local try = try[i]
			local default = select(i, dr,dg,db,da)
			
			result[i] = validComponent(try) and try or default
		end
		return result
	end
	typeInstanceOrigins[instance] = types.rgba
	return instance
end
function types.rgb(dr, dg, db)
	for i = 1, select("#", dr,dg,db) do
		assert(validComponent(select(i, dr,dg,db)), "Invalid component as default for component " .. i .. " in a colour setting")
	end
	
	local instance = function(try)
		if type(try) ~= "table" then return {dr,dg,db} end
		local result = {}
		for i = 1, select("#", dr,dg,db) do
			local try = try[i]
			local default = select(i, dr,dg,db)
			
			result[i] = validComponent(try) and try or default
		end
		return result
	end
	typeInstanceOrigins[instance] = types.rgb
	return instance
end

local function validNatural(x)
	return type(x) == "number" and math.floor(x) == x and x > 0
end
function types.natural(default)
	assert(validNatural(default), "Non-natural default for natural setting")
	local instance = function(try)
		return validNatural(try) and try or default
	end
	typeInstanceOrigins[instance] = types.natural
	return instance
end

function types.number(default)
	assert(type(default) == "number", "Non-number default for number setting")
	local instance = function(try)
		return type(try) == "number" and try or default
	end
	typeInstanceOrigins[instance] = types.number
	return instance
end

function types.commands(kind, default)
	local instance = function(try)
		if type(try) == "table" then
			local result = {}
			for k, v in pairs(try) do
				if constants[kind .. "Commands"][k] then
					if pcall(love.keyboard.isScancodeDown, v) or pcall(love.mouse.isDown, v) then
						result[k] = v
					else
						print("\"" .. v .. "\" is not a valid input to bind to a " .. kind .. " command")
					end
				else
					print("\"" .. k .. "\" is not a valid " .. kind .. " command to bind inputs to")
				end
			end
			return result
		else
			return default
		end
	end
	typeInstanceOrigins[instance] = types.commands
	return instance
end

local template = {
	graphics = {
		fullscreen = types.boolean(false),
		interpolation = types.boolean(true),
		showPerformance = types.boolean(false),
		scale = types.natural(2),
		display = types.natural(1),
		maxTicksPerFrame = types.natural(4),
		vsync = types.boolean(true),
		blockCursorColour = types.rgba(0, 0, 0, 0.75)
	},
	
	mouse = {
		divideByScale = types.boolean(true),
		xSensitivity = types.number(1),
		ySensitivity = types.number(1),
		cursorColour = types.rgba(1, 1, 1, 1)
	},
	
	useScancodes = types.boolean(true),
	frameCommands = types.commands("frame", {
		pause = "escape",
		
		toggleMouseGrab = "f1",
		takeScreenshot = "f2",
		toggleInfo = "f3",
		
		previousDisplay = "f7",
		nextDisplay = "f8",
		scaleDown = "f9",
		scaleUp = "f10",
		toggleFullscreen = "f11",
		
		uiPrimary = 1,
		uiSecondary = 2,
		uiModifier = "lalt"
	}),
	fixedCommands = types.commands("fixed", {
		advance = "w",
		strafeLeft = "a",
		backpedal = "s",
		strafeRight = "d",
		jump = "space",
		run = "lshift",
		crouch = "lctrl",
		
		destroy = 1,
		build = 2
	})
}

return setmetatable({}, {
	__call = function(settings, action)
		if action == "save" then
			local success, message = love.filesystem.write("settings.json", json.encode(settings))
			if not success then print(message) end -- TODO: UX(?)
			
		elseif action == "load" then
			local info = love.filesystem.getInfo("settings.json")
			local decoded
			if info then
				if info.type == "file" then
					decoded = json.decode(love.filesystem.read("settings.json"))
				else
					print("There is already a non-file item called settings.json. Rename it or move it to use custom settings")
				end
			else
				print("Couldn't find settings.json, creating")
			end
			local function traverse(currentTemplate, currentDecoded, currentResult)
				for k, v in pairs(currentTemplate) do
					if type(v) == "table" then
						currentResult[k] = currentResult[k] or {}
						traverse(v, currentDecoded and currentDecoded[k] or nil, currentResult[k])
					elseif type(v) == "function" then
						currentResult[k] = v(currentDecoded and currentDecoded[k])
					else
						error(v .. "is not a valid value in the settings template")
					end
				end
			end
			traverse(template, decoded, settings)
			settings("apply")
			settings("save")
			
		elseif action == "apply" then
			if settings.graphics.fullscreen then
				local width, height = love.window.getDesktopDimensions(settings.graphics.display)
				love.window.setMode(width, height, {vsync = settings.graphics.vsync, fullscreen = true, borderless = true, display = settings.graphics.display})
			else
				love.window.setMode(constants.width * settings.graphics.scale, constants.height * settings.graphics.scale, {vsync = settings.graphics.vsync, fullscreen = false, borderless = false, display = settings.graphics.display})
			end
			-- TODO: Apparently shader uniforms can get cleared by setMode? I haven't seen it yet, though?
			-- FIXME: Either way, scene.outputCanvas does.
		
		elseif action == "meta" then -- TODO: Better name
			return types, typeInstanceOrigins, template, uiLayout
		
		else
			error("Settings is to be called with either \"save\", \"load\", \"apply\", or \"meta\"")
		end
	end
})
