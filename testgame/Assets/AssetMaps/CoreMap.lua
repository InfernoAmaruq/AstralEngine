return {
    [RES["CAMERA"]] = {
        Name = "WorldCam",
        Components = {
            Transform = {},
            Camera = { FOV = 90, DrawToScreen = true, NearestSampler = true, Resolution = vec2(1200, 1200) },
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
