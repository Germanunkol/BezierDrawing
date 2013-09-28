-- material to be used in vessel construction

local function profile( dir, amount )
	return 0,0,1
end

local mat = {
	col = { r = 150, g=150, b=170, a=200 },
	profile = profile,
	profileDepth = 0,
}

return mat
