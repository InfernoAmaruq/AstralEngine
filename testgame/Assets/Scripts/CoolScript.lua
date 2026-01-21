print("RESERVE:", RES, RES["FLDR"])
print("Hello world 2")

local FLDR = RES["FLDR"]
local CAMERA = RES["CAMERA"]

local GLOBAL_OBJ = GetService("Entity").GetEntityFromId(100)

for i in FLDR:IterChildren() do
    print("HAS CHILDREN:", i)
end

for i in GLOBAL_OBJ:IterChildren() do
    print("GLOBAL:", i)
end

if not CAMERA then
    return
end

local Transform = CAMERA.Transform
print(CAMERA, Transform)
