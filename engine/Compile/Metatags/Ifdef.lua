local SharedMem = select(1, ...)
local IfDef = {}

local Defined

IfDef.Priority = 2

local function Tokenize(Line)
    Line = Line:gsub("%s+", "")

    local Tokens = {}
    local Pos = 1

    while Pos <= #Line do
        local c = Line:sub(Pos, Pos)

        if c == "&" or c == "|" then
            table.insert(Tokens, c)
            Pos = Pos + 1
        elseif c == "!" then
            local NextField = Line:match("!([%w_%.]+)", Pos)
            if NextField then
                table.insert(Tokens, "!" .. NextField)
                Pos = Pos + #NextField + 1
            else
                Pos = Pos + 1
            end
        else
            local Field = Line:match("([%w_%.]+)", Pos)
            if Field then
                table.insert(Tokens, Field)
                Pos = Pos + #Field
            else
                Pos = Pos + 1
            end
        end
    end

    return Tokens
end

local function LogicEval(Values, Operators)
    local Collapsed = { Values[1] }
    local CollapsedOps = {}

    -- first resolve &
    for i, op in ipairs(Operators) do
        if op == "&" then
            local Lhs = table.remove(Collapsed)
            local Rhs = Values[i + 1]
            table.insert(Collapsed, Lhs and Rhs)
        else
            table.insert(Collapsed, Values[i + 1])
            table.insert(CollapsedOps, op)
        end
    end

    local Result = Collapsed[1]
    for i in ipairs(CollapsedOps) do
        local Rhs = Collapsed[i + 1]
        Result = Result or Rhs
    end

    return Result
end

IfDef.Tag = "ifdef"
function IfDef.PARSE(Blk)
    -- MOUNT DEFINED
    if not Defined then
        Defined = SharedMem.DEFINED
    end
    -- ACTUAL LOGIC

    local Parameters = Blk.Context
    if not Parameters or Parameters == "" or Parameters == " " then
        print("[IFDEF]: NO PROPPER STATEMENT FOR IFDEF")
        return
    end

    local Values = {}
    local LogicTokens = {}

    for _, FIELD in pairs(Tokenize(Parameters)) do
        if FIELD == "&" or FIELD == "|" then
            LogicTokens[#LogicTokens + 1] = FIELD
        else
            local Negate = FIELD:sub(1, 1) == "!"
            if Negate then
                FIELD = FIELD:sub(2)
            end

            local Table = "_G"
            local LookFor

            if FIELD:find("%.") then
                local temp = FIELD:split(".")
                Table = temp[1]
                LookFor = temp[2]
            else
                LookFor = FIELD
            end

            local v = Defined[Table] and Defined[Table][LookFor] or nil
            if Negate then
                v = not v
            end
            Values[#Values + 1] = v
        end
    end

    local Result = LogicEval(Values, LogicTokens)

    return Result and Blk.Raw or nil
end

return IfDef
