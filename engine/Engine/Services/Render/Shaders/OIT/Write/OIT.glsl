@TYPE:FRAGMENT;
@PRIORITY:100000;
@IDENTIFIER:OIT_DRAW;

layout(location = 1) out vec4 SecondColor;
uniform bool Transparent;

vec4 astral_main(){
    float a = CurrentColor.a;
    if (a < 0.02) discard;

    if (Transparent){
        if (a > 0.95) discard;
        
        float z = clamp(gl_FragCoord.z,0.0,1.0);
        float DepthWeight = min(pow(z,1.5),0.8);

        float Weight = a * (0.2 + 1.5 * DepthWeight);

        SecondColor = vec4(- log(1.0-a),Weight,0,0);
        terminate vec4(CurrentColor.rgb * a * Weight, 1);
    }
    else
    {
        if (a < 0.95) discard;
        SecondColor = vec4((s.normal + 1) / 2,1);
        terminate vec4(CurrentColor.rgb,1);
    }
}
