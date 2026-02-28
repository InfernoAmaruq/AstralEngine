lovr.filesystem.setRequirePath(package.path)
local Normalize = lovr.filesystem.normalize

-- set cpath
local OgRequire = require
local OgLoadLib = package.loadlib
local OgLoadfile = function(Path, Env)
    local Raw = lovr.filesystem.read(Path)
    local f = Raw and loadstring(Raw, "@" .. (Normalize(Path) or Path)) or nil
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
    ".laf",
}

local CacheExtensionsToTry = {
    "",
    ".lua",
    ".aspr",
    "/init.lua",
    "/init.aspr",
    ".laf",
    package.clibtag,
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
                if e == "lua" or e == "aspr" or e == "laf" or e == package.clibtag:sub(2) then
                    return "." .. e
                else
                    return "/" .. ext
                end
            end)
        )
end

local function LoadLib(Path, EntryPoint)
    local Extract = lovr.filesystem.extractor.Extract(Path)
    local EP = EntryPoint
    if not EP then
        local Folder = lovr.filesystem.folderFromPath(Path)
        local Name = Path:gsub(Folder, "")
        EP = "luaopen_" .. Name:gsub("%..*$", "")
    end
    return OgLoadLib(Extract, EP)
end

local function LoadFile(Path, Env, STACK)
    local UseGlobalPath = false
    if Path:sub(1, 1) == "-" then
        Path = Path:sub(2)
        UseGlobalPath = true
    end
    Path = DotFix(Path)

    local Info, CurPath, CurDir
    if not UseGlobalPath then
        Info = debug.getinfo(STACK or 2, "S")
        CurPath = Info.source:sub(1, 1) == "@" and Info.source:sub(2) or Info.source
        CurDir = CurPath:match(Match)
    end

    local PathsToTry = {
        Path,
        CurDir and CurDir .. "/" .. Path or nil,
        not UseGlobalPath and "GAMEFILE/" .. Path or nil,
    }

    local Data
    local TruePath = Path
    for _, v in ipairs(PathsToTry) do
        v = v == Path and v or Normalize(v)
        for _, ext in ipairs(LoadExtensionsToTry) do
            local True = v .. ext

            if not lovr.filesystem.isFile(True) then
                continue
            end

            local F
            if True:sub(-3):lower() == "laf" and LAF then
                F = LAF.LoadArchive(True, nil, 3)
            else
                F = OgLoadfile(True, Env)
            end

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

local NEXT_CONTEXTUAL

local Methods = {
    function(Path, ...)
        -- cache fetch
        Path = DotFix(Path)

        local Info = debug.getinfo(3, "S")
        local CurPath = Info.source:sub(1, 1) == "@" and Info.source:sub(2) or Info.source
        local CurDir = CurPath:match(Match)
        local PathsToTry = {
            Path,
            CurDir and CurDir .. "/" .. Path or "",
            "GAMEFILE/" .. Path,
            _G.package.ENG_PATH .. Path,
            _G.package.GAME_PATH .. Path,
        }
        for _, v in ipairs(PathsToTry) do
            for _, ext in ipairs(CacheExtensionsToTry) do
                local c = v == Path and v .. ext or Normalize(v .. ext)
                if c and package.loaded[c] then
                    return true, (package.loaded[c] and unpack(package.loaded[c]))
                end
            end
        end
    end,
    function(Path, ...)
        --  try loadfile
        if Path:find(package.clibtag) then
            return false
        end
        local f, TruePath = LoadFile(Path, nil, 4)
        if f then
            local Canon = TruePath
            if type(f) == "function" then
                package.loaded[Canon] = { f(...) }
            else
                package.loaded[Canon] = { f }
            end
            if _G.CONTEXT and NEXT_CONTEXTUAL then
                _G.CONTEXT:BindToContext("Require", package.loaded[Canon], Canon)
            end
            return true, unpack(package.loaded[Canon])
        end
    end,
    function(Path, ...)
        -- C lib?
        local Info = debug.getinfo(3, "S")
        local CurPath = Info.source:sub(1, 1) == "@" and Info.source:sub(2) or Info.source
        local CurDir = CurPath:match(Match)

        local Canon = Path

        local old = package.cpath
        if CurDir then
            -- since LoadFile failed, we could be trying for a c lib
            --[[local OSP = lovr.filesystem.getRealDirectory(CurPath)
            local PhysPath = OSP .. "/" .. CurDir .. "/"
            local TryPath = PhysPath .. Path .. package.clibtag
            local List = DotFix(Path):split("/")
            local Name = List[#List]
            local Lib = package.loadlib(TryPath, "luaopen_" .. Name)
            if Lib and type(Lib) == "function" then
                local a, b, c, d, e = Lib()
                package.loaded[Canon] = { a, b, c, d, e }
                if _G.CONTEXT and NEXT_CONTEXTUAL then
                    _G.CONTEXT:BindToContext("Require", package.loaded[Canon], Canon)
                end
                return true, a, b, c, d, e
            end]]

            -- nts: try all paths

            local Normalized = Normalize(CurDir .. "/" .. Path)
            local ToTry = {
                Path,
                Path .. package.clibtag,
                Normalized,
                Normalized .. package.clibtag,
            }

            for _, v in pairs(ToTry) do
                if lovr.filesystem.isFile(v) then
                    local Lib = package.loadlib(v)
                    if Lib then
                        local Grab = { Lib(...) }
                        package.loaded[v] = Grab

                        if _G.CONTEXT and NEXT_CONTEXTUAL then
                            _G.CONTEXT:BindToContext("Require", package.loaded[v], v)
                        end

                        return true, unpack(Grab)
                    end
                end
            end
        end

        -- its over try og require?
        local a = { OgRequire(Path) }
        package.cpath = old
        if a then
            package.loaded[Canon] = a
            if _G.CONTEXT and NEXT_CONTEXTUAL then
                _G.CONTEXT:BindToContext("Require", package.loaded[Canon], Canon)
            end
            return true, unpack(a)
        end
    end,
}

local function RequireNoCtx(Path, ...)
    for _, v in ipairs(Methods) do
        local s, a, b, c, d, e = v(Path, ...)
        if s then
            return a, b, c, d, e
        end
    end
end

_G.require_noctx = RequireNoCtx

local function Require(Path, ...)
    NEXT_CONTEXTUAL = true
    for _, v in ipairs(Methods) do
        local s, a, b, c, d, e = v(Path, ...)
        if s then
            NEXT_CONTEXTUAL = false
            return a, b, c, d, e
        end
    end
    NEXT_CONTEXTUAL = false
end

return { LoadFile, Require, LoadLib }
