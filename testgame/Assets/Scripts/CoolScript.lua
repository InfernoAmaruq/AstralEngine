print("RESERVE:", RES, RES["FLDR"])
print("Hello world 2")

local FLDR = RES["FLDR"]

for i in FLDR:IterChildren() do
    print("HAS CHILDREN:", i)
end
