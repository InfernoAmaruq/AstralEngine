local ShaderService = {}

local ShaderType = Enum({
    Compute = 1,
    Graphics = 2,
}, "ShaderType")

local ShaderPath = { "Engine/Services/Render/Shaders/", "GAMEFILE/Assets/Shaders/" }

local Normalize = lovr.filesystem.normalize
local IsFile = lovr.filesystem.isFile
local Read = lovr.filesystem.read

local function ResolvePath(File, LocalPath)
    -- try shaders

    for _, ToSearch in ipairs(ShaderPath) do
        local Shader = Normalize(ToSearch .. File)
        if IsFile(Shader) then
            return Shader
        end
    end

    -- try local
    local Local = Normalize(LocalPath .. "/" .. File)
    if IsFile(Local) then
        return Local
    end

    -- try global
    local Global = Normalize(File)
    if IsFile(Global) then
        return Global
    end
end

local function ResolveFile(File, IncludedFiles, ErrDepth)
    IncludedFiles = IncludedFiles or { [File] = true }
    ErrDepth = ErrDepth or 6

    local Content = Read(File)

    local LocalPath = AstralEngine.Filesystem.FolderFromPath(File)

    Content = Content:gsub("#pragma%s+[^\n]+", function(Match)
        -- kill the pragma

        local Pragma = Match:match("%S+%s+(.*)")
        if Pragma == "once" then
            IncludedFiles[File] = true
        else
            AstralEngine.Error("Unknown pragma in shader file: " .. File .. " '" .. Pragma .. "'", "Shader", ErrDepth)
        end

        return ""
    end)

    Content = Content:gsub("#include%s+[^\n]+", function(Match)
        local Target = Match:match("%S+%s+(.*)")

        local Open, Cont = Target:match("^(<)(.-)>$")
        if not Open then
            Open, Cont = Target:match('^(")(.-)"$')
        end

        if not Open then
            AstralEngine.Error(
                "Malformed file inclusion in file: " .. File .. ". Tried to include: " .. Target,
                "Shader",
                ErrDepth
            )
        end

        local PathTo = ResolvePath(Cont, LocalPath)
        if not PathTo then
            AstralEngine.Error("Failed inclusion of file " .. Cont .. " - Not found", "Shader", ErrDepth)
        elseif PathTo == File then
            AstralEngine.Error("Cannot link itself. Attempt to link file to itself in Shader", "Shader", ErrDepth)
        end

        local Include = ResolveFile(PathTo, IncludedFiles, ErrDepth + 1)

        Include = string.format('\n#line 1 "%s"\n', Cont) .. Include

        return Include
    end)

    return Content
end

local ShaderCodes = {
    unlit = true,
    normal = true,
    font = true,
    cubemap = true,
    equirect = true,
    fill = true,
}

local function GetShaderCode(SourceFile, Defines, CallerPath)
    local ShaderCode = ""

    if ShaderCodes[SourceFile] then
        return SourceFile
    end

    local Code = ResolveFile(ResolvePath(SourceFile, CallerPath))

    local VerStr
    Code = Code:gsub(
        "^#version%s+(%d+)\n",
        function(v) -- glsl wants versions to be always first, so we gotta do that manually
            VerStr = v
            return ""
        end
    )

    if VerStr then
        ShaderCode = "#version " .. VerStr .. "\n"
    end

    if Defines then
        ShaderCode = ShaderCode .. "//INJECTED DEFINES\n"
        for Define, Value in pairs(Defines) do
            if type(Define) == "number" then
                ShaderCode = ShaderCode .. string.format("#define %s\n", tostring(Value))
            else
                ShaderCode = ShaderCode .. string.format("#define %s %s\n", tostring(Define), tostring(Value))
            end
        end
        ShaderCode = ShaderCode .. "//CODE\n"
    end

    ShaderCode = ShaderCode .. Code

    return ShaderCode
end

function ShaderService.NewShader(Type, Shader1, Shader2, Data)
    if not Data and type(Shader2) == "table" then
        Data = Shader2
    end

    local Raw = Data and Data.Raw or false
    local Label = Data and Data.Label or "AstralShader"
    local Flags = Data and Data.Flags or nil

    local LovrData = { raw = Raw, label = Label, flags = Flags }
    local LovrShader = nil

    local Caller = AstralEngine.Filesystem.FolderFromPath(AstralEngine.Filesystem.GetCurrentPath(2))

    if Type == ShaderType.Compute then
        local Code = GetShaderCode(Shader1, Data and Data.Defines, Caller)

        LovrShader = lovr.graphics.newShader(Code, LovrData)
    elseif Type == ShaderType.Graphics then
        local NoShader2 = false
        if type(Shader2) ~= "string" then
            NoShader2 = true
            Data = Shader2
            Shader2 = Shader1
        end

        local Defines = Data and Data.Defines
        local DefineVertex = Defines and Defines.Vertex
        local DefineFragment = Defines and Defines.Fragment

        local CodeVertex = GetShaderCode(Shader1, DefineVertex, Caller)
        local CodeFragment
        if NoShader2 then
            CodeFragment = CodeVertex
        else
            CodeFragment = GetShaderCode(Shader2, DefineFragment, Caller)
        end

        LovrShader = lovr.graphics.newShader(CodeVertex, CodeFragment, LovrData)
    end

    return LovrShader
end

GetService.AddService("ShaderService", ShaderService)

return ShaderService
