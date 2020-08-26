local MouseArea = Recipe.new('MouseArea')

function MouseArea:init()
    self.target = self:first_parent_with('hitTestFromOrigin')
    if not self.target then
        DEBUG.WARN("Couldn't find hitTestFromOrigin in MouseArea parent")
        self:disable_method('update')
        self:disable_method('draw')
    end
    self.button = { {}, {}, {} }
end

function MouseArea:update(dt)
    local inside = self.__inside
    for i, button in ipairs(self.button) do
        if inside and get(mouse, i, 'pressed') then
            button.down = true
            button.pressed = true
            set_next_frame(button, 'pressed', nil)
        end
        if button.down and get(mouse, i, 'released') then
            button.down = nil
            button.released = inside and 'inside' or 'outside' 
            set_next_frame(button, 'released', nil)
        end
    end
    self.hover = inside
end

function MouseArea:draw()
    local x, y = love.graphics.inverseTransformPoint(unpack(mouse.position))
    self.__inside = self.target:hitTestFromOrigin(x, y)
end

MouseArea:add_getter('mouse', function(self)
    return _ENV.mouse
end)
MouseArea:add_getter('moved', function(self)
    return self.__inside and _ENV.mouse.moved or nil
end)
MouseArea:add_getter('wheelmoved', function(self)
    return self.__inside and _ENV.mouse.wheelmoved or nil
end)

return MouseArea
