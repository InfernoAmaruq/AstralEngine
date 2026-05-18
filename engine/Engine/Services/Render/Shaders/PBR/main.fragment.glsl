@TYPE:FRAGMENT;
@IDENTIFIER:PBR_MAIN;
@PRIORITY:25;

float DistributionGGX(float NdotH, float rough){
    float a = rough * rough;
    float a2 = a*a;

    float denom = (NdotH * NdotH) * (a2 - 1.0) + 1.0;
    return a2 / (PI * denom * denom + 1e-5);
}

float GeometrySchlickGGX(float NdotV, float k){
    return NdotV / (NdotV * (1.0 - k) + k + 1e-5);
}

float GeometrySmith(float NdotV, float NdotL, float k){
    return GeometrySchlickGGX(NdotV,k) * GeometrySchlickGGX(NdotL, k);
}

vec3 fresnelSchlick(float cosTheta, vec3 F0){
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

vec4 astral_main(){
    vec3 albedo = getPixel(ColorTexture,UV).rgb;
    vec3 nmap = (getPixel(NormalTexture, UV).rgb * 2.0 - 1.0) * vec3(Material.normalScale,Material.normalScale,1);
    float roughness = getPixel(RoughnessTexture, UV).r * Material.roughness;
    float metallic = getPixel(MetalnessTexture, UV).r * Material.metalness;

    vec3 N = TangentMatrix * nmap;
    vec3 V = normalize(CameraPositionWorld - PositionWorld);

    float NdotV = max(dot(N,V), 0.0);

    vec3 F0 = mix(vec3(0.04),albedo,metallic);

    float k = roughness + 1.0;
    k = (k * k) / 8.0;

    for (int i = 0; i < Light_LightCount; ++i) {
        vec3 LightPos = Light_Positions[i].xyz;

        vec3 L = normalize(LightPos - PositionWorld);
        vec3 H = normalize(V + L);

        float NdotL = max(dot(N,L),0.0);
        float NdotH = max(dot(N,H),0.0);
        float VdotH = max(dot(V,H),0.0);

        float D = DistributionGGX(NdotH, roughness);
        float G = GeometrySmith(NdotV,NdotL,k);
        vec3 F = fresnelSchlick(VdotH, F0);

        vec3 num = vec3(D * G) * F;
        float denom = 4.0 * NdotV * NdotL + 1e-5;
        vec3 specular = num; // denom;

	float fdLam = 1 / PI;

        vec3 kD = (vec3(1.0) - F) * (1.0 - metallic);
        vec3 diffuse = mix(Color.rgb, vec3(0), metallic);//kD * albedo / PI;

        vec3 radiance = lighting_getLight(N,i);
        vec3 Lo = (diffuse) * radiance;

        // light


        // add ao next
        vec3 color = Lo;

        // tone map

	CurrentColor.rgb += tonemap(Lo);
    }

    // glow
    vec4 map = getPixel(GlowTexture,UV);
    vec4 glow = Material.glow;
    vec3 glowColor = (map.rgb * glow.rgb * glow.a);
    CurrentColor.rgb += glowColor;
}
