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

  Mesh* mesh = luax_totype(L, 2, Mesh);

  if (mesh) {
    luax_readmat4(L, 3, transform, 1);
    uint32_t id = lovrRaytracerAddMesh(raytracer, mesh, transform);
    luax_assert(L, id != ~0u);
    lua_pushinteger(L, id + 1);
    return 1;
  }

  Model* model = luax_totype(L, 2, Model);

  if (model) {
    luax_readmat4(L, 3, transform, 1);
    uint32_t id = lovrRaytracerAddModel(raytracer, model, transform);
    luax_assert(L, id != ~0u);
    lua_pushinteger(L, id + 1);
    return 1;
  }

  return luax_typeerror(L, 2, "Model or Mesh");
}

const luaL_Reg lovrRaytracer[] = {
  { "getCapacity", l_lovrRaytracerGetCapacity },
  { "getCount", l_lovrRaytracerGetCount },
  { "clear", l_lovrRaytracerClear },
  { "add", l_lovrRaytracerAdd },
  { NULL, NULL }
};
