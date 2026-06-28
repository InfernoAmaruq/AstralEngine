@TYPE:GRAPHICS;
@IDENTIFIER:MATERIAL_HEADER;
@PRIORITY:-1000;

uniform mat4 Material_Matrix;
uniform sampler Material_PixelSampler;

#define HAS_MATERIAL_HEADER

uniform vec3 Material_ObjectScale;

#ifdef INSTANCING_ACTIVE

uniform INSTANCE_Material {
    vec3 Material_ObjectScaleInstanced[INSTANCES];
};

uniform INSTANCE_Scale {
    mat4 Material_MatrixInstanced[INSTANCES];
};

#endif

// offset is xy, scale is zw
#define Material_UV Material_Matrix[0]
#define Material_Color Material_Matrix[1]
#define Material_FitMode int(Material_Matrix[2].x)
#define Material_UsePixelSampler int(Material_Matrix[2].y) == 1

vec4 astral_main(){}
