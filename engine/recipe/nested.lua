local AssetMap = require 'resources.asset_map'
local Object = require 'object'

local recipe_nested = {}

local function text_filter(s, quotes, file, line)
    if quotes == '`' then
        return Expression.from_string(s, file, line)
    else
        return nested.bool_number_filter(s, quotes, line)
    end
end

local function table_constructor(opening, file, line)
    local t = nested_ordered.new()
    rawset(t, '__opening_token', opening)
    rawset(t, '__file', file)
    rawset(t, '__line', line)
    return t
end

local function bind_file_to_constructors(file)
    return function(s, quotes, line)
        return text_filter(s, quotes, file, line)
    end, function(opening, line)
        return table_constructor(opening, file, line)
    end
end

function recipe_nested.load(filename, contents)
    local recipe = assert(nested.decode(contents, bind_file_to_constructors(filename)))
    local name = AssetMap.get_basename(filename)
    recipe_nested.preprocess(name, recipe)
    return recipe
end

function recipe_nested.preprocess(name, recipe)
    local recipe_name = recipe[1]
    if type(recipe_name) ~= 'string' then
        table.insert(recipe, 1, name)
    else
        assertf(recipe_name == name, "Expected name in recipe %q to match file %q", recipe_name, name)
        -- TODO: permit specifying __super here, replacing name
    end

    for kp, t, parent in nested.iterate(recipe, { table_only = true }) do
        for k, v in nested.kpairs(t) do
            if type(v) == 'table' and v.__opening_token == '{' then
                t[k] = Expression.from_table(v, v.__file, v.__line)
            end
            if type(k) == 'string' and k:startswith(Object.SET_METHOD_PREFIX) then
                Expression.bind_argument_names(v, Object.SET_METHOD_ARGUMENT_NAMES)
            end
        end
        if #kp > 0 then
            local super_recipe_name = t[1]
            assertf(super_recipe_name[1] ~= recipe[1], "Cannot have recursive recipes @ %s:%s", super_recipe_name.__file, super_recipe_name.__line)
            local super_recipe = assertf(R(super_recipe_name), "Recipe %q couldn't be loaded", super_recipe_name)
            t.__super = super_recipe
            t.__parent = parent
            if super_recipe.__init_recipe then
                DEBUG.PUSH_CALL(t, '__init_recipe')
                super_recipe:__init_recipe(t)
                DEBUG.POP_CALL(t, '__init_recipe')
            end
        end
        setmetatable(t, Recipe)
    end
end

return recipe_nested