local Object = require 'object'

local Expression = {}

local loadstring_with_env
if setfenv and loadstring then
    loadstring_with_env = function(body, env)
        local chunk, err = loadstring(body)
        if not chunk then return nil, err end
        return setfenv(chunk, env)
    end
else
    loadstring_with_env = function(body, env)
        return load(body, nil, 't', env)
    end
end

local loadstring = loadstring or load
local nested_function_evaluate = nested_function.evaluate

function Expression.is_expression_template(v)
    return type(v) == 'table' and v.__expression
end

local function bind_argument_names_to_callable(callable, argument_names)
    return function(expr, ...)
        for i = 1, math.min(#argument_names, select('#', ...)) do
            local name = argument_names[i]
            expr[name] = select(i, ...)
        end
        return callable(expr, ...)
    end
end

local function call_expression_literal(expr, ...)
    return nested_function_evaluate(expr[2], expr, ...)
end

local function call_expression_self(expr, ...)
    return nested_function_evaluate(expr, expr, ...)
end

function Expression.empty_template()
    local template = { __call = call_expression_self, __pairs = Object.__pairs }
    template.__expression = template
    return setmetatable(template, template)
end

function Expression.template(literal, insert_return, argument_names)
    if type(literal) == 'function' or Expression.is_expression_template(literal) then return literal end

    local callable
    if type(literal) == 'string' then
        if insert_return then
            literal = 'return ' .. literal
        end
        local chunk = assert(loadstring(literal))
        callable = function(expr, ...)
            return setfenv(chunk, expr)(...)
        end
    else
        callable = call_expression_literal
    end

    if argument_names then
        callable = bind_argument_names_to_callable(callable, argument_names)
    end

    local template = { 'Expression', literal, __expression = literal, __call = callable, __pairs = Object.__pairs }
    return setmetatable(template, template)
end

function Expression.instantiate(template, index_chain)
    if type(template) == 'function' then return template end
    assertf(Expression.is_expression_template(template), "FIXME invalid expression template %q", nested.encode(template))

    local expr = { 'Expression', template.__expression,
        __index = create_index_first_of(index_chain),
        __call = template.__call,
        __pairs = template.__pairs,
    }
    return setmetatable(expr, expr)
end

function Expression.new(literal, index_chain, ...)
    local template = Expression.template(literal, ...)
    return Expression.instantiate(template, index_chain)
end

function Expression.call(template, index_chain, ...)
    local expr = Expression.instantiate(template, index_chain)
    return expr and expr(...)
end

return Expression