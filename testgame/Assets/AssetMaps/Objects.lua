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
            Collider = {
                Tag = "STATIC_DEFAULT",
                Kinematic = true,
            },
        },
    },
    [RES["BALL"]] = {
        Name = "Obj2",
        Parent = RES["FLDR"],
        Components = {
            Transform = {
                Rotation = Vec3(0, 45, 45),
                Position = Vec3(-3, 3, -4),
            },
            Shape = {
                Shape = ENUM.ShapeType.Sphere,
                Color = color.fromHex("#0000ff99"),
                Size = Vec3(3, 3, 3),
            },
            Collider = {
                Shape = GetService("Physics").Shapes.NewShape(ENUM.ColliderShape.Sphere),
            },
        },
    },
    [RES["HITBOX"]] = {
        Name = "Obj3",
        Parent = Obj1,
        Components = {
            Transform = {
                Position = Vec3(-3, 0, -4),
            },
            Shape = {
                Color = color.fromHex("#AAAA0044"),
                Size = Vec3(5, 0.25, 5),
            },
            Collider = {
                IsTrigger = true,
                Tag = "STATIC_DEFAULT",
            },
        },
    },
    [RES["WALL"]] = {
        Name = "Obj4",
        Components = {
            Transform = { Position = Vec3(0, 0, -10) },
            Shape = {
                Color = color.fromHex("#FF0000FF"),
                Size = Vec3(5, 5, 1),
            },
            Collider = {
                Tag = "STATIC_DEFAULT",
            },
        },
    },
}
