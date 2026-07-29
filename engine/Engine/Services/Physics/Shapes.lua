local RawPhys = lovr.physics
local Shapes = {}

local ST = Enum({
    Box = 1,
    Sphere = 2,
    Cylinder = 3,
    Capsule = 4,
    Convex = 5,
    Mesh = 6,
}, "ColliderShape")

local TypeToShapeName = {
    [ST.Box] = "BoxShape",
    [ST.Sphere] = "SphereShape",
    [ST.Cylinder] = "CylinderShape",
    [ST.Capsule] = "CapsuleShape",
    [ST.Convex] = "ConvexShape",
    [ST.Mesh] = "MeshShape",
}

local StrToFunc = {
    SetSize = function(Self, NewSize)
        local T = Self.Type
        if T == ST.Box then
            Self.__ShapePtr:setDimensions(NewSize:unpack())
        elseif T == ST.Sphere then
            Self.__ShapePtr:setRadius(type(NewSize) == "number" and NewSize or math.max(NewSize:unpack()))
        elseif T == ST.Capsule or T == ST.Cylinder then
            Self.__ShapePtr:setLength(NewSize.y)
            Self.__ShapePtr:setRadius(NewSize.x)
        elseif T == ST.Mesh or T == ST.Convex then
            Self.__ShapePtr:setScale(NewSize)
        end
    end,
    SetRotation = function(self, Rotation)
        local x, y, z = self.__ShapePtr:getOffset()

        local Quat = nil
        if typeof(Rotation) == "Vec3" then
            Quat = quat():setEuler(Rotation:unpack())
        else
            Quat = Rotation
        end

        self.__ShapePtr:setOffset(x, y, z, Quat:unpack())
    end,
    SetOffset = function(self, Position, Rotation)
        local Quat = nil
        if typeof(Rotation) == "Vec3" then
            Quat = quat():setEuler(Rotation:unpack())
        else
            Quat = Rotation or quat()
        end

        self.__ShapePtr:setOffset(Position, Quat)
    end,
    SetPosition = function(self, Position)
        local _, _, _, a, ax, ay, az = self.__ShapePtr:getOffset()
        self.__ShapePtr:setOffset(Position.x, Position.y, Position.z, a, ax, ay, az)
    end,
    SetDensity = function(self, Density)
        self.__ShapePtr:setDensity(Density)
    end,

    -- getters
    GetMass = function(self)
        return self.__ShapePtr:getMass()
    end,
    GetDensity = function(self)
        return self.__ShapePtr:getDensity()
    end,
    GetWorldTransform = function(self)
        local x, y, z, a, ax, ay, az = self.__ShapePtr:getPose()
        local Q = quat(a, ax, ay, ax)
        return vec3(x, y, z), vec3(Q:getEuler()), Q
    end,
    GetOffset = function(self)
        local x, y, z, a, ax, ay, az = self.__ShapePtr:getOffset()
        local Q = quat(a, ax, ay, ax)
        return vec3(x, y, z), vec3(Q:getEuler()), Q
    end,
    GetSize = function(Self)
        local T = Self.Type
        if T == ST.Box then
            return vec3(self.__ShapePtr:getDimensions())
        elseif T == ST.Sphere then
            return vec3(self.__ShapePtr:getRadius())
        elseif T == ST.Cylinder or T == ST.Capsule then
            local ptr = self.__ShapePtr
            local Rad = ptr:getRadius()
            return vec3(Rad, ptr:getLength(), Rad)
        elseif T == ST.Mesh or T == ST.Convex then
            return vec3(self.__ShapePtr:getScale())
        end
    end,

    Destroy = function(self)
        self.__ShapePtr:destroy()
        self.__ShapePtr:setUserData(nil)
    end,
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
            return
        end
        rawset(self, k, v)
    end,
}

function Shapes.NewShape(ShapeType, Config)
    local Shape
    local IsMesh = false

    if ShapeType.Value <= 4 then
        Shape = RawPhys["new" .. TypeToShapeName[ShapeType]]()
    else
        local Mesh = Config.Mesh
        IsMesh = true

        Shape = RawPhys["new" .. TypeToShapeName[ShapeType]](Mesh, Config.Size)
    end

    AstralEngine.Assert(Shape, "Failed to create shape!", "PHYSICS")

    local UD = {}
    UD.Type = ShapeType
    UD.__ShapePtr = Shape

    setmetatable(UD, UDMeta)

    Shape:setUserData(UD)

    if Config then
        if Config.Size and not IsMesh then
            UD:SetSize(Config.Size)
        end
        if Config.OffsetPosition or Config.OffsetRotation then
            UD:SetOffset(Config.OffsetPosition, Config.OffsetRotation)
        end
    end

    return UD
end

return Shapes
