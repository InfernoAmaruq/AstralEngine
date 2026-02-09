local Tilemap = {}

local IdxMap = {
    UVX = "x",
    UVY = "y",
    SizeX = "z",
    SizeY = "w",
}

local InitialBuffer = Vec4(1, 1, 1, 1)

local TexConfig = { mipmaps = false }

local TextureRegistry = setmetatable({}, { __mode = "v" })
-- Image PTR -> Texture

local MT = {
    __newindex = function(self, k, v)
        if k == "Buffer" or k == "Texture" then
            AstralEngine.Error("SPRITE ATLAS TEXTURE/BUFFER IS READ ONLY", "TILEMAP", 1)
        end
        local IdxVal = IdxMap[k]
        if IdxVal then
            AstralEngine.Assert(math.mathtype(v) == "Integer", "TILEMAP POSITION/SIZE INPUTS MUST BE INTEGER", 1)
            self[3][IdxMap[k]] = v + 1
            self[2]:setData(self[3])
        else
            AstralEngine.Error("INVALID WRITE TO TILEMAP KEY: " .. k, "TILEMAP", 1)
        end
    end,
    __index = function(self, k)
        if k == "Buffer" then
            return self[2]
        elseif k == "Texture" then
            return self[1]
        elseif IdxMap[k] then
            return self[3][IdxMap[k]] - 1
        end
    end,
    __type = "SpriteAtlas",
    __tostring = function(self)
        return "SpriteAtlas: " .. debug.getaddress(self)
    end,
}

Tilemap.New = function(RenderObj, Data)
    local Type = typeof(RenderObj)

    local Ptr
    local Texture

    if Type == "Image" then
        Ptr = RenderObj.getPath and RenderObj:getPath() or RenderObj:getPointer()

        Texture = TextureRegistry[Ptr]
        if not Texture then
            Texture = AstralEngine.Graphics.NewRawTexture(RenderObj, TexConfig)
            TextureRegistry[Ptr] = Texture
        end
    elseif Type == "Texture" then
        AstralEngine.Error("Cannot construct Tilemap from GPU Texture!", "TILEMAP", 2)
    elseif Type == "String" then
        AstralEngine.Error("Cannot get Tilemap Texture from filepath!", "TILEMAP", 2)
    end

    AstralEngine.Assert(Texture, "NO VALID TEXTURE PROVIDED FOR TILEMAP CREATION", "TILEMAP")

    local Val
    if Data then
        Val = vec4(Data.UVX, Data.UVY, Data.SizeX, Data.SizeY)
    else
        Val = InitialBuffer
    end

    local TilemapData = {
        [1] = Texture,
        [2] = lovr.graphics.newBuffer("i32x4", Val),
        [3] = Vec4(InitialBuffer),
        PathPointer = Ptr or "PATH_POINTER_NULL",
        -- why? because sprite renderer, when sending graphics, does SR[1][1], which, if the main texture is overriden by TilemapData, will cause the SR to use that
        -- slot [2] for buffer cause yeah, GPU needs to know size
        -- [3] is gonna be cache so we can R/W without re-alloc
    }

    setmetatable(TilemapData, MT)

    return TilemapData
end

return Tilemap
