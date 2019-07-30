local constants = require("constants")
local registry = require("registry")

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
	ui = {
		cursor = {load = function(self) self.value = love.graphics.newImage("assets/images/ui/cursor.png") end},
		font = {load = function(self) self.value = love.graphics.newImageFont("assets/images/ui/font.png", constants.fontString) end} -- See constants.fontSpecials
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

return setmetatable(assets, {
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
