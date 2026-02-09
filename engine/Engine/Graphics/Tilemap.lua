local Tilemap = {}

local IdxMap = {
    UVX = 1,
    UVY = 2,
    SizeX = 3,
    SizeY = 4,
}

local InitialBuffer = { 1, 1, 1, 1 }

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
        return "SpriteAtlas : " .. debug.getaddress(self)
    end,
}

Tilemap.New = function(RenderObj)
    local Type = typeof(RenderObj)

    local Texture

    if Type == "Image" or Type == "Texture" then
        if Type == "Texture" then
            local RawTex = RenderObj[1] or RenderObj
            AstralEngine.Assert(
                RawTex:hasUsage("transfer"),
                "INVALID TEXTURE PROVIDED. NO TRANSFER USAGE SET.\nUsing a texture for a tilemap is advised against due to costs. Use image instead",
                "TILEMAP"
            )
            RenderObj = RawTex:getPixels()
        end

        Texture = AstralEngine.Graphics.NewRawTexture(RenderObj)
    elseif Type == "String" then
        AstralEngine.Error("Cannot get Tilemap Texture from filepath!", "TILEMAP", 2)
    end

    AstralEngine.Assert(Texture, "NO VALID TEXTURE PROVIDED FOR TILEMAP CREATION", "TILEMAP")

    local TilemapData = {
        [1] = Texture,
        [2] = lovr.graphics.newBuffer("i32x4", InitialBuffer),
        [3] = {},
        -- why? because sprite renderer, when sending graphics, does SR[1][1], which, if the main texture is overriden by TilemapData, will cause the SR to use that
        -- slot [2] for buffer cause yeah, GPU needs to know size
        -- [3] is gonna be cache so we can R/W without re-alloc
    }

    for i, v in ipairs(InitialBuffer) do
        TilemapData[3][i] = v
    end

    setmetatable(TilemapData, MT)

    return TilemapData
end

return Tilemap
