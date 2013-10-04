-- material to be used in vessel construction

local function profile( dir, amount )
	local normal3D
	if amount > 0.8 then
		dir = dir*(1 - (amount - 0.8)*(amount - 0.8)*30)
	end
	return dir.x, dir.y, amount
end

local function profileSpecular( dir, amount )
	if amount > 0.8 then
		return 190,255,255
	else
		return 155, 200, 200
	end
end

local function pattern( x, y )
	return 255,255,255,255
end

local function patternNormal( x, y )
	return 0,0,1
end

local function patternSpecular( x, y )
	local amount = math.random(64) + 190
	return amount, amount, amount, 255
end

local mat = {
	-- fallback color: will only be used if no "pattern" function is specified:
	col = { r = 50, g=50, b=50, a=255 },
	-- profile function:
	profile = profile,
	profileDepth = 10,
	specular = { r = 155, g=200, b=200 },
	profileSpecular = profileSpecular,
	patternWidth = 20,
	patternHeight = 30,
	pattern = pattern,
	--patternNormal = patternNormal,
	--patternSpecular = patternSpecular,
}

return mat
