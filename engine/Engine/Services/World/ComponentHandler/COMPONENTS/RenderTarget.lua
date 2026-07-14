---@class RenderTarget: Component

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
    __Shader = 6,
    __ShaderLock = 7,
    __Enabled = 8,
}

local RenderFlags = {
    Param_Old = -1, -- sent when we don't know the parameter. Like if we have a Material but Shape is submitting it

    Stack_None = 0,
    Stack_Solid = 1,
    Stack_Transparent = 2,
    Stack_Both = 3,
}

RendTarget.Metadata.Flags = RenderFlags

local Methods = {
    GetMaterial = function(self)
        local Mat = Component.GetComponent(self.__E, "Material")
        if Mat then
            return Mat[1] or false
        end
        return false
    end,
    GetShader = function(self)
        local Shader = Component.GetComponent(self.__E, "Shader")
        if Shader then
            return Shader[1] or false
        end
        return false
    end,
    ShaderLock = function(State)
        self[FIELDS.__ShaderLock] = State
    end,
    Update = function(self, Material, Solid, GeometryHash, DrawType, Shader)
        local bit = bit
        local OldSolid, OldMaterial, OldGeometryHash, OldDrawType, OldShader = unpack(self, 2, 6)

        Solid = Solid == RenderFlags.Param_Old and OldSolid or Solid or RenderFlags.Stack_None
        GeometryHash = GeometryHash == RenderFlags.Param_Old and OldGeometryHash or GeometryHash or -1

        DrawType = DrawType == RenderFlags.Param_Old and OldDrawType or DrawType or -1

        if Shader == RenderFlags.Param_Old then
            Shader = OldShader
        end

        if Material == RenderFlags.Param_Old then
            Material = OldShader
        end

        if self[FIELDS.__ShaderLock] and Shader ~= OldShader then
            AstralEngine.Error("Attempt to set a new shader to a ShaderLocked object!", "RenderTarget")
        end

        if self[FIELDS.__Enabled] then
            if
                Solid == OldSolid
                and Material == OldMaterial
                and GeometryHash == OldGeometryHash
                and DrawType == OldDrawType
                and Shader == OldShader
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
                DrawTable.RemoveFromStack(Entity, false, OldMaterial, GeometryHash, Shader)
            elseif not HadTransparent and DoTransparent then
                DrawTable.AddToStack(Entity, false, Material, GeometryHash, DrawType, Shader)
            elseif
                (OldMaterial ~= Material or DrawType ~= OldDrawType or OldGeometryHash ~= GeometryHash)
                and DoTransparent
            then
                DrawTable.RemoveFromStack(Entity, false, OldMaterial, OldGeometryHash, Shader)
                DrawTable.AddToStack(Entity, false, Material, GeometryHash, DrawType, Shader)
            end

            if HadSolid and not DoSolid then
                DrawTable.RemoveFromStack(Entity, true, OldMaterial, GeometryHash, Shader)
            elseif not HadSolid and DoSolid then
                DrawTable.AddToStack(Entity, true, Material, GeometryHash, DrawType, Shader)
            elseif
                (OldMaterial ~= Material or DrawType ~= OldDrawType or OldGeometryHash ~= GeometryHash) and DoSolid
            then
                DrawTable.RemoveFromStack(Entity, true, OldMaterial, OldGeometryHash, Shader)
                DrawTable.AddToStack(Entity, true, Material, GeometryHash, DrawType, Shader)
            end
        end

        self[2] = Solid
        self[3] = Material
        self[4] = GeometryHash
        self[5] = DrawType
        self[6] = Shader
    end,
    Invalidate = function(self)
        Renderer.DrawTable.Invalidate(self[6], self[3], self[4])
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
    __newindex = function(self, k, v)
        if k == "Enabled" then
            local Old = self[FIELDS.__Enabled]
            local Bool = not not v
            self[FIELDS.__Enabled] = Bool

            local DrawTable = Renderer.DrawTable
            local OldSolid, OldMaterial, OldGeometryHash, OldDrawType, OldShader = unpack(self, 2, 6)
            local Entity = self.__E

            local HadTransparent, HadSolid =
                bit.band(OldSolid, RenderFlags.Stack_Transparent) ~= 0, bit.band(OldSolid, RenderFlags.Stack_Solid) ~= 0

            if Old == true and Bool == false then
                if HadTransparent then
                    DrawTable.RemoveFromStack(Entity, false, OldMaterial, OldGeometryHash, OldShader)
                end
                if HadSolid then
                    DrawTable.RemoveFromStack(Entity, true, OldMaterial, OldGeometryHash, OldShader)
                end
            elseif Old == false and Bool == true then
                if HadTransparent then
                    DrawTable.AddToStack(Entity, false, OldMaterial, OldGeometryHash, OldDrawType, OldShader)
                elseif HadSolid then
                    DrawTable.AddToStack(Entity, true, OldMaterial, OldGeometryHash, OldDrawType, OldShader)
                end
            end
        end
    end,
}

RendTarget.Metadata.__create = function(In, Entity)
    local RM = Renderer.CamMask

    local Data = setmetatable({
        [FIELDS.__RenderMask] = RM,
        [FIELDS.__Stacks] = RenderFlags.Stack_None,
        [FIELDS.__Enabled] = In.Enabled == nil and true or In.Enabled,
        [2] = false,
        [3] = false,
        [4] = false,
        [5] = false,
        [6] = false,
        __E = Entity,
    }, mt)

    local Material, Stack, Hash, Type, Shader = In.Material, In.Stack, In.GeometryHash, In.GeometryType, In.Shader
    local MatComp = Component.GetComponent(Entity, "Material")
    local ShaderComp = Component.GetComponent(Entity, "Shader")

    if ShaderComp and not Data[FIELDS.__ShaderLock] then
        Shader = ShaderComp[1] or false
    end

    if MatComp then
        Material = MatComp[1] or false
        local IsSolid = MatComp.Color.a == 255
        if Material then
            Stack = IsSolid and RenderFlags.Stack_Both or RenderFlags.Stack_Transparent
        else
            Stack = IsSolid and RenderFlags.Stack_Solid or RenderFlags.Stack_Transparent
        end
    end

    Methods.Update(Data, Material, Stack, Hash, Type, Shader)

    Data[FIELDS.__ShaderLock] = In.ShaderLock or false

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
