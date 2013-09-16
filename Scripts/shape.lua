require("Scripts/bezier")
require("Scripts/middleclass")
require("Scripts/corner")
require("Scripts/misc")
require("Scripts/polygon")

local clickDist = 10

Shape = class("Shape")

function Shape:initialize()
	self.corners = {}
	self.curves = {}
	self.selected = true
	self.boundingBox = {}
	self.polygon = {}
	self.triangles = {}
	--self.finalCanvas = love.graphics.newCanvas()
	--self.tempCanvas = love.graphics.newCanvas()
end

function interpolate( P1, P2, amount )
	local x = P1.x + (P2.x-P1.x)*amount
	local y = P1.y + (P2.y-P1.y)*amount
	return Point:new( x, y )
end

function Shape:addCorner(x,y)

	if self.selectedCorner then
		if self.selectedCorner.next and self.selectedCorner.prev then
			return
		end
	end

	local newCorner = Corner:new( x, y )
	self.corners[#self.corners + 1] = newCorner
	
	if self.selectedCorner then
		if not self.selectedCorner.next then
			self.selectedCorner.next = newCorner
			newCorner.prev = self.selectedCorner
			
			local P1 = interpolate( self.selectedCorner, newCorner, 0.25 )
			local P2 = interpolate( self.selectedCorner, newCorner, 0.75 )
			
			local b = Bezier:new( {self.selectedCorner, P1, P2, newCorner}, 5, 1)
			self.curves[#self.curves +1] = b
			
			self.selectedCorner.bezierNext = b
			newCorner.bezierPrev = b
		else
			if not self.selectedCorner.prev then
				self.selectedCorner.prev = newCorner
				newCorner.next = self.selectedCorner
				
				local P1 = interpolate( self.selectedCorner, newCorner, 0.25 )
				local P2 = interpolate( self.selectedCorner, newCorner, 0.75 )
				
				local b = Bezier:new( {newCorner, P1, P2, self.selectedCorner}, 5, 1)
				self.curves[#self.curves +1] = b
				
				self.selectedCorner.bezierPrev = b
				newCorner.bezierNext = b
			end
		end
	end
	
	self:selectCorner( newCorner )
	self.modified = true
end

function Shape:addCurve( connectTo )
	if self.selectedCorner then
		if self.selectedCorner.next and self.selectedCorner.prev then
			return
		end
	end
	
	if self.selectedCorner then
		self.closed = true
		if not self.selectedCorner.next then
			self.selectedCorner.next = connectTo
			connectTo.prev = self.selectedCorner
			
			local P1 = interpolate( self.selectedCorner, connectTo, 0.25 )
			local P2 = interpolate( self.selectedCorner, connectTo, 0.75 )
			
			local b = Bezier:new( {self.selectedCorner, P1, P2, connectTo}, 5, 1)
			self.curves[#self.curves +1] = b
			
			self.selectedCorner.bezierNext = b
			connectTo.bezierPrev = b
		else
			if not self.selectedCorner.prev then
				self.selectedCorner.prev = connectTo
				connectTo.next = self.selectedCorner
				
				local P1 = interpolate( self.selectedCorner, connectTo, 0.25 )
				local P2 = interpolate( self.selectedCorner, connectTo, 0.75 )
				
				local b = Bezier:new( {connectTo, P1, P2, self.selectedCorner}, 5, 1)
				self.curves[#self.curves +1] = b
				
				self.selectedCorner.bezierPrev = b
				connectTo.bezierNext = b
			end
		end
		
		self:selectCorner( nil )
	end
	self.modified = true
end

function Shape:selectCorner( new )
	if self.selectedCorner then
		self.selectedCorner:deselect()
		self.selectedCorner = nil
	end
	if new then
		self.selectedCorner = new
		new:select()
	end
end

function Shape:getSelectedCorner()
	return self.selectedCorner
end


function Shape:removeCorner( p )

	removeFromTbl( self.corners, p )
	
	-- join previous and next:
	if p.prev and p.next and not self.closed then
		local P1, P2, P3, P4
		P1 = p.prev
		P2 = p.bezierPrev:getCPoint( 3 )
		P3 = p.bezierNext:getCPoint( 2 )
		P4 = p.next
		
		local b = Bezier:new( { P1, P2, P3, P4 }, 5, 1)
		self.curves[#self.curves +1] = b
		
		P4.bezierPrev = b
		P1.bezierNext = b
		
		P4.prev = P1
		P1.next = P4
	else
		if p.next then
			p.next.prev = nil
			p.next.bezierPrev = nil
		end
		if p.prev then
			p.prev.next = nil
			p.prev.bezierNext = nil
		end
		if self.closed then
			self:selectCorner( nil )
		end
		self.closed = false
	end
	
	if self.selectedCorner == p or self.selectedCorner == nil then
		for k=1, #self.corners do
			if  self.corners[k].next == nil then
				self:selectCorner( self.corners[k] )
				break
			end
		end
	end
	
	removeFromTbl( self.curves, p.bezierPrev )
	removeFromTbl( self.curves, p.bezierNext )
	self.modified = true
end

function Shape:checkHit( x, y, ignore )

	ignore = ignore or self.draggedPoint
	local hit, dist
	local minDist = clickDist/cam:getZoom()
	local P = {x=x,y=y}
	
	for k = 1, #self.curves do
		for i, p in pairs(self.curves[k].cPoints) do
			if p ~= ignore then
				dist = distance(P, p)
				if dist < minDist then
					minDist = dist
					hit = p
				end
			end
		end
	end
	if not hit then
		for k = 1,#self.corners do
			if self.corners[k] ~= ignore then
				dist = distance(P, self.corners[k])
				if dist < minDist then
					minDist = dist
					hit = self.corners[k]
				end
			end
		end
	end
	return hit, minDist
end

function Shape:click( x, y, button, dontDrag )
	if button == "l" then
		local hit = self:checkHit( x, y )
		if hit then
			if not dontDrag then
				self.draggedPoint = hit
			end
			return hit
		end
	end
end

function Shape:release()
	self.draggedPoint = nil
end

function Shape:isMoving()
	if self.draggedPoint then
		return true
	end
	return false
end

function Shape:movePoint( x, y )
	if self.draggedPoint then
		self.draggedPoint:move( x, y )
	end
end

function Shape:draw()
	
	--love.graphics.setCanvas(self.tempCanvas)
	
	if self.closed and not self.draggedPoint then
		love.graphics.setColor(255,200,180, 75)
		--for k, tr in pairs(self.triangles) do
			--love.graphics.triangle("fill", unpack(tr))
		--end
		--print("now")
		if self.filledPolygon then
			love.graphics.polygon("fill", self.filledPolygon)
		end
	end
	for k,c in pairs( self.curves ) do
		c:draw( self.selected, self.closed )
	end
	if self.selected then
		for k,c in pairs( self.corners ) do
			c:draw()
		end
	end
	--love.graphics.setCanvas()
	
	--love.graphics.draw
	if self.boundingBox then
		love.graphics.setLineWidth( math.max( 1/cam:getZoom(), 1) )
		love.graphics.setColor(255,120,50, 75)
		local str
		if self.boundingBox.minX and self.boundingBox.maxX ~= self.boundingBox.minX then
			love.graphics.line( self.boundingBox.minX, self.boundingBox.maxY + 20,
				self.boundingBox.maxX, self.boundingBox.maxY + 20)
			str = pixelsToMeters(math.floor(self.boundingBox.maxX - self.boundingBox.minX)) .. " m"
			love.graphics.print( str, self.boundingBox.maxX - love.graphics.getFont():getWidth(str),
				self.boundingBox.maxY + 22)
		end
				
		if self.boundingBox.minY and self.boundingBox.maxY ~= self.boundingBox.minY then
			love.graphics.line( self.boundingBox.maxX + 20, self.boundingBox.minY,
					self.boundingBox.maxX + 20, self.boundingBox.maxY)
			str = pixelsToMeters(math.floor(self.boundingBox.maxY - self.boundingBox.minY)) .. " m"
			love.graphics.print( str, self.boundingBox.maxX + 22,
				self.boundingBox.maxY - love.graphics.getFont():getHeight())
		end
	end
end

function Shape:setSelected( bool )
	self.selected = bool
end

function Shape:getNumCorners()
	return #self.corners
end

function Shape:checkLineHit( x, y )
	local hit, t
	print("line", x, y)
	for k = 1, #self.curves do
		hit, t = self.curves[k]:checkLineHit( x, y, clickDist*2 )
		if hit then 
			return self.curves[k], t
		end
	end
end

function Shape:splitCurve( curve, dist )
	-- local prev, next = curve.prev, curve.next
	
	local firstCurve, secondCurve, newCorner = curve:splitCurveAt( dist/curve.length )
	
	local moved = curve.cPoints[2].hasBeenMoved or curve.cPoints[3].hasBeenMoved
	
	for k,p in pairs(firstCurve) do
		if not p.class or not p.class == Corner and not p.class == Point then
			firstCurve[k] = Point:new(p.x, p.y)
		end
		firstCurve[k].hasBeenMoved = moved
	end
	for k,p in pairs(secondCurve) do
		if not p.class or not p.class == Corner and not p.class == Point then
			secondCurve[k] = Point:new(p.x, p.y)
		end
		secondCurve[k].hasBeenMoved = moved
	end
	
	firstCurve = Bezier:new( firstCurve, 5, 1 )
	secondCurve = Bezier:new( secondCurve, 5, 1 )
	
	self.curves[#self.curves + 1] = firstCurve
	self.curves[#self.curves + 1] = secondCurve
	
	if curve.cPoints[1] then
		curve.cPoints[1].next = newCorner
		curve.cPoints[1].bezierNext = firstCurve
		newCorner.prev = curve.cPoints[1]
		newCorner.bezierPrev = firstCurve
	end
	if curve.cPoints[#curve.cPoints] then
		curve.cPoints[#curve.cPoints].prev = newCorner
		curve.cPoints[#curve.cPoints].bezierPrev = secondCurve
		newCorner.next = curve.cPoints[#curve.cPoints]
		newCorner.bezierNext = secondCurve
	end
	
	self.corners[#self.corners+1] = newCorner
	removeFromTbl( self.curves, curve )
end

function Shape:fill()
	local prev, next, new
	local minAng = math.pi/10
	--print("NOW")
	for k = 1, #self.curves do
		for i = 1, #self.curves[k].points do
			--print("cp:", self.curves[k].points[i].x, self.curves[k].points[i].y, self.curves[k].points[i].class)
			prev = self.polygon[#self.polygon]
			new = {
					x = self.curves[k].points[i].x,
					y = self.curves[k].points[i].y
			}
			self.polygon[#self.polygon + 1] = new
			new.prev = prev
			if prev then
				prev.next = new
			end
			--[[else
				self.polygon[#self.polygon] = new
				new.prev = prev.prev
				if prev.prev then
					prev.prev.next = new
				end
			end]]--
		end
	end

	-- close loop:			
	if self.polygon[#self.polygon-1] then
		self.polygon[#self.polygon-1].next = self.polygon[1]
		self.polygon[1].prev = self.polygon[#self.polygon-1]
	end
	self.polygon[#self.polygon] = nil
	print("#polygon points:", #self.polygon)

	--self.triangles = triangulate( self.polygon )
	self.triangles = triangulateSimple( self.polygon )
	print("#triangle points:", #self.triangles)
	
	self.filledPolygon = {}
	for k = 1, #self.polygon do
		self.filledPolygon[#self.filledPolygon+1] = self.polygon[k].x
		self.filledPolygon[#self.filledPolygon+1] = self.polygon[k].y
	end
end

function Shape:update()
	if not self.lastUpdateTime then
		self.lastUpdateTime = love.timer.getMicroTime()
	else
		if love.timer.getMicroTime() - self.lastUpdateTime < .01 then
			return
		end
	end

	--local updated = false
	for k = 1, #self.curves do
		if self.curves[k]:getModified() then
			self.curves[k]:update()
			self.modified = true
		end
	end
	if self.modified then
		self.boundingBox.minX = math.huge
		self.boundingBox.minY = math.huge
		self.boundingBox.maxX = -math.huge
		self.boundingBox.maxY = -math.huge
		local boundings
		for k = 1, #self.curves do
			boundings = self.curves[k]:getBoundingBox()
			self.boundingBox.minX = math.min( boundings.minX, self.boundingBox.minX )
			self.boundingBox.minY = math.min( boundings.minY, self.boundingBox.minY )
			self.boundingBox.maxX = math.max( boundings.maxX, self.boundingBox.maxX )
			self.boundingBox.maxY = math.max( boundings.maxY, self.boundingBox.maxY )
		end
		
		if self.closed then
			self.polygon = {}
			
			if not self.draggedPoint then
				
				self:fill()
				
				self.modified = false
			end
		end
	end
end
