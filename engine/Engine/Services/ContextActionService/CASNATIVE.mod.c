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
        int IsThr = lua_isthread(L,-1);

        int Yielded, Err = 0;

        if (IsFunc){
            lua_pushvalue(L,-1);
            lua_pushvalue(L,2);
            int Base = lua_gettop(L);

            if (lua_pcall(L,1,1,0) != 0){
                fprintf(stderr, "Function error: %s\n", lua_tostring(L,-1));
                lua_pop(L,1);
                Err = 1;
            }

            if (!Err){
                int Consumed = 0;

                if (lua_isboolean(L,-1)){
                    Consumed = lua_toboolean(L,-1);
                }

                lua_pop(L,1);

                if (Consumed){
                    lua_pushboolean(L,1);
                    return 1;
                }
            }
        } else {
            fprintf(stderr, "INVALID DATATYPE: %s\n",luaL_typename(L,-1));
        }

		lua_pop(L,1);
	}

	lua_pop(L,2);

	return 0;
}

ASTRAL_API int luaopen_CASNATIVE(lua_State* L){
	lua_newtable(L);

	lua_pushcfunction(L,l_CAS_Init);
	lua_setfield(L,-2,"Init");

	lua_pushcfunction(L,l_CAS_Call);
	lua_setfield(L,-2,"Call");

	return 1;
}
