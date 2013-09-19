------------------------------------------------
-- Rendering thread for creating filled images.
-------------------------------------------------
-- gets new shapes in the form:
-- ID{minX,minY,maxX,maxY}x1,y1|x2,y2|x3,y3| ...

require('love.image')
require('love.filesystem')
require('love.graphics')
require('love.timer')
thisThread = love.thread.getThread()

local shapeQueue = {}
local lastTime = love.timer.getMicroTime()
local newTime --= love.timer.getMicroTime()

local newShape, ID, pos, boundingBox, pointList
local minX,minY,maxX,maxY
local tmpPoints
local seedFinishded

local outCol = {
	r = 255,
	g = 120,
	b = 50,
	a = 180
}
local insCol = {
	r = 170,
	g = 170,
	b = 255,
	a = 120
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

function fill( shape, x )
	local inside = false
	local lastPixelWasSet, thisPixelIsSet = false, false
	local r,g,b,a

	local firstHit = false

	for y = 0, shape.imageData:getHeight()-1 do
		
		thisPixelIsSet = false
		
		
		--os.execute("sleep .1")
		r,g,b,a = shape.imageData:getPixel( x, y )
		
		if a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b then
			thisPixelIsSet = true
			if not firstHit then	-- remember where the first hit occurred
				firstHit = y
			end
		end
		
		if lastPixelWasSet then
			if not thisPixelIsSet then		-- change from last pixel!
				inside = not inside
			end
		end
		
		if inside and not thisPixelIsSet then
			shape.imageData:setPixel( x, y, insCol.r,insCol.g,insCol.b,insCol.a )
		end
		
		lastPixelWasSet = thisPixelIsSet
		
		-- If we end up at the bottom and the algo says we're still "inside", then something went
		-- wrong. Invert until we get back to the first hit!
		if y == shape.imageData:getHeight()-1 then
			if inside and firstHit then
				for y2 = y,firstHit, -1 do
					r,g,b,a = shape.imageData:getPixel( x, y2 )
					if r == insCol.r and g == insCol.g and b == insCol.b and a == insCol.a then
						shape.imageData:setPixel( x, y2, 0,0,0,0 )
					elseif a == 0 then
						shape.imageData:setPixel( x, y, insCol.r,insCol.g,insCol.b,insCol.a )
					elseif  a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b then
						break
					end
					
				end
			end
		end
	end
end


function fill( shape, x )
	local inside = false
	local lastPixelWasSet, thisPixelIsSet = false, false
	local r,g,b,a

	local firstHit = false

	for y = 0, shape.imageData:getHeight()-1 do
		
		thisPixelIsSet = false
		
		
		--os.execute("sleep .1")
		r,g,b,a = shape.imageData:getPixel( x, y )
		
		if a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b then
			thisPixelIsSet = true
			if not firstHit then	-- remember where the first hit occurred
				firstHit = y
			end
		end
		
		if lastPixelWasSet then
			if not thisPixelIsSet then		-- change from last pixel!
				inside = not inside
			end
		end
		
		if inside and not thisPixelIsSet then
			shape.imageData:setPixel( x, y, insCol.r,insCol.g,insCol.b,insCol.a )
		end
		
		lastPixelWasSet = thisPixelIsSet
		
		-- If we end up at the bottom and the algo says we're still "inside", then something went
		-- wrong. Invert until we get back to the first hit!
		if y == shape.imageData:getHeight()-1 then
			if inside and firstHit then
				for y2 = y,firstHit, -1 do
					r,g,b,a = shape.imageData:getPixel( x, y2 )
					if r == insCol.r and g == insCol.g and b == insCol.b and a == insCol.a then
						shape.imageData:setPixel( x, y2, 0,0,0,0 )
					elseif a == 0 then
						shape.imageData:setPixel( x, y, insCol.r,insCol.g,insCol.b,insCol.a )
					elseif  a == outCol.a and r == outCol.r and g == outCol.g and b == outCol.b then
						break
					end
					
				end
			end
		end
	end
end

function newScanlineSeed( shape, x, y )
	shape.seedList[#shape.seedList+1] = {
		x = x, y = y
	}
end

function scanlineFill( shape, seed )
	local r,g,b,a, y

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
		end
		
		seed.lineFilled = true
	
	-- Next, scan the neighbouring lines on the left and right side:
	-- (first up, then down)
	elseif not seed.leftCheckedUp then
		thisThread:set("msg", "a" )
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
		thisThread:set("msg", "b" )
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
		thisThread:set("msg", "c" )
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
		if y >= seed.minY then
			thisThread:set("msg", "d" )
			seed.rightCheckedDown = true
			return true		-- done, checked in all directions!
		end
	end
	
	return false
end

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
			}
			
			
			for k = 1, #tmpPoints do
				shapeQueue[ID].points[k] = {}
				shapeQueue[ID].points[k].x, shapeQueue[ID].points[k].y
							= split(tmpPoints[k], ",")
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
			
			shapeQueue[ID].seedList[1] = {
				x = shapeQueue[ID].points[1].x-3,
				y = shapeQueue[ID].points[1].y-3,
			}
		end
	end
	
	for ID, s in pairs(shapeQueue) do
	
		--[[fill( s, s.currentLine )
		s.currentLine = s.currentLine + 1
		
		s.percent = 100 * ( s.width - s.currentLine) / s.width
		thisThread:set(ID .. "(%)", s.percent)
		
		
		]]--
		--if s.currentLine >= s.width then
		seeds = shapeQueue[ID].seedList
		seedFinishded = scanlineFill( s, seeds[#seeds] )
		if seedFinishded then
			if #seeds == 1 then
				s.imageData:setPixel( seeds[1].x, seeds[1].y, 255,0,0,255)
				s.imageData:setPixel( seeds[1].x+1, seeds[1].y+1, 255,0,0,255)
				s.imageData:setPixel( seeds[1].x-1, seeds[1].y-1, 255,0,0,255)
			end
			seeds[#seeds] = nil -- remove last seed!
		end
		thisThread:set("msg", #seeds)
		if #seeds == 0 then
			thisThread:set( "msg", "Done: " .. ID )
			thisThread:set( ID .. "(img)", s.imageData )
			shapeQueue[ID] = nil
		end
	end
end


