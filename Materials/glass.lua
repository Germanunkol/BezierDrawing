-- material to be used in vessel construction

local mat = {
	-- fallback color: will only be used if no "pattern" function is specified:
	colDiffuse = { r = 100, g=130, b=250, a=200 },
	-- specular color will be used for the full shape unless patternSpecular is defined:
	colSpecular = { r = 255, g=255, b=255 },
	
	-- profile:
	edgeDepth = 1,		-- how far each edge reaches into the shape
	--edgeNormal = edgeNormal,
	--edgeSpecular = edgeSpecular,
	edgeDiffuse = function()
			return 200,200,250
		end,
	
	-- pattern repeated over the full shape:
	--patternWidth = 20,
	--patternHeight = 30,
	--patternDiffuse = patternDiffuse,
	--patternNormal = patternNormal,
	--patternSpecular = patternSpecular,
	tiltable = true,
}

return mat
