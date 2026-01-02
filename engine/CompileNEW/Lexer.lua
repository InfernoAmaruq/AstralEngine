local Lexer = {}

local DIRS = {}
local Keywords = {}

local LANGUAGE, DIRECTIVE_CALLBACK

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

function Lexer.ExtractDirectives(Src)
    if not LANGUAGE then
        error("NO LANGUAGE SET FOR DIRECTIVE EXTRACTION!")
    end

    local Directives = {}
    local Output = {}
    local Len = #Src
    local Idx = 1
    local State = "Code"
    local Quote

    local S1, S2 = LANGUAGE.Syntax.S1, LANGUAGE.Syntax.S2
    local SML1, SML2 = LANGUAGE.Syntax.SML1, LANGUAGE.Syntax.SML2
    local C, CML1, CML2 = LANGUAGE.Syntax.C, LANGUAGE.Syntax.CML1, LANGUAGE.Syntax.CML2

    local SMLLEN = SML1 and #SML1
    local CLEN = C and #C
    local CMLEN = CML1 and #CML1

    while Idx <= Len do
        local c = Src:sub(Idx, Idx)
        local ms = SMLLEN and Src:sub(Idx, Idx + SMLLEN)
        local com = CLEN and Src:sub(Idx, Idx + CLEN)
        local mlcom = CLEN and Src:sub(Idx, Idx + CMLEN)

        if not c then
            break
        end

        if State == "Code" then
            if c and (c == S1 or c == S2) then
                Quote = c
                State = "String"
                Output[#Output + 1] = c
            elseif ms and ms == SML1 then
                State = "MLString"
                Output[#Output + 1] = ms
                Idx = Idx + SMLLEN - 1
            elseif com and com == C then
                State = "Comment"
                Output[#Output + 1] = com
                Idx = Idx + CLEN - 1
            elseif mlcom and mlcom == CML1 then
                State = "MLComment"
                Output[#Output + 1] = mlcom
                Idx = Idx + CMLEN - 1
            elseif c == "@" then
                -- PRAGMA START
                -- no custom logic here, SAME syntax everywhere, thems the rules

                local s, e, n, cont, term = Src:find("@([%w_]+)%s*<?([^>{:]*)>?%s*([{:;])", Idx)
                local Determ = (term == ";" or term == ":") and "\n" or "}"
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
                        if term ~= ";" then
                            while J < Len and D > 0 do
                                local CJ = Src:sub(J, J)
                                if CJ == term then
                                    D = D + 1
                                elseif CJ == Determ or CJ == Determ2 then
                                    D = D - 1
                                end
                                J = J + 1
                            end
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
                        local v = DIRECTIVE_CALLBACK and DIRECTIVE_CALLBACK(Block, Src)

                        local Skip = false
                        if v == -1 or v == 0 then
                            Block.Discarded = true
                            v = Src:sub(s, J - 1)
                            Skip = v == 0
                        elseif v == -2 then
                            error("Unknown directive '" .. Src:sub(s, J - 1) .. "'! Manually dropped via callback")
                        elseif not v then
                            v = ("<%s=%d>"):format(n, #Directives)
                        end

                        if not Skip then
                            Directives[#Directives + 1] = Block
                            Output[#Output + 1] = v
                            Block.Identifier = v
                        end
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
            if ms and ms == SML2 then
                Output[#Output + 1] = SML2:sub(1, #SML2 - 1)
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
            if mlcom and mlcom == CML2 then
                Output[#Output + 1] = CML2:sub(1, #CML2 - 1)
                Idx = Idx + 1
                State = "Code"
            end
        end
        Idx = Idx + 1
    end

    return Directives, table.concat(Output)
end

function Lexer.SetCallback(c)
    DIRECTIVE_CALLBACK = c
end

function Lexer.SetLanguage(l)
    LANGUAGE = l
end

return Lexer
