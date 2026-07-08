#ifdef GL_FRAGMENT_SHADER

#include "OIT/Composite.glsl"
#include "AO/SSAO.frag"
#include "PostProcessing/Fog.frag"
#include "PostProcessing/Bloom/Extract.glsl"

vec4 lovrmain() {
    float Depth;
    vec3 Normal;
    vec4 Color = OIT_Unpack(Depth, Normal);

    float Fog;
    Color.rgb = DoFog(Depth, Color.rgb, Fog);

    SSAO_GetValue(Normal, Depth, 1-Fog);

    GetBloom(Color.rgb);

    return Color;
}
#else
vec4 lovrmain() { return DefaultPosition; }
#endif
