local Expression = require 'expression'
local table_pool = require 'table_pool'.raw

local Object = {}

Object.NO_RAWSET = {}

function Object.is_object(v)
    return getmetatable(v) == Object
end

local function apply_initial_setters(recipe, obj)
    local already_processed = table_pool:acquire()
    while recipe.__super do
        for k, v in nested.kpairs(recipe) do
            if not already_processed[k] and type(k) == 'string' and recipe:setter_for(k) then
                already_processed[k] = true
                if Expression.is_getter(v) then
                    DEBUG.PUSH_CALL(recipe, k)
                    v = v(obj)
                    DEBUG.POP_CALL(recipe, k)
                end
                obj[k] = v
            end
        end
        recipe = recipe.__super
    end
    table_pool:release(already_processed)
    Input.register_events(obj)
end

function Object.new(recipe, obj, parent, root_param)
    DEBUG.PUSH_CALL(recipe, "new")
    assertf(obj == nil or #obj == 0, "FIXME %q", nested.encode(obj))
    obj = setmetatable(obj or {}, Object)
    obj[1] = recipe[1]
    rawset(obj, '__recipe', recipe)
    rawset(obj, '__parent', parent)
    rawset(obj, '__root', root_param)
    rawset(obj, '__in_middle_of_indexing', {})

    if root_param and type(recipe.id) == 'string' then
        root_param['_' .. recipe.id] = obj
    end

    for super in Recipe.iter_super_chain(recipe) do
        Recipe.invoke_raw(super, 'preinit', obj)
    end
    Recipe.invoke_raw(recipe, 'preinit', obj)

    apply_initial_setters(recipe, obj)

    for super in Recipe.iter_super_chain(recipe) do
        for i = 2, #super do
            obj[#obj + 1] = super[i]({}, obj, obj)
        end
    end

    local root_or_obj = root_param or obj
    for i = 2, #recipe do
        obj[#obj + 1] = recipe[i]({}, obj, root_or_obj)
    end

    for super in Recipe.iter_super_chain(recipe) do
        Recipe.invoke_raw(super, 'init', obj)
    end
    Recipe.invoke_raw(recipe, 'init', obj)

    DEBUG.POP_CALL(recipe, "new")
    
    return obj
end

local release_iterator_flags = { postorder = 'only', table_only = true }
function Object:release()
    self.disabled = true
    for kp, obj, parent in nested.iterate(self, release_iterator_flags) do
        obj:invoke('destroy')
        if parent then parent[kp[#kp]] = nil end
    end
end

local function rawget_self_or_recipe(self, index)
    local value = rawget(self, index)
    if value ~= nil then return value end
    return rawget(rawget(self, '__recipe'), index)
end

function Object:__index(index)
    if index == nil then return nil end
    if index == 'self' then return self end
    if index == 'recipe' then return rawget(self, '__recipe') end
    if index == 'root' then return rawget(self, '__root') end
    if index == 'parent' then return rawget(self, '__parent') end
    if Object[index] then return Object[index] end

    local value_in_recipe = rawget(self, '__recipe')[index]
    if Expression.is_getter(value_in_recipe) then
        local in_middle_of_indexing = rawget(self, '__in_middle_of_indexing')  -- avoid possible infinite recursion
        if not in_middle_of_indexing[index] then
            DEBUG.PUSH_CALL(self, index)
            in_middle_of_indexing[index] = true
            local value = value_in_recipe(self)
            in_middle_of_indexing[index] = nil
            DEBUG.POP_CALL(self, index)
            if value ~= nil then
                rawset(self, '_' .. index, value)
                return value
            end
        end
    else
        local _value = rawget(self, '_' .. index)
        if _value ~= nil then
            return _value
        elseif value_in_recipe ~= nil then
            return value_in_recipe
        elseif index ~= 'update' and index ~= 'draw' and index ~= 'late_draw' and index ~= 'hidden' then
            local root = rawget(self, '__root')
            return root and root[index]
        end
    end
end

function Object:__newindex(index, value)
    if type(index) == 'string' then
        local recipe = rawget(self, '__recipe')
        local set_method = recipe:setter_for(index)
        if iscallable(set_method) then
            DEBUG.PUSH_CALL(self, set_method_index)
            local result = set_method(self, value)
            DEBUG.POP_CALL(self, set_method_index)
            if result == Object.NO_RAWSET then
                return
            elseif result ~= nil then
                value = result
            end
            index = '_' .. index
        end
    end
    rawset(self, index, value)
end

Object.__pairs = default_object_pairs

-- Methods
function Object:type()
    return self[1]
end

function Object:typeOf(t)
    local recipe = self.__recipe
    while recipe do
        if recipe[1] == t then
            return true
        end
        recipe = recipe.__super
    end
    return false
end


function Object:invoke(method_name, ...)
    return Recipe.invoke(self, method_name, self, ...)
end
function Object:invoke_super(method_name, ...)
    return Recipe.invoke_super(self.__recipe, method_name, self, ...)
end
function Object:invoke_after_frames(n, method_name, ...)
    if self[method_name] then
        InvokeQueue:queue_after(n, Object.invoke, self, method_name, ...)
    end
end
function Object:invoke_next_frame(...)
    return self:invoke_after_frames(1, ...)
end

function Object:iter_parents()
    local current = self
    return function()
        current = current.parent
        return current
    end
end
function Object:first_parent_with(field)
    for p in self:iter_parents() do
        local value = p[field]
        if value then
            return p, value
        end
    end
end
function Object:first_parent_of(typename)
    for p in self:iter_parents() do
        if p:typeOf(typename) then
            return p
        end
    end
end

function Object:iter_children()
    local i = 1
    return function()
        i = i + 1
        return self[i]
    end
end
function Object:child_count()
    assert(#self >= 1, "FIXME object with '< 1' children")
    return #self - 1
end

function Object:set_method_enabled(method_name, enable)
    rawset(self, method_name, (enable or false) and nil)
    return enable
end
function Object:enable_method(method_name)
    return Object.set_method_enabled(self, method_name, true)
end
function Object:disable_method(method_name)
    return Object.set_method_enabled(self, method_name, false)
end

return Object
