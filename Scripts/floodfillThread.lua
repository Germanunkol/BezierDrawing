------------------------------------------------
-- Rendering thread for creating filled images.
-------------------------------------------------
-- gets new shapes in the form:
-- ID{minX,minY,maxX,maxY}x1,y1|x2,y2|x3,y3| ...

require('love.image')
require('love.filesystem')
require('love.graphics')
require('love.timer')
require('Scripts/misc')
require('Scripts/point')

thisThread = love.thread.getThread()

local shapeQueue = {}
local lastTime = love.timer.getMicroTime()
local newTime --= love.timer.getMicroTime()

local newShape, ID, pos, boundingBox, pointList
local minX,minY,maxX,maxY
local tmpPoints
local seedFinishded,coveredPixels

local outCol = {
	r = 250,
	g = 250,
	b = 250,
	a = 250
}
local insCol = {
	r = 255,
	g = 255,
	b = 255,
	a = 255
}

thisThread:set("msg", "started")

local function split( str, sep )
	if str:sub( -1 ) ~= sep then
		str = str .. sep
	end
	return str:match((str:gsub("[^"..sep.."]*"..sep, "([^"..sep.."]*)"..sep)))
end

function sign( a )
	return ( a > 0 and 1 ) or ( a < 0 and -1 ) or 0
end

function drawLine( imgData, x1, y1, x2, y2 )
	--thisThread:set("msg", "line: " .. x1 .. " " .. y1 .. " " .. x2 .. " " .. y2 .. " ")
	
	local dx = x2-x1
	local dy = y2-y1
	local incrX = sign(dx)
	local incrY = sign(dy)
	dx = math.abs(dx)
	dy = math.abs(dy)
	local pdx, pdy, el, es, ddx, ddy

	if dx > dy then
		--/* x ist schnelle Richtung */
		pdx=incrX; pdy=0;    --/* pd. ist Parallelschritt */
		ddx=incrX; ddy=incrY; --/* dd. ist Diagonalschritt */
		es =dy;   el =dx;   --/* Fehlerschritte schnell, langsam */
	else
		--/* y ist schnelle Richtung */
		pdx=0;    pdy=incrY; --/* pd. ist Parallelschritt */
		ddx=incrX; ddy=incrY; --/* dd. ist Diagonalschritt */
		es =dx;   el =dy;   --/* Fehlerschritte schnell, langsam */
	end
	
	local x = x1
	local y = y1
	
	
	imgData:setPixel( x, y, outCol.r,outCol.g,outCol.b,outCol.a )
	local err = dx/2

	for t=0,el do
		--/* Aktualisierung Fehlerterm */
		err = err - es
		if err<0 then
			--/* Fehlerterm wieder positiv (>=0) machen */
			err = err + el;
			--/* Schritt in langsame Richtung, Diagonalschritt */
			x = x + ddx;
			y = y + ddy;
		else
			--/* Schritt in schnelle Richtung, Parallelschritt */
			x = x + pdx;
			y = y + pdy;
		end
      
		imgData:setPixel( x, y, outCol.r,outCol.g,outCol.b,outCol.a )
   end
end

function drawOutline( shape )
	shape.imageData = love.image.newImageData(
						shape.maxX - shape.minX + 10, shape.maxY - shape.minY + 10 )
						
	for k = 1, #shape.points-1 do
		drawLine( shape.imageData, shape.points[k].x, shape.points[k].y,
							shape.points[k+1].x, shape.points[k+1].y)
	end
end

function newScanlineSeed( shape, x, y )
	shape.seedList[#shape.seedList+1] = {
		x = x, y = y
	}
end

