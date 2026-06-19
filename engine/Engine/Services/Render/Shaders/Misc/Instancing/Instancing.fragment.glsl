@TYPE:FRAGMENT;
@IDENTIFIER:INSTANCING_FRAGMENT;
@PRIORITY:-1000;

layout(location = 50) flat in int InstIndex;

#ifndef INSTANCES
#define INSTANCES 256
#endif

uniform bool IsInstanced;

vec4 astral_main(){}
