local Shapes = {}

local PI = math.pi
local MULTI_SEGMENT_RES = 48

local BaseFormat = {
  { 'VertexPosition', 'vec3' },
  { 'VertexNormal', 'vec3' },
  { 'VertexUV', 'vec2' }
}

function Shapes.NewBox(x,y,z)
  x = x or 1
  y = y or x
  z = z or y

  local w = x * 0.5
  local h = y * 0.5
  local d = z * 0.5

  local Verts = {
      { -w, -h, -d,  0,  0, -1, 1, 1 }, -- Front
      { -w,  h, -d,  0,  0, -1, 1, 0 },
      {  w, -h, -d,  0,  0, -1, 0, 1 },
      {  w,  h, -d,  0,  0, -1, 0, 0 },
      {  w,  h, -d,  1,  0,  0, 1, 0 }, -- Right
      {  w,  h,  d,  1,  0,  0, 0, 0 },
      {  w, -h, -d,  1,  0,  0, 1, 1 },
      {  w, -h,  d,  1,  0,  0, 0, 1 },
      {  w, -h,  d,  0,  0,  1, 1, 1 }, -- Back
      {  w,  h,  d,  0,  0,  1, 1, 0 },
      { -w, -h,  d,  0,  0,  1, 0, 1 },
      { -w,  h,  d,  0,  0,  1, 0, 0 },
      { -w,  h,  d, -1,  0,  0, 1, 0 }, -- Left
      { -w,  h, -d, -1,  0,  0, 0, 0 },
      { -w, -h,  d, -1,  0,  0, 1, 1 },
      { -w, -h, -d, -1,  0,  0, 0, 1 },
      { -w, -h, -d,  0, -1,  0, 1, 1 }, -- Bottom
      {  w, -h, -d,  0, -1,  0, 0, 1 },
      { -w, -h,  d,  0, -1,  0, 1, 0 },
      {  w, -h,  d,  0, -1,  0, 0, 0 },
      { -w,  h, -d,  0,  1,  0, 1, 0 }, -- Top
      { -w,  h,  d,  0,  1,  0, 1, 1 },
      {  w,  h, -d,  0,  1,  0, 0, 0 },
      {  w,  h,  d,  0,  1,  0, 0, 1 }
  }

  local Mesh = lovr.graphics.newMesh(BaseFormat, Verts)

  Mesh:setIndices({
    1, 2, 3, 3, 2, 4,
    5, 6, 7, 7, 6, 8,
    9, 10, 11, 11, 10, 12,
    13, 14, 15, 15, 14, 16,
    17, 18, 19, 19, 18, 20,
    21, 22, 23, 23, 22, 24
  })

  Mesh:setBoundingBox(-w,w,-h,h,-z,z)

  return Mesh
end

