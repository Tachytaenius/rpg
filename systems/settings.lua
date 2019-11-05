local constants = require("constants")
local json = require("lib.json")

-- Definitions below
local isReal, isInteger, isNatural

local template = {
	graphics = {
		fullscreen = function(try) return type(try) == "boolean" and try end,
		interpolation = function(try) if type(try) == "boolean" then return try else return true end end,
		showPerformance = function(try) return type(try) == "boolean" and try end,
		scale = function(try) return isNatural(try) and try or 2 end,
		display = function(try) return isNatural(try) and try or 1 end,
		maxTicksPerFrame = function(try) return isNatural(try) and try or 4 end,
		vsync = function(try) if type(try) == "boolean" then return try else return true end end
	},
	
	mouse = {
		divideByScale = function(try) if type(try) == "boolean" then return try else return true end end,
		xSensitivity = function(try) return type(try) == "number" and try or 1 end,
		ySensitivity = function(try) return type(try) == "number" and try or 1 end,
		cursorColour = {
			function(try) return type(try) == "number" and try >= 0 and try <= 1 and try or 1 end,
			function(try) return type(try) == "number" and try >= 0 and try <= 1 and try or 1 end,
			function(try) return type(try) == "number" and try >= 0 and try <= 1 and try or 1 end,
			function(try) return type(try) == "number" and try >= 0 and try <= 1 and try or 1 end
		},
		cursorRotation = function(try) return isInteger(try) and 0 <= try and try <= 3 and try or 0 end
	},
	
	useScancodes = function(try) if type(try) == "boolean" then return try else return true end end,
	frameCommands = function(try)
		if type(try) == "table" then
			local result = {}
			for k, v in pairs(try) do
				if constants.frameCommands[k] then
					if pcall(love.keyboard.isScancodeDown, v) or pcall(love.mouse.isDown, v) then
						result[k] = v
					else
						print("\"" .. v .. "\" is not a valid input to bind to a frame command")
					end
				else
					print("\"" .. k .. "\" is not a valid frame command to bind inputs to")
				end
			end
			return result
		else
			return {
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
			}
		end
	end,
	fixedCommands = function(try)
		if type(try) == "table" then
			local result = {}
			for k, v in pairs(try) do
				if constants.fixedCommands[k] then
					if pcall(love.keyboard.isScancodeDown, v) or pcall(love.mouse.isDown, v) then
						result[k] = v
					else
						print("\"" .. v .. "\" is not a valid input to bind to a fixed command")
					end
				else
					print("\"" .. k .. "\" is not a valid fixxed command to bind inputs to")
				end
			end
			return result
		else
			return {
				advance = "w",
				strafeLeft = "a",
				backpedal = "s",
				strafeRight = "d",
				jump = "space",
				run = "lshift",
				crouch = "lctrl",
				
				destroy = 1,
				build = 2
			}
		end
	end
}

function isReal(x)
	return type(x) == "number" and math.abs(x) ~= math.huge and x == x
end

function isInteger(x)
	return isReal(x) and math.floor(x) == x
end

function isNatural(x)
	return isInteger(x) and x > 0
end

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
				-- TODO: Shader values removed?
				love.window.setMode(width, height, {vsync = settings.graphics.vsync, fullscreen = true, borderless = true, display = settings.graphics.display})
			else
				love.window.setMode(constants.width * settings.graphics.scale, constants.height * settings.graphics.scale, {vsync = settings.graphics.vsync, fullscreen = false, borderless = false, display = settings.graphics.display})
			end
			
		else
			error("Settings is to be called with either \"save\", \"load\" or \"apply\"")
		end
	end
})
