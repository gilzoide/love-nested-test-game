-- Ignore: blank ,;\t\r
-- Always special: \n()[]{}:
-- Special if first in token: '"`#
----------  Decoder  ----------
local TOKEN = {
    'SPACE', 'COMMENT', 'NEWLINE', 'EOF',
    'OPEN_BRACKETS', 'CLOSE_BRACKETS',
    'OPEN_PAREN', 'CLOSE_PAREN',
    'OPEN_BRACES', 'CLOSE_BRACES',
    'KEYVALUE',
    -- 'QUOTED', 'TEXT' -- both return as strings rather than numeric codes
}
for i = 1, #TOKEN do TOKEN[TOKEN[i]] = i end

local TOKEN_BY_PREFIX = {
    [' '] = 'SPACE', [','] = 'SPACE', [';'] = 'SPACE', ['\t'] = 'SPACE', ['\r'] = 'SPACE',
    ['#'] = 'COMMENT',
    ['\n'] = 'NEWLINE',
    [''] = 'EOF',
    ['['] = 'OPEN_BRACKETS', [']'] = 'CLOSE_BRACKETS',
    ['('] = 'OPEN_PAREN', [')'] = 'CLOSE_PAREN',
    ['{'] = 'OPEN_BRACES', ['}'] = 'CLOSE_BRACES',
    [':'] = 'KEYVALUE',
    ["'"] = 'QUOTED', ['"'] = 'QUOTED', ['`'] = 'QUOTED',
}
local TOKEN_DESCRIPTION = {
    [TOKEN.OPEN_BRACKETS] = '[', [TOKEN.CLOSE_BRACKETS] = ']',
    [TOKEN.OPEN_PAREN] = '(', [TOKEN.CLOSE_PAREN] = ')',
    [TOKEN.OPEN_BRACES] = '{', [TOKEN.CLOSE_BRACES] = '}',
}
local MATCHING_CLOSING_BLOCK = {
    [''] = TOKEN.EOF,
    [TOKEN.OPEN_BRACKETS] = TOKEN.CLOSE_BRACKETS,
    [TOKEN.OPEN_PAREN] = TOKEN.CLOSE_PAREN,
    [TOKEN.OPEN_BRACES] = TOKEN.CLOSE_BRACES,
}
-- Each function returns token, advance
-- Quotes error if not closed properly
local LEXICAL_SCANNERS = {
    SPACE = function(s)
        local pos = s:match('[ ,;\t\r]+()')
        return TOKEN.SPACE, pos
    end,
    COMMENT = function(s)
        local pos = s:match('#[^\n]+()')
        return TOKEN.COMMENT, pos
    end,
    NEWLINE = function(s) return TOKEN.NEWLINE, 2, 1, 1 end,
    EOF = function(s) return TOKEN.EOF, 0 end,
    OPEN_BRACKETS = function(s) return TOKEN.OPEN_BRACKETS, 2 end,
    CLOSE_BRACKETS = function(s) return TOKEN.CLOSE_BRACKETS, 2 end,
    OPEN_PAREN = function(s) return TOKEN.OPEN_PAREN, 2 end,
    CLOSE_PAREN = function(s) return TOKEN.CLOSE_PAREN, 2 end,
    OPEN_BRACES = function(s) return TOKEN.OPEN_BRACES, 2 end,
    CLOSE_BRACES = function(s) return TOKEN.CLOSE_BRACES, 2 end,
    KEYVALUE = function(s) return TOKEN.KEYVALUE, 2 end,
    QUOTED = function(s)
        local delimiter = s:sub(1, 1)
        local pattern = string.format("([^%s]*%s?)%s()", delimiter, delimiter, delimiter) -- ([^']*'?)'()
        local components = {}
        for m, pos in s:sub(2):gmatch(pattern) do
            components[#components + 1] = m
            if m:sub(-1) ~= delimiter then
                local result = table.concat(components)
                local newlines, last_start = 0, nil
                for pos_after_newline in result:gmatch("\n()") do
                    newlines = newlines + 1
                    last_start = pos_after_newline
                end
                return result, pos + 1, newlines, (last_start and pos - last_start + 1), delimiter
            end
        end
        return nil, string.format('Unmatched closing %q', delimiter)
    end,
    TEXT = function(s)
        return s:match('([^ ,;\t\r\n%[%](){}:]+)()')
    end,
}

local function peek_token_type_name(s)
    local prefix = s:sub(1, 1)
    return TOKEN_BY_PREFIX[prefix] or 'TEXT'
end

local function read_next_token(s)
    local rule = peek_token_type_name(s)
    return LEXICAL_SCANNERS[rule](s)
end

local function token_description(t)
    if type(t) == 'number' then
        local description = TOKEN_DESCRIPTION[t]
        return description and string.format("%q", description) or TOKEN[t]
    else
        return t
    end
end

local PARSE_EVENTS = { 'TEXT', 'KEY', 'OPEN_NESTED', 'CLOSE_NESTED', 'SIBLING', 'ERROR' }
for i = 1, #PARSE_EVENTS do local name = PARSE_EVENTS[i]; PARSE_EVENTS[name] = name end

local function decode_iterate_coroutine(text)
    local line, column = 1, 1
    local function send_event(event, ...) coroutine.yield(line, column, event, ...) end
    local expected_closing_token = MATCHING_CLOSING_BLOCK['']
    local expected_closing_stack = { expected_closing_token }

    local token, previous_token, advance, newlines, newcolumn, quotation_mark
    repeat
        previous_token = token
        token, advance, newlines, newcolumn, quotation_mark = read_next_token(text)
        if not token then
            send_event(PARSE_EVENTS.ERROR, advance)
            break
        elseif type(token) == 'string' then
            if peek_token_type_name(text:sub(advance)) == 'KEYVALUE' then
                send_event(PARSE_EVENTS.KEY, token, quotation_mark)
            else
                send_event(PARSE_EVENTS.TEXT, token, quotation_mark)
            end
        elseif token == TOKEN.EOF or token == TOKEN.CLOSE_BRACKETS or token == TOKEN.CLOSE_PAREN or token == TOKEN.CLOSE_BRACES then
            if token == expected_closing_token then
                if token == TOKEN.EOF then break end
                send_event(PARSE_EVENTS.CLOSE_NESTED, TOKEN_DESCRIPTION[token])
                table.remove(expected_closing_stack)
                expected_closing_token = expected_closing_stack[#expected_closing_stack]
            else
                send_event(PARSE_EVENTS.ERROR, string.format('Expected closing block with %s, but found %s', token_description(expected_closing_token), token_description(token)))
                break
            end
        elseif token == TOKEN.OPEN_BRACKETS or token == TOKEN.OPEN_PAREN or token == TOKEN.OPEN_BRACES then
            send_event(PARSE_EVENTS.OPEN_NESTED, TOKEN_DESCRIPTION[token])
            expected_closing_token = MATCHING_CLOSING_BLOCK[token]
            table.insert(expected_closing_stack, expected_closing_token)
        elseif token == TOKEN.KEYVALUE then
            if type(previous_token) ~= 'string' then
                send_event(PARSE_EVENTS.ERROR, string.format('Key-value mapping must appear right after text, found %s instead', token_description(previous_token)))
                break
            end
        else
             -- TODO: after thorough testing, remove unecessary assertion
            assert(token == TOKEN.SPACE or token == TOKEN.COMMENT or token == TOKEN.NEWLINE, 'FIXME!!!')
        end

        text = text:sub(advance)
        column = newcolumn or (column + advance - 1)
        if newlines then line = line + newlines end
    until token == TOKEN.EOF
end
local function decode_iterate(text)
    return coroutine.wrap(function() decode_iterate_coroutine(text) end)
end

local EMPTY_OPTIONS = {}
local function create_table() return {} end
local function decode(text, options)
    options = options or EMPTY_OPTIONS
    local text_filter = options.text_filter
    local table_filter = options.table_filter
    local table_constructor = options.table_constructor or create_table
    local root_constructor = options.root_constructor or table_constructor

    local current, key, value = root_constructor('', line, column)
    local table_stack = { current }
    for line, column, event, token, quote in decode_iterate(text) do
        if event == 'TEXT' then
            value = text_filter and text_filter(token, quote, line, column)
            if value == nil then value = token end
            current[key or #current + 1], key = value, nil
        elseif event == 'KEY' then
            key = token
        elseif event == 'OPEN_NESTED' then
            local nested_table = table_constructor(token, line, column)
            current[key or #current + 1], key = nested_table, nil
            table.insert(table_stack, nested_table)
            current = nested_table
        elseif event == 'CLOSE_NESTED' then
            table.remove(table_stack)
            current = table_stack[#table_stack]
        elseif event == 'ERROR' then
            return nil, string.format('Error at line %u (col %u): %s', line, column, token)
        end
    end
    return current
end

local function decode_file(stream, ...)
    local previous = io.input()
    stream = io.input(stream)
    local contents = stream:read('*a')
    stream:close()
    io.input(previous)
    return decode(contents, ...)
end

----------  Iterators  ----------
local function kpairs(t)
    return coroutine.wrap(function()
        for k, v in pairs(t) do
            if type(k) ~= 'number' then coroutine.yield(k, v) end
        end
    end)
end

local POSTORDER = 'postorder'
local POSTORDER_ONLY = 'only'
local TABLE_ONLY = 'table_only'
local INCLUDE_KV = 'include_kv'
local SKIP_ROOT = 'skip_root'
local function iterate_step(keypath, t, parent, options)
    local is_table = type(t) == 'table'
    if options[TABLE_ONLY] and not is_table then return end
    local skip = options[SKIP_ROOT] and #keypath == 0
    local postorder = options[POSTORDER]
    local skip_inner
    if not skip and postorder ~= POSTORDER_ONLY then skip_inner = coroutine.yield(keypath, t, parent, true) end
    if not skip_inner and is_table then
        local keypath_index = #keypath + 1
        for i = 1, #t do
            keypath[keypath_index] = i
            iterate_step(keypath, t[i], t, options)
        end
        if options[INCLUDE_KV] then
            for k, v in kpairs(t) do
                keypath[keypath_index] = k
                iterate_step(keypath, v, t, options)
            end
        end
        keypath[keypath_index] = nil
    end
    if not skip and postorder then coroutine.yield(keypath, t, parent, false) end
end
local function iterate(t, options)
    options = options or EMPTY_OPTIONS
    return coroutine.wrap(function() iterate_step({}, t, nil, options) end)
end

----------  Encoder  ----------
local anchor_mt = {}
function anchor_mt.__tostring(self)
    local ref = ''
    if self.ref_count > 0 then
        self.state.anchor_count = self.state.anchor_count + 1
        self.index = self.state.anchor_count
        ref = string.format("&%d ", self.index)
    end
    return '[' .. ref
end
function anchor_mt.new(state)
    return setmetatable({ state = state, ref_count = 0 }, anchor_mt)
end

local anchor_reference_mt = {}
function anchor_reference_mt.__tostring(self)
    return '*' .. self.anchor.index
end
function anchor_reference_mt.new(anchor)
    anchor.ref_count = anchor.ref_count + 1
    return setmetatable({ anchor = anchor }, anchor_reference_mt)
end

local encode
local function encode_into(state, t)
    local function append(v) state[#state + 1] = v end
    if type(t) == 'table' then
        local keypath = state.keypath
        if state[t] ~= nil then
            append(anchor_reference_mt.new(state[t]))
            return
        end
        local compact = state.compact
        if compact and state[#state] == ' ' then state[#state] = nil end
        append(anchor_mt.new(state))
        state[t] = state[#state]
        for i, v in ipairs(t) do
            keypath[#keypath + 1] = i
            encode_into(state, v)
            if not compact or state[#state] ~= ']' then append(' ') end
            keypath[#keypath] = nil
        end
        for k, v in kpairs(t) do
            -- TODO: error if k is table
            keypath[#keypath + 1] = k
            encode_into(state, k)
            append(':')
            if not compact then append(' ') end
            encode_into(state, v)
            append(' ')
            keypath[#keypath] = nil
        end
        if state[#state] == ' ' then state[#state] = nil end
        append(']')
    else
        local encoded_value = tostring(t)
        if encoded_value:match('[ ,\t\r\n%[%](){}:;]') or encoded_value:match('^[\'\"`#]') then
            -- TODO: if compact, find out the quotation mark that requires less escaping
            encoded_value = '"' .. encoded_value:gsub('"', '""') .. '"'
        end
        append(encoded_value)
    end
end

encode = function(t, compact)
    local state = { compact = compact, keypath = {}, anchor_count = 0 }
    local success, err = pcall(encode_into, state, t)
    if not success then
        return nil, err
    else
        local is_table = type(t) == 'table'
        local i = is_table and 2 or 1
        local j = is_table and #state - 1 or #state
        for k = i, j do state[k] = tostring(state[k]) end
        return table.concat(state, '', i, j)
    end
end

local function encode_to_file(t, stream, ...)
    local encoded_value, err = encode(t, ...)
    if not encoded_value then return nil, err end
    local previous = io.output()
    stream = io.output(stream)
    stream:write(encoded_value)
    stream:close()
    io.output(previous)
    return true
end

----------  Keypaths  ----------
local function get_internal(t, create_subtables, keypath, ...)
    if select('#', ...) > 0 then keypath = { keypath, ... }
    elseif type(keypath) ~= 'table' then keypath = { keypath }
    end
    for i = 1, #keypath do
        local key = keypath[i]
        local ttype = type(t)
        if ttype ~= 'table' then
            keypath[i] = nil
            local keypath_with_error = encode(keypath)
            keypath[i] = key
            return nil, string.format("Cannot index %s at keypath %s", ttype, keypath_with_error)
        end
        
        local subtable = t[key]
        if subtable == nil and create_subtables then
            subtable = {}
            t[key] = subtable
        end
        t = subtable
    end
    return t
end
local function get(t, ...)
    return get_internal(t, false, ...)
end
local function get_or_create(t, ...)
    return get_internal(t, true, ...)
end

local function set_internal(t, create_subtables, keypath, ...)
    local value
    local n = select('#', ...)
    if n > 1 then
        keypath = { keypath, ... }
        value, keypath[n + 1] = keypath[n + 1], nil
    else
        if type(keypath) ~= 'table' then keypath = { keypath } end
        value = ...
    end
    local subtable, key = t, nil
    for i = 1, #keypath - 1 do
        key = keypath[i]
        local next_subtable = subtable[key]
        if next_subtable == nil and create_subtables then
            next_subtable = {}
            subtable[key] = next_subtable
        end
        local ttype = type(next_subtable)
        if ttype ~= 'table' then
            key, keypath[i + 1] = keypath[i + 1], nil
            local keypath_with_error = encode(keypath)
            keypath[i + 1] = key
            return nil, string.format("Cannot index %s at keypath %s", ttype, keypath_with_error)
        end
        subtable = next_subtable
    end
    key = keypath[#keypath]
    subtable[key] = value
    return t
end
local function set(t, ...)
    return set_internal(t, false, ...)
end
local function set_or_create(t, ...)
    return set_internal(t, true, ...)
end

----------  Filter  ----------
local function bool_number_filter(s, quoted)
    if quoted then return nil
    elseif s == 'true' then return true
    elseif s == 'false' then return false
    else return tonumber(s)
    end
end

----------  Module  ----------
return {
    decode_iterate = decode_iterate, decode = decode, decode_file = decode_file,
    encode = encode, encode_to_file = encode_to_file,
    kpairs = kpairs,
    bool_number_filter = bool_number_filter,
    get = get, get_or_create = get_or_create,
    set = set, set_or_create = set_or_create,
    iterate = iterate,
    POSTORDER = POSTORDER,
    POSTORDER_ONLY = POSTORDER_ONLY,
    TABLE_ONLY = TABLE_ONLY,
    INCLUDE_KV = INCLUDE_KV,
    SKIP_ROOT = SKIP_ROOT,
}
