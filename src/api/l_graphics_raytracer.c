#include "api.h"
#include "util.h"
#include "graphics/graphics.h"

static int l_lovrRaytracerGetCapacity(lua_State* L) {
  Raytracer* raytracer = luax_checktype(L, 1, Raytracer);
  uint32_t capacity = lovrRaytracerGetCapacity(raytracer);
  lua_pushinteger(L, capacity);
  return 1;
}

const luaL_Reg lovrRaytracer[] = {
  { "getCapacity", l_lovrRaytracerGetCapacity },
  { NULL, NULL }
};
