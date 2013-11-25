Object = class("Object")

local img = {}

function loadAllObjectImages()
	img = {}
	local path = "Images/Objects/"
	img["exhaust_main_blue"] = love.graphics.newImage( path .. "exhaust_main_blue.png" )
	img["exhaust_flare"] = love.graphics.newImage( path .. "exhaust_flare.png" )
	print("Loaded " .. #img .. " object images.")
end

local objects = 0
local function newObjectID()
	objects = objects+1
	return objects -1
end


function Object:initialize( objType, materialName )
	self.selected = false
	self.boundingBox = {}
	self.images = {}
	self.imagesB = {}	-- below shapes
	self.imagesA = {}	-- above shapes
	self.shapes = {}
	self.objType = objType
	self.sx, self.sy = 1, 1
	self:loadFromFile( objType )
	self.objectID = newObjectID()
	self.materialName = materialName or "chrome"
	self:calcBoundingBox()
end

function Object:loadFromFile( objType )
	local ok, content = pcall( love.filesystem.read, "Objects/" .. objType .. ".sav" )
	if not ok then print("\tDidn't find specification for object: " .. objType .. "!") return end

	self.images = {}
	self.imagesB = {}	-- below shapes
	self.imagesA = {}	-- above shapes
	self.shapes = {}

	local shapeNum = 1
	for str in content:gmatch("(Shape:.-endShape)") do
		self.shapes[#self.shapes + 1] = shapeFromString( str )
		self.shapes[#self.shapes]:setLayer( shapeNum )
		shapeNum = shapeNum + 1
	end
	for str in content:gmatch("(Image:.-endImage)") do
		local img = self:imageFromString( str )
		if img.drawBelow then	-- draw below the shapes?
			self.imagesB[#self.imagesB + 1] = img
		else
			self.imagesA[#self.imagesA + 1] = img
		end
		self.images[#self.images + 1] = img
	end
end

function Object:imageFromString( str )
	local fileName = str:match("file: (.-)\r?\n")
	local xPos = str:match("x: (.-)\r?\n")
	local yPos = str:match("y: (.-)\r?\n")
	local ang = str:match("ang: (.-)\r?\n")
	local below = str:match("below: (.-)\r?\n")
	xPos, yPos = tonumber(xPos), tonumber(yPos)
	ang = tonumber(ang)
	image = {
		img = img[fileName],
		x = xPos or 0,
		y = yPos or 0,
		ang = ang or 0,
		drawBelow = below == "true" and true,
	}
	return image
end

function Object:setMaterial( mat )
	self.materialName = mat
	for k = 1, #self.shapes do
		self.shapes[k]:setMaterial( mat )
	end
end

function Object:getMaterial()
	return self.materialName
end

function Object:setModified()
	self.modified = true
end

function Object:isInsideBox( x1, y1, x2, y2 )
	if x2 < x1 then x2,x1 = x1,x2 end
	if y2 < y1 then y2,y1 = y1,y2 end
	if x1 < self.boundingBox.minX and y1 < self.boundingBox.minY and
		x2 > self.boundingBox.maxX and y2 > self.boundingBox.maxY then
		return true
	else
		return false
	end
end

function Object:checkHit( x, y, ignore )
	local hit = self:pointIsInsideBoundings( x, y )
	minDist = 100
	return hit, minDist
end

function Object:drag( x, y )
	self.offsetX, self.offsetY = x - self.startDragX, y - self.startDragY
end

function Object:startDragging( x, y )
	self.dragged = true
	self.startDragX, self.startDragY = x, y
end

function Object:stopDragging( x, y )
	if self.offsetX and self.offsetY then
		for k = 1, #self.images do
			self.images[k].x = self.images[k].x + self.offsetX
			self.images[k].y = self.images[k].y + self.offsetY
		end
		for i = 1, #self.shapes do
			for k = 1, #self.shapes[i].curves do
				for j = 1, #self.shapes[i].curves[k].cPoints do
					self.shapes[i].curves[k].cPoints[j]:addOffset( self.offsetX, self.offsetY )
				end
			end
			for k = 1, #self.shapes[i].curves do
				for j = 1, #self.shapes[i].curves[k].cPoints do
					self.shapes[i].curves[k].cPoints[j]:removeOffsetLock()
				end
			end
			self.shapes[i].modified = true
		end
	end
	self.dragged = false
	self.modified = true
end

function Object:moveTo( x, y )
	self.offsetX, self.offsetY = x, y
	self:stopDragging()
end

function Object:drop()	-- stop dragging and reset
	self.dragged = false
end

function Object:draw( editMode )
	
	if self.dragged then
		love.graphics.push()
		love.graphics.translate( self.offsetX, self.offsetY )
	end
	
	love.graphics.setColor(255,255,255,255)
	for k = 1, #self.imagesB do
		love.graphics.draw( self.imagesB[k].img, self.imagesB[k].x, self.imagesB[k].y,
							0, self.sx, self.sy )
	end
	for k = 1, #self.shapes do
		self.shapes[k]:draw( false )
	end
	love.graphics.setColor(255,255,255,255)
	for k = 1, #self.imagesA do
		love.graphics.draw( self.imagesA[k].img, self.imagesA[k].x, self.imagesA[k].y,
							0, self.sx, self.sy )
	end
	if self.dragged then
		love.graphics.pop()
	end
end

function Object:drawOutline()
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

		self:drawLayer()
	end
	
	if self.dragged then
		love.graphics.pop()
	end
end

function Object:drawLayer()
	if self.boundingBox then
		if self.layer then
			love.graphics.print( self.layer, self.boundingBox.maxX + 24,
					self.boundingBox.minY + 2)
		end
	end
end

function Object:setLayer( layer )
	self.layer = layer
end

function Object:getLayer()
	return self.layer
end

function Object:setEditing( bool )

end

function Object:setSelected( bool )
	self.selected = bool
end

function Object:getSelected()
	return self.selected or false
end

function Object:calcBoundingBox()
	self.boundingBox.minX = math.huge
	self.boundingBox.minY = math.huge
	self.boundingBox.maxX = -math.huge
	self.boundingBox.maxY = -math.huge
	local boundings
	for k = 1, #self.shapes do
		boundings = self.shapes[k]:getBoundingBox()
		self.boundingBox.minX = math.min( boundings.minX, self.boundingBox.minX )
		self.boundingBox.minY = math.min( boundings.minY, self.boundingBox.minY )
		self.boundingBox.maxX = math.max( boundings.maxX, self.boundingBox.maxX )
		self.boundingBox.maxY = math.max( boundings.maxY, self.boundingBox.maxY )
	end
	for k,im in pairs(self.images) do
		-- careful! If the image is mirrored, take that into account:
		if self.sx > 0 then		-- not mirrored
			self.boundingBox.minX = math.min( im.x, self.boundingBox.minX )
			self.boundingBox.maxX = math.max( im.img:getWidth() + im.x, self.boundingBox.maxX )
		else					-- mirrored
			self.boundingBox.minX = math.min( im.x - im.img:getWidth(), self.boundingBox.minX )
			self.boundingBox.maxX = math.max( im.x, self.boundingBox.maxX )
		end
		if self.sy > 0 then		-- same deal for y direction
			self.boundingBox.minY = math.min( im.y, self.boundingBox.minY )
			self.boundingBox.maxY = math.max( im.img:getHeight() + im.y, self.boundingBox.maxY )
		else
			self.boundingBox.minY = math.min( im.y - im.img:getHeight(), self.boundingBox.minY )
			self.boundingBox.maxY = math.max( im.y, self.boundingBox.maxY )
		end
	end
end

function Object:getBoundingBox()
	self:calcBoundingBox()
	return self.boundingBox
end

function Object:update( dt )
	for k = 1, #self.shapes do
		self.shapes[k]:update( dt )
	end
	if self.modified == true then
		self:calcBoundingBox()
		self.modified = false
	end
end

function Object:pointIsInside( x, y )
	return self:pointInsideBoundings( x, y )
end

-- less precice, but more reliable check:
function Object:pointInsideBoundings( x, y )
	
	if x >= self.boundingBox.minX and x <= self.boundingBox.maxX
		and y >= self.boundingBox.minY and y <= self.boundingBox.maxY then
		return true
	end
	
	return false
end

function Object:flip( dir, axis )

	self:calcBoundingBox()
	print("axis:", axis)	
	local center
	if dir == "x" then
		center = axis or (self.boundingBox.maxX - self.boundingBox.minX)/2 + self.boundingBox.minX
		self.sx = -self.sx
		for k = 1, #self.images do
			local dist = self.images[k].x - center
			self.images[k].x = self.images[k].x - 2*dist
		end
	else
		center = axis or (self.boundingBox.maxY - self.boundingBox.minY)/2 + self.boundingBox.minY
		self.sy = -self.sy
		for k = 1, #self.images do
			local dist = self.images[k].y - center
			self.images[k].y = self.images[k].y - 2*dist
		end
	end
	for k = 1, #self.shapes do
		self.shapes[k]:flip( dir, center )
	end
	self.modified = true
end

function Object:duplicate()
	new = Object:new( self.objType, self.materialName )
	new:setEditing( false )
	new:setSelected( false )
	new:moveTo( self.boundingBox.minX, self.boundingBox.minY )
	if new.sx ~= self.sx then
		new:flip( "x", (self.boundingBox.maxX + self.boundingBox.minX)/2)
	end
	if new.sy ~= self.sy then
		new:flip( "y", (self.boundingBox.maxY + self.boundingBox.minY)/2)
	end
	return new
end

function Object:__tostring()
	local str = "\tObject: " .. self.objectID .. "\n"
	str = str .. "\t\ttype: " .. self.objType .. "\n"
	str = str .. "\t\tmaterial: " .. self.materialName .. "\n"
	if self.boundingBox then
		str = str .. "\t\tx: " .. self.boundingBox.minX .. "\n"
		str = str .. "\t\ty: " .. self.boundingBox.minY .. "\n"
		str = str .. "\t\tmaxX: " .. self.boundingBox.maxX .. "\n"
		str = str .. "\t\tmaxY: " .. self.boundingBox.maxY .. "\n"
	end
	str = str .. "\t\tsx: " .. self.sx .. "\n"
	str = str .. "\t\tsy: " .. self.sy .. "\n"

	str = str .. "\tendObject\n\n"
	
	return str
end

loadAllObjectImages()
