---@class Shape: Component

local Component = GetService("Component", "Component")
local ShapeManager = GetService("AssetService").Shapes

local Shape = {}

local E = Enum({
    Box = 1,
    Capsule = 2,
    Cylinder = 3,
    Sphere = 4,
    Plane = 5,
}, "ShapeType")

local WeakMt = {__mode = "v"}
local MeshRegistry = setmetatable({},WeakMt)

Shape.Name = "Shape"

local function GetShape(Type,x,y,z,SegX,SegY)
  local Key = Type.Value.."-"..x..":"..y..":"..z..":"..(SegX or -1)..":"..(SegY or -1)

  local Mesh = MeshRegistry[Key]
  if not Mesh then
    if Type == E.Box then
      Mesh = ShapeManager.NewBox(x,y,z)
    elseif Type == E.Capsule then
      Mesh = ShapeManager.NewCapsule(x,y,z,SegX)
    elseif Type == E.Cylinder then
      Mesh = ShapeManager.NewCylinder(x,y,z,nil,nil,nil,SegX)
    elseif Type == E.Plane then
      Mesh = ShapeManager.NewPlane(x,y,SegX,SegY)
    else
      Mesh = ShapeManager.NewSphere(x,y,z,SegX,SegY)
    end
    MeshRegistry[Key] = Mesh
  end

  return Key, Mesh
end

local function Rebuild()
end

local MT = {
    __index = function(self, k)
      if k == "Shape" then
        return self.__Shape
      elseif k == "Rebuild" then
        return Rebuild
      end
    end,
    __newindex = function(Comp, k, v)
      local MeshCmp = Component.GetComponent(Comp.__Owner, "Mesh")
      AstralEngine.Assert(MeshCmp, "Attempt to edit 'Shape' component with a dead Mesh component!","Shape")
      if k == "Shape" then
        assert(
          typeof(v) == "Enum.ShapeType",
          "Attempt to set 'Shape' field of component "
          .. tostring(Comp)
          .. ": "
          .. debug.getaddress(Comp)
          .. " to non-enum"
        )

        if v == Comp.__Shape then return end

        Comp.__Shape = v
        local Key, NewShape = GetShape(v,Comp.__x,Comp.__y,Comp.__z,Comp.__SegX,Comp.__SegY)
        MeshCmp.Mesh = NewShape
        Comp.__Key = Key
      end
    end,
}

Shape.Userdata = {}
Shape.New = function(DATA, e, ShouldSink)
    AstralEngine.Assert(
        (not Component.GetComponent(e, "RenderTarget") and not Component.GetComponent(e,"Mesh")),
        "Entity already has RenderTarget/Mesh component. Cannot bind more than 1 RenderTarget/Mesh to an entity!",
        "Shape"
    )

    local ShapeEnum = (DATA.Shape or E.Box)

    if not Component.GetComponent(e, "Transform") and not ShouldSink then
        Component.AddComponent(e, "Transform")
    end

    local Scale = DATA.Scale or vec3(1,1,1)
    local SegX, SegY = DATA.SegX or nil, DATA.SegY or nil

    local Key, ObjMesh = GetShape(ShapeEnum,Scale.x,Scale.y,Scale.z,SegX,SegY)

    Component.AddComponent(e, "Mesh", {
      Mesh = ObjMesh
    })

    local Comp = {
        __Owner = e,
        __Mesh = ObjMesh,
        __Shape = ShapeEnum,
        __x = Scale.x,
        __y = Scale.y,
        __z = Scale.z,
        __SegX = SegX,
        __SegY = SegY,
        __Key = Key
    }

    return setmetatable(Comp, MT)
end

Shape.Destroy = function(self,e)
  local MeshCmp = Component.GetComponent(e,"Mesh")
  if MeshCmp and MeshCmp.Mesh == self.__Mesh then
    MeshCmp.Mesh = nil
    Component.RemoveComponent(e,"Mesh")
  end
end

Shape.Userdata.HardExclusion = {
    RenderTarget = true,
}
Shape.Userdata.SoftDependency = {
    Transform = true,
}

return Shape
