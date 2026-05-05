@TYPE:FRAGMENT;
@IDENTIFIER:CEL_SHADER;
@PRIORITY:2;

flagged const float BANDS = 5.0;

flagged const float LD_x = -1;
flagged const float LD_y = -1;
flagged const float LD_z = -1;

vec4 astral_main(){
    const vec3 LightDirection = vec3(LD_x,LD_y,LD_z);
    vec3 L = normalize(-LightDirection);
    vec3 N = normalize(Normal);
    float Norm = 0.5 + dot(N,L) * 0.5;

    vec3 BaseColor = CurrentColor.rgb * Norm;
    vec3 ClampedColor = round(BaseColor * BANDS) / BANDS;

    return vec4(ClampedColor, CurrentColor.a);
}
