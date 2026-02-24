#include "api.h"
#include "audio/audio.h"
#include "core/maf.h"
#include "util.h"

static int l_lovrSourceClone(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  Source* clone = lovrSourceClone(source);
  luax_assert(L, clone);
  luax_pushtype(L, Source, clone);
  lovrRelease(clone, lovrSourceDestroy);
  return 1;
}

static int l_lovrSourceGetSound(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  struct Sound* sound = lovrSourceGetSound(source);
  luax_pushtype(L, Sound, sound);
  return 1;
}

static int l_lovrSourcePlay(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  bool played = lovrSourcePlay(source);
  lua_pushboolean(L, played);
  return 1;
}

static int l_lovrSourcePause(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  lovrSourcePause(source);
  return 0;
}

static int l_lovrSourceStop(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  lovrSourceStop(source);
  return 0;
}

static int l_lovrSourceIsPlaying(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  lua_pushboolean(L, lovrSourceIsPlaying(source));
  return 1;
}

static int l_lovrSourceIsLooping(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  lua_pushboolean(L, lovrSourceIsLooping(source));
  return 1;
}

static int l_lovrSourceSetLooping(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  luax_assert(L, lovrSourceSetLooping(source, lua_toboolean(L, 2)));
  return 0;
}

static int l_lovrSourceGetPitch(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  lua_pushnumber(L, lovrSourceGetPitch(source));
  return 1;
}

static int l_lovrSourceSetPitch(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  luax_assert(L, lovrSourceSetPitch(source, luax_checkfloat(L, 2)));
  return 0;
}

static int l_lovrSourceGetVolume(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  VolumeUnit units = luax_checkenum(L, 2, VolumeUnit, "linear");
  lua_pushnumber(L, lovrSourceGetVolume(source, units));
  return 1;
}

static int l_lovrSourceSetVolume(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  float volume = luax_checkfloat(L, 2);
  VolumeUnit units = luax_checkenum(L, 3, VolumeUnit, "linear");
  lovrSourceSetVolume(source, volume, units);
  return 0;
}

static int l_lovrSourceSeek(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  double seconds = luaL_checknumber(L, 2);
  TimeUnit units = luax_checkenum(L, 3, TimeUnit, "seconds");
  lovrSourceSeek(source, seconds, units);
  return 0;
}

static int l_lovrSourceTell(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  TimeUnit units = luax_checkenum(L, 2, TimeUnit, "seconds");
  double time = lovrSourceTell(source, units);
  lua_pushnumber(L, time);
  return 1;
}

static int l_lovrSourceGetDuration(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  TimeUnit units = luax_checkenum(L, 2, TimeUnit, "seconds");
  double duration = lovrSourceGetDuration(source, units);
  lua_pushnumber(L, duration);
  return 1;
}

static int l_lovrSourceGetPosition(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  float position[3], orientation[4];
  lovrSourceGetPose(source, position, orientation);
  lua_pushnumber(L, position[0]);
  lua_pushnumber(L, position[1]);
  lua_pushnumber(L, position[2]);
  return 3;
}

static int l_lovrSourceSetPosition(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  float position[3];
  luax_readvec3(L, 2, position, NULL);
  lovrSourceSetPose(source, position, NULL);
  return 0;
}

static int l_lovrSourceGetOrientation(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  float position[3], orientation[4], angle, ax, ay, az;
  lovrSourceGetPose(source, position, orientation);
  quat_getAngleAxis(orientation, &angle, &ax, &ay, &az);
  lua_pushnumber(L, angle);
  lua_pushnumber(L, ax);
  lua_pushnumber(L, ay);
  lua_pushnumber(L, az);
  return 4;
}

static int l_lovrSourceSetOrientation(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  float orientation[4];
  luax_readquat(L, 2, orientation, NULL);
  lovrSourceSetPose(source, NULL, orientation);
  return 0;
}

