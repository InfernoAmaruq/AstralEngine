@TYPE:VERTEX;
@IDENTIFIER:INSTANCING_VERTEX;
@PRIORITY:-1000;

layout(location = 5) flat out unmangled int InstIndex;

uniform INSTANCE_Transform {
    mat4 InstTransformData[INSTANCES];
};

vec4 astral_main(){
    if (IsInstanced){
        InstIndex = InstanceIndex;

        mat4 Transform = InstTransformData[InstIndex];

        PositionWorld = vec3(Transform * VertexPosition);
        Normal = mat3(transpose(inverse(Transform))) * VertexNormal;

        return Projection * View * Transform * VertexPosition;
    }
}
