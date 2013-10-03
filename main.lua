require("Scripts/shapeControl")
require("Scripts/camera")

local gridSize = 20		-- 20 pixels is one meter
local canvasWidth = 50
local canvasHeight = 50
local shapeControl

function love.load()

	assert(love.graphics.isSupported("canvas"), "Your graphics card does not support canvases, sorry!")
	assert(love.graphics.isSupported("pixeleffect"), "Your graphics card does not support shaders, sorry!")

	local imgName = arg[2]

	love.filesystem.setIdentity("BezierDrawing")

	shapeControl = ShapeControl:new( gridSize, canvasWidth, canvasHeight, imgName )
	
	cam = Camera:new( .25, 2, gridSize*canvasWidth/2, gridSize*canvasHeight/2 )
	
end

function displayHeader( x, y, headerText )
	y = y + 10
	love.graphics.setColor(100,160,255, 255)
	love.graphics.print(headerText, x, y)
	return y + love.graphics.getFont():getHeight()
end
function displayKey( x, y, redText, whiteText )
	x = x + 5
	love.graphics.setColor(255,120,50, 255)
	love.graphics.print(redText, x, y)
	love.graphics.setColor(255,255,255, 255)
	love.graphics.print(whiteText, x + 5 + love.graphics.getFont():getWidth(redText), y)
	return y + love.graphics.getFont():getHeight()
end
function displayInfo( x, y, whiteText )
	x = x + 5
	love.graphics.setColor(255,255,255, 255)
	love.graphics.print(whiteText, x, y)
	return y + love.graphics.getFont():getHeight()
end

function drawGrid()
	cam:set()

	love.graphics.setLineWidth( 2*math.max(1/cam:getZoom(),1) )
	love.graphics.setColor(255,255,255,20)
	for k = 0, canvasWidth,5 do
		love.graphics.line(k*gridSize, 0, k*gridSize, canvasHeight*gridSize)
	end
	for k = 0, canvasHeight,5 do
		love.graphics.line(0, k*gridSize, canvasWidth*gridSize, k*gridSize)
	end

	cam:reset()
end
function drawGrid2()
	cam:set()

	love.graphics.setLineWidth( math.max(1/cam:getZoom(),1) )
	love.graphics.setColor(255,255,255,20)
	for k = 0, canvasWidth do
		love.graphics.line(k*gridSize, 0, k*gridSize, canvasHeight*gridSize)
	end
	for k = 0, canvasHeight do
		love.graphics.line(0, k*gridSize, canvasWidth*gridSize, k*gridSize)
	end

	cam:reset()
end

function love.draw()

	drawGrid()
	drawGrid2()
	
	cam:set()
	shapeControl:draw()
	cam:reset()
	shapeControl:drawUI()
	
	local y = 10
	y = displayHeader(10, y, "Info")
	y = displayInfo(10, y, "FPS: " .. love.timer.getFPS())
	y = displayInfo(10, y, "Zoom: " .. cam:getZoom())
	
	y = displayHeader(10, y, "Camera")
	y = displayKey(10, y, "Middle Mouse", "Move")
	y = displayKey(10, y, "Mouse Wheel", "Zoom")
	
	
	if not shapeControl:getEditedShape() then
		y = displayHeader(10, y, "Shape Control")
		y = displayKey(10, y, "Ctrl + Click", "New")
		if shapeControl:getNumShapes() > 0 then
			y = displayKey(10, y, "Click", "Select")
			y = displayKey(10, y, "Double Click", "Edit")
			y = displayKey(10, y, "Click + Drag", "Move")
		end
		if shapeControl:getSelectedShape() then
			y = displayHeader(10, y, "Selected")
			y = displayKey(10, y, "Delete", "Delete Shape")
			y = displayKey(10, y, "+", "Raise Shape")
			y = displayKey(10, y, "-", "Lower Shape")
			y = displayKey(10, y, "M", "Change Material")
			
			y = displayKey(10, y, "X", "Mirror X")
			y = displayKey(10, y, "Y", "Mirror Y")
			y = displayKey(10, y, "D", "Duplicate")
		end
	end
	
	
	if shapeControl:getEditedShape() then
		y = displayHeader(10, y, "Edit Mode")
		y = displayKey(10, y, "Ctrl + Click", "Add corner")
		y = displayKey(10, y, "Right Click", "Remove corner / Reset Point")
		y = displayKey(10, y, "Click + Drag", "Move")
		y = displayKey(10, y, "Esc or Click outside", "Stop editing")
		y = displayKey(10, y, "X", "Mirror X")
		y = displayKey(10, y, "Y", "Mirror Y")
	end
	y = love.graphics.getHeight() -40
	if shapeControl:getSnapToGrid() then
		y = displayKey(10, y, "G", "Snap to grid (is ON)")
	else
		y = displayKey(10, y, "G", "Snap to grid (is OFF)")
	end
	y = displayKey(10, y, "F5", "Screenshot")
	
	
	
	-- local xPos, yPos = love.mouse.getPosition()
	-- love.graphics.print( angBetweenPoints({x=xPos, y=yPos}, {x=love.graphics.getWidth()/2, y=love.graphics.getHeight()/2}, {x=love.graphics.getWidth()/2, y = 0}) /math.pi*180, 10, y + 20 )
	
end

function love.mousepressed( x,y,button )
	if button == "m" then
		cam:setDrag( true, love.mouse.getPosition() )
	end
	if button == "wu" then
		cam:zoomIn()
	end
	if button == "wd" then
		cam:zoomOut()
	end
	if button == "l" or button == "r" then
		x, y = cam:worldPos(x, y)
		shapeControl:click( x, y, button, cam:getZoom() )
	end
end

function love.mousereleased( x,y,button )
	if button == "m" then
		cam:setDrag( false )
	else
		x, y = cam:worldPos(x, y)
		shapeControl:release( x, y, button )
	end
end

function love.update( dt )
	local x, y = cam:worldPos(love.mouse.getPosition())
	shapeControl:update( x, y, dt )
	if love.mouse.isDown("m") then
		cam:drag( love.mouse.getPosition() )
	end
end

function love.keypressed( key, unicode )
	shapeControl:keypressed( key, unicode )
	
	if key == "f5" then
		screenshot()
	end
end

function love.quit()
	if filename then
		shapeControl:save()
	end
end

