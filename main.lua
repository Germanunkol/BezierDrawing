require("Scripts/shapeControl")

local gridSize = 20
local shapeControl


function love.load()
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
	y = displayKey(10, y, "Click", "Add point")
	y = displayKey(10, y, "Click + Drag", "Move point")
	
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
	if key == "lctrl" then
		shapeControl:setSnapToGrid( true )
	else
		if key == "lshift" then
			shapeControl:setSnapToCPoints( true )
		end
	end
end

function love.keyreleased( key, unicode )
	if key == "lctrl" then
		shapeControl:setSnapToGrid( false )
	else
		if key == "lshift" then
			shapeControl:setSnapToCPoints( false )
		end
	end
end
