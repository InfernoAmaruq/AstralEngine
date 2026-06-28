@TYPE:VERTEX;
@IDENTIFIER:INSTANCING_VERTEX;
@PRIORITY:-1000;

layout(location = 50) flat out int InstIndex;

uniform INSTANCE_Transform {
    mat4 InstTransformData[INSTANCES];
};

vec4 astral_main(){
    if (IsInstanced){
        InstIndex = InstanceIndex;
        return Projection * View * InstTransformData[InstIndex] * VertexPosition;
    }
}
