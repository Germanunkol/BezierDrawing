require("Scripts/shapeControl")
require("Scripts/camera")
ui = require("Scripts/ui")

local gridSize = 20		-- 20 pixels is one meter
local canvasWidth = 50
local canvasHeight = 50
local shapeControl

local time
local timeStr = ""

function printDT( time, name )
	timeStr = timeStr .. "\n" .. round(time*1000, 2) .. " (" .. name ..")"
end

function round( num, prec )
	prec = prec or 0
	
	return math.floor(num*10^prec)/(10^prec)
end

function love.load()

	assert(love.graphics.isSupported("canvas"), "Your graphics card does not support canvases, sorry!")
	assert(love.graphics.isSupported("pixeleffect"), "Your graphics card does not support shaders, sorry!")

	love.graphics.setDefaultImageFilter("nearest", "nearest")

	local imgName = arg[2]

	love.filesystem.setIdentity("BezierDrawing")

	shapeControl = ShapeControl:new( gridSize, canvasWidth, canvasHeight, imgName )
	
	cam = Camera:new( .25, 2, gridSize*canvasWidth/2, gridSize*canvasHeight/2 )
	
end

function displayHeader( x, y, headerText )
	if x > 0 then
		y = y + 10
		love.graphics.setColor(100,160,255, 255)
		love.graphics.print(headerText, x, y)
		return y + love.graphics.getFont():getHeight()
	else
		x = love.graphics.getWidth() - love.graphics.getFont():getWidth(headerText) + x -5
		love.graphics.setColor(100,160,255, 255)
		love.graphics.print(headerText, x, y)
		return y + love.graphics.getFont():getHeight()
	end
end
function displayKey( x, y, redText, whiteText )
	if x > 0 then
		x = x + 5
		love.graphics.setColor(255,120,50, 255)
		love.graphics.print(redText, x, y)
		love.graphics.setColor(255,255,255, 255)
		love.graphics.print(whiteText, x + 5 + love.graphics.getFont():getWidth(redText), y)
		return y + love.graphics.getFont():getHeight()
	else
		x = love.graphics.getWidth() - love.graphics.getFont():getWidth(redText .. whiteText) + x -5
		love.graphics.setColor(255,120,50, 255)
		love.graphics.print(redText, x, y)
		love.graphics.setColor(255,255,255, 255)
		love.graphics.print(whiteText, x + 5 + love.graphics.getFont():getWidth(redText), y)
		return y + love.graphics.getFont():getHeight()
	end
end
function displayInfo( x, y, whiteText )
	x = x + 5
	love.graphics.setColor(255,255,255, 255)
	love.graphics.print(whiteText, x, y)
	return y + love.graphics.getFont():getHeight()
end

function drawGrid( res )
	cam:set()
	
	love.graphics.setLineWidth( math.max(1/cam:getZoom(),1) )
	
	love.graphics.setColor(255,255,255,20)
	
	-- convert screen size into world coordinates:
	local x1,y1 = cam:worldPos( 0, 0 )
	local x2,y2 = cam:worldPos( love.graphics.getWidth(), love.graphics.getHeight() )
	local startX = math.max( x1, 0 )
	local startY = math.max( y1, 0 )
	local endX = math.min( x2, canvasWidth*gridSize )
	local endY = math.min( y2, canvasHeight*gridSize )
	
	startX = startX - startX % (gridSize*res)
	startY = startY - startY % (gridSize*res)
	
	for k = startX, endX, res*gridSize do
		love.graphics.line( k, startY, k, endY )
	end
	for k = startY, endY, res*gridSize do
		love.graphics.line( startX, k, endX, k )
	end
	
	cam:reset()
end


function love.draw()
	time = love.timer.getMicroTime()
	if cam:getZoom() == 2 then
		drawGrid( 0.5 )
		drawGrid( 1 )
	else
		drawGrid( 5 )
		drawGrid( 1 )
	end
	
	printDT(love.timer.getMicroTime() - time, "grid")
	time = love.timer.getMicroTime()
	
	cam:set()
	shapeControl:draw()
	printDT(love.timer.getMicroTime() - time, "shapes")
	time = love.timer.getMicroTime()
	cam:reset()
	shapeControl:drawUI()
	printDT(love.timer.getMicroTime() - time, "shapecontrol UI")
	time = love.timer.getMicroTime()
	
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
			y = displayKey(10, y, "Click + Drag", "Box Select")
		end
		if #shapeControl:getSelectedShape() > 0 then
			y = displayHeader(10, y, "Selected")
			y = displayKey(10, y, "Select + Drag", "Move")
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
	
	printDT(love.timer.getMicroTime() - time, "UI")
	time = love.timer.getMicroTime()
	
	
	love.graphics.print(timeStr, 15, love.graphics.getHeight() - 130)
	
	-- local xPos, yPos = love.mouse.getPosition()
	-- love.graphics.print( angBetweenPoints({x=xPos, y=yPos}, {x=love.graphics.getWidth()/2, y=love.graphics.getHeight()/2}, {x=love.graphics.getWidth()/2, y = 0}) /math.pi*180, 10, y + 20 )
	
	ui:draw()
end

function love.mousepressed( x,y,button )
	if button == "m" then
		cam:setDrag( true, love.mouse.getPosition() )
	end
	if button == "wu" then
		cam:zoomIn()
		shapeControl:setSnapSize()
	end
	if button == "wd" then
		cam:zoomOut()
		shapeControl:setSnapSize()
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
	ui:update(dt)

	timeStr = ""
	time = love.timer.getMicroTime()
	local x, y = cam:worldPos(love.mouse.getPosition())
	shapeControl:update( x, y, dt )
	if love.mouse.isDown("m") then
		cam:drag( love.mouse.getPosition() )
	end
	printDT(love.timer.getMicroTime() - time, "update")
	time = love.timer.getMicroTime()
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

