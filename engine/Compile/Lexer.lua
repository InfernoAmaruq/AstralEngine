local Lexer = {}

local DIRS = {}
local Keywords = {}

function Lexer.FSearch(Src)
    for _, v in ipairs(Keywords) do
        if Src:find(v) then
            return true
        end
    end
end

function Lexer.AttachDirective(Directive)
    table.insert(Keywords, Directive.Tag)
    DIRS[Directive.Tag] = Directive
end

local SplitSymbol = "NOSPLIT"
function Lexer.SetSplitSymbol(s)
    SplitSymbol = s
end

local MLCOMMENT = "--[[" --]]"

function Lexer.ExtractDirectives(Src)
    local Directives = {}
    local Output = {}
    local Len = #Src
    local Idx = 1
    local State = "Code"
    local Quote

    while Idx <= Len do
        local c = Src:sub(Idx, Idx)
        local nxt = Src:sub(Idx, Idx + 1)

        if State == "Code" then
            if c == '"' or c == '"' then
                Quote = c
                State = "String"
                Output[#Output + 1] = c
            elseif nxt == "[[" then
                State = "MLString"
                Output[#Output + 1] = nxt
                Idx = Idx + 1
            elseif nxt == "--" then
                if Src:sub(Idx, Idx + 3) == MLCOMMENT then
                    State = "MLComment"
                    Output[#Output + 1] = MLCOMMENT
                    Idx = Idx + 3
                else
                    State = "Comment"
                    Output[#Output + 1] = nxt
                    Idx = Idx + 1
                end
            elseif c == "@" then
                -- PRAGMA START

                local s, e, n, cont, term = Src:find("@([%w_]+)%s*<?([^>{:]*)>?%s*([{:])", Idx)
                local Determ = term == ":" and "\n" or "}"
                local Determ2 = term == ":" and ";" or nil

                local DIR = DIRS[n]
                local SPLITTER = DIR and DIR.SPLIT or ",\n"

                if s then
                    if DIR and DIR.LEX then
                        local Block, NewIdx = DIR.LEX(Src, s, e, cont, term)
                        if Block then
                            Directives[#Directives + 1] = Block
                        end
                        Idx = NewIdx or e + 1
                    else
                        local D, J = 1, e + 1
                        while J < Len and D > 0 do
                            local CJ = Src:sub(J, J)
                            if CJ == term then
                                D = D + 1
                            elseif CJ == Determ or CJ == Determ2 then
                                D = D - 1
                            end
                            J = J + 1
                        end

                        local Raw = Src:sub(e + 1, J - 2)
                        local Body =
                            Raw:gsub("[" .. SPLITTER .. "@]+", SplitSymbol):gsub("%s+", ""):match("^%s*(.-)%s*$")

                        if Body:sub(1, 4) == SplitSymbol then
                            Body = Body:sub(5)
                        end
                        if Body:sub(-4) == SplitSymbol then
                            Body = Body:sub(1, #Body - 4)
                        end

                        local Block = {
                            Type = n,
                            Body = Body:split(SplitSymbol),
                            Raw = Raw,
                            Context = cont,
                            Start = s,
                            Stop = e,
                            Id = #Directives + 1,
                        }
                        Directives[#Directives + 1] = Block
                        Output[#Output + 1] = ("<%s=%d>"):format(n, #Directives)
                        Idx = J - 1
                    end
                else
                    Output[#Output + 1] = c
                end
            else
                Output[#Output + 1] = c
            end
        elseif State == "String" then
            Output[#Output + 1] = c
            if c == "\\" then
                Idx = Idx + 1
                Output[#Output + 1] = Src:sub(Idx, Idx)
            elseif c == Quote then
                State = "Code"
            end
        elseif State == "MLString" then
            Output[#Output + 1] = c
            if nxt == "]]" then
                Output[#Output + 1] = "]"
                Idx = Idx + 1
                State = "Code"
            end
        elseif State == "Comment" then
            Output[#Output + 1] = c
            if c == "\n" then
                State = "Code"
            end
        elseif State == "MLComment" then
            Output[#Output + 1] = c
            if nxt == "]]" then
                Output[#Output + 1] = "]"
                Idx = Idx + 1
                State = "Code"
            end
        end
        Idx = Idx + 1
    end

    return Directives, table.concat(Output)
end

return Lexer
