#include "lua.h"
#include "lauxlib.h"
//#include "timer/timer.h"

#define DEFAULT_BUDGET 1

#define KillRoutine(L,RIdx) (lua_pushvalue(L.-1);lua_pushnil(L);lua_settable(L,RIdx);)
#define GetTime() ;//lovrTimerGetTime();

int DoRoutines(lua_State* L, double Budget, double Start){
    return 0;
};

int DoQueue(lua_State* L, double Budget, double Start){

}

int l_astralSchedUpd(lua_State* L){
    const int base = lua_gettop(L);

    lua_pushvalue(L,1);
    const int withinBudget = 1;
    float curTime = GetTime();

    lua_getfield(L,-1,"Budget");
    double budget = lua_tonumber(L,-1);
    lua_pop(L,1);

    DoRoutines(L, budget, curTime);

defer:
    const int top = lua_gettop(L);
    if (top != base)
        lua_pop(L, top-base);
    return 0;

    // work

    goto defer;
}

ASTRAL_API int luaopen_NativeSched(lua_State* L){
    lua_newtable(L);
    lua_pushcfunction(L, l_astralSchedUpd);
    lua_setfield(L, -2, "Update");

    return 1;
}