-- Fills a shape recursively. The function interupts itself after every
-- single line, so that other shapes can be worked on and communication
-- with the main thread doesn't stop. Will plant new seeds if the line
-- is finished processing.
function scanlineFill( shape, seed )
	local r,g,b,a, y

	local covered = 0
	if not seed.lineFilled then
		-- check towards the top
		
		r,g,b,a = shape.imageData:getPixel( seed.x, seed.y )
		if (a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b) then
			return
		end
		
		y = seed.y
		seed.minY = 0
		while y >= seed.minY do
			r,g,b,a = shape.imageData:getPixel( seed.x, y )
			if (a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b) then
				seed.minY = y
				break
			end
			shape.imageData:setPixel( seed.x, y, insCol.r,insCol.g,insCol.b,insCol.a )
			y = y - 1
			covered = covered + 1
		end
		
		y = seed.y
		seed.maxY = shape.imageData:getHeight()-1
		while y <= seed.maxY do
			r,g,b,a =shape.imageData:getPixel( seed.x, y )
			if (a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b) then
				seed.maxY = y
				break			
			end
			shape.imageData:setPixel( seed.x, y, insCol.r,insCol.g,insCol.b,insCol.a )
			y = y + 1
			covered = covered + 1
		end
		
		seed.lineFilled = true
		
	
	-- Next, scan the neighbouring lines on the left and right side:
	-- (first up, then down)
	elseif not seed.leftCheckedUp then
		if seed.x > 0 then
			y = seed.currentLeftUp or seed.y
			while y > seed.minY do
				r,g,b,a = shape.imageData:getPixel( seed.x - 1, y )
				if a == 0 then
					newScanlineSeed( shape, seed.x - 1, y )
					seed.currentLeftUp = y
					break			
				end
				y = y - 1
			end
		else
			y = seed.minY
		end
		if y <= seed.minY then
			seed.leftCheckedUp = true
		end
	elseif not seed.leftCheckedDown then
		if seed.x > 0 then
			y = seed.currentLeftDown or seed.y
			while y < seed.maxY do
				r,g,b,a = shape.imageData:getPixel( seed.x - 1, y )
				if a == 0 then
					newScanlineSeed( shape, seed.x - 1, y )
					seed.currentLeftDown = y
					break			
				end
				y = y + 1
			end
		else
			y = seed.maxY
		end
		if y >= seed.maxY then
			seed.leftCheckedDown = true
		end
	elseif not seed.rightCheckedUp then
		if seed.x < shape.imageData:getWidth()-1 then
			y = seed.currentRightUp or seed.y
			while y > seed.minY do
				r,g,b,a = shape.imageData:getPixel( seed.x + 1, y )
				if a == 0 then
					newScanlineSeed( shape, seed.x + 1, y )
					seed.currentRightUp = y
					break			
				end
				y = y - 1
			end
		else
			y = seed.minY
		end
		if y <= seed.minY then
			seed.rightCheckedUp = true
		end
	elseif not seed.rightCheckedDown then
		if seed.x < shape.imageData:getWidth()-1 then
			y = seed.currentRightDown or seed.y
			while y < seed.maxY do
				r,g,b,a = shape.imageData:getPixel( seed.x + 1, y )
				if a == 0 then
					newScanlineSeed( shape, seed.x + 1, y )
					seed.currentRightDown = y
					break			
				end
				y = y + 1
			end
		else
			y = seed.maxY
		end
		if y >= seed.maxY then
			seed.rightCheckedDown = true
			return true		-- done, checked in all directions!
		end
	end
	
	return false, covered
end

