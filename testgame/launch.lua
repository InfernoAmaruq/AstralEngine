print("Hello world!")

local BOUND = GetService("SceneManager").OnLoadEnd:Connect(function()
    print("SCENE BOUND")
end)

local UNBOUND = GetService("SceneManager").OnUnloadEnd:Connect(function()
    print("SCENE DEAD!")
end)

local AS = GetService("AssetService").NewImage
local T1 = os.clock()            --debug.cpuclock()
local IMG = AS("./Assets/Img/cart.png")
local Delta = os.clock() - T1    --debug.cpuclock() - T1

local T2 = os.clock()            --debug.cpuclock()
local IMG2 = AS("./Assets/Img/cart.png")
local HotDelta = os.clock() - T2 --debug.cpuclock() - T2

local T3 = os.clock()
local Texture = GetService("AssetService").NewTexture("./Assets/Img/cart.png", { usage = { "transfer" } })
local TexDelta = os.clock() - T3

print(AstralEngine.Graphics.NewTilemap(Texture))
local Tilemap = AstralEngine.Graphics.NewTilemap(IMG)
Tilemap.SizeX = 1000
Tilemap.SizeY = 1000

for i, v in ipairs(Tilemap[2]:getData()) do
    print(i, v)
end

_G.TILEMAP = Tilemap

print("Tex delta:", TexDelta)

print(Texture)

print("Cold delta:", Delta)
print("Hot delta:", HotDelta)

coroutine.yield()
print("This is running POST yield")

local CAS = GetService("ContextActionService")
CAS.Bind("INP_TEST", 100, function()
    print("PRESSED X")
end, ENUM.KeyCode.x)
