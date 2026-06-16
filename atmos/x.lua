local M = {}

-- task/tasks metatables are injected by `run.lua` to avoid a require cycle
local meta_task, meta_tasks

function M._metas (task, tasks)
    meta_task, meta_tasks = task, tasks
end

function M.is (v, x)
    local tv = type(v)
    local tx = type(x)
    local mv = getmetatable(v)
    if v == x then
        return true
    elseif tv == x then
        return true
    elseif x=='task' and mv==meta_task then
        return true
    elseif x=='tasks' and mv==meta_tasks then
        return true
    elseif tv=='table' and tx=='string' and type(v.tag)=='string' then
        return M.gte(x, v.tag)
    else
        return M.gte(x, v)
    end
end

function M.gte (a, b)
    local ta = type(a)
    local tb = type(b)
    if ta ~= tb then
        return false
    elseif a == b then
        return true
    elseif getmetatable(a) ~= getmetatable(b) then
        return false
    elseif ta=='string' and tb=='string' then
        return (string.sub(b, 1, #a+1) == a..'.')
    elseif ta== 'table' and tb=='table' then
        for k,va in pairs(a) do
            if not M.gte(va,b[k]) then
                return false
            end
        end
        return true
    else
        return false
    end
end

function M.eq (a, b)
    return M.gte(a,b) and M.gte(b,a)
end

local function fi (N, i)
    i = i + 1
    if i>N then
        return nil
    end
    return i
end

-- stateless table iterator: array part (1..#t) then non-array keys,
-- skipping numeric keys already covered by the array part
local function fx (t, k)
    local n = #t
    if k == nil then
        if n >= 1 then
            return 1, t[1]
        end
    elseif math.type(k)=='integer' and k>=1 and k<n then
        return k+1, t[k+1]
    elseif math.type(k)=='integer' and k==n then
        k = nil
    end
    repeat
        k = next(t, k)
    until (k==nil) or not (type(k)=='number' and k>0 and k<=n)
    if k ~= nil then
        return k, t[k]
    end
end

-- generic-for iterator over `t`; yield arity depends on the source:
--   number / (n,m) / nil : one value (the index)
--   table / __pairs      : key, value
--   function / __call    : generator values, until nil
-- NOTE: consumers must handle per-source arity (e.g. `xin` checks `y`).
function M.iter (t, ...)
    local mt = getmetatable(t)
    if mt and mt.__pairs then
        return mt.__pairs(t)
    elseif mt and mt.__call then
        return t
    elseif t == nil then
        return fi, math.maxinteger, 0
    elseif type(t) == 'function' then
        return t
    elseif type(t) == 'number' then
        local fr, to
        if ... then
            fr, to = t-1, ...
        else
            fr, to = 0, t
        end
        return fi, to, fr
    elseif type(t) == 'table' then
        return fx, t, nil
    else
        error("TODO - iter(t)")
    end
end

function M.xin (v, t)
    for a,b,c in M.iter(t) do
        assert(c == nil)
        if b == nil then
            if M.gte(v, a) then
                return true
            end
        elseif type(a) == 'number' then
            if M.gte(v,b) then
                return true
            end
        else
            if M.gte(v,a) or M.gte(v,b) then
                return true
            end
        end
    end
    return false
end

function M.cat (v1, v2)
    local ok, v = pcall(function()
        return v1 .. v2
    end)
    if ok then
        return v
    end

    local ret = {}
    for a,b,c in M.iter(v1) do
        assert(c == nil)
        if b == nil then
            ret[#ret+1] = a
        else
            ret[a] = b
        end
    end
    local n = 1
    for a,b,c in M.iter(v2) do
        assert(c == nil)
        if b == nil then
            ret[#ret+1] = a
        else
            if a == n then
                ret[#ret+1] = b
                n = n + 1
            else
                ret[a] = b
            end
        end
    end
    return ret
end

function M.tostring (v)
    if type(v) ~= 'table' then
        return tostring(v)
    else
        local fst = true
        local vs = ""
        local t = {}
        for k,x in pairs(v) do
            assert(type(k)=='number' or type(k)=='string')
            --if k ~= 'tag' then
                t[#t+1] = { k, x }
            --end
        end
        table.sort(t, function (x, y)
            local n1, n2 = tonumber(x[1]), tonumber(y[1])
            if n1 and n2 then
                return (n1 < n2)
            else
                return (tostring(x[1]) < tostring(y[1]))
            end
        end)
        local i = 1
        for _,kx in ipairs(t) do
            local k,x = table.unpack(kx)
            if not fst then
                vs = vs .. ', '
            end
            if tonumber(k) == i then
                i = i + 1
                vs = vs .. M.tostring(x)
            else
                vs = vs .. k .. '=' .. M.tostring(x)
            end
            fst = false
        end
        --local tag = v.tag and (':'..v.tag..' ') or ''
        return --[[tag ..]] "{" .. vs .. "}"
    end
end

function M.print (...)
    local ret = {}
    for i=1, select('#', ...) do
        ret[#ret+1] = M.tostring(select(i, ...))
    end
    print(table.unpack(ret))
end

function M.copy (v)
    if type(v) ~= 'table' then
        return v
    end
    local ret = {}
    for k,x in pairs(v) do
        ret[k] = M.copy(x)
    end
    return ret
end

return M
