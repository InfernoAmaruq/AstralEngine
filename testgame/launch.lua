print("Hello world!")

local BOUND = GetService("SceneManager").OnLoad:Connect(function()
    print("SCENE BOUND")
end)

local UNBOUND = GetService("SceneManager").OnUnload:Connect(function()
    print("SCENE DEAD!")
end)

coroutine.yield()
print("This is running POST yield")

local CAS = GetService("ContextActionService")
CAS.Bind("INP_TEST", 100, function()
    print("PRESSED X")
end, ENUM.KeyCode.x)
