local walkpath
local polyMap
local walkspeed = 3
local currentwalknode = 1
local walking = false
local walktox = 0
local walktoy = 0
local showLables = true

function love.load()
    --seed the random generator
    math.randomseed( os.time( ) ) math.random()

    --version check using the getVersion added in 0.9.1
    local major, minor, revision, codename = love.getVersion( )
    if major <= 0 and minor < 10 then error( 'LOVE is outdated! Please update love to version 0.10.0 or above...' ) end

    -- love.graphics.setDefaultFilter('nearest', 'nearest',1) --pixelated
    love.graphics.setDefaultFilter( 'linear', 'linear', 2 ) --smoother
    love.graphics.setBackgroundColor( 48, 48, 48 )

    class = require 'middleclass'

    --vector manpulation
    vector = require 'vector'

    --grab the a-star lib
    require 'a-star'

    playerPos = vector:new(63, 290)

    walkpath = {}
    

    initializeWalkableArea( 1 )
    -- initializeWalkableArea( 2 )
end

function love.update( dt )
    love.window.setTitle('A* Pathfinding (' .. string.format( '%04d', love.timer.getFPS() ) .. 'FPS)')

    --If walking is true, then walk some more
    if walking then
        walkPlayer()
    else
        walkpath = polyMap:calculatePath(
            playerPos, 
            vector:new(love.mouse.getX(),love.mouse.getY())
        )
    end
end

