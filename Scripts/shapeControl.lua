require("Scripts/bezier")
require("Scripts/middleclass")
require("Scripts/shape")
require("Scripts/misc")

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
		print(x, y)
		if love.keyboard.isDown( "rctrl", "lctrl" ) then
			if not self.selShape or not self.selShape.closed then
				local hit
				if self.selShape then
					hit = self.selShape:click( x, y, button, true )
				end
		
				if not hit or hit.class ~= Corner
					or (hit.prev and hit.next)	-- only two edges per node!
					or hit == self.selShape:getSelectedCorner()
					or hit.next == self.selShape:getSelectedCorner()
					or hit.prev == self.selShape:getSelectedCorner() then
					
					if not self.selShape then
						self.selShape = self:newShape()
					end

					local hitLine, dist = self.selShape:checkLineHit( x, y )
					if hitLine then		-- if click hit line, then 
						self.selShape:splitCurve( hitLine, dist )
					else
						if self.snapToGrid then
							x = math.floor((x+self.gridSize/2)/self.gridSize)*self.gridSize
							y = math.floor((y+self.gridSize/2)/self.gridSize)*self.gridSize
						end
						self.selShape:addCorner( x, y )
					end
				else
			
					self.selShape:addCurve( hit )
			
				end
			end
		else
			local hit
			if self.selShape then
				hit = self.selShape:click( x, y, button )
			end
			if hit then
				-- if the point that I clicked on was a corner, not a normal construction point:
				if self.selShape and hit.class == Corner then
					self.selShape:selectCorner( hit )
				end
			else
				local hitShape
				for k = 1, #self.shapes do
					if self.shapes[k] ~= self.selShape then
						if self.shapes[k]:checkLineHit( x, y ) then
							hitShape = self.shapes[k]
							break
						end
					end
				end
				if hitShape then
					if self.selShape then
						self.selShape:setSelected( false )
					end
					hitShape:setSelected( true )
					self.selShape = hitShape
				end
			end
		end
	end
	if button == "r" then
		local hit
		if self.selShape then
			hit = self.selShape:checkHit( x, y )
		end
		if hit and hit.class == Corner then
			self.selShape:removeCorner( hit )
			if self.selShape:getNumCorners() == 0 then
				removeFromTbl( self.shapes, self.selShape )
				self.selShape = nil
			end
		end
	end
end

function ShapeControl:release( x, y, button )
	if self.selShape then
		self.selShape:release()
	end
end


function ShapeControl:keypressed( key, unicode )
	if key == "g" then
		self:setSnapToGrid( not self:getSnapToGrid() )
	else
		if key == "h" then
			self:setSnapToCPoints( not self:getSnapToCPoints() )
		end
	end
	
	if key == "escape" then
		if self.selShape then
			self.selShape:setSelected( false )
			self.selShape = nil
		end
	end
end

function ShapeControl:keyreleased( key, unicode )
--[[	if key == "lctrl" then
		self:setSnapToGrid( false )
	else
		if key == "lshift" then
			self:setSnapToCPoints( false )
		end
	end
	]]--
end


function ShapeControl:draw()
	for k = 1,#self.shapes do
		self.shapes[k]:draw()
	end
end

function ShapeControl:update( x, y )
	if self.selShape then
		if self.selShape:isMoving() then
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
		self.selShape:update()
	end
end

function ShapeControl:setSnapToCPoints( bool )
	self.snapToCPoints = bool
end

function ShapeControl:setSnapToGrid( bool )
	self.snapToGrid = bool
end
function ShapeControl:getSnapToCPoints( ) return self.snapToCPoints end
function ShapeControl:getSnapToGrid( ) return self.snapToGrid end
