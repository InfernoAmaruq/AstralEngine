#include "Camera.inc"

#ifdef GL_FRAGMENT_SHADER
vec4 lovrmain(){
    vec4 CurrentColor;

    Surface s = getMaterialSurface();

    CurrentColor = s.baseColor * Lighting_Ambience;

    CurrentColor.rgb += lighting_getLights(s);

    CurrentColor.rgb += getIndirectLighting(s, PBR_EnvMap, PBR_SH);

    CurrentColor.rgb += s.emissive;

    return CurrentColor;
}
#else
vec4 lovrmain(){
    return vec4();
}
#endif
