local Obj1 = 1

return {
    [Obj1] = {
        Name = "Obj1",
        Parent = RES["FLDR"],
        Components = {
            Transform = {
                Position = Vec3(0, -2, -1),
            },
            Shape = {
                Color = color.Red,
                Size = Vec3(10, 1, 10),
            },
        },
    },
    [RES["BALL"]] = {
        Name = "Obj2",
        Parent = RES["FLDR"],
        Components = {
            Transform = {
                Rotation = Vec3(0, 45, 45),
                Position = Vec3(-3, -0.7, -4),
            },
            Shape = {
                Shape = ENUM.ShapeType.Sphere,
                Color = color.fromHex("#0000ff99"),
                Size = Vec3(0.5, 0.5, 0.5),
            },
        },
    },
    [3] = {
        Name = "Obj3",
        Parent = Obj1,
    },
}
