---@class Material: Component

local Comp = GetService("Component")
local Material = {}

Material.Name = "Material"
Material.Metadata = {}

Comp.ComponentAdded:Connect(function(e, id, c)
    local Mat = Comp.GetComponent(e, "Material")
    if id == "RenderTarget" and Mat then
        if Mat[1] then
            c:SetMaterial(Mat[1])
        else
            local Alpha = Mat[4].w
            c:RemoveFromStack()
            c:SwapStacks(Alpha == 1)
        end
    end
end)

local MaterialFitMode = ENUM({ Stretch = 0, Tile = 1, Crop = 2 }, "MaterialFitMode")

Material.Metadata.EmptyMatrix = Mat4(
    0,
    0, -- uv offset
    1,
    1, -- uv scale
    --
    1,
    1,
    1,
    1, -- color
    --
    0, -- fit mode
    0, -- sampler
    0,
    0,
    --
    1,
    1,
    1,
    1
-- glow
)

local function RebuildMatrix(self)
    local RT = Comp.GetComponent(self[8], "RenderTarget")

    local Offset, Scale, Color, GlowColor = self[3], self[2], self[4], self[10]
    self[9]:set(
        Offset.x,
        Offset.y,
        Scale.x,
        Scale.y,
        --
        Color.r,
        Color.g,
        Color.b,
        Color.a,
        --
        self[5],
        self[6] and 1 or 0,
        0,
        0,
        --
        GlowColor.r,
        GlowColor.g,
        GlowColor.b,
        GlowColor.a
    )

    if RT then
        local F = RT.Flags

        local Flag = (Color.a >= 0.99 and (self[1] and F.Stack_Both or F.Stack_Solid) or F.Stack_Transparent)

        RT:Update(self[1], Flag, F.Param_Old, F.Param_Old)
    end
end

local Mt = {
    __index = function(self, k)
        if k == "Color" or k == "GlowColor" then
            return self[k == "Color" and 4 or 10] * 255
        elseif k == "Material" then
            return self[7]
        elseif k == "UVOffset" then
            return vec2(self[3])
        elseif k == "UVScale" then
            return vec2(self[2])
        elseif k == "FitMode" then
            return rawget(self, "__FitEnum")
        elseif k == "UseNearest" then
            return self[6]
        end
    end,
    __newindex = function(self, k, v)
        if k == "Material" then
            self[7] = v
            self[1] = v and v.__lmat or v[1] or v
        elseif k == "Color" or k == "GlowColor" then
            v = v or vec4(255, 255, 255, 255)
            local r, g, b, a = v:div(255):unpack()
            self[k == "Color" and 4 or 10]:set(r, g, b, a or 1)
        elseif k == "UVOffset" then
            self[3]:set(v)
        elseif k == "UVScale" then
            self[2]:set(v)
        elseif k == "FitMode" then
            rawset(self, "__FitEnum", v)
            self[5] = v.RawValue
        elseif k == "UseNearest" then
            self[6] = v
        end
        RebuildMatrix(self)
    end,
}

Material.Metadata.__create = function(Data, Ent)
    local Storage = {}

    local RT = Comp.GetComponent(Ent, "RenderTarget")

    local Mat = Data and Data.Material
    Storage[1] = Mat and (Mat.__lmat or Mat[1] or Mat)
    Storage[2] = Data and Data.UVScale and Vec2(Data.UVScale) or Vec2(1, 1)
    Storage[3] = Data and Data.UVOffset and Vec2(Data.UVOffset) or Vec2(0, 0)

    local InColor = Data and Data.Color or vec4(255, 255, 255, 255)
    local R, G, B, A = InColor:unpack()
    local Color = Vec4(R, G, B, A or 1):div(255)
    Storage[4] = Color
    Storage[7] = Mat
    Storage[8] = Ent
    Storage[9] = Mat4() -- allocate matrix for it

    local InGlowColor = Data and Data.Glow or vec4(0, 0, 0, 255)
    R, G, B, A = InGlowColor:unpack()
    local GlowColor = Vec4(R, G, B, A or 1):div(255)

    Storage[10] = GlowColor

    local FitMode = Data.FitMode or MaterialFitMode.Stretch
    Storage.__FitEnum = FitMode
    Storage[5] = FitMode.RawValue
    Storage[6] = Data.UseNearest or false

    if Storage[7] and Storage[7].Properties then
        Storage[3]:set(Storage[3], Storage[7].Properties.Texture)
    elseif Storage[7] then
        Storage[3]:set(Storage[3], Storage[7][1] or Storage[7])
    end

    RebuildMatrix(Storage)

    setmetatable(Storage, Mt)

    return Storage
end

return Material
