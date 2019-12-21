local suit = require("lib.suit")
local constants = require("constants")
local assets = require("assets")
local settings = require("systems.settings")
local types, typeInstanceOrigins, template, uiLayout = settings("meta")

local trueButton, falseButton = assets.ui.trueButton, assets.ui.falseButton

local settingsUI = {}

function settingsUI.construct(state)
	state.causesPause = true
	
	state.changes = {}
end

local function get(state, ...)
	local current = state.changes
	for i = 1, select("#", ...) do
		local key = select(i, ...)
		if current[key] ~= nil then
			current = current[key]
		else
			-- Get from original settings
			local current = settings
			for i = 1, select("#", ...) do
				current = current[select(i, ...)]
			end
			return current
		end
	end
	return current
end

local function set(state, to, ...)
	local current = state.changes
	local len = select("#", ...)
	for i = 1, len - 1 do
		local key = select(i, ...)
		current[key] = current[key] or {}
		current = current[key]
	end
	
	current[select(len, ...)] = to
end

function settingsUI.update(state)
	local x, y = constants.width / 3, constants.height / 12
	local w, h = constants.width / 3, assets.ui.font.value:getHeight() + 3
	local pad = 4
	suit.layout:reset(x, y, pad)
	
	local rectangles = {}
	local function finishRect()
		if #rectangles ~= 0 then
			rectangles[#rectangles][3], rectangles[#rectangles][4] = w + pad * 2, (suit.layout._y + pad) - rectangles[#rectangles][2] + h + pad
		end
	end
	
	if suit.Button("Cancel", suit.layout:row(w/2-pad/2, h)).hit then
		return true
	end
	if suit.Button("OK", suit.layout:col()).hit then
		local function traverse(currentChanges, currentSettings, currentTemplate)
			for k, v in pairs(currentChanges) do
				if type(currentTemplate[k]) == "table" then
					 -- Another category to traverse
					traverse(v, currentSettings[k], currentTemplate[k])
				else--if type(currentTemplate[k]) == "function"
					-- A setting to change
					currentSettings[k] = v
				end
			end
		end
		traverse(state.changes, settings, template)
		
		settings("apply")
		settings("save")
		return true
	end
	
	suit.layout:reset(x, y + h, pad)
	
	for i, item in ipairs(uiLayout) do
		if type(item) == "string" then 
			finishRect()
			suit.layout:row(w, h)
			suit.Label(item .. ":", {align = "left"}, suit.layout:row(w, h))
			rectangles[#rectangles + 1] = {suit.layout._x - pad, suit.layout._y - pad}
		elseif type(item) == "table" then
			local settingName = item.name
			local settingState = get(state, unpack(item))
			
			local current = template
			for _, key in ipairs(item) do
				current = current[key]
			end
			assert(type(current) == "function", "Settings UI layout references nonexistent setting")
			local settingType = typeInstanceOrigins[current]
			local x,y,w,h=suit.layout:row(w, h)
			if settingType == types.boolean then
				if suit.ImageButton((settingState and trueButton or falseButton).value, {id = i}, x,y,w,h).hit then
					set(state, not settingState, unpack(item))
				end
				suit.Label(item.name, {align = "right"}, x,y,w,h)
			end
		else
			error("String or table only in settings UI layout, not " .. type(item))
		end
	end
	
	finishRect()
	
	function state.draw()
		for _, rectangle in ipairs(rectangles) do
			love.graphics.rectangle("line", unpack(rectangle))
		end
	end
end

return settingsUI
