local DLLPath = "TableAlloc.so"
print("AT:", DLLPath)
print(AstralEngine.Filesystem.IsFile(DLLPath))
local ExtractedPath = AstralEngine.Filesystem.Extractor.Extract(DLLPath)

print("OPEN LIB:", DLLPath)
local Package = require(DLLPath)
print(Package, "GOT PACKAGE")
for i, v in pairs(Package) do
    print(i, v)
end

local Retry = require(DLLPath)
print(Retry, Package)
