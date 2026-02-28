local DLLPath = AstralEngine.Filesystem.FolderFromPath(AstralEngine.Filesystem.GetCurrentPath()) .. "TableAlloc.so"
print("AT:", DLLPath)
print(AstralEngine.Filesystem.IsFile(DLLPath))
local ExtractedPath = AstralEngine.Filesystem.Extractor.Extract(DLLPath)

print("OPEN LIB:", DLLPath)
local Package = package.loadlib(DLLPath)()
print(Package, "GOT PACKAGE")
for i, v in pairs(Package) do
    print(i, v)
end
