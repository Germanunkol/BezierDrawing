-- material to be used in vessel construction

local function profile( dir, amount )
	return 0,0,-1
end

local mat = {
	col = { r = 116, g=133, b=3, a=200 },
	profile = profile,
	profileDepth = 0,
}

return mat
