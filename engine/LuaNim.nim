#[
    NOTE: DEFINE FUNCTIONS WITH:

    proc f*() {.cdecl, exportc, dynlib.} FOR THE SYMBOLS TO EXPORT CORRECTLY
]#

{.passC: "-I./LUA_SRC".}
{.passL: "-L./LuaLib -llua -Wl,-rpath=./LuaLib".}

# GLOBALS
const
    LUA_YIELD* : cint = 1
    LUA_OK* : cint = 0

    LUA_TNIL* : cint     = 0
    LUA_TBOOLEAN* : cint = 1
    LUA_TLIGHTUSERDATA* : cint = 2
    LUA_TNUMBER* : cint = 3
    LUA_TSTRING* : cint = 4
    LUA_TTABLE* : cint = 5
    LUA_TFUNCTION* : cint = 6
    LUA_TUSERDATA* : cint = 7
    LUA_TTHREAD* : cint = 8

# TYPES

type
    Lua_State* = object
    Plua_State* = ptr Lua_State
    TLuaCFunction* = proc(L: Plua_State): cint {.cdecl.}

# IMPORTS

proc luaL_newstate*(): Plua_State {.importc, cdecl.}
proc lua_close*(L: Plua_State) {.importc, cdecl.}
proc luaL_openlibs*(L: Plua_State) {.importc, cdecl.}
proc luaL_loadstring*(L: Plua_State, s:cstring) : cint {.importc, cdecl.}
proc lua_pcall*(L: Plua_State, nargs, nresults, errfunc : cint) : cint {.importc, cdecl.}

proc lua_type*(L: PluaState, idx: cint): cint {.importc, cdecl.}

proc lua_gettop*(L: Plua_State): cint {.importc, cdecl.}
proc lua_settop*(L: Plua_State; idx: cint) {.importc, cdecl.}
proc lua_pushnumber*(L: Plua_State; n: cdouble) {.importc, cdecl.}
proc lua_pushinteger*(L: Plua_State; n: clonglong) {.importc, cdecl.}
proc lua_pushboolean*(L: Plua_State; b: cint) {.importc, cdecl.}
proc lua_pushstring*(L: Plua_State; s: cstring) {.importc, cdecl.}
proc lua_pushfstring*(L: Plua_State; fmt: cstring) {.importc, cdecl, varargs.}
proc lua_pushcclosure*(L: Plua_State; f: TLuaCFunction, n: cint) {.importc, cdecl.}
proc lua_pushvalue*(L:Plua_State; n:cint) {.importc, cdecl.}
proc lua_pushnil*(L:Plua_State) {.importc, cdecl.}
proc lua_pushthread*(L:Plua_State) {.importc,cdecl.}

proc lua_tonumber*(L: Plua_State; idx: cint): cdouble {.importc, cdecl.}
proc lua_tointeger*(L: Plua_State; idx: cint): clonglong {.importc, cdecl.}
proc lua_toboolean*(L: Plua_State; idx: cint): cint {.importc, cdecl.}
proc lua_tolstring*(L: Plua_State; idx: cint, len: ptr csize_t): cstring {.importc, cdecl.}
proc lua_tothread*(L: Plua_State; idx: cint): Plua_State {.importc, cdecl.}
proc lua_topointer*(L: Plua_State; idx: cint): pointer {.importc, cdecl.}

proc lua_isnumber*(L: Plua_State; idx: cint): cint {.importc, cdecl.}

proc lua_newthread*(L: Plua_State): Plua_State {.importc, cdecl.}
proc lua_resume*(L: Plua_State; n: cint): cint {.importc, cdecl.}
proc lua_status*(L: Plua_State): cint {.importc, cdecl.}

proc lua_remove*(L: Plua_State; idx: cint) {.importc, cdecl.}
proc lua_insert*(L: Plua_State; idx: cint) {.importc, cdecl.}

proc lua_createtable*(L: Plua_State, narr, nrec : cint) {.importc, cdecl.}
proc lua_settable*(L: Plua_State; idx: cint) {.importc, cdecl.}
proc lua_gettable*(L: Plua_State; idx: cint) {.importc, cdecl.}

proc lua_setfield*(L: Plua_State; idx: cint; k: cstring) {.importc, cdecl.}
proc lua_getfield*(L: Plua_State; idx: cint; k: cstring) {.importc, cdecl.}

proc lua_rawgeti*(L: Plua_State; idx:cint; n: cint) {.importc, cdecl.}
proc lua_rawseti*(L: Plua_State, idx:cint; n: cint) {.importc, cdecl.}

proc lua_newuserdata*(L: Plua_State; size: csize_t): pointer {.importc, cdecl.}
proc luaL_newmetatable*(L: Plua_State; name: cstring): cint {.importc, cdecl.}
proc lua_setmetatable*(L: Plua_State; idx: cint) {.importc, cdecl.}

proc lua_next*(L: Plua_State; idx: cint): cint {.importc, cdecl.}
proc lua_xmove*(L: Plua_State; To: Plua_State; x:cint) {.importc, cdecl.}

proc lua_objlen*(L: Plua_State, idx: cint): csize_t {.importc, cdecl.}

# MACROS

template lua_pop*(L:Plua_State,n:cint) = 
    lua_settop(L,-((n)+1))

template lua_pushcfunction*(L: Plua_State; f: TLuaCFunction) =
    lua_pushcclosure(L,f,0)

template lua_newtable*(L: Plua_State) =
    lua_createtable(L,0,0)

template lua_tostring*(L: Plua_State; idx: cint): cstring = 
    lua_tolstring(L,idx,nil)
