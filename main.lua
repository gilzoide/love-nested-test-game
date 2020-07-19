require 'globals'

function love.load(arg)
    DEBUG.LOAD(arg)
    DEBUG.STARTTIMER('load')
    
    local initial_scene = arg[1] or 'PetecaScene'
    local scene = assert(R(initial_scene))()
    addtoscene(scene)

    -- print(nested.encode(scene))
    DEBUG.REPORTTIMER('load')
    _ENV.TIME = 0
end

function love.update(dt)
    _ENV.dt = dt
    _ENV.TIME = _ENV.TIME + dt
    Setqueue:update(dt)
    Director.update(dt)
    DEBUG.UPDATE(dt)
end

function love.draw()
    Setqueue:flip()
    Director.draw()
    Setqueue:frame_ended()
    DEBUG.DRAW()
end

love.mousemoved = Input.mousemoved
love.mousepressed = Input.mousepressed
love.mousereleased = Input.mousereleased
love.wheelmoved = Input.wheelmoved

love.keypressed = Input.keypressed
love.keyreleased = Input.keyreleased
