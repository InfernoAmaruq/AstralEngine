@TYPE:FRAGMENT;
@PRIORITY:100;
@IDENTIFIER:SSAO;

uniform mat4 Proj;

uniform mat4 ProjInv;

uniform mat4 ViewMatrix;

uniform sampler2D SSAO_Noise;

#define SSAO_Bias 0.0005
#define SSAO_Samples 16
#define SSAO_Radius 4
#define SSAO_Power .3
#define SSAO_MaxDist 1

// NTS: adaptive radius w dist
// NTS 2: hard corners softer soft corners rougher

vec3 SSAO_ReconstructViewPos(vec2 UV, float z){
    vec4 clip = vec4(UV * 2.0 - 1.0, z, 1.0);
    vec4 view = ProjInv * clip;
    vec3 pos = view.xyz / view.w;
    return pos;
}

vec4 astral_main(){
    ivec2 iUV = ivec2(UV * Resolution);
    vec3 normal = OIT_ResolveRGB(OIT_TexNormal, iUV) * 2 - 1;

    normal = normalize(mat3(ViewMatrix) * normal);

    float depth = OIT_ResolveRG(OIT_TexDepth, iUV).r;

    float ao = 0;

    vec3 position = SSAO_ReconstructViewPos(UV,depth);

    if (depth < 0.999){
        vec2 noiseUV = mod(iUV, vec2(4)) / vec2(4);
        vec2 randomDir = texture(SSAO_Noise, noiseUV).xy * 2 - 1;

        for (int i = 0; i < SSAO_Samples; i++){
            float angle = (float(i) / float(SSAO_Samples)) * TAU;

            vec2 dir = vec2(cos(angle), sin(angle));

            float s = sin(randomDir.x * TAU);
            float c = cos(randomDir.x * TAU);
            dir = vec2(
                dir.x * c - dir.y * s,
                dir.x * s + dir.y * c
            );

            vec2 sampleOffset = dir * SSAO_Radius;
            vec2 sampleUV = UV + sampleOffset / Resolution;

            float sampleDepth = OIT_ResolveRG(OIT_TexDepth, ivec2(sampleUV * Resolution)).r;
            vec3 samplePos = SSAO_ReconstructViewPos(sampleUV, sampleDepth);

            vec3 diff = samplePos - position;
            float dist = length(diff);

            if (dist > SSAO_MaxDist) continue;

            vec3 biasedPos = position + normal + SSAO_Bias;
            diff = samplePos - biasedPos;
            dist = length(diff);

            if(samplePos.z > position.z){
                float falloff = 1.0 - smoothstep(0.0, SSAO_MaxDist, dist);
                ao += falloff;
            }
        }

        ao /= float(SSAO_Samples);
        ao = pow(clamp(ao, 0, 1), SSAO_Power);
    }

    ao = smoothstep(0,1,ao);

    CurrentColor.rgb *= 1 - ao;
}
