function assertx(cur, exp)
    return assert(cur == exp, cur)
end

local OUT = ""
function out (...)
    if select('#',...) == 0 then
        local ret = OUT
        OUT = ""
        return ret
    else
        for i=1, select('#',...) do
            if i>1 then
                OUT = OUT .. '\t'
            end
            OUT = OUT .. tostring(select(i,...))
        end
        OUT = OUT .. '\n'
    end
end
