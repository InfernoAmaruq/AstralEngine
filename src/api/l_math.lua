local abs, sqrt, sin, cos, asin, acos, atan2 = math.abs, math.sqrt, math.sin, math.cos, math.asin, math.acos, math.atan2

vector = {}
vector.__index = vector

local function isvector(x)
  return type(x) == 'table' and getmetatable(x) == vector
end

local function newvector(x, y, z)
  return setmetatable({ x = x, y = y, z = z }, vector)
end

function vector.pack(x, y, z)
  return newvector(x or 0, y or 0, z or 0)
end

function vector.unpack(v)
  return v.x, v.y, v.z
end

function vector.length(v)
  return sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

function vector.normalize(v)
  local length = v:length()
  if length > 0 then
    return newvector(v.x / length, v.y / length, v.z / length)
  else
    return newvector(0, 0, 0)
  end
end

function vector.distance(v, u)
  local dx, dy, dz = v.x - u.x, v.y - u.y, v.z - u.z
  return sqrt(dx * dx + dy * dy + dz * dz)
end

function vector.cross(v, u)
  return newvector(
    v.y * u.z - v.z * u.y,
    v.z * u.x - v.x * u.z,
    v.x * u.y - v.y * u.x
  )
end

function vector.dot(v, u)
  return v.x * u.x + v.y * u.y + v.z * u.z
end

function vector.angle(v, u, axis)
  local cx, cy, cz = v.y * u.z - v.z * u.y, v.z * u.x - v.x * u.z, v.x * u.y - v.y * u.x
  local sina = sqrt(cx * cx + cy * cy + cz * cz)
  local cosa = v.x * u.x + v.y * u.y + v.z * u.z
  local angle = atan2(sina, cosa)

  if axis and cx * axis.x + cy * axis.y + cz * axis.z < 0 then
    angle = -angle
  end

  return angle
end

function vector.lerp(v, u, t)
  return newvector(
    v.x + (u.x - v.x) * t,
    v.y + (u.y - v.y) * t,
    v.z + (u.z - v.z) * t
  )
end

function vector.__add(a, b)
  if isvector(a) and isvector(b) then
    return newvector(a.x + b.x, a.y + b.y, a.z + b.z)
  elseif isvector(a) and type(b) == 'number' then
    return newvector(a.x + b, a.y + b, a.z + b)
  elseif type(a) == 'number' and isvector(b) then
    return newvector(a + b.x, a + b.y, a + b.z)
  else
    error('Unsupported type for vector __add')
  end
end

function vector.__sub(a, b)
  if isvector(a) and isvector(b) then
    return newvector(a.x - b.x, a.y - b.y, a.z - b.z)
  elseif isvector(a) and type(b) == 'number' then
    return newvector(a.x - b, a.y - b, a.z - b)
  elseif type(a) == 'number' and isvector(b) then
    return newvector(a - b.x, a - b.y, a - b.z)
  else
    error('Unsupported type for vector __sub')
  end
end

function vector.__mul(a, b)
  if isvector(a) and isvector(b) then
    return newvector(a.x * b.x, a.y * b.y, a.z * b.z)
  elseif isvector(a) and type(b) == 'number' then
    return newvector(a.x * b, a.y * b, a.z * b)
  elseif type(a) == 'number' and isvector(b) then
    return newvector(a * b.x, a * b.y, a * b.z)
  else
    error('Unsupported type for vector __mul')
  end
end

function vector.__div(a, b)
  if isvector(a) and isvector(b) then
    return newvector(a.x / b.x, a.y / b.y, a.z / b.z)
  elseif isvector(a) and type(b) == 'number' then
    return newvector(a.x / b, a.y / b, a.z / b)
  elseif type(a) == 'number' and isvector(b) then
    return newvector(a / b.x, a / b.y, a / b.z)
  else
    error('Unsupported type for vector __div')
  end
end

function vector.__unm(v)
  return newvector(-v.x, -v.y, -v.z)
end

function vector.__tostring(v)
  return ('%f, %f, %f'):format(v.x, v.y, v.z)
