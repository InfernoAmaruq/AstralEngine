@TYPE:FRAGMENT;
@PRIORITY:1000;
@IDENTIFIER:OIT_DRAW;

layout(location = 1) out vec2 SecondColor;
uniform bool Transparent;

vec4 astral_main(){
    float a = CurrentColor.a;
    if (a < 0.05) discard;

    if (Transparent){
        if (a > 0.95) discard;
        
        float z = clamp(gl_FragCoord.z,0.0,1.0);
        float DepthWeight = min(pow(z,1.5),0.8);

        float Weight = a * (0.2 + 1.5 * DepthWeight);

        SecondColor = vec2(- log(1.0-a),Weight);
        terminate vec4(CurrentColor.rgb * a * Weight, 1);
    }
    else
    {
        if (a < 0.95) discard;
        terminate vec4(CurrentColor.rgb,1);
    }
}
