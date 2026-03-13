#include "api.h"
#include "data/cstruct.h"
#include "util.h"
#include <string.h>

static int l_lovrCStructGetPointer(lua_State* L){
    CStruct* cs = luax_checktype(L, 1, CStruct);
    lua_pushlightuserdata(L, cs);
    return 1;
}

static int l_lovrCStructGetName(lua_State* L){
    CStruct* cs = luax_checktype(L, 1, CStruct);
    lua_pushstring(L, cs->Name);
    return 1;
}

static int l_lovrCStructSetSize(lua_State* L){
    CStruct* Str = luax_checktype(L, 1, CStruct);
    int size = luaL_optinteger(L,2,0);

    if (size == 0) {luaL_argerror(L,2,"Invalid size provided to CStruct resize!"); return 0;}

    int Length = Str->Length;
    int CurSize = Str->Size;

    if (size < CurSize){
        // gotta downsize and free heap values
        for (int i = CurSize; i > size; i--){
            CValue* CVal = &Str->Data[i-1];
            int t = CVal->Type;

            if (t == CVAL_STRING){
                lovrFree((void*)CVal->String);
            } else if (t == CVAL_CSTRUCT){
                lovrRelease((void*)CVal->CStruct, lovrCStructDestroy);
            }
        }
    }

    CValue* NewData = realloc(Str->Data,sizeof(CValue) * size);

    if (NewData == NULL){
        lua_pushstring(L, "CStruct resize failed, out of memory");
        lua_error(L);
        return 0;
    }

    Str->Data = NewData;
    Str->Size = size;

    return 0;
}

static int l_lovrCStructGetSize(lua_State* L){
    CStruct* cs = luax_checktype(L, 1, CStruct);
    lua_pushinteger(L, cs->Size);
    return 1;
}

#define l_lovrCStructWrite(L, T)\
    CStruct* cstruct = luax_checktype(L,1,CStruct);\
    lua_Integer index = lua_tointeger(L,2);\
    luax_check(L, index >= 1, "CStruct index cannot be negative");\
    luax_check(L, index <= cstruct->Size, "CStruct index must be less than the size of the CStruct");\
    CValue* cval = &cstruct->Data[index-1];\
\
    if (cval->Type == CVAL_STRING){\
        lovrFree((void*)cval->String);\
    }\
    else if (cval->Type == CVAL_CSTRUCT){\
        lovrRelease(cval->CStruct, lovrCStructDestroy);\
    }\
\
    switch(T){\
        case CVAL_INT:\
            cval->Type = CVAL_INT;\
            cval->Int32 = (int32_t)lua_tointeger(L,3);\
            break;\
        case CVAL_INT64:\
            cval->Type = CVAL_INT64;\
            uint32_t Low = (uint32_t)lua_tointeger(L,3);\
            uint32_t High = (uint32_t)lua_tointeger(L,4);\
            cval->Int64 = ((int64_t)High << 32) | Low;\
            break;\
        case CVAL_FLOAT:\
            cval->Type = CVAL_FLOAT;\
            cval->Float = (float)lua_tonumber(L,3);\
            break;\
        case CVAL_DOUBLE:\
            cval->Type = CVAL_DOUBLE;\
            cval->Double = lua_tonumber(L, 3);\
            break;\
        case CVAL_BOOL:\
            cval->Type = CVAL_BOOL;\
            cval->Boolean = (int)lua_toboolean(L, 3);\
            break;\
        case CVAL_NIL:\
            cval->Type = CVAL_NIL;\
            break;\
        case CVAL_STRING:\
            cval->Type = CVAL_STRING;\
            const char* lstr = lua_tostring(L, 3);\
            size_t len = strlen(lstr);\
            char* str = lovrMalloc(len + 1);\
            memcpy(str, lstr, len + 1);\
            cval->String = str;\
            break;\
        case CVAL_CSTRUCT:\
            cval->Type = CVAL_CSTRUCT;\
            CStruct* inpstruct = luax_checktype(L,3,CStruct);\
            lovrRetain(inpstruct);\
            cval->CStruct = inpstruct;\
            break;\
    }\
    return 0;

