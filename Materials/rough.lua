-- material to be used in vessel construction

local function profile( dir, amount )
	local len = 1-amount
	local normal3D = dir
	return normal3D.x, normal3D.y, amount
end

local function specularFalloff( dir, amount )
	return 1*amount, 0.5*amount, 0.3*amount
end

local function pattern( x, y )
	return math.random(255), math.random(255), math.random(255)
end

local function patternNormal( x, y )
	return 0,0,1
end

local function patternSpecularity( x, y )
	if x > 0.5 and y > 0.5 then
		return 0.5,0,0.5
	else
		return 0,0,1
	end
end

local mat = {
	-- fallback color: will only be used if no "pattern" function is specified:
	col = { r = 50, g=50, b=50, a=255 },
	-- profile function:
	profile = profile,
	profileDepth = 300,
	specular = { r = 255, g=155, b=60 },
	specularFalloff = specularFalloff,
	patternWidth = 20,
	patternHeight = 30,
	pattern = pattern,
	patternNormal = patternNormal,
	patternSpecularity = patternSpecularity,
}

return mat
