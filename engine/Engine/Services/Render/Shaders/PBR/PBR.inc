#pragma once
#include "Material/Material.glsl"
#include "Lighting/Lighting.glsl"

uniform textureCube PBR_EnvMap;
buffer readonly PBR_SphericalHarmonics { vec3 PBR_SH[9]; };
buffer readonly PBR_SphericalHarmonics_User { vec3 PBR_SH_U[9]; };

Surface PBR_GetSurface(inout vec4 CurrentColor){
    Surface s = getMaterialSurface();

    CurrentColor = vec4(0,0,0,1);

    CurrentColor.rgb += lighting_getLights(s);

    vec3 SH[9];

    for (int i = 0; i < 9; ++i)
        SH[i] = PBR_SH[i] + PBR_SH_U[i];

    CurrentColor.rgb += getIndirectLighting(s, PBR_EnvMap, SH);

    CurrentColor.rgb += s.emissive;

    return s;
}

vec4 PBR_GetColor(){
    Surface s = getMaterialSurface();

    vec4 CurrentColor = vec4(s.baseColor.rgb,s.baseColor.a);

    CurrentColor.rgb += lighting_getLights(s);

    vec3 SH[9];

    for (int i = 0; i < 9; ++i)
        SH[i] = PBR_SH[i] + PBR_SH_U[i];

    CurrentColor.rgb += getIndirectLighting(s, PBR_EnvMap, SH);

    CurrentColor.rgb += s.emissive;

    return CurrentColor;
}
