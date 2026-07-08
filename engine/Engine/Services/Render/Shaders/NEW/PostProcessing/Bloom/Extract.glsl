layout(location = 2) out vec4 BLOOM_OUTPUT;

uniform bool ExtractBloom;

uniform float BrightnessThreshold;

#define BrightnessThresholdSoft 0.1

void GetBloom(vec3 CurrentColor){
    if (ExtractBloom){
        float luminance = dot(CurrentColor, vec3(0.299, 0.587, 0.114));

        float bloomFactor = smoothstep(
            BrightnessThreshold - BrightnessThresholdSoft,
            BrightnessThreshold + BrightnessThresholdSoft,
            luminance
        );

        if (luminance >= BrightnessThreshold){
            BLOOM_OUTPUT = vec4(CurrentColor * bloomFactor,1);
        }
        else
            BLOOM_OUTPUT = vec4(0,0,0,0);
    }
}
