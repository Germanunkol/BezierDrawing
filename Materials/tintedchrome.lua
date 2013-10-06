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
		return 255,190,190, 50
	end
end

local function patternSpecular( dir, amount )
	local r = math.random(50)
	return 200-r,200-r,200-r
end

local mat = {
	-- fallback color: will only be used if no "pattern" function is specified:
	colDiffuse = { r = 255, g=150, b=100, a=255 },
	-- specular color will be used for the full shape unless patternSpecular is defined:
	--colSpecular = { r = 200, g=155, b=155 },
	
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
