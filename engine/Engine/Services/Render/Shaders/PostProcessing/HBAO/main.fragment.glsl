@TYPE:FRAGMENT;
@PRIORITY:100;
@IDENTIFIER:HBAO;

uniform mat4 Proj;

uniform mat4 ProjInv;

#define HBAO_Rad 0.05
#define HBAO_Bias 0.01
#define HBAO_N_Dir 8
#define HBAO_S_Dir 6
#define HBAO_Strength 2

vec3 HBAO_ReconstructViewPos(vec2 UV, float z){
    vec4 clip = vec4(UV * 2.0 - 1.0, z, 1.0);
    vec4 view = ProjInv * clip;
    vec3 pos = view.xyz / view.w;
    return pos;
}

vec4 astral_main(){
    ivec2 iUV = ivec2(UV * Resolution);
    float z = OIT_ResolveRG(OIT_TexDepth,iUV).r;

    vec3 pos = HBAO_ReconstructViewPos(UV,z);
    vec3 normal = OIT_ResolveRGB(OIT_TexNormal,iUV);

    // marching
    float occlusion = 0.0;

    for (int d = 0; d < HBAO_N_Dir; ++d){
        float angle = (2.0 * PI * d) / HBAO_N_Dir;
        vec2 dir = vec2(cos(angle),sin(angle));

        for (int s = 1; s <= HBAO_S_Dir; ++s){
            float t = pow(s * (HBAO_Rad / HBAO_S_Dir),s / 4);
            vec3 samplePos = pos + (vec3(dir,0) * t);

            vec4 projSample = Proj * vec4(samplePos,1.0);
            vec2 sampleUV = projSample.xy / projSample.w * 0.5 + 0.5;
            ivec2 sampleIUV = ivec2(sampleUV * Resolution);

            float sampleDepth = OIT_ResolveRG(OIT_TexDepth,sampleIUV).r;
            vec3 sampleViewPos = HBAO_ReconstructViewPos(sampleUV,sampleDepth);

            vec3 v = sampleViewPos - pos;
            float height = dot(v,normal);
            float dist = length(v);
            float contribution = smoothstep(HBAO_Bias, HBAO_Rad, -height) * (1.0 / (1.0 + dist));
            occlusion += contribution;
        }
    }

    occlusion /= float(HBAO_N_Dir * HBAO_S_Dir);
    float ao = 1 - clamp(occlusion * HBAO_Strength,0.0,1.0);

    CurrentColor.rgb *= ao;
    CurrentColor.rgb = vec3(1) * ao;
}