function Shapes.NewCylinder(x, y, z, capped, angle1, angle2, segments)
  x = x or 1
  y = y or x
  z = z or y

  capped = capped or true

  angle1 = angle1 or 0
  angle2 = angle2 or (2 * PI)
  segments = segments or MULTI_SEGMENT_RES

  local d = z / 2

  local Ind, Vert = {}, {}

  local AngleShift = (angle2 - angle1) / segments

  local cos, sin = math.cos, math.sin
  for i = 0, segments do
    local Theta = angle1 + i * AngleShift;
    local X, Y = cos(Theta) * 0.5, sin(Theta) * 0.5

    Vert[#Vert + 1] = { X * x, Y * y, -d, X, Y, 0, X + 0.5, 0.5 - Y }
    Vert[#Vert + 1] = { X * x, Y * y,  d, X, Y, 0, X + 0.5, 0.5 - Y }
  end

  for i = 0, segments - 1 do
    local a = i * 2 + 1;
    local b = i * 2 + 2;
    local c = i * 2 + 3;
    local d = i * 2 + 4;

    Ind[#Ind + 1] = a
    Ind[#Ind + 1] = c
    Ind[#Ind + 1] = b
    Ind[#Ind + 1] = b
    Ind[#Ind + 1] = c
    Ind[#Ind + 1] = d
  end

  if capped then
    local Base = #Vert + 1

    Vert[#Vert + 1] = { 0, 0, -d, 0, 0, -1, 0.5, 0.5 }
    Vert[#Vert + 1] = { 0, 0,  d, 0, 0,  1, 0.5, 0.5 }

    for i = 0, segments do
      local Theta = angle1 + i * AngleShift
      local X = cos(Theta) * 0.5
      local Y = sin(Theta) * 0.5

      Vert[#Vert + 1] = { X * x, Y * y, -d, 0, 0, -1, X + 0.5, Y - 0.5 }
      Vert[#Vert + 1] = { X * x, Y * y,  d, 0, 0,  1, X + 0.5, Y - 0.5 }
    end

    for i = 0, segments - 1 do
      local a = Base + 0
      local b = Base + (i + 1) * 2
      local c = Base + (i + 2) * 2

      Ind[#Ind + 1] = a
      Ind[#Ind + 1] = c
      Ind[#Ind + 1] = b
      Ind[#Ind + 1] = a + 1
      Ind[#Ind + 1] = b + 1
      Ind[#Ind + 1] = c + 1
    end

    print(Ind[#Ind],#Ind)
    print(#Vert)

  end

  local Mesh = lovr.graphics.newMesh(Vert)
  Mesh:setIndices(Ind)
  Mesh:setBoundingBox(-x/2,x/2,-y/2,y/2,-d,d)

  return Mesh
end

local function MakeSphere(w, h, d, segmentsH, segmentsV)
  local Vert = {}
  local Ind = {}

  local VertexCount = 2 + (segmentsH + 1) * (segmentsV - 1)

  Vert[1] = { 0, h, 0, 0, 1, 0, .5, 0 } --top

  local sin, cos = math.sin, math.cos
  for i = 1, segmentsV do
    local v = i / segmentsV
    local phi = v * PI
    local sinphi = sin(phi)
    local cosphi = cos(phi)
    for j = 0, segmentsH do
      local u = j / segmentsH
      local theta = u * 2 * PI
      local sintheta = sin(theta)
      local costheta = cos(theta)

      local x = sintheta * sinphi
      local y = cosphi
      local z = -costheta * sinphi

      Vert[#Vert + 1] = { x * w,y * h,z * d, x,y,z, u,v }
    end
  end

  Vert[#Vert+1] = { 0, -h, 0, 0, -1, 0, .5, 1 } -- bottom

  -- do indices

  for i = 1, segmentsH + 1 do
    Ind[#Ind + 1] = 1
    Ind[#Ind + 1] = i + 2
    Ind[#Ind + 1] = i + 1
  end

  for i = 0, segmentsV - 2 do
    for j = 0, segmentsH do
      local a = 1 + i * (segmentsH + 1) + 0 + j + 1
      local b = 1 + i * (segmentsH + 1) + 1 + j + 1
      local c = 1 + i * (segmentsH + 1) + 0 + segmentsH + 1 + j + 1
      local d = 1 + i * (segmentsH + 1) + 1 + segmentsH + 1 + j + 1

      Ind[#Ind + 1] = a
      Ind[#Ind + 1] = b
      Ind[#Ind + 1] = c
      Ind[#Ind + 1] = c
      Ind[#Ind + 1] = b
      Ind[#Ind + 1] = d
    end
  end

  for i = 0, segmentsH do
    Ind[#Ind + 1] = VertexCount - 1
    Ind[#Ind + 1] = VertexCount - 1 - (i + 2)
    Ind[#Ind + 1] = VertexCount - 1 - (i + 1)
  end

  return Vert, Ind
end

function Shapes.NewSphere(x,y,z,sh,sv)
  x = x or 1
  y = y or x
  z = z or y

  local w = x * 0.5
  local h = y * 0.5
  local d = z * 0.5

  sh = sh or MULTI_SEGMENT_RES
  sv = sv or (sh / 2)

  local Vert, Ind = MakeSphere(w,h,d,sh,sv)

  local Mesh = lovr.graphics.newMesh(Vert)
  Mesh:setIndices(Ind)
  Mesh:setBoundingBox(-w,w,-h,h,-d,d)
  return Mesh
end

function Shapes.NewCapsule(scaleX,scaleY,len,segments)
  segments = segments or MULTI_SEGMENT_RES

  local Length = (len or 1) * 0.25
  local Radius = (scaleX or 1) * 0.5

  if Length == 0 then
    return Shapes.NewSphere(x,y,z,MULTI_SEGMENT_RES,nil)
  end

  local Rings = segments / 2
  local Tip = Radius
  local VertCount = 2 * (1 + Rings * (segments + 1))

  local Vert, Ind = {}, {}

  Vert[1] = { 0, 0, -Tip, 0, 0, -1, 0.5, 0 }
  Vert[VertCount / 2 + 1] = { 0, 0, Tip, 0, 0, 1, 0.5, 1 }

  local Mesh = lovr.graphics.newMesh(Vert)
  Mesh:setIndices(Ind)

  return Mesh
end

function Shapes.NewPlane(x,y,col,row)

  local w = (x or 1) * 0.5
  local h = (y or (x or 1)) * 0.5

  row = row or 1
  col = col or row

  local Verts = {}
  local Ind = {}

  for iCol = 0, col do
    local v = iCol * ( 1 / row )
    for iRow = 0, row do
      local u = iRow * ( 1 / col )
      Verts[#Verts + 1] = {
        u - w, h - v, 0,
        0, 0, 1,
        u, v
      }
    end
  end

  local Mesh = lovr.graphics.newMesh(BaseFormat, Verts)

  for iCol = 0, col - 1 do
    for iRow = 0, row - 1 do
      local a = ((iCol * (col + 1)) + iRow) + 1
      local b = a + 1
      local c = a + col + 1
      local d = a + col + 2

      Ind[#Ind + 1] = a
      Ind[#Ind + 1] = c
      Ind[#Ind + 1] = b
      Ind[#Ind + 1] = b
      Ind[#Ind + 1] = c
      Ind[#Ind + 1] = d
    end
  end

  Mesh:setIndices(Ind)

  Mesh:setBoundingBox(-w, w, -h, h, 0, 0)

  return Mesh
end

return Shapes
