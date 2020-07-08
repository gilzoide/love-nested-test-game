local Object = {}

function Object:type()
    return self[1]
end

function Object:typeOf(t)
    return self:type() == t
end

local function instantiate_into(dest, src, root_param, index_chain)
    local root = root_param or dest
    for k, v in nested.kpairs(src) do
        if type(k) == 'string' and k:sub(1, 1) == '$' then
            dest[k] = Expression.new(v, index_chain)
        elseif k ~= 'init' then
            if k == 'id' then
                root[v] = dest
            end
            dest[k] = deepcopy(v)
        end
    end
    for i = 2, #src do
        local t = src[i]
        local constructor = t[1] and R.recipe[t[1]] or deepcopy
        dest[#dest + 1] = constructor(t, dest, root)
    end
end

function Object.new(recipe, overrides, parent, root_param)
    local newobj = setmetatable({
        recipe[1],
        __recipe = recipe,
        __parent = parent,
        __root = root_param,
        __index_chain = { recipe, Object }
    }, Object)
    local index_chain = { newobj, root_param, _ENV }
    instantiate_into(newobj, recipe, root_param, index_chain)
    if overrides then
        instantiate_into(newobj, overrides, root_param, index_chain)
    end

    if recipe.init then Expression.call(recipe.init, index_chain, newobj) end
    if overrides and overrides.init then Expression.call(overrides.init, index_chain, newobj) end
    if newobj.when then
        for i = 1, #newobj.when do
            local t = newobj.when[i]
            t[2] = newobj:create_expression(t[2])
        end
    end
    return newobj
end

function Object:__index(index)
    if index == 'self' then return self end
    if index == 'recipe' then return rawget(self, '__recipe') end
    if index == 'root' then return rawget(self, '__root') end
    if index == 'parent' then return rawget(self, '__parent') end
    if type(index) == 'string' then
        local value = rawget(self, '$' .. index)
        if value then
            value = value(self)
            Object.__newindex(self, index, value)
            return value
        end
        value = rawget(self, '_' .. index)
        if value ~= nil then return value end
    end
    return index_first_of(index, rawget(self, '__index_chain'))
end

function Object:__newindex(index, value)
    if type(index) == 'string' and index:match('^[^_$]') then index = '_' .. index end
    rawset(self, index, value)
end

function Object:__pairs()
    return coroutine.wrap(function()
        for k, v in rawpairs(self) do
            if type(k) == 'string' then
                if k:match('^_[^_]') then
                    coroutine.yield(k:sub(2), v)
                end
            else
                coroutine.yield(k, v)
            end
        end
    end)
end

function Object:iter_parents()
    local current = self
    return function()
        current = current.parent
        return current
    end
end

function Object:expressionify(field_name, ...)
    if self[field_name] then
        local expression = self:create_expression(self[field_name], ...)
        self[field_name] = expression
        return expression
    end
end

function Object:create_expression(v, ...)
    local index_chain = { self, self.root, _ENV }
    table_extend(index_chain, ...)
    return Expression.new(v, index_chain)
end

function Object:add_when(condition, func)
    if not self.also_when then self.also_when = {} end
    self.also_when[#self.also_when + 1] = { condition, self:create_expression(func) }
end

return Object