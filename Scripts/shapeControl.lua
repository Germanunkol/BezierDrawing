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
	self.snapSize = self.gridSize
	self.canvasWidth = canvasWidth
	self.canvasHeight = canvasHeight
	
	self:resetShapes()
	
	self.selectedShapes = {}
	self.editedShape = nil
	
	self.materialList = {}

	-- initialize box selection:
	self.boxSel = {}
	
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

function ShapeControl:resetShapes()
	self.layers = {
		[1] = {name = "exterior"},
		[2] = {name = "interior lower"},
		[3] = {name = "interior upper"},
	}
	
	self.shapes = self.layers[1]
end

function ShapeControl:getSelectedShape()
	return self.selectedShapes
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

function ShapeControl:cycleLayers( num )
	if num and self.layers[num] then -- set directly:
		self.shapes = self.layers[num]
	else -- cycle:
		for k = 1, #self.layers do
			if self.shapes == self.layers[k] then
				if k == #self.layers then
					self.shapes = self.layers[1]
				else
					self.shapes = self.layers[k+1]
				end
				break
			end
		end
	end
	
	
	if self.editedShape then
		self.editedShape:setEditing( false )
		self.editedShape = nil
	end

	self:unselectAll()

	-- select a material that's valid for the layer:
	self:selectMaterial()
end

