local Table = {}

Table.__NAME = "table"
Table.__PRO = function()
    return table
end

local OgUnpack = unpack
runpack = OgUnpack
unpack = function(t, i, j)
    local mt = debug.getmetatable(t)
    local UnpackField = mt and mt.__unpack
    if UnpackField then
        local t = rtype(UnpackField)
        if t == "function" then
            return UnpackField(t, i, j)
        else
            return t == "table" and unpack(UnpackField, i, j) or UnpackField
        end
    end
    return OgUnpack(t, i, j)
end

local temp = require("TableAlloc")
table.alloc = temp.Alloc
debug.getaddress = temp.GetPtr

local mt = { __mode = "k" }
local TSizes = setmetatable({}, mt)
local Types = setmetatable({}, mt)

local ArrayMeta = {}
ArrayMeta.__index = function(self, k)
    if k == "Size" then
        return TSizes[self]
    end
    if type(k) ~= "number" then
        error("Attempt to index array with non-numeric value", 2)
    end
    if k < 1 or k > TSizes[self] then
        error("Attempt to index invalid array key: " .. k, 2)
    end

    return rawget(self, k)
end
ArrayMeta.__newindex = function(self, k, v)
    if type(k) ~= "number" then
        error("Attempt to index array with non-numeric value")
    end
    if k < 1 or k > TSizes[self] then
        error("Attempt to index invalid array key:", k)
    end
    if not rawget(self, "Type") then
        Types[self] = type(v)
    end
    rawset(self, k, v)
end
ArrayMeta.__tostring = function(self)
    local ToStr = "array "
    local Size = TSizes[self]
    local Type = Types[self]

    local SizeStr = "(" .. Size .. ")"
    Type = Type and "{" .. Type .. "}" or ""

    local Cont
    if #self <= 10 and #self > 0 then
        Cont = "["
        for i, v in ipairs(self) do
            Cont = Cont .. tostring(v) .. (i == #self and "" or ",")
        end
        Cont = Cont .. "]"
    elseif #self > 0 then
        Cont = "[Too large]"
    else
        Cont = ""
    end

    return ToStr .. SizeStr .. Type .. Cont .. ": " .. debug.getaddress(self)
end
ArrayMeta.__array = true

function table.array(...)
    local Args = { ... }

    if #Args > 1 then
        return table.array(Args)
    end
    local V1 = Args[1]

    if not V1 then
        error("Cannot allocate array if no size is provided!")
    end
    local VT = type(V1)

    local Type
    local Size = VT == "number" and V1 or nil
    if not Size and VT == "table" then
        Size = #V1
    end
    if not Type and VT == "table" then
        local BasicType = nil
        for _, v in ipairs(V1) do
            local VALTYPE = type(v)
            if not BasicType then
                BasicType = VALTYPE
                Type = VALTYPE
            elseif BasicType ~= VALTYPE then
                error("Table contains different types!")
            end
        end
    end
    if not Size then
        error("Invalid value passed to array")
    end

    local Array = table.alloc(Size, 0)
    TSizes[Array] = Size
    Types[Array] = Type
    if VT == "table" then
        for _, v in pairs(V1) do
            Array[#Array + 1] = v
        end
    end
    setmetatable(Array, ArrayMeta)
    return Array
end

table.unpack = unpack
table.find = function(Haystack, Needle, Cmp)
    for i, v in pairs(Haystack) do
        if Cmp and Cmp(v, Needle) or v == Needle then
            return i
        end
    end
end

table.foreach = function(list, callback, itype)
    local f = itype and ipairs or pairs
    local r = {}
    for i, v in f(list) do
        r[i] = callback(i, v)
    end
    return r
end

return Table
