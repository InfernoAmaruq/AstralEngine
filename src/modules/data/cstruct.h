#include <stdatomic.h>
#include <stdlib.h>
#include "stdint.h"

#pragma once

static enum {
    CVAL_NONE = 0b000000,
    CVAL_NIL = 0b000001,

    CVAL_GENERIC_NUM = 0b110000,

    CVAL_INT = 0b110010,
    CVAL_INT64 = 0b110011,
    CVAL_FLOAT = 0b110100,
    CVAL_DOUBLE = 0b110101,

    CVAL_BOOL = 0b000111,
    CVAL_STRING = 0b001000,
    CVAL_CSTRUCT = 0b001001

} CS_CVALUE_TYPE;

typedef struct CStruct CStruct;

typedef struct {
    uint8_t Type;
    union {
        int32_t Int32;
        int64_t Int64;
        float Float;
        double Double;
        int Boolean;
        const char* String;
        CStruct* CStruct;
    };
} CValue;

typedef struct CStruct {
    _Atomic uint32_t RefCount;
    uint32_t Size;
    uint32_t Length;
    CValue* Data;
    char* Name;
} CStruct;

CStruct* lovrCStructCreate(size_t size);
void lovrCStructDestroy(void* ref);
