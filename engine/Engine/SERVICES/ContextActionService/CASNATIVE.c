#include "lua.h"
#include "lauxlib.h"

#ifndef lua_isfunction
#define lua_isfunction(L,n) (lua_type(L, (n)) == LUA_TFUNCTION)
#endif

static int FTRef = LUA_NOREF;

static int l_CAS_Init(lua_State* L){
	luaL_checktype(L,1,LUA_TTABLE);
	lua_pushvalue(L,1);
	FTRef = luaL_ref(L,LUA_REGISTRYINDEX);
	return 0;
}

static int l_CAS_Call(lua_State* L){
	double CODE = luaL_checknumber(L,1);
	luaL_checktype(L,2,LUA_TTABLE);

	lua_rawgeti(L,LUA_REGISTRYINDEX,FTRef);
	lua_rawgeti(L,-1,(int) CODE);

	int Len = (int) lua_objlen(L,-1);

	for (int i = Len; i >= 1; i--){

		lua_rawgeti(L,-1,i);
        int IsFunc = lua_isfunction(L,-1);

        int s;
        lua_State* co;
        
        if (IsFunc){
            co = lua_newthread(L);
            lua_pushvalue(L,-2);
            lua_pushvalue(L,2);
            lua_xmove(L,co,2);
            s = lua_resume(co,1);
        } else {
            co = lua_tothread(L,-1);
            lua_pushvalue(L,2);
            lua_xmove(L,co,2);
            s = lua_resume(co,1);
        }

        if (s != 0 && s != LUA_YIELD)
        {
            fprintf(stderr,"Coroutine error: %s\n",lua_tostring(co,-1));
        }
        else
        {
            int NRes = lua_gettop(co);
            int IsBool = lua_isboolean(co,-1);
            int IsTrue = lua_toboolean(co,-1);

            if (IsBool && IsTrue)
            {
                lua_pushboolean(L,1);
                return 1;
            }
        }

		lua_pop(L,2);
	}

	lua_pop(L,3);

	return 0;
}

int luaopen_CASNATIVE(lua_State* L){
	lua_newtable(L);

	lua_pushcfunction(L,l_CAS_Init);
	lua_setfield(L,-2,"Init");

	lua_pushcfunction(L,l_CAS_Call);
	lua_setfield(L,-2,"Call");

	return 1;
}
