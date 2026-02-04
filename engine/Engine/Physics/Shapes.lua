local RawPhys = lovr.physics
local Shapes = {}

local Cache = setmetatable({}, { __mode = "k" })

local ST = ENUM({
    Box = 1,
    Sphere = 2,
    Cylinder = 3,
    Capsule = 4,
    Convex = 5,
}, "ColliderShape")

local TypeToShapeName = {
    [ST.Box] = "BoxShape",
    [ST.Sphere] = "SphereShape",
    [ST.Cylinder] = "CylinderShape",
    [ST.Capsule] = "CapsuleShape",
}

local StrToFunc = {
    SetSize = function(Self, NewSize)
        local T = Self.Type
        if T == ST.Box then
            Self.__ShapePtr:setDimensions(NewSize:unpack())
        elseif T == ST.Sphere then
            Self.__ShapePtr:setRadius(type(NewSize) == "number" and NewSize or math.max(NewSize:unpack()))
        else
            error("SHAPES: INCOMPLETE API")
        end
    end,
    SetRotation = function(self, Rotation) end,
    SetOffset = function(self, Rotation, Position) end,
    SetPosition = function(self, Position) end,
    SetMass = function(self, NewMass) end,
    SetDensity = function(self, Density) end,

    -- getters
    GetMass = function(self) end,
    GetDensity = function(self) end,
    GetWorldTransform = function(self) end,
    GetOffset = function(self) end,
    GetSize = function(self) end,
}

local IdxResolve = {
    Mass = StrToFunc.GetMass,
    Density = StrToFunc.GetDensity,
    Offset = StrToFunc.GetOffset,
    Transform = StrToFunc.GetWorldTransform,
    Size = StrToFunc.GetSize,
}
local NIdxResolve = {
    Mass = StrToFunc.SetMass,
    Density = StrToFunc.SetDensity,
    Size = StrToFunc.SetSize,
    Position = StrToFunc.SetPosition,
    Rotation = StrToFunc.SetRotation,
}

local UDMeta = {
    __tostring = function(self)
        return "ColliderShape : " .. debug.getaddress(self)
    end,
    __index = function(self, k)
        return StrToFunc[k] or (IdxResolve[k] and IdxResolve[k](self))
    end,
    __newindex = function(self, k, v)
        if NIdxResolve[k] then
            NIdxResolve[k](v)
        end
    end,
}

function Shapes.NewShape(ShapeType, Config)
    local Shape

    if ShapeType.RawValue <= 4 then
        Shape = RawPhys["new" .. TypeToShapeName[ShapeType]]()
    elseif ShapeType == ST.Convex then
    end

    AstralEngine.Assert(Shape, "Failed to create shape!", "PHYSICS")

    local UD = {}
    UD.Type = ShapeType
    UD.__ShapePtr = Shape

    setmetatable(UD, UDMeta)

    Shape:setUserData(UD)

    if Config then
        if Config.Size then
            UD:SetSize(Config.Size)
        end
    end

    return UD
end

return Shapes
