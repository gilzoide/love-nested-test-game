local drawable_common = require 'recipe.builtin.drawable._common'

local Sprite = Recipe.new('Sprite')

Sprite.anchorPoint = {0.5, 0.5}

function Sprite:init()
    drawable_common.disable_draw_if_nil(self, self.texture)
end

Sprite.draw_push = 'transform'
Sprite.draw = drawable_common.draw
Sprite.hitTestFromOrigin = drawable_common.hitTestFromOrigin

Object.add_setter(Sprite, "anchorPoint", drawable_common.setAnchorPoint)

Object.add_getter(Sprite, "drawable", function(self)
    return self.texture
end)

Object.add_setter(Sprite, "texture", drawable_common.setDrawable)

return Sprite