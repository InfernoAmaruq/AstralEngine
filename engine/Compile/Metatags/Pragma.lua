local Pragma = {}

-- PRAGMA STACK
local PRAGMASTACK = {}
function meta.PRAGMA_S_PUSH(K, V)
    PRAGMASTACK[#PRAGMASTACK + 1] = { File = K, Pragma = V }
    if #PRAGMASTACK > 4 then
        repeat
            table.remove(PRAGMASTACK)
        until #PRAGMASTACK <= 4
    end
end

function meta.PRAGMA_S_POP()
    return table.remove(PRAGMASTACK)
end

function meta.PRAGMA_S_GETTOP()
    return #PRAGMASTACK
end

function meta.PRAGMA_S_PEEK()
    return PRAGMASTACK[#PRAGMASTACK]
end

-- PRAGMA FUNC STACK
local PRAGMAFSTACK = {}
function meta.PRAGMA_F_PUSH(f)
    PRAGMAFSTACK[#PRAGMAFSTACK + 1] = f
end

function meta.PRAGMA_F_POP()
    return table.remove(PRAGMAFSTACK)
end

function meta.PRAGMA_F_PEEK()
    return PRAGMAFSTACK[#PRAGMAFSTACK]
end

-- PRAGMA MAIN
Pragma.Priority = 10
Pragma.Tag = "pragma"
function Pragma.PARSE(Blk)
    return "--[[PRAGMA:" .. Blk.Raw .. "]]"
end

return Pragma
