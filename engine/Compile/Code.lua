local Code = {}

local Meta = {}
Code.Meta = Meta

local Sorted = {}

function Code.AttachDirective(d)
    Meta[d.Tag] = d
    local Priority = d.Priority or 1
    Sorted[d.Tag] = Priority
end

local SharedMemory
function Code.LoadMemory(m)
    SharedMemory = m
end

local SplitSymbol = "NOSPLIT"
function Code.SetSplitSymbol(s)
    SplitSymbol = s
end

function Code.Translate(Src, Dirs, N)
    table.sort(Dirs, function(a, b)
        local pa = Sorted[a.Type] or 1
        local pb = Sorted[b.Type] or 1
        return pa < pb
    end)

    for _, v in ipairs(Dirs) do
        if v.Type then
            local Type = Meta[v.Type]
            if Type then
                local Replacement = Type.PARSE(v, Src, N) or ""
                Src = Src:gsub(("<%s=%d>"):format(v.Type, v.Id), Replacement)
            end
        end
    end
    return Src
end

return Code