function love.draw()
    local r, g, b, a = love.graphics.getColor()
    --Draw the walkable area-polygon
    love.graphics.setColor( 0, 0, 255, 255 )
    for _, polygon in pairs( polyMap.polygons ) do
        --print(_)
        --FIXME: more effecent way
        -- love.graphics.line(
        --     polygon:dumpPoints()
        -- )
        local startNode = polygon.vertices[ 1 ]
        local endNode = polygon.vertices[ #polygon.vertices ]
        local lastX = startNode.x
        local lastY = startNode.y

        --wrap around to beginning
        love.graphics.line( lastX, lastY, endNode.x, endNode.y )

        --Draw all the vertices of the walkable area polygon
        for _, v in pairs( polygon.vertices ) do
            love.graphics.line( lastX, lastY, v.x, v.y )

            lastX, lastY = v.x, v.y

            love.graphics.circle(
                'fill',
                v.x,
                v.y,
                4,
                4
            )
        end
    end
    --Draw the graph
    if polyMap.walkgraph ~= nil then
        love.graphics.setColor( 0, 255, 0, 255 * 0.2 )
        for _, edge_from in pairs ( polyMap.walkgraph.edges ) do
            for _, edge in pairs ( edge_from ) do
                local l0 = vector:new(
                    polyMap.walkgraph.nodes[edge.from].pos.x,
                    polyMap.walkgraph.nodes[edge.from].pos.y
                )
                local l1 = vector:new(
                    polyMap.walkgraph.nodes[edge.to].pos.x,
                    polyMap.walkgraph.nodes[edge.to].pos.y
                )

                local mousePos = vector:new( love.mouse.getX(), love.mouse.getY() )
                local nodePos  = vector:new(
                    (l0.x + l1.x) * 0.5,
                    (l0.y + l1.y) * 0.5
                )
                --draw green graph
                love.graphics.setColor( 0, 255, 0, 255 * 0.2 )
                love.graphics.line(
                    l0.x,
                    l0.y,
                    l1.x,
                    l1.y
                )

                if showLables then
                    local textPos = vector:new(nodePos.x,_*10.5)
                    local distFloat = mousePos:dist( nodePos )
                    local fadeDist = 20.0
                    if distFloat > fadeDist then
                        distFloat = fadeDist
                    end
                    local fadeScale = round(1.0 - (distFloat / fadeDist) )
                    --fade based on distance to node
                    love.graphics.setColor( 255, 255, 255, 255 * fadeScale )
                    love.graphics.line(
                        nodePos.x,
                        nodePos.y,
                        textPos.x,
                        textPos.y
                    )

                    love.graphics.print(
                        "walknodes: "..edge.from..":"..edge.to,
                        textPos.x,
                        textPos.y,
                        0, 1
                    )
                end
            end
        end

        local i = 1
        for _, node in pairs( walkpath ) do

            love.graphics.setColor( 255, 255, 255, 255 )

            local s = i + 1
            if s < #walkpath+1 then
                love.graphics.line(
                    polyMap.walkgraph.nodes[walkpath[i]].pos.x,
                    polyMap.walkgraph.nodes[walkpath[i]].pos.y,
                    polyMap.walkgraph.nodes[walkpath[s]].pos.x,
                    polyMap.walkgraph.nodes[walkpath[s]].pos.y
                )
            end

            if i == 1 then
                love.graphics.setColor( 0, 255, 0, 255 )
            end
            if i == #walkpath then
                love.graphics.setColor( 255, 0, 0, 255 )
            end

            love.graphics.circle(
                'fill',
                polyMap.walkgraph.nodes[node].pos.x,
                polyMap.walkgraph.nodes[node].pos.y,
                4, 6
            )
            i = i + 1
        end
        --concave points
        love.graphics.setColor( 255, 255, 0, 255 )
        for _, co in pairs( polyMap.vertices_concave ) do
            love.graphics.circle(
                'fill',
                co.x,
                co.y,
                4, 6
            )
        end
    end
    love.graphics.setColor( 120, 255, 255, 255 )
    --draw player token
    love.graphics.rectangle(
        'fill',
        playerPos.x - 5,
        playerPos.y - 40,
        10,40
    )
    love.graphics.setColor( r, g, b, a )

    love.graphics.print( { 
        { 255, 255, 255, 255 },
        'Press 1 and 2 to switch between examples\nPress X to toggle node labels'
    }, 5, 5 )
end

function love.keyreleased( key, scancode )
    if key == '1' then
        initializeWalkableArea( 1 )
    elseif key == '2' then
        initializeWalkableArea( 2 )
    elseif key == 'x' then
        showLables = not showLables
    end
end

function love.mousereleased( x, y, button, isTouch )
    --left mouse
    if button == 1 then
        if not walking then
            ReverseTable( walkpath )
            currentwalknode = walkpath[ #walkpath ]
            table.remove(walkpath) --pop
            walking = true
            walktox = polyMap.targetx
            walktoy = polyMap.targety
        end
    end
end

function initializeWalkableArea( p )
    local polyid = 1
    
    --Create new polyMap
    polyMap = PolygonMap:new()
    polyMap.polygons[polyid] = Polygon:new()
    if p == 1 then
        polyMap.polygons[polyid]:addPoint(5,248)
        polyMap.polygons[polyid]:addPoint(235,248)
        polyMap.polygons[polyid]:addPoint(252,277)
        polyMap.polygons[polyid]:addPoint(214,283)
        polyMap.polygons[polyid]:addPoint(217,300)
        polyMap.polygons[polyid]:addPoint(235,319)
        polyMap.polygons[polyid]:addPoint(265,339)
        polyMap.polygons[polyid]:addPoint(275,352)
        polyMap.polygons[polyid]:addPoint(310,353)
        polyMap.polygons[polyid]:addPoint(309,312)
        polyMap.polygons[polyid]:addPoint(322,308)
        polyMap.polygons[polyid]:addPoint(304,279)
        polyMap.polygons[polyid]:addPoint(307,249)
        polyMap.polygons[polyid]:addPoint(419,248)
        polyMap.polygons[polyid]:addPoint(431,262)
        polyMap.polygons[polyid]:addPoint(389,274)
        polyMap.polygons[polyid]:addPoint(378,295)
        polyMap.polygons[polyid]:addPoint(408,311)
        polyMap.polygons[polyid]:addPoint(397,316)
        polyMap.polygons[polyid]:addPoint(378,309)
        polyMap.polygons[polyid]:addPoint(365,323)
        polyMap.polygons[polyid]:addPoint(342,360)
        polyMap.polygons[polyid]:addPoint(358,379)
        polyMap.polygons[polyid]:addPoint(205,379)
        polyMap.polygons[polyid]:addPoint(206,341)
        polyMap.polygons[polyid]:addPoint(212,325)
        polyMap.polygons[polyid]:addPoint(198,316)
        polyMap.polygons[polyid]:addPoint(162,298)
        polyMap.polygons[polyid]:addPoint(119,305)
        polyMap.polygons[polyid]:addPoint(99,338)
        polyMap.polygons[polyid]:addPoint(91,362)
        polyMap.polygons[polyid]:addPoint(79,372)
        polyMap.polygons[polyid]:addPoint(90,380)
        polyMap.polygons[polyid]:addPoint(4, 379)
    else
        polyMap.polygons[polyid]:addPoint(4,249)
        polyMap.polygons[polyid]:addPoint(418,251)
        polyMap.polygons[polyid]:addPoint(501,340)
        polyMap.polygons[polyid]:addPoint(507,379)
        polyMap.polygons[polyid]:addPoint(3,378)
        polyid = polyid + 1
        polyMap.polygons[polyid] = Polygon:new()
        polyMap.polygons[polyid]:addPoint(243,269)
        polyMap.polygons[polyid]:addPoint(297,273)
        polyMap.polygons[polyid]:addPoint(318,306)
        polyMap.polygons[polyid]:addPoint(314,333)
        polyMap.polygons[polyid]:addPoint(266,348)
        polyMap.polygons[polyid]:addPoint(196,341)
        polyMap.polygons[polyid]:addPoint(174,303)
        polyMap.polygons[polyid]:addPoint(196,277)
    end
    --Create a graph based on the polyMap
    polyMap:createGraph()

    -- walkpath = polyMap:calculatePath(
    --     playerPos, 
    --     vector:new(63, 400)
    -- )
end

function drawLables()
    
end

function walkPlayer()
    --Set temp walkto position to the current node the play is walking towards
    local tempwalktox = polyMap.walkgraph.nodes[currentwalknode].pos.x
    local tempwalktoy = polyMap.walkgraph.nodes[currentwalknode].pos.y
    --Create a vector for the current pos and a vector for the destionation pos
    local b = playerPos
    local a = vector( tempwalktox, tempwalktoy )
    --Create a vector from current pos to dest pos
    local c = b:diff( a )
    --if the length of that vector > walkspeed, normalize that vector and make the length = walkspeed
    --In plain english:if the destination is more that 'walkspeed' away, walk 'walkspeed' pixels towards it.
    if c:length() >= walkspeed then
        c = c:normalized()
        c.x = c.x * walkspeed
        c.y = c.y * walkspeed
    end
    --Add the new vector to the current position vector
    b = b:add(c)
    --update play position
    playerPos.x = b.x
    playerPos.y = b.y
    
    --If the end of the walkpath is not yet reached
    --and the player is currently at the 'current walk node', then set the currentwalknode to the next node from the list
    if #walkpath > 0 then
        if tempwalktox == playerPos.x and tempwalktoy == playerPos.y then
            currentwalknode = walkpath[ #walkpath ]
            table.remove(walkpath) --pop
        end
    end
    --if the player is at its final destination, stop walking
    if walktox == playerPos.x and walktoy == playerPos.y then
        walking = false
    end
end

function ReverseTable( tbl )
  for i=1, math.floor(#tbl * 0.5) do
    tbl[i], tbl[#tbl - i + 1] = tbl[#tbl - i + 1], tbl[i]
  end
end

function round(x)
  if x%2 ~= 0.5 then
    return math.floor(x+0.5)
  end
  return x-0.5
end
