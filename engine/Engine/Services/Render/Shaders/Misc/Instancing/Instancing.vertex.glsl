@TYPE:VERTEX;
@IDENTIFIER:INSTANCING_VERTEX;
@PRIORITY:-1000;

layout(location = 101) flat out int InstIndex;

#ifndef INSTANCES
#define INSTANCES 256
#endif

uniform bool IsInstanced;

uniform mat4 InstTransformData[INSTANCES];

vec4 astral_main(){
    if (IsInstanced){
        InstIndex = InstanceIndex;
        return Projection * View * InstTransformData[InstIndex] * VertexPosition;
    }
}
