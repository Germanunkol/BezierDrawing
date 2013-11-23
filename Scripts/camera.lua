require("Scripts/middleclass")

Camera = class("Camera")

function Camera:initialize( minZoom, maxZoom, x, y )
	self.maxZoom, self.minZoom = maxZoom, minZoom
	self.x, self.y = x, y
	self.angle = 0
	self.zoom = 1
end

function Camera:setPos( x, y )
	self.x, self.y = x, y
end

function Camera:getPos()
	return self.x, self.y
end

function Camera:setAngle( ang )
	self.angle = ang
end

function Camera:setZoom( zoom )
	self.zoom = math.max( self.minZoom, math.min( self.maxZoom, zoom ) )
end

function Camera:getZoom()
	return self.zoom
end

function Camera:zoomIn()
	self:setZoom( self.zoom*2 )
end
function Camera:zoomOut()
	self:setZoom( self.zoom/2 )
end

function Camera:screenPos(x,y)
        -- x,y = ((x,y) - (self.x, self.y)):rotated(self.rot) * self.scale + center
        local w,h = love.graphics.getWidth(), love.graphics.getHeight()
        local c,s = math.cos(self.angle), math.sin(self.angle)
        x,y = x - self.x, y - self.y
        x,y = c*x - s*y, s*x + c*y
        return x*self.zoom + w/2, y*self.zoom + h/2
end

function Camera:worldPos( x, y )
	local w,h = love.graphics.getWidth(), love.graphics.getHeight()
	local c,s = math.cos(-self.angle), math.sin(-self.angle)
	x,y = (x - w/2) / self.zoom, (y - h/2) / self.zoom
	x,y = c*x - s*y, s*x + c*y
	return x+self.x, y+self.y
end

function Camera:setDrag( bool, startX, startY )
	if bool == true then
		self.dragLastX, self.dragLastY = startX, startY
	end
	self.dragging = bool
end

function Camera:drag( curX, curY )
	if self.dragging then
		local dx, dy = curX - self.dragLastX, curY - self.dragLastY
		self.x = self.x - dx/self.zoom
		self.y = self.y - dy/self.zoom
		self.dragLastX, self.dragLastY = curX, curY
	end
end


function Camera:set()
	love.graphics.push()
	local dx,dy = love.graphics.getWidth()/2, love.graphics.getHeight()/2
	love.graphics.translate(dx, dy)
	love.graphics.scale(self.zoom)
	love.graphics.rotate(self.angle)
	love.graphics.translate(-self.x, -self.y)
end

function Camera:reset()
	love.graphics.pop()
end
