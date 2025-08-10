#include "api.h"
#include "math/math.h"
#include "core/maf.h"
#include "util.h"

static int l_lovrMat4Equals(lua_State* L) {
  const float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  const float* n = lovrMat4GetData(luax_checktype(L, 2, Mat4));
  for (int i = 0; i < 16; i += 4) {
    float dx = m[i + 0] - n[i + 0];
    float dy = m[i + 1] - n[i + 1];
    float dz = m[i + 2] - n[i + 2];
    float dw = m[i + 3] - n[i + 3];
    float distance2 = dx * dx + dy * dy + dz * dz + dw * dw;
    if (distance2 > 1e-10f) {
      lua_pushboolean(L, false);
      return 1;
    }
  }
  lua_pushboolean(L, true);
  return 1;
}

static int l_lovrMat4Unpack(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  if (lua_toboolean(L, 2)) {
    for (int i = 0; i < 16; i++) {
      lua_pushnumber(L, m[i]);
    }
    return 16;
  } else {
    float position[3], scale[3], angle, ax, ay, az;
    mat4_getPosition(m, position);
    mat4_getScale(m, scale);
    mat4_getAngleAxis(m, &angle, &ax, &ay, &az);
    lua_pushnumber(L, position[0]);
    lua_pushnumber(L, position[1]);
    lua_pushnumber(L, position[2]);
    lua_pushnumber(L, scale[0]);
    lua_pushnumber(L, scale[1]);
    lua_pushnumber(L, scale[2]);
    lua_pushnumber(L, angle);
    lua_pushnumber(L, ax);
    lua_pushnumber(L, ay);
    lua_pushnumber(L, az);
    return 10;
  }
}

static int l_lovrMat4GetPosition(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  float position[3];
  mat4_getPosition(m, position);
  lua_pushnumber(L, position[0]);
  lua_pushnumber(L, position[1]);
  lua_pushnumber(L, position[2]);
  return 3;
}

static int l_lovrMat4GetOrientation(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  float angle, ax, ay, az;
  mat4_getAngleAxis(m, &angle, &ax, &ay, &az);
  lua_pushnumber(L, angle);
  lua_pushnumber(L, ax);
  lua_pushnumber(L, ay);
  lua_pushnumber(L, az);
  return 4;
}

static int l_lovrMat4GetScale(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  float scale[3];
  mat4_getScale(m, scale);
  lua_pushnumber(L, scale[0]);
  lua_pushnumber(L, scale[1]);
  lua_pushnumber(L, scale[2]);
  return 3;
}

static int l_lovrMat4GetPose(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  float position[3], angle, ax, ay, az;
  mat4_getPosition(m, position);
  mat4_getAngleAxis(m, &angle, &ax, &ay, &az);
  lua_pushnumber(L, position[0]);
  lua_pushnumber(L, position[1]);
  lua_pushnumber(L, position[2]);
  lua_pushnumber(L, angle);
  lua_pushnumber(L, ax);
  lua_pushnumber(L, ay);
  lua_pushnumber(L, az);
  return 7;
}

int l_lovrMat4Set(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  int top = lua_gettop(L);
  Mat4* other;
  if (lua_isnoneornil(L, 2)) {
    mat4_identity(m);
  } else if ((other = luax_totype(L, 2, Mat4)) != NULL) {
    mat4_init(m, lovrMat4GetData(other));
  } else if (top == 17) {
    for (int i = 2; i <= 17; i++) {
      *m++ = luax_checkfloat(L, i);
    }
  } else if (top == 2 && lua_type(L, 2) == LUA_TNUMBER) {
    float x = luax_tofloat(L, 2);
    memset(m, 0, 16 * sizeof(float));
    m[0] = m[5] = m[10] = m[15] = x;
  } else {
    int index = 2;
    mat4_identity(m);

    float position[3], orientation[4], scale[3];
    index = luax_readvec3(L, index, position, "nil, number, vec3, or mat4");
    m[12] = position[0];
    m[13] = position[1];
    m[14] = position[2];

    // 1 more arg or 4 numbers: rotation, otherwise scale + rotation
    if (top == index || ((top - index) == 3 && lua_type(L, top) == LUA_TNUMBER)) {
      luax_readquat(L, index, orientation, NULL);
      mat4_rotateQuat(m, orientation);
    } else {
      index = luax_readscale(L, index, scale, 3, NULL);
      index = luax_readquat(L, index, orientation, NULL);
      mat4_rotateQuat(m, orientation);
      mat4_scale(m, scale[0], scale[1], scale[2]);
    }
  }
  lua_settop(L, 1);
  return 1;
}

