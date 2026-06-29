@TYPE:GRAPHICS;
@IDENTIFIER:MATERIAL_HEADER;
@PRIORITY:-1000;

uniform mat4 Material_Matrix;
uniform sampler Material_PixelSampler;

#define HAS_MATERIAL_HEADER

uniform vec3 Material_ObjectScale;

#ifdef INSTANCING_ACTIVE

uniform INSTANCE_Material {
    mat4 Material_MatrixInstanced[INSTANCES];
};

uniform INSTANCE_Scale {
    vec3 Material_ObjectScaleInstanced[INSTANCES];
};

#define Material_UV (IsInstanced ? Material_MatrixInstanced[InstIndex][0] : Material_Matrix[0])
#define Material_Color (IsInstanced ? Material_MatrixInstanced[InstIndex][1] : Material_Matrix[1])
#define Material_FitMode int(IsInstanced ? Material_MatrixInstanced[InstIndex][2].x : Material_Matrix[2].x)
#define Material_UsePixelSampler int(IsInstanced ? Material_MatrixInstanced[InstIndex][2].y : Material_Matrix[2].y) == 1
#define Material_Scale (IsInstanced ? Material_ObjectScaleInstanced[InstIndex] : Material_ObjectScale)

#else

#define Material_UV Material_Matrix[0]
#define Material_Color Material_Matrix[1]
#define Material_FitMode int(Material_Matrix[2].x)
#define Material_UsePixelSampler int(Material_Matrix[2].y) == 1
#define Material_Scale Material_ObjectScale

#endif

// offset is xy, scale is zw

vec4 astral_main(){}
