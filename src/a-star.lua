--offset for lua starting at 1 not 0
local luaIndexFix = 1

----------------------------------------------------------------
-- graph node functions
----------------------------------------------------------------

local GraphEdge = class( 'GraphEdge' )

function GraphEdge:initialize( _from, _to, _cost )
    self.from = _from
    self.to   = _to
    self.cost = _cost or 1.0
end

function GraphEdge:clone()
    return GraphEdge(self.from, self.to, self.cost)
end


local GraphNode = class( 'GraphNode' )

function GraphNode:initialize( _pos )
    self.pos = _pos
end

function GraphNode:clone()
    return GraphNode( vector( self.pos.x, self.pos.y ) )
end


local Graph = class( 'Graph' )

function Graph:initialize()
    self.nodes = {}
    self.edges = {}
end

function Graph:clone()
    local g = Graph()

    for n, _ in ipairs( self.nodes ) do
        g.nodes[n] = self.nodes[n]:clone()
    end

    for i, _ in ipairs( self.edges ) do
        g.edges[i] = {}
        for _, e in pairs( self.edges[i] ) do
            table.insert( g.edges[i], e:clone() )
        end
    end

    return g
end

function Graph:addNode(node)
    table.insert( self.nodes, node )
    table.insert( self.edges, {} )

    return 0
end

function Graph:getEdge(from,to)
    local from_Edges = self.edges[from]
    for a, _ in ipairs( from_Edges ) do
        if from_Edges[a].to == to then
            return from_Edges[a]
        end
    end

    return nil
end

function Graph:addEdge( edge )
    if self:getEdge(edge.from, edge.to) == nil then
        table.insert( self.edges[edge.from], edge )
    end
    if self:getEdge(edge.to, edge.from) == nil then

        table.insert( self.edges[edge.to], 
        	GraphEdge(
        		edge.to,
        		edge.from,
        		edge.cost
        	)
        )
    end
end

----------------------------------------------------------------
-- polygon map functions
----------------------------------------------------------------

PolygonMap = class( 'PolygonMap' )

function PolygonMap:initialize()
    self.vertices_concave = {}
    self.polygons         = {}

    self.walkgraph = {}
    self.targetx   = 0.0
    self.targety   = 0.0

    self.startNodeIndex = 1
    self.endNodeIndex   = 1

    self.calculatedpath = {}
end

function PolygonMap:createGraph()
	self.mainwalkgraph = Graph()
	local first = true
	self.vertices_concave = {}
    for _, polygon in pairs( self.polygons ) do
		if polygon ~= nil and
		   polygon.vertices ~= nil and
           #polygon.vertices > 2 then
            for i, _ in ipairs( polygon.vertices ) do
				--check using boolean 'first', because the first polygon is the walkable area
				--and all other polygons are blocking polygons inside the walkabl area and for
				--those polygons we need the non-concave vertices
				if self:isVertexConcave(polygon.vertices, i) == first then
                    table.insert( self.vertices_concave, polygon.vertices[i] )
					self.mainwalkgraph:addNode( GraphNode( vector( polygon.vertices[i].x, polygon.vertices[i].y ) ) )
				end
			end
		end
		first = false
	end
	--find concave nodes that can see one another
	for c1_index, _ in ipairs( self.vertices_concave ) do
		for c2_index, _ in ipairs( self.vertices_concave ) do
			local c1 = self.vertices_concave[c1_index]
			local c2 = self.vertices_concave[c2_index]

			if self:inLineOfSight( c1, c2 ) then
				self.mainwalkgraph:addEdge( GraphEdge( c1_index, c2_index, c1:dist(c2) ) )
			end
		end
	end
end
	
	--ported from http:--www.david-gouveia.com/portfolio/pathfinding-on-a-2d-polygonal-map/
function PolygonMap:lineSegmentsCross(a, b, c, d)
	local denominator = ((b.x - a.x) * (d.y - c.y)) - ((b.y - a.y) * (d.x - c.x))

	if denominator == 0 then
		return false
	end

	local numerator1 = ((a.y - c.y) * (d.x - c.x)) - ((a.x - c.x) * (d.y - c.y))

	local numerator2 = ((a.y - c.y) * (b.x - a.x)) - ((a.x - c.x) * (b.y - a.y))

	if numerator1 == 0 or 
	   numerator2 == 0 then
		return false
	end

	local r = numerator1 / denominator
	local s = numerator2 / denominator

	return (r > 0 and r < 1) and (s > 0 and s < 1)
end

