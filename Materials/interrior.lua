-- material to be used in vessel construction

local function edgeNormal( dir, amount )
	if amount >= 0.5 then
		return -dir.x, -dir.y, 0.1
	else
		return 0,0,-1
	end
	--return 0,0,1
end

function edgeDiffuse( dir, amount )
	return 255,255,255,255
end

local function patternDiffuse( dx, dy )
	if (dx >= 0.45 and dx <= 0.55) or (dy >= 0.45 and dy <= 0.55) then
		if dx == 0.5 or dy == 0.5 then
			return 150,150,150,255
		end
		return 255,255,255,255
	else
		return 230,230,230,255
	end
end

local function patternSpecular( dx, dy )
	if (dx >= 0.45 and dx <= 0.55) or (dy >= 0.45 and dy <= 0.55) then
		if dx == 0.5 or dy == 0.5 then
			return 50,50,50,255
		end
		return 150,150,150,255
	else
		return 100,100,80,100
	end
end

local function patternNormal( dx, dy )
	if (dx >= 0.45 and dx <= 0.5) then
		return 1,0,1
	elseif (dx >= 0.5 and dx <= 0.55) then
		return -1,0,1
	elseif (dy >= 0.45 and dy <= 0.5) then
		return 0,-1,1
	elseif (dy >= 0.5 and dy <= 0.55) then
		return 0,1,1
	else
		return 0,0,1
	end
end

local mat = {
	-- fallback color: will only be used if no "pattern" function is specified:
	colDiffuse = { r = 255, g=255, b=255, a=255 },
	-- specular color will be used for the full shape unless patternSpecular is defined:
	colSpecular = { r = 100, g=100, b=100 },
	
	-- profile:
	edgeDepth = 6,		-- how far each edge reaches into the shape
	edgeNormal = edgeNormal,
	edgeDiffuse = edgeDiffuse,
	
	-- pattern repeated over the full shape:
	patternWidth = 20,
	patternHeight = 20,
	patternDiffuse = patternDiffuse,
	--patternNormal = patternNormal,
	patternSpecular = patternSpecular,
}

return mat
