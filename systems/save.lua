local json = require("lib.json")
local warn = require("systems.warn")

local function save(world)
	local info = love.filesystem.getInfo("saves")
	if not info then
		print("Couldn't find saves folder. Creating")
		love.filesystem.createDirectory("saves")
	elseif info.type ~= "directory" then
		-- TODO: UX(?)
		warn("There is already a non-folder item called saves. Rename it or move it to save a world")
		return
	end
	
	local current = 0
	for _, foldername in pairs(love.filesystem.getDirectoryItems("saves")) do
		if string.match(foldername, "^%d+$") then
			current = math.max(current, tonumber(foldername))
		end
	end
	
	local path = current + 1
	
	if not love.filesystem.createDirectory("saves/" .. path) then
		return -- I think it'd be deliberate if you made a directory between here and that loop, so no need to say anything
	end
	
	do
		-- Chunks
		local ret, lenRet = {}, 0
		for _, chunk in pairs(world.chunksById) do
			ret[lenRet + 1] = string.char(chunk.x)
			ret[lenRet + 2] = string.char(chunk.y)
			ret[lenRet + 3] = string.char(chunk.z)
			ret[lenRet + 4] = chunk.terrain
			ret[lenRet + 5] = chunk.metadata
			lenRet = lenRet + 5
		end
		
		local success, message = love.filesystem.write("saves/" .. path .. "/chunks.bin", table.concat(ret))
		if not success then
			warn("Error saving to " .. path .. ": " .. message)
			return
		end
	end
	
	return true
end

return save
