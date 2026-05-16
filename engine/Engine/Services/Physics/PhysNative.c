#include "lua.h"
#include "lapi.h"
#include <threads.h>

#include "api/l_physics_world.c"
#include "physics/physics.h"

struct WorldCollisionBuffer {
    mtx_t EnterLock;
    mtx_t ExitLock;
    Contact* ContactArray; // for enter, holds only contact (we can get Collider from Contact after)
    Collider* ColliderArray; // for exit, holds both colliders. Iterate in 2's
} WorldCollisionBuffer;

// c state

void PhysNative_ExitCallback(void* userdata, World* world, Collider* a, Collider* b){
    printf("TOUCH END");
}

void PhysNative_EnterCallback(void* userdata, World* world, Collider* a, Collider* b, Contact* contact){
    printf("TOUCH START");
}

// lua

int PhysNative_RegisterWorld(lua_State* L){
    return 0;
}

int PhysNative_KillWorld(lua_State* L){
    return 0;
}

int PhysNative_IterateBufferStart(lua_State *L){
    // lua calls this to iter over collision enter
    return 0;
}

int PhysNative_IterateBufferEnd(lua_State* L){
    // lua calls this to iter over collision exit
    return 0;
}

int luaopen_PhysNative(lua_State* L){

    lua_newtable(L);
    lua_pushlightuserdata(L,PhysNative_ExitCallback);
    lua_setfield(L, -2, "NativeExit");

    lua_pushlightuserdata(L,PhysNative_EnterCallback);
    lua_setfield(L, -2, "NativeEnter");

    return 1;
}