end

vector.zero = vector.pack(0, 0, 0)
vector.one = vector.pack(1, 1, 1)
vector.up = vector.pack(0, 1, 0)
vector.right = vector.pack(1, 0, 0)

setmetatable(vector, {
  __call = function(self, ...)
    return vector.pack(...)
  end
})


quaternion = {}
quaternion.__index = quaternion

local function isquaternion(x)
  return type(x) == 'table' and getmetatable(x) == quaternion
end

local function newquaternion(x, y, z, w)
  return setmetatable({ x = x, y = y, z = z, w = w }, quaternion)
end

function quaternion.pack(x, y, z, w)
  return newquaternion(x, y, z, w)
end

function quaternion.unpack(q)
  return q.x, q.y, q.z, q.w
end

function quaternion.conjugate(q)
  return newquaternion(-q.x, -q.y, -q.z, q.w)
end

function quaternion.angleaxis(angle, ax, ay, az)
  local s = sin(angle * .5)
  local c = cos(angle * .5)

  local length = sqrt(ax * ax + ay * ay + az * az)

  if length > 0 then
    s = s / length
  end

  return newquaternion(ax * s, ay * s, az * s, c)
end

function quaternion.toangleaxis(q)
  local s = sqrt(1 - q.w * q.w)
  s = s < 1e-6 and 1 or 1 / s

  return 2 * acos(q.w), q.x * s, q.y * s, q.z * s
end

function quaternion.euler(x, y, z)
  local cx, sx = cos(x * .5), sin(x * .5)
  local cy, sy = cos(y * .5), sin(y * .5)
  local cz, sz = cos(z * .5), sin(z * .5)

  return newquaternion(
    cy * sx * cz + sy * cx * sz,
    sy * cx * cz - cy * sx * sz,
    cy * cx * sz - sy * sx * cz,
    cy * cx * cz + sy * sx * sz
  )
end

function quaternion.toeuler(q)
  local x, y, z, w = q.x, q.y, q.z, q.w
  local unit = x * x + y * y + z * z + w * w
  local test = x * w - y * z
  local ax, ay, az

  if test > (.5 - 1e-6) * unit then
    ax = math.pi / 2
    ay = 2 * atan2(y, x)
    az = 0
  elseif test < -(.5 - 1e-6) * unit then
    ax = -math.pi / 2
    ay = -2 * atan2(y, x)
    az = 0
  else
    ax = asin(2 * (w * x - y * z))
    ay = atan2(2 * w * y + 2 * z * x, 1 - 2 * (x * x + y * y))
    az = atan2(2 * w * z + 2 * x * y, 1 - 2 * (z * z + x * x))
  end

  return ax, ay, az
end

function quaternion.between(a, b)
  local dot = a.x * b.x + a.y * b.y + a.z * b.z

  if dot > .99999 or dot < -.99999 then
    return newquaternion(0, 0, 0, 1)
  end

  local x = a.y * b.z - a.z * b.y
  local y = a.z * b.x - a.x * b.z
  local z = a.x * b.y - a.y * b.x
  local w = 1 + dot

  local length = sqrt(x * x + y * y + z * z + w * w)

  return newquaternion(x / length, y / length, z / length, w / length)
end

