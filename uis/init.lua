local names = {"plainPause"}
local uis = {}

for _, name in ipairs(names) do
	uis[name] = require("uis." .. name)
end

return uis
