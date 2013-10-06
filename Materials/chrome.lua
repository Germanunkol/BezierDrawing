-- material to be used in vessel construction

local function edgeNormal( dir, amount )
	local normal3D
	if amount > 0.8 then
		dir = dir*(1 - (amount - 0.8)*(amount - 0.8)*30)
	end
	return dir.x, dir.y, amount
end

local function edgeSpecular( dir, amount )
	if amount > 0.8 then
		return 190,255,255, 50
	end
end

local function patternSpecular( dir, amount )
	local r = math.random(50)
	return 155-r,200-r,200-r
end

local mat = {
	-- fallback color: will only be used if no "pattern" function is specified:
	colDiffuse = { r = 255, g=255, b=255, a=255 },
	-- specular color will be used for the full shape unless patternSpecular is defined:
	--colSpecular = { r = 155, g=200, b=200 },
	
	-- profile:
	edgeDepth = 4,		-- how far each edge reaches into the shape
	edgeNormal = edgeNormal,
	edgeSpecular = edgeSpecular,
	
	-- pattern repeated over the full shape:
	patternWidth = 5,
	patternHeight = 5,
	--patternDiffuse = patternDiffuse,
	--patternNormal = patternNormal,
	patternSpecular = patternSpecular,
}

return mat
