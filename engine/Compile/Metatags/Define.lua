local SharedMem = select(1, ...)
local Define = {}

SharedMem.DEFINED = {}

function meta.setdefined(z, f, v)
    z = z or "_G"
    if not v then
        v = nil
    end
    SharedMem.DEFINED[z] = SharedMem.DEFINED[z] or {}
    SharedMem.DEFINED[z][f] = v
end

function meta.getdefined(z, f)
    z = z or "_G"
    return SharedMem.DEFINED[z] and SharedMem.DEFINED[z][f] or nil
end

meta.defined = SharedMem.DEFINED

Define.Priority = 1
Define.Tag = "define"
function Define.PARSE(Blk)
    local Context = Blk.Context or "_G"
    if Context == "" then
        Context = "_G"
    end
    SharedMem.DEFINED[Context] = SharedMem.DEFINED[Context] or {}
    for _, v in ipairs(Blk.Body) do
        local VAL = true
        if v:sub(1, 1) == "!" then
            v = v:sub(2)
            VAL = nil
        end
        SharedMem.DEFINED[Context][v] = VAL
        print("DEFINED:", Context, v, VAL)
    end
    return nil
end

return Define
