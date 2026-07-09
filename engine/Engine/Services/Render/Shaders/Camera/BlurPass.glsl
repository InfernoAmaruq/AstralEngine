#ifdef GL_FRAGMENT_SHADER

uniform bool IsHorizontal;

layout(location = 1) out vec4 AO_OUTPUT;
layout(location = 2) out vec4 BLOOM_OUTPUT;

uniform sampler2D AO_Tex;
uniform sampler2D Bloom_Tex;
uniform sampler2D Color_Tex;
uniform bool Horizontal;

#define AO_BLUR_RADIUS 4

float gaussianWeight(int ld, float SIGMA){
    float sigma2 = SIGMA * SIGMA;
    return exp(-(float(ld * ld)) / (2.0 * sigma2));
}

vec3 blur(sampler2D Image, vec2 UV, int Radius, float sigma){
    vec3 result = vec3(0.0);
    float weightSum = 0.0;

    for (int i = -Radius; i <= Radius; i++){
        vec2 offset;

        if (Horizontal)
            offset = vec2(float(i),0) / Resolution;
        else
            offset = vec2(0,float(i)) / Resolution;

        vec2 newUV = UV + offset;
        if (newUV.x > 1 || newUV.x < 0 || newUV.y > 1 || newUV.y < 0){
            continue;
        }
        vec3 sampled = getPixel(Image,newUV).rgb;

        float weight = gaussianWeight(abs(i), sigma);
        result += sampled * weight;
        weightSum += weight;
    }

    return result / weightSum;
}


uniform bool DoBloom;
uniform float BloomSize;
uniform float BloomStrength;

uniform bool DoDOF;
uniform vec4 DOFData;
uniform float DOFFadeDist;

#define DEPTH_SAMPLES 4
uniform sampler2DMS Depth_Tex;
uniform float CamNear;

#define DOF_BLUR_RADIUS 5

vec4 lovrmain(){
    AO_OUTPUT = vec4(blur(AO_Tex,UV,AO_BLUR_RADIUS,AO_BLUR_RADIUS/2.0),1);

    vec4 CurrentColor;

    ivec2 IUV = ivec2(UV * Resolution);
    float d = 0;
    for (int i = 0; i < DEPTH_SAMPLES; ++i){
        d += texelFetch(Depth_Tex,IUV,i).r * .25;
    }
    float ld = (CamNear / (d));

    if (DoDOF){
        float focusRadius = DOFData.x;
        float focusDistance = DOFData.y;
        float nearIntensity = DOFData.z;
        float farIntensity = DOFData.w;

        float focusMin = focusDistance - focusRadius;
        float focusMax = focusDistance + focusRadius;

        float dofIntensity = 0;

        if (ld < focusMin) {
            dofIntensity = nearIntensity;

            float u = clamp((focusMin - ld) / DOFFadeDist,0,1);
            dofIntensity *= u;
        }
        else if (ld > focusMax){
            dofIntensity = farIntensity;

            float u = clamp((ld - focusMax) / DOFFadeDist,0,1);
            dofIntensity *= u;
        }

        int rad = int(DOF_BLUR_RADIUS * dofIntensity);

        if (rad <= 0){
            CurrentColor = getPixel(Color_Tex,UV);
        }
        else {
            CurrentColor = vec4(blur(Color_Tex,UV,rad,DOF_BLUR_RADIUS * dofIntensity),1);
        }
    }
    else {
        CurrentColor = getPixel(Color_Tex,UV);
    }
    
    if (DoBloom){
        int bloomSizeCalculated = int(clamp(BloomSize * d,max(BloomSize,5),100));

        float bloomStrength = bloomSizeCalculated;
        if (bloomSizeCalculated > 0){
            BLOOM_OUTPUT = vec4(blur(Bloom_Tex,UV,bloomSizeCalculated,bloomSizeCalculated/2),1) * BloomStrength;
        }
        else
            BLOOM_OUTPUT = vec4(0);
    }
    
    return CurrentColor;
}

#else
vec4 lovrmain() { return DefaultPosition; }
#endif
