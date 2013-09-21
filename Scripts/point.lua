require("Scripts/misc")
require("Scripts/middleclass")

Point = class("Point")

function Point:initialize( x, y )
	self.x = x
	self.y = y
	
	self.curves = {}
end

function Point:move( x, y )
	self.x = x
	self.y = y
	self.hasBeenMoved = true
	
	for k = 1, #self.curves do
		self.curves[k]:setModified()
	end
end
function Point:reset()	--set point back to straight line
	self.hasBeenMoved = false
	
	for k = 1, #self.curves do
		self.curves[k]:setModified()
	end
end

function Point:addCurve( c )
	self.curves[#self.curves+1] = c
end

function Point:interpolate( P1, P2, amount )
	self.x = P1.x + (P2.x-P1.x)*amount
	self.y = P1.y + (P2.y-P1.y)*amount
end

function Point:setSelected( bool )
	self.selected = bool
end

function Point:draw()
	if self.class == Corner then
		if self.selected then
			--love.graphics.setPointSize(5)
			love.graphics.setColor(50,120,255, alpha)
			love.graphics.circle( "line", self.x, self.y, 5 )
		else
			love.graphics.setPointSize(4)
			love.graphics.setColor(50,120,160, alpha)
			love.graphics.point( self.x, self.y )
		end
	else
		if self.selected then
			love.graphics.setPointSize(5)
			love.graphics.setColor(255,120,50, alpha)
			love.graphics.point( self.x, self.y )
		else
			love.graphics.setPointSize(3)
			love.graphics.setColor(160,120,50, alpha)
			love.graphics.point( self.x, self.y )
		end
	end
end

-- metamethods:

function Point:__sub( second )
	return Point:new( self.x - second.x, self.y - second.y )
end

function Point:__add( second )
	return Point:new( self.x + second.x, self.y + second.y )
end

function Point:__mul( val )
	if type(val) == "number" then
		return Point:new( self.x*val, self.y*val )
	end
end

function Point:getLength()
	return math.sqrt(self.x^2 + self.y^2)
end

