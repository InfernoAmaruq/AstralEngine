@TYPE:FRAGMENT;
@IDENTIFIER:INSTANCING_FRAGMENT;
@PRIORITY:-1000;

layout(location = 101) flat in int InstIndex;

#ifndef INSTANCES
#define INSTANCES 256
#endif

uniform bool IsInstanced;

uniform mat4 InstMaterialData[INSTANCES];

vec4 astral_main(){
    // so we'd wanna affect the Surface here really..
}
