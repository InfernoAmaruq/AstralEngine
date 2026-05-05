local Data = {}

Data.__BOUND = {}
Data.__USEDNAMES = {}
Data.__SortedArray = {}

local function SORT()
    local SortedArray = Data.__SortedArray
    for i in pairs(SortedArray) do
        SortedArray[i] = nil
    end

    for _, PRIGROUP in pairs(Data.__BOUND) do
        for _, BIND in pairs(PRIGROUP) do
            if #BIND.C == 1 then
                local Key = BIND.C[1]
                SortedArray[Key] = SortedArray[Key] or {}
                SortedArray[Key][#SortedArray[Key] + 1] = BIND.F
            else
                for _, Key in pairs(BIND.C) do
                    SortedArray[Key] = SortedArray[Key] or {}
                    SortedArray[Key][#SortedArray[Key] + 1] = BIND.F
                end
            end
        end
    end
end

function Data.Bind(NAME, PRIORITY, FUNC, Conf, ...)
    if Data.__USEDNAMES[NAME] then
        return
    end

    local ConfT = type(Conf)
    local Contextless = (ConfT == "table" and Conf.Contextless)
        or (ConfT == "string" and Conf:find("Contextless"))
        or false
    local IsConf = ConfT == "string" or ConfT == "table"

    Data.__USEDNAMES[NAME] = PRIORITY

    local TABLE = {
        N = NAME,
        P = PRIORITY,
        F = FUNC,
        C = { not IsConf and Conf or nil, ... },
    }

    Data.__BOUND[PRIORITY] = Data.__BOUND[PRIORITY] or {}
    Data.__BOUND[PRIORITY][NAME] = TABLE

    if _G.CONTEXT and not Contextless then
        _G.CONTEXT:BindToContext("CASBinds", NAME)
    end

    SORT()
end

function Data.__RawUnbind(NAME)
    if not Data.__USEDNAMES[NAME] then
        return
    end
    Data.__BOUND[Data.__USEDNAMES[NAME]][NAME] = nil
    Data.__USEDNAMES[NAME] = nil

    SORT()
end

function Data.Unbind(NAME)
    if not Data.__USEDNAMES[NAME] then
        return
    end
    Data.__BOUND[Data.__USEDNAMES[NAME]][NAME] = nil
    Data.__USEDNAMES[NAME] = nil

    if _G.CONTEXT then
        _G.CONTEXT:UnbindFromContext("CASBinds", NAME)
    end

    SORT()
end

local Native = require("CASNATIVE")
Native.Init(Data.__SortedArray)

Data.__CALL = Native.Call

GetService.AddService("ContextActionService", Data)

return Data
