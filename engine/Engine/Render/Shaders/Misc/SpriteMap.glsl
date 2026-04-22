@TYPE:FRAGMENT;
@IDENTIFIER:TEXTURE_ATLAS;
@PRIORITY:1;

uniform AtlasData {
    ivec4 Atlas;
};

ivec2 TEXTURE_ATLAS_GET_PIXEL(vec2 UV){
    return ivec2(floor(Atlas.xy - 1)) + ivec2(floor(UV * (Atlas.zw - 1)));
}

vec4 astral_main(){
    if (Atlas.x >= 1){
        ivec2 Pixel = ivec2(floor(Atlas.xy - 1)) + ivec2(floor(UV * (Atlas.zw - 1)));

        return Color * texelFetch(ColorTexture, Pixel,0);
    }
}
