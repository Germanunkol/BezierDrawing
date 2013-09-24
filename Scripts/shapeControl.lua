require("Scripts/bezier")
require("Scripts/middleclass")
require("Scripts/shape")
require("Scripts/misc")

ShapeControl = class("ShapeControl")

floodFillThread = nil

function ShapeControl:initialize( gridSize, canvasWidth, canvasHeight )
	self.gridSize = gridSize or 10
	self.canvasWidth = canvasWidth
	self.canvasHeight = canvasHeight
	self.shapes = {}
	self.selectedShape = nil
	self.editedShape = nil
	
	-- for double clicking:
	self.doubleClickTime = 0.5
	self.lastClickTime = 0
	
	-- Thread will wait for shapes to request filled images and normalmaps:
	floodFillThread = love.thread.newThread("floodfill", "Scripts/floodfillThread.lua")
	floodFillThread:start()
end

function ShapeControl:getSelectedShape()
	return self.selectedShape
end
function ShapeControl:getNumShapes()
	return #self.shapes
end

function ShapeControl:newShape()
	local s = Shape:new()
	
	self.shapes[#self.shapes + 1] = s
	self.waitedTime = 0
	return s
end


function ShapeControl:checkDoubleClick()
	local now = love.timer.getTime()
	local doubleClicked = false
	if now - self.lastClickTime < self.doubleClickTime then
		doubleClicked = true
	end
	self.lastClickTime = now
	return doubleClicked
end

function ShapeControl:getHitShape( mX, mY )
	for k = #self.shapes, 1,-1 do
		if self.shapes[k].closed == true then
			if self.shapes[k]:pointIsInside(  mX, mY ) then
				return self.shapes[k]
			end
		else
			-- if not hit inside, check if line was hit
			if self.shapes[k]:checkLineHit( mX, mY ) then
				return self.shapes[k]
			end
		end
	end
end

function ShapeControl:click( mX, mY, button, zoom )
	if button == "l" then
		if love.keyboard.isDown( "rctrl", "lctrl" ) then
				local hit
				if self.editedShape then
					hit = self.editedShape:click( mX, mY, button, true )
				end
		
				if not hit or hit.class ~= Corner
					or (hit.prev and hit.next)	-- only two edges per node!
					or hit == self.editedShape:getSelectedCorner()
					or hit.next == self.editedShape:getSelectedCorner()
					or hit.prev == self.editedShape:getSelectedCorner() then
					
					if not self.editedShape then
						if self.editedShape then
							self.editedShape:setEditing( false )
						end
						self.editedShape = self:newShape()
					end

					local hitLine, dist = self.editedShape:checkLineHit( mX, mY, zoom )
					if hitLine then		-- if click hit line, then 
						self.editedShape:splitCurve( hitLine, dist )
					elseif not self.editedShape.closed then
						if self.snapToGrid then
							mX = math.floor((mX+self.gridSize/2)/self.gridSize)*self.gridSize
							mY = math.floor((mY+self.gridSize/2)/self.gridSize)*self.gridSize
						end
						self.editedShape:addCorner( mX, mY )
					end
				else
			
					self.editedShape:addCurve( hit )
			
				end
			--end
		else
		

			local double = self:checkDoubleClick()
			local hit, t
						
			if double then
			
				if self.editedShape then
					self.editedShape:setEditing( false )
					self.editedShape = nil
				end
				
				hit = self:getHitShape( mX, mY )
				if hit then
					hit:setEditing( true )
					self.editedShape = hit
				end
				
			else
				if self.editedShape then
					hit = self.editedShape:click( mX, mY, button )
				end
				if hit then
					-- if the point that I clicked on was a corner, not a normal construction point:
					if self.editedShape and hit.class == Corner then
						self.editedShape:selectCorner( hit )
					end
				else
					
					if self.editedShape then
						self.editedShape:setEditing( false )
						self.editedShape = nil
					end
				
					hit = self:getHitShape( mX, mY )
					if hit then
						if self.selectedShape then
							self.selectedShape:setSelected( false )
						end
						hit:setSelected( true )
						self.selectedShape = hit
						
							self.draggedShape = hit
							hit:startDragging( mX, mY )
					end

				end
			end
		end
	end
	if button == "r" then
		local hit
		if self.editedShape then
			hit = self.editedShape:checkHit( mX, mY )
		end
		if hit then
			if hit.class == Corner then
				self.editedShape:removeCorner( hit )
				if self.editedShape:getNumCorners() == 0 then
					removeFromTbl( self.shapes, self.selShape )
					self.editedShape = nil
				end
			else	-- right click on control point should reset this control point!
				hit:reset()
			end
		end
	end
	
	if self.editedShape then
		if self.editedShape ~= self.selectedShape then
			if self.selectedShape then
				self.selectedShape:setSelected( false )
			end
			self.selectedShape = self.editedShape
		end
	end
end

function ShapeControl:release( x, y, button )
	if self.draggedShape then
		self.draggedShape:stopDragging( x, y )
		self.draggedShape = nil
	elseif self.editedShape then
		self.editedShape:release()
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
		if self.editedShape then
			self.editedShape:setEditing( false )
			self.editedShape = nil
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

function ShapeControl:update( mX, mY, dt )
	for k = 1, #self.shapes do
		if self.editedShape and self.editedShape == self.shapes[k] then
			if self.editedShape:isMoving() then
				if self.snapToCPoints then
					-- check if other points are close by:
					local hit = self.editedShape:checkHit( mX, mY )
				
					if hit then
						mX = hit.x
						mY = hit.y
					else
						if self.snapToGrid then
							mX = math.floor((mX+self.gridSize/2)/self.gridSize)*self.gridSize
							mY = math.floor((mY+self.gridSize/2)/self.gridSize)*self.gridSize
						end
					end
				else
					if self.snapToGrid then
						mX = math.floor((mX+self.gridSize/2)/self.gridSize)*self.gridSize
						mY = math.floor((mY+self.gridSize/2)/self.gridSize)*self.gridSize
					end
				end
				self.editedShape:movePoint( mX, mY )
			end
		end
		self.shapes[k]:update( dt )
	end
	
	if self.draggedShape then
		self.draggedShape:drag( mX, mY )
	end
	
	local err = floodFillThread:get("error")
	local msg = floodFillThread:get("msg")
	
	if msg then print("FF (msg):", msg) end
	if err then print("FF (error):", err) end
end

function ShapeControl:setSnapToCPoints( bool )
	self.snapToCPoints = bool
end

function ShapeControl:setSnapToGrid( bool )
	self.snapToGrid = bool
end
function ShapeControl:getSnapToCPoints( ) return self.snapToCPoints end
function ShapeControl:getSnapToGrid( ) return self.snapToGrid end
