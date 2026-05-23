@TYPE:FRAGMENT;
@PRIORITY:120;
@IDENTIFIER:BLOOM_EXTRACT;

layout(location = 2) out vec4 BLOOM_OUTPUT;

#define BrightnessThreshold .5
#define BrightnessThresholdSoft 0.1

vec4 astral_main(){
    float luminance = dot(CurrentColor.rgb, vec3(0.299, 0.587, 0.114));

    float bloomFactor = smoothstep(
        BrightnessThreshold - BrightnessThresholdSoft,
        BrightnessThreshold + BrightnessThresholdSoft,
        luminance
    );

    if (luminance >= BrightnessThreshold){
        BLOOM_OUTPUT = vec4(CurrentColor.rgb * bloomFactor,1);
    }
    else
        BLOOM_OUTPUT = vec4(0,0,0,0);
}
