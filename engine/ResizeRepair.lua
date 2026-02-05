local OgTex = lovr.graphics.newTexture
local OgPass = lovr.graphics.newPass
local FS = lovr.filesystem

local RefToRebuild = setmetatable({}, { __mode = "v" })

local TOSTRING = function(self)
    return "Wrapped " .. (self.__IsPass and "Pass" or "Texture") .. ": " .. debug.getaddress(self)
end

local function CAPTURE(t, ...)
    local Val = t[1]
    local NEXTCALL = t[".NEXTCALL"]
    return NEXTCALL(Val, ...)
end

local function IDX(t, k)
    local Og = t[1]
    local Val = Og and Og[k] or Og[k:sub(1, 1):lower() .. k:sub(2)]
    if rtype(Val) == "function" then
        rawset(t, ".NEXTCALL", Val)
        return CAPTURE
    end
    return Val or rawget(t, k)
end

local function ResolvePath(Path)
    if FS.isFile(Path) then
        return Path
    end
    local CallFrom = debug.getinfo(3, "S")
    local LocalizedPath = CallFrom.source:gsub("%@")

    return FS.normalize(FS.folderFromPath(LocalizedPath) .. Path)
end

local MT = { __index = IDX, __tostring = TOSTRING }

local function MakeRef(Value, Capture, Pass)
    return setmetatable({ [1] = Value, __CAPTURE = Capture, __IsPass = Pass }, MT)
end

lovr.graphics.newPass = function(...)
    local CAPTURE = MakeRef(OgPass(...), { ... }, true)
    table.insert(RefToRebuild, CAPTURE)
    return CAPTURE
end

lovr.graphics.newTexture = function(...)
    local ARGS
    if type(select(1, ...)) == "string" then
        ARGS = { ... }
        ARGS[1] = ResolvePath(ARGS[1])
    end
    local CAPTURE
    if ARGS then
        CAPTURE = MakeRef(OgTex(unpack(ARGS)), ARGS, false)
    else
        CAPTURE = MakeRef(OgTex(...), { ... }, false)
    end
    table.insert(RefToRebuild, CAPTURE)
    return CAPTURE
end

AstralEngine.Graphics = {
    NewRawPass = OgPass,
    NewRawTexture = function(...)
        local Args = { ... }

        if type(Args[1]) == "string" then
            Args[1] = ResolvePath(Args[1])
        end

        return OgTex(unpack(Args))
    end,
    NewTexture = lovr.graphics.newTexture,
    NewPass = lovr.graphics.newPass,
}

function AstralEngine.Window.__WindowResizedPasses(...)
    for _, v in pairs(RefToRebuild) do
        if v.ResizeCallback then
            v.ResizeCallback(v, v.__IsPass, ...)
        end
    end
end

return nil
