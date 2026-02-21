local TileMapImg = GetService("AssetService").NewImage("../Img/tilemap-characters.png")
print("TILEMAP IMG:", TileMapImg, TileMapImg:getPath())

local t1 = os.clock()
local Tilemap = AstralEngine.Graphics.NewTilemap(TileMapImg)
local t2 = os.clock()
print("GOT TILEMAP:", Tilemap, Tilemap[1])
print("TILEMAP ALLOC TIME:", t2 - t1)

TileMapImg = GetService("AssetService").NewImage("../Img/tilemap-characters.png")
print("TILEMAP IMG 2:", TileMapImg, TileMapImg:getPath())

local Tilemap = AstralEngine.Graphics.NewTilemap(TileMapImg)
print("GOT TILEMAP:", Tilemap, Tilemap[1])

local CAM = RES["CAMERA"].Camera

Tilemap.UVX = 0
Tilemap.UVY = 0
Tilemap.SizeX = 24
Tilemap.SizeY = 24

local NewE = GetService("Entity").New("TEXTURE")
local SIGNAL = NewE.ComponentAdded:Connect(function(id, Data)
    print("ADDED COMPONENT", id, Data)
end)
local SIGNAL3 = NewE.ComponentRemoving:Connect(function(id, Data)
    print("REMOVE COMPONENT:", id, Data)
end)
local SIGNAL2 = NewE.Destroying:Connect(function()
    print("DESTROYING")
end)
NewE:AddComponent("Transform", { Position = Vec3(0, 0, -1) })
NewE:AddComponent("SpriteRenderer", { Texture = Tilemap, Size = vec2(1, 1), UseNearest = true })
NewE:AddComponent("Collider")

task.wait(2)
NewE.SpriteRenderer.Size = vec2(3, 3)
NewE:Destroy()

while true do
    task.wait(0.15)
    Tilemap.UVX = Tilemap.UVX + 25
    task.wait(0.15)
    Tilemap.UVX = 0
end
