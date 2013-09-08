require("Scripts/bezier")
require("Scripts/middleclass")
require("Scripts/corner")
require("Scripts/misc")

local clickDist = 10

Shape = class("Shape")

function Shape:initialize()
	self.corners = {}
	self.curves = {}
end

local function interpolate( P1, P2, amount )
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

function Shape:selectCorner( new )
	if self.selectedCorner then
		self.selectedCorner:deselect()
	end
	self.selectedCorner = new
	new:select()
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

function Shape:click( x, y, button )
	if button == "l" then
		local hit = self:checkHit( x, y )
		if hit then
			self.draggedPoint = hit
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
		c:draw(self.selected)
	end
	for k,c in pairs( self.corners ) do
		c:draw(self.selected)
	end
end



