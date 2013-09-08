require("Scripts/misc")

Point = class("Point")

function Point:initialize( x, y )
	self.x = x
	self.y = y
	
	self.curves = {}
end

function Point:move( x, y )
	self.x = x
	self.y = y
end

function Point:addCurve( c )
	self.curves[#self.curves+1] = c
end

--[[function Point:checkHit( x, y, d)
	if distance( {x=x,y=y}, self ) < d then
		return true
	else
		return false
	end
end
]]--

function Point:setSelected( bool )
	self.selected = bool
end

function Point:draw()
	if self.selected then
		love.graphics.setPointSize(5)
		love.graphics.setColor(50,120,255, alpha)
	else
		love.graphics.setPointSize(3)
		love.graphics.setColor(50,120,160, alpha)
	end
	love.graphics.point( self.x, self.y )
	
	for k = 1, #self.curves do
		self.curves[k]:update()
	end
end
