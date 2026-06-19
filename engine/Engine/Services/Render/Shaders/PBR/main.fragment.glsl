@TYPE:FRAGMENT;
@IDENTIFIER:PBR_MAIN;
@PRIORITY:25;

uniform textureCube PBR_EnvMap;
uniform PBR_SphericalHarmonics { vec3 PBR_SH[9]; };

vec4 astral_main(){
    Surface s = getMaterialSurface();

    CurrentColor = s.baseColor * Lighting_Ambience;

    CurrentColor.rgb += lighting_getLights(s);

    CurrentColor.rgb += getIndirectLighting(s, PBR_EnvMap, PBR_SH);

    CurrentColor.rgb += s.emissive;
}