-- This function repeats the ray-cast algorithm in 4 directions,
-- because one-pixel-wide lines can make the single ray unprecise.
-- The case where the border of the shape lies on the edge of the
-- image can be discared: it can never happen because the shape is
-- padded by a few pixels in all directions (phew!)
function isInsideShape( shape, x, y )
	if x < 0 or x > shape.imageData:getWidth() - 1 or 
		y < 0 or y > shape.imageData:getHeight() - 1 then
			thisThread:set("msg", 0)
		return false
	end
	
	local r,g,b,a = shape.imageData:getPixel( x, y )
	
	-- On outline? Then return false - not inside shape!
	if (a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b) then
			thisThread:set("msg", 1)
		return false
	end
	
	local iterations = 0
	local intersectionsUp = 0
	local lastWasOnLine, thisIsOnLine = false, false
	for y1 = y-1,0,-1 do	-- move upwards and check the intersections
		thisIsOnLine = false
		r,g,b,a = shape.imageData:getPixel( x, y1 )
		if (a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b) then
			thisIsOnLine = true
		end
		
		if lastWasOnLine and not thisIsOnLine then
			intersectionsUp = intersectionsUp + 1
		end
		iterations = iterations +1
		--thisThread:set("msg", iterations .. " " .. tostring(lastWasOnLine) .. " " .. tostring(thisIsOnLine))
		--os.execute("sleep .1")
		lastWasOnLine = thisIsOnLine
	end
		thisThread:set("msg", "intersectionsUp: " .. intersectionsUp)
		os.execute("sleep .1")
	
	local intersectionsDown = 0
	lastWasOnLine, thisIsOnLine = false, false
	for y1 = y+1,shape.imageData:getHeight()-1,1 do	-- move downwards and check the intersections
		thisIsOnLine = false
		r,g,b,a = shape.imageData:getPixel( x, y1 )
		if (a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b) then
			thisIsOnLine = true
		end
		
		if lastWasOnLine and not thisIsOnLine then
			intersectionsDown = intersectionsDown + 1
		end
		
		lastWasOnLine = thisIsOnLine
	end
	
	local intersectionsLeft = 0
	lastWasOnLine, thisIsOnLine = false, false
	for x1 = x-1,0,-1 do	-- move left and check the intersections
		thisIsOnLine = false
		r,g,b,a = shape.imageData:getPixel( x1, y )
		if (a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b) then
			thisIsOnLine = true
		end
		
		if lastWasOnLine and not thisIsOnLine then
			intersectionsLeft = intersectionsLeft + 1
		end
		
		lastWasOnLine = thisIsOnLine
	end
	
	local intersectionsRight = 0
	lastWasOnLine, thisIsOnLine = false, false
	for x1 = x+1,shape.imageData:getWidth()-1,1 do	-- move right and check the intersections
		thisIsOnLine = false
		r,g,b,a = shape.imageData:getPixel( x1, y )
		if (a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b) then
			thisIsOnLine = true
		end
		
		if lastWasOnLine and not thisIsOnLine then
			intersectionsRight = intersectionsRight + 1
		end
		
		lastWasOnLine = thisIsOnLine
	end
	
	if intersectionsUp % 2 == 1 and intersectionsDown % 2 == 1 and
		intersectionsLeft % 2 == 1 and intersectionsRight % 2 == 1 then
		return true
	end
			thisThread:set("msg", intersectionsUp .. " " .. intersectionsDown .. " " .. intersectionsLeft .. " " .. intersectionsRight)
	return false
end



function checkShapeThickness( shape )
	if not shape.thickness then
		shape.thickness = {}
		--shape.thickness
	end

end


