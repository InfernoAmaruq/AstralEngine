#include "lua.h"
#include "lapi.h"
#include <stdlib.h>
#include "util.h"
#include "lib/std/threads.h"

#include "api/l_physics.c"
#include "physics/physics.h"

#define MAX_WORLDS 5
#define BASE_SIZE 64
#define RESIZE_STEP 1.2

// lazy shim, THIS SKIPS THE WORLD DESTROY CHECK
// IF THIS EXPLODES THIS IS WHY \/\/\/
World* luax_checkworld(lua_State* L, int index){
    return luax_checktype(L,index,World);
}

typedef struct LightContact {
    Collider* ColliderA; Collider* ColliderB;
    Shape* ShapeA; Shape* ShapeB;
    float normal[3];
    float Overlap;
} LightContact;

typedef struct WorldColBuf {
    mtx_t EnterLock;
    mtx_t ExitLock;

    LightContact* ContactArray; // for enter, holds only contact (we can get Collider from Contact after)
    size_t ContactCount;
    size_t ContactCapacity;

    Collider** ColliderArray; // for exit, holds both colliders. Iterate in 2's
    size_t ColliderCount;
    size_t ColliderCapacity;
} WorldColBuf;

static WorldColBuf* TotalWorlds[MAX_WORLDS];
static int WorldCount = 0;

// c state

static void PhysNative_ExitCallback(void* userdata, World* world, Collider* a, Collider* b){
    WorldColBuf* Buffer = (void*)lovrWorldGetUserData(world);

    if (Buffer == NULL) {printf("ATTEMPT TO USE NULL WORLD BUFFER FOR COLLIDER\n"); return;}

    mtx_lock(&Buffer->ExitLock);

    Buffer->ColliderArray[Buffer->ColliderCount++] = a;
    Buffer->ColliderArray[Buffer->ColliderCount++] = b;

    if (Buffer->ColliderCount == Buffer->ColliderCapacity){
        Buffer->ColliderCapacity = (size_t)Buffer->ColliderCapacity * RESIZE_STEP;
        Buffer->ColliderArray = lovrRealloc(Buffer->ColliderArray,sizeof(void*) * Buffer->ColliderCapacity);
    }

    mtx_unlock(&Buffer->ExitLock);
}

static void PhysNative_EnterCallback(void* userdata, World* world, Collider* a, Collider* b, Contact* contact){
    WorldColBuf* Buffer = (void*)lovrWorldGetUserData(world);

    if (Buffer == NULL) {printf("ATTEMPT TO USE NULL WORLD BUFFER FOR COLLIDER\n"); return;}

    mtx_lock(&Buffer->EnterLock);

    LightContact* lc = &Buffer->ContactArray[Buffer->ContactCount++];
    lc->ColliderA = a;
    lc->ColliderB = b;
    lc->ShapeA = lovrContactGetShapeA(contact);
    lc->ShapeB = lovrContactGetShapeB(contact);
    lc->Overlap = lovrContactGetOverlap(contact);
    lovrContactGetNormal(contact,lc->normal);

    if (Buffer->ContactCount == Buffer->ContactCapacity){
        Buffer->ContactCapacity = (size_t)Buffer->ContactCapacity * RESIZE_STEP;
        Buffer->ContactArray = lovrRealloc(Buffer->ContactArray,sizeof(LightContact) * Buffer->ContactCapacity);
    }

    mtx_unlock(&Buffer->EnterLock);
}

// lua

static int PhysNative_RegisterWorld(lua_State* L){
    World* World = luax_checkworld(L, 1);

    WorldColBuf* Buffer = lovrMalloc(sizeof(WorldColBuf));
    mtx_init(&Buffer->EnterLock,mtx_plain);
    mtx_init(&Buffer->ExitLock,mtx_plain);

    Buffer->ContactCount = 0;
    Buffer->ContactCapacity = BASE_SIZE;
    Buffer->ContactArray = malloc(Buffer->ContactCapacity * sizeof(LightContact));

    Buffer->ColliderCount = 0;
    Buffer->ColliderCapacity = BASE_SIZE * 2;
    Buffer->ColliderArray = malloc(Buffer->ColliderCapacity * sizeof(void*));

    TotalWorlds[WorldCount] = Buffer;
    lua_pushinteger(L,WorldCount);
    WorldCount++;

    lovrWorldSetUserData(World,(uintptr_t)Buffer);

    return 1;
}

static int PhysNative_KillWorld(lua_State* L){
    World* World = luax_checkworld(L, 1);
    int id = lua_tointeger(L,2);

    if (id == WorldCount) WorldCount--;

    TotalWorlds[id] = NULL;
    lovrFree((void*)lovrWorldGetUserData(World));

    lovrWorldSetUserData(World, (uintptr_t)NULL);

    return 0;
}

static int PhysNative_IterateBufferStart(lua_State *L){
    World* World = luax_checkworld(L, 1);
    luaL_checktype(L,2,LUA_TFUNCTION);

    WorldColBuf* Buffer = (void*)lovrWorldGetUserData(World);

    for (int i = 0; i < Buffer->ContactCount; i++){
        lua_pushvalue(L,2);

        LightContact* c = &Buffer->ContactArray[i];

        luax_pushtype(L, Collider, c->ColliderA);
        luax_pushtype(L, Collider, c->ColliderB);

        luax_pushshape(L, c->ShapeA);
        luax_pushshape(L, c->ShapeB);

        lua_pushnumber(L, c->normal[0]);
        lua_pushnumber(L, c->normal[1]);
        lua_pushnumber(L, c->normal[2]);

        lua_pushnumber(L,c->Overlap);

        lua_pcall(L,8,0,0);
    }

    Buffer->ContactCount = 0;

    return 0;
}

static int PhysNative_IterateBufferEnd(lua_State* L){
    World* World = luax_checkworld(L, 1);
    luaL_checktype(L,2,LUA_TFUNCTION);

    WorldColBuf* Buffer = (void*)lovrWorldGetUserData(World);

    for (int i = 0; i < Buffer->ColliderCount; i++){
        lua_pushvalue(L,2);

        luax_pushtype(L, Collider, Buffer->ColliderArray[i]);
        luax_pushtype(L, Collider, Buffer->ColliderArray[i++]);

        lua_pcall(L,2,0,0);
    }

    Buffer->ColliderCount = 0;

    return 0;
}

ASTRAL_API int luaopen_PhysNative(lua_State* L){

    lua_newtable(L);
    lua_pushlightuserdata(L,PhysNative_ExitCallback);
    lua_setfield(L, -2, "NativeExit");

    lua_pushlightuserdata(L,PhysNative_EnterCallback);
    lua_setfield(L, -2, "NativeEnter");

    lua_pushcfunction(L,PhysNative_KillWorld);
    lua_setfield(L,-2,"KillWorld");

    lua_pushcfunction(L,PhysNative_RegisterWorld);
    lua_setfield(L,-2,"RegisterWorld");

    lua_pushcfunction(L,PhysNative_IterateBufferStart);
    lua_setfield(L,-2,"IterateStartArray");

    lua_pushcfunction(L,PhysNative_IterateBufferEnd);
    lua_setfield(L,-2,"IterateEndArray");

    return 1;
}
