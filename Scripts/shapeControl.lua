require("Scripts/bezier")
require("Scripts/middleclass")
require("Scripts/shape")
require("Scripts/misc")

ShapeControl = class("ShapeControl")

floodFillThread = nil

local fileHeader = [[
-------------------------------------------
Design saved using Germanunkol's Bezier Design tool.
To open the file, install the Löve engine (Love2d.org) and get the project from:
https://github.com/Germanunkol/BezierDrawing
-------------------------------------------
]]

function ShapeControl:initialize( gridSize, canvasWidth, canvasHeight, designName )
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
	
	-- snap per default:
	self.snapToGrid = true
	
	-- Thread will wait for shapes to request filled images and normalmaps:
	floodFillThread = love.thread.newThread("floodfill", "Scripts/floodfillThread.lua")
	floodFillThread:start()
	
	self:loadMaterials()
	
	self.designName = designName or os.time()
	self:load()
	
	love.filesystem.mkdir("Designs")
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
	local s = Shape:new( self.currentMaterial )
	
	self.shapes[#self.shapes + 1] = s
	self.waitedTime = 0
	s:setLayer( #self.shapes )
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
	
		if self:uiHit() then return end
	
	
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
	elseif key == "delete" then
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
					self.shapes[k]:setLayer( k )
					self.shapes[k+1]:setLayer( k+1 )
					print("new layers:", k, k+1)
					break
				end
			end
		end
	elseif key == "-" then		 -- move shape to higher layer:
		if self.selectedShape then
			for k = #self.shapes, 2, -1 do	-- if it's the lowest shape, don't bother moving it
				if self.shapes[k] == self.selectedShape then
					self.shapes[k], self.shapes[k-1] = self.shapes[k-1], self.shapes[k]
					self.shapes[k]:setLayer( k )
					self.shapes[k-1]:setLayer( k-1 )
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
	elseif key == "x" then
		if self.selectedShape then
			self.selectedShape:flip( "x" )
		end
	elseif key == "y" then
		if self.selectedShape then
			self.selectedShape:flip( "y" )
		end
	elseif key == "d" then
		if self.selectedShape and not self.editedShape and not self.draggedShape then
			local new = self.selectedShape:duplicate()
			self.shapes[#self.shapes+1] = new
			self.selectedShape:setSelected( false )
			new:setSelected( true )
			self.selectedShape = new
			new:setLayer( #self.shapes )
		end
	elseif key == "s" then
		self:save()
	elseif key == "l" then
		self:load()
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
	if self.selectedShape then
		self.selectedShape:drawOutline()
	end
end

local mouseX, mouseY = 0,0
function ShapeControl:drawUI()
	--if self.selectedShape then
		for k = 1,#self.materials do
			--self.materials[k].baseShape:moveTo( 0, 0 )
					--self.selectedShape.boundingBox.maxX + 25,
					--self.selectedShape.boundingBox.maxY - 20 - k*30)
			--self.materials[k].baseShape:update()
			self.materials[k].currentShape:draw( )
		end
	--end
	love.graphics.setColor(255,120,50, 255)
	local str = "(" .. mouseX/self.gridSize .. "," .. mouseY/self.gridSize .. ")"
	love.graphics.print(str, love.graphics.getWidth()-love.graphics.getFont():getWidth(str) - 10,
							love.graphics.getHeight() - 30)
	love.graphics.setColor(255,255,255,255)
end

function ShapeControl:update( mX, mY, dt )

	mouseX, mouseY = mX, mY

	if not self.materialsRendered then
		self:renderMaterials()
	end

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
	self.materials = {}
	for k, name in pairs(files) do
		print(k, name, name:find(".lua"), #name)
		if name:find(".lua") == #name-3 then
			self.materials[#self.materials+1] = {
				name = name:sub( 1, #name-4 )
			}
			print("\t" , self.materials[#self.materials].name)
		end
	end
	
	for k, mat in pairs(self.materials) do
		local x, y = love.graphics.getWidth(), love.graphics.getHeight() - 30 - k*35
		
		-- create a button for "not selected":
		mat.baseShape = Shape:new( mat.name )
		mat.baseShape:addCorner( x-40, y )
		mat.baseShape:addCorner( x,y )
		mat.baseShape:addCorner( x,y+30 )
		mat.baseShape:addCorner( x-40,y+30 )
		mat.baseShape:close()		-- add connection between first and last point
		mat.baseShape:setSelected( false )
		mat.baseShape:setEditing( false )
		-- mat.baseShape:moveTo( love.graphics.getWidth(),  - 30 - k*35 )
		mat.baseShape:update()
		
		-- create a button for "selected":
		mat.selShape = Shape:new( mat.name )
		mat.selShape:addCorner( x-60, y )
		mat.selShape:addCorner( x,y )
		mat.selShape:addCorner( x,y+30 )
		mat.selShape:addCorner( x-60,y+30 )
		mat.selShape:close()		-- add connection between first and last point
		mat.selShape:setSelected( false )
		mat.selShape:setEditing( false )
		-- mat.selShape:moveTo( , love.graphics.getHeight() - 30 - k*35 )
		mat.selShape:update()
		-- self.shapes[#self.shapes+1] = mat.baseShape
		
		if k == #self.materials then	-- set one of the materials to selected:
			mat.currentShape = mat.selShape
			self.currentMaterial = mat.name
		else
			mat.currentShape = mat.baseShape
		end
	end
end

function ShapeControl:renderMaterials()
	local numFinished = 0	
	for k = 1, #self.materials do
		-- render the base (non selected) shape:
		if self.materials[k].baseShape.image.img then
			numFinished = numFinished + 1
		else
			self.materials[k].baseShape:update()
		end
		
		-- render the selected shape:
		if self.materials[k].selShape.image.img then
			numFinished = numFinished + 1
		else
			self.materials[k].selShape:update()
		end
	end
	if numFinished >= #self.materials*2 then
		self.materialsRendered = true
	end
end

function ShapeControl:uiHit()
	x, y = love.mouse.getPosition()
	for k, m in pairs(self.materials) do
		if m.currentShape:pointInsideBoundings( x, y ) then
			for i,m2 in pairs(self.materials) do	-- set all others to unselected
				m2.currentShape = m2.baseShape
			end
			m.currentShape = m.selShape
			self.currentMaterial = m.name
			if self.selectedShape then
				self.selectedShape:setMaterial( m.name )
			end
			return true
		end
	end
	return false
end


-------------------------------------------
-- Save and load to the current imgName:
-------------------------------------------
function ShapeControl:save()
	print("saving:", self.designName .. ".sav" )
	if self.designName then
		local content = fileHeader
		
		-- go through the shapes in order of layer and append them:
		for k = 1, #self.shapes do
			content = content .. tostring(self.shapes[k])
		end
		love.filesystem.write( "Designs/" .. self.designName .. ".sav", content )
	end
end

function ShapeControl:load()
	
	self.shapes = {}
	self.selectedShape = nil
	self.editedShape = nil
	self.draggedShape = nil
	
	print("Loading:", self.designName .. ".sav" )
	
	if self.designName then
		local ok, content = pcall(love.filesystem.read, "Designs/" .. self.designName .. ".sav" )
		if not ok then print("\tDidn't find " .. self.designName .. ".sav" ) end
		while ok and content and #content > 0 do
			
			s, e = string.find(content, "Shape:.-endShape")
			if s and e then
				print("Found shape:", content:sub(s,e))
				self.shapes[#self.shapes+1] = ShapeControl:shapeFromString( content:sub(s,e) )
				content = content:sub(e+1, #content)
			else
				break
			end
		end
	end
end

function ShapeControl:shapeFromString( str )

	-- initialize with default values:
	local tmpShape = {
		materialName = "metal",
		x = 0,
		y = 0,
		closed = false,
		points = {},
	}
	
	-- get the actual values from the string:
	local key, value, pos, x, y
	for k, line in lines(str) do
		key, value = line:match("\t(.+): (.+)")
		if key and value then
			print("found:", key, value)
			if key == "material" then
				tmpShape.materialName = value
			elseif key == "closed" then
				if value == "true" then
					tmpShape.closed = true
				end
			elseif key == "x" then
				tmpShape.x = tonumber(value)
			elseif key == "y" then
				tmpShape.y = tonumber(value)
			elseif key == "Point" then
				x, y = value:match("([%d\.]+), ([%d\.]+)")
				print("\t\t", x, y)
				tmpShape.points[#tmpShape.points+1] = {x=x, y=y}
			end
		end
	end


	local shape = Shape:new( tmpShape.materialName )

	for k = 1, #tmpShape.points do
		--tmpShape.points[k].x = tmpShape.points[k].x + tmpShape.x
		--tmpShape.points[k].y = tmpShape.points[k].y + tmpShape.y
	end
	
	for k = 1, #tmpShape.points, 3 do
		shape:addCorner( tmpShape.points[k].x, tmpShape.points[k].y )
	end
	
	if tmpShape.closed then
		shape:close()	
	end
	
	local corner, k2
	for k = 1, #shape.corners do
		corner = shape.corners[k]
		if corner.bezierNext then
			k2 = (k-1)*3+1		-- index of the corner in the full point list
			-- set the two control points that aren't corners to the correct positions:
			if corner.bezierNext.cPoints[2].x ~= tmpShape.points[k2+1].x or
				corner.bezierNext.cPoints[2].y ~= tmpShape.points[k2+1].y then
				
				corner.bezierNext.cPoints[2].x = tmpShape.points[k2+1].x
				corner.bezierNext.cPoints[2].y = tmpShape.points[k2+1].y
				corner.bezierNext.cPoints[2].hasBeenMoved = true
			end
			if corner.bezierNext.cPoints[3].x ~= tmpShape.points[k2+2].x or
				corner.bezierNext.cPoints[3].y ~= tmpShape.points[k2+2].y then
				
				corner.bezierNext.cPoints[3].x = tmpShape.points[k2+2].x
				corner.bezierNext.cPoints[3].y = tmpShape.points[k2+2].y
				corner.bezierNext.cPoints[3].hasBeenMoved = true
			end
			corner.bezierNext:setModified()
		end
	end
	
	shape:setEditing( false )
	shape:setSelected( false )
	shape:setModified()
	shape:calcBoundingBox()
	return shape
end
-------------------------------------------
