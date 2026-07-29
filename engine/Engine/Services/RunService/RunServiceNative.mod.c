#include "lua.h"
#include "lauxlib.h"

#ifndef lua_isfunction
#define lua_isfunction(L,n) (lua_type(L, (n)) == LUA_TFUNCTION)
#endif

static int RSRef = LUA_NOREF;

static int l_RunService_Init(lua_State* L){
    luaL_checktype(L,1,LUA_TTABLE);
    lua_pushvalue(L,1);
    RSRef = luaL_ref(L,LUA_REGISTRYINDEX);
    return 0;
}

static int l_RunService_Tick(lua_State* L){
    int PStart = luaL_checkinteger(L,1);
    int PLimit = luaL_checkinteger(L,2);
    int HasPass = !lua_isnoneornil(L,3);

    lua_rawgeti(L,LUA_REGISTRYINDEX,RSRef);
    lua_getfield(L,-1,"__BoundToStep");
    luaL_checktype(L,-1,LUA_TTABLE);

    for (int Pr = PStart; Pr <= PLimit; Pr++)
    {
        lua_rawgeti(L,-1,Pr);
        if (!lua_istable(L,-1)) {lua_pop(L,1);continue;}

        int InnerIdx = lua_gettop(L);
        lua_pushnil(L);

        while (lua_next(L,InnerIdx) != 0) {
            int Retain = 0;

            lua_pushvalue(L,-1);
            if (HasPass) lua_pushvalue(L,3);

            if (lua_pcall(L,HasPass ? 1 : 0,0,0) != 0){
                const char *err = lua_tostring(L,-1);
                printf("Lua error: %s\n",err);
                lua_pop(L,1);
            }

            lua_pop(L,1);
        }

        lua_pop(L,1);
    }

    lua_pop(L,2);

    return 0;
}

ASTRAL_API int luaopen_RunServiceNative(lua_State* L){
    lua_newtable(L);

    lua_pushcfunction(L,l_RunService_Init);
    lua_setfield(L,-2,"Init");
    
    lua_pushcfunction(L,l_RunService_Tick);
    lua_setfield(L,-2,"Tick");

    return 1;
}
