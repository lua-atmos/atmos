function assertn (n, cnd, err)
    if n > 0 then
        n = n + 1
    end
    if not cnd then
        error(err, n)
    end
    return cnd
end
