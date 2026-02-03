@TYPE:FRAGMENT;
@PRIORITY:1000;
@IDENTIFIER:OIT_DRAW;

layout(location = 1) out vec4 SecondColor;
uniform bool Transparent;

vec4 astral_main(){
    float a = CurrentColor.a;
    if (a < 0.001) discard;

    if (Transparent){
        if (a > 0.999) discard;

        SecondColor = vec4(a,0,0,1);
        terminate vec4(CurrentColor.rgb * a, a);
    }
    else
    {
        if (a < 0.999) discard;
        terminate vec4(CurrentColor.rgb,1);
    }
}
