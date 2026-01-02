#include "lua.h"
#include "lauxlib.h"

int l_AllocTable(lua_State* L)
{
    double Pull = lua_tointeger(L,-1);
    lua_createtable(L,Pull,0);
    return 1;
}

int l_GetPointer(lua_State* L)
{
    const void* pt = lua_topointer(L,1);
    if (pt == NULL)
        lua_pushnil(L);
    else
        lua_pushfstring(L,"%p",pt);
    return 1;
}

int luaopen_TableAlloc(lua_State* L){
    lua_newtable(L);
    lua_pushcfunction(L,l_AllocTable);
    lua_setfield(L,-2,"Alloc");
    lua_pushcfunction(L,l_GetPointer);
    lua_setfield(L,-2,"GetPtr");
    return 1;
}
