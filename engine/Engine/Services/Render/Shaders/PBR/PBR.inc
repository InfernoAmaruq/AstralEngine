#pragma once
#include "Material/Material.glsl"
#include "Lighting/Lighting.glsl"

uniform vec3 Lighting_Ambience;

uniform textureCube PBR_EnvMap;
buffer readonly PBR_SphericalHarmonics { vec3 PBR_SH[9]; };

Surface PBR_GetSurface(inout vec4 CurrentColor){
    Surface s = getMaterialSurface();

    CurrentColor = vec4(s.baseColor.rgb * Lighting_Ambience,s.baseColor.a);

    CurrentColor.rgb += lighting_getLights(s) * Lighting_Ambience;

    CurrentColor.rgb += getIndirectLighting(s, PBR_EnvMap, PBR_SH);

    CurrentColor.rgb += s.emissive;

    return s;
}

vec4 PBR_GetColor(){
    Surface s = getMaterialSurface();

    vec4 CurrentColor = vec4(s.baseColor.rgb * Lighting_Ambience,s.baseColor.a);

    CurrentColor.rgb += lighting_getLights(s) * Lighting_Ambience;

    CurrentColor.rgb += getIndirectLighting(s, PBR_EnvMap, PBR_SH) * Lighting_Ambience;

    CurrentColor.rgb += s.emissive;

    return CurrentColor;
}
