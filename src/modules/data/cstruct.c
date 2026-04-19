#include "data/cstruct.h"
#include "util.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

CStruct* lovrCStructCreate(size_t size){
  CStruct* Str = lovrMalloc(sizeof(CStruct));

  CValue* CValArray = lovrMalloc(sizeof(CValue) * size);

  // lua api spawning it is expected to declare itself as owner
  Str->RefCount = 1;
  Str->Length = 0;
  Str->Size = size;
  Str->Data = CValArray;

  return Str;
}

void lovrCStructDestroy(void* ref){
    CStruct* cstruct = ref;

    for (int i = 0; i < cstruct->Size; i++){
        CValue* CVal = &cstruct->Data[i];
        int t = CVal->Type;

        if (t == CVAL_CSTRUCT){
            lovrRelease((void*)CVal->CStruct, lovrCStructDestroy);
        }
        else if (t == CVAL_STRING){
            lovrFree((void*)CVal->String);
        }
    }

    lovrFree(cstruct->Data);
    lovrFree(cstruct);
}
