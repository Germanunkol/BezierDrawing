require("Scripts/shapeControl")

local gridSize = 20
local shapeControl

function love.load()

	love.filesystem.setIdentity("BezierDrawing")

	shapeControl = ShapeControl:new(gridSize)
	
end

function displayKey( x, y, redText, whiteText )
	love.graphics.setColor(255,120,50, 255)
	love.graphics.print(redText, 10, y)
	love.graphics.setColor(255,255,255, 255)
	love.graphics.print(whiteText, 15 + love.graphics.getFont():getWidth(redText), y)
	return y + love.graphics.getFont():getHeight()
end

function love.draw()

	love.graphics.setLineWidth( 1 )
	love.graphics.setColor(255,255,255,20)
	for k = 1, love.graphics.getWidth()/gridSize do
		love.graphics.line(k*gridSize, 0, k*gridSize, love.graphics.getHeight())
	end
	for k = 1, love.graphics.getHeight()/gridSize do
		love.graphics.line(0, k*gridSize, love.graphics.getWidth(), k*gridSize)
	end

	local y = 10
	y = displayKey(10, y, "", "FPS: " .. love.timer.getFPS())
	--y = displayKey(10, y, "Esc", "Select none")
	y = displayKey(10, y, "Alt + Click", "Add point")
	y = displayKey(10, y, "Click + Drag", "Move point")
	y = displayKey(10, y, "Ctrl", "Snap to grid")
	y = displayKey(10, y, "Shift", "Snap to point")
	y = displayKey(10, y, "Right Click", "Remove point")
	
	shapeControl:draw()
end

function love.mousepressed( x,y,button )
	shapeControl:click( x, y, button )
end

function love.mousereleased( x,y,button )
	shapeControl:release( x, y, button )
end

function love.update( dt )
	shapeControl:update()
end

function love.keypressed( key, unicode )
	shapeControl:keypressed( key, unicode )
	
	if key == "f5" then
		love.graphics.newScreenshot():encode("Screen" .. os.time() ..".png")
		print("Saved screenshot.")
	end
	
end

function love.keyreleased( key, unicode )
	shapeControl:keyreleased( key, unicode )
end
