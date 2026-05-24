@TYPE:FRAGMENT;
@PRIORITY:100;
@IDENTIFIER:BLUR_PASS;

uniform bool IsHorizontal;

layout(location = 1) out vec4 AO_OUTPUT;
layout(location = 2) out vec4 BLOOM_OUTPUT;

uniform sampler2D AO_Tex;
uniform sampler2D Bloom_Tex;
uniform bool Horizontal;

#define AO_BLUR_RADIUS 3
#define BLOOM_BLUR_RADIUS 40

#define MAX_RADIUS max(AO_BLUR_RADIUS,BLOOM_BLUR_RADIUS)

float gaussianWeight(int dist, float SIGMA){
    float sigma2 = SIGMA * SIGMA;
    return exp(-(float(dist * dist)) / (2.0 * sigma2));
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
        vec3 sample = getPixel(Image,newUV).rgb;

        float weight = gaussianWeight(abs(i), sigma);
        result += sample * weight;
        weightSum += weight;
    }

    return result / weightSum;
}

vec4 astral_main(){

    AO_OUTPUT = vec4(blur(AO_Tex,UV,AO_BLUR_RADIUS,2.0),1);
    
    BLOOM_OUTPUT = vec4(blur(Bloom_Tex,UV,BLOOM_BLUR_RADIUS,10.0),1);

}