static int l_lovrMat4Mul(lua_State* L) {
  Mat4* matrix = luax_checktype(L, 1, Mat4);
  Mat4* other = luax_totype(L, 2, Mat4);
  if (other) {
    mat4_mul(lovrMat4GetData(matrix), lovrMat4GetData(other));
    lua_settop(L, 1);
  } else {
    float v[4];
    int index = luax_readvec3(L, 2, v, NULL);
    v[3] = luax_optfloat(L, index, 1.f);
    mat4_mulVec4(lovrMat4GetData(matrix), v);
    lua_pushnumber(L, v[0]);
    lua_pushnumber(L, v[1]);
    lua_pushnumber(L, v[2]);
    return 3;
  }
  return 1;
}

static int l_lovrMat4Identity(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  mat4_identity(m);
  lua_settop(L, 1);
  return 1;
}

static int l_lovrMat4Invert(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  mat4_invert(m);
  lua_settop(L, 1);
  return 1;
}

static int l_lovrMat4Transpose(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  mat4_transpose(m);
  lua_settop(L, 1);
  return 1;
}

static int l_lovrMat4Translate(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  float translation[3];
  luax_readvec3(L, 2, translation, NULL);
  mat4_translate(m, translation[0], translation[1], translation[2]);
  lua_settop(L, 1);
  return 1;
}

static int l_lovrMat4Rotate(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  float rotation[4];
  luax_readquat(L, 2, rotation, NULL);
  mat4_rotateQuat(m, rotation);
  lua_settop(L, 1);
  return 1;
}

static int l_lovrMat4Scale(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  float scale[3];
  luax_readscale(L, 2, scale, 3, NULL);
  mat4_scale(m, scale[0], scale[1], scale[2]);
  lua_settop(L, 1);
  return 1;
}

static int l_lovrMat4Orthographic(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  if (lua_gettop(L) <= 5) {
    float width = luax_checkfloat(L, 2);
    float height = luax_checkfloat(L, 3);
    float n = luax_optfloat(L, 4, -1.f);
    float f = luax_optfloat(L, 5, 1.f);
    mat4_orthographic(m, 0.f, width, 0.f, height, n, f);
  } else {
    float left = luax_checkfloat(L, 2);
    float right = luax_checkfloat(L, 3);
    float bottom = luax_checkfloat(L, 4);
    float top = luax_checkfloat(L, 5);
    float n = luax_checkfloat(L, 6);
    float f = luax_checkfloat(L, 7);
    mat4_orthographic(m, left, right, bottom, top, n, f);
  }
  lua_settop(L, 1);
  return 1;
}

static int l_lovrMat4Perspective(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  float fovy = luax_checkfloat(L, 2);
  float aspect = luax_checkfloat(L, 3);
  float n = luax_checkfloat(L, 4);
  float f = luax_optfloat(L, 5, 0.);
  mat4_perspective(m, fovy, aspect, n, f);
  lua_settop(L, 1);
  return 1;
}

static int l_lovrMat4Fov(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  float left = luax_checkfloat(L, 2);
  float right = luax_checkfloat(L, 3);
  float up = luax_checkfloat(L, 4);
  float down = luax_checkfloat(L, 5);
  float n = luax_checkfloat(L, 6);
  float f = luax_optfloat(L, 7, 0.);
  mat4_fov(m, left, right, up, down, n, f);
  lua_settop(L, 1);
  return 1;
}

static int l_lovrMat4LookAt(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  float from[3], to[3], up[3];
  int index = 2;
  index = luax_readvec3(L, index, from, NULL);
  index = luax_readvec3(L, index, to, NULL);
  if (lua_isnoneornil(L, index)) {
    vec3_set(up, 0.f, 1.f, 0.f);
  } else {
    luax_readvec3(L, index, up, NULL);
  }
  mat4_lookAt(m, from, to, up);
  lua_settop(L, 1);
  return 1;
}

static int l_lovrMat4Target(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  float from[3], to[3], up[3];
  int index = 2;
  index = luax_readvec3(L, index, from, NULL);
  index = luax_readvec3(L, index, to, NULL);
  if (lua_isnoneornil(L, index)) {
    vec3_set(up, 0.f, 1.f, 0.f);
  } else {
    luax_readvec3(L, index, up, NULL);
  }
  mat4_target(m, from, to, up);
  lua_settop(L, 1);
  return 1;
}

static int l_lovrMat4Reflect(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  int index = 2;
  float position[3], normal[3];
  index = luax_readvec3(L, index, position, NULL);
  index = luax_readvec3(L, index, normal, NULL);
  mat4_reflect(m, position, normal);
  lua_settop(L, 1);
  return 1;
}

