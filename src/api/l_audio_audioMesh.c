#include "api.h"
#include "audio/audio.h"
#include "core/maf.h"
#include "util.h"

static int l_lovrAudioMeshClone(lua_State* L) {
  AudioMesh* mesh = luax_checktype(L, 1, AudioMesh);
  AudioMesh* clone = lovrAudioMeshClone(mesh);
  luax_assert(L, clone);
  luax_pushtype(L, AudioMesh, clone);
  lovrRelease(clone, lovrAudioMeshDestroy);
  return 1;
}

static int l_lovrAudioMeshIsEnabled(lua_State* L) {
  AudioMesh* mesh = luax_checktype(L, 1, AudioMesh);
  bool enabled = lovrAudioMeshIsEnabled(mesh);
  lua_pushboolean(L, enabled);
  return 1;
}

static int l_lovrAudioMeshSetEnabled(lua_State* L) {
  AudioMesh* mesh = luax_checktype(L, 1, AudioMesh);
  bool enable = lua_toboolean(L, 2);
  lovrAudioMeshSetEnabled(mesh, enable);
  return 0;
}

static int l_lovrAudioMeshGetPosition(lua_State* L) {
  AudioMesh* mesh = luax_checktype(L, 1, AudioMesh);
  float transform[16], position[3];
  lovrAudioMeshGetTransform(mesh, transform);
  mat4_getPosition(transform, position);
  lua_pushnumber(L, position[0]);
  lua_pushnumber(L, position[1]);
  lua_pushnumber(L, position[2]);
  return 3;
}

static int l_lovrAudioMeshSetPosition(lua_State* L) {
  AudioMesh* mesh = luax_checktype(L, 1, AudioMesh);
  float transform[16], position[3];
  lovrAudioMeshGetTransform(mesh, transform);
  luax_readvec3(L, 2, position, NULL);
  mat4_setPosition(transform, position);
  lovrAudioMeshSetTransform(mesh, transform);
  return 0;
}

static int l_lovrAudioMeshGetOrientation(lua_State* L) {
  AudioMesh* mesh = luax_checktype(L, 1, AudioMesh);
  float transform[16], angle, ax, ay, az;
  lovrAudioMeshGetTransform(mesh, transform);
  mat4_getAngleAxis(transform, &angle, &ax, &ay, &az);
  lua_pushnumber(L, angle);
  lua_pushnumber(L, ax);
  lua_pushnumber(L, ay);
  lua_pushnumber(L, az);
  return 4;
}

static int l_lovrAudioMeshSetOrientation(lua_State* L) {
  AudioMesh* mesh = luax_checktype(L, 1, AudioMesh);
  float transform[16], orientation[4];
  lovrAudioMeshGetTransform(mesh, transform);
  luax_readquat(L, 2, orientation, NULL);
  mat4_setOrientation(transform, orientation);
  lovrAudioMeshSetTransform(mesh, transform);
  return 0;
}

static int l_lovrAudioMeshGetPose(lua_State* L) {
  AudioMesh* mesh = luax_checktype(L, 1, AudioMesh);
  float transform[16], position[3], angle, ax, ay, az;
  lovrAudioMeshGetTransform(mesh, transform);
  mat4_getPosition(transform, position);
  mat4_getAngleAxis(transform, &angle, &ax, &ay, &az);
  lua_pushnumber(L, position[0]);
  lua_pushnumber(L, position[1]);
  lua_pushnumber(L, position[2]);
  lua_pushnumber(L, angle);
  lua_pushnumber(L, ax);
  lua_pushnumber(L, ay);
  lua_pushnumber(L, az);
  return 7;
}

static int l_lovrAudioMeshSetPose(lua_State* L) {
  AudioMesh* mesh = luax_checktype(L, 1, AudioMesh);
  float transform[16], position[3], orientation[4];
  lovrAudioMeshGetTransform(mesh, transform);
  int index = luax_readvec3(L, 2, position, NULL);
  luax_readquat(L, index, orientation, NULL);
  mat4_fromPose(transform, position, orientation);
  lovrAudioMeshSetTransform(mesh, transform);
  return 0;
}

static int l_lovrAudioMeshGetScale(lua_State* L) {
  AudioMesh* mesh = luax_checktype(L, 1, AudioMesh);
  float transform[16], scale[3];
  lovrAudioMeshGetTransform(mesh, transform);
  mat4_getScale(transform, scale);
  lua_pushnumber(L, scale[0]);
  lua_pushnumber(L, scale[1]);
  lua_pushnumber(L, scale[2]);
  return 3;
}

static int l_lovrAudioMeshSetScale(lua_State* L) {
  AudioMesh* mesh = luax_checktype(L, 1, AudioMesh);
  float transform[16], scale[3];
  lovrAudioMeshGetTransform(mesh, transform);
  luax_readscale(L, 2, scale, 3, NULL);
  mat4_setScale(transform, scale);
  lovrAudioMeshSetTransform(mesh, transform);
  return 0;
}

static int l_lovrAudioMeshGetTransform(lua_State* L) {
  AudioMesh* mesh = luax_checktype(L, 1, AudioMesh);
  float transform[16], position[3], scale[3], angle, ax, ay, az;
  lovrAudioMeshGetTransform(mesh, transform);
  mat4_getPosition(transform, position);
  mat4_getScale(transform, scale);
  mat4_getAngleAxis(transform, &angle, &ax, &ay, &az);
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

static int l_lovrAudioMeshSetTransform(lua_State* L) {
  AudioMesh* mesh = luax_checktype(L, 1, AudioMesh);
  float transform[16];
  luax_readmat4(L, 2, transform, 1);
  lovrAudioMeshSetTransform(mesh, transform);
  return 0;
}

const luaL_Reg lovrAudioMesh[] = {
  { "clone", l_lovrAudioMeshClone },
  { "isEnabled", l_lovrAudioMeshIsEnabled },
  { "setEnabled", l_lovrAudioMeshSetEnabled },
  { "getPosition", l_lovrAudioMeshGetPosition },
  { "setPosition", l_lovrAudioMeshSetPosition },
  { "getOrientation", l_lovrAudioMeshGetOrientation },
  { "setOrientation", l_lovrAudioMeshSetOrientation },
  { "getPose", l_lovrAudioMeshGetPose },
  { "setPose", l_lovrAudioMeshSetPose },
  { "getScale", l_lovrAudioMeshGetScale },
  { "setScale", l_lovrAudioMeshSetScale },
  { "getTransform", l_lovrAudioMeshGetTransform },
  { "setTransform", l_lovrAudioMeshSetTransform },
  { NULL, NULL }
};
