local ShaderService = {}

function ShaderService.NewShader(Type, Data)
    local Files = Data.Files
    local Defines = Data.Defines or nil
end

function ShaderService.NewBytecode(Type, Data) end

GetService.AddService("ShaderService", ShaderService)
return ShaderService
