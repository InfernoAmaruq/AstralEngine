local A = {}

print("HELLO WORLD!")
print("I AM MAIN.LUA TEST FILE, I EXIST IN:", lovr.filesystem.getCurrentPath())

print("time to mount MYSELF!")

local Extract = AstralEngine.Filesystem.Extractor
local ExtractedPath = Extract.Extract("LAF/TESTZIP.zip")

print("ExtractedPath:", ExtractedPath)

local MOUNT, e = lovr.filesystem.mount(ExtractedPath, "TESTING")
print(MOUNT, e)
local FILE = loadfile("TESTING/TESTFILE_ZIP_2.lua")
print("CALL FILE")
print(FILE, pcall(FILE))
print("END CALL")

print("end")

return A
