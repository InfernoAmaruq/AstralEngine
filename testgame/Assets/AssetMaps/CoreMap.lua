return {
    [1] = {
        Name = "WorldCam",
        Components = {
            Transform = {},
            Camera = { FOV = math.rad(90), DrawToScreen = true, NearestSampler = true },
        },
    },
    [2] = {
        Name = "Skybox",
        Components = {
            Skybox = {
                Texture = AstralEngine.Graphics.NewTexture("../Img/Skybox.jpg"),
            },
        },
    },
}
