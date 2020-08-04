local MouseArea = Recipe.new('MouseArea')
    
MouseArea.button = 1

function MouseArea:init()
    self.target = self:first_parent_with('hitTestFromOrigin')
    if not self.target then
        DEBUG.WARN("Couldn't find hitTestFromOrigin in MouseArea parent")
        self.paused = true
    end
end

function MouseArea:draw(dt)
    local x, y = love.graphics.inverseTransformPoint(unpack(mouse.position))
    local inside = self.target:hitTestFromOrigin(x, y)
    if inside and get(mouse, self.button, 'pressed') then
        self.down = true
        self.pressed = true
        set_next_frame(self, 'pressed', nil)
    end
    if self.down and get(mouse, self.button, 'released') then
        self.down = nil
        self.released = inside and 'inside' or 'outside' 
        set_next_frame(self, 'released', nil)
    end
    self.hover = inside
end

return MouseArea
