local M = {}

-- task/tasks metatables are injected by `run.lua` to avoid a require cycle
local meta_task, meta_tasks

function M._metas (task, tasks)
    meta_task, meta_tasks = task, tasks
end

function M.is (v, x)
    if v == x then
        return true
    end
    local tp = type(v)
    local mt = getmetatable(v)
    if tp == x then
        return true
    elseif mt==meta_task and x=='task' then
        return true
    elseif mt==meta_tasks and x=='tasks' then
        return true
    elseif tp=='table' and type(x)=='string' and type(v.tag)=='string' then
        return M.gte(x, v.tag)
    else
        return M.gte(v, x)
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
    elseif ta=='number' and tb=='number' then
        return a >= b
    elseif ta=='string' and tb=='string' then
        return (string.find(b, '^'..a..'%.') == 1)
    elseif type(a) ~= 'table' then
        return false
    end
    for k,va in pairs(a) do
        if not M.gte(va,b[k]) then
            return false
        end
    end
    return true
end

function M.eq (a, b)
    return M.gte(a,b) and M.gte(b,a)
end

function M.xin (v, t)
    for x,y in iter(t) do
        if (type(x)~='number' and x==v) or (M.eq(y,v)) then
            return true
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
    for k,x in iter(v1) do
        ret[k] = x
    end
    local n = 1
    for k,x in iter(v2) do
        if k == n then
            ret[#ret+1] = x
            n = n + 1
        else
            ret[k] = x
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
