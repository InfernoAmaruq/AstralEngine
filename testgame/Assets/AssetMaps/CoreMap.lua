return {
    [RES["CAMERA"]] = {
        Name = "WorldCam",
        Components = {
            Transform = {},
            Camera = { FOV = math.rad(90), DrawToScreen = true, NearestSampler = true },
        },
    },
    [1] = {
        Name = "Skybox",
        Components = {
            Skybox = {
                Texture = AstralEngine.Graphics.NewTexture("../Img/Skybox.jpg"),
            },
        },
    },
}
