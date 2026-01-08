local OgTex = lovr.graphics.newTexture
local OgPass = lovr.graphics.newPass

local RefToRebuild = setmetatable({}, { __mode = "v" })

local TOSTRING = function(self)
    return "Wrapped " .. (self.__IsPass and "pass" or "texture") .. ": " .. tostring(self[1])
end

local function CAPTURE(t, ...)
    local Val = t[1]
    local NEXTCALL = t[".NEXTCALL"]
    return NEXTCALL(Val, ...)
end

local function IDX(t, k)
    local Og = t[1]
    local Val = Og and Og[k]
    if rtype(Val) == "function" then
        rawset(t, ".NEXTCALL", Val)
        return CAPTURE
    end
    return Val or rawget(t, k)
end

local function MakeRef(Value, Capture, Pass)
    return setmetatable({ [1] = Value, __CAPTURE = Capture, __IsPass = Pass }, {
        __index = IDX,
        __tostring = TOSTRING,
    })
end

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
    for _, v in pairs(RefToRebuild) do
        if v.ResizeCallback then
            v.ResizeCallback(v, v.IsPass, ...)
        end
    end
end

return nil