function ShapeControl:unselectAll()
	if #self.selectedShapes > 0 then
		for k = 1, #self.selectedShapes do
			self.selectedShapes[k]:setSelected( false )
			self.selectedShapes[k] = nil
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
							mX = math.floor((mX+self.snapSize/2)/self.snapSize)*self.snapSize
							mY = math.floor((mY+self.snapSize/2)/self.snapSize)*self.snapSize
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
						
						if not love.keyboard.isDown("lshift") and
							not hit:getSelected() then
							self:unselectAll()
						end

						if not hit:getSelected() then
							hit:setSelected( true )
							self.selectedShapes[#self.selectedShapes+1] = hit
						end
					
						self.draggedShape = { startDragX = mX, startDragY = mY }
						for k = 1, #self.selectedShapes do
							self.selectedShapes[k]:startDragging( mX, mY )
						end
					else
						self:unselectAll()
						self.boxSel.active = true
						self.boxSel.startX, self.boxSel.startY = cam:screenPos(mX, mY)
					end

				end
			end
		end
	end
	if button == "r" then
		if self.draggedShape then
			for k = 1, #self.selectedShapes do
				self.selectedShape[k]:drop()
			end
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
						self:unselectAll()
						self.editedShape = nil
					end
				else	-- right click on control point should reset this control point!
					hit:reset()
				end
			end
		end
	end
	
	if self.editedShape then
		if self.editedShape ~= self.selectedShapes[1] then
			if self.selectedShapes[1] then
				self:unselectAll()
			end
			self.selectedShapes[1] = self.editedShape
		end
	end
	for k = 1, #self.shapes do
		if self.shapes[k]:getNumCorners() <= 1 and self.shapes[k] ~= self.editedShape then
			for i = 1, #self.selectedShapes do
				if self.selectedShapes[i] == self.shapes[k] then
					removeFromTbl( self.selectedShapes, self.selectedShapes[i])
				end
			end
			
			removeFromTbl( self.shapes, self.shapes[k] )
		end
	end
end

function ShapeControl:release( x, y, button )
	if self.draggedShape then
		self.draggedShape = nil	
		for k = 1, #self.selectedShapes do
			self.selectedShapes[k]:stopDragging( x, y )
		end
	elseif self.editedShape then
		self.editedShape:release()
--[[	else
		local mX, mY = cam:worldPos( x, y )
		hit = self:getHitShape( mX, mY )
		if hit then
			if not love.keyboard.isDown("lshift") then
				self:unselectAll()
			end
			
			if not hit:getSelected() then
				hit:setSelected( true )
				self.selectedShapes[#self.selectedShapes+1] = hit
			end
		end]]--
	end
	if self.boxSel.active then
		local mX, mY = cam:worldPos( love.mouse.getPosition() )
		self:boxSelect( self.boxSel.startX, self.boxSel.startY, mX, mY ) 
		self.boxSel.active = false
	end
end

function ShapeControl:boxSelect( x1, y1, x2, y2 )
	self:unselectAll()
	for k = 1, #self.shapes do
		if self.shapes[k]:isInsideBox( x1, y1, x2, y2 ) then
			self.selectedShapes[#self.selectedShapes+1] = self.shapes[k]
			self.shapes[k]:setSelected( true )
		end
	end
end
function ShapeControl:keypressed( key, unicode )
	if key == "g" then
		self:setSnapToGrid( not self:getSnapToGrid() )
	elseif key == "h" then
		self:setSnapToCPoints( not self:getSnapToCPoints() )
	elseif key == "delete" then
		if #self.selectedShapes > 0 then
			print(#self.selectedShapes)
			for k = 1, #self.selectedShapes do
				if self.editedShape == self.selectedShapes[k] then
					self.editedShape = nil
				end
			
				removeFromTbl( self.shapes, self.selectedShapes[k] )
			
				self.selectedShapes[k] = nil
			end
		end
	elseif key == "+" then		-- move shape to lower layer:
		if #self.selectedShapes > 0 then
			for k = #self.shapes-1, 1 do	-- if it's the highest shape, don't bother moving it
				if self.shapes[k]:getSelected() and not self.shapes[k+1]:getSelected() then
					self.shapes[k], self.shapes[k+1] = self.shapes[k+1], self.shapes[k]
					self.shapes[k]:setLayer( k )
					self.shapes[k+1]:setLayer( k+1 )
					print("new layers:", k, k+1)
				end
			end
		end
	elseif key == "-" then		 -- move shape to higher layer:
		if #self.selectedShapes > 0 then
			for k = 2, #self.shapes do	-- if it's the lowest shape, don't bother moving it
				if self.shapes[k]:getSelected() and not self.shapes[k-1]:getSelected() then
					self.shapes[k], self.shapes[k-1] = self.shapes[k-1], self.shapes[k]
					self.shapes[k]:setLayer( k )
					self.shapes[k-1]:setLayer( k-1 )
					print("new layers:", k, k-1)
				end
			end
		end
	--[[elseif key == "m" then
	
		-- Scroll through all available materials.
		-- Find the one the shape is currently using
		-- then assign the next one, or the first material
		-- if the current one is the last one in the list:
		if self.selectedShapes then
			mat = self.selectedShapes:getMaterial()
			for k = 1, #self.materialList do
				if self.materialList[k] == mat then
					if k < #self.materialList then
						self.selectedShapes:setMaterial(self.materialList[k+1])
					else
						self.selectedShapes:setMaterial(self.materialList[1])
					end
				end
			end
		end]]--
	elseif key == "x" then
		for k = 1, #self.selectedShapes do
			self.selectedShapes[k]:flip( "x" )
		end
	elseif key == "y" then
		for k = 1, #self.selectedShapes do
			self.selectedShapes[k]:flip( "y" )
		end
	elseif key == "d" then
		if #self.selectedShapes > 0 and not self.editedShape and not self.draggedShape then
			local new = {}
			for k = 1, #self.selectedShapes do
				new[k] = self.selectedShapes[k]:duplicate()
				
				self.shapes[#self.shapes+1] = new[k]
				self.selectedShapes[k]:setSelected( false )
				new[k]:setSelected( true )
				new[k]:setLayer( #self.shapes )
			end
			self.selectedShapes = new
		end
	elseif key == "s" then
		self:save()
	elseif key == "o" then
		self:load()
	elseif key == "u" then
		self:cycleLayers()
	elseif key == "1" or key == "2" or key == "3" then
		self:cycleLayers(tonumber(key))
	elseif key == "i" then
		for k = 1, #self.selectedShapes do
			self.selectedShapes[k]:modifyAngle( 0, 1 )
		end
	elseif key == "k" then
		for k = 1, #self.selectedShapes do
			self.selectedShapes[k]:modifyAngle( 0, -1 )
		end
	elseif key == "j" then
		for k = 1, #self.selectedShapes do
			self.selectedShapes[k]:modifyAngle( 1, 0 )
		end
	elseif key == "l" then
		for k = 1, #self.selectedShapes do
			self.selectedShapes[k]:modifyAngle( -1, 0 )
		end
	elseif key == "p" then
		self:saveImages()
	elseif key == "escape" then
		if self.editedShape then
			self.editedShape:setEditing( false )
			self.editedShape = nil
		end
	end
end

local mouseX, mouseY = 0,0

function ShapeControl:draw()

	local reachedCurrentLayer = false
	for i = 1,#self.layers do
		for k = 1, #self.layers[i] do
			if self.layers[i] == self.shapes then
				if self.editedShape ~= self.layers[i][k] then		-- draw edited shape last!
					self.layers[i][k]:draw( self.editedShape )
				end
				reachedCurrentLayer = true
			else
				if reachedCurrentLayer then
					self.layers[i][k]:draw( true )	-- draw layers above current in wireframe mode
				else
					self.layers[i][k]:draw( false )
				end
			end
		end
	end
	if self.editedShape then
		self.editedShape:draw( self.editedShape )
	end
	for k = 1, #self.selectedShapes do
		self.selectedShapes[k]:drawOutline()
	end

end

function ShapeControl:drawUI()
	--if self.selectedShapes then
	if self.shapes == self.layers[1] then	-- exterior:
		for k = 1,#self.materials do
			if not self.materials[k].interior then
			--self.materials[k].baseShape:moveTo( 0, 0 )
					--self.selectedShapes.boundingBox.maxX + 25,
					--self.selectedShapes.boundingBox.maxY - 20 - k*30)
			--self.materials[k].baseShape:update()
				self.materials[k].currentShape:draw( )
			end
		end
	else
		for k = 1,#self.materials do
			if self.materials[k].interior then
				self.materials[k].currentShape:draw( )
			end
		end
	end
	--end
	love.graphics.setColor(255,120,50, 255)
	local str = "(" .. mouseX/self.gridSize .. "," .. mouseY/self.gridSize .. ")"
	love.graphics.print(str, love.graphics.getWidth()-love.graphics.getFont():getWidth(str) - 10,
							love.graphics.getHeight() - 30)
	love.graphics.setColor(255,255,255,255)
	
	local x, y, str = -10, 10
	for k = 1, #self.layers do
		if self.shapes == self.layers[k] then
			y = displayHeader( x, y, k .. " " .. self.layers[k].name)
		else
			y = displayKey( x, y, k, self.layers[k].name )
		end
		--x = love.graphics.getWidth() - 10 - love.graphics.getFont():getWidth(self.layers[k].name)
		--love.graphics.print( self.layers[k].name, x, 10 + k*love.graphics.getFont():getHeight())
	end

	if self.boxSel.active then
		local mX, mY = love.mouse.getPosition()
		--mX, mY = cam:worldPos(mX, mY)
		mX = mX - self.boxSel.startX
		mY = mY - self.boxSel.startY
		love.graphics.rectangle( "line", self.boxSel.startX, self.boxSel.startY, mX, mY)
	end
end

function ShapeControl:update( mX, mY, dt )

	mouseX, mouseY = mX, mY

	if not self.materialsRendered then
		self:renderMaterials()
	end

	for i = 1, #self.layers do
		for k = 1, #self.layers[i] do
			if self.editedShape and self.editedShape == self.layers[i][k] then
				if self.editedShape:isMoving() then
					if self.snapToCPoints then
						-- check if other points are close by:
						local hit = self.editedShape:checkHit( mX, mY )
				
						if hit then
							mX = hit.x
							mY = hit.y
						else
							if self.snapToGrid then
								mX = math.floor((mX+self.snapSize/2)/self.snapSize)*self.snapSize
								mY = math.floor((mY+self.snapSize/2)/self.snapSize)*self.snapSize
							end
						end
					else
						if self.snapToGrid then
							mX = math.floor((mX+self.snapSize/2)/self.snapSize)*self.snapSize
							mY = math.floor((mY+self.snapSize/2)/self.snapSize)*self.snapSize
						end
					end
					self.editedShape:movePoint( mX, mY )
				end
			end
			self.layers[i][k]:update( dt )
		end
	end
	
	if self.draggedShape then
		if self.snapToGrid then
			local dX, dY = mX - self.draggedShape.startDragX, mY - self.draggedShape.startDragY
			mX = math.floor((dX+self.snapSize/2)/self.snapSize)*self.snapSize
					+ self.draggedShape.startDragX
			mY = math.floor((dY+self.snapSize/2)/self.snapSize)*self.snapSize
					+ self.draggedShape.startDragY
		end
		for k = 1, #self.selectedShapes do
			self.selectedShapes[k]:drag( mX, mY )
		end
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

function ShapeControl:setSnapSize()
	if cam:getZoom() == 2 then
		self.snapSize = self.gridSize/2
	else
		self.snapSize = self.gridSize
	end
end

function ShapeControl:getSnapToCPoints( ) return self.snapToCPoints end
function ShapeControl:getSnapToGrid( ) return self.snapToGrid end

function ShapeControl:selectMaterial()
	for	k = 1,#self.materials do
		self.materials[k].currentShape = self.materials[k].baseShape
	end
	if self.shapes == self.layers[1] then	-- exterior
		for	k = 1,#self.materials do
			if not self.materials[k].interior then
				self.materials[k].currentShape = self.materials[k].selShape
				self.currentMaterial = self.materials[k].name
				break
			end
		end
	else
		for	k = 1,#self.materials do
			if self.materials[k].interior then
				self.materials[k].currentShape = self.materials[k].selShape
				self.currentMaterial = self.materials[k].name
				break
			end
		end
	end
end

function ShapeControl:loadMaterials()
	print("Loading materials:")
	local files = love.filesystem.enumerate("Materials")
	self.materials = {}
	for k, name in pairs(files) do
		if name:find(".lua") == #name-3 then
			local interior = false
			if name:find("interior") then
				interior = true
			end
			self.materials[#self.materials+1] = {
				name = name:sub( 1, #name-4 ),
				interior = interior
			}
			print("\t" , self.materials[#self.materials].name)
		end
	end
	
	local yExterior = 0
	local yInterior = 0
	local yCurrent = 0
	
	for k, mat in pairs(self.materials) do
		if mat.interior then
			yInterior = yInterior + 1
			yCurrent = yInterior
		else
			yExterior = yExterior + 1
			yCurrent = yExterior
		end
		local x, y = love.graphics.getWidth(), love.graphics.getHeight() - 30 - yCurrent*35
		
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
		
		mat.currentShape = mat.baseShape
	end
	
	-- set a non-interior shape to "Selected":
	self:selectMaterial()
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
	
	if self.shapes == self.layers[1] then -- exterior
		for k, m in pairs(self.materials) do
			if not m.interior then
				if m.currentShape:pointInsideBoundings( x, y ) then
					for i,m2 in pairs(self.materials) do	-- set all others to unselected
						m2.currentShape = m2.baseShape
					end
					m.currentShape = m.selShape
					self.currentMaterial = m.name
					for k = 1, #self.selectedShapes do
						self.selectedShapes[k]:setMaterial( m.name )
					end
					return true
				end
			end
		end
	else	-- interior
		for k, m in pairs(self.materials) do
			if m.interior then
				if m.currentShape:pointInsideBoundings( x, y ) then
					for i,m2 in pairs(self.materials) do	-- set all others to unselected
						m2.currentShape = m2.baseShape
					end
					m.currentShape = m.selShape
					self.currentMaterial = m.name
					for k = 1, #self.selectedShapes do
						self.selectedShapes[k]:setMaterial( m.name )
					end
					return true
				end
			end
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
		content = content .. "Layer: exterior\n"
		for k = 1, #self.layers[1] do
			content = content .. tostring(self.layers[1][k])
		end
		content = content .. "endLayer\n"
		content = content .. "Layer: interior1\n"
		for k = 1, #self.layers[2] do
			content = content .. tostring(self.layers[2][k])
		end
		content = content .. "endLayer\n"
		content = content .. "Layer: interior2\n"
		for k = 1, #self.layers[3] do
			content = content .. tostring(self.layers[3][k])
		end
		content = content .. "endLayer\n"
		
		love.filesystem.write( "Designs/" .. self.designName .. ".sav", content )
	end
end

function ShapeControl:load()
	
	self:resetShapes()
	
	self.selectedShapes = {}
	self.editedShape = nil
	self.draggedShape = nil
	
	print("Loading:", self.designName .. ".sav" )
	
	if self.designName then
		local ok, content = pcall(love.filesystem.read, "Designs/" .. self.designName .. ".sav" )
		if not ok then print("\tDidn't find " .. self.designName .. ".sav" ) end
		
		local layer = 1
		for str in content:gmatch("Layer:(.-)endLayer\n") do
			self.shapes = self.layers[layer]
			if not self.shapes then
				print("\tERROR: invalid layer in file!")
				self:resetShapes()
				break
			end
			for s in str:gmatch("(Shape:.-endShape)") do
				self.shapes[#self.shapes+1] = ShapeControl:shapeFromString( s )
			end
			layer = layer+1
		end
	end
	
	-- start with the layer selected that is highest in the hierarchy:
	for k = #self.layers, 1, -1 do
		if #self.layers[k] > 0 or k == 1 then
			self.shapes = self.layers[k]
			break
		end
	end

	self:selectMaterial()
	
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
		key, value = line:match("\t\t(.+): (.+)")
		if key and value then
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
			elseif key == "angX" then
				tmpShape.angX = tonumber(value)
			elseif key == "angY" then
				tmpShape.angY = tonumber(value)
			elseif key == "Point" then
				x, y = value:match("([-?%d.]+), ([-?%d.]+)")
				tmpShape.points[#tmpShape.points+1] = {x=tonumber(x), y=tonumber(y)}
			end
		end
	end


	local shape = Shape:new( tmpShape.materialName )
	shape:setAngle( tmpShape.angX or 0, tmpShape.angY or 0 )

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
			else
				corner.bezierNext.cPoints[2].hasBeenMoved = false
				
			end
			if corner.bezierNext.cPoints[3].x ~= tmpShape.points[k2+2].x or
				corner.bezierNext.cPoints[3].y ~= tmpShape.points[k2+2].y then
				
				corner.bezierNext.cPoints[3].x = tmpShape.points[k2+2].x
				corner.bezierNext.cPoints[3].y = tmpShape.points[k2+2].y
				corner.bezierNext.cPoints[3].hasBeenMoved = true
			else
				corner.bezierNext.cPoints[3].hasBeenMoved = false
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

function ShapeControl:saveImages( )
	local bb = {}
	local canvasDiff, canvasNM, canvasSM
	local boundings
	local currentLayer
	local filename
	
	
	for k = 1, #self.layers do
		currentLayer = self.layers[k]
		if #currentLayer > 0 then	-- don't bother saving layer if it's empty!
			bb.minX = math.huge
			bb.minY = math.huge
			bb.maxX = -math.huge
			bb.maxY = -math.huge
			for i = 1, #currentLayer do
				boundings = currentLayer[i]:getBoundingBox()
				bb.minX = math.min( boundings.minX, bb.minX )
				bb.minY = math.min( boundings.minY, bb.minY )
				bb.maxX = math.max( boundings.maxX, bb.maxX )
				bb.maxY = math.max( boundings.maxY, bb.maxY )
			end
			
			canvasDiff = love.graphics.newCanvas( bb.maxX - bb.minX,
												bb.maxY - bb.minY)
			canvasNM = love.graphics.newCanvas( bb.maxX - bb.minX,
												bb.maxY - bb.minY)
			canvasSM = love.graphics.newCanvas( bb.maxX - bb.minX,
												bb.maxY - bb.minY)
			love.graphics.push()
			love.graphics.translate( -bb.minX, -bb.minY )
			for i = 1, #currentLayer do
				love.graphics.setCanvas( canvasDiff )
				love.graphics.setColor(255,255,255,255)
				currentLayer[i]:drawPlain( "diffuse" )
				love.graphics.setCanvas( canvasNM )
				love.graphics.setColor(255,255,255,255)
				currentLayer[i]:drawPlain( "normal" )
				love.graphics.setCanvas( canvasSM )
				love.graphics.setColor(255,255,255,255)
				currentLayer[i]:drawPlain( "specular" )
			end
			love.graphics.pop()
			love.graphics.setCanvas()
			filename = "Designs/" .. self.designName .. "_" .. k .. "_"
			canvasDiff:getImageData():encode( filename .. "d.png" )
			canvasNM:getImageData():encode( filename .. "n.png" )
			canvasSM:getImageData():encode( filename .. "s.png" )
		end
	end
end
