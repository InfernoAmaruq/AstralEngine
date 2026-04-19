return {
    [RES["CAMERA"]] = {
        Name = "WorldCam",
        Components = {
            Transform = { Rotation = vec3(30, 0, 0) },
            Camera = { FOV = 90, DrawToScreen = true, NearestSampler = true, Resolution = vec2(1000, 1000) },
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
