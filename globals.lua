unpack = unpack or table.unpack
local __pairs = pairs
function pairs(t)
    local mt = getmetatable(t)
    return (mt and mt.__pairs or __pairs)(t)
end
pcall(require, 'DEBUG')  -- DEBUG is excluded on release
nested = require 'nested'
nested_function = require 'nested.function'
nested_match = require 'nested.match'
log = require 'log'
Expression = require 'expression'
_ENV = _ENV or getfenv()

METER_BY_PIXEL = 60
love.physics.setMeter(METER_BY_PIXEL)

get = nested.get
get_or_create = nested.get_or_create
set = nested.set
set_or_create = nested.set_or_create

function index_first_of(index, index_chain)
    for i = 1, #index_chain do
        local t = index_chain[i]
        if t then
            local value = t[index]
            if value ~= nil then return value end
        end
    end
    return nil
end

function safeunpack(v)
    if type(v) == 'table' then
        return unpack(v)
    elseif v ~= nil then
        return v
    end
    -- if v == nil, don't return any values
end

function string.startswith(s, prefix)
    return s:sub(1, #prefix) == prefix
end

function rawpairs(t)
    return next, t, nil
end

function index_or_create(t, index)
    local value = t[index]
    if value == nil then
        value = {}
        t[index] = value
    end
    return value
end

function addchild(obj)
    local self = getfenv(2)
    self[#self + 1] = obj
    Scene:track(obj)
    return obj
end
function addtoscene(obj)
    Scene:add(obj)
end

function assertf(cond, fmt, ...)
    return assert(cond, string.format(fmt, ...))
end

function errorf(fmt, ...)
    return error(string.format(fmt, ...))
end

function clamp(x, min, max)
    if x < min then return min
    elseif x > max then return max
    else return x
    end
end

function deg2rad(angle)
    return angle * math.pi / 180
end
function rad2deg(angle)
    return angle * 180 / math.pi
end

function bind(f, ...)
    local bound_args = {...}
    return function(...)
        local args = {}
        for i = 1, #bound_args do args[i] = bound_args[i] end
        for i = 1, select('#', ...) do args[#args + 1] = select(i, ...) end
        return f(unpack(args))
    end
end

function is_callable(v)
    local vtype = type(v)
    if vtype == 'table' then
        local mt = getmetatable(v)
        return mt and type(mt.__call) == 'function'
    else
        return vtype == 'function'
    end
end

function deepcopy(value)
    if type(value) == 'table' then
        local newvalue = {}
        for k, v in pairs(value) do
            newvalue[k] = deepcopy(v)
        end
        return newvalue
    else
        return value
    end
end

key = {}
mouse = {}
Input = require 'input'

Scene = require 'scene'.new()
Setqueue = require 'setqueue'.new()
Collisions = require 'collisions'.new()
Director = require 'director'
Resources = require 'resources'.new()
R = Resources
State = {
    scene = Scene,
    resources = Resources,
    key = key,
    mouse = mouse,
    collisions = Collisions,
    setqueue = Setqueue,
}

function dump_state()
    print(nested.encode(State))
end

function set_next_frame(...)
    Setqueue:queue(...)
end