static int l_lovrMat4__mul(lua_State* L) {
  Mat4* self = luax_checktype(L, 1, Mat4);
  Mat4* other = luax_totype(L, 2, Mat4);

  if (other) {
    Mat4* result = lovrMat4Create();
    mat4_init(lovrMat4GetData(result), lovrMat4GetData(self));
    mat4_mul(lovrMat4GetData(self), lovrMat4GetData(other));
    luax_pushtype(L, Mat4, result);
    lovrRelease(result, lovrMat4Destroy);
    return 1;
  }

  if (lua_istable(L, 2)) {
    float v[3];
    luax_readvec3(L, 2, v, NULL);
    mat4_mulPoint(lovrMat4GetData(self), v);
    lua_createtable(L, 3, 0);
    lua_pushnumber(L, v[0]);
    lua_setfield(L, -2, "x");
    lua_pushnumber(L, v[1]);
    lua_setfield(L, -2, "y");
    lua_pushnumber(L, v[2]);
    lua_setfield(L, -2, "z");
    lua_getmetatable(L, 2);
    lua_setmetatable(L, -2);
    return 1;
  }

#ifdef LOVR_USE_LUAU
  if (lua_isvector(L, 2)) {
    const float* v = lua_tovector(L, 2);
    float out[3];
    vec3_init(out, v);
    mat4_mulPoint(lovrMat4GetData(self), out);
    lua_pushvector(L, out[0], out[1], out[2]);
    return 1;
  }
#endif

  return luaL_error(L, "Bad right hand side for Mat4 * operator: expected a Mat4 or a vector");
}

static int l_lovrMat4__tostring(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  const char* format = "(%f, %f, %f, %f,\n %f, %f, %f, %f,\n %f, %f, %f, %f,\n %f, %f, %f, %f)";
  lua_pushfstring(L, format,
    m[0], m[4], m[8], m[12],
    m[1], m[5], m[9], m[13],
    m[2], m[6], m[10], m[14],
    m[3], m[7], m[11], m[15]);
  return 1;
}

static int l_lovrMat4__newindex(lua_State* L) {
  float* m = lovrMat4GetData(luax_checktype(L, 1, Mat4));
  if (lua_type(L, 2) == LUA_TNUMBER) {
    int index = lua_tointeger(L, 2);
    if (index >= 1 && index <= 16) {
      m[index - 1] = luax_checkfloat(L, 3);
      return 0;
    }
  }
  lua_getglobal(L, "tostring");
  lua_pushvalue(L, 2);
  lua_call(L, 1, 1);
  return luaL_error(L, "attempt to assign property %s of mat4 (invalid property)", lua_tostring(L, -1));
}

static int l_lovrMat4__index(lua_State* L) {
  Mat4* matrix = luax_checktype(L, 1, Mat4);

  lua_getmetatable(L, 1);
  lua_pushvalue(L, 2);
  lua_rawget(L, -2);
  if (!lua_isnil(L, -1)) {
    return 1;
  } else {
    lua_pop(L, 2);
  }

  if (lua_type(L, 2) == LUA_TNUMBER) {
    int index = lua_tointeger(L, 2);
    if (index >= 1 && index <= 16) {
      float* m = lovrMat4GetData(matrix);
      lua_pushnumber(L, m[index - 1]);
      return 1;
    }
  }

  lua_getglobal(L, "tostring");
  lua_pushvalue(L, 2);
  lua_call(L, 1, 1);
  return luaL_error(L, "attempt to index field %s of mat4 (invalid property)", lua_tostring(L, -1));
}

const luaL_Reg lovrMat4[] = {
  { "equals", l_lovrMat4Equals },
  { "unpack", l_lovrMat4Unpack },
  { "getPosition", l_lovrMat4GetPosition },
  { "getOrientation", l_lovrMat4GetOrientation },
  { "getScale", l_lovrMat4GetScale },
  { "getPose", l_lovrMat4GetPose },
  { "set", l_lovrMat4Set },
  { "mul", l_lovrMat4Mul },
  { "identity", l_lovrMat4Identity },
  { "invert", l_lovrMat4Invert },
  { "transpose", l_lovrMat4Transpose },
  { "translate", l_lovrMat4Translate },
  { "rotate", l_lovrMat4Rotate },
  { "scale", l_lovrMat4Scale },
  { "orthographic", l_lovrMat4Orthographic },
  { "perspective", l_lovrMat4Perspective },
  { "fov", l_lovrMat4Fov },
  { "lookAt", l_lovrMat4LookAt },
  { "target", l_lovrMat4Target },
  { "reflect", l_lovrMat4Reflect },
  { "__mul", l_lovrMat4__mul },
  { "__tostring", l_lovrMat4__tostring },
  { "__newindex", l_lovrMat4__newindex },
  { "__index", l_lovrMat4__index },
  { NULL, NULL }
};
