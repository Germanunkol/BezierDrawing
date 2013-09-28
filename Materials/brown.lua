-- material to be used in vessel construction

local function profile( dir, amount )
	local len = 1-amount
	local normal3D = dir*len
	return normal3D.x, normal3D.y, amount
end

local function specularFalloff( dir, amount )
	return 1*amount, 0.5*amount, 0.3*amount
end

local mat = {
	col = { r = 133, g=85, b=10, a=255 },
	profile = profile,
	profileDepth = 20,
	specular = { r = 255, g=155, b=60 },
	specularFalloff = specularFalloff,
}

return mat
