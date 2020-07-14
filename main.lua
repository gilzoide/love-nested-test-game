require 'globals'

function love.load(arg)
    DEBUG.STARTTIMER('load')
    
    local initial_scene = arg[1] or 'PetecaScene'
    local scene = assert(R.recipe[initial_scene])()
    addtoscene(scene)

    -- print(nested.encode(scene))
    DEBUG.REPORTTIMER('load')
end

_ENV.TIME = 0
function love.update(dt)
    _ENV.dt = dt
    _ENV.TIME = _ENV.TIME + dt
    Setqueue:update(dt)
    Director.update(dt)
end

function love.draw()
    Setqueue:flip()
    Director.draw()
    Setqueue:frame_ended()
end

love.mousemoved = Input.mousemoved
love.mousepressed = Input.mousepressed
love.mousereleased = Input.mousereleased
love.wheelmoved = Input.wheelmoved

love.keypressed = Input.keypressed
love.keyreleased = Input.keyreleased
