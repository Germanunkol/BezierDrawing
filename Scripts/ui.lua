
local ui = {}
local WARN_COLOR = {255,32,0}
local WARN_TIME = 7
local PADDING = 20
local warnings = {}

function ui:draw()
	
	if warnings[1] then
		love.graphics.setColor( WARN_COLOR )
		local x = (love.graphics.getWidth() - love.graphics.getFont():getWidth(warnings[1].msg))/2
		local y = love.graphics.getHeight() - PADDING
		
		love.graphics.print( warnings[1].msg, x, y )
	end

end

function ui:addWarning( msg )
	table.insert( warnings, 1, {msg = msg, time = WARN_TIME} )
end

function ui:update( dt )
	if warnings[1] then
		warnings[1].time = warnings[1].time - dt
		if warnings[1].time <= 0 then
			table.remove( warnings, 1 )
			if warnings[1] then
				warnings[1].time = WARN_TIME
			end
		end
	end
end

return ui
