function distance( P1, P2 )
	return math.sqrt((P1.x-P2.x)^2 + (P1.y-P2.y)^2)
end

function removeFromTbl( tbl, elem )
	for k = 1, #tbl do
		if tbl[k] == elem then
			for i = k,#tbl-1 do
				tbl[i] = tbl[i+1]
			end
			tbl[#tbl] = nil
			return
		end
	end
end

-- prints tables recursively with nice indentation.
function tablePrint( tbl, level )
	level = level or 1
	if level > 5 then return end	-- beware of loops!
	
	local indentation = string.rep("\t", level)
	for k, v in pairs( tbl ) do 
		if type(v) == "table" then
			print (indentation, k .. " = {")
			tablePrint( v, level + 1 )
			print( indentation, "}")
		else
			print( indentation, k," =", v)
		end
	end
end