function quaternion.lookdir(dir, up)
  up = up or vector.up

  local fx, fy, fz = dir.x, dir.y, dir.z
  local length = sqrt(fx * fx + fy * fy + fz * fz)

  if length == 0 then
    return newquaternion(0, 0, 0, 1)
  end

  fx, fy, fz = fx / length, fy / length, fz / length

  local rx, ry, rz = fy * up.z - fz * up.y, fz * up.x - fx * up.z, fx * up.y - fy * up.x
  length = sqrt(rx * rx + ry * ry + rz * rz)

  if length == 0 then
    if abs(fx) < .9 then
      rx, ry, rz = 0, fz, -fy
    else
      rx, ry, rz = fz, 0, -fx
    end

    length = sqrt(rx * rx + ry * ry + rz * rz)
  end

  rx, ry, rz = rx / length, ry / length, rz / length

  local ux, uy, uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx

  local m00, m01, m02 = rx, ux, fx
  local m10, m11, m12 = ry, uy, fy
  local m20, m21, m22 = rz, uz, fz

  if m22 < 0 then
    if m00 > m11 then
      local t = 1 + m00 - m11 - m22
      local s = .5 / sqrt(t)
      return newquaternion(t * s, (m01 + m10) * s, (m20 + m02) * s, (m12 - m21) * s)
    else
      local t = 1 - m00 + m11 - m22
      local s = .5 / sqrt(t)
      return newquaternion((m01 + m10) * s, t * s, (m12 + m21) * s, (m20 - m02) * s)
    end
  else
    if m00 < -m11 then
      local t = 1 - m00 - m11 + m22
      local s = .5 / sqrt(t)
      return newquaternion((m20 + m02) * s, (m12 + m21) * s, t * s, (m01 - m10) * s)
    else
      local t = 1 + m00 + m11 + m22
      local s = .5 / sqrt(t)
      return newquaternion((m12 - m21) * s, (m20 - m02) * s, (m01 - m10) * s, t * s)
    end
  end
end

function quaternion.direction(q)
  local x = -2 * q.x * q.z - 2 * q.w * q.y
  local y = -2 * q.y * q.z + 2 * q.w * q.x
  local z = -1 + 2 * q.x * q.x + 2 * q.y * q.y
  return x, y, z
end

function quaternion.slerp(q, r, t)
  local dot = q.x * r.x + q.y * r.y + q.z * r.z + q.w * r.w

  if abs(dot) >= 1 then
    return q
  end

  local x, y, z, w = q.x, q.y, q.z, q.w

  if dot < 0 then
    x, y, z, w, dot = -x, -y, -z, -w, -dot
  end

  local halfTheta = acos(dot)
  local sinHalfTheta = sqrt(1 - dot * dot)

  if abs(sinHalfTheta) < .001 then
    return newquaternion(
      x * .5 + r.x * .5,
      y * .5 + r.y * .5,
      z * .5 + r.z * .5,
      w * .5 + r.w * .5
    )
  end

  local a = sin((1 - t) * halfTheta) / sinHalfTheta
  local b = sin(t * halfTheta) / sinHalfTheta

  return newquaternion(
    x * a + r.x * b,
    y * a + r.y * b,
    z * a + r.z * b,
    w * a + r.w * b
  )
end

function quaternion.__mul(q, b)
  if isquaternion(q) and isquaternion(b) then
    return newquaternion(
      q.x * b.w + q.w * b.x + q.y * b.z - q.z * b.y,
      q.y * b.w + q.w * b.y + q.z * b.x - q.x * b.z,
      q.z * b.w + q.w * b.z + q.x * b.y - q.y * b.x,
      q.w * b.w - q.x * b.x - q.y * b.y - q.z * b.z
    )
  elseif isquaternion(q) and isvector(b) then
    local ux, uy, uz = q.x, q.y, q.z
    local cx, cy, cz = q.y * b.z - q.z * b.y, q.z * b.x - q.x * b.z, q.x * b.y - q.y * b.z

    local uu = ux * ux + uy * uy + uz * uz
    local uv = ux * b.x + uy * b.y + uz * b.z
    local s = q.w * q.w - uu

    return newvector(
      b.x * s + ux * 2 * uv + cx * 2 * q.w,
      b.y * s + uy * 2 * uv + cy * 2 * q.w,
      b.z * s + uz * 2 * uv + cz * 2 * q.w
    )
  else
    error('Unsupported type for quaternion __mul')
  end
end

function quaternion.__tostring(q)
  return ('%f, %f, %f, %f'):format(q.x, q.y, q.z, q.w)
end

quaternion.identity = quaternion.pack(0, 0, 0, 1)

setmetatable(quaternion, {
  __call = function(self, ...)
    return quaternion.angleaxis(...)
  end
})
