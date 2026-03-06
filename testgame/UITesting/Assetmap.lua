return {
    [RES["ROOT"]] = {
        Name = "TextFrame",
        Components = {
            Ancestry = {},
            UIRoot = {
                Size = {
                    Scale = vec2(1, 0),
                    Offset = vec2(0, 100),
                },
                Position = { Scale = vec2(0.5, 0.5) },
                AnchorPoint = vec2(0.5, 0.5),
            },
            UICanvas = {
                Color = color.fromRGBA(100, 100, 100, 255),
            },
        },
    },
    [2] = {
        Name = "TextObj",
        Components = {
            Ancestry = {},
            UIRoot = {
                Size = { Scale = vec2(0.3, 0.5) },
                Position = { Scale = vec2(0.5, 0.5) },
                AnchorPoint = vec2(0.5, 0.5),
            },
            UIText = {
                Color = color.fromRGB(255, 255, 255),
                Text = "Hello World",
            },
        },
        Parent = 1,
    },
}
