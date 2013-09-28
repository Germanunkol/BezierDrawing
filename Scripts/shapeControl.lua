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
	
	self.materialList = {}
	
	-- for double clicking:
	self.doubleClickTime = 0.3
	self.lastClickTime = 0
	
	-- Thread will wait for shapes to request filled images and normalmaps:
	floodFillThread = love.thread.newThread("floodfill", "Scripts/floodfillThread.lua")
	floodFillThread:start()
	
	self:loadMaterials()
end

function ShapeControl:getSelectedShape()
	return self.selectedShape
end
function ShapeControl:getEditedShape()
	return self.editedShape
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
					else
						if self.selectedShape then
							self.selectedShape:setSelected( false )
							self.selectedShape = nil
						end
					end

				end
			end
		end
	end
	if button == "r" then
		if self.draggedShape then
			self.draggedShape:drop()
			self.draggedShape = nil
		else
			local hit
			if self.editedShape then
				hit = self.editedShape:checkHit( mX, mY )
			end
			if hit then
				if hit.class == Corner then
					self.editedShape:removeCorner( hit )
					if self.editedShape:getNumCorners() == 0 then
						removeFromTbl( self.shapes, self.editedShape )
						self.selectedShape = nil
						self.editedShape = nil
					end
				else	-- right click on control point should reset this control point!
					hit:reset()
				end
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
	for k = 1, #self.shapes do
		if self.shapes[k]:getNumCorners() <= 1 and self.shapes[k] ~= self.editedShape then
			if self.selectedShape == self.shapes[k] then
				self.selectedShape = nil
			end
			
			removeFromTbl( self.shapes, self.shapes[k] )
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
	elseif key == "h" then
		self:setSnapToCPoints( not self:getSnapToCPoints() )
	elseif key == "x" or key == "delete" then
		if self.selectedShape then
			if self.editedShape == self.selectedShape then
				self.editedShape = nil
			end
			
			removeFromTbl( self.shapes, self.selectedShape )
			
			self.selectedShape = nil
		end
	elseif key == "+" then		-- move shape to lower layer:
		if self.selectedShape then
			for k = 1, #self.shapes-1 do	-- if it's the highest shape, don't bother moving it up
				if self.shapes[k] == self.selectedShape then
					self.shapes[k], self.shapes[k+1] = self.shapes[k+1], self.shapes[k]
					break
				end
			end
		end
	elseif key == "-" then		 -- move shape to higher layer:
		if self.selectedShape then
			for k = #self.shapes, 2, -1 do	-- if it's the lowest shape, don't bother moving it
				if self.shapes[k] == self.selectedShape then
					self.shapes[k], self.shapes[k-1] = self.shapes[k-1], self.shapes[k]
					break
				end
			end
		end
	elseif key == "m" then
	
		-- Scroll through all available materials.
		-- Find the one the shape is currently using
		-- then assign the next one, or the first material
		-- if the current one is the last one in the list:
		if self.selectedShape then
			mat = self.selectedShape:getMaterial()
			for k = 1, #self.materialList do
				if self.materialList[k] == mat then
					if k < #self.materialList then
						self.selectedShape:setMaterial(self.materialList[k+1])
					else
						self.selectedShape:setMaterial(self.materialList[1])
					end
				end
			end
		end
	end
	
	if key == "escape" then
		if self.editedShape then
			self.editedShape:setEditing( false )
			self.editedShape = nil
		end
	end
end


function ShapeControl:draw()
	for k = 1,#self.shapes do
		if self.editedShape ~= self.shapes[k] then		-- draw edited shape last!
			self.shapes[k]:draw( self.editedShape )
		end
	end
	if self.editedShape then
		self.editedShape:draw( self.editedShape )
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
		if self.snapToGrid then
			local dX, dY = mX - self.draggedShape.startDragX, mY - self.draggedShape.startDragY
			mX = math.floor((dX+self.gridSize/2)/self.gridSize)*self.gridSize
					+ self.draggedShape.startDragX
			mY = math.floor((dY+self.gridSize/2)/self.gridSize)*self.gridSize
					+ self.draggedShape.startDragY
		end
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


function ShapeControl:loadMaterials()
	print("Loading materials:")
	local files = love.filesystem.enumerate("Materials")
	self.materialList = {}
	for k, name in pairs(files) do
		if name:find(".lua") == #name-4 then
			self.materialList[#self.materialList+1] = name:sub( 1, #name-5 )
			print("\t" , self.materialList[#self.materialList])
		end
	end
end