static int l_lovrCStructWriteI32(lua_State* L){ l_lovrCStructWrite(L, CVAL_INT) }
static int l_lovrCStructWriteI64(lua_State* L){ l_lovrCStructWrite(L, CVAL_INT64) }
static int l_lovrCStructWriteF32(lua_State* L){ l_lovrCStructWrite(L, CVAL_FLOAT) }
static int l_lovrCStructWriteF64(lua_State* L){ l_lovrCStructWrite(L, CVAL_DOUBLE) }
static int l_lovrCStructWriteNil(lua_State* L){ l_lovrCStructWrite(L, CVAL_NIL) }
static int l_lovrCStructWriteBool(lua_State* L){ l_lovrCStructWrite(L, CVAL_BOOL) }
static int l_lovrCStructWriteString(lua_State* L){ l_lovrCStructWrite(L, CVAL_STRING) }
static int l_lovrCStructWriteCStruct(lua_State* L){ l_lovrCStructWrite(L, CVAL_CSTRUCT) }

static int l_lovrCStructGet(lua_State* L){
    CStruct* cstruct = luax_checktype(L,1,CStruct);
    lua_Integer index = lua_tointeger(L,2);
    luax_check(L, index >= 1, "CStruct index cannot be negative");
    luax_check(L, index <= cstruct->Size, "CStruct index must be less than the size of the CStruct");

    CValue* cval = &cstruct->Data[index-1];
    uint type = cval->Type;
    int ret = 1;

    switch(type){
        case CVAL_DOUBLE:
            lua_pushnumber(L, cval->Double);
            break;
        case CVAL_FLOAT:
            lua_pushnumber(L, (double)cval->Float);
            break;
        case CVAL_INT:
            lua_pushinteger(L, (lua_Integer)cval->Int32);
            break;
        case CVAL_INT64:
            ret = 2;
            int64_t Int = (cval->Int64);
            lua_pushinteger(L, (uint32_t)(Int & 0xFFFFFFFF));
            lua_pushinteger(L, (uint32_t)((Int >> 32) & 0xFFFFFFFF));
            break;
        case CVAL_NIL:
            lua_pushnil(L);
            break;
        case CVAL_BOOL:
            lua_pushboolean(L, cval->Boolean);
            break;
        case CVAL_STRING:
            lua_pushstring(L,cval->String);
            break;
        case CVAL_CSTRUCT:
            luax_pushtype(L, CStruct, cval->CStruct);
            break;
        default:
            lua_pushnil(L);
            break;
    }

    return ret;
}

static int l_lovrCStructGetType(lua_State* L){
    CStruct* cstruct = luax_checktype(L,1,CStruct);
    lua_Integer index = lua_tointeger(L,2);
    luax_check(L, index >= 1, "CStruct index cannot be negative");
    luax_check(L, index < cstruct->Size, "CStruct index must be less than the size of the CStruct");

    CValue* cval = &cstruct->Data[index-1];
    uint type = cval->Type;

    const char* str;

    switch(type){
        case CVAL_INT:
            str = "i32";
            break;
        case CVAL_DOUBLE:
            str = "f64";
            break;
        case CVAL_INT64:
            str = "i64";
            break;
        case CVAL_FLOAT:
            str = "f32";
            break;
        case CVAL_STRING:
            str = "string";
            break;
        case CVAL_BOOL:
            str = "boolean";
            break;
        case CVAL_CSTRUCT:
            str = "cstruct";
            break;
        default:
            str = "nil";
            break;
    }

    lua_pushstring(L,str);
    return 1;
}

const luaL_Reg lovrCStruct[] = {
    { "getName", l_lovrCStructGetName },
    { "getPointer", l_lovrCStructGetPointer },
    { "setSize", l_lovrCStructSetSize },
    { "getSize", l_lovrCStructGetSize },

    {"writeI32", l_lovrCStructWriteI32},
    {"writeI64", l_lovrCStructWriteI64},
    {"writeF32", l_lovrCStructWriteF32},
    {"writeF64", l_lovrCStructWriteF64},

    {"writeNil", l_lovrCStructWriteNil},
    {"writeBool", l_lovrCStructWriteBool},

    {"writeString", l_lovrCStructWriteString},
    {"writeCStruct", l_lovrCStructWriteCStruct},

    {"get", l_lovrCStructGet},

    {"getType", l_lovrCStructGetType},

    { NULL, NULL }
};
