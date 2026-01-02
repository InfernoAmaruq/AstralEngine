local LBMF = {}

local Data = {}

local Pre = "local GREF = select(1,...);"

local function Parse(Raw)
    return (Pre .. "return {" .. Raw .. "}")
end

local EMPTY = { select = _G.select }

function Data.FromPath(Path)
    local Raw = lovr.filesystem.read(Path)
    if Raw then
        local f, err = loadstring(Parse(Raw), "LBMFFILE:" .. Path)
        return f and setfenv(f, EMPTY)(_G) or (print("LBMF READING ERROR:", err) or nil)
    end
    return nil
end

function Data.RawToTable() end

LBMF.__NAME = "LBMF"
LBMF.__PRO = function()
    return Data
end

return LBMF
