require("Scripts/bezier")
require("Scripts/middleclass")
require("Scripts/corner")
require("Scripts/misc")
require("Scripts/polygon")

local clickDist = 10
local IMG_PADDING = 25
local ANGLE_STEP = 0.1--math.pi/30
local MAX_ANGLE = 0.9--14*math.pi/30
local ANG_DISPL_SIZE = 10

Shape = class("Shape")
local shapes = 0
local numRenderedShapes = 0
local function newShapeID()
	shapes = shapes+1
	return shapes -1
end

function Shape:initialize( materialName )
	self.corners = {}
	self.curves = {}
	self.editing = true
	self.selected = true
	self.maxAngle = 10
	self.boundingBox = {}
	self.polygon = {}
	self.triangles = {}
	self.shapeID = newShapeID()
	self.outCol = {r=255,g=120,b=50,a=255}
	--self.insCol = {r=170,g=170,b=255,a=200}
	self.insCol = {r=255,g=255,b=170,a=255}
	--self.insCol = {r=50,g=255,b=20,a=200}
	self.lineWidth = 2
	
	self.angle = { x=0,y=0 }	
	self.materialName = materialName or "metal"
	self.material = loadMaterial( self.materialName )
	
	--self.finalCanvas = love.graphics.newCanvas()
	--self.tempCanvas = love.graphics.newCanvas()
	self:resetImage()
end

function Shape:resetImage()
	self.image = {}
	self.image.rendering = false
	self.image.percent = 0
	self.image.finished = false
	
	self.shader = love.graphics.newPixelEffect(
				love.filesystem.read("/Scripts/Shaders/normalmap.glsl") )
	local x, y = love.graphics.getWidth(), love.graphics.getHeight()
	self.shader:send( "Resolution", {x, y} )
	
	-- flush thread messages:
	floodFillThread:get( self.shapeID .. "(done)")
	
	if self.materialName:find("interior") then
		self.shader:send( "AmbientColor", {1.0,1.0,1.0,0.9} )
	else
		self.shader:send( "AmbientColor", {1.0,1.0,1.0,0.5} )
	end
end

function interpolate( P1, P2, amount )
	local x = P1.x + (P2.x-P1.x)*amount
	local y = P1.y + (P2.y-P1.y)*amount
	return Point:new( x, y )
end

function Shape:setMaterial( mat )
	self.materialName = mat
	self.material = loadMaterial( self.materialName )
	self:resetImage()
	if self.closed and not self.edited then
		--self:startFill()
		self:resetImage()
	end
end

function Shape:getMaterial()
	return self.materialName
end