static int l_lovrSourceGetPose(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  float position[3], orientation[4], angle, ax, ay, az;
  lovrSourceGetPose(source, position, orientation);
  quat_getAngleAxis(orientation, &angle, &ax, &ay, &az);
  lua_pushnumber(L, position[0]);
  lua_pushnumber(L, position[1]);
  lua_pushnumber(L, position[2]);
  lua_pushnumber(L, angle);
  lua_pushnumber(L, ax);
  lua_pushnumber(L, ay);
  lua_pushnumber(L, az);
  return 7;
}

static int l_lovrSourceSetPose(lua_State *L) {
  Source* source = luax_checktype(L, 1, Source);
  float position[3], orientation[4];
  int index = 2;
  index = luax_readvec3(L, index, position, NULL);
  index = luax_readquat(L, index, orientation, NULL);
  lovrSourceSetPose(source, position, orientation);
  return 0;
}

static int l_lovrSourceGetRadius(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  float radius = lovrSourceGetRadius(source);
  lua_pushnumber(L, radius);
  return 1;
}

static int l_lovrSourceSetRadius(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  float radius = luax_checkfloat(L, 2);
  lovrSourceSetRadius(source, radius);
  return 0;
}

static int l_lovrSourceIsSpatial(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  bool spatial = lovrSourceIsSpatial(source);
  lua_pushboolean(L, spatial);
  return 1;
}

static int l_lovrSourceGetAbsorption(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  float absorption[3];
  lovrSourceGetAbsorption(source, absorption);
  lua_pushnumber(L, absorption[0]);
  lua_pushnumber(L, absorption[1]);
  lua_pushnumber(L, absorption[2]);
  return 3;
}

static int l_lovrSourceSetAbsorption(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  float absorption[3];
  if (!lua_toboolean(L, 2)) {
    absorption[0] = absorption[1] = absorption[2] = 0.f;
  } else if (lua_isboolean(L, 2)) {
    lovrAudioGetAbsorption(absorption);
  } else {
    absorption[0] = luax_checkfloat(L, 2);
    absorption[1] = luax_checkfloat(L, 3);
    absorption[2] = luax_checkfloat(L, 4);
  }
  lovrSourceSetAbsorption(source, absorption);
  return 0;
}

static int l_lovrSourceGetCone(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  float innerAngle, outerAngle, outerVolume;
  lovrSourceGetCone(source, &innerAngle, &outerAngle, &outerVolume);
  lua_pushnumber(L, innerAngle);
  lua_pushnumber(L, outerAngle);
  lua_pushnumber(L, outerVolume);
  return 3;
}

static int l_lovrSourceSetCone(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  if (!lua_toboolean(L, 2)) {
    lovrSourceSetCone(source, 2.f * (float) M_PI, 2.f * (float) M_PI, 0.f);
  } else if (lua_isboolean(L, 2)) {
    lovrSourceSetCone(source, 0.f, (float) M_PI, 0.f);
  } else {
    float innerAngle = luax_checkfloat(L, 2);
    float outerAngle = luax_checkfloat(L, 3);
    float outerVolume = luax_optfloat(L, 4, 0.);
    lovrSourceSetCone(source, innerAngle, outerAngle, outerVolume);
  }
  return 0;
}

static int l_lovrSourceGetFalloff(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  float innerDistance, minVolume;
  lovrSourceGetFalloff(source, &innerDistance, &minVolume);
  lua_pushnumber(L, innerDistance);
  lua_pushnumber(L, minVolume);
  return 2;
}

static int l_lovrSourceSetFalloff(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  if (!lua_toboolean(L, 2)) {
    lovrSourceSetFalloff(source, 0.f, 1.f);
  } else if (lua_isboolean(L, 2)) {
    lovrSourceSetFalloff(source, 0.f, 0.f);
  } else {
    float innerDistance = luax_checkfloat(L, 2);
    float minVolume = luax_optfloat(L, 3, 0.);
    lovrSourceSetFalloff(source, innerDistance, minVolume);
  }
  return 0;
}

static int l_lovrSourceGetOcclusion(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  uint32_t occlusionRays, transmissionRays;
  lovrSourceGetOcclusion(source, &occlusionRays, &transmissionRays);
  lua_pushinteger(L, occlusionRays);
  lua_pushinteger(L, transmissionRays);
  return 2;
}

