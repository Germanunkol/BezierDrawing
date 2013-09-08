require("Scripts/bezier")
require("Scripts/middleclass")
require("Scripts/shape")

ShapeControl = class("ShapeControl")

function ShapeControl:initialize( gridSize )
	self.gridSize = gridSize or 10

	self.selShape = nil
	self.shapes = {}
end

function ShapeControl:getSelected()
	return shapeControl.selected
end

function ShapeControl:newShape()
	local s = Shape:new()
	
	self.shapes[#self.shapes + 1] = s
	return s
end

function ShapeControl:click( x, y, button )
	if button == "l" then
		local hit
		if self.selShape then
			hit = self.selShape:click( x, y, button )
		end
		if not hit then
			if not self.selShape then
				self.selShape = self:newShape()
			end
			self.selShape:addCorner( x, y )
		end
	end
end

function ShapeControl:release( x, y, button )
	if self.selShape then
		self.selShape:release()
	end
end

function ShapeControl:draw()
	for k = 1,#self.shapes do
		self.shapes[k]:draw()
	end
end

function ShapeControl:update()
	if self.selShape then
		if self.selShape:isMoving() then
			local x, y = love.mouse.getPosition()
			if self.snapToCPoints then
				-- check if other points are close by:
				local hit = self.selShape:checkHit( x, y )
				
				if hit then
					x = hit.x
					y = hit.y
				else
					if self.snapToGrid then
						x = math.floor((x+self.gridSize/2)/self.gridSize)*self.gridSize
						y = math.floor((y+self.gridSize/2)/self.gridSize)*self.gridSize
					end
				end
			else
				if self.snapToGrid then
					x = math.floor((x+self.gridSize/2)/self.gridSize)*self.gridSize
					y = math.floor((y+self.gridSize/2)/self.gridSize)*self.gridSize
				end
			end
			self.selShape:movePoint( x, y )
		end
	end
end

function ShapeControl:setSnapToCPoints( bool )
	self.snapToCPoints = bool
end

function ShapeControl:setSnapToGrid( bool )
	self.snapToGrid = bool
end
