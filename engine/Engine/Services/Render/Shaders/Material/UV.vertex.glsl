@TYPE:VERTEX;
@IDENTIFIER:MATERIAL_BASE_UV_SHADER;
@PRIORITY:-100;

#define MATERIAL_FIT_MODE_STRETCH 0
#define MATERIAL_FIT_MODE_TILE 1
#define MATERIAL_FIT_MODE_CROP 2

vec4 astral_main(){
    int FitMode = Material_FitMode;

    if (FitMode == MATERIAL_FIT_MODE_TILE){
        vec2 ImageSize = textureSize(ColorTexture,0);

        float ImageAspect = ImageSize.x / ImageSize.y;

        UV.y = UV.y * ImageAspect;

        vec3 AbsNormal = abs(Normal);
        vec2 AbsScale;

        if (AbsNormal.z > AbsNormal.x && AbsNormal.z > AbsNormal.y)
            AbsScale = Material_Scale.xy;
        else if (AbsNormal.y > AbsNormal.x)
            AbsScale = Material_Scale.xz;
        else
            AbsScale = Material_Scale.zy;

        UV = UV * AbsScale;
    }
    else if (FitMode == MATERIAL_FIT_MODE_CROP){
        vec2 ImageSize = textureSize(ColorTexture,0);

        float ImageAspect = ImageSize.x / ImageSize.y;

        UV.x = UV.x / ImageAspect + 0.25;
    }

    vec4 MatUV = Material_UV;
    vec2 Material_UVOffset = MatUV.xy;
    vec2 Material_UVScale = MatUV.zw;

    UV = UV * Material_UVScale + Material_UVOffset;
}
