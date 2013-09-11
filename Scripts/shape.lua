require("Scripts/bezier")
require("Scripts/middleclass")
require("Scripts/corner")
require("Scripts/misc")

local clickDist = 10

Shape = class("Shape")

function Shape:initialize()
	self.corners = {}
	self.curves = {}
	self.selected = true
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
end

function Shape:checkHit( x, y, ignore )

	ignore = ignore or self.draggedPoint
	local hit, dist
	local minDist = clickDist
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
	for k,c in pairs( self.curves ) do
		c:draw( self.selected, self.closed )
	end
	if self.selected then
		for k,c in pairs( self.corners ) do
			c:draw()
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
	for k = 1, #self.curves do
		if self.curves[k]:checkLineHit( x, y, clickDist*2 ) then
			return self.curves[k]
		end
	end
end

function Shape:splitCurve( curve, dist )
	-- local prev, next = curve.prev, curve.next
	
	local firstCurve, secondCurve, newCorner = curve:splitCurve( 0.5 )
	
	for k,p in pairs(firstCurve) do
		print(p.class)
		if not p.class or not p.class == Corner and not p.class == Point then
			firstCurve[k] = Point:new(p.x, p.y)
		end
		print("\t",firstCurve[k].class)
	end
	for k,p in pairs(secondCurve) do
		print(p.class)
		if not p.class or not p.class == Corner and not p.class == Point then
			secondCurve[k] = Point:new(p.x, p.y)
		end
		print("\t",secondCurve[k].class)
	end
	
	firstCurve = Bezier:new( firstCurve, 5, 1 )
	secondCurve = Bezier:new( secondCurve, 5, 1 )
	
	self.curves[#self.curves + 1] = firstCurve
	self.curves[#self.curves + 1] = secondCurve
	if curve.prev then
		curve.prev.next = newCorner
		curve.prev.bezierNext = firstCurve
		newCorner.prev = curve.prev
		newCorner.bezierPrev = firstCurve
	end
	if curve.next then
		curve.next.prev = newCorner
		curve.prev.bezierPrev = secondCurve
		newCorner.next = curve.next
		newCorner.bezierNext = secondCurve
	end
	
	removeFromTbl( self.curves, curve )
end
