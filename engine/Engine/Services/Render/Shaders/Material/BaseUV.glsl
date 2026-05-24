@TYPE:VERTEX;
@IDENTIFIER:MATERIAL_BASE_UV_SHADER;
@PRIORITY:-9999;

uniform vec2 Material_UVOffset;
uniform vec2 Material_UVScale;

vec4 astral_main(){
    UV = UV * Material_UVScale + Material_UVOffset;
    #ifdef MATERIAL_BASEUV_TO_COLOR
    return Color * getPixel(ColorTexture,UV);
    #endif
}
