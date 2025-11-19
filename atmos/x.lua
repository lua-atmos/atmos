local M = {}

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
                vs = vs .. xtostring(x)
            else
                vs = vs .. k .. '=' .. xtostring(x)
            end
            fst = false
        end
        --local tag = v.tag and (':'..v.tag..' ') or ''
        return --[[tag ..]] "@{" .. vs .. "}"
    end
end

function M.print (...)
    local ret = {}
    for i=1, select('#', ...) do
        ret[#ret+1] = xtostring(select(i, ...))
    end
    print(table.unpack(ret))
end

function M.copy (v)
    if type(v) ~= 'table' then
        return v
    end
    local ret = {}
    for k,x in pairs(v) do
        ret[k] = xcopy(x)
    end
    return ret
end

return M
