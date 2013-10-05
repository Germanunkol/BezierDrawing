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
		return 190,255,255,255
	end
end

local mat = {
	-- fallback color: will only be used if no "pattern" function is specified:
	colDiffuse = { r = 50, g=50, b=50, a=255 },
	-- specular color will be used for the full shape unless patternSpecular is defined:
	colSpecular = { r = 155, g=200, b=200 },
	
	-- profile:
	edgeDepth = 15,		-- how far each edge reaches into the shape
	edgeNormal = edgeNormal,
	edgeSpecular = edgeSpecular,
	
	-- pattern repeated over the full shape:
	--patternWidth = 20,
	--patternHeight = 30,
	--patternDiffuse = patternDiffuse,
	--patternNormal = patternNormal,
	--patternSpecular = patternSpecular,
}

return mat