-- Make sure shape is oriented counter-clockwise!!
function correctShapeDirection( shape )

	local checked = false
	local needsTurning = false
	local dir, normal1, normal2, len
	
	local k = 1
	while not checked and k < #shape.points-1 do
		dir = shape.points[k+1] - shape.points[k]
	
		normal1 = Point:new( -dir.y, dir.x )
		len = normal1:getLength()
		normal1 = normal1*(3/len)	-- normalize to 3 pixels!
		
		normal2 = Point:new( dir.y, -dir.x )
		len = normal2:getLength()
		normal2 = normal2*(3/len)	-- normalize to 3 pixels!
		
		isInside1 = isInsideShape( shape,
					shape.points[k].x + normal1.x, shape.points[k].y + normal1.y )
		
		isInside2 = isInsideShape( shape,
					shape.points[k].x + normal2.x, shape.points[k].y + normal2.y )
					
		if isInside1 and not isInside2 then
			checked = true
		elseif not isInside1 and isInside2 then		-- the wrong normal is inside!!
			checked = true
			needsTurning = true
		end
		k = k+1
	end
	
	-- If the check above returned that the shape was clockwise, 
	-- then turn it around to now be counter-clockwise.
	if needsTurning then
		local newList = {}
		for k = 1, #shape.points do
			newList[k] = shape.points[#shape.points + 1 - k]
		end
		shape.points = newList
	end
end

function drawNormals( shape )

	local dir, normal, len, endPoint
	for k = 1, #shape.points-1 do
	
		dir = shape.points[k+1] - shape.points[k]
	
		normal = Point:new( -dir.y, dir.x )
		--len = normal1:getLength()
		--normal1 = normal1*(3/len)	-- normal
		
		endPoint = normal+shape.points[k]
		
		drawLine( shape.imageData, shape.points[k].x, shape.points[k].y, endPoint.x, endPoint.y)
	end
end
	
function runThread()
	while true do
		newTime = love.timer.getMicroTime()
		dt = newTime - lastTime
		lastTime = newTime
	
		-- Check if there's a new shape in the queue. If so, put it in a table to process later:
		newShape = thisThread:get("newShape")
		if newShape then
			pos = newShape:find( "{" )
			if pos then
				ID = newShape:sub( 1, pos - 1 )
				newShape = newShape:sub( pos + 1 )
				pos = newShape:find( "}" )
				minX,minY,maxX,maxY = split(newShape:sub(1, pos-1), ",")
				minX,minY,maxX,maxY = tonumber(minX),tonumber(minY),tonumber(maxX),tonumber(maxY)
				-- minX,minY,maxX,maxY = math.floor(minX),math.floor(minY),math.floor(maxX),math.floor(maxY)

				pointList = newShape:sub(pos+1)
			
				--tmpPoints = {split(pointList, "|")}
			
				tmpPoints = {}
				pos = pointList:find("|")
				while pos do
					tmpPoints[#tmpPoints + 1] = pointList:sub(1, pos-1)
					pointList = pointList:sub( pos+1 )
					pos = pointList:find("|")
				end
			
				-- disregard any earlier rendering for this shape:
				shapeQueue[ID] = {
					percent = 0,
					minX = minX,
					minY = minY,
					maxX = maxX,
					maxY = maxY,
					points = {},
					seedList = {},
					currentLine = 0,
					pixelsFilled = 0,
				}
			
			
				for k = 1, #tmpPoints do
					shapeQueue[ID].points[k] = Point:new( split(tmpPoints[k], ",") )
					shapeQueue[ID].points[k].x = tonumber( shapeQueue[ID].points[k].x ) - minX + 5
					shapeQueue[ID].points[k].y = tonumber( shapeQueue[ID].points[k].y ) - minY + 5
					shapeQueue[ID].points[k].x = math.floor( shapeQueue[ID].points[k].x )
					shapeQueue[ID].points[k].y = math.floor( shapeQueue[ID].points[k].y )
				end
			
			
				msg = "New shape for: " .. ID ..
					" " .. minX .. 
					" " .. minY .. 
					" " .. maxX .. 
					" " .. maxY ..
					"\n\tnumPoints:" .. #shapeQueue[ID].points
				thisThread:set("msg", msg)
			
				drawOutline(shapeQueue[ID])
			
				shapeQueue[ID].width = shapeQueue[ID].imageData:getWidth()
				shapeQueue[ID].height = shapeQueue[ID].imageData:getHeight()
				shapeQueue[ID].pixels = (shapeQueue[ID].width-10)*(shapeQueue[ID].height-10)
			
				-- Find starting point inside shape. Choose random point and check if it's inside.
				local a,b
				repeat			
					a = math.random(0, shapeQueue[ID].width-1)
					b = math.random(0, shapeQueue[ID].height-1)
				until isInsideShape( shapeQueue[ID], a, b )
			
				shapeQueue[ID].seedList[1] = {
					x = a,
					y = b,
				}
				
				correctShapeDirection( shapeQueue[ID] )
				drawNormals( shapeQueue[ID] )
			end
		end
	
		for ID, s in pairs(shapeQueue) do
			seeds = shapeQueue[ID].seedList
			seedFinishded, coveredPixels = scanlineFill( s, seeds[#seeds] )
			if seedFinishded then
				seeds[#seeds] = nil -- remove last seed!
			end
		
			if coveredPixels then
				s.pixelsFilled = s.pixelsFilled + coveredPixels
				thisThread:set(ID .. "(%)", math.floor(100*s.pixelsFilled/shapeQueue[ID].pixels))
			end
		
			if #seeds == 0 then
				thisThread:set( "msg", "Done: " .. ID )
				thisThread:set( ID .. "(img)", s.imageData )
				shapeQueue[ID] = nil
			end
		end
	end
end


runThread()		-- start the whole process

