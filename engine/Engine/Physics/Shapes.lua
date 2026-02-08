local RawPhys = lovr.physics
local Shapes = {}

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
            Quat = Rotation
        end

        self.__ShapePtr:setOffset(Position:unpack(), Quat:unpack())
    end,
    SetPosition = function(self, Position)
        local _, _, _, a, ax, ay, az = self.__ShapePtr:getOffset()
        self.__ShapePtr:setOffset(Position:unpack(), a, ax, ay, az)
    end,
    SetMass = function(self, NewMass)
        self.__ShapePtr:setMass(NewMass)
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
        else
            error("SHAPE API INCOMPLETE")
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
