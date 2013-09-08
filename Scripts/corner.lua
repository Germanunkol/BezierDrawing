------------------------------------------------------------------------
-- Shape corner holds references to up to two connected bezier curves.
-- The two Bezier curves end in this point.
require("Scripts/point")

Corner = class("Corner", Point)

function Corner:initialize( x, y )
	Point.initialize( self, x, y ) -- Parent's function
end

function Corner:move( x, y )
	if self.bezierNext then
		self.bezierNext:update() --setEndPoint( x,  y )
	end
	if self.bezierPrev then
		self.bezierPrev:update() --setStartPoint( x, y )
	end
	Point.move( self, x, y ) -- Parent's function
end

function Corner:select()
	self.selected = true
end

function Corner:deselect()
	self.selected = false
end

