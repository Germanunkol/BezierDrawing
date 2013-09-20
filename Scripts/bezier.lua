----------------------------------------------------------------
-- Bezier curve Library by Micha Pfeiffer
----------------------------------------------------------------
-- Use however you want to, but at your own risk.

------------------------------------------------
-- Usage:
--	cPoints: List of construction points
--	segmentLength: will keep subdividing until the drawn lines are not longer than segmentLength
--	width: line width to draw the line with.
--	Example: curve = Bezier:new( {{x=10,y=20},{x=20,y=40},{x=30,y=50}}, 10, 2)
------------------------------------------------


require("Scripts/middleclass")
require("Scripts/misc")
require("Scripts/shapeCollisions")

Bezier = class('Bezier')

local clickRadius = 15
local gridSize = 30

function Bezier:initialize( cPoints, segmentAngle, width )
	self.cPoints = cPoints
	self.numCPoints = #cPoints
	
	for k, p in pairs(cPoints) do
		p:addCurve( self )
	end
	
	self:setSegmentAngle( segmentAngle or 5 )

	self.lineWidth = width or 2
	
	self.boundingBox = {}
	self:update()
	--self:setModified()
end

function Bezier:print()
	local str = "Bezier curve:\n"
	for k = 1, self.numCPoints do
		str = str .. "\t" .. "{" .. self.cPoints[k].x .. "," .. self.cPoints[k].y .. "}\n" 
	end
	print(str)
end

local function debugPrintCoefficients( tbl, n )
	local str
	for i=1,n do
		str = ""
		for j=1,n do
			str = str .. (tbl[i][j] and tbl[i][j].x or "-") .. " "
		end
		print(str)
	end
end

