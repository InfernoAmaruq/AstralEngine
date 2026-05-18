@TYPE:FRAGMENT;
@IDENTIFIER:LIGHTING_COLOR;
@PRIORITY:20;

#define MAX_LIGHTS 256

uniform Lighting_Data {
    uint Light_LightCount;
    vec4 Light_Positions[MAX_LIGHTS]; // where w is max distance
    vec4 Light_Directions[MAX_LIGHTS]; // where w is angle and MUST be > 0
    vec4 Light_Colors[MAX_LIGHTS];
};

vec3 lighting_getLightPosition(int i){
    return Light_Positions[i].xyz;
}

vec3 lighting_getLight(vec3 Normal, uint i){
    vec3 normNormal = normalize(Normal);

    vec4 lp_raw = Light_Positions[i];
    vec4 ld_raw = Light_Directions[i];
    vec4 lc = Light_Colors[i];
    vec3 lp = lp_raw.xyz;
    float maxDistSqr = lp_raw.w;

    vec3 diff = lp - PositionWorld;
    float distSqr = dot(diff,diff);

    float intensity = lc.a;

    if (distSqr > maxDistSqr) return vec3(0);

    float att = 1.0 - distSqr / maxDistSqr;
    vec3 lDir = diff * inversesqrt(distSqr);
    float NdotL = max(dot(normNormal, lDir),0.0);

    return lc.rgb * intensity * att * NdotL;
}

vec3 lighting_getLights(vec3 Normal){
    vec3 color = vec3(0.0);
    vec3 normNormal = normalize(Normal);

    for (int i = 0; i < Light_LightCount; ++i) {
        vec4 lp_raw = Light_Positions[i];
        vec4 ld_raw = Light_Directions[i];
        vec4 lc = Light_Colors[i];
        vec3 lp = lp_raw.xyz;
        float maxDistSqr = lp_raw.w;

        vec3 diff = lp - PositionWorld;
        float distSqr = dot(diff,diff);

        float intensity = lc.a;

        if (distSqr > maxDistSqr) continue;

        float att = 1.0 - distSqr / maxDistSqr;
        vec3 lDir = diff * inversesqrt(distSqr);
        float NdotL = max(dot(normNormal, lDir),0.0);

        color += lc.rgb * intensity * att * NdotL;
    }

    return color;
}

vec4 astral_main(){

}