--ported from http:--www.david-gouveia.com/portfolio/pathfinding-on-a-2d-polygonal-map/
function PolygonMap:isVertexConcave(vertices, vertIndex)
    local curPos    = vertices[vertIndex]
	local nextPos   = vertices[(vertIndex % #vertices) + luaIndexFix]
    local prevIndex = vertIndex - 1
    --wrap around
    if vertIndex == 1 then
        prevIndex = #vertices - 1
    end

	local prevPos = vertices[ prevIndex ]

	local left  = vector(curPos.x - prevPos.x, curPos.y - prevPos.y)
	local right = vector(nextPos.x - curPos.x, nextPos.y - curPos.y)

	local cross = (left.x * right.y) - (left.y * right.x)

	return cross < 0
end

function PolygonMap:inLineOfSight( startPos, endPos )
	local polyTable = self.polygons
	-- Not in LOS if any of the ends is outside the polygon
	if not polyTable[1]:pointInside(startPos) or
	   not polyTable[1]:pointInside(endPos) then
		return false
	end

	local epsilon = 0.5
	-- dont waste edge on the same start and end location
	if startPos:diff( endPos ):length() < epsilon then
		return true
	end

	-- Not in LOS if any edge is intersected by the start-end line segment
	for _, polygon in pairs( polyTable ) do
		for i, _ in ipairs( polygon.vertices ) do
			local v1 = polygon.vertices[i]
			local v2 = polygon.vertices[ (i % #polygon.vertices) + luaIndexFix ]
			if self:lineSegmentsCross(startPos, endPos, v1, v2) then
				--In some cases a 'snapped' endpoint is just a little over the line due to rounding errors. So a 0.5 margin is used to tackle those cases.
				if polygon:distanceToSegment( startPos.x, startPos.y, v1.x, v1.y, v2.x, v2.y ) > 0.5 and
				   polygon:distanceToSegment( endPos.x, endPos.y, v1.x, v1.y, v2.x, v2.y ) > 0.5 then
					return false
				end
			end
		end
	end

	-- Finally the middle point in the segment determines if in LOS or not
	local v  = startPos:add( endPos )
	local v2 = vector( v.x * 0.5, v.y * 0.5 )
	--los checking for pure outline
	local inside = polyTable[1]:pointInside(v2)
	for i = 2, #polyTable, 1 do
		if polyTable[i]:pointInside(v2, false) then
			inside = false
		end
	end

	return inside
end

function PolygonMap:calculatePath( fromPos, toPos )
    --Clone the graph, so you can safely add new nodes without altering the original graph
    self.walkgraph = self.mainwalkgraph:clone()

    local mindistanceFrom = 100000
    local mindistanceTo = 100000
    --create new node on start position
    self.startNodeIndex = #self.walkgraph.nodes + luaIndexFix
    --clamp pos to edge walkable area
    if not self.polygons[1]:pointInside( fromPos ) then
        fromPos = self.polygons[1]:getClosestPointOnEdge( fromPos )
    end
    if not self.polygons[1]:pointInside( toPos ) then
        toPos = self.polygons[1]:getClosestPointOnEdge( toPos )
    end
    --prevent new pos from being inside of a blockade
    --Are there more polygons? Then check if endpoint is inside one of them and find closest point on edge
    if #self.polygons > 1 then
    	for i = 2, #self.polygons, 1 do
            if self.polygons[i]:pointInside( toPos ) then
                toPos = self.polygons[i]:getClosestPointOnEdge( toPos )
                break
            end
        end
    end
    
    self.targetx, self.targety = toPos.x, toPos.y

    --node graph from start to shapes
    local startNode = GraphNode( vector( fromPos.x, fromPos.y ) )
    local startNodeVector = vector( startNode.pos.x, startNode.pos.y )
    self.walkgraph:addNode( startNode )

    for c_index, _ in ipairs( self.vertices_concave ) do
        local c = self.vertices_concave[c_index]
        if self:inLineOfSight( startNodeVector, c ) then
            self.walkgraph:addEdge( GraphEdge( self.startNodeIndex, c_index, startNodeVector:dist( c ) ) )
        end
    end

    --create new node on end position
    self.endNodeIndex = #self.walkgraph.nodes + luaIndexFix
    --node graph from shape to end
    local endNode = GraphNode( vector( toPos.x, toPos.y ) )
    local endNodeVector = vector( endNode.pos.x, endNode.pos.y )
    self.walkgraph:addNode( endNode )

    for c_index, _ in ipairs( self.vertices_concave ) do
        local c = self.vertices_concave[c_index]
        if self:inLineOfSight( endNodeVector, c ) then
            self.walkgraph:addEdge( GraphEdge( c_index, self.endNodeIndex, endNodeVector:dist( c ) ) )
        end
    end

    --direct line of sight connection
    if self:inLineOfSight( startNodeVector, endNodeVector ) then
        self.walkgraph:addEdge( GraphEdge( self.startNodeIndex, self.endNodeIndex, startNodeVector:dist( endNodeVector ) ) )
    end
    
    --solve the path
    local astar = Astar( self.walkgraph, self.startNodeIndex, self.endNodeIndex )

    self.calculatedpath = astar:getPath()
    return self.calculatedpath
end

----------------------------------------------------------------
-- polygon functions
----------------------------------------------------------------

Polygon = class( 'Polygon' )

function Polygon:initialize()
	self.vertices = {}
end

function Polygon:dumpPoints()
	local dumpVerts = {}
	for i = 1, #self.vertices, 1 do
		local vec = self.vertices[i]
		if i % 2 == 1 then
			dumpVerts[ i ] = vec.x
		else
			dumpVerts[ i ] = vec.y
		end
	end

	return dumpVerts
end
	
function Polygon:addPoint( x, y )
	local v = vector( x, y )
	table.insert( self.vertices, v )
	return v
end
	
--ported from http://www.david-gouveia.com/portfolio/pathfinding-on-a-2d-polygonal-map/
function Polygon:pointInside( point, toleranceOnOutside )
	--defaults
	if toleranceOnOutside == nil then 
		toleranceOnOutside = true 
	end

	local epsilon = 0.5

	local inside = false
	-- Must have 3 or more edges
	if #self.vertices < 3 then 
		return inside 
	end

	local oldPoint  = self.vertices[#self.vertices]
	local oldSqDist = self:distSquared(oldPoint.x, oldPoint.y, point.x, point.y)

	for i, _ in ipairs( self.vertices ) do
		local newPoint = self.vertices[i]
		local newSqDist = self:distSquared(newPoint.x, newPoint.y, point.x, point.y)

		if oldSqDist + newSqDist + 2.0 * math.sqrt(oldSqDist * newSqDist) - self:distSquared(newPoint.x, newPoint.y, oldPoint.x, oldPoint.y) < epsilon then
			return toleranceOnOutside
		end

		local left
		local right
		if newPoint.x > oldPoint.x then
			left = oldPoint
			right = newPoint
		else
			left = newPoint
			right = oldPoint
		end

		if left.x < point.x and 
		   point.x <= right.x and 
		   (point.y - left.y) * (right.x - left.x) < (right.y - left.y) * (point.x - left.x) then
			inside = not inside
        end

		oldPoint = newPoint
		oldSqDist = newSqDist
	end

	return inside
end

function Polygon:distSquared( vx, vy, wx, wy )
	return (vx - wx)*(vx - wx) + 
		   (vy - wy)*(vy - wy)
end
	
	
function Polygon:distanceToSegmentSquared( px, py, vx, vy, wx, wy )
	local l2 = self:distSquared(vx,vy,wx,wy)
	if l2 == 0 then
		return self:distSquared(px, py, vx, vy)
	end
	local t = ((px - vx) * (wx - vx) + (py - vy) * (wy - vy)) / l2
	if t < 0 then
		return self:distSquared(px, py, vx, vy)
	end
	if t > 1 then
		return self:distSquared(px, py, wx, wy)
	end

	return self:distSquared(px, py, vx + t * (wx - vx), vy + t * (wy - vy))
end

function Polygon:distanceToSegment( px, py, vx, vy, wx, wy )
	return math.sqrt(self:distanceToSegmentSquared(px, py, vx, vy, wx, wy))
end

function Polygon:getClosestPointOnEdge( p3 )
	local tx = p3.x
	local ty = p3.y
	local vi1 = -1
	local vi2 = -1
	local mindist = 100000
	
	for i, _ in ipairs( self.vertices ) do
		local dist = self:distanceToSegment(
			tx,
			ty,
			self.vertices[i].x,
			self.vertices[i].y,
			self.vertices[(i % #self.vertices) + luaIndexFix].x,
			self.vertices[(i % #self.vertices) + luaIndexFix].y
		)
		if dist < mindist then
			mindist = dist
			vi1 = i
			vi2 = (i % #self.vertices) + luaIndexFix
		end
	end
	local p1 = self.vertices[vi1]
	local p2 = self.vertices[vi2]

	local x1 = p1.x
	local y1 = p1.y
	local x2 = p2.x
	local y2 = p2.y
	local x3 = p3.x
	local y3 = p3.y

	local u = (((x3 - x1) * (x2 - x1)) + ((y3 - y1) * (y2 - y1))) / (((x2 - x1) * (x2 - x1)) + ((y2 - y1) * (y2 - y1)))

	local xu = x1 + u * (x2 - x1)
	local yu = y1 + u * (y2 - y1)
	
	local linevector
	if u < 0 then
		linevector = vector(x1, y1)
	elseif u > 1 then
		linevector = vector(x2, y2)
	else 
		linevector = vector(xu, yu)
	end

	return linevector
end

----------------------------------------------------------------
-- priority queue functions
----------------------------------------------------------------

local IndexedPriorityQueue = class( 'IndexedPriorityQueue' )

function IndexedPriorityQueue:initialize( _keys )
	self.keys = _keys -- array of floats
	self.data = {}    -- array of integers
end

function IndexedPriorityQueue:insert( index )
	self.data[ #self.data+1 ] = index;
	self:reorderUp()
end

function IndexedPriorityQueue:pop()
	local r = self.data[1]
	self.data[1]=self.data[#self.data]
	table.remove(self.data) --pop
	self:reorderDown()

	return r
end

function IndexedPriorityQueue:reorderUp()
	local a = #self.data
	while a > 1 do
		if self.keys[self.data[a]] < self.keys[self.data[a-1]] then
			local tmp=self.data[a]
			self.data[a]=self.data[a-1]
			self.data[a-1]=tmp
		else 
			return
		end
		a = a - 1
	end
end

function IndexedPriorityQueue:reorderDown()
	--FIXME: might be broken
	for a = 1, #self.data-1, 1 do
		local checkA = self.keys[self.data[a]]
		local checkB = self.keys[self.data[a+1]]

		if checkA > checkB then
			local tmp = self.data[a]
			self.data[a]=self.data[a+1]
			self.data[a+1]=tmp
		else 
			return
		end
	end
end

function IndexedPriorityQueue:isEmpty()
	return #self.data == 0
end

----------------------------------------------------------------
-- a star functions
----------------------------------------------------------------

Astar = class( 'Astar' )

function Astar:initialize( _graph, _source, _target )
	self.graph  = _graph
	self.source = _source
	self.target = _target
	self.SPT    = {} -- The Shortest Path Tree
	self.G_Cost = {}
	self.F_Cost = {}
	self.SF 	= {} -- The Search Frontier

	for i, _ in ipairs( self.graph.nodes ) do
		self.G_Cost[i] = 0 --This array will store the G cost of each node <Float>
		self.F_Cost[i] = 0 --This array will store the F cost of each node <Float>
	end

	self:search()
end

function Astar:search()
	--This will be the indexed priority Queue that will sort the nodes
	local pq = IndexedPriorityQueue( self.F_Cost )
	--To start the algorithm we first add the source to the pq
	pq:insert( self.source )
	--With this we make sure that we will continue the search until there are no more nodes on the pq
	while not pq:isEmpty() do
		--1.- Take the closest node not yet analyzed
        --We get the Next Closest Node (NCN) which is the first element of the pq
		local NCN = pq:pop()
		--2.-Add its best edge to the Shortest Path Tree (Its best edge is stored on the SF)
		self.SPT[NCN] = self.SF[NCN]
		--3.- If it is the target node, finish the search
		if NCN == self.target then
			return
		end
		--4.- Retrieve all the edges of this node
		local edges = self.graph.edges[NCN]
		--With this loop we will analyze each of the edges of the array
		for _, edge in pairs( edges ) do
			local Hcost = self.graph.nodes[edge.to].pos:diff( self.graph.nodes[self.target].pos ):length()
			local Gcost = self.G_Cost[NCN] + edge.cost
			local to = edge.to
			if self.SF[edge.to] == nil then
				self.F_Cost[edge.to] = Gcost + Hcost
				self.G_Cost[edge.to] = Gcost
				pq:insert(edge.to)
				self.SF[edge.to] = edge
				--6.- If the cost of this edge is less than the cost of the arrival node until now, then update the node cost with the new one
			elseif (Gcost < self.G_Cost[edge.to]) and (self.SPT[edge.to] == nil) then
				self.F_Cost[edge.to] = Gcost + Hcost
				self.G_Cost[edge.to] = Gcost
				--Since the cost of the node has changed, we need to reorder again the pq to reflect the changes
				pq:reorderUp()
				self.SF[edge.to] = edge
			end
		end
	end
end

function Astar:getPath()
	local path = {}
	if self.target < 1 then
		return path
	end
	local nd = self.target
	table.insert( path, nd )
	while nd ~= self.source and self.SPT[nd] ~= nil do
		nd = self.SPT[nd].from
		table.insert( path, nd )
	end

	ReverseTable(path)

	return path
end
