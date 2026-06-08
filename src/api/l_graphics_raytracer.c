#include "api.h"
#include "util.h"
#include "graphics/graphics.h"

static int l_lovrRaytracerGetCapacity(lua_State* L) {
  Raytracer* raytracer = luax_checktype(L, 1, Raytracer);
  uint32_t capacity = lovrRaytracerGetCapacity(raytracer);
  lua_pushinteger(L, capacity);
  return 1;
}

static int l_lovrRaytracerGetCount(lua_State* L) {
  Raytracer* raytracer = luax_checktype(L, 1, Raytracer);
  uint32_t count = lovrRaytracerGetCount(raytracer);
  lua_pushinteger(L, count);
  return 1;
}

static int l_lovrRaytracerClear(lua_State* L) {
  Raytracer* raytracer = luax_checktype(L, 1, Raytracer);
  lovrRaytracerClear(raytracer);
  return 0;
}

static int l_lovrRaytracerAdd(lua_State* L) {
  Raytracer* raytracer = luax_checktype(L, 1, Raytracer);

  float transform[16];
  int index = luax_readmat4(L, 3, transform, 1);
  uint32_t layers = (uint8_t) luax_optu32(L, index++, 0xff);
  uint32_t tag = luax_optu32(L, index, ~0u);

  Mesh* mesh;
  Model* model;
  uint32_t id;

  if ((mesh = luax_totype(L, 2, Mesh)) != NULL) {
    luax_assert(L, lovrRaytracerAddMesh(raytracer, mesh, transform, layers, tag, &id));
  } else if ((model = luax_totype(L, 2, Model)) != NULL) {
    luax_assert(L, lovrRaytracerAddModel(raytracer, model, transform, layers, tag, &id));
  } else {
    return luax_typeerror(L, 2, "Model or Mesh");
  }

  if (id == ~0u) {
    lua_pushnil(L);
  } else {
    lua_pushinteger(L, id + 1);
  }

  return 1;
}

static int l_lovrRaytracerSet(lua_State* L) {
  Raytracer* raytracer = luax_checktype(L, 1, Raytracer);
  uint32_t id = luax_checku32(L, 2) - 1;

  int index = 3;
  float matrix[16];
  float* transform = NULL;
  if (!lua_isnoneornil(L, index)) {
    index = luax_readmat4(L, index, matrix, 1);
    transform = matrix;
  }

  uint32_t layers = luax_optu32(L, index++, ~0u);
  uint32_t tag = luax_optu32(L, index++, ~0u);

  luax_assert(L, lovrRaytracerSet(raytracer, id, transform, layers, tag));
  return 0;
}

static int l_lovrRaytracerBuild(lua_State* L) {
  Raytracer* raytracer = luax_checktype(L, 1, Raytracer);
  luax_assert(L, lovrRaytracerBuild(raytracer));
  return 0;
}

const luaL_Reg lovrRaytracer[] = {
  { "getCapacity", l_lovrRaytracerGetCapacity },
  { "getCount", l_lovrRaytracerGetCount },
  { "clear", l_lovrRaytracerClear },
  { "add", l_lovrRaytracerAdd },
  { "set", l_lovrRaytracerSet },
  { "build", l_lovrRaytracerBuild },
  { NULL, NULL }
};
