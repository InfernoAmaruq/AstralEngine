#pragma once
#include "Material/Material.glsl"
#include "Lighting/Lighting.glsl"

uniform textureCube PBR_EnvMap;
uniform PBR_SphericalHarmonics { vec3 PBR_SH[9]; };

Surface PBR_GetSurface(inout vec4 CurrentColor){
    Surface s = getMaterialSurface();

    CurrentColor = s.baseColor * Lighting_Ambience;

    CurrentColor.rgb += lighting_getLights(s);

    CurrentColor.rgb += getIndirectLighting(s, PBR_EnvMap, PBR_SH);

    CurrentColor.rgb += s.emissive;

    return s;
}

vec4 PBR_GetColor(){
    Surface s = getMaterialSurface();

    vec4 CurrentColor = s.baseColor * Lighting_Ambience;

    CurrentColor.rgb += lighting_getLights(s);

    CurrentColor.rgb += getIndirectLighting(s, PBR_EnvMap, PBR_SH);

    CurrentColor.rgb += s.emissive;

    return CurrentColor;
}
