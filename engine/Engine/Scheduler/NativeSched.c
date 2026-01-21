#include "lua.h"
#include "lauxlib.h"

// NON FUNCTIONAL CURRENTLY!!!

#define KillRoutine(L,RIdx) (lua_pushvalue(L.-1);lua_pushnil(L);lua_settable(L,RIdx);)

int DoRoutines(lua_State* L, double Budget, double Start){
    return 0;
};

int DoQueue(lua_State* L, double Budget, double Start){

}

int lua_SchedUpd(lua_State* L){

}

int lua_GetClock(lua_State* L){
    return 1;
}

int TEST_FUNC(lua_State* L){
    return 1;
}

int luaopen_libNativeSched(lua_State* L){
    lua_newtable(L);

    return 1;
}
