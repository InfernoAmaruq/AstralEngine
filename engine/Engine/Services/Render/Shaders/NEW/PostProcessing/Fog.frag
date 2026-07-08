uniform bool Fog_DoFog;
uniform float Fog_CamNear;

uniform Fog_Info {
    vec4 fogColor;
    vec4 horizonColor;
    vec4 otherData;
    // x,y - near/far(Fog)
    // z - sharpness
    // w - horizon y offset
};

vec3 DoFog(float depth, vec3 CurrentColor, inout float fogOcclusion){
    fogOcclusion = 0;

    if (Fog_DoFog){
        float Fog_Near = otherData.x;
        float Fog_Far = otherData.y;
        float Fog_Sharpness = otherData.z;

        ivec2 iUV = ivec2(UV * Resolution);

        vec3 fragPos;
        float finalDepth;
        if (depth <= 0){
            depth = Fog_CamNear / (Fog_Far + 1);
            fragPos = ReconstructViewPos(UV,depth);
            finalDepth = Fog_Far + 1;
        } else {
            fragPos = ReconstructViewPos(UV,depth);
            finalDepth = length(fragPos);
        }

        float heightDiff = (inverse(mat3(ViewMatrix)) * fragPos).y - otherData.w;

        float fogFactor = 1 - (Fog_Far - finalDepth) / (Fog_Far - Fog_Near);
        fogFactor = clamp(fogFactor,0.0,1.0);

        Fog_Sharpness = Fog_Sharpness / fogFactor;

        float heightAlpha = 1 - clamp(((heightDiff + Fog_Sharpness) / (Fog_Sharpness * 2)),0,1);

        vec3 hColor = horizonColor.rgb;
        if (horizonColor.a <= 0){
            hColor = CurrentColor;
        }

        vec3 effectiveFogColor = clamp(mix(hColor, fogColor.rgb, heightAlpha),vec3(0),vec3(1));
        float effectiveAlpha = clamp(mix(horizonColor.a, fogColor.a, heightAlpha),0,1);

        vec3 FinalColor = mix(CurrentColor, effectiveFogColor, fogFactor * effectiveAlpha);
        fogOcclusion = fogFactor * effectiveAlpha;
        return FinalColor;
    }
}
