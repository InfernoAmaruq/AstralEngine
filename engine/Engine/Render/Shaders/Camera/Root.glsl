
@TYPE:FRAGMENT;
@IDENTIFIER:ROOT_CAM_SHADER;
@PRIORITY:1;

uniform vec2 UVOffset;
uniform vec2 UVScale;

vec4 astral_main(){
    UV = UV * UVScale + UVOffset;
    return Color * getPixel(ColorTexture,UV);
}
