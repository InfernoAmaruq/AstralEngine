@TYPE:VERTEX;
@IDENTIFIER:MATERIAL_BASE_UV_SHADER;
@PRIORITY:-10000;

#define MATERIAL_FILL_MODE_STRETCH 0
#define MATERIAL_FILL_MODE_TILE 1
#define MATERIAL_FILL_MODE_CROP 2

uniform int Material_FillMode;
uniform vec3 Material_ObjectScale;

vec4 astral_main(){
    if (Material_FillMode == MATERIAL_FILL_MODE_TILE){
        vec2 ImageSize = textureSize(ColorTexture,0);

        float ImageAspect = ImageSize.x / ImageSize.y;

        UV.y = UV.y * ImageAspect;

        vec3 AbsNormal = abs(Normal);
        vec2 AbsScale;

        if (AbsNormal.z > AbsNormal.x && AbsNormal.z > AbsNormal.y)
            AbsScale = Material_ObjectScale.xy;
        else if (AbsNormal.y > AbsNormal.x)
            AbsScale = Material_ObjectScale.xz;
        else
            AbsScale = Material_ObjectScale.zy;

        UV = UV * AbsScale;
    }
    else if (Material_FillMode == MATERIAL_FILL_MODE_CROP){
        vec2 ImageSize = textureSize(ColorTexture,0);

        float ImageAspect = ImageSize.x / ImageSize.y;

        UV.x = UV.x / ImageAspect + 0.25;
    }
    // else fall through, default logic
}
