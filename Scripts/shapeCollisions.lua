require("Scripts/misc")

function distance( P1, P2 )
	return math.sqrt((P1.x-P2.x)^2 + (P1.y-P2.y)^2)
end

function distPointToLine( line, x, y )
	if line[1].x == line[2].x and line[1].y == line[2].y then
		print("Error: Not a line!")
		return false
	end
	
	local d = distance( line[1], line[2] )
	
	local t = ((x - line[1].x)*(line[2].x - line[1].x) + (y - line[1].y)*(line[2].y - line[1].y))/(d^2)
	
	local projection = {}
	projection.x = line[1].x + t*(line[2].x-line[1].x)
	projection.y = line[1].y + t*(line[2].y-line[1].y)
	
	if t >= 0 and t <= 1 then	-- within line segment?
		return distance( projection, {x=x, y=y} )
	else
		return false
	end
end