static int l_lovrSourceSetOcclusion(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  if (!lua_toboolean(L, 2)) {
    lovrSourceSetOcclusion(source, 0, 0);
  } else if (lua_isboolean(L, 2)) {
    lovrSourceSetOcclusion(source, 64, 4);
  } else {
    uint32_t occlusionRays = luax_checku32(L, 2);
    uint32_t transmissionRays = luax_optu32(L, 3, 4);
    lovrSourceSetOcclusion(source, occlusionRays, transmissionRays);
  }
  return 0;
}

static int l_lovrSourceGetReverb(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  float reverb;
  ReverbMode mode;
  lovrSourceGetReverb(source, &reverb, &mode);
  lua_pushnumber(L, reverb);
  luax_pushenum(L, ReverbMode, mode);
  return 2;
}

static int l_lovrSourceSetReverb(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  if (!lua_toboolean(L, 2)) {
    lovrSourceSetReverb(source, 0.f, REVERB_LISTENER);
  } else if (lua_isboolean(L, 2)) {
    lovrSourceSetReverb(source, 1.f, REVERB_LISTENER);
  } else {
    float reverb = luax_optfloat(L, 2, 0.f);
    ReverbMode mode = luax_checkenum(L, 3, ReverbMode, "listener");
    lovrSourceSetReverb(source, reverb, mode);
  }
  return 0;
}

static int l_lovrSourceGetSpatialization(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  float spatialization = lovrSourceGetSpatialization(source);
  lua_pushnumber(L, spatialization);
  return 1;
}

static int l_lovrSourceSetSpatialization(lua_State* L) {
  Source* source = luax_checktype(L, 1, Source);
  if (!lua_toboolean(L, 2)) {
    lovrSourceSetSpatialization(source, 0.f);
  } else if (lua_isboolean(L, 2)) {
    lovrSourceSetSpatialization(source, 1.f);
  } else {
    float spatialization = luax_checkfloat(L, 2);
    lovrSourceSetSpatialization(source, spatialization);
  }
  return 0;
}

const luaL_Reg lovrSource[] = {
  { "clone", l_lovrSourceClone },
  { "getSound", l_lovrSourceGetSound },
  { "play", l_lovrSourcePlay },
  { "pause", l_lovrSourcePause },
  { "stop", l_lovrSourceStop },
  { "isPlaying", l_lovrSourceIsPlaying },
  { "isLooping", l_lovrSourceIsLooping },
  { "setLooping", l_lovrSourceSetLooping },
  { "getPitch", l_lovrSourceGetPitch },
  { "setPitch", l_lovrSourceSetPitch },
  { "getVolume", l_lovrSourceGetVolume },
  { "setVolume", l_lovrSourceSetVolume },
  { "seek", l_lovrSourceSeek },
  { "tell", l_lovrSourceTell },
  { "getDuration", l_lovrSourceGetDuration },
  { "getPosition", l_lovrSourceGetPosition },
  { "setPosition", l_lovrSourceSetPosition },
  { "getOrientation", l_lovrSourceGetOrientation },
  { "setOrientation", l_lovrSourceSetOrientation },
  { "getPose", l_lovrSourceGetPose },
  { "setPose", l_lovrSourceSetPose },
  { "getRadius", l_lovrSourceGetRadius },
  { "setRadius", l_lovrSourceSetRadius },
  { "isSpatial", l_lovrSourceIsSpatial },
  { "getAbsorption", l_lovrSourceGetAbsorption },
  { "setAbsorption", l_lovrSourceSetAbsorption },
  { "getCone", l_lovrSourceGetCone },
  { "setCone", l_lovrSourceSetCone },
  { "getFalloff", l_lovrSourceGetFalloff },
  { "setFalloff", l_lovrSourceSetFalloff },
  { "getOcclusion", l_lovrSourceGetOcclusion },
  { "setOcclusion", l_lovrSourceSetOcclusion },
  { "getReverb", l_lovrSourceGetReverb },
  { "setReverb", l_lovrSourceSetReverb },
  { "getSpatialization", l_lovrSourceGetSpatialization },
  { "setSpatialization", l_lovrSourceSetSpatialization },
  { NULL, NULL }
};