local function tableConcat( A, B )
	local C = {}
	for k,v in ipairs(A) do
		C[#C + 1] = v
	end
	for k,v in ipairs(B) do
		C[#C + 1] = v
	end
	return C
end

local function split( points, t )

	local tbl = {}
	local n = #points
	for i = 1,n do
		tbl[i] = {}
		tbl[i][1] = points[i]
	end

	local size = {}
	local x, y	
	for j = 2,n+1 do
		for i = 1,n-j+1 do
			x = tbl[i][j-1].x*(1-t) + tbl[i+1][j-1].x*t
			y = tbl[i][j-1].y*(1-t) + tbl[i+1][j-1].y*t
			
			tbl[i][j] = {x=x, y=y}
		end
	end
	
	local first, second = {},{}
	local firstSegLength, secondSegLength = 0, 0
	local dist
	for j=1,n do
		first[j] = tbl[1][j]
		second[n-j+1] = tbl[n-j+1][j]
	end
	return first, second
end

local function subdivideRecursive( points, t, segmentAngle )
	local first, second = split( points, t )
	
	local firstSegLength, secondSegLength = 0, 0
	local firstMinAng, secondMinAng = math.huge, math.huge
	first.length, second.length = 0, 0
	local dist
	
	segmentAngle = segmentAngle or deg2rad(5)
	--local segmentAngle = math.pi*segmentAngle/180
	
	local n = #points
	--[[
	for j=1,n do
		-- check how long the line segments are:
		if first[j-1] then
			dist = distance(first[j-1], first[j])
			if dist > firstSegLength then
				firstSegLength = dist
			end
			first.length = first.length + dist -- sum up length of line
		end
		if second[n-j+2] then
			dist = distance(second[n-j+1], second[n-j+2])
			if dist > secondSegLength then
				secondSegLength = dist
			end
			second.length = second.length + dist -- sum up length of line
		end
	end
	]]--
	local ang
	for j=1,n-1 do
		-- check the angle between line segments:
			ang = 0
			if first[j] and first[j+1] and first[j+2] then
				ang = angBetweenPoints(first[j], first[j+1], first[j+2])
			end
			first[j+1].ang = ang
			if math.abs(math.pi/2 - ang) < firstMinAng then
				firstMinAng = math.abs(math.pi/2 - ang)
			end
			dist = distance(first[j], first[j+1])
			first.length = first.length + dist -- sum up length of line
			
			ang = 0
			if second[j] and second[j+1] and second[j+2] then
				ang = angBetweenPoints(second[j], second[j+1], second[j+2])
			end
			if math.abs(math.pi/2 - ang) < secondMinAng then
				secondMinAng = math.abs(math.pi/2 - ang)
			end
			dist = distance(second[n-j], second[n-j+1])
			second.length = second.length + dist -- sum up length of line
	end
		if firstMinAng < math.pi/2 - segmentAngle then
			first = subdivideRecursive( first, t, segmentAngle )
		end
		if secondMinAng < math.pi/2 - segmentAngle then
			second = subdivideRecursive( second, t, segmentAngle )
		end
	
	local fullLine = tableConcat(first, second)
	fullLine.length = first.length + second.length
	return fullLine
end

function Bezier:setSegmentAngle( l )
	if not tonumber( l ) then
		l = 5
	end
	self.segmentAngle = tonumber( l  )
	-- self:update()	-- rerender points
	self:setModified()
end

function Bezier:getSegmentAngle( )
	return self.segmentAngle
end

function Bezier:setLineWidth( width )
	self.lineWidth = width or 2
end

function Bezier:removeDoubles()
	local toRemove = {}
	
	--local remember = #self.points
	-- find all doubles:
	for k = 1, #self.points-1 do
		--if self.points[k].x == self.points[k+1].x and
			--self.points[k].y == self.points[k+1].y then
		if distance(self.points[k], self.points[k+1]) < 0.01 then
			toRemove[#toRemove + 1] = k	-- save key to remove later
		end
	end
	
	-- remove all doubles:
	for i = 1, #toRemove do
		removeFromTbl( self.points, self.points[toRemove[i]] )
	end	
end

function Bezier:calcBoundingBox()
	self.boundingBox.minX, self.boundingBox.minY = math.huge, math.huge
	self.boundingBox.maxX, self.boundingBox.maxY = -math.huge, -math.huge
	
	for k = 1, #self.points do
		self.boundingBox.minX = math.min( self.points[k].x, self.boundingBox.minX )
		self.boundingBox.minY = math.min( self.points[k].y, self.boundingBox.minY )
		self.boundingBox.maxX = math.max( self.points[k].x, self.boundingBox.maxX )
		self.boundingBox.maxY = math.max( self.points[k].y, self.boundingBox.maxY )
	end
end

function Bezier:getBoundingBox()
	return self.boundingBox
end

function Bezier:setModified()
	self.modified = true
end

function Bezier:getModified()
	return self.modified
end

function Bezier:update()
	-- Stay a line unless the intermediate points have been moved manually:
	if not self.cPoints[2].hasBeenMoved and not self.cPoints[3].hasBeenMoved then
		self.cPoints[2]:interpolate( self.cPoints[1], self.cPoints[4], 0.25 )
		self.cPoints[3]:interpolate( self.cPoints[1], self.cPoints[4], 0.75 )
	end

	-- Subdivide curve until all segments are smoothed out:
	self.points = subdivideRecursive( self.cPoints, 0.5, deg2rad(self.segmentAngle) )
	self.length = self.points.length
	
	self:removeDoubles()
	
	if self.points[#self.points] ~= self.cPoints[#self.cPoints] then
		self.points[#self.points+1] = self.cPoints[#self.cPoints]
	end
	
	self:calcBoundingBox()
	self.modified = false
end

function Bezier:splitCurveAt( t )
	local first, second = split( self.cPoints, t)
	self:removeDoubles()
	
	-- define corner for the point which connects the two lines:
	local newCorner = Corner:new( first[#first].x, first[#first].y )
	first[#first] = newCorner
	second[1] = newCorner
	
	return first, second, newCorner
end

function Bezier:draw( active, closed )

	love.graphics.setLineWidth( math.max( self.lineWidth/cam:getZoom(), 1) )
	love.graphics.setLineStyle("smooth")
	love.graphics.setPointStyle("smooth")
	
	if closed then
		love.graphics.setColor(225,255,225, 255)
	else
		love.graphics.setColor(255,255,255, 255)
	end
	for k=1,#self.points-1 do
		love.graphics.line( self.points[k].x, self.points[k].y, self.points[k+1].x, self.points[k+1].y )
		--if self.points[k].ang then
			--love.graphics.print( round(self.points[k].ang, 1), self.points[k].x, self.points[k].y)
		--end
	end
	
	if active then
		--love.graphics.setLineWidth( math.max( self.lineWidth/cam:getZoom(), 1) )
		love.graphics.setColor(255,120,50, 75)

		for k = 1, self.numCPoints-1 do
			love.graphics.line(self.cPoints[k].x, self.cPoints[k].y, self.cPoints[k+1].x, self.cPoints[k+1].y)
		end
	
		for k = 2, self.numCPoints-1 do
			if k == self.selected then
				love.graphics.setPointSize( 6 )
				love.graphics.setColor(255,120,50, 255)
			else
				love.graphics.setPointSize( 4 )
				love.graphics.setColor(255,180,100, 255)
			end
			love.graphics.point( self.cPoints[k].x, self.cPoints[k].y )
		end
	end
	
	love.graphics.setColor(255,255,255,255)
end

function Bezier:checkHit( clickPoint, ignore )		-- check if the click landed on a construction Point
	local minDist = clickRadius
	local selected
	local dist
	for k,p in pairs(self.cPoints) do	-- of all points, take the one clostest to the click
		if k ~= ignore then
			dist = distance( p, clickPoint )
			if dist < minDist then
				selected = k
				minDist = dist
			end
		end
	end
	return selected, self.cPoints[selected]
end

function Bezier:setSelected( k )
	self.selected = k
end

-- Add a control point:
function Bezier:addCPoint( P )
	self.numCPoints = self.numCPoints + 1
	local snapPoint
	if self.snapToCPoints then
		local hit = self:checkHit( P )
		if self.cPoints[hit] then
			-- create copy of point:
			snapPoint = {}
			snapPoint.x = self.cPoints[hit].x
			snapPoint.y = self.cPoints[hit].y
		end
	else
		if self.snapToGrid then
			snapPoint = {}
			snapPoint.x = math.floor((P.x+gridSize/2)/gridSize)*gridSize
			snapPoint.y = math.floor((P.y+gridSize/2)/gridSize)*gridSize
		end
	end
	self.cPoints[self.numCPoints] = snapPoint or P
	--self:update()
	self:setModified()
	self:setSelected( self.numCPoints )		-- new points are always selected!
	
	P:addCurve( self )
end

function Bezier:getCPoint( k )
	return self.cPoints[k]
end

function Bezier:removeCPoint( k )
	if k < 1 or k > self.numCPoints then
		return
	end
	if self.selected == k then
		self.selected = nil
	end
	self.cPoints[k] = nil
	for c=k, self.numCPoints-1 do
		self.cPoints[c] = self.cPoints[c+1]
	end
	self.cPoints[self.numCPoints] = nil
	self.numCPoints = self.numCPoints - 1
	--self:update()
	self:setModified()
end

function Bezier:startMoving()
	self.movingPoint = true
end
function Bezier:stopMoving()
	self.movingPoint = false
end
function Bezier:isMoving()
	return self.movingPoint
end

function Bezier:movePoint( P )
	if self.selected and self.movingPoint then
		if self.snapToCPoints then
			k = self:checkHit( P, self.selected )	-- check if other buttons are close by
			if k then
				self.cPoints[self.selected].x = self.cPoints[k].x
				self.cPoints[self.selected].y = self.cPoints[k].y
			else
				if self.snapToGrid then
					self.cPoints[self.selected].x = math.floor((P.x+gridSize/2)/gridSize)*gridSize
					self.cPoints[self.selected].y = math.floor((P.y+gridSize/2)/gridSize)*gridSize
				else
					self.cPoints[self.selected].x = P.x
					self.cPoints[self.selected].y = P.y
				end
			end
		else
			if self.snapToGrid then
				self.cPoints[self.selected].x = math.floor((P.x+gridSize/2)/gridSize)*gridSize
				self.cPoints[self.selected].y = math.floor((P.y+gridSize/2)/gridSize)*gridSize
			else
				self.cPoints[self.selected].x = P.x
				self.cPoints[self.selected].y = P.y
			end
		end
		--self:update()
		self:setModified()
	end
end

function Bezier:setStartPoint( x, y )
	if self.cPoints[1] then
		self.cPoints[1].x, self.cPoints[1].y = x, y
		--self:update()
		self:setModified()
	end
end
function Bezier:setEndPoint( x, y )
	if self.cPoints[#self.cPoints] then
		self.cPoints[#self.cPoints].x, self.cPoints[#self.cPoints].y = x, y
		--self:update()
		self:setModified()
	end
end

function Bezier:getNumCPoints()
	return self.numCPoints, #self.points
end

function Bezier:setSnapToCPoints( bool )
	self.snapToCPoints = bool
end

function Bezier:setSnapToGrid( bool )
	self.snapToGrid = bool
end

function Bezier:checkLineHit( x, y, dist )
	local hit
	local d
	local segLength = 0
	local t = 0
	for k = 1, #self.points-1 do
		d = distPointToLine({self.points[k], self.points[k+1]}, x, y )
		segLength = distance( self.points[k], self.points[k+1] )
		if d and d < dist then
			print("FOUND")
			t = t + segLength/2		-- return center of the hit segment
			return true, t		-- a line segment was found: stop checking!
		end
		t = t + segLength
	end
	return false
end
