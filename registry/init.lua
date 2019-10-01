local forNameIn = require("fornamein")

local terrainNames = [[
	soil grass
]]
local entityNames = [[
	testman
]]
local itemNames = [[
	sword
]]

local registry = {}
registry.terrainByName, registry.terrainByIndex, registry.terrainCount = forNameIn("registry/terrain/", terrainNames,
	function(path, name, index)
		local ret = {name = name, index = index}
		for line in love.filesystem.lines(path) do
			local iterator = line:gmatch("%S+")
			local propertyName = iterator()
			local propertyType = iterator()
			if propertyType == "!" then -- Boolean
				ret[propertyName] = true
			elseif propertyType == "#" then -- Number
				local propertyValue = iterator()
				ret[propertyName] = tonumber(iterator())
			elseif word2 == "$" then -- String
				local propertyValue = iterator()
				ret[propertyName] = propertyValue
			end
		end
		return ret
	end,
	nil, true
)
local terrainClone = require("registry.terrainClone")
terrainClone.terrainByName, terrainClone.terrainByIndex, terrainClone.terrainCount = registry.terrainByName, registry.terrainByIndex, registry.terrainCount

registry.entities = forNameIn("registry.entities.", entityNames)
registry.items = forNameIn("registry.items.", itemNames)

return registry
