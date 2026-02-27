local A = {}

print("HELLO WORLD!")
print("I AM MAIN.LUA TEST FILE, I EXIST IN:", lovr.filesystem.getCurrentPath())

print("LOAD:", "test2.lua")
local File2 = loadfile("test2.lua")
print(File2, pcall(File2))
print(require("test2"))

return A
