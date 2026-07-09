#ifndef INSTANCES
#define INSTANCING_ACTIVE
#endif

uniform bool IsInstanced;

#ifdef GL_FRAGMENT_SHADER
layout(location = 5) flat in int InstIndex;
#else
layout(location = 5) flat out int InstIndex;

readonly buffer INSTANCE_Transform {
    mat4 InstTransformData[];
};

vec4 GetInstancedTransform(){
    InstIndex = InstanceIndex;

    mat4 TransformMat = InstTransformData[InstanceIndex];

    PositionWorld = vec3(TransformMat * VertexPosition);
    Normal = mat3(transpose(inverse(TransformMat))) * VertexNormal;

    return Projection * View * TransformMat * VertexPosition;
}
#endif
