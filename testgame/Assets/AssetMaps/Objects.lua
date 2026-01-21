local Obj1 = 1

return {
    [Obj1] = {
        Name = "Obj1",
        Parent = RES["FLDR"],
    },
    [GID[100]] = {
        Name = "GLOBALOBJ",
    },
    [4] = {
        Name = "CHILD_OF_GLOBAL",
        Parent = GID[100],
    },
    [2] = {
        Name = "Obj2",
        Parent = RES["FLDR"],
    },
    [3] = {
        Name = "Obj3",
        Parent = Obj1,
    },
}
