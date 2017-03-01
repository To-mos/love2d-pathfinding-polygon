local vector = class( 'vector' )

function vector:initialize( x, y )
	self.x = x;	self.y = y
end

function vector:toString()
	return "<" .. self.x .. ", " .. self.y .. ">"
end

function vector:add( v1 )
    return vector:new( self.x + v1.x, self.y + v1.y )
end

function vector:diff( v1 )
    return vector:new( v1.x - self.x, v1.y - self.y )
end

function vector:dist( v1 )
	return vector:new( v1.x - self.x, v1.y - self.y ):length()
end

function vector:length()
	return math.sqrt( self.x * self.x + self.y * self.y )
end

function vector:normalized()
  local len = self:length()
  self.x = self.x / len
  self.y = self.y / len
  return self
end

return vector
