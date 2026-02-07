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
    lua_getfield(L,-1,"__BOUNDTOSTEP");
    luaL_checktype(L,-1,LUA_TTABLE);

    for (int Pr = PStart; Pr <= PLimit; Pr++)
    {
        lua_rawgeti(L,-1,Pr);
        if (!lua_istable(L,-1)) {lua_pop(L,1);continue;}

        int InnerIdx = lua_gettop(L);
        lua_pushnil(L);

        while (lua_next(L,InnerIdx) != 0) {
            int IsFunc = lua_isfunction(L,-1);
            int IsThr = lua_isthread(L,-1);
            int Retain = 0;
            if (IsFunc || IsThr) {
                lua_State* Co;

                if (IsFunc){
                    /*Co = lua_newthread(L);
                    lua_pushvalue(L,-2);
                    lua_xmove(L,Co,1);

                    int Nargs = 0;
                    if (HasPass) {lua_pushvalue(L,3); lua_xmove(L,Co,1); Nargs = 1;}
                    int s = lua_resume(Co,Nargs);
                    if (s != 0 && s != LUA_YIELD) {
                        const char* Err = lua_tostring(Co,-1);
                        fprintf(stderr,"[RunService] Coroutine error: %s\n",Err ? Err : "(nil)");
                        lua_pop(Co,1);
                    }*/

                    lua_pushvalue(L,-1);
                    if (HasPass) lua_pushvalue(L,3);
                    if (lua_pcall(L,HasPass ? 1 : 0,0,0) != 0){
        
                        const char *err = lua_tostring(L,-1);
                        printf("Lua error: %s\n",err);
                        lua_pop(L,1);
                    }

                } else {
                    Co = lua_tothread(L,-1);
                    int St = lua_status(Co);
                    if (St == LUA_YIELD || St == 0)
                    {
                        int Nargs = 0;
                        if (HasPass) {lua_pushvalue(L,3);lua_xmove(L,Co,1);Nargs = 1;}
                        int s = lua_resume(Co,Nargs);
                        if (s != LUA_YIELD && s != 0){
                            const char* Err = lua_tostring(Co,-1);
                            fprintf(stderr,"[RunService] Coroutine error: %s\n",Err ? Err : "(nil)");
                            lua_pop(Co,1);
                        }
                        else if (s == LUA_YIELD)
                        {
                            int NRet = lua_gettop(Co);
                            if (NRet >= 1 && lua_isnumber(Co,1) && lua_tonumber(Co,1) == -1)
                                Retain = 1;
                        }
                    }else printf("DEAD ROUTINE ON STACK");
                }

                if (IsThr && !Retain)
                {
                    lua_pushvalue(L,-2);
                    lua_pushnil(L);
                    lua_settable(L,InnerIdx);
                }

                lua_pop(L,1);
            } else {
                lua_pop(L,1);
            }
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
