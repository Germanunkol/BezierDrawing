require("Scripts/misc")



function triangulate( pointList )

	local triangles = {}
	local current = pointList[1]
	local inside
	local c = 0
	while current and current.prev ~= current and current.next ~= current and current.next ~= current.prev and c < 10000 do
		c = c + 1
		inside = false
		--print("p:", #pointList)
		if angBetweenPoints(current.prev, current, current.next) < 180 then
			for k, p in pairs( pointList ) do
				if p ~= current and p ~= current.prev and p ~= current.next then
					if pointInTriangle(p, current, current.next, current.prev) then
						inside = true
						break
					end
				end
			end
		
			if not inside then
				triangles[#triangles+1] = {
					current.x, current.y,
					current.next.x, current.next.y,
					current.prev.x, current.prev.y
				}
				current.next.prev = current.prev
				current.prev.next = current.next
			end
		end
		current = current.next
	end
	if c == 10000 then
		print("took too long!")
	end
	print(#triangles, c)
	return triangles
end


function triangulateSimple( pointList )

	local triangles = {}
	for k = 2, #pointList-1 do
		triangles[#triangles+1] = {
			pointList[1].x, pointList[1].y,
			pointList[k].x, pointList[k].y,
			pointList[k+1].x, pointList[k+1].y
		}
	end
	print("simple:", #triangles, c)
	return triangles
end