function Shape:setModified()
	self.modified = true
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
			
			local b = Bezier:new( {self.selectedCorner, P1, P2, newCorner}, self.maxAngle, 1)
			self.curves[#self.curves +1] = b
			
			self.selectedCorner.bezierNext = b
			newCorner.bezierPrev = b
		else
			if not self.selectedCorner.prev then
				self.selectedCorner.prev = newCorner
				newCorner.next = self.selectedCorner
				
				local P1 = interpolate( self.selectedCorner, newCorner, 0.25 )
				local P2 = interpolate( self.selectedCorner, newCorner, 0.75 )
				
				local b = Bezier:new( {newCorner, P1, P2, self.selectedCorner}, self.maxAngle, 1)
				self.curves[#self.curves +1] = b
				
				self.selectedCorner.bezierPrev = b
				newCorner.bezierNext = b
			end
		end
	end
	
	self:selectCorner( newCorner )
	self.modified = true
	return newCorner
end

function Shape:addCurve( connectTo )
	if self.selectedCorner then
		if self.selectedCorner.next and self.selectedCorner.prev then
			return
		end
	end
	
	if self.selectedCorner then
		self.closed = true
		if not self.selectedCorner.next then
			self.selectedCorner.next = connectTo
			connectTo.prev = self.selectedCorner
			
			local P1 = interpolate( self.selectedCorner, connectTo, 0.25 )
			local P2 = interpolate( self.selectedCorner, connectTo, 0.75 )
			
			local b = Bezier:new( {self.selectedCorner, P1, P2, connectTo}, self.maxAngle, 1)
			self.curves[#self.curves +1] = b
			
			self.selectedCorner.bezierNext = b
			connectTo.bezierPrev = b
		else
			if not self.selectedCorner.prev then
				self.selectedCorner.prev = connectTo
				connectTo.next = self.selectedCorner
				
				local P1 = interpolate( connectTo, self.selectedCorner, 0.25 )
				local P2 = interpolate( connectTo, self.selectedCorner, 0.75 )
				
				local b = Bezier:new( {connectTo, P1, P2, self.selectedCorner}, self.maxAngle, 1)
				self.curves[#self.curves +1] = b
				
				self.selectedCorner.bezierPrev = b
				connectTo.bezierNext = b
			end
		end
		
		self:selectCorner( nil )
	end
	self.modified = true
end

function Shape:close()
	if #self.corners > 2 then
		local prevSelected = self.selectedCorner
		self.selectedCorner = self.corners[#self.corners]
		self:addCurve( self.corners[1] )
		self.selectedCorner = prevSelected	-- reset to the selected corner!
		self.closed = true
	end
end

function Shape:selectCorner( new )
	if self.selectedCorner then
		self.selectedCorner:deselect()
		self.selectedCorner = nil
	end
	if new then
		self.selectedCorner = new
		new:select()
	end
end

function Shape:isInsideBox( x1, y1, x2, y2 )
	if x2 < x1 then x2,x1 = x1,x2 end
	if y2 < y1 then y2,y1 = y1,y2 end
	if x1 < self.boundingBox.minX and y1 < self.boundingBox.minY and
		x2 > self.boundingBox.maxX and y2 > self.boundingBox.maxY then
		return true
	else
		return false
	end
end

function Shape:getSelectedCorner()
	return self.selectedCorner
end


function Shape:removeCorner( p )

	removeFromTbl( self.corners, p )
	
	-- join previous and next:
	if p.prev and p.next and not self.closed then
		local P1, P2, P3, P4
		P1 = p.prev
		P2 = p.bezierPrev:getCPoint( 3 )
		P3 = p.bezierNext:getCPoint( 2 )
		P4 = p.next
		
		local b = Bezier:new( { P1, P2, P3, P4 }, self.maxAngle, 1)
		self.curves[#self.curves +1] = b
		
		P4.bezierPrev = b
		P1.bezierNext = b
		
		P4.prev = P1
		P1.next = P4
	else
		if p.next then
			p.next.prev = nil
			p.next.bezierPrev = nil
		end
		if p.prev then
			p.prev.next = nil
			p.prev.bezierNext = nil
		end
		if self.closed then
			self:selectCorner( nil )
		end
		self.closed = false
	end
	
	if self.selectedCorner == p or self.selectedCorner == nil then
		for k=1, #self.corners do
			if  self.corners[k].next == nil then
				self:selectCorner( self.corners[k] )
				break
			end
		end
	end
	
	removeFromTbl( self.curves, p.bezierPrev )
	removeFromTbl( self.curves, p.bezierNext )
	self.modified = true
end

function Shape:checkHit( x, y, ignore )

	ignore = ignore or self.draggedPoint
	local hit, dist
	local minDist = clickDist/cam:getZoom()
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

function Shape:click( x, y, button, dontDrag )
	if button == "l" then
		local hit = self:checkHit( x, y )
		if hit then
			if not dontDrag then
				self.draggedPoint = hit
			end
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

function Shape:drag( x, y )
	self.offsetX, self.offsetY = x - self.startDragX, y - self.startDragY
end

function Shape:startDragging( x, y )
	self.dragged = true
	self.startDragX, self.startDragY = x, y
end

function Shape:stopDragging( x, y )
	if self.offsetX and self.offsetY then
		for k = 1, #self.curves do
			for i = 1, #self.curves[k].cPoints do
				self.curves[k].cPoints[i]:addOffset( self.offsetX, self.offsetY )
			end
		end
		for k = 1, #self.curves do
			for i = 1, #self.curves[k].cPoints do
				self.curves[k].cPoints[i]:removeOffsetLock()
			end
		end
	end
	self.dragged = false
	self.modified = true
end

function Shape:moveTo( x, y )
	self.offsetX, self.offsetY = x, y
	self:stopDragging()
end

function Shape:drop()	-- stop dragging and reset
	self.dragged = false
end

function Shape:draw( editMode )
	
	--love.graphics.setCanvas(self.tempCanvas)
	if self.image.tempImage then
		love.graphics.draw( self.image.tempImage, self.boundingBox.minX-IMG_PADDING,
							 self.boundingBox.minY-IMG_PADDING )
	end
	if self.dragged then
		love.graphics.push()
		love.graphics.translate( self.offsetX, self.offsetY )
	end
	
	if self.image.diffuseMap and not self.editing and self.boundingBox and not editMode then
	
		local x, y = love.mouse.getPosition()
		self.shader:send( "LightPos", {x, (love.graphics.getHeight() - y), .04} )
		self.shader:send("nm", self.image.normalMap)
		self.shader:send("sm", self.image.specularMap)
		--if self.selected then
		--	love.graphics.setColor(255,255,255,200)
		--else
		love.graphics.setColor(255,255,255,255)
		--end
		love.graphics.setPixelEffect(self.shader)
		love.graphics.draw( self.image.diffuseMap,
							self.boundingBox.minX - IMG_PADDING,
							self.boundingBox.minY - IMG_PADDING )
		--love.graphics.draw( self.image.nm, self.boundingBox.minX-5, self.boundingBox.minY-5 )
	--	love.graphics.draw( self.image.specularMap,
	--						self.boundingBox.minX +150 - IMG_PADDING,
	--						self.boundingBox.minY - IMG_PADDING )
		--love.graphics.draw( self.image.nm, self.boundingBox.minX-5, self.boundingBox.minY-5 )
	--	love.graphics.draw( self.image.normalMap,
	--						self.boundingBox.minX +300- IMG_PADDING,
	--						self.boundingBox.minY - IMG_PADDING )
		--love.graphics.draw( self.image.nm, self.boundingBox.minX-5, self.boundingBox.minY-5 )
		--love.graphics.setColor(255,255,255,255)
		--love.graphics.setLineWidth(2)
		--for k,c in pairs( self.curves ) do
			--for i = 1,#c.points-1 do
				--love.graphics.line(c.points[i].x, c.points[i].y, c.points[i+1].x, c.points[i+1].y)
				--if c.points[i].class == Corner then
					--love.graphics.print( c.points[i].x .."," .. c.points[i].y, c.points[i].x, c.points[i].y+10)
				--end
			--end
		--end
		love.graphics.setPixelEffect()
		love.graphics.setBlendMode("alpha")

	elseif not self.image.tempImage then
		if self.image.wireframe then
			love.graphics.setColor(200,200,200,100)
			love.graphics.draw( self.image.wireframe,
				self.boundingBox.minX - IMG_PADDING,
				self.boundingBox.minY - IMG_PADDING )
		else
			for k,c in pairs( self.curves ) do
				c:draw( self.editing, self.closed )
			end
			if self.editing then
				for k,c in pairs( self.corners ) do
					c:draw()
				end
			end
		end
	end
	--love.graphics.setCanvas()
	
	--love.graphics.draw
	
	
	if self.dragged then
		love.graphics.setColor(100,160,255, 255)
	else
		love.graphics.setColor(255,120,50, 150)
	end
	if self.image then
		if self.image.rendering then
			love.graphics.print( "Rendering (" .. self.image.percent .. "%)", 
				 self.boundingBox.minX,
				 self.boundingBox.maxY + 4
			)
			love.graphics.setColor(100,160,255, 255)
			
			local startX, Y = self.boundingBox.minX, self.boundingBox.maxY + 20
			local endX = self.boundingBox.minX +
							(self.boundingBox.maxX - startX)*self.image.percent/100
			
			love.graphics.line( startX, Y, endX, Y )
		end
	end
	
	if self.dragged then
		love.graphics.pop()
	end
end

function Shape:drawOutline()
	if self.dragged then
		love.graphics.setColor(100,160,255, 255)
		love.graphics.push()
		love.graphics.translate( self.offsetX, self.offsetY )
	else
		love.graphics.setColor(255,120,50, 150)
	end
	
	if self.boundingBox and self.selected or self.editing then
		love.graphics.setLineWidth( math.max( 1/cam:getZoom(), 1) )
		local str
		if self.boundingBox.minX and self.boundingBox.maxX ~= self.boundingBox.minX then
			love.graphics.line( self.boundingBox.minX, self.boundingBox.maxY + 20,
					self.boundingBox.maxX, self.boundingBox.maxY + 20)
			str = pixelsToMeters(math.floor(self.boundingBox.maxX - self.boundingBox.minX)) .. " m"
			love.graphics.print( str, self.boundingBox.maxX - love.graphics.getFont():getWidth(str),
					self.boundingBox.maxY + 22)
		end
				
		if self.boundingBox.minY and self.boundingBox.maxY ~= self.boundingBox.minY then
			love.graphics.line( self.boundingBox.maxX + 20, self.boundingBox.minY,
					self.boundingBox.maxX + 20, self.boundingBox.maxY)
			str = pixelsToMeters(math.floor(self.boundingBox.maxY - self.boundingBox.minY)) .. " m"
			love.graphics.print( str, self.boundingBox.maxX + 24,
					self.boundingBox.maxY - love.graphics.getFont():getHeight())
		end

		if self.angle.x ~= 0 or self.angle.y ~= 0 then

			local centerX = self.boundingBox.maxX + ANG_DISPL_SIZE
			local centerY = self.boundingBox.maxY + ANG_DISPL_SIZE
			
			love.graphics.setColor( 128, 255, 255 )
			love.graphics.line( centerX, centerY,
								centerX + ANG_DISPL_SIZE/MAX_ANGLE*self.angle.x,
								centerY - ANG_DISPL_SIZE/MAX_ANGLE*self.angle.y)
			--[[local a,b,x,y,z = self.angle.x, self.angle.y, 0, 0, 10
			local dY,dX
			dY = x*math.cos(b) + math.sin(b) * ( y*math.sin(a) + z*math.cos(a) )
			dX = y*math.cos(a) - z*math.sin(a)
			local centerX = self.boundingBox.minX - ANG_DISPL_SIZE
			local centerY = self.boundingBox.minY - ANG_DISPL_SIZE
			
			love.graphics.setColor( 128, 255, 255 )
			love.graphics.line( centerX, centerY,
								centerX - dX, centerY - dY)
			]]--
			love.graphics.setColor( self.outCol.r, self.outCol.g, self.outCol.b, self.outCol.a )
			love.graphics.circle( "line", centerX, centerY, ANG_DISPL_SIZE)
		end
		self:drawLayer()
	end
	
	if self.dragged then
		love.graphics.pop()
	end
end

function Shape:drawLayer()
	if self.boundingBox then
		if self.layer then
			love.graphics.print( self.layer, self.boundingBox.maxX + 24,
					self.boundingBox.minY + 2)
		end
	end
end

function Shape:setLayer( layer )
	self.layer = layer
end

function Shape:setEditing( bool )
	self.editing = bool
	if bool == true then
		self:resetImage()
		self.selected = true
	end
end

function Shape:setSelected( bool )
	self.selected = bool
end

function Shape:getSelected()
	return self.selected or false
end

function Shape:getNumCorners()
	return #self.corners
end

function Shape:checkLineHit( x, y, zoom )
	local hit, t
	for k = 1, #self.curves do
		hit, t = self.curves[k]:checkLineHit( x, y, clickDist/2 )
		if hit then 
			return self.curves[k], t
		end
	end
end

function Shape:splitCurve( curve, dist )
	-- local prev, next = curve.prev, curve.next
	
	local firstCurve, secondCurve, newCorner = curve:splitCurveAt( dist/curve.length )
	
	local moved = curve.cPoints[2].hasBeenMoved or curve.cPoints[3].hasBeenMoved
	
	for k,p in pairs(firstCurve) do
		if not p.class or not p.class == Corner and not p.class == Point then
			firstCurve[k] = Point:new(p.x, p.y)
		end
		firstCurve[k].hasBeenMoved = moved
	end
	for k,p in pairs(secondCurve) do
		if not p.class or not p.class == Corner and not p.class == Point then
			secondCurve[k] = Point:new(p.x, p.y)
		end
		secondCurve[k].hasBeenMoved = moved
	end
	
	firstCurve = Bezier:new( firstCurve, self.maxAngle, 1 )
	secondCurve = Bezier:new( secondCurve, self.maxAngle, 1 )
	
	self.curves[#self.curves + 1] = firstCurve
	self.curves[#self.curves + 1] = secondCurve
	
	if curve.cPoints[1] then
		curve.cPoints[1].next = newCorner
		curve.cPoints[1].bezierNext = firstCurve
		newCorner.prev = curve.cPoints[1]
		newCorner.bezierPrev = firstCurve
	end
	if curve.cPoints[#curve.cPoints] then
		curve.cPoints[#curve.cPoints].prev = newCorner
		curve.cPoints[#curve.cPoints].bezierPrev = secondCurve
		newCorner.next = curve.cPoints[#curve.cPoints]
		newCorner.bezierNext = secondCurve
	end
	
	self.corners[#self.corners+1] = newCorner
	removeFromTbl( self.curves, curve )
end

function Shape:startFill()

	self:resetImage()

	self.image.rendering = true
	self.image.percent = 0
	
	local serialShape = "ID{" .. self.shapeID .. "}\n"
	serialShape = serialShape .. "bbox{"
	serialShape = serialShape .. self.boundingBox.minX .. ","
	serialShape = serialShape .. self.boundingBox.minY .. ","
	serialShape = serialShape .. self.boundingBox.maxX .. ","
	serialShape = serialShape .. self.boundingBox.maxY .. "}\n"
	
	serialShape = serialShape .. "ang{"
	serialShape = serialShape .. self.angle.x .. ","
	serialShape = serialShape .. self.angle.y .. "}\n"

	serialShape = serialShape .. "mat{"
	serialShape = serialShape .. self.materialName .. "}\n"
	
	self.startRenderTime = love.timer.getTime()

	serialShape = serialShape .. "points{"

	local startPoint = self.curves[1].cPoints[1]
	local curPoint = startPoint
	local curve
	repeat
		curve = curPoint.bezierNext
		for i = 1, #curve.points-1 do
			-- never send doubles!
			if i < 2 or
				curve.points[i].x ~= curve.points[i-1].x or
				curve.points[i].y ~= curve.points[i-1].y then
				
				serialShape	= serialShape ..
					curve.points[i].x .. "," ..
					curve.points[i].y .. "|"
			end
		end
		curPoint = curPoint.next
	until curPoint == startPoint
	
	serialShape	= serialShape .. 
		startPoint.x .. "," ..
		startPoint.y .. "|"
	serialShape = serialShape .. "}\n"

	--print("New shape being sent:\n", serialShape)
	
	floodFillThread:set("newShape" .. numRenderedShapes, serialShape)
	numRenderedShapes = numRenderedShapes + 1
	
	self:renderWireframe()
end

function Shape:finishFill( img, nm, sm )
	--nm:encode("nm.png")
	--img:encode("img.png")
	--sm:encode("sm.png")
	
	--self.image.canvas = love.graphics.newCanvas( img:getWidth(), img:getHeight() )
	--love.graphics.setCanvas( self.image.canvas )
	--love.graphics.setLineStyle("smooth")
	--love.graphics.setLineWidth(self.lineWidth*2)

	--img = love.graphics.newImage( img )
	
	self.image.normalMap = love.graphics.newImage( nm )
	self.image.specularMap = love.graphics.newImage( sm )
	
	--[[love.graphics.setColor( self.material.col.r,
							self.material.col.g,
							self.material.col.b,
							self.material.col.a )
	]]--
	--love.graphics.setColor(255,255,255,255)
	--love.graphics.draw( img, 0, 0 )
	--love.graphics.setColor( 255,255,255,255 )
	--love.graphics.draw( nm, 0, 0 )
--[[	love.graphics.setColor( self.outCol.r, self.outCol.g, self.outCol.b, self.outCol.a )
	--love.graphics.setBlendMode("premultiplied")
	if not self.materialName:find("interior") then
		local a,b,c,d
		for k,curve in pairs( self.curves ) do
			for i = 1,#curve.points-1 do
				a = curve.points[i].x - self.boundingBox.minX + IMG_PADDING
				b = curve.points[i].y - self.boundingBox.minY + IMG_PADDING
				c = curve.points[i+1].x - self.boundingBox.minX + IMG_PADDING
				d = curve.points[i+1].y - self.boundingBox.minY + IMG_PADDING
				love.graphics.line( a, b, c, d )
			end
		end
	end]]--
	--love.graphics.setCanvas()
	--love.graphics.setBlendMode("alpha")
	
	--self.image.diffuseMap = love.graphics.newImage( self.image.canvas:getImageData() )
	self.image.diffuseMap = love.graphics.newImage( img )
	self.image.rendering = false
	self.image.finished = true

	print("\tRendered shape " .. self.shapeID .. " in " .. love.timer.getTime() - self.startRenderTime .. " s.")
end

function Shape:renderWireframe()
	local canvas = love.graphics.newCanvas( self.boundingBox.maxX - self.boundingBox.minX +IMG_PADDING*2,
											self.boundingBox.maxY - self.boundingBox.minY+IMG_PADDING*2 )
	love.graphics.setCanvas( canvas )
	love.graphics.setLineStyle("smooth")
	love.graphics.setLineWidth(2)
	--love.graphics.setBlendMode("premultiplied")

	love.graphics.setColor(255,255,255,255)
	
	local a,b,c,d
	for k,curve in pairs( self.curves ) do
		for i = 1,#curve.points-1 do
			a = curve.points[i].x - self.boundingBox.minX + IMG_PADDING
			b = curve.points[i].y - self.boundingBox.minY + IMG_PADDING
			c = curve.points[i+1].x - self.boundingBox.minX + IMG_PADDING
			d = curve.points[i+1].y - self.boundingBox.minY + IMG_PADDING
			love.graphics.line( a, b, c, d )
		end
	end
	
	love.graphics.setCanvas()
	self.image.wireframe = love.graphics.newImage(canvas:getImageData())
	--canvas:getImageData():encode("wf.png")
	--love.graphics.setBlendMode("alpha")
end

function Shape:calcBoundingBox()
	self.boundingBox.minX = math.huge
	self.boundingBox.minY = math.huge
	self.boundingBox.maxX = -math.huge
	self.boundingBox.maxY = -math.huge
	local boundings
	for k = 1, #self.curves do
		boundings = self.curves[k]:getBoundingBox()
		self.boundingBox.minX = math.min( boundings.minX, self.boundingBox.minX )
		self.boundingBox.minY = math.min( boundings.minY, self.boundingBox.minY )
		self.boundingBox.maxX = math.max( boundings.maxX, self.boundingBox.maxX )
		self.boundingBox.maxY = math.max( boundings.maxY, self.boundingBox.maxY )
	end
end

function Shape:getBoundingBox()
	self:calcBoundingBox()
	return self.boundingBox
end

function Shape:update( dt )

	if self.editing or self.modified then
		for k = 1, #self.curves do
			if self.curves[k]:getModified() then
				self.curves[k]:update()
				self.modified = true
			end
		end
		if self.modified then
			self:calcBoundingBox()
		
			self.modified = false
		end
	else
		if not self.image.finished then
			if not self.image.rendering and self.closed then
				for k = 1, #self.curves do
					self.curves[k]:update()
				end
				self:startFill()
			else
				local percent = floodFillThread:get( self.shapeID .. "(%)")
				if percent then self.image.percent = math.floor(percent) end
				
				local done = floodFillThread:get( self.shapeID .. "(done)")
				
				if done then
					local img = floodFillThread:demand( self.shapeID .. "(img)")
					local nm = floodFillThread:demand( self.shapeID .. "(nm)")
					local sm = floodFillThread:demand( self.shapeID .. "(sm)")
					self:finishFill( img, nm, sm )
				else
					local tmpimg = floodFillThread:get( self.shapeID .. "(tmpimg)")
					if tmpimg then
						self.image.tempImage = love.graphics.newImage( tmpimg )
					end
				end
			end
		end
	end
end

function Shape:pointIsInside( x, y )

	-- a point can only lie in a closed shape:
	if not self.closed then return false end
	
	local P = Point:new( x, y )
	local Pup, Pleft = Point:new( x, -99999 ), Point:new( -99999, y )
	
	local hitLeft, hitUp = 0,0
	
	for k, c in pairs(self.curves) do
		for i = 1, #c.points-1 do
			hit = segmentIntersections( P, Pup, c.points[i], c.points[i+1])
			if hit then
				hitUp = hitUp + 1
			end
			hit = segmentIntersections( P, Pleft, c.points[i], c.points[i+1])
			if hit then
				hitLeft = hitLeft + 1
			end
		end
	end
	if hitUp % 2 == 1 and hitLeft % 2 == 1 then
		love.graphics.setColor( 0, 255, 0, 60 )
		love.graphics.line( P.x, P.y, Pup.x, Pup.y )
		love.graphics.line( P.x, P.y, Pleft.x, Pleft.y )
		return true
	end
	
	love.graphics.setColor( 255, 0, 0, 30 )
	love.graphics.line( P.x, P.y, Pup.x, Pup.y )
	love.graphics.line( P.x, P.y, Pleft.x, Pleft.y )
	return false
end

-- less precice, but more reliable check:
function Shape:pointInsideBoundings( x, y )
	if not self.closed then return false end
	
	if not self.boundingBox then return false end
	
	if x >= self.boundingBox.minX and x <= self.boundingBox.maxX
		and y >= self.boundingBox.minY and y <= self.boundingBox.maxY then
		return true
	end
	
	return false
end

function Shape:flip( dir )

	self:calcBoundingBox()
	
	if dir == "x" then
		local centerX = (self.boundingBox.maxX - self.boundingBox.minX)/2 + self.boundingBox.minX
		for k = 1, #self.curves do
			for i = 1, #self.curves[k].cPoints do
				local x = -self.curves[k].cPoints[i].x + 2*centerX
				self.curves[k].cPoints[i]:directSet( x, self.curves[k].cPoints[i].y )
			end
		end
		for k = 1, #self.curves do
			for i = 1, #self.curves[k].cPoints do
				self.curves[k].cPoints[i]:removeOffsetLock()
			end
		end
		self.angle.x = -self.angle.x
	else
		local centerY = (self.boundingBox.maxY - self.boundingBox.minY)/2 + self.boundingBox.minY
		for k = 1, #self.curves do
			for i = 1, #self.curves[k].cPoints do
				local y = -self.curves[k].cPoints[i].y + 2*centerY
				self.curves[k].cPoints[i]:directSet( self.curves[k].cPoints[i].x, y )
			end
		end
		for k = 1, #self.curves do
			for i = 1, #self.curves[k].cPoints do
				self.curves[k].cPoints[i]:removeOffsetLock()
			end
		end
		self.angle.y = -self.angle.y
	end
	self.modified = true
	self:resetImage()
end

function Shape:setAngle( xAxis, yAxis )
	self.angle.x = math.max(math.min( xAxis, MAX_ANGLE ), -MAX_ANGLE )
	self.angle.y = math.max(math.min( yAxis, MAX_ANGLE ), -MAX_ANGLE )
end

function Shape:modifyAngle( xAxis, yAxis )

	if self.material and self.material.tiltable then
		if xAxis == -1 then
			self.angle.x =  self.angle.x + ANGLE_STEP
		elseif xAxis == 1 then
			self.angle.x = self.angle.x - ANGLE_STEP
		end

		if yAxis == 1 then
			self.angle.y = self.angle.y + ANGLE_STEP
		elseif yAxis == -1 then
			self.angle.y = self.angle.y - ANGLE_STEP
		end
		
		local len = math.sqrt(self.angle.x*self.angle.x + self.angle.y*self.angle.y)
		if len > MAX_ANGLE then
			self.angle.x = self.angle.x/len
			self.angle.y = self.angle.y/len
		end
		
		self:resetImage() -- force a re-render!
		
		print( self.angle.x*180/math.pi, self.angle.y*180/math.pi )
	end
end

function Shape:duplicate()
	new = Shape:new( self.materialName )
	new:setEditing( false )
	new:setSelected( false )
	new.angle.x = self.angle.x
	new.angle.y = self.angle.y
	
	print(#self.corners)
	local c = self.corners[1]
	repeat
		new:addCorner( c.x, c.y )
		c = c.next
	until c == self.corners[1] or c == nil
	
	if self.closed then
		new:close()
	end
	
	local newCurve, oldCurve
	local newCorner, olfCornder
	oldCorner = self.corners[1]
	for k = 1, #new.corners do
		newCorner = new.corners[k]
		newCurve, oldCurve = newCorner.bezierNext, oldCorner.bezierNext
		
		if newCurve and oldCurve then
			-- copy the two center control points of the curve (they're not corners)
			local x, y = oldCurve.cPoints[2].x, oldCurve.cPoints[2].y
			newCurve.cPoints[2].x, newCurve.cPoints[2].y = x,y
			newCurve.cPoints[2].hasBeenMoved = oldCurve.cPoints[2].hasBeenMoved
		
			x, y = oldCurve.cPoints[3].x, oldCurve.cPoints[3].y
			newCurve.cPoints[3].x, newCurve.cPoints[3].y = x,y
			newCurve.cPoints[3].hasBeenMoved = oldCurve.cPoints[3].hasBeenMoved
			newCurve:setModified()
		end
		oldCorner = oldCorner.next
		if not oldCorner then break end
	end
	
	return new
end

function Shape:__tostring()
	for i = 1, #self.curves do
		self.curves[i].cPoints[1].hasBeenSaved = false
		self.curves[i].cPoints[4].hasBeenSaved = false
	end
	local str = "\tShape: " .. self.shapeID .. "\n"
	str = str .. "\t\tmaterial: " .. self.materialName .. "\n"
	str = str .. "\t\tangX: " .. self.angle.x .. "\n"
	str = str .. "\t\tangY: " .. self.angle.y .. "\n"
	str = str .. "\t\tclosed: " .. (self.closed and tostring(self.closed) or "false") .. "\n"
	if self.boundingBox then
		str = str .. "\t\tx: " .. self.boundingBox.minX .. "\n"
		str = str .. "\t\ty: " .. self.boundingBox.minY .. "\n"
	end

	local corner = self.corners[1]
	if corner then
		repeat
			c = corner.bezierNext
			if not c then break end
			if not c.cPoints[1].hasBeenSaved then
				str = str .. "\t\t" .. tostring(c.cPoints[1]) .. "\n"
				c.cPoints[1].hasBeenSaved = true
			end
			str = str .. "\t\t" .. tostring(c.cPoints[2]) .. "\n"
			str = str .. "\t\t" .. tostring(c.cPoints[3]) .. "\n"
			if not c.cPoints[4].hasBeenSaved then
				str = str .. "\t\t" .. tostring(c.cPoints[4]) .. "\n"
				c.cPoints[4].hasBeenSaved = true
			end
			corner = corner.next
		until corner == self.corners[1]
	end
	
	str = str .. "\tendShape\n\n"
	
	return str
end

function Shape:drawPlain( map )
	if map == "diffuse" then
		if self.image.diffuseMap then
			love.graphics.draw( self.image.diffuseMap,
							self.boundingBox.minX - IMG_PADDING,
							self.boundingBox.minY - IMG_PADDING )
		else
			for k,c in pairs( self.curves ) do
				c:draw( false, false )
			end
		end
	elseif map == "normal" then
		if self.image.normalMap then
			love.graphics.draw( self.image.normalMap,
							self.boundingBox.minX - IMG_PADDING,
							self.boundingBox.minY - IMG_PADDING )
		end
	elseif map == "specular" then
		if self.image.specularMap then
			love.graphics.draw( self.image.specularMap,
							self.boundingBox.minX - IMG_PADDING,
							self.boundingBox.minY - IMG_PADDING )
		end
	end
end
