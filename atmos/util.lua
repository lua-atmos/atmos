function trim (s)
    return (s:gsub("^%s*",""):gsub("\n%s*","\n"):gsub("%s*$",""))
end

function assertn (n, cnd, err)
    if n > 0 then
        n = n + 1
    end
    if not cnd then
        error(err, n)
    end
    return cnd
end

function totable (...)
    local t = {}
    local n = select('#',...) / 2
    assert((n*2) == select('#',...))
    for i=1, n do
        t[select(i,...)] = select(i+n,...)
    end
    return t
end
