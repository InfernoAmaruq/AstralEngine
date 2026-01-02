local OgTex = lovr.graphics.newTexture
local OgPass = lovr.graphics.newPass

local RefToRebuild = setmetatable({}, { __mode = "v" })

local TOSTRING = function(self)
    return "Wrapped "..(self.__IsPass and "pass" or "texture")..": "..tostring(self[1])
end

local function CAPTURE(t,...)
    local Val = t[1]
    local NEXTCALL = t[".NEXTCALL"]
    return NEXTCALL(Val,...)
end

local function IDX(t,k)
    local Og = t[1]
    local Val = Og and Og[k]
    if rtype(Val) == "function" then
        rawset(t,".NEXTCALL",Val)
        return CAPTURE
    end
    return Val or rawget(t,k)
end

local function MakeRef(Value, Capture, Pass)
    return setmetatable({ [1] = Value, __CAPTURE = Capture, __IsPass = Pass }, {
        __index = IDX, __tostring = TOSTRING
    })
end

@execute<UNSAFE>{
    local System = lovr.system.getOS()
    if System == "Windows" || System == "macOS" then
        return ""
    elseif System == "Linux" then
        return [[
            local OgResize = lovr.system.setWindowSize
            local LastResize = 0
            lovr.system.setWindowSize = function(x,y)
                local CurX, CurY = lovr.system.getWindowDimensions()
                if (CurX < x || CurY < y) && os.clock() - LastResize > 0.005 then
                    LastResize = os.clock()
        print("WARNING: RESIZING TO A LARGER SCREEN SIZE IS DANGEROUS ON LINUX\nCALL THE COMMAND AGAIN TO CONFIRM\nIT IS RECOMMENDED TO RESIZE VIA RESTART")
        return
                end
        OgResize(x, y)
            end
        ]]
    end
    return "lovr.system.setWindowSize = nil"
}

lovr.graphics.newPass = function(...)
    local CAPTURE = MakeRef(OgPass(...), { ... }, true)
    table.insert(RefToRebuild, CAPTURE)
    return CAPTURE
end

lovr.graphics.newTexture = function(...)
    local CAPTURE = MakeRef(OgTex(...), { ... }, false)
    table.insert(RefToRebuild, CAPTURE)
    return CAPTURE
end

AstralEngine.Graphics = {
    NewRawPass = OgPass,
    NewRawTexture = OgTex,
    NewTexture = lovr.graphics.newTexture,
    NewPass = lovr.graphics.newPass,
}

function AstralEngine.Window.__WindowResizedPasses(...)
    for _,v in pairs(RefToRebuild) do
        if v.ResizeCallback then
            v.ResizeCallback(v,v.IsPass,...)
        end
    end
end

return nil
