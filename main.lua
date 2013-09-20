require("Scripts/shapeControl")
require("Scripts/camera")


local gridSize = 20		-- 20 pixels is one meter
local canvasWidth = 50
local canvasHeight = 50
local shapeControl

pointsSave = {}

function love.load()

	love.filesystem.setIdentity("BezierDrawing")

	shapeControl = ShapeControl:new(gridSize, canvasWidth, canvasHeight )
	
	cam = Camera:new( .25, 2, gridSize*canvasWidth/2, gridSize*canvasHeight/2 )
	
end

function displayKey( x, y, redText, whiteText )
	love.graphics.setColor(255,120,50, 255)
	love.graphics.print(redText, 10, y)
	love.graphics.setColor(255,255,255, 255)
	love.graphics.print(whiteText, 15 + love.graphics.getFont():getWidth(redText), y)
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
	
	local y = 10
	y = displayKey(10, y, "", "FPS: " .. love.timer.getFPS())
	--y = displayKey(10, y, "Esc", "Select none")
	y = displayKey(10, y, "Alt + Click", "Add point")
	y = displayKey(10, y, "Click + Drag", "Move point")
	y = displayKey(10, y, "Ctrl", "Snap to grid")
	y = displayKey(10, y, "Shift", "Snap to point")
	y = displayKey(10, y, "Right Click", "Remove point")
	
	cam:set()
	shapeControl:draw()
	for k = 1, #pointsSave do
		love.graphics.line( 0, 0, pointsSave[k].x, pointsSave[k].y )
	end
	cam:reset()
	
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
		shapeControl:click( x, y, button )
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

function love.keyreleased( key, unicode )
	shapeControl:keyreleased( key, unicode )
end
