local RendTarget = {}

local Component = GetService("Component", "Component")
local Renderer = GetService("Renderer")
local Entity = GetService("Entity")

RendTarget.Name = "RenderTarget"
RendTarget.Pattern = {}
RendTarget.Metadata = {}

local FIELDS = {
    __RenderMask = 1,
    __Stacks = 2,
    __Material = 3,
    __GeometryHash = 4,
    __DrawType = 5,
}

local RenderFlags = {
    Param_Old = -1, -- sent when we don't know the parameter. Like if we have a Material but Shape is submitting it

    Stack_None = 0,
    Stack_Solid = 1,
    Stack_Transparent = 2,
    Stack_Both = 3,
}

local Methods = {
    GetMaterial = function(Entity)
        local Mat = Component.HasComponent(Entity, "Material")
        if Mat then
            return Mat[1] or false
        end
        return false
    end,
    Update = function(self, Material, Solid, GeometryHash, DrawType)
        local bit = bit
        local OldSolid, OldMaterial, OldGeometryHash, OldDrawType = unpack(self, 2, 5)

        Solid = Solid == RenderFlags.Param_Old and OldSolid or Solid or RenderFlags.Stack_None
        Material = Material == RenderFlags.Param_Old and OldMaterial or Material or false
        GeometryHash = GeometryHash == RenderFlags.Param_Old and OldGeometryHash or GeometryHash or -1
        DrawType = DrawType == RenderFlags.Param_Old and OldDrawType or DrawType or -1

        if
            Solid == OldSolid
            and Material == OldMaterial
            and GeometryHash == OldGeometryHash
            and DrawType == OldDrawType
        then
            self:Invalidate()
            return
        end

        local HadTransparent, HadSolid =
            bit.band(OldSolid, RenderFlags.Stack_Transparent) ~= 0, bit.band(OldSolid, RenderFlags.Stack_Solid) ~= 0
        local DoTransparent, DoSolid =
            bit.band(Solid, RenderFlags.Stack_Transparent) ~= 0, bit.band(Solid, RenderFlags.Stack_Solid) ~= 0

        local Entity = self.__E
        local DrawTable = Renderer.DrawTable

        if HadTransparent and not DoTransparent then
            DrawTable.RemoveFromStack(Entity, false, OldMaterial, GeometryHash)
        elseif not HadTransparent and DoTransparent then
            DrawTable.AddToStack(Entity, false, Material, GeometryHash, DrawType)
        elseif
            (OldMaterial ~= Material or DrawType ~= OldDrawType or OldGeometryHash ~= GeometryHash) and DoTransparent
        then
            DrawTable.RemoveFromStack(Entity, false, OldMaterial, OldGeometryHash)
            DrawTable.AddToStack(Entity, false, Material, GeometryHash, DrawType)
        end

        if HadSolid and not DoSolid then
            DrawTable.RemoveFromStack(Entity, true, OldMaterial, GeometryHash)
        elseif not HadSolid and DoSolid then
            DrawTable.AddToStack(Entity, true, Material, GeometryHash, DrawType)
        elseif (OldMaterial ~= Material or DrawType ~= OldDrawType or OldGeometryHash ~= GeometryHash) and DoSolid then
            DrawTable.RemoveFromStack(Entity, true, OldMaterial, OldGeometryHash)
            DrawTable.AddToStack(Entity, true, Material, GeometryHash, DrawType)
        end

        self[2] = Solid
        self[3] = Material
        self[4] = GeometryHash
        self[5] = DrawType
    end,
    Invalidate = function(self)
        Renderer.DrawTable.Invalidate(self[3], self[4])
    end,
}

Entity.OnTransformChanged:Connect(function(Ent)
    local rt = Component.Components.RenderTarget.Storage[Ent.Id]
    if rt then
        Methods.Invalidate(rt)
    end
end)

local mt = {
    __index = function(self, k)
        local v = FIELDS[k]
        return (k == "Flags" and RenderFlags) or Methods[k] or (v and rawget(self, v))
    end,
}

RendTarget.Metadata.__create = function(Type, Entity)
    local RM = Renderer.CamMask

    local Data = setmetatable({
        [FIELDS.__RenderMask] = RM,
        [FIELDS.__Stacks] = RenderFlags.Stack_None,
        [FIELDS.__GeometryHash] = -1,
        [FIELDS.__DrawType] = -1,
        [FIELDS.__Material] = false,
        __E = Entity,
    }, mt)

    return Data
end

RendTarget.Metadata.__remove = function(self, Entity)
    local Solid, Mat, Hash = unpack(self, 2, 4)

    local HadTransparent, HadSolid =
        bit.band(Solid, RenderFlags.Stack_Transparent) ~= 0, bit.band(Solid, RenderFlags.Stack_Solid) ~= 0
    local DrawTable = Renderer.DrawTable

    if HadTransparent then
        DrawTable.RemoveFromStack(Entity, false, Mat, Hash)
    end
    if HadSolid then
        DrawTable.RemoveFromStack(Entity, true, Mat, Hash)
    end
end

RendTarget.FinalProcessing = function()
    Renderer.__OnRenderTargetReady()
end

return RendTarget
