-- For name in...

return function(prepend, names, func, append, passNameAndI)
	func = func or require -- Perhaps love.graphics.newImage?
	append = append or "" -- Perhaps "".png"?
	local nameRet, indexRet = {}, {}
	local i = 0
	for name in names:gmatch("%S+") do
		i = i + 1
		local x
		if passNameAndI then
			x = func(prepend .. name .. append, name, i)
		else
			x = func(prepend .. name .. append)
		end
		nameRet[name] = x
		indexRet[i] = x
	end
	return nameRet, indexRet, i
end
