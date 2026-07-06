---@class Shape: Component

local Component = GetService("Component", "Component")
local Render = GetService("Renderer")

local Shape = {}

local E = Enum({
    Box = 1,
    Capsule = 2,
    Cylinder = 3,
    Sphere = 4,
    Plane = 5,
}, "ShapeType")

local P_Box, P_Sphere, P_Capsule, P_Plane, P_Cylinder
do
    local TMPPASS = AstralEngine.Graphics.NewPass()
    P_Box = TMPPASS.box
    P_Sphere = TMPPASS.sphere
    P_Capsule = TMPPASS.capsule
    P_Plane = TMPPASS.plane
    P_Cylinder = TMPPASS.cylinder
    P_Send = TMPPASS.send
end

local function GenerateProcessors(f, Offset) -- offset to last arg
    local Comp = Component.Components

    local P_Send = P_Send

    local function Single(Pass, Geometry)
        local TransformStorage = Comp.Transform.Storage
        local M = Comp.Material
        local MatStorage = M.Storage
        local EmptyMatrix = M.Metadata.EmptyMatrix

        local P_Send = P_Send

        local f = f

        for i = 1, Geometry.Top do
            local Ent = Geometry[i]
            local Mat = MatStorage[Ent]
            local Transform = TransformStorage[Ent]

            if Mat then
                P_Send(Pass, "Material_Matrix", Mat[9])
                P_Send(Pass, "Material_ObjectScale", Transform[5])
            else
                P_Send(Pass, "Material_Matrix", EmptyMatrix)
            end

            f(Pass, Transform[3])
        end
    end

    local Bulk

    if Offset == 3 then
        Bulk = function(Pass, Geometry)
            f(Pass, nil, nil, Geometry.Top)
        end
    elseif Offset == 4 then
        Bulk = function(Pass, Geometry)
            f(Pass, nil, nil, nil, Geometry.Top)
        end
    elseif Offset == 5 then
        Bulk = function(Pass, Geometry)
            f(Pass, nil, nil, nil, nil, Geometry.Top)
        end
    end

    return Single, Bulk
end

local BoxId, SphereId, CapsuleId, PlaneId, CylinderId
BoxId = Render.NewGeometryType(GenerateProcessors(P_Box, 3))
SphereId = Render.NewGeometryType(GenerateProcessors(P_Sphere, 4))
CapsuleId = Render.NewGeometryType(GenerateProcessors(P_Capsule, 3))
PlaneId = Render.NewGeometryType(GenerateProcessors(P_Plane, 5))
CylinderId = Render.NewGeometryType(GenerateProcessors(P_Cylinder, 5))

local LookupTable = {
    [E.Box] = BoxId,
    [E.Capsule] = CapsuleId,
    [E.Plane] = PlaneId,
    [E.Cylinder] = CylinderId,
    [E.Sphere] = SphereId,
}

Shape.Name = "Shape"
Shape.Pattern = { Shape = 0 }

local IdxFields = {
    Shape = 1,
}

local MT = {
    __index = function(self, k)
        return self[IdxFields[k]]
    end,
    __newindex = function(Comp, k, v)
        local RT = Comp.__RenderTypePtr
        if k == "Shape" then
            assert(
                typeof(v) == "__Enum_ShapeType",
                "Attempt to set 'Shape' field of component "
                .. tostring(Comp)
                .. ": "
                .. debug.getaddress(Comp)
                .. " to non-enum"
            )

            local Conversion = LookupTable[v]

            Comp[IdxFields.Shape] = v
            local Flags = RT.Flags
            RT:Update(Flags.Param_Old, Flags.Param_Old, Conversion, Conversion)
        end
    end,
}

Shape.Metadata = {}
Shape.Metadata.__create = function(DATA, e, ShouldSink)
    AstralEngine.Assert(
        not Component.GetComponent(e, "RenderTarget"),
        "Entity already has RenderTarget component. Cannot bind more than 1 RenderTarget to an entity!",
        "Shape"
    )
    local ShapeEnum = (DATA.Shape or E.Box)

    local Val = LookupTable[ShapeEnum]
    AstralEngine.Assert(Val, "No valid shape type provided!", "Shape")

    if not Component.GetComponent(e, "Transform") and not ShouldSink then
        Component.AddComponent(e, "Transform")
    end

    local RT = Component.AddComponent(e, "RenderTarget")

    local Comp = {
        [IdxFields.Shape] = ShapeEnum,
    }

    Comp.__RenderTypePtr = RT
    Comp.__Ent = e

    RT:Update(RT:GetMaterial(), RT.Flags.Stack_Solid, Val, Val) -- SUBMIT MATERIAL HERE AS WELL

    return setmetatable(Comp, MT)
end

Shape.Metadata.__remove = function(_, e)
    if Component.GetComponent(e, "RenderTarget") then
        Component.RemoveComponent(e, "RenderTarget", true)
    end
end

Shape.Metadata.HardExclusion = {
    RenderTarget = true,
}
Shape.Metadata.SoftDependency = {
    Transform = true,
}

return Shape
