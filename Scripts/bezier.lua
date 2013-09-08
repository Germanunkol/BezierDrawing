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

Bezier = class('Bezier')

local clickRadius = 15
local gridSize = 30

function Bezier:initialize( cPoints, segmentLength, width )
	self.cPoints = cPoints
	self.numCPoints = #cPoints
	
	for k, p in pairs(cPoints) do
		p:addCurve( self )
	end
	
	self:setSegmentLength( segmentLength or 5 )

	self.lineWidth = width or 2
	
	self:update()
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

local function calcCoefficients( points, t, segmentLength )

	local tbl = {}
	local n = #points
	for i = 1,n do
		tbl[i] = {}
		tbl[i][1] = points[i]
	end

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
			
		-- check how long the line segments are:
		if first[j-1] then
			dist = distance(first[j-1], first[j])
			
			if dist > firstSegLength then
				firstSegLength = dist
			end
		end
		if second[n-j+2] then
			dist = distance(second[n-j+1], second[n-j+2])
			if dist > secondSegLength then
				secondSegLength = dist
			end
		end
	end
	
	if firstSegLength > segmentLength then
		first = calcCoefficients( first, t, segmentLength )
	end
	if secondSegLength > segmentLength then
		second = calcCoefficients( second, t, segmentLength )
	end
	return tableConcat(first, second)
end

function Bezier:setSegmentLength( l )
	if not tonumber( l ) then
		res = 5
	end
	self.segmentLength = tonumber( l  )
	self:update()	-- rerender points
end

function Bezier:getSegmentLength( )
	return self.segmentLength
end

function Bezier:setLineWidth( width )
	self.lineWidth = width or 2
end

function Bezier:update()
	self.points = calcCoefficients( self.cPoints, 0.5, self.segmentLength )
end

function Bezier:draw()

	love.graphics.setLineWidth( self.lineWidth )
	love.graphics.setColor(255,255,255, 255)
	for k=1,#self.points-1 do
		love.graphics.line( self.points[k].x, self.points[k].y, self.points[k+1].x, self.points[k+1].y )
	end
	love.graphics.setLineWidth( 1 )

	love.graphics.setColor(255,120,50, 150)

	for k = 1, self.numCPoints-1 do
		love.graphics.line(self.cPoints[k].x, self.cPoints[k].y, self.cPoints[k+1].x, self.cPoints[k+1].y)
	end

	love.graphics.setPointStyle("rough")
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
	self:update()
	self:setSelected( self.numCPoints )		-- new points are always selected!
	
	P:addCurve( self )
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
	self:update()
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
		self:update()
	end
end

function Bezier:setStartPoint( x, y )
	if self.cPoints[1] then
		self.cPoints[1].x, self.cPoints[1].y = x, y
		self:update()
	end
end
function Bezier:setEndPoint( x, y )
	if self.cPoints[#self.cPoints] then
		self.cPoints[#self.cPoints].x, self.cPoints[#self.cPoints].y = x, y
		self:update()
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
