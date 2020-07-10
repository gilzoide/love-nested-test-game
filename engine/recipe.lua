local Object = require 'object'

local Recipe = {}

Recipe.path = {
    'engine/wrapper/%s.lua', 'engine/wrapper/drawable/%s.lua', 
    'engine/wrapper/graphics/%s.lua', 'engine/wrapper/physics/%s.lua',
    'script/%s.lua'
}
Recipe.nestedpath = {'script/%s.nested'}

function Recipe.load(name)
    local recipe = Recipe.tryloadlua(name) or Recipe.tryloadnested(name)
    if recipe ~= nil then
        assertf(type(recipe) == 'table', "Recipe must be a table, found %q", type(recipe))
        assertf(recipe[1] == nil or recipe[1] == name, "Expected name in recipe %q to match file %q", recipe[1], name)
        return setmetatable(recipe, {
            __index = recipe.__index,
            __call = Object.new
        })
    end
end

function Recipe.tryloadlua(lowername)
    for i, fmt in ipairs(Recipe.path) do
        local filename = string.format(fmt, lowername)
        if love.filesystem.getInfo(filename) then
            return assert(love.filesystem.load(filename))()
        end
    end
    return nil
end

function Recipe.tryloadnested(lowername)
    for i, fmt in ipairs(Recipe.nestedpath) do
        local filename = string.format(fmt, lowername)
        if love.filesystem.getInfo(filename) then
            local contents = assert(love.filesystem.read(filename))
            return assert(nested.decode(contents, nested.bool_number_filter))
        end
    end
    return nil
end

return Recipe