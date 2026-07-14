local Component = GetService("Component")
local Render = GetService("Renderer")

local MeshId = Render.NewGeometryType(function(Pass, Geom)
    local TransformStorage = Component.Components.Transform.Storage
    local M = Component.Components.Material
    local MatStorage = M.Storage
    local EmptyMatrix = M.Metadata.EmptyMatrix

    local Mesh = Geom.Hash

    for i = 1, Geom.Top do
        local Ent = Geom[i]
        local Mat = MatStorage[Ent]
        local Transform = TransformStorage[Ent]

        if Mat then
            Pass:send("Material_Matrix", Mat[9])
            Pass:send("Material_ObjectScale", Transform[5])
        else
            Pass:send("Material_Matrix", EmptyMatrix)
        end

        Pass:draw(Mesh, Transform[3])
    end
end)

local Mesh = { Metadata = {} }
Mesh.Name = "Mesh"

local Mt = {
    __newindex = function(self, k, v)
        if k == "Mesh" then
            AstralEngine.Assert(typeof(v) == "Mesh" or v == nil, "Not a valid mesh!", "Mesh")
            self[1] = v
            local Flag = self.__RenderTypePtr.Flags.Param_Old
            self.__RenderTypePtr:Update(Flag, Flag, v or 0, Flag, Flag)
            self.__RenderTypePtr.Enabled = not not v
        end
    end,
}

Mesh.Metadata.__create = function(Data, Ent)
    AstralEngine.Assert(
        not Component.GetComponent(e, "RenderTarget"),
        "Entity already has RenderTarget component. Cannot bind more than 1 RenderTarget to an entity!",
        "Mesh"
    )

    local self = {}

    self[1] = Data.Mesh or false

    -- we wanna put this onto both just incase since meshes can have transparent vertices due to vertex colors
    local Stack = Component.Components.RenderTarget.Metadata.Flags.Stack_Both

    self.__RenderTypePtr = Component.AddComponent(Ent, "RenderTarget", {
        Shader = false,
        Stack = Stack,
        GeometryType = MeshId,
        GeometryHash = Data.Mesh or 0,
        Material = false,
        Enabled = not not self[1],
    })

    return setmetatable(self, Mt)
end

Mesh.Metadata.__remove = function(_, e)
    if Component.GetComponent(e, "RenderTarget") then
        Component.RemoveComponent(e, "RenderTarget", true)
    end
end

return Mesh
