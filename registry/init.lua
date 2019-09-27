local registry = {}

local terrainNames = {
	"soil"
}

registry.terrainByIndex = {}
registry.terrainByName = {}
for index, name in ipairs(terrainNames) do
	local newBlock = {index = index, name = name}
	for line in love.filesystem.lines("registry/terrain/" .. name) do
		if line[1] ~= "'" then -- Minimal comment functionality
			for word in line:gmatch("%S+") do
				
			end
		end
	end
	registry.terrainByIndex[index] = newBlock
	registry.terrainByName[name] = newBlock
end

registry.terrainCount = #registry.terrainByIndex




registry.entities = {}
registry.entities.testman = require("registry.entities.testman")

registry.items = {}
registry.items.sword = require("registry.items.sword")



return registry
