print("Hello world!")

local BOUND = GetService("SceneManager").OnLoad:Connect(function()
    print("SCENE BOUND")
end)

coroutine.yield()
print("This is running POST yield")
