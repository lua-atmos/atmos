function totable (...)
    local t = {}
    local n = select('#',...) / 2
    assert((n*2) == select('#',...))
    for i=1, n do
        t[select(i,...)] = select(i+n,...)
    end
    return t
end
