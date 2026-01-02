lovr.filesystem.setRequirePath(package.path)

local OgRequire = require
local OgLoadfile = function(Path, Env)
    local Raw = lovr.filesystem.read(Path)
    local f = Raw and loadstring(Raw, Path) or nil
    return (f and Env) and setfenv(f, Env) or f
end
local Match = "^(.*)/[^/]+$"

local ext = package.cpath:match("%.dll") and ".dll" or package.cpath:match("%.so") and ".so" or nil
package.clibtag = ext or ""

local LoadExtensionsToTry = {
    "",
    ".lua",
    ".aspr",
    "/init.lua",
    "/init.aspr",
    ".lbmf",
}

function _G.__BOOT.REQUIRELIB_OVERRIDE(Type, Func)
    if Type == "require" then
        OgRequire = Func
    elseif Type == "loadfile" then
        OgLoadfile = Func
    end
end

local function DotFix(s)  -- fix Lua's dot indexing so require("Folder.Script") works
    return s:find("/") and s -- if we see a /, we assume it's already proper, so we just ignore it. CANNOT have it mixed
        or (
            s:gsub("%.(%w+)", function(ext)
                local e = ext:lower()
                if e == "sol" or e == "lua" or e == "aspr" or e == "lbmf" then
                    return "." .. e
                else
                    return "/" .. ext
                end
            end)
        )
end

local function Normalize(Path)
    if not Path:find("%.%./") and not Path:find("/%.") then
        return Path
    end

    local Parts = {}
    for Part in Path:gmatch("[^/]+") do
        if Part == ".." then
            table.remove(Parts)
        elseif Part ~= "." then
            Parts[#Parts + 1] = Part
        end
    end
    return table.concat(Parts, "/")
end

local function LoadFile(Path, Env, STACK)
    Path = DotFix(Path)
    local Info = debug.getinfo(STACK or 2, "S")
    local CurPath = Info.source:sub(1, 1) == "@" and Info.source:sub(2) or Info.source
    local CurDir = CurPath:match(Match)

    local PathsToTry = {
        Path,
        "GAMEFILE/" .. Path,
        CurDir and CurDir .. "/" .. Path or nil,
    }

    local Data
    local TruePath = Path
    for _, v in ipairs(PathsToTry) do
        v = v == Path and v or Normalize(v)
        for _, ext in ipairs(LoadExtensionsToTry) do
            local True = v .. ext
            local F = (ext == ".lbmf" and LBMF) and LBMF.FromPath(True) or OgLoadfile(True, Env)
            if F then
                Data = F
                TruePath = True
                break
            end
        end
        if Data then
            break
        end
    end

    return Data, TruePath
end

local function Canonical(Path)
    local RealDir = lovr.filesystem.getRealDirectory(Path)
    if not RealDir then
        return Path
    end
    return (RealDir .. "/" .. Path):gsub("//+", "/")
end

local Methods = {
    function(Path, ...)
        Path = DotFix(Path)
        local Info = debug.getinfo(3, "S")
        local CurPath = Info.source:sub(1, 1) == "@" and Info.source:sub(2) or Info.source
        local CurDir = CurPath:match(Match)
        local PathsToTry = {
            Path,
            "GAMEFILE/" .. Path,
            CurDir and CurDir .. "/" .. Path or nil,
        }
        for _, v in ipairs(PathsToTry) do
            for _, ext in ipairs(LoadExtensionsToTry) do
                local c = Canonical(v == Path and v .. ext or Normalize(v .. ext))
                if c and package.loaded[c] then
                    return true, package.loaded[c]
                end
            end
        end
    end,
    function(Path, ...)
        local f, TruePath = LoadFile(Path, nil, 4)
        if f then
            local Canon = Canonical(TruePath)
            if type(f) == "function" then
                package.loaded[Canon] = f(...)
            else
                package.loaded[Canon] = f
            end
            return true, package.loaded[Canon]
        end
    end,
    function(Path, ...)
        local Info = debug.getinfo(3, "S")
        local CurPath = Info.source:sub(1, 1) == "@" and Info.source:sub(2) or Info.source
        local CurDir = CurPath:match(Match)

        local Canon = Canonical(Path)

        local old = package.cpath
        if CurDir then
            -- since LoadFile failed, we could be trying for a c lib
            local OSP = lovr.filesystem.getRealDirectory(CurPath)
            local PhysPath = OSP .. "/" .. CurDir .. "/"
            local TryPath = PhysPath .. Path .. package.clibtag
            local Lib = package.loadlib(TryPath, "IMPORTED LIB: <" .. TryPath .. ">")
            if Lib and type(Lib) == "function" then
                local Extract = Lib()
                package.loaded[Canon] = Extract
                return true, Extract
            end
            -- loadlib failed, try require
            package.cpath = package.cpath .. ";" .. PhysPath .. "?" .. package.clibtag
        end

        local f = OgRequire(Path)
        package.cpath = old
        if f then
            package.loaded[Canon] = f
            return true, f
        end
    end,
}

local function Require(Path, ...)
    for _, v in ipairs(Methods) do
        local s, r = v(Path, ...)
        if s then
            return r
        end
    end
end

return { LoadFile, Require }
