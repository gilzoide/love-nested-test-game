local table_stack = require 'table_stack'

local Director = {}

local function iterate_scene(scene, skip_if_field)
    local iterator = scene:iterate()
    return function()
        local kp, obj, parent, skip
        repeat
            kp, obj, parent = iterator(skip)
            skip = obj and obj[skip_if_field]
        until not skip
        return kp, obj, parent
    end
end

function Director.update(dt, scene)
    scene = scene or Scene
    if scene.paused then return end
    for kp, obj in iterate_scene(scene, 'paused') do
        obj:invoke('update', dt)
    end
end


local pop_list = table_stack.new(100)
pop_list:push(-1)
function Director.draw(scene)
    scene = scene or Scene
    pop_list:clear(1)
    for kp, obj in iterate_scene(scene, 'hidden') do
        while #kp <= pop_list:peek()[1] do
            pop_list:pop()
            love.graphics.pop()
        end
        if obj.draw then
            if obj.draw_push then
                love.graphics.push(obj.draw_push)
                pop_list:push(#kp, obj)
            end
            DEBUG.PUSH_CALL(obj, 'draw')
            obj:draw()
            DEBUG.POP_CALL(obj, 'draw')
        end
    end
    for i = pop_list.n, 2, -1 do
        love.graphics.pop()
    end
    DEBUG.ONLY(function()
        local stackDepth = love.graphics.getStackDepth()
        if stackDepth ~= 0 then
            DEBUG.WARN("MISSING POP, stackDepth = %d", stackDepth)
            for i = 1, stackDepth do love.graphics.pop() end
        end
    end)
end

return Director
