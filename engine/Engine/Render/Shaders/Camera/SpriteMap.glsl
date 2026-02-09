@TYPE:FRAGMENT;
@IDENTIFIER:CEL_SHADER;
@PRIORITY:1;

uniform AtlasData {
    ivec4 Atlas;
};

vec4 astral_main(){
    if (Atlas.x >= 1){
        vec2 TexSize = vec2(textureSize(ColorTexture,0));
        vec2 UvMin = vec2(Atlas.xy - 1) / TexSize;
        vec2 UvSize = vec2(Atlas.zw - 1) / TexSize;
        vec2 duv = UvMin + UV * UvSize;

        return Color * getPixel(ColorTexture,duv);
    }
}
