local forNameIn = require("fornamein")

local terrainNames = [[
	soil grass
	stone
]]
local entityNames = [[
	testman
]]

local registry = {}
registry.terrainByName, registry.terrainByIndex = forNameIn("registry.terrain.", terrainNames,
	function(path, name, index)
		local ret = require(path)
		ret.name = name
		ret.index = index
		return ret
	end,
	nil, true
)
local air = {name = "air", index = 0, invisible = true}
registry.terrainByName.air, registry.terrainByIndex[0] = air, air
local terrainClone = require("registry.terrainClone")
terrainClone.terrainByName, terrainClone.terrainByIndex = registry.terrainByName, registry.terrainByIndex

registry.entities = forNameIn("registry.entities.", entityNames)

return registry
