function love.conf( t )
    t.version          = '0.10.0'
    t.title            = 'A* Pathfinding'
    t.author           = 'To-mos'
    t.url              = 'https://github.com/To-mos'
    t.console          = true
    -- save folder name
    t.identity         = 'pfind'

    t.window.width     = 512
    t.window.height    = 384

    t.window.resizable = false
    t.window.vsync     = true
    t.window.fullscreentype = 'desktop'

    -- DISABLED MODULES
    t.modules.physics  = false
    t.modules.joystick = false
    t.modules.touch    = false
end